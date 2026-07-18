// lib/screens/cashiering/exchange_receipt_screen.dart
// v1.0.69+155 - Exchange Receipt PDF (v151.2, mirrors refund receipt)
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/exchange_model.dart';

class ExchangeReceiptScreen extends StatefulWidget {
  final Exchange exchange;
  final List<Map<String, dynamic>> returnedItems;
  final List<Map<String, dynamic>> takenItems;
  final double cashReceived;
  final double changeGiven;

  const ExchangeReceiptScreen({
    super.key,
    required this.exchange,
    required this.returnedItems,
    required this.takenItems,
    this.cashReceived = 0,
    this.changeGiven = 0,
  });

  @override
  State<ExchangeReceiptScreen> createState() => _ExchangeReceiptScreenState();
}

class _ExchangeReceiptScreenState extends State<ExchangeReceiptScreen> {
  bool _busy = false;

  Future<pw.Document> _buildPdf() async {
    final pdf = pw.Document();
    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontItalic = pw.Font.helveticaOblique();

    final titleStyle = pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.orange800);
    final subtitleStyle = pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey700);
    final labelStyle = pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey700);
    final valueStyle = pw.TextStyle(font: fontRegular, fontSize: 8);
    final valueBoldStyle = pw.TextStyle(font: fontBold, fontSize: 8);
    final itemStyle = pw.TextStyle(font: fontRegular, fontSize: 8);
    final totalStyle = pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.orange800);
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

    final exc = widget.exchange;

    List<pw.Widget> returnedRows = [];
    double returnedTotal = 0;
    for (final item in widget.returnedItems) {
      final name = (item['name'] ?? '').toString();
      final sku = (item['sku'] ?? '').toString();
      final qty = (item['qty'] ?? 0) as int;
      final price = ((item['price'] ?? 0) as num).toDouble();
      final reason = (item['reason'] ?? '').toString();
      final lineTotal = price * qty;
      returnedTotal += lineTotal;
      returnedRows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 5, child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(name, style: itemStyle, maxLines: 2),
                  pw.Text('SKU: ' + sku, style: subtitleStyle),
                  if (reason.isNotEmpty) pw.Text('Reason: ' + reason, style: subtitleStyle),
                ],
              )),
              pw.Expanded(flex: 3, child: pw.Text(
                qty.toString() + ' x ' + price.toStringAsFixed(2),
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

    List<pw.Widget> takenRows = [];
    double takenTotal = 0;
    for (final item in widget.takenItems) {
      final name = (item['name'] ?? '').toString();
      final sku = (item['sku'] ?? '').toString();
      final qty = (item['qty'] ?? 0) as int;
      final price = ((item['price'] ?? 0) as num).toDouble();
      final lineTotal = price * qty;
      takenTotal += lineTotal;
      takenRows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 5, child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(name, style: itemStyle, maxLines: 2),
                  pw.Text('SKU: ' + sku, style: subtitleStyle),
                ],
              )),
              pw.Expanded(flex: 3, child: pw.Text(
                qty.toString() + ' x ' + price.toStringAsFixed(2),
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

    final diffLabel = exc.priceDifference >= 0 ? 'Customer Owes' : 'Refund to Customer';
    final diffValue = 'PHP ' + exc.priceDifference.abs().toStringAsFixed(2);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80.copyWith(marginTop: 20, marginBottom: 20, marginLeft: 12, marginRight: 12),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(child: pw.Text('FLAV POS', style: titleStyle)),
            pw.SizedBox(height: 2),
            pw.Center(child: pw.Text('EXCHANGE RECEIPT', style: titleStyle)),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('*** OFFICIAL EXCHANGE ***', style: subtitleStyle)),
            divider(),
            kv('Exchange #:', exc.exchangeNumber, bold: true),
            kv('Exchange Date:', exc.exchangeDate),
            kv('Branch:', exc.branch),
            divider(),
            pw.Text('ORIGINAL TRANSACTION', style: valueBoldStyle),
            pw.SizedBox(height: 2),
            kv('Receipt #:', exc.originalTxnId),
            divider(),
            pw.Text('ITEMS RETURNED', style: valueBoldStyle),
            pw.SizedBox(height: 2),
            pw.Row(children: [
              pw.Expanded(flex: 5, child: pw.Text('Item', style: subtitleStyle)),
              pw.Expanded(flex: 3, child: pw.Text('Qty x Price', style: subtitleStyle, textAlign: pw.TextAlign.center)),
              pw.Expanded(flex: 2, child: pw.Text('Total', style: subtitleStyle, textAlign: pw.TextAlign.right)),
            ]),
            pw.SizedBox(height: 2),
            ...returnedRows,
            pw.SizedBox(height: 2),
            kv('Returned Total:', 'PHP ' + returnedTotal.toStringAsFixed(2), bold: true),
            divider(),
            pw.Text('ITEMS TAKEN', style: valueBoldStyle),
            pw.SizedBox(height: 2),
            pw.Row(children: [
              pw.Expanded(flex: 5, child: pw.Text('Item', style: subtitleStyle)),
              pw.Expanded(flex: 3, child: pw.Text('Qty x Price', style: subtitleStyle, textAlign: pw.TextAlign.center)),
              pw.Expanded(flex: 2, child: pw.Text('Total', style: subtitleStyle, textAlign: pw.TextAlign.right)),
            ]),
            pw.SizedBox(height: 2),
            ...takenRows,
            pw.SizedBox(height: 2),
            kv('Taken Total:', 'PHP ' + takenTotal.toStringAsFixed(2), bold: true),
            divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(diffLabel, style: totalStyle),
                pw.Text(diffValue, style: totalStyle),
              ],
            ),
            if (widget.cashReceived > 0) ...[
              pw.SizedBox(height: 4),
              kv('Cash Received:', 'PHP ' + widget.cashReceived.toStringAsFixed(2)),
              if (widget.changeGiven > 0)
                kv('Change:', 'PHP ' + widget.changeGiven.toStringAsFixed(2), bold: true),
            ],
            divider(),
            kv('Reason:', exc.reason),
            kv('Processed By:', exc.processedBy),
            kv('Approved By:', exc.approvedBy),
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
      await Printing.sharePdf(bytes: bytes, filename: widget.exchange.exchangeNumber + '.pdf');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved: ' + widget.exchange.exchangeNumber + '.pdf'), backgroundColor: Colors.green),
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
        title: const Text('Exchange Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange[700],
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
            pdfFileName: widget.exchange.exchangeNumber + '.pdf',
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
                Text('Exchange #: ' + widget.exchange.exchangeNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text((widget.exchange.priceDifference >= 0 ? '+' : '-') + 'PHP ' + widget.exchange.priceDifference.abs().toStringAsFixed(2),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange[700])),
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
                    foregroundColor: Colors.orange[700],
                    side: BorderSide(color: Colors.orange[700]!),
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
