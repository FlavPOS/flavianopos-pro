import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xl;
import '../../utils/download_helper.dart';
import 'delivery_model.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});
  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  List<DeliveryRecord> _records = [];
  List<DeliveryRecord> _filtered = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() { super.initState(); _load(); _searchCtrl.addListener(_applyFilters); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async { final all = await DeliveryStorage.getAll(); setState(() { _records = all; _filtered = all; _isLoading = false; }); }
  Future<void> _applyFilters() async { final r = await DeliveryStorage.getFiltered(dateFrom: _dateFrom, dateTo: _dateTo, searchQuery: _searchCtrl.text); setState(() => _filtered = r); }
  Future<void> _pickDate(bool isFrom) async {
    final p = await showDatePicker(context: context, initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
    if (p != null) { setState(() { if (isFrom) _dateFrom = p; else _dateTo = p; }); _applyFilters(); }
  }
  void _clearFilters() { setState(() { _dateFrom = null; _dateTo = null; _searchCtrl.clear(); _filtered = _records; }); }
  void _snack(String msg, Color bg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  String _fmtDate(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  String _fmtTime(DateTime d) => '${_pad(d.hour)}:${_pad(d.minute)}';
  String _fmtDateTime(DateTime d) => '${_fmtDate(d)} ${_fmtTime(d)}';
  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<void> _exportExcel() async {
    if (_filtered.isEmpty) { _snack('No records to export', Colors.orange); return; }
    try {
      final excel = xl.Excel.createExcel(); final sheet = excel['Delivery History']; excel.delete('Sheet1');
      final headerStyle = xl.CellStyle(bold: true, fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'), backgroundColorHex: xl.ExcelColor.fromHexString('#1565C0'), horizontalAlign: xl.HorizontalAlign.Center);
      final titleStyle = xl.CellStyle(bold: true, fontSize: 14);
      final subtitleStyle = xl.CellStyle(bold: true, fontSize: 11, fontColorHex: xl.ExcelColor.fromHexString('#555555'));
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = xl.TextCellValue('FlavianoPOS - PRO - Delivery History Report');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      String dateRange = 'Date Range: All';
      if (_dateFrom != null || _dateTo != null) { dateRange = 'Date Range: ${_dateFrom != null ? _fmtDate(_dateFrom!) : "Start"} to ${_dateTo != null ? _fmtDate(_dateTo!) : "Present"}'; }
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = xl.TextCellValue(dateRange);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = subtitleStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = xl.TextCellValue('Generated: ${_fmtDateTime(DateTime.now())} | Total: ${_filtered.length} deliveries');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).cellStyle = subtitleStyle;
      final headers = ['Date', 'Time', 'DR #', 'Supplier', 'Driver', 'Plate #', 'Received By', 'Item', 'SKU', 'Batch #', 'MFG Date', 'EXP Date', 'Qty', 'Old Stock', 'New Stock', 'Unit Cost', 'Unit Retail', 'Total Cost', 'Total Retail'];
      for (var c = 0; c < headers.length; c++) { final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 4)); cell.value = xl.TextCellValue(headers[c]); cell.cellStyle = headerStyle; }
      int row = 5;
      for (final r in _filtered) { final date = _fmtDate(r.dateTime); final time = _fmtTime(r.dateTime);
        for (final item in r.items) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue(date);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.TextCellValue(time);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.TextCellValue(r.refNumber);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.TextCellValue(r.supplier);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xl.TextCellValue(r.driverName);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = xl.TextCellValue(r.plateNumber);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = xl.TextCellValue(r.receivedBy);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = xl.TextCellValue(item.itemName);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = xl.TextCellValue(item.sku);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = xl.TextCellValue(item.batchNumber);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = xl.TextCellValue(item.mfgDate);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row)).value = xl.TextCellValue(item.expDate);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row)).value = xl.IntCellValue(item.quantity);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row)).value = xl.IntCellValue(item.oldStock);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: row)).value = xl.IntCellValue(item.newStock);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: row)).value = xl.DoubleCellValue(item.cost);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 16, rowIndex: row)).value = xl.DoubleCellValue(item.retail);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 17, rowIndex: row)).value = xl.DoubleCellValue(item.cost * item.quantity);
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 18, rowIndex: row)).value = xl.DoubleCellValue(item.retail * item.quantity);
          row++;
        }
      }
      final sumStyle = xl.CellStyle(bold: true, backgroundColorHex: xl.ExcelColor.fromHexString('#E3F2FD'));
      row++;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = xl.TextCellValue('GRAND TOTAL');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).cellStyle = sumStyle;
      final grandQty = _filtered.fold(0, (s, r) => s + r.totalQuantity);
      final grandCost = _filtered.fold(0.0, (s, r) => s + r.totalCost);
      final grandRetail = _filtered.fold(0.0, (s, r) => s + r.totalRetail);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row)).value = xl.IntCellValue(grandQty);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row)).cellStyle = sumStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 17, rowIndex: row)).value = xl.DoubleCellValue(grandCost);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 17, rowIndex: row)).cellStyle = sumStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 18, rowIndex: row)).value = xl.DoubleCellValue(grandRetail);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 18, rowIndex: row)).cellStyle = sumStyle;
      for (var i = 0; i < 19; i++) { sheet.setColumnWidth(i, [12.0,8.0,16.0,18.0,16.0,12.0,16.0,24.0,14.0,14.0,12.0,12.0,8.0,10.0,10.0,12.0,12.0,12.0,12.0][i]); }
      final fileBytes = excel.save();
      if (fileBytes != null) { final ts = DateTime.now().millisecondsSinceEpoch; await saveFileBytes('delivery_history_$ts.xlsx', fileBytes); if (mounted) _snack('Excel exported!', Colors.green.shade700); }
    } catch (e) { if (mounted) _snack('Excel error: $e', Colors.red); }
  }

  Future<void> _exportPdfReport() async {
    if (_filtered.isEmpty) { _snack('No records to export', Colors.orange); return; }
    try {
      final pdf = pw.Document();
      String dateRange = 'All Dates';
      if (_dateFrom != null || _dateTo != null) { dateRange = '${_dateFrom != null ? _fmtDate(_dateFrom!) : "Start"} to ${_dateTo != null ? _fmtDate(_dateTo!) : "Present"}'; }
      final grandQty = _filtered.fold(0, (s, r) => s + r.totalQuantity);
      final grandCost = _filtered.fold(0.0, (s, r) => s + r.totalCost);
      final grandRetail = _filtered.fold(0.0, (s, r) => s + r.totalRetail);
      final List<List<String>> dataRows = [];
      for (final r in _filtered) { for (int i = 0; i < r.items.length; i++) { final item = r.items[i];
        dataRows.add([i == 0 ? _fmtDateTime(r.dateTime) : '', i == 0 ? r.refNumber : '', i == 0 ? (r.supplier.isEmpty ? '-' : r.supplier) : '',
          item.itemName, item.sku, item.batchNumber.isEmpty ? '-' : item.batchNumber, item.mfgDate.isEmpty ? '-' : item.mfgDate, item.expDate.isEmpty ? '-' : item.expDate,
          '${item.quantity}', item.cost.toStringAsFixed(2), item.retail.toStringAsFixed(2), (item.cost * item.quantity).toStringAsFixed(2), (item.retail * item.quantity).toStringAsFixed(2)]); } }
      const rowsPerPage = 22; final chunks = <List<List<String>>>[]; for (var i = 0; i < dataRows.length; i += rowsPerPage) { chunks.add(dataRows.sublist(i, i + rowsPerPage > dataRows.length ? dataRows.length : i + rowsPerPage)); }
      for (var pageIdx = 0; pageIdx < chunks.length; pageIdx++) {
        pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4.landscape, margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (pageIdx == 0) ...[
              pw.Container(padding: const pw.EdgeInsets.all(12), decoration: const pw.BoxDecoration(color: PdfColors.blue800, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('FlavianoPOS - PRO', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)), pw.Text('DELIVERY HISTORY REPORT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow))]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [pw.Text('Date Range: $dateRange', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)), pw.Text('Generated: ${_fmtDateTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey300))])])),
              pw.SizedBox(height: 6),
              pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [_pdfStat('Deliveries', '${_filtered.length}'), _pdfStat('Total Qty', '+$grandQty'), _pdfStat('Total Cost', grandCost.toStringAsFixed(2)), _pdfStat('Total Retail', grandRetail.toStringAsFixed(2))])),
              pw.SizedBox(height: 8)],
            if (pageIdx > 0) ...[pw.Text('Delivery History (continued)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)), pw.SizedBox(height: 8)],
            pw.TableHelper.fromTextArray(headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.white), headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 7), cellAlignments: {8: pw.Alignment.centerRight, 9: pw.Alignment.centerRight, 10: pw.Alignment.centerRight, 11: pw.Alignment.centerRight, 12: pw.Alignment.centerRight},
              headerPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4), cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3), oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              headers: ['Date/Time', 'DR #', 'Supplier', 'Item', 'SKU', 'Batch #', 'MFG', 'EXP', 'Qty', 'U.Cost', 'U.Retail', 'T.Cost', 'T.Retail'], data: chunks[pageIdx]),
            pw.Spacer(), pw.Divider(color: PdfColors.grey400),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total: ${_filtered.length}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)), pw.Text('Page ${pageIdx + 1}/${chunks.length}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)), pw.Text('System-generated document', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500))])])));
      }
      final pdfBytes = await pdf.save(); final ts = DateTime.now().millisecondsSinceEpoch;
      await saveFileBytes('delivery_history_$ts.pdf', pdfBytes); if (mounted) _snack('PDF exported!', Colors.green.shade700);
    } catch (e) { if (mounted) _snack('PDF error: $e', Colors.red); }
  }

  static pw.Widget _pdfStat(String l, String v) => pw.Column(children: [pw.Text(v, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)), pw.Text(l, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700))]);

  pw.Document _buildA4Pdf(DeliveryRecord r) {
    final pdf = pw.Document(); final date = _fmtDate(r.dateTime); final time = '${_pad(r.dateTime.hour)}:${_pad(r.dateTime.minute)}:${_pad(r.dateTime.second)}';
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4.landscape, margin: const pw.EdgeInsets.all(20 * PdfPageFormat.mm),
      build: (pw.Context ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(width: double.infinity, padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: const pw.BoxDecoration(color: PdfColors.blue800, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
          child: pw.Column(children: [pw.Text('FlavianoPOS - PRO', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)), pw.SizedBox(height: 2), pw.Text('DELIVERY RECEIVING REPORT', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow, letterSpacing: 2))])),
        pw.SizedBox(height: 12),
        pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_pdfInfoRow('Date', date), _pdfInfoRow('Time', time), _pdfInfoRow('DR #', r.refNumber)]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_pdfInfoRow('Supplier', r.supplier.isEmpty ? '-' : r.supplier), _pdfInfoRow('Driver', r.driverName.isEmpty ? '-' : r.driverName), _pdfInfoRow('Plate #', r.plateNumber.isEmpty ? '-' : r.plateNumber)]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_pdfInfoRow('Received By', r.receivedBy.isEmpty ? '-' : r.receivedBy), _pdfInfoRow('Total Items', '${r.totalItems}'), _pdfInfoRow('Total Qty', '+${r.totalQuantity} pcs')])])),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white), headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700), cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignments: {0: pw.Alignment.center, 6: pw.Alignment.center, 7: pw.Alignment.centerRight, 8: pw.Alignment.centerRight, 9: pw.Alignment.centerRight, 10: pw.Alignment.centerRight},
          headerPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5), cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4), oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          headers: ['#', 'Item', 'SKU', 'Batch #', 'MFG', 'EXP', 'Qty', 'Unit Cost', 'Unit Retail', 'Total Cost', 'Total Retail'],
          data: [for (int i = 0; i < r.items.length; i++) ['${i + 1}', r.items[i].itemName, r.items[i].sku, r.items[i].batchNumber.isEmpty ? '-' : r.items[i].batchNumber, r.items[i].mfgDate.isEmpty ? '-' : r.items[i].mfgDate, r.items[i].expDate.isEmpty ? '-' : r.items[i].expDate, '${r.items[i].quantity}', r.items[i].cost.toStringAsFixed(2), r.items[i].retail.toStringAsFixed(2), (r.items[i].cost * r.items[i].quantity).toStringAsFixed(2), (r.items[i].retail * r.items[i].quantity).toStringAsFixed(2)]]),
        pw.SizedBox(height: 4),
        pw.Container(width: double.infinity, padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: pw.BoxDecoration(color: PdfColors.blue50, border: pw.Border.all(color: PdfColors.blue200), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [pw.Text('Items: ${r.totalItems}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text('Qty: +${r.totalQuantity}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)), pw.Text('Cost: ${r.totalCost.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text('Retail: ${r.totalRetail.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800))])),
        pw.SizedBox(height: 8),
        if (r.notes.isNotEmpty) ...[pw.Container(width: double.infinity, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(color: PdfColors.amber50, border: pw.Border.all(color: PdfColors.amber200), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))), child: pw.Text('Notes: ${r.notes}', style: const pw.TextStyle(fontSize: 9))), pw.SizedBox(height: 8)],
        pw.Spacer(), pw.Divider(color: PdfColors.grey400), pw.SizedBox(height: 8),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [_pdfSignature('Received By'), _pdfSignature('Checked By'), _pdfSignature('Approved By')]),
        pw.SizedBox(height: 12), pw.Center(child: pw.Text('System-generated document from FlavianoPOS - PRO', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)))])));
    return pdf;
  }

  static pw.Widget _pdfInfoRow(String l, String v) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1), child: pw.Row(children: [pw.SizedBox(width: 70, child: pw.Text('$l:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))), pw.Text(v, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))]));
  static pw.Widget _pdfSignature(String l) => pw.Column(children: [pw.SizedBox(height: 30), pw.Container(width: 140, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey600))), child: pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Text(l, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)))))]);
  Future<void> _printA4(DeliveryRecord r) async { final pdf = _buildA4Pdf(r); await Printing.layoutPdf(onLayout: (_) async => pdf.save(), name: 'DR_${r.refNumber}'); }
  Future<void> _savePdf(DeliveryRecord r) async { final pdf = _buildA4Pdf(r); await Printing.sharePdf(bytes: await pdf.save(), filename: 'DR_${r.refNumber}.pdf'); }

  void _showDetail(DeliveryRecord r) {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.95, expand: false,
        builder: (_, sc) => Padding(padding: const EdgeInsets.all(20), child: ListView(controller: sc, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          const Center(child: Text('Delivery Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _dRow('Date', _fmtDate(r.dateTime)), _dRow('Time', _fmtTime(r.dateTime)),
          _dRow('DR #', r.refNumber), _dRow('Supplier', r.supplier.isEmpty ? '-' : r.supplier),
          _dRow('Driver', r.driverName.isEmpty ? '-' : r.driverName), _dRow('Plate #', r.plateNumber.isEmpty ? '-' : r.plateNumber),
          _dRow('Received By', r.receivedBy.isEmpty ? '-' : r.receivedBy),
          _dRow('Total Items', '${r.totalItems}'), _dRow('Total Qty', '${r.totalQuantity} pcs'),
          _dRow('Total Cost', r.totalCost.toStringAsFixed(2)), _dRow('Total Retail', r.totalRetail.toStringAsFixed(2)),
          if (r.notes.isNotEmpty) _dRow('Notes', r.notes),
          const Divider(height: 24),
          const Text('Items Received:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 8),
          ...r.items.map((item) => Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green.withAlpha(50), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withAlpha(200))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('SKU: ${item.sku}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                if (item.batchNumber.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4),
                  child: Wrap(spacing: 6, runSpacing: 4, children: [_batchChip('Batch: ${item.batchNumber}', Colors.teal), if (item.mfgDate.isNotEmpty) _batchChip('MFG: ${item.mfgDate}', Colors.green), if (item.expDate.isNotEmpty) _batchChip('EXP: ${item.expDate}', Colors.red)])),
                const SizedBox(height: 2),
                Text('C: ${item.cost.toStringAsFixed(2)}  R: ${item.retail.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.blue[700]))])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('+${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                Text('${item.oldStock} \u2192 ${item.newStock}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text((item.cost * item.quantity).toStringAsFixed(2), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green[700]))])]))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.print, color: Colors.white, size: 18), label: const Text('Print A4', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () { Navigator.pop(context); _printA4(r); })),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18), label: const Text('Save PDF', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () { Navigator.pop(context); _savePdf(r); }))])]))));
  }

  Widget _batchChip(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
    child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)));
  Widget _dRow(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
    SizedBox(width: 110, child: Text(l, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]))), Expanded(child: Text(v, style: const TextStyle(fontSize: 14)))]));
  Widget _infoChip(IconData ic, String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(ic, size: 12, color: color), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color))]));

  @override
  Widget build(BuildContext context) {
    final grandQty = _filtered.fold(0, (s, r) => s + r.totalQuantity);
    final grandCost = _filtered.fold(0.0, (s, r) => s + r.totalCost);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(elevation: 0, title: const Text('\u{1F4CB} Delivery History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white,
        actions: [PopupMenuButton<String>(icon: const Icon(Icons.file_download_rounded), tooltip: 'Export',
          onSelected: (v) { if (v == 'excel') _exportExcel(); if (v == 'pdf') _exportPdfReport(); },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'excel', child: Row(children: [Icon(Icons.table_chart, color: Colors.green, size: 20), SizedBox(width: 10), Text('Export to Excel')])),
            const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, color: Colors.red, size: 20), SizedBox(width: 10), Text('Export to PDF')]))])]),
      body: Column(children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(children: [
            Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: TextField(controller: _searchCtrl, style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(hintText: '\u{1F50D} Search DR#, supplier, item...', hintStyle: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.6), size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.6), size: 18), onPressed: () { _searchCtrl.clear(); _applyFilters(); }) : null,
                  border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: InkWell(onTap: () => _pickDate(true), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [Icon(Icons.calendar_today, size: 14, color: Colors.white.withOpacity(0.7)), const SizedBox(width: 6),
                  Text(_dateFrom != null ? _fmtDate(_dateFrom!) : 'From Date', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(_dateFrom != null ? 1 : 0.5)))])))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('-', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
              Expanded(child: InkWell(onTap: () => _pickDate(false), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [Icon(Icons.calendar_today, size: 14, color: Colors.white.withOpacity(0.7)), const SizedBox(width: 6),
                  Text(_dateTo != null ? _fmtDate(_dateTo!) : 'To Date', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(_dateTo != null ? 1 : 0.5)))])))),
              if (_dateFrom != null || _dateTo != null || _searchCtrl.text.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 6),
                child: InkWell(onTap: _clearFilters, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.red.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.filter_alt_off, color: Colors.white, size: 18))))])])),
        if (_filtered.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
          child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.blue[700], borderRadius: BorderRadius.circular(10)),
              child: Text('${_filtered.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
            const SizedBox(width: 8), Text('deliveries', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const Spacer(),
            _infoChip(Icons.add_box, '+$grandQty pcs', Colors.green),
            const SizedBox(width: 6),
            _infoChip(Icons.payments, grandCost.toStringAsFixed(0), Colors.blue)])),
        Expanded(child: _isLoading
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Loading deliveries...', style: TextStyle(color: Colors.grey))]))
          : _filtered.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                  child: Icon(Icons.local_shipping_outlined, size: 48, color: Colors.blue[200])),
                const SizedBox(height: 16), Text('No deliveries found', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 4), Text('Receive items to see history here', style: TextStyle(color: Colors.grey[400], fontSize: 12))]))
            : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final r = _filtered[i];
                  return Container(margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
                    child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => _showDetail(r),
                      child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)]), borderRadius: BorderRadius.circular(8)),
                            child: Text('DR# ${r.refNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                          const Spacer(),
                          Text('${_fmtDate(r.dateTime)}  ${_fmtTime(r.dateTime)}', style: TextStyle(fontSize: 10, color: Colors.grey[500]))]),
                        const SizedBox(height: 8),
                        if (r.supplier.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [Icon(Icons.business, size: 13, color: Colors.grey[400]), const SizedBox(width: 4),
                            Text(r.supplier, style: TextStyle(fontSize: 12, color: Colors.grey[700]))])),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          _infoChip(Icons.inventory_2, '${r.totalItems} items', Colors.indigo),
                          _infoChip(Icons.add_box, '+${r.totalQuantity} pcs', Colors.green),
                          _infoChip(Icons.payments, 'C: ${r.totalCost.toStringAsFixed(0)}', Colors.teal),
                          _infoChip(Icons.sell, 'R: ${r.totalRetail.toStringAsFixed(0)}', Colors.blue)]),
                        if (r.items.isNotEmpty && r.items.any((x) => x.batchNumber.isNotEmpty)) Padding(padding: const EdgeInsets.only(top: 6),
                          child: Row(children: [Icon(Icons.layers, size: 12, color: Colors.teal[300]), const SizedBox(width: 4),
                            Text('${r.items.where((x) => x.batchNumber.isNotEmpty).length} batch(es)', style: TextStyle(fontSize: 10, color: Colors.teal[400]))])),
                      ]))));
                })),
      ]),
    );
  }
}
