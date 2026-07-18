// lib/screens/cashiering/hold_receipt_screen.dart
// v1.0.73+159 - HOLD Receipt PDF with Code128 barcode (v153)
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/held_transaction_model.dart';

class HoldReceiptScreen extends StatefulWidget {
  final HeldTransaction held;
  const HoldReceiptScreen({super.key, required this.held});

  @override
  State<HoldReceiptScreen> createState() => _HoldReceiptScreenState();
}

class _HoldReceiptScreenState extends State<HoldReceiptScreen> {
  bool _busy = false;
  bool _autoPrinted = false;

  @override
  void initState() {
    super.initState();
    // v153 Q2=B: Auto-print immediately after generation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_autoPrinted) {
        _autoPrinted = true;
        _print();
      }
    });
  }

  Future<pw.Document> _buildPdf() async {
    final pdf = pw.Document();
    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontItalic = pw.Font.helveticaOblique();

    // Purple theme for HOLD receipts
    final titleStyle = pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.purple800);
    final hldNumStyle = pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.purple900);
    final subtitleStyle = pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey700);
    final labelStyle = pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey700);
    final valueStyle = pw.TextStyle(font: fontRegular, fontSize: 8);
    final valueBoldStyle = pw.TextStyle(font: fontBold, fontSize: 8);
    final itemStyle = pw.TextStyle(font: fontRegular, fontSize: 8);
    final totalStyle = pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.purple800);
    final warningStyle = pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.red700);
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

    final h = widget.held;
    final heldDate = h.heldAt.toString().substring(0, 16);

    List<pw.Widget> itemRows = [];
    for (final item in h.items) {
      final lineTotal = item.product.sellingPrice * item.quantity;
      itemRows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 5, child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(item.product.name, style: itemStyle, maxLines: 2),
                  pw.Text('SKU: ' + item.product.sku, style: subtitleStyle),
                ],
              )),
              pw.Expanded(flex: 3, child: pw.Text(
                item.quantity.toString() + ' x ' + item.product.sellingPrice.toStringAsFixed(2),
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
            pw.Center(child: pw.Text('*** HOLD RECEIPT ***', style: titleStyle)),
            divider(),
            // HLD number - BIG display
            pw.Center(child: pw.Text(h.heldNumber, style: hldNumStyle)),
            pw.SizedBox(height: 6),
            // CODE128 BARCODE
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: h.heldNumber,
                width: 180,
                height: 40,
                drawText: false,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Center(child: pw.Text(h.heldNumber, style: subtitleStyle)),
            divider(),
            kv('Date:', heldDate),
            kv('Cashier:', h.cashierName.isNotEmpty ? h.cashierName : h.cashierId),
            kv('Branch:', h.branch),
            if (h.customerName.isNotEmpty) kv('Customer:', h.customerName, bold: true),
            if (h.note.isNotEmpty) kv('Note:', h.note),
            divider(),
            pw.Text('ITEMS ON HOLD', style: valueBoldStyle),
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
                pw.Text('TOTAL (HOLD)', style: totalStyle),
                pw.Text('PHP ' + h.total.toStringAsFixed(2), style: totalStyle),
              ],
            ),
            divider(),
            pw.SizedBox(height: 4),
            // Warning box
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                border: pw.Border.all(color: PdfColors.red300, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('!!! IMPORTANT !!!', style: warningStyle),
                  pw.SizedBox(height: 2),
                  pw.Text('Please keep this receipt.', style: subtitleStyle, textAlign: pw.TextAlign.center),
                  pw.Text('Present at counter to resume purchase.', style: subtitleStyle, textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 3),
                  pw.Text('Valid TODAY ONLY', style: warningStyle),
                  pw.Text('(Expires at store closing)', style: subtitleStyle, textAlign: pw.TextAlign.center),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Customer Signature: ______________', style: subtitleStyle),
            pw.SizedBox(height: 10),
            pw.Text('Cashier Signature: ______________', style: subtitleStyle),
            pw.SizedBox(height: 8),
            divider(),
            pw.Center(child: pw.Text('This is NOT an official receipt', style: footerStyle)),
            pw.Center(child: pw.Text('Customer copy only', style: subtitleStyle)),
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
      await Printing.sharePdf(bytes: bytes, filename: widget.held.heldNumber + '.pdf');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved: ' + widget.held.heldNumber + '.pdf'), backgroundColor: Colors.green),
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
    final h = widget.held;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hold Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple[700],
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
            pdfFileName: h.heldNumber + '.pdf',
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
                Text(h.heldNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('PHP ' + h.total.toStringAsFixed(2),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.purple[700])),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _print,
                  icon: const Icon(Icons.print),
                  label: const Text('PRINT AGAIN'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple[700],
                    side: BorderSide(color: Colors.purple[700]!),
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
