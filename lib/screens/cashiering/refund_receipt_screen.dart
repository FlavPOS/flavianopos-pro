// lib/screens/cashiering/refund_receipt_screen.dart
// v1.0.66+151 - Refund Receipt PDF (v150b)
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/transaction_model.dart';

class RefundReceiptScreen extends StatefulWidget {
  final Transaction originalTransaction;
  final List<TransactionItem> refundedItems;
  final Map<int, int> refundQuantities;
  final double refundTotal;
  final String refundReason;
  final String approvedBy;
  final String refundNumber;
  final DateTime refundDateTime;

  const RefundReceiptScreen({
    super.key,
    required this.originalTransaction,
    required this.refundedItems,
    required this.refundQuantities,
    required this.refundTotal,
    required this.refundReason,
    required this.approvedBy,
    required this.refundNumber,
    required this.refundDateTime,
  });

  @override
  State<RefundReceiptScreen> createState() => _RefundReceiptScreenState();
}

class _RefundReceiptScreenState extends State<RefundReceiptScreen> {
  bool _busy = false;

  Future<pw.Document> _buildPdf() async {
    final pdf = pw.Document();
    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontItalic = pw.Font.helveticaOblique();

    final titleStyle = pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.red800);
    final subtitleStyle = pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey700);
    final labelStyle = pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey700);
    final valueStyle = pw.TextStyle(font: fontRegular, fontSize: 8);
    final valueBoldStyle = pw.TextStyle(font: fontBold, fontSize: 8);
    final itemStyle = pw.TextStyle(font: fontRegular, fontSize: 8);
    final totalStyle = pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.red800);
    final footerStyle = pw.TextStyle(font: fontItalic, fontSize: 8, color: PdfColors.grey600);

    pw.Widget kv(String k, String v, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(k, style: labelStyle),
            pw.Text(v, style: bold ? valueBoldStyle : valueStyle),
          ],
        ),
      );
    }

    pw.Widget divider() {
      return pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 4),
        height: 0.5,
        color: PdfColors.grey400,
      );
    }

    final txn = widget.originalTransaction;
    final origDate = txn.dateTime.toString().substring(0, 16);
    final refDate = widget.refundDateTime.toString().substring(0, 16);

    List<pw.Widget> itemRows = [];
    for (int i = 0; i < widget.refundedItems.length; i++) {
      final it = widget.refundedItems[i];
      final q = widget.refundQuantities[i] ?? 0;
      if (q <= 0) continue;
      final lineTotal = it.price * q;
      itemRows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 5, child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(it.name, style: itemStyle, maxLines: 2),
                  pw.Text('SKU: ' + it.sku, style: subtitleStyle),
                ],
              )),
              pw.Expanded(flex: 3, child: pw.Text(
                q.toString() + ' x ' + it.price.toStringAsFixed(2),
                style: subtitleStyle, textAlign: pw.TextAlign.center,
              )),
              pw.Expanded(flex: 2, child: pw.Text(
                lineTotal.toStringAsFixed(2),
                style: itemStyle, textAlign: pw.TextAlign.right,
              )),
            ],
          ),
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80.copyWith(marginTop: 20, marginBottom: 20, marginLeft: 12, marginRight: 12),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(child: pw.Text('FLAV POS', style: titleStyle)),
            pw.SizedBox(height: 2),
            pw.Center(child: pw.Text('REFUND RECEIPT', style: titleStyle)),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('*** OFFICIAL REFUND ***', style: subtitleStyle)),
            divider(),
            kv('Refund #:', widget.refundNumber, bold: true),
            kv('Refund Date:', refDate),
            kv('Branch:', txn.branch),
            divider(),
            pw.Text('ORIGINAL TRANSACTION', style: valueBoldStyle),
            pw.SizedBox(height: 2),
            kv('Receipt #:', txn.id),
            kv('Date:', origDate),
            kv('Cashier:', txn.cashier),
            kv('Total:', 'PHP ' + txn.total.toStringAsFixed(2)),
            kv('Payment:', txn.paymentMethod),
            divider(),
            pw.Text('ITEMS REFUNDED', style: valueBoldStyle),
            pw.SizedBox(height: 2),
            pw.Row(children: [
              pw.Expanded(flex: 5, child: pw.Text('Item', style: subtitleStyle)),
              pw.Expanded(flex: 3, child: pw.Text('Qty x Price', style: subtitleStyle, textAlign: pw.TextAlign.center)),
              pw.Expanded(flex: 2, child: pw.Text('Total', style: subtitleStyle, textAlign: pw.TextAlign.right)),
            ]),
            pw.SizedBox(height: 2),
            ...itemRows,
            divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL REFUND', style: totalStyle),
                pw.Text('PHP ' + widget.refundTotal.toStringAsFixed(2), style: totalStyle),
              ],
            ),
            divider(),
            kv('Refund Method:', txn.paymentMethod, bold: true),
            kv('Reason:', widget.refundReason),
            kv('Approved By:', widget.approvedBy),
            divider(),
            pw.SizedBox(height: 6),
            pw.Center(child: pw.Text('Customer Signature: ______________', style: subtitleStyle)),
            pw.SizedBox(height: 12),
            pw.Center(child: pw.Text('Cashier Signature: ______________', style: subtitleStyle)),
            pw.SizedBox(height: 12),
            divider(),
            pw.Center(child: pw.Text('Keep this receipt for your records', style: footerStyle)),
            pw.Center(child: pw.Text('THIS IS NOT AN OFFICIAL RECEIPT', style: subtitleStyle)),
          ],
        ),
      ),
    );
    return pdf;
  }

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      final pdf = await _buildPdf();
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: ' + e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePdf() async {
    setState(() => _busy = true);
    try {
      final pdf = await _buildPdf();
      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: widget.refundNumber + '.pdf');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved: ' + widget.refundNumber + '.pdf'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: ' + e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Refund Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Column(children: [
        Expanded(
          child: PdfPreview(
            build: (format) async => (await _buildPdf()).save(),
            allowPrinting: false,
            allowSharing: false,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            pdfFileName: widget.refundNumber + '.pdf',
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, -2))],
          ),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Refund #: ' + widget.refundNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('PHP ' + widget.refundTotal.toStringAsFixed(2),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red[700])),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _print,
                  icon: const Icon(Icons.print),
                  label: const Text('PRINT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    side: BorderSide(color: Colors.red[700]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _savePdf,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('SAVE PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    side: BorderSide(color: Colors.blue[700]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('DONE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
