import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'adjustment_v3_model.dart';

class AdjustmentPdfGenerator {
  static const _red = PdfColor.fromInt(0xFFEF4444);
  static const _green = PdfColor.fromInt(0xFF22C55E);
  static const _blue = PdfColor.fromInt(0xFF3B82F6);
  static const _dark = PdfColor.fromInt(0xFF111827);
  static const _gray = PdfColor.fromInt(0xFF6B7280);
  static const _light = PdfColor.fromInt(0xFFF3F4F6);

  static String _thousands(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '${buf.toString()}.${parts[1]}';
  }

  static String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  static Future<Uint8List> generate({
    required AdjustmentV3 header,
    required List<AdjustmentV3Item> items,
    required String companyName,
  }) async {
    final doc = pw.Document();

    int totalQty = 0;
    double totalCost = 0;
    for (final i in items) {
      totalQty += i.qty;
      totalCost += i.qty * i.unitCost * i.direction;
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Stack(
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeader(header, companyName),
                pw.SizedBox(height: 12),
                _buildItemsTable(items),
                pw.SizedBox(height: 8),
                _buildTotals(items.length, totalQty, totalCost),
                pw.Spacer(),
                _buildSignatures(header),
                pw.SizedBox(height: 8),
                _buildFooter(header),
              ],
            ),
            if (header.status == 'APPROVED') _approvedStamp(),
            if (header.status == 'REJECTED') _rejectedStamp(),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader(AdjustmentV3 h, String company) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _light,
        border: pw.Border.all(color: _gray, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(company,
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: _dark)),
              pw.SizedBox(height: 3),
              pw.Text('Branch: ${h.branchCode}   ${h.branchName}',
                  style: const pw.TextStyle(fontSize: 10, color: _gray)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('INVENTORY ADJUSTMENT',
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: _dark)),
              pw.SizedBox(height: 3),
              pw.Text('Doc #: ${h.docNumber.isEmpty ? h.adjustmentId : h.docNumber}',
                  style: const pw.TextStyle(fontSize: 10, color: _gray)),
              pw.Text('Status: ${h.status}',
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _statusColor(h.status))),
            ],
          ),
        ],
      ),
    );
  }

  static PdfColor _statusColor(String status) {
    if (status == 'APPROVED') return _green;
    if (status == 'REJECTED') return _red;
    if (status == 'SUBMITTED') return _blue;
    return _gray;
  }

  static pw.Widget _buildItemsTable(List<AdjustmentV3Item> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: _gray, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(80),   // SKU
        1: const pw.FlexColumnWidth(3),      // Product
        2: const pw.FixedColumnWidth(60),   // Qty
        3: const pw.FixedColumnWidth(80),   // Cost
        4: const pw.FixedColumnWidth(50),   // Code
        5: const pw.FlexColumnWidth(2),      // Reason
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _light),
          children: [
            _headerCell('SKU'),
            _headerCell('Product'),
            _headerCell('Qty'),
            _headerCell('Cost'),
            _headerCell('Code'),
            _headerCell('Reason'),
          ],
        ),
        ...items.map((i) {
          final sign = i.direction < 0 ? '-' : '+';
          final qty = '$sign${i.qty}';
          final cost = i.qty * i.unitCost * i.direction;
          final costSign = cost < 0 ? '-' : (cost > 0 ? '+' : '');
          final costStr = '$costSign${_thousands(cost.abs())}';
          final color = i.direction < 0 ? _red : _green;
          return pw.TableRow(children: [
            _cell(i.sku),
            _cell(i.productName),
            _cellCentered(qty, color: color, bold: true),
            _cellRight(costStr, color: color, bold: true),
            _cellCentered(i.reasonCode),
            _cell(i.reasonName, color: color),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _headerCell(String text) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        alignment: pw.Alignment.center,
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold, color: _dark)),
      );

  static pw.Widget _cell(String text, {PdfColor? color}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 9, color: color ?? _dark)),
      );

  static pw.Widget _cellCentered(String text,
          {PdfColor? color, bool bold = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        alignment: pw.Alignment.center,
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9,
                color: color ?? _dark,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _cellRight(String text,
          {PdfColor? color, bool bold = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        alignment: pw.Alignment.centerRight,
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9,
                color: color ?? _dark,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _buildTotals(int itemCount, int totalQty, double totalCost) {
    final sign = totalCost >= 0 ? '+' : '-';
    final costColor = totalCost == 0
        ? _dark
        : (totalCost < 0 ? _red : _green);
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      color: _light,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text('Total:  $itemCount items  |  $totalQty pcs  |  ',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold, color: _dark)),
          pw.Text('$sign${_thousands(totalCost.abs())}',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold, color: costColor)),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatures(AdjustmentV3 h) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: _signatureBlock('PREPARED BY',
            h.createdByName, _formatDate(h.createdAt))),
        pw.SizedBox(width: 20),
        pw.Expanded(child: _signatureBlock(
            'APPROVED BY',
            h.approvedBy.isEmpty ? '________________' : h.approvedBy,
            h.approvedAt.isEmpty ? '' : _formatDate(h.approvedAt),
            role: h.approvedByRole)),
      ],
    );
  }

  static pw.Widget _signatureBlock(String label, String name, String date,
      {String role = ''}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          height: 24,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _dark, width: 0.5)),
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold, color: _dark)),
        pw.SizedBox(height: 2),
        pw.Text(name,
            style: const pw.TextStyle(fontSize: 10, color: _dark)),
        if (role.isNotEmpty)
          pw.Text('($role)',
              style: const pw.TextStyle(fontSize: 9, color: _gray)),
        if (date.isNotEmpty)
          pw.Text('Date: $date',
              style: const pw.TextStyle(fontSize: 9, color: _gray)),
      ],
    );
  }

  static pw.Widget _buildFooter(AdjustmentV3 h) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _gray, width: 0.3),
      ),
      child: pw.Row(
        children: [
          pw.Text('Notes: ',
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Expanded(
            child: pw.Text(h.notes.isEmpty ? '_' : h.notes,
                style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _approvedStamp() {
    return pw.Positioned(
      right: 60,
      bottom: 60,
      child: pw.Transform.rotate(
        angle: -0.15,
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _green, width: 3),
          ),
          child: pw.Text('APPROVED',
              style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: _green,
                  letterSpacing: 3)),
        ),
      ),
    );
  }

  static pw.Widget _rejectedStamp() {
    return pw.Positioned(
      right: 60,
      bottom: 60,
      child: pw.Transform.rotate(
        angle: -0.15,
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _red, width: 3),
          ),
          child: pw.Text('REJECTED',
              style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: _red,
                  letterSpacing: 3)),
        ),
      ),
    );
  }

  static Future<void> printPdf({
    required AdjustmentV3 header,
    required List<AdjustmentV3Item> items,
    String companyName = 'FLAV POS',
  }) async {
    final bytes = await generate(
      header: header,
      items: items,
      companyName: companyName,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> downloadPdf({
    required AdjustmentV3 header,
    required List<AdjustmentV3Item> items,
    String companyName = 'FLAV POS',
  }) async {
    final bytes = await generate(
      header: header,
      items: items,
      companyName: companyName,
    );
    final filename = 'ADJ-${header.docNumber.isEmpty ? header.adjustmentId : header.docNumber}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
