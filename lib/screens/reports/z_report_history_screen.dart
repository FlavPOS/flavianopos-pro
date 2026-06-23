// lib/screens/reports/z_report_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/z_report_model.dart';
import '../../utils/z_report_pdf.dart';

class ZReportHistoryScreen extends StatefulWidget {
  final String branch;
  const ZReportHistoryScreen({super.key, required this.branch});
  @override
  State<ZReportHistoryScreen> createState() => _ZReportHistoryScreenState();
}

class _ZReportHistoryScreenState extends State<ZReportHistoryScreen> {
  String? _expandedId;

  String _formatDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';
  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  Future<void> _exportCSV(ZReportRecord r) async {
    final buf = StringBuffer();
    buf.writeln('Z REPORT - ${r.reportId}');
    buf.writeln('Date,${_formatDate(r.reportDate)}');
    buf.writeln('Branch,${r.branch}');
    buf.writeln('Cashier,${r.cashier}');
    buf.writeln('Generated,${_formatDate(r.generatedAt)} ${_formatTime(r.generatedAt)}');
    buf.writeln('');
    buf.writeln('SALES SUMMARY');
    buf.writeln('Gross Sales,${r.grossSales.toStringAsFixed(2)}');
    buf.writeln('Discounts,${r.totalDiscount.toStringAsFixed(2)}');
    buf.writeln('Net Sales,${r.netSales.toStringAsFixed(2)}');
    buf.writeln('Transactions,${r.totalTransactions}');
    buf.writeln('Average/TXN,${r.averageTransaction.toStringAsFixed(2)}');
    buf.writeln('');
    buf.writeln('PAYMENT BREAKDOWN');
    for (final p in r.paymentBreakdown) {
      buf.writeln('${p.method},${p.count},${p.total.toStringAsFixed(2)}');
    }
    buf.writeln('');
    buf.writeln('CASH COUNT');
    buf.writeln('Beginning Cash,${r.beginningCash.toStringAsFixed(2)}');
    buf.writeln('Expected Cash,${r.expectedCash.toStringAsFixed(2)}');
    buf.writeln('Ending Cash,${r.endingCash.toStringAsFixed(2)}');
    buf.writeln('Over/Short,${r.overShort.toStringAsFixed(2)}');
    buf.writeln('');
    buf.writeln('VOIDS');
    buf.writeln('Count,${r.voidedCount}');
    buf.writeln('Amount,${r.voidedAmount.toStringAsFixed(2)}');
    buf.writeln('');
    buf.writeln('TRANSACTIONS');
    buf.writeln('TXN ID,Time,Payment,Amount,Status');
    for (final t in r.transactionLog) {
      buf.writeln('${t.txnId},${t.dateTime.hour}:${t.dateTime.minute.toString().padLeft(2, '0')},${t.paymentMethod},${t.amount.toStringAsFixed(2)},${t.status}');
    }

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${r.reportId} CSV copied!'), behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = ZReportRecord.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Z Report History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple[700], foregroundColor: Colors.white,
      ),
      body: reports.isEmpty
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
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: () => _exportCSV(r),
                          icon: const Icon(Icons.table_chart, size: 16),
                          label: const Text('CSV', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton.icon(
                          onPressed: () => ZReportPdf.printFromRecord(r),
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
}
