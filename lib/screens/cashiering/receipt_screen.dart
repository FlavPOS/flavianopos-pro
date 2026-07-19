// lib/screens/cashiering/receipt_screen.dart
import '../../models/settings_model.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/cart_item_model.dart';

class ReceiptScreen extends StatefulWidget {
  final List<CartItem> items;
  final double totalAmount;
  final double totalDiscount;
  final String paymentMethod;
  // v159c: Payment audit trail
  final String paymentReference;
  final String bankName;
  final double amountPaid;
  final double change;
  final String transactionId;
  final String branch;
  final String cashier;
  final DateTime dateTime;

  const ReceiptScreen({
    super.key, required this.items, required this.totalAmount,
    required this.totalDiscount, required this.paymentMethod, this.paymentReference = '', this.bankName = '',
    required this.amountPaid, required this.change,
    required this.transactionId, required this.branch,
    required this.cashier, required this.dateTime,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _isSavingPdf = false;

  @override
  void initState() {
    super.initState();
    if (AppSettings.autoPrintReceipt) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _saveReceiptAsPdf());
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${_formatTime(dt)}';
  }

  String _formatDateForFile(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  int get _totalQty => widget.items.fold(0, (s, i) => s + i.quantity);

  double get _vatAmount {
    final vatableAmount = widget.totalAmount / 1.12;
    return widget.totalAmount - vatableAmount;
  }

  // ────────────────────────────────────────────────────────────
  // SAVE RECEIPT AS PDF
  // ────────────────────────────────────────────────────────────
  Future<void> _saveReceiptAsPdf() async {
    setState(() => _isSavingPdf = true);

    try {
      final pdf = pw.Document();
      final fontRegular = pw.Font.helvetica();
      final fontBold = pw.Font.helveticaBold();
      final fontItalic = pw.Font.helveticaOblique();

      // Styles
      final titleStyle = pw.TextStyle(font: fontBold, fontSize: 14);
      final addressStyle = pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey700);
      final tinStyle = pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey500);
      final labelStyle = pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey700);
      final valueStyle = pw.TextStyle(font: fontRegular, fontSize: 8);
      final valueBoldStyle = pw.TextStyle(font: fontBold, fontSize: 8);
      final headerStyle = pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.grey600);
      final itemNameStyle = pw.TextStyle(font: fontRegular, fontSize: 8);
      final itemDetailStyle = pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey600);
      final itemTotalStyle = pw.TextStyle(font: fontRegular, fontSize: 8);
      final discountStyle = pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.red);
      final totalLabelStyle = pw.TextStyle(font: fontBold, fontSize: 14);
      final totalValueStyle = pw.TextStyle(font: fontBold, fontSize: 14);
      final thankStyle = pw.TextStyle(font: fontItalic, fontSize: 9);
      final comeAgainStyle = pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500);
      final barcodeTextStyle = pw.TextStyle(font: fontRegular, fontSize: 6, color: PdfColors.grey400);

      // Helper: left-right info row
      pw.Widget pdfInfoRow(String label, String value, {bool bold = false, bool red = false}) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: red ? discountStyle : labelStyle),
              pw.Text(value, style: bold ? valueBoldStyle : (red ? discountStyle : valueStyle)),
            ],
          ),
        );
      }

      // Helper: dotted divider
      pw.Widget pdfDivider() {
        return pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            children: List.generate(60, (i) => pw.Expanded(
              child: pw.Container(
                height: 0.5,
                color: i.isEven ? PdfColors.grey400 : PdfColors.white,
              ),
            )),
          ),
        );
      }

      // Build item rows
      List<pw.Widget> itemRows = [];
      for (final item in widget.items) {
        itemRows.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Text(item.product.name, style: itemNameStyle, maxLines: 2),
                ),
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    '${item.quantity} x ${item.product.sellingPrice.toStringAsFixed(2)}',
                    style: itemDetailStyle,
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    item.subtotal.toStringAsFixed(2),
                    style: itemTotalStyle,
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        );

        // Item discount row
        if (item.discountAmount > 0) {
          itemRows.add(
            pw.Row(
              children: [
                pw.Expanded(flex: 5, child: pw.SizedBox()),
                pw.Expanded(
                  flex: 5,
                  child: pw.Text(
                    '  Disc: -${item.discountAmount.toStringAsFixed(2)}',
                    style: discountStyle,
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }
      }

      // Receipt page format: 80mm width, auto height
      const double receiptWidth = 226; // 80mm in points
      // Estimate height based on items
      final double estimatedHeight = 500 + (widget.items.length * 30);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(receiptWidth, estimatedHeight, marginAll: 12),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Store icon placeholder
                pw.Icon(const pw.IconData(0xe8d1), size: 24, color: PdfColors.grey),
                pw.SizedBox(height: 4),

                // Store name
                pw.Text('FlavianoPOS Store', style: titleStyle, textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 2),
                pw.Text('Diversion Road, Consolacion, Cebu', style: addressStyle, textAlign: pw.TextAlign.center),
                pw.Text('${AppSettings.vatRegStatus} TIN: ${AppSettings.businessTin.replaceAll('TIN: ', '')}', style: tinStyle, textAlign: pw.TextAlign.center),
                // v160b: BIR compliance header
                if (AppSettings.birPermitNumber.isNotEmpty)
                  pw.Text('BIR Permit No: ${AppSettings.birPermitNumber}', style: tinStyle, textAlign: pw.TextAlign.center),
                if (AppSettings.terminalSN.isNotEmpty)
                  pw.Text('Terminal SN: ${AppSettings.terminalSN}', style: tinStyle, textAlign: pw.TextAlign.center),
                if (AppSettings.machineIdentNumber.isNotEmpty)
                  pw.Text('MIN: ${AppSettings.machineIdentNumber}', style: tinStyle, textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 4),

                // Divider
                pdfDivider(),

                // Transaction info
                pdfInfoRow('Date:', _formatDate(widget.dateTime)),
                pdfInfoRow('Cashier:', widget.cashier),
                pdfInfoRow('Branch:', widget.branch),
                pdfInfoRow('TXN #:', widget.transactionId),
                pw.SizedBox(height: 2),

                // Divider
                pdfDivider(),

                // Item header
                pw.Row(
                  children: [
                    pw.Expanded(flex: 5, child: pw.Text('Item', style: headerStyle)),
                    pw.Expanded(flex: 3, child: pw.Text('Qty x Price', style: headerStyle, textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 2, child: pw.Text('Total', style: headerStyle, textAlign: pw.TextAlign.right)),
                  ],
                ),
                pw.SizedBox(height: 4),

                // Items
                ...itemRows,
                pw.SizedBox(height: 2),

                // Divider
                pdfDivider(),

                // Summary
                pdfInfoRow('Items:', '$_totalQty'),
                pdfInfoRow('Subtotal:', (widget.totalAmount + widget.totalDiscount).toStringAsFixed(2)),
                if (widget.totalDiscount > 0)
                  pdfInfoRow('Discount:', '-${widget.totalDiscount.toStringAsFixed(2)}', red: true),
                pdfInfoRow('VAT (${AppSettings.vatRate.toStringAsFixed(0)}%) incl:', _vatAmount.toStringAsFixed(2)),
                pw.SizedBox(height: 4),

                // Divider
                pdfDivider(),

                // TOTAL
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL', style: totalLabelStyle),
                    pw.Text(widget.totalAmount.toStringAsFixed(2), style: totalValueStyle),
                  ],
                ),
                pw.SizedBox(height: 4),

                // Divider
                pdfDivider(),

                // Payment info
                pdfInfoRow('Payment:', widget.paymentMethod),
                if (widget.bankName.isNotEmpty)
                  pdfInfoRow('Bank:', widget.bankName),
                if (widget.paymentReference.isNotEmpty)
                  pdfInfoRow('Reference:', widget.paymentReference),
                pdfInfoRow('Paid:', widget.amountPaid.toStringAsFixed(2)),
                pdfInfoRow('Change:', widget.change.toStringAsFixed(2), bold: true),
                pw.SizedBox(height: 6),

                // Divider
                pdfDivider(),

                // Thank you
                pw.SizedBox(height: 8),
                // v160b: Store Policy
                if (AppSettings.showStorePolicy && AppSettings.storePolicy.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('STORE POLICY:', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                        pw.SizedBox(height: 3),
                        pw.Text(AppSettings.storePolicy, style: pw.TextStyle(font: fontRegular, fontSize: 7)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),
                ],

                // v160b: OFFICIAL RECEIPT notice
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1),
                  ),
                  child: pw.Text(
                    AppSettings.officialReceiptNotice,
                    style: pw.TextStyle(font: fontBold, fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 10),

                // v160b: Signature lines
                if (AppSettings.showSignatureLines) ...[
                  pw.Text('Customer Signature: ______________________',
                    style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                  pw.SizedBox(height: 10),
                  pw.Text('Cashier Signature: _______________________',
                    style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                  pw.SizedBox(height: 8),
                ],

                pw.Text('Thank you for shopping with us!', style: thankStyle, textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 2),
                pw.Text('Please come again!', style: comeAgainStyle, textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 12),

                // Barcode placeholder
                pw.Container(
                  height: 25,
                  width: 140,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Center(
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: widget.transactionId,
                      width: 130,
                      height: 20,
                      drawText: false,
                    ),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(widget.transactionId, style: barcodeTextStyle, textAlign: pw.TextAlign.center),
              ],
            );
          },
        ),
      );

      // Generate and share/save PDF
      final bytes = await pdf.save();
      final fileName = 'FlavianoPOS_Receipt_${widget.transactionId}_${_formatDateForFile(widget.dateTime)}.pdf';

      await Printing.sharePdf(bytes: bytes, filename: fileName);

      if (mounted) {
        _snack(context, 'Receipt saved as PDF!');
      }
    } catch (e) {
      if (mounted) {
        _snack(context, 'Failed to save PDF: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700], foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
      body: Column(children: [
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(child: Container(
            width: 340,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const Icon(Icons.store, size: 36, color: Colors.grey),
              const SizedBox(height: 4),
              const Text('FlavianoPOS Store', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('Diversion Road, Consolacion, Cebu', style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  textAlign: TextAlign.center),
              Text('${AppSettings.vatRegStatus} TIN: ${AppSettings.businessTin.replaceAll('TIN: ', '')}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              // v160b: BIR compliance header
              if (AppSettings.birPermitNumber.isNotEmpty)
                Text('BIR Permit No: ${AppSettings.birPermitNumber}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              if (AppSettings.terminalSN.isNotEmpty)
                Text('Terminal SN: ${AppSettings.terminalSN}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              if (AppSettings.machineIdentNumber.isNotEmpty)
                Text('MIN: ${AppSettings.machineIdentNumber}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              const SizedBox(height: 8),
              _dottedLine(),
              const SizedBox(height: 8),
              _infoRow('Date:', '${widget.dateTime.month}/${widget.dateTime.day}/${widget.dateTime.year} ${_formatTime(widget.dateTime)}'),
              _infoRow('Cashier:', widget.cashier),
              _infoRow('Branch:', widget.branch),
              _infoRow('TXN #:', widget.transactionId),
              const SizedBox(height: 8),
              _dottedLine(),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(flex: 5, child: Text('Item', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                Expanded(flex: 3, child: Text('Qty x Price', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600]), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('Total', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600]), textAlign: TextAlign.right)),
              ]),
              const SizedBox(height: 6),
              ...widget.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(children: [
                  Row(children: [
                    Expanded(flex: 5, child: Text(item.product.name, style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 3, child: Text('${item.quantity} x ${item.product.sellingPrice.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text(item.subtotal.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
                  ]),
                  if (item.discountAmount > 0)
                    Row(children: [
                      const Expanded(flex: 5, child: SizedBox()),
                      Expanded(flex: 5, child: Text(
                          '  Disc: -${item.discountAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 10, color: Colors.red), textAlign: TextAlign.right)),
                    ]),
                ]),
              )),
              const SizedBox(height: 8),
              _dottedLine(),
              const SizedBox(height: 8),
              _infoRow('Items:', '$_totalQty'),
              _infoRow('Subtotal:', (widget.totalAmount + widget.totalDiscount).toStringAsFixed(2)),
              if (widget.totalDiscount > 0)
                _infoRow('Discount:', '-${widget.totalDiscount.toStringAsFixed(2)}', isRed: true),
              _infoRow('VAT (${AppSettings.vatRate.toStringAsFixed(0)}%) incl:', _vatAmount.toStringAsFixed(2)),
              const SizedBox(height: 4),
              _dottedLine(),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('TOTAL', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(widget.totalAmount.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 10),
              _dottedLine(),
              const SizedBox(height: 8),
              _infoRow('Payment:', widget.paymentMethod),
              if (widget.bankName.isNotEmpty)
                _infoRow('Bank:', widget.bankName),
              if (widget.paymentReference.isNotEmpty)
                _infoRow('Reference:', widget.paymentReference),
              _infoRow('Paid:', widget.amountPaid.toStringAsFixed(2)),
              _infoRow('Change:', widget.change.toStringAsFixed(2), isBold: true),
              const SizedBox(height: 12),
              _dottedLine(),
              const SizedBox(height: 16),
              // v160b: Store Policy
              if (AppSettings.showStorePolicy && AppSettings.storePolicy.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STORE POLICY:',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      Text(AppSettings.storePolicy,
                        style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // v160b: OFFICIAL RECEIPT notice
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Text(
                  AppSettings.officialReceiptNotice,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),

              // v160b: Signature lines
              if (AppSettings.showSignatureLines) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Customer Signature: ______________________',
                    style: TextStyle(fontSize: 10)),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Cashier Signature:  ______________________',
                    style: TextStyle(fontSize: 10)),
                ),
                const SizedBox(height: 12),
              ],

              const Text('Thank you for shopping with us!',
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Please come again!', style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Container(height: 35, width: 180,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                child: const Center(child: Text('|||| |||| |||| |||| ||||',
                    style: TextStyle(letterSpacing: 1, fontSize: 14, fontWeight: FontWeight.bold)))),
              const SizedBox(height: 4),
              Text(widget.transactionId, style: TextStyle(fontSize: 9, color: Colors.grey[400])),
            ]),
          )),
        )),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8, offset: const Offset(0, -2))]),
          child: SafeArea(child: Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _snack(context, 'No printer detected. Configure in Settings > Printer Settings.'),
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Print', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: _isSavingPdf ? null : _saveReceiptAsPdf,
              icon: _isSavingPdf
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.picture_as_pdf, size: 18, color: Colors.red[700]),
              label: Text(_isSavingPdf ? 'Saving...' : 'Save PDF', style: const TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: const Text('New Sale', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
          ])),
        ),
      ]),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false, bool isRed = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 12, color: isRed ? Colors.red : Colors.grey[600])),
      Text(value, style: TextStyle(fontSize: 12,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: isRed ? Colors.red : Colors.black87)),
    ]));

  Widget _dottedLine() => Row(children: List.generate(50, (i) =>
      Expanded(child: Container(height: 1, color: i.isEven ? Colors.grey[300] : Colors.transparent))));

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }
}
