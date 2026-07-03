// lib/screens/receive_delivery/approved_detail_screen.dart
// Read-only APPROVED delivery viewer with Reprint PDF + Export Excel
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import '../../utils/receive_delivery_theme.dart';
import 'delivery_model.dart';

class ApprovedDetailScreen extends StatefulWidget {
  final DeliveryRecord record;
  const ApprovedDetailScreen({super.key, required this.record});

  @override
  State<ApprovedDetailScreen> createState() => _ApprovedDetailScreenState();
}

class _ApprovedDetailScreenState extends State<ApprovedDetailScreen> {
  static const _green      = Color(0xFF16A34A);
  static const _greenLight = Color(0xFFDCFCE7);
  static const _border     = Color(0xFFE5E7EB);
  static const _muted      = Color(0xFF6B7280);

  bool _processing = false;
  int? _expandedIndex;

  final _int = NumberFormat.decimalPattern();
  final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  String _money(double v) => NumberFormat('#,##0.00', 'en_PH').format(v);

  List<_SkuGroup> get _groups {
    final map = <String, _SkuGroup>{};
    for (final item in widget.record.items) {
      final key = item.sku.isEmpty ? item.productId : item.sku;
      map.putIfAbsent(key, () => _SkuGroup(sku: item.sku, productId: item.productId, itemName: item.itemName, batches: [])).batches.add(item);
    }
    return map.values.toList();
  }

  // ═══════════════ PDF BUILD ═══════════════
  pw.Document _buildPdf() {
    final d = widget.record;
    final pdf = pw.Document();
    final approvedBy = d.approvedBy.isEmpty ? '-' : d.approvedBy;
    final approvedDate = d.approvedDate.isEmpty ? '' : d.approvedDate;
    String fD(String iso) { try { return DateFormat('MM/dd/yyyy HH:mm').format(DateTime.parse(iso)); } catch (_) { return iso; } }
    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(8 * PdfPageFormat.mm),
      build: (ctx) => _buildPdfContent(d, 'TRUCKER COPY', approvedBy, fD(approvedDate))));
    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(8 * PdfPageFormat.mm),
      build: (ctx) => _buildPdfContent(d, 'STORE COPY', approvedBy, fD(approvedDate))));
    return pdf;
  }

  List<pw.Widget> _buildPdfContent(DeliveryRecord d, String copyLabel, String approvedBy, String approvedDate) {
    final Map<String, List<DeliveryItemRecord>> grouped = {};
    for (final item in d.items) {
      final key = '${item.itemName}||${item.sku}';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    double grandTotal = 0;
    int grandQty = 0;
    final rows = <pw.TableRow>[];
    rows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1976D2)), children: [
      _pC('#', bold: true, color: PdfColors.white, align: pw.Alignment.center),
      _pC('Description', bold: true, color: PdfColors.white),
      _pC('Qty', bold: true, color: PdfColors.white, align: pw.Alignment.centerRight),
      _pC('Unit Retail', bold: true, color: PdfColors.white, align: pw.Alignment.centerRight),
      _pC('Total @ Retail', bold: true, color: PdfColors.white, align: pw.Alignment.centerRight),
    ]));
    int idx = 1;
    grouped.forEach((_, batches) {
      final first = batches.first;
      final subQty = batches.fold<int>(0, (s, b) => s + b.quantity);
      double subRetail = 0;
      rows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)), children: [
        _pC('$idx', bold: true, align: pw.Alignment.center),
        _pC('${first.itemName}  (${first.sku})', bold: true),
        _pC(''), _pC(''), _pC(''),
      ]));
      for (final b in batches) {
        final line = b.quantity * b.retail;
        subRetail += line;
        String mfg = b.mfgDate.isEmpty ? '-' : b.mfgDate.split('T').first;
        String exp = b.expDate.isEmpty ? '-' : b.expDate.split('T').first;
        rows.add(pw.TableRow(children: [
          _pC(''),
          _pC('    Batch: ${b.batchNumber.isEmpty ? "-" : b.batchNumber}   MFG: $mfg   EXP: $exp', size: 8, color: PdfColors.grey800),
          _pC(_int.format(b.quantity), align: pw.Alignment.centerRight, size: 9),
          _pC(_money(b.retail), align: pw.Alignment.centerRight, size: 9),
          _pC(_money(line), align: pw.Alignment.centerRight, size: 9),
        ]));
      }
      rows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE3F2FD)), children: [
        _pC(''),
        _pC('   ITEM SUBTOTAL', bold: true, color: const PdfColor.fromInt(0xFF0D47A1)),
        _pC(_int.format(subQty), bold: true, color: const PdfColor.fromInt(0xFF0D47A1), align: pw.Alignment.centerRight),
        _pC('-', bold: true, color: const PdfColor.fromInt(0xFF0D47A1), align: pw.Alignment.centerRight),
        _pC(_money(subRetail), bold: true, color: const PdfColor.fromInt(0xFF0D47A1), align: pw.Alignment.centerRight),
      ]));
      grandQty += subQty;
      grandTotal += subRetail;
      idx++;
    });

    return [
      pw.Container(padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor.fromInt(0xFF1976D2), width: 1), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Row(children: [
            pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1976D2)),
              child: pw.Text('DR', style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(width: 8),
            pw.Text(copyLabel, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0D47A1), letterSpacing: 2)),
            pw.SizedBox(width: 12),
            pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(color: PdfColors.green700, borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Text('APPROVED', style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5))),
          ]),
          pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor.fromInt(0xFF1976D2), width: 1), borderRadius: pw.BorderRadius.circular(3)),
            child: pw.Text('Serial: DR-${d.refNumber}', style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF0D47A1)))),
        ])),
      pw.SizedBox(height: 6),
      pw.Container(width: double.infinity, padding: const pw.EdgeInsets.symmetric(vertical: 6),
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1976D2)),
        child: pw.Column(children: [
          pw.Text('HEAD OFFICE - DELIVERY RECEIVING REPORT', style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
          pw.SizedBox(height: 2),
          pw.Text('TIN: TO-BE-ASSIGNED   |   MIN: TO-BE-ASSIGNED   |   PTU: TO-BE-ASSIGNED', style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
        ])),
      pw.SizedBox(height: 8),
      pw.Row(children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _pI('Date', DateFormat('yyyy-MM-dd').format(d.dateTime)),
          _pI('Time', DateFormat('HH:mm:ss').format(d.dateTime)),
          _pI('DR #', d.refNumber),
        ])),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _pI('Supplier', d.supplier.isEmpty ? '-' : d.supplier),
          _pI('Driver', d.driverName.isEmpty ? '-' : d.driverName),
          _pI('Plate #', d.plateNumber.isEmpty ? '-' : d.plateNumber),
        ])),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _pI('Received By', d.receivedBy.isEmpty ? '-' : d.receivedBy),
          _pI('Total Items', '${grouped.length}'),
          _pI('Total Qty', '${_int.format(grandQty)} pcs'),
        ])),
      ]),
      pw.SizedBox(height: 8),
      pw.Table(border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        columnWidths: {0: const pw.FlexColumnWidth(0.4), 1: const pw.FlexColumnWidth(4.0), 2: const pw.FlexColumnWidth(1.2), 3: const pw.FlexColumnWidth(1.1), 4: const pw.FlexColumnWidth(1.3)},
        children: rows),
      pw.SizedBox(height: 10),
      pw.Row(children: [
        pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor.fromInt(0xFF1976D2))),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _pI('Total Items', '${grouped.length}'),
            _pI('Total Qty', '${_int.format(grandQty)} pcs'),
          ]))),
        pw.SizedBox(width: 8),
        pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.all(8),
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0D47A1)),
          child: pw.Column(children: [
            pw.Text('GRAND TOTAL @ RETAIL', style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('PHP ${_money(grandTotal)}', style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ]))),
      ]),
      pw.SizedBox(height: 8),
      if (d.notes.isNotEmpty)
        pw.Container(padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
          child: pw.Text('Notes: ${d.notes}', style: const pw.TextStyle(fontSize: 9))),
      pw.Spacer(),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
        _pS('Received By'), _pS('Checked By'), _pS('Approved By'),
      ]),
    ];
  }

  pw.Widget _pI(String l, String v) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(children: [
      pw.SizedBox(width: 75, child: pw.Text('$l:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
      pw.Expanded(child: pw.Text(v, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
    ]));

  pw.Widget _pC(String text, {bool bold = false, PdfColor color = PdfColors.black, pw.Alignment align = pw.Alignment.centerLeft, double size = 9}) {
    return pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4), alignment: align,
      child: pw.Text(text, style: pw.TextStyle(fontSize: size, color: color, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal), maxLines: 2));
  }

  pw.Widget _pS(String label) => pw.Column(children: [
    pw.Container(width: 200, height: 25, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey700)))),
    pw.SizedBox(height: 2),
    pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
    pw.Text('Name / Signature / Date', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
  ]);

  Future<void> _printPdf() async {
    setState(() => _processing = true);
    try {
      final pdf = _buildPdf();
      await Printing.layoutPdf(onLayout: (_) async => pdf.save(), name: 'DR_${widget.record.refNumber}_APPROVED');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _savePdf() async {
    setState(() => _processing = true);
    try {
      final pdf = _buildPdf();
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'DR_${widget.record.refNumber}_APPROVED.pdf');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ═══════════════ EXCEL EXPORT ═══════════════
  Future<void> _exportExcel() async {
    setState(() => _processing = true);
    try {
      final d = widget.record;
      final excel = xl.Excel.createExcel();
      excel.delete('Sheet1');

      // ── SUMMARY sheet ──
      final s1 = excel['SUMMARY'];
      final hStyle = xl.CellStyle(bold: true, fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: xl.ExcelColor.fromHexString('#16A34A'), horizontalAlign: xl.HorizontalAlign.Center);
      final titleStyle = xl.CellStyle(bold: true, fontSize: 14, fontColorHex: xl.ExcelColor.fromHexString('#0D4020'));

      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = xl.TextCellValue('FlavianoPOS PRO - Approved Delivery');
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = xl.TextCellValue('DR #: ${d.refNumber}    |    Status: APPROVED    |    Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');

      final headers1 = ['Field', 'Value'];
      for (var c = 0; c < headers1.length; c++) {
        final cell = s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3));
        cell.value = xl.TextCellValue(headers1[c]);
        cell.cellStyle = hStyle;
      }
      final fields = [
        ['DR #', d.refNumber],
        ['Supplier', d.supplier],
        ['Driver', d.driverName],
        ['Plate #', d.plateNumber],
        ['Received By', d.receivedBy],
        ['Delivery Date', DateFormat('yyyy-MM-dd HH:mm').format(d.dateTime)],
        ['Approved By', d.approvedBy],
        ['Approved Date', d.approvedDate.isEmpty ? '-' : d.approvedDate],
        ['Total Items', '${d.totalItems}'],
        ['Total Qty', '${d.totalQuantity}'],
        ['Total Cost', d.totalCost.toStringAsFixed(2)],
        ['Total Retail', d.totalRetail.toStringAsFixed(2)],
        ['Notes', d.notes],
      ];
      for (var i = 0; i < fields.length; i++) {
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4 + i)).value = xl.TextCellValue(fields[i][0]);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4 + i)).value = xl.TextCellValue(fields[i][1]);
      }
      s1.setColumnWidth(0, 20);
      s1.setColumnWidth(1, 40);

      // ── ITEMS & BATCHES sheet ──
      final s2 = excel['ITEMS_AND_BATCHES'];
      final headers2 = ['#', 'DR #', 'SKU', 'Product', 'Batch #', 'MFG Date', 'EXP Date', 'Qty', 'Cost', 'Retail', 'Line Total'];
      for (var c = 0; c < headers2.length; c++) {
        final cell = s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = xl.TextCellValue(headers2[c]);
        cell.cellStyle = hStyle;
      }
      int rowIdx = 1;
      int idx = 1;
      for (final item in d.items) {
        s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx)).value = xl.IntCellValue(idx);
        s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx)).value = xl.TextCellValue(d.refNumber);
        s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx)).value = xl.TextCellValue(item.sku);
        s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx)).value = xl.TextCellValue(item.itemName);
        s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx)).value = xl.TextCellValue(item.batchNumber);
        s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx)).value = xl.TextCellValue(item.mfgDate);
        s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIdx)).value = xl.TextCellValue(item.expDate);
        s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIdx)).value = xl.IntCellValue(item.quantity);
        s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIdx)).value = xl.DoubleCellValue(item.cost);
        s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIdx)).value = xl.DoubleCellValue(item.retail);
        s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIdx)).value = xl.DoubleCellValue(item.quantity * item.retail);
        rowIdx++;
        idx++;
      }
      s2.setColumnWidth(0, 5);
      s2.setColumnWidth(1, 12);
      s2.setColumnWidth(2, 12);
      s2.setColumnWidth(3, 30);
      s2.setColumnWidth(4, 12);
      s2.setColumnWidth(5, 12);
      s2.setColumnWidth(6, 12);
      s2.setColumnWidth(7, 10);
      s2.setColumnWidth(8, 10);
      s2.setColumnWidth(9, 10);
      s2.setColumnWidth(10, 14);

      // ── Save ──
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Excel encoding failed');
      final filename = 'DR_${d.refNumber}_APPROVED.xlsx';
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: filename);
      if (!mounted) return;
      ReceiveDeliveryTheme.showSuccess(context, 'Excel exported: $filename');
    } catch (e) {
      if (mounted) ReceiveDeliveryTheme.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ═══════════════ UI ═══════════════
  Widget _info(String label, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[50], border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: _muted),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.record;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0, backgroundColor: _green, foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.check_circle_outline, size: 20),
            SizedBox(width: 8),
            Text('View Approved', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
          ]),
          Text('${_groups.length} Item${_groups.length == 1 ? "" : "s"}',
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
        ]),
        actions: [
          IconButton(onPressed: _processing ? null : _printPdf, tooltip: 'Print A4', icon: const Icon(Icons.print, color: Colors.white, size: 22)),
          IconButton(onPressed: _processing ? null : _savePdf, tooltip: 'Save PDF', icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 22)),
          IconButton(onPressed: _processing ? null : _exportExcel, tooltip: 'Export Excel', icon: const Icon(Icons.table_chart, color: Colors.white, size: 22)),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(36),
          child: Container(width: double.infinity, color: _green,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              Flexible(child: Text('DR#: ${d.refNumber}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: const Text('APPROVED', style: TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
            ]),
          ),
        ),
      ),
      body: Stack(children: [
        LayoutBuilder(builder: (context, cons) {
          final w = cons.maxWidth;
          final cols = w >= 800 ? 3 : 2;
          return ListView(padding: const EdgeInsets.all(12), children: [
            // Delivery Info Card
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: const [
                  Icon(Icons.description_outlined, size: 18, color: _green),
                  SizedBox(width: 8),
                  Text('Delivery Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (ctx, c) {
                  final colW = (c.maxWidth - (cols - 1) * 8) / cols;
                  return Wrap(spacing: 8, runSpacing: 8, children: [
                    SizedBox(width: colW, child: _info('DR # / Reference', d.refNumber, Icons.receipt_long)),
                    SizedBox(width: colW, child: _info('Supplier', d.supplier, Icons.business)),
                    SizedBox(width: colW, child: _info('Driver', d.driverName, Icons.person)),
                    SizedBox(width: colW, child: _info('Plate #', d.plateNumber, Icons.local_shipping)),
                    SizedBox(width: colW, child: _info('Received By', d.receivedBy, Icons.assignment_ind)),
                    SizedBox(width: colW, child: _info('Notes', d.notes, Icons.note_alt_outlined)),
                  ]);
                }),
              ]),
            ),
            const SizedBox(height: 12),
            // Approval Info Card
            Container(
              decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: const [
                  Icon(Icons.verified, size: 16, color: _green),
                  SizedBox(width: 8),
                  Text('Approval Info', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _green)),
                ]),
                const SizedBox(height: 6),
                Padding(padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    SizedBox(width: 130, child: Text('Approved By:', style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                    Expanded(child: Text(d.approvedBy.isEmpty ? '-' : d.approvedBy, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  ])),
                Padding(padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    SizedBox(width: 130, child: Text('Approved Date:', style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                    Expanded(child: Text(d.approvedDate.isEmpty ? '-' : d.approvedDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  ])),
              ]),
            ),
            const SizedBox(height: 12),
            // Items Card
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.inventory_2_outlined, size: 18, color: _green),
                  const SizedBox(width: 8),
                  const Text('Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(10)),
                    child: Text('${_groups.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 10),
                for (int i = 0; i < _groups.length; i++)
                  _SkuAccordionRow(group: _groups[i], index: i, isExpanded: _expandedIndex == i,
                    screenWidth: w,
                    onToggle: () => setState(() => _expandedIndex = _expandedIndex == i ? null : i),
                    intFmt: _int),
              ]),
            ),
            const SizedBox(height: 8),
          ]);
        }),
        if (_processing) Container(color: Colors.black.withValues(alpha: 0.3),
          child: const Center(child: CircularProgressIndicator())),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _border)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))]),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SafeArea(top: false, child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _fStat('Items', '${_groups.length}', Icons.inventory_2_outlined),
          _fStat('Qty', '${_int.format(d.totalQuantity)} pcs', Icons.numbers),
          _fStat('Retail', _peso.format(d.totalRetail), Icons.sell),
        ])),
      ),
    );
  }

  Widget _fStat(String label, String value, IconData icon) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.orange[700]),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
      ]),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    ]);
  }
}

class _SkuGroup {
  final String sku;
  final String productId;
  final String itemName;
  final List<DeliveryItemRecord> batches;
  _SkuGroup({required this.sku, required this.productId, required this.itemName, required this.batches});
}

class _SkuAccordionRow extends StatelessWidget {
  static const _green      = Color(0xFF16A34A);
  static const _greenLight = Color(0xFFDCFCE7);
  static const _border     = Color(0xFFE5E7EB);
  static const _muted      = Color(0xFF6B7280);

  final _SkuGroup group;
  final int index;
  final bool isExpanded;
  final double screenWidth;
  final VoidCallback onToggle;
  final NumberFormat intFmt;

  const _SkuAccordionRow({required this.group, required this.index, required this.isExpanded, required this.screenWidth, required this.onToggle, required this.intFmt});

  @override
  Widget build(BuildContext context) {
    final totalQty = group.batches.fold<int>(0, (s, b) => s + b.quantity);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: isExpanded ? _greenLight.withValues(alpha: 0.3) : Colors.white,
        border: Border.all(color: isExpanded ? _green.withValues(alpha: 0.4) : _border),
        borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Material(color: Colors.transparent, child: InkWell(onTap: onToggle, borderRadius: BorderRadius.circular(8),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)),
                child: Text(group.sku, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[800]))),
              const SizedBox(width: 10),
              Expanded(child: Text(group.itemName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(6)),
                child: Text('${intFmt.format(totalQty)} pcs', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
              const SizedBox(width: 4),
              AnimatedRotation(turns: isExpanded ? 0.5 : 0, duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.expand_more, size: 22, color: _green)),
            ]),
          ))),
        if (isExpanded)
          Container(width: double.infinity,
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _border))),
            padding: const EdgeInsets.all(8),
            child: Column(children: group.batches.map((b) {
              String mfg = b.mfgDate.isEmpty ? '-' : b.mfgDate.split('T').first;
              String exp = b.expDate.isEmpty ? '-' : b.expDate.split('T').first;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey[50], border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
                child: Row(children: [
                  Icon(Icons.qr_code, size: 12, color: _muted),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Batch: ${b.batchNumber}   MFG: $mfg   EXP: $exp',
                    style: const TextStyle(fontSize: 11))),
                  Text('${intFmt.format(b.quantity)} pcs', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _green)),
                ]),
              );
            }).toList())),
      ]),
    );
  }
}
