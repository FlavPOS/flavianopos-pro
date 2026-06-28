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
            final r = reports[index];
            final isExpanded = _expandedId == r.reportId;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.purple.withAlpha(60))),
              child: Column(children: [
                // Header
                InkWell(
                  onTap: () => setState(() => _expandedId = isExpanded ? null : r.reportId),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(8)),
                        child: Text(r.reportId, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple[700]))),
                      const Spacer(),
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]), const SizedBox(width: 6),
                      Text(_formatDate(r.reportDate), style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                      const SizedBox(width: 16),
                      Icon(Icons.person, size: 14, color: Colors.grey[500]), const SizedBox(width: 4),
                      Text(r.cashier, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      _quickStat('Net Sales', r.netSales.toStringAsFixed(0), Colors.green),
                      const SizedBox(width: 8),
                      _quickStat('TXN', '${r.totalTransactions}', Colors.blue),
                      const SizedBox(width: 8),
                      _quickStat('Voids', '${r.voidedCount}', Colors.red),
                      const SizedBox(width: 8),
                      _quickStat(
                        r.overShort == 0 ? 'Balanced' : r.overShort > 0 ? 'Over' : 'Short',
                        r.overShort.abs().toStringAsFixed(0),
                        r.overShort == 0 ? Colors.green : r.overShort > 0 ? Colors.blue : Colors.red),
                    ]),
                  ])),
                ),

                // Expanded details
                if (isExpanded) ...[
                  const Divider(height: 1),
                  Container(
                    color: Colors.grey[50],
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Sales
                      _detailSection('Sales Summary', [
                        _detailRow('Gross Sales', r.grossSales.toStringAsFixed(2)),
                        _detailRow('Discounts', '-${r.totalDiscount.toStringAsFixed(2)}', Colors.red),
                        _detailRow("VATable Sales", (r.netSales / 1.12).toStringAsFixed(2), null),
                        _detailRow("VAT (12%)", (r.netSales - r.netSales / 1.12).toStringAsFixed(2), Colors.purple),
                        _detailRow("VAT-Exempt Sales", "0.00", null),
                        _detailRow("Zero-Rated Sales", "0.00", null),
                        _detailRow('Net Sales', r.netSales.toStringAsFixed(2), Colors.green[800]),
                        _detailRow('Avg/TXN', r.averageTransaction.toStringAsFixed(2)),
                      ]),
                      const SizedBox(height: 12),

                      // Payment
                      _detailSection('Payment Breakdown',
                        r.paymentBreakdown.map((p) =>
                          _detailRow('${p.method} (${p.count})', p.total.toStringAsFixed(2))).toList()),
                      const SizedBox(height: 12),

                      // Cash count
                      _detailSection('Cash Count', [
                        _detailRow('Beginning', r.beginningCash.toStringAsFixed(2)),
                        _detailRow('Expected', r.expectedCash.toStringAsFixed(2)),
                        _detailRow('Ending', r.endingCash.toStringAsFixed(2)),
                        _detailRow('Over/Short', r.overShort.toStringAsFixed(2),
                          r.overShort == 0 ? Colors.green : r.overShort > 0 ? Colors.blue : Colors.red),
                      ]),
                      const SizedBox(height: 12),


                      // Generated info
                      Text('Generated: ${_formatDate(r.generatedAt)} ${_formatTime(r.generatedAt)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      const SizedBox(height: 10),

                      // Export button
                      // 🔄 Re-Declare button (only today's Z Report)
                      if (_isSameDay(r.reportDate, DateTime.now())) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final username = await ManagerPinDialog.verify(
                                context,
                                title: "🔄 Re-Declare Cash Count",
                                actionLabel: "Re-declare cash for " + r.reportId + " (reason required)",
                              );
                              if (username != null && context.mounted) {
                                await _showHistoryDenominationDialog(
                                  r,
                                  username,
                                  "Manager-authorized recount for " + r.reportId,
                                );
                              }
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text("🔄 Re-Declare (Manager PIN)",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(children: [
                        Expanded(child: ElevatedButton.icon(
                          onPressed: () async { final denomMap = await DatabaseHelper().getDenominationMapForSession(r.reportId); await ZReportPdf.printFromRecord(r, denominations: denomMap); },
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Print / PDF', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[700], foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        )),
                      ]),
                    ]),
                  ),
                ],
              ]),
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
