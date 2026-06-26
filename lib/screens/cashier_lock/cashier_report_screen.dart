// lib/screens/cashier_lock/cashier_report_screen.dart
// Cashier Report — View all shifts with full details

import 'package:flutter/material.dart';
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
        if (id.isNotEmpty) merged[id] = r; // overrides local if same ID
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
    // Get denominations for this session
    final denomMap = _denomMap[session.id] ?? [];
    if (denomMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No denomination data found for this shift'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Convert List<DenominationRecord> back to Map<double, int>
    final Map<double, int> denominations = {};
    for (final d in denomMap) {
      denominations[d.denomination] = d.quantity;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating voucher...'), duration: Duration(seconds: 2)),
      );

      await CashVarianceVoucherPDF.generate(
        context: context,
        session: session,
        totalCounted: session.endingCashDeclared,
        systemExpected: session.systemExpectedCash,
        variance: session.variance,
        denominations: denominations,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Cashier Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        actions: [
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

            // IR (if any)
            if (ir != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[700], size: 16),
                        const SizedBox(width: 6),
                        Text('🚨 IR: ${ir.irNumber}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[800])),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Reason: ${ir.reason}', style: const TextStyle(fontSize: 11)),
                    const SizedBox(height: 4),
                    Text('Remarks: ${ir.remarks}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
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
