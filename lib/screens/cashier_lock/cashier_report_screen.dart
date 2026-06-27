// lib/screens/cashier_lock/cashier_report_screen.dart
// Cashier Report — View all shifts with full details

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/cashier_session_model.dart';
import '../../models/incident_report_model.dart';
import '../../models/denomination_model.dart';
import '../../helpers/database_helper.dart';
import '../../utils/cash_variance_voucher_pdf.dart';
import '../../helpers/sync_bridge.dart';
import 'cash_adjustment_screen.dart';

class CashierReportScreen extends StatefulWidget {
  final String currentUser;
  final String branch;
  const CashierReportScreen({super.key, required this.currentUser, required this.branch});

  @override
  State<CashierReportScreen> createState() => _CashierReportScreenState();
}

class _CashierReportScreenState extends State<CashierReportScreen> {
  String _selectedPeriod = 'Today';
  String _selectedCashier = 'All';
  List<CashierSession> _sessions = [];
  Map<String, IncidentReport?> _irMap = {};
  Map<String, List<DenominationRecord>> _denomMap = {};
  bool _loading = true;
  DateTime? _customStart;
  DateTime? _customEnd;

  final List<String> _periods = ['Today', 'This Week', 'This Month', 'Custom'];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    try {
      // Get all closed sessions
      // ═══════════════════ MERGED LOCAL + CLOUD SESSIONS ═══════════════════
      // ✅ Phase 1: Local first (instant, works offline)
      final localRows = await DatabaseHelper().getAllSessions(status: 'closed');
      
      // ✅ Phase 2: Cloud (non-blocking, only if online)
      List<Map<String, dynamic>> cloudRows = [];
      try {
        final cloudData = await SyncBridge.readCashierSessionsFromFirebase();
        // Filter only closed sessions from cloud
        cloudRows = cloudData.where((m) => (m['status'] ?? '') == 'closed').toList();
      } catch (e) {
        debugPrint('⚠️ Cloud read skipped (offline?): $e');
      }
      
      // ✅ Phase 3: Merge by ID (cloud wins on duplicate - source of truth)
      final Map<String, Map<String, dynamic>> merged = {};
      for (final r in localRows) {
        final id = (r['id'] ?? '').toString();
        if (id.isNotEmpty) merged[id] = r;
      }
      for (final r in cloudRows) {
        final id = (r['id'] ?? '').toString();
        // NEWER WINS BY TIMESTAMP — fixes Re-Declare race condition
        final existing = merged[id];
        if (existing == null) {
          merged[id] = r;
        } else {
          final existingTime = (existing["updatedAt"] ?? existing["adjustedAt"] ?? "").toString();
          final newTime = (r["updatedAt"] ?? r["adjustedAt"] ?? "").toString();
          if (newTime.compareTo(existingTime) >= 0) merged[id] = r;
          else merged[id] = existing;
        }
      }
      
      final allRows = merged.values.toList();
      // Sort by openedAt descending (newest first)
      allRows.sort((a, b) => (b['openedAt'] ?? '').toString().compareTo((a['openedAt'] ?? '').toString()));
      debugPrint('📊 Merged sessions: ${localRows.length} local + ${cloudRows.length} cloud = ${allRows.length} unique');
      List<CashierSession> sessions = allRows.map((r) => CashierSession.fromMap(r)).toList();

      // Filter by period
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;

      switch (_selectedPeriod) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'This Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'Custom':
          startDate = _customStart ?? DateTime(now.year, now.month, now.day);
          endDate = _customEnd ?? now;
          break;
        default:
          startDate = DateTime(now.year, now.month, now.day);
      }

      sessions = sessions.where((s) {
        if (s.closedAt == null) return false;
        return s.closedAt!.isAfter(startDate) && s.closedAt!.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();

      // Filter by cashier
      if (_selectedCashier != 'All') {
        sessions = sessions.where((s) => s.cashierName == _selectedCashier).toList();
      }

      // Sort by closed date desc
      sessions.sort((a, b) => (b.closedAt ?? DateTime.now()).compareTo(a.closedAt ?? DateTime.now()));

      // Load IRs for each session

      // MERGED IR LOCAL + CLOUD
      final localIRRows = await DatabaseHelper().getAllIncidentReports();
      List<Map<String, dynamic>> cloudIRRows = [];
      try {
        cloudIRRows = await SyncBridge.readIncidentReportsFromFirebase();
      } catch (e) {
        debugPrint("Cloud IR read skipped: $e");
      }
      final Map<String, Map<String, dynamic>> mergedIRsByIRId = {};
      for (final r in localIRRows) {
        final id = (r["id"] ?? "").toString();
        if (id.isNotEmpty) mergedIRsByIRId[id] = r;
      }
      for (final r in cloudIRRows) {
        final id = (r["id"] ?? "").toString();
        if (id.isNotEmpty) mergedIRsByIRId[id] = r;
      }
      final Map<String, IncidentReport?> preloadedIRMap = {};
      for (final r in mergedIRsByIRId.values) {
        final sessionId = (r["sessionId"] ?? "").toString();
        if (sessionId.isNotEmpty) {
          try {
            preloadedIRMap[sessionId] = IncidentReport.fromMap(r);
          } catch (e) {
            debugPrint("Skipped malformed IR: $e");
          }
        }
      }
      debugPrint("Merged IRs total: ${preloadedIRMap.length}");
      Map<String, IncidentReport?> irMap = {};
      Map<String, List<DenominationRecord>> denomMap = {};

      for (final s in sessions) {
        irMap[s.id] = preloadedIRMap[s.id]; // O(1) lookup (was DB query per session)

        // Load ending denominations
        final denomRows = await DatabaseHelper().getDenominationsBySession(s.id, type: 'ending');
        denomMap[s.id] = denomRows.map((d) => DenominationRecord.fromMap(d)).toList();
      }

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _irMap = irMap;
          _denomMap = denomMap;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _uniqueCashiers {
    final names = <String>{'All'};
    for (final s in _sessions) {
      names.add(s.cashierName);
    }
    return names.toList();
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStart != null && _customEnd != null
        ? DateTimeRange(start: _customStart!, end: _customEnd!)
        : null,
    );
    if (range != null) {
      setState(() {
        _customStart = range.start;
        _customEnd = range.end;
      });
      _loadSessions();
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")} ${h.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")} $ampm';
  }

  String _formatDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '—';
    final dur = end.difference(start);
    final hours = dur.inHours;
    final mins = dur.inMinutes % 60;
    return '${hours}h ${mins}m';
  }

  Future<void> _reprintVoucher(CashierSession session) async {
    // DIRECT DB QUERY FOR REPRINT — always fresh from SQLite
    final denomRows = await DatabaseHelper().getDenominationsBySession(session.id, type: "ending");
    final Map<double, int> denominations = {};
    for (final row in denomRows) {
      final d = (row["denomination"] as num?)?.toDouble() ?? 0;
      final q = (row["quantity"] as int?) ?? 0;
      if (d > 0) denominations[d] = q;
    }
    if (denominations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Reprint without denomination breakdown (no data found)"),
          backgroundColor: Colors.amber,
          duration: Duration(seconds: 2),
        ),
      );
    }
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating voucher...'), duration: Duration(seconds: 2)),
      );

      // REPRINT WITH WATERMARK + IR (if exists)
      final ir = _irMap[session.id];
      await CashVarianceVoucherPDF.generate(
        context: context,
        session: session,
        totalCounted: session.endingCashDeclared,
        systemExpected: session.systemExpectedCash,
        variance: session.variance,
        denominations: denominations,
        isReprint: true,
        incidentReport: ir,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voucher re-printed successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Re-print error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  // EXPORT ALL EXCEL CASHIER — flat table of all cashier sessions
  Future<void> _exportAllExcel() async {
    try {
      if (_sessions.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No sessions to export")));
        return;
      }
      
      final excel = Excel.createExcel();
      final sheet = excel["Cashier Report"];
      excel.setDefaultSheet("Cashier Report");
      excel.delete("Sheet1");
      
      // Header Row
      sheet.appendRow([
        TextCellValue("Shift ID"),
        TextCellValue("Cashier"),
        TextCellValue("Branch"),
        TextCellValue("Opened At"),
        TextCellValue("Closed At"),
        TextCellValue("Status"),
        TextCellValue("Beginning Cash"),
        TextCellValue("Cash Sales"),
        TextCellValue("GCash Sales"),
        TextCellValue("Maya Sales"),
        TextCellValue("Card Sales"),
        TextCellValue("Other Sales"),
        TextCellValue("Total Refunds"),
        TextCellValue("Total Voids"),
        TextCellValue("Total Discounts"),
        TextCellValue("Total Exchanges"),
        TextCellValue("Transaction Count"),
        TextCellValue("System Expected"),
        TextCellValue("Ending Declared"),
        TextCellValue("Variance"),
        TextCellValue("Variance Type"),
        TextCellValue("Was Adjusted"),
        TextCellValue("Original Declared"),
        TextCellValue("Original Variance"),
        TextCellValue("Adjusted By"),
        TextCellValue("Adjusted At"),
        TextCellValue("Adjustment Reason"),
        TextCellValue("IR Number"),
        TextCellValue("IR Status"),
        TextCellValue("IR Reason"),
        TextCellValue("IR Remarks"),
        TextCellValue("IR Filed By"),
        TextCellValue("IR Created At"),
        TextCellValue("IR Approved By"),
        TextCellValue("Denominations"),
      ]);
      
      // Data Rows
      for (final s in _sessions) {
        final ir = _irMap[s.id];
        
        // EXCEL CLOUD DENOMS FALLBACK — try local first, then cloud session payload
        var denomRows = await DatabaseHelper().getDenominationsBySession(s.id, type: "ending");
        var denomStr = denomRows.map((r) {
          final d = (r["denomination"] as num?)?.toDouble() ?? 0;
          final q = r["quantity"] ?? 0;
          return "PHP " + d.toStringAsFixed(2) + " x " + q.toString();
        }).join(", ");
        // If empty, try to find from cloud session payload (already in _sessions if loaded from cloud)
        if (denomStr.isEmpty) {
          try {
            final cloudData = await SyncBridge.readCashierSessionsFromFirebase();
            final cloudSession = cloudData.firstWhere((m) => (m["id"] ?? "").toString() == s.id, orElse: () => {});
            final cloudDenoms = cloudSession["denominations"];
            if (cloudDenoms is List) {
              denomStr = cloudDenoms.map((d) {
                final den = (d["denomination"] as num?)?.toDouble() ?? 0;
                final qty = d["quantity"] ?? 0;
                return "PHP " + den.toStringAsFixed(2) + " x " + qty.toString();
              }).join(", ");
            }
          } catch (e) { debugPrint("Cloud denom fetch failed: $e"); }
        }
        
        // Format dates
        final openedStr = "" +
          s.openedAt.year.toString() + "-" +
          s.openedAt.month.toString().padLeft(2, "0") + "-" +
          s.openedAt.day.toString().padLeft(2, "0") + " " +
          s.openedAt.hour.toString().padLeft(2, "0") + ":" +
          s.openedAt.minute.toString().padLeft(2, "0");
        
        final closedStr = s.closedAt == null ? "" :
          s.closedAt!.year.toString() + "-" +
          s.closedAt!.month.toString().padLeft(2, "0") + "-" +
          s.closedAt!.day.toString().padLeft(2, "0") + " " +
          s.closedAt!.hour.toString().padLeft(2, "0") + ":" +
          s.closedAt!.minute.toString().padLeft(2, "0");
        
        sheet.appendRow([
          TextCellValue(s.shiftId),
          TextCellValue(s.cashierName),
          TextCellValue(s.branch),
          TextCellValue(openedStr),
          TextCellValue(closedStr),
          TextCellValue(s.status),
          DoubleCellValue(s.beginningCash),
          DoubleCellValue(s.cashSales),
          DoubleCellValue(s.gcashSales),
          DoubleCellValue(s.mayaSales),
          DoubleCellValue(s.cardSales),
          DoubleCellValue(s.otherSales),
          DoubleCellValue(s.totalRefunds),
          DoubleCellValue(s.totalVoids),
          DoubleCellValue(s.totalDiscounts),
          DoubleCellValue(s.totalExchanges),
          IntCellValue(s.transactionCount),
          DoubleCellValue(s.systemExpectedCash),
          DoubleCellValue(s.endingCashDeclared),
          DoubleCellValue(s.variance),
          TextCellValue(s.varianceType),
          TextCellValue(""), // wasAdjusted - field may not be in model
          TextCellValue(""), // originalDeclared
          TextCellValue(""), // originalVariance
          TextCellValue(""), // adjustedBy
          TextCellValue(""), // adjustedAt
          TextCellValue(""), // adjustmentReason
          TextCellValue(ir?.irNumber ?? ""),
          TextCellValue(ir?.status ?? ""),
          TextCellValue(ir?.reason ?? ""),
          TextCellValue(ir?.remarks ?? ""),
          TextCellValue(ir?.createdBy ?? ""),
          TextCellValue(ir == null ? "" : ir.createdAt.toIso8601String()),
          TextCellValue(ir?.approvedBy ?? ""),
          TextCellValue(denomStr),
        ]);
      }
      
      final bytes = excel.encode();
      if (bytes == null) return;
      
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final filename = "CashierReport_" + timestamp + ".xlsx";
      
      // Web + Mobile compatible export
      if (kIsWeb) {
        final xfile = XFile.fromData(
          Uint8List.fromList(bytes),
          name: filename,
          mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        );
        await Share.shareXFiles([xfile], 
          text: "Cashier Report Export (" + _sessions.length.toString() + " sessions)");
      } else {
        final dir = await getTemporaryDirectory();
        final file = File(dir.path + "/" + filename);
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)],
          text: "Cashier Report Export (" + _sessions.length.toString() + " sessions)");
      }
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Exported " + _sessions.length.toString() + " sessions"),
        backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Export failed: " + e.toString()),
        backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Cashier Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        actions: [
          // EXPORT BUTTON ADDED — Excel export
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: "Export",
            onSelected: (value) {
              if (value == "excel") _exportAllExcel();
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: "excel",
                child: Row(children: [
                  Icon(Icons.table_chart, color: Colors.green),
                  SizedBox(width: 8),
                  Text("Export Excel"),
                ]),
              ),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSessions),
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          _summaryBar(),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _sessions.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _sessions.length,
                    itemBuilder: (_, i) => _sessionCard(_sessions[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          // Period chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _periods.map((p) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(p, style: const TextStyle(fontSize: 11)),
                  selected: _selectedPeriod == p,
                  selectedColor: Colors.indigo[100],
                  onSelected: (_) {
                    setState(() => _selectedPeriod = p);
                    if (p == 'Custom') {
                      _pickCustomRange();
                    } else {
                      _loadSessions();
                    }
                  },
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Cashier filter
          Row(
            children: [
              const Text('Cashier: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Expanded(
                child: DropdownButton<String>(
                  value: _uniqueCashiers.contains(_selectedCashier) ? _selectedCashier : 'All',
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _uniqueCashiers.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) {
                    setState(() => _selectedCashier = v ?? 'All');
                    _loadSessions();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryBar() {
    final totalBeginning = _sessions.fold<double>(0, (s, ss) => s + ss.beginningCash);
    final totalEnding = _sessions.fold<double>(0, (s, ss) => s + ss.endingCashDeclared);
    final totalVariance = _sessions.fold<double>(0, (s, ss) => s + ss.variance);
    final totalSales = _sessions.fold<double>(0, (s, ss) => s + ss.totalSales);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo[50],
        border: Border(top: BorderSide(color: Colors.indigo[200]!), bottom: BorderSide(color: Colors.indigo[200]!)),
      ),
      child: Row(
        children: [
          _summaryItem('Shifts', '${_sessions.length}', Colors.indigo[700]!),
          _summaryItem('Beginning', '₱${(totalBeginning / 1000).toStringAsFixed(1)}k', Colors.blue[700]!),
          _summaryItem('Sales', '₱${(totalSales / 1000).toStringAsFixed(1)}k', Colors.green[700]!),
          _summaryItem('Ending', '₱${(totalEnding / 1000).toStringAsFixed(1)}k', Colors.purple[700]!),
          _summaryItem('Variance', '₱${totalVariance.toStringAsFixed(0)}', totalVariance == 0 ? Colors.green[700]! : (totalVariance.abs() > 50 ? Colors.red[700]! : Colors.orange[700]!)),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('No closed shifts found', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Try a different period or cashier', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _sessionCard(CashierSession session) {
    final ir = _irMap[session.id];
    final denoms = _denomMap[session.id] ?? [];
    final hasVariance = session.variance.abs() > 0.01;
    final varianceColor = session.variance == 0
      ? Colors.green
      : (session.variance.abs() > 50 ? Colors.red : Colors.orange);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person, color: Colors.indigo[700], size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.cashierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(session.shiftId.length > 28 ? '...${session.shiftId.substring(session.shiftId.length - 26)}' : session.shiftId,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Text('CLOSED', style: TextStyle(color: Colors.green[800], fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 16),

            // Shift duration
            _row(Icons.access_time, 'Opened', _formatDate(session.openedAt)),
            _row(Icons.lock, 'Closed', _formatDate(session.closedAt)),
            _row(Icons.timer, 'Duration', _formatDuration(session.openedAt, session.closedAt)),
            const Divider(height: 12),

            // Cash flow
            _bigRow('💰 Beginning', '₱${session.beginningCash.toStringAsFixed(2)}', Colors.blue[700]!),
            _bigRow('💵 Total Sales', '₱${session.totalSales.toStringAsFixed(2)}', Colors.green[700]!),
            _bigRow('🧮 Expected', '₱${session.systemExpectedCash.toStringAsFixed(2)}', Colors.orange[700]!),
            _bigRow('📦 Counted', '₱${session.endingCashDeclared.toStringAsFixed(2)}', Colors.purple[700]!),
            const Divider(height: 12),

            // Variance
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: varianceColor[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(hasVariance ? (session.variance > 0 ? Icons.arrow_upward : Icons.arrow_downward) : Icons.check_circle,
                    color: varianceColor[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasVariance
                        ? 'Variance: ${session.variance > 0 ? "+" : ""}₱${session.variance.toStringAsFixed(2)} (${session.variance > 0 ? "OVER" : "SHORT"})'
                        : 'Variance: ₱0.00 (BALANCED ✓)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: varianceColor[800], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Payment breakdown (compact)
            if (session.totalSales > 0) ...[
              const SizedBox(height: 10),
              const Text('📊 Payment Methods', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (session.cashSales > 0) _paymentChip('💵 Cash', session.cashSales, Colors.green),
                  if (session.gcashSales > 0) _paymentChip('📱 GCash', session.gcashSales, Colors.blue),
                  if (session.mayaSales > 0) _paymentChip('💳 Maya', session.mayaSales, Colors.teal),
                  if (session.cardSales > 0) _paymentChip('💳 Card', session.cardSales, Colors.indigo),
                ],
              ),
            ],

            // Denomination breakdown (collapsed)
            if (denoms.isNotEmpty) ...[
              const SizedBox(height: 10),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('🔢 Denomination Breakdown (${denoms.length})',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                children: denoms.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                  child: Row(
                    children: [
                      Text(DenominationRecord.labelFor(d.denomination), style: const TextStyle(fontSize: 11)),
                      const Text(' × ', style: TextStyle(fontSize: 11)),
                      Text('${d.quantity}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('₱${d.total.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.green[700], fontWeight: FontWeight.w500)),
                    ],
                  ),
                )).toList(),
              ),
            ],

            // EXPANDED IR DETAILS (when session has variance)
            if (ir != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red[300]!, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "INCIDENT REPORT",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[800], letterSpacing: 0.5),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ir.status == "approved" ? Colors.green[100] : (ir.status == "rejected" ? Colors.grey[300] : Colors.orange[100]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ir.status == "approved" ? Colors.green[400]! : (ir.status == "rejected" ? Colors.grey[500]! : Colors.orange[400]!)),
                          ),
                          child: Text(
                            ir.status.toUpperCase(),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ir.status == "approved" ? Colors.green[800] : (ir.status == "rejected" ? Colors.grey[700] : Colors.orange[800])),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, thickness: 1),
                    Row(children: [
                      Icon(Icons.confirmation_number_outlined, size: 14, color: Colors.red[700]),
                      const SizedBox(width: 6),
                      Text("IR No: ", style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      Text(ir.irNumber, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.attach_money, size: 14, color: Colors.red[700]),
                      const SizedBox(width: 6),
                      Text("Variance: ", style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      Text(
                        "PHP ${ir.variance.abs().toStringAsFixed(2)} ${ir.varianceType.toUpperCase()}",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ir.varianceType == "over" ? Colors.blue[700] : Colors.red[700]),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.notes, size: 14, color: Colors.red[700]),
                      const SizedBox(width: 6),
                      Text("Reason: ", style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      Expanded(child: Text(ir.reason.isEmpty ? "Not specified" : ir.reason, style: const TextStyle(fontSize: 11))),
                    ]),
                    if (ir.remarks.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.comment_outlined, size: 14, color: Colors.red[700]),
                        const SizedBox(width: 6),
                        Text("Remarks: ", style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        Expanded(child: Text(ir.remarks, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic))),
                      ]),
                    ],
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.person_outline, size: 14, color: Colors.red[700]),
                      const SizedBox(width: 6),
                      Text("Filed by: ", style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      Text(ir.createdBy.isEmpty ? "Unknown" : ir.createdBy, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.access_time, size: 14, color: Colors.red[700]),
                      const SizedBox(width: 6),
                      Text("Created: ", style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      Text(
                        "${ir.createdAt.month}/${ir.createdAt.day}/${ir.createdAt.year} ${ir.createdAt.hour.toString().padLeft(2, "0")}:${ir.createdAt.minute.toString().padLeft(2, "0")}",
                        style: const TextStyle(fontSize: 11),
                      ),
                    ]),
                    if (ir.approvedBy.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.verified_user_outlined, size: 14, color: Colors.green[700]),
                        const SizedBox(width: 6),
                        Text("Approved by: ", style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        Text(ir.approvedBy, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.green[800])),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
            // Re-Print Voucher Button
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _reprintVoucher(session),
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Re-Print Voucher', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),

            // Re-Declare button (only for sessions with variance)
            ...[ // Always show Re-Declare
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CashAdjustmentScreen(session: session),
                    ));
                    if (result == true) _loadSessions();
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Re-Declare (Manager Only)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _bigRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _paymentChip(String label, double amount, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[200]!),
      ),
      child: Text('$label ₱${amount.toStringAsFixed(2)}',
        style: TextStyle(fontSize: 10, color: color[800], fontWeight: FontWeight.w500)),
    );
  }
}
