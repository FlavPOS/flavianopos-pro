// lib/screens/reports/z_report_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../services/daily_lock_service.dart';
import '../../models/z_report_model.dart';
import '../../models/denomination_model.dart';
import '../../helpers/database_helper.dart';
import '../../helpers/sync_bridge.dart';
import '../../models/sync_queue_model.dart';
import '../../utils/z_report_pdf.dart';

class ZReportHistoryScreen extends StatefulWidget {
  final String branch;
  const ZReportHistoryScreen({super.key, required this.branch});
  @override
  State<ZReportHistoryScreen> createState() => _ZReportHistoryScreenState();

}

class _ZReportHistoryScreenState extends State<ZReportHistoryScreen> {
  String? _expandedId;
  // Z REPORT SEARCH STATE - smart search for Z Reports
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";


  // Z REPORT FILTER - smart search across multiple fields
  List<ZReportRecord> get _filteredReports {
    final allReports = ZReportRecord.history;
    if (_searchQuery.isEmpty) return allReports;
    final q = _searchQuery.toLowerCase().trim();
    return allReports.where((r) {
      // Search in: Report ID
      if (r.reportId.toLowerCase().contains(q)) return true;
      // Search in: Cashier name
      if (r.cashier.toLowerCase().contains(q)) return true;
      // Search in: Branch
      if (r.branch.toLowerCase().contains(q)) return true;
      // Search in: Date (formatted as M/D/YYYY)
      final dateStr = "${r.reportDate.month}/${r.reportDate.day}/${r.reportDate.year}";
      if (dateStr.contains(q)) return true;
      // Search in: Status keywords (Over/Short/Balanced)
      if (r.overShort > 0 && "over".contains(q)) return true;
      if (r.overShort < 0 && "short".contains(q)) return true;
      if (r.overShort == 0 && "balanced".contains(q)) return true;
      return false;
    }).toList();
  }

  String _formatDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';
  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }


  @override

  // Z REPORT SEARCH BAR widget
  Widget _searchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      color: Colors.white,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: "Search report ID, cashier, date, status...",
          hintStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: Colors.purple[700], size: 20),
          suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey[600], size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = "");
                },
              )
            : null,
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }


  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }


  // Z REPORT POPUP - slide-up bottom sheet with full report details
  void _showZReportDetail(ZReportRecord r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.purple[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Z Report Detail",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                r.reportId,
                                style: TextStyle(fontSize: 11, color: Colors.purple[700], fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 22),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Body - show full card content using existing builder
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(12),
                      children: [
                        _buildFullReportCard(r),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper: builds the full content of a Z report (was inline in itemBuilder)

  // RICH Z REPORT POPUP - full report content matching PDF layout
  Widget _buildFullReportCard(ZReportRecord r) {
    final isOver = r.overShort > 0;
    final isBalanced = r.overShort == 0;
    final overShortColor = isBalanced ? Colors.green[700]! : (isOver ? Colors.blue[700]! : Colors.orange[700]!);
    final overShortLabel = isBalanced ? "BALANCED" : (isOver ? "OVER" : "SHORT");
    
    // Helper for currency
    String fmt(double v) => "PHP " + v.toStringAsFixed(2);
    
    // Get payment by method
    double getPayment(String method) {
      final p = r.paymentBreakdown.firstWhere(
        (x) => x.method == method,
        orElse: () => ZReportPaymentBreakdown(method: method, count: 0, total: 0),
      );
      return p.total;
    }
    int getPaymentCount(String method) {
      final p = r.paymentBreakdown.firstWhere(
        (x) => x.method == method,
        orElse: () => ZReportPaymentBreakdown(method: method, count: 0, total: 0),
      );
      return p.count;
    }
    
    final vatable = r.netSales / 1.12;
    final vat = r.netSales - vatable;
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.purple[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(8)),
                child: Text(r.reportId, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple[700])),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: overShortColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(overShortLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: overShortColor)),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.calendar_today, size: 13, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(_formatDate(r.reportDate), style: TextStyle(fontSize: 12, color: Colors.grey[800])),
              const SizedBox(width: 12),
              Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(r.cashier, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
            ]),
            const SizedBox(height: 14),
            
            // SALES SUMMARY
            _zSectionTitle("SALES SUMMARY"),
            _zRow("Gross Sales", fmt(r.grossSales)),
            _zRow("Less: Discounts", "-" + fmt(r.totalDiscount)),
            const SizedBox(height: 10),
            
            // NET SALES
            _zSectionTitle("NET SALES"),
            _zRow("Net Sales", fmt(r.netSales), bold: true),
            _zRow("VATable Sales", fmt(vatable)),
            _zRow("VAT (12%)", fmt(vat)),
            _zRow("Total Transactions", r.totalTransactions.toString()),
            _zRow("Average per Transaction", fmt(r.averageTransaction)),
            const SizedBox(height: 10),
            
            // PAYMENT BREAKDOWN
            _zSectionTitle("PAYMENT BREAKDOWN"),
            _zRow("Cash (" + getPaymentCount("Cash").toString() + ")", fmt(getPayment("Cash"))),
            _zRow("GCash (" + getPaymentCount("GCash").toString() + ")", fmt(getPayment("GCash"))),
            _zRow("Maya (" + getPaymentCount("Maya").toString() + ")", fmt(getPayment("Maya"))),
            _zRow("Card (" + getPaymentCount("Card").toString() + ")", fmt(getPayment("Card"))),
            const Divider(height: 16),
            _zRow("TOTAL", fmt(r.netSales), bold: true),
            const SizedBox(height: 10),
            
            // VOIDED & REFUNDED
            _zSectionTitle("VOIDED & REFUNDED"),
            _zRow("Voided Transactions", r.voidedCount.toString()),
            _zRow("Voided Amount", fmt(r.voidedAmount)),
            _zRow("Refunded Transactions", r.refundedCount.toString()),
            _zRow("Refunded Amount", fmt(r.refundedAmount)),
            const SizedBox(height: 10),
            
            // CASH COUNT
            _zSectionTitle("CASH COUNT"),
            _zRow("Beginning Cash", fmt(r.beginningCash)),
            _zRow("+ Cash Sales", "+" + fmt(getPayment("Cash"))),
            _zRow("Expected Cash", fmt(r.expectedCash), bold: true),
            _zRow("Ending Cash", fmt(r.endingCash), bold: true),
            const SizedBox(height: 10),
            
            // OVER/SHORT BADGE
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: overShortColor.withOpacity(0.1),
                border: Border.all(color: overShortColor, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(overShortLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: overShortColor)),
                Text(fmt(r.overShort.abs()), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: overShortColor)),
              ]),
            ),
            const SizedBox(height: 14),
            
            // Re-Print button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.print, size: 16),
                label: const Text('Re-Print Voucher', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  final denomMap = await DatabaseHelper().getDenominationMapForSession(r.reportId);
                  await ZReportPdf.printFromRecord(r, denominations: denomMap);
                },
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text(
              "Generated: " + _formatDate(r.generatedAt) + " " + _formatTime(r.generatedAt),
              style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic),
            )),
          ],
        ),
      ),
    );
  }
  
  // Helper: section title (uppercase, bold, with divider)
  Widget _zSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple[800], letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Container(height: 1, color: Colors.grey[300]),
        ],
      ),
    );
  }
  
  // Helper: label-value row
  Widget _zRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: 12,
            color: Colors.grey[800],
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          )),
          Text(value, style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: bold ? Colors.black : Colors.grey[800],
          )),
        ],
      ),
    );
  }


  Widget build(BuildContext context) {
    final allReports = ZReportRecord.history;
    final reports = _filteredReports; // Z REPORT WIRED

    return Scaffold(
      appBar: AppBar(
        title: const Text('Z Report History', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            tooltip: 'Export',
            onSelected: (value) {
              if (value == 'excel') _exportAllExcel();
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(value: 'excel', child: Row(children: [Icon(Icons.table_chart, color: Colors.green), SizedBox(width: 8), Text('Export Excel')])),
            ],
          ),
        ],
        backgroundColor: Colors.purple[700], foregroundColor: Colors.white,
      ),
      body: Column(children: [_searchBar(), Expanded(child: allReports.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 8),
            const Text('No Z Reports generated yet', style: TextStyle(color: Colors.grey)),
            Text('Generate a Z Report to see it here', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ]))
        : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            // MINIMAL Z CARD - tap to open popup detail
            final r = reports[index];
            
            // Color coding by overShort status
            Color borderColor;
            Color badgeBg;
            Color badgeColor;
            String statusLabel;
            
            if (r.overShort == 0) {
              borderColor = Colors.green[400]!;
              badgeBg = Colors.green[50]!;
              badgeColor = Colors.green[700]!;
              statusLabel = "BALANCED";
            } else if (r.overShort > 0) {
              borderColor = Colors.blue[400]!;
              badgeBg = Colors.blue[50]!;
              badgeColor = Colors.blue[700]!;
              statusLabel = "OVER";
            } else {
              borderColor = Colors.orange[400]!;
              badgeBg = Colors.orange[50]!;
              badgeColor = Colors.orange[700]!;
              statusLabel = "SHORT";
            }
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showZReportDetail(r),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(color: borderColor, width: 5),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(children: [
                    // Status icon
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.receipt_long, size: 18, color: badgeColor),
                    ),
                    const SizedBox(width: 12),
                    // Report info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            r.reportId,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(children: [
                            Icon(Icons.calendar_today, size: 11, color: Colors.grey[600]),
                            const SizedBox(width: 3),
                            Text(_formatDate(r.reportDate), style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                            Text(" • ", style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                            Icon(Icons.person_outline, size: 11, color: Colors.grey[600]),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                r.cashier.isEmpty ? "Unknown" : r.cashier,
                                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor.withOpacity(0.4), width: 0.8),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
                  ]),
                ),
              ),
            );
          },
        ),
    )]),
    );
  }

  Widget _quickStat(String label, String value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
        Text(label, style: TextStyle(fontSize: 8, color: Colors.grey[600])),
      ]),
    ));
  }

  Widget _detailSection(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple[700])),
      const SizedBox(height: 4),
      ...children,
    ]);
  }

  Widget _detailRow(String label, String value, [Color? color]) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]));
  }
  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// 🆕 Re-declare cash count from History — self-contained audit flow
  Future<void> _showHistoryDenominationDialog(ZReportRecord r, String username, String reason) async {
    final tempCtrls = <double, TextEditingController>{};
    for (final d in DenominationRecord.phDenominations) {
      tempCtrls[d] = TextEditingController();
    }

    double computeTotal() {
      double total = 0;
      for (final d in DenominationRecord.phDenominations) {
        final qty = int.tryParse(tempCtrls[d]?.text.trim() ?? '') ?? 0;
        total += d * qty;
      }
      return total;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final total = computeTotal();
          return AlertDialog(
            title: Row(children: [
              Icon(Icons.account_balance_wallet, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 8),
              const Expanded(child: Text('Re-Declare Cash Count')),
            ]),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        '🔄 Recount for ' + r.reportId + '\nAuthorized by: ' + username + '\nReason: ' + reason,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...DenominationRecord.phDenominations.map((d) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        SizedBox(width: 56, child: Text(
                          d >= 1 ? 'P' + d.toInt().toString() : d.toStringAsFixed(2) + 'c',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        )),
                        const SizedBox(width: 8),
                        const Text('x'),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(
                          controller: tempCtrls[d],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '0',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        )),
                        const SizedBox(width: 8),
                        SizedBox(width: 70, child: Text(
                          'P' + (d * (int.tryParse(tempCtrls[d]?.text.trim() ?? '') ?? 0)).toStringAsFixed(2),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11),
                        )),
                      ]),
                    )),
                    const Divider(thickness: 2),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('NEW COUNT:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('P' + total.toStringAsFixed(2),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange.shade800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: total == 0 ? null : () async {
                  final newOverShort = total - r.expectedCash;
                  final now = DateTime.now().toUtc().toIso8601String();
                  await DatabaseHelper().updateZReport(r.reportId, {
                    'endingCash': total,
                    'overShort': newOverShort,
                  });

                  // 💰 Save re-declared denominations to denomination_records (linked to reportId)
                  try {
                    final db2 = await DatabaseHelper().database;
                    // Delete previous denomination records for this reportId (avoid duplicates)
                    await db2.delete('denomination_records', where: 'sessionId = ?', whereArgs: [r.reportId]);
                    // Save the new breakdown
                    final denomRecords = <Map<String, dynamic>>[];
                    final nowDt = DateTime.now();
                    for (final d in DenominationRecord.phDenominations) {
                      final qty = int.tryParse(tempCtrls[d]?.text.trim() ?? '') ?? 0;
                      if (qty > 0) {
                        denomRecords.add(DenominationRecord(
                          sessionId: r.reportId,
                          type: 'ending',
                          denomination: d,
                          quantity: qty,
                          total: d * qty,
                          createdAt: nowDt,
                        ).toMap());
                      }
                    }
                    if (denomRecords.isNotEmpty) {
                      await DatabaseHelper().insertDenominationBatch(denomRecords);
                      debugPrint('💰 Re-declared & saved ' + denomRecords.length.toString() + ' denominations for ' + r.reportId);
                    }
                  } catch (e) {
                    debugPrint('⚠️ Failed to save re-declared denominations: ' + e.toString());
                  }

                  // 🔥 Sync to Firebase (multi-store BIR audit)
                  try {
                    await ZReportRecord.loadFromDB();
                    final updated = ZReportRecord.history.firstWhere((rec) => rec.reportId == r.reportId, orElse: () => r);
                    await SyncBridge.enqueueZReport(updated, op: SyncOp.update);
                  } catch (e) {
                    debugPrint("⚠️ Firebase sync failed: $e");
                  }
                  final db = await DatabaseHelper().database;
                  await db.insert('expense_audit_trail', {
                    'id': 'AUDIT-' + DateTime.now().millisecondsSinceEpoch.toString(),
                    'expenseId': 'Z_REDECLARE',
                    'expenseNumber': r.reportId,
                    'action': 'Z_REPORT_REDECLARED',
                    'oldValue': r.endingCash.toStringAsFixed(2),
                    'newValue': total.toStringAsFixed(2),
                    'performedBy': username,
                    'performedDate': now,
                    'branch': widget.branch,
                  });
                  if (context.mounted) Navigator.pop(ctx);
                  await ZReportRecord.loadFromDB();
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Re-declared by ' + username + ': P' + total.toStringAsFixed(2)),
                      backgroundColor: Colors.green,
                    ));
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Save New Count'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 🆕 Export ALL Z Reports to Excel
  Future<void> _exportAllExcel() async {
    try {
      final allReports = ZReportRecord.history;
    final reports = _filteredReports; // Z REPORT WIRED
      if (reports.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Z Reports to export')));
        return;
      }
      final excel = Excel.createExcel();
      final summary = excel['Summary'];
      excel.setDefaultSheet('Summary');
      excel.delete('Sheet1');
      summary.appendRow([
        TextCellValue('Report ID'), TextCellValue('Date'), TextCellValue('Cashier'),
        TextCellValue('Branch'), TextCellValue('Gross'), TextCellValue('Discounts'),
        TextCellValue('Net Sales'), TextCellValue('VATable'), TextCellValue('VAT 12%'),
        TextCellValue('TXN'), TextCellValue('Voided'), TextCellValue('Refunded'),
        TextCellValue('Beginning'), TextCellValue('Expected'), TextCellValue('Ending'), TextCellValue('Over/Short'),
        TextCellValue('Avg/TXN'),
        TextCellValue('Voided Amount'),
        TextCellValue('Refunded Amount'),
        TextCellValue('Cash Sales'),
        TextCellValue('GCash'),
        TextCellValue('Maya'),
        TextCellValue('Card'),
        TextCellValue('Generated At'),
        TextCellValue('Denominations'),
      ]);
      for (final r in reports) {
        final vatable = r.netSales / 1.12;
        final vat = r.netSales - vatable;
        final denomStr = await DatabaseHelper().getDenominationsForSession(r.reportId);
        summary.appendRow([
          TextCellValue(r.reportId),
          TextCellValue(r.reportDate.year.toString() + '-' + r.reportDate.month.toString().padLeft(2, '0') + '-' + r.reportDate.day.toString().padLeft(2, '0')),
          TextCellValue(r.cashier),
          TextCellValue(r.branch),
          DoubleCellValue(r.grossSales),
          DoubleCellValue(r.totalDiscount),
          DoubleCellValue(r.netSales),
          DoubleCellValue(vatable),
          DoubleCellValue(vat),
          IntCellValue(r.totalTransactions),
          IntCellValue(r.voidedCount),
          IntCellValue(r.refundedCount),
          DoubleCellValue(r.beginningCash),
          DoubleCellValue(r.expectedCash),
          DoubleCellValue(r.endingCash),
          DoubleCellValue(r.overShort),
          DoubleCellValue(r.averageTransaction),
          DoubleCellValue(r.voidedAmount),
          DoubleCellValue(r.refundedAmount),
          DoubleCellValue(r.paymentBreakdown.firstWhere((p) => p.method == "Cash", orElse: () => ZReportPaymentBreakdown(method: "Cash", count: 0, total: 0)).total),
          DoubleCellValue(r.paymentBreakdown.firstWhere((p) => p.method == "GCash", orElse: () => ZReportPaymentBreakdown(method: "GCash", count: 0, total: 0)).total),
          DoubleCellValue(r.paymentBreakdown.firstWhere((p) => p.method == "Maya", orElse: () => ZReportPaymentBreakdown(method: "Maya", count: 0, total: 0)).total),
          DoubleCellValue(r.paymentBreakdown.firstWhere((p) => p.method == "Card", orElse: () => ZReportPaymentBreakdown(method: "Card", count: 0, total: 0)).total),
          TextCellValue(r.generatedAt.toIso8601String()),
          TextCellValue(denomStr),
        ]);
      }
      final bytes = excel.encode();
      if (bytes == null) return;
      // �� Web + Mobile compatible export
      if (kIsWeb) {
        // Web: use XFile.fromData (no file system needed)
        final xfile = XFile.fromData(
          Uint8List.fromList(bytes),
          name: 'Z_Reports_' + DateTime.now().millisecondsSinceEpoch.toString() + '.xlsx',
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        await Share.shareXFiles([xfile], text: 'Z Report History Export (' + reports.length.toString() + ' reports)');
      } else {
        // Mobile: save to temp file + share
        final dir = await getTemporaryDirectory();
        final file = File(dir.path + '/Z_Reports_' + DateTime.now().millisecondsSinceEpoch.toString() + '.xlsx');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Z Report History Export (' + reports.length.toString() + ' reports)');
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Exported ' + reports.length.toString() + ' Z Reports'),
        backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Export failed: ' + e.toString()),
        backgroundColor: Colors.red));
    }
  }

  /// 🆕 Export ALL Z Reports to PDF
  Future<void> _exportAllPdf() async {
    try {
      final allReports = ZReportRecord.history;
    final reports = _filteredReports; // Z REPORT WIRED
      if (reports.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Z Reports to export')));
        return;
      }
      for (final r in reports) {
        final denomMap = await DatabaseHelper().getDenominationMapForSession(r.reportId);
        await ZReportPdf.printFromRecord(r, denominations: denomMap);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Generated ' + reports.length.toString() + ' PDF reports'),
        backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ PDF export failed: ' + e.toString()),
        backgroundColor: Colors.red));
    }
  }
}
