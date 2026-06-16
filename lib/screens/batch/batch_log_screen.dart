import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import '../../utils/download_helper.dart';
import '../../models/batch_log_model.dart';

class BatchLogScreen extends StatefulWidget {
  final String? filterBatchId;
  final String? filterBatchNumber;
  const BatchLogScreen({super.key, this.filterBatchId, this.filterBatchNumber});
  @override
  State<BatchLogScreen> createState() => _BatchLogScreenState();
}

class _BatchLogScreenState extends State<BatchLogScreen> {
  List<BatchLog> _logs = [];
  List<BatchLog> _filtered = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() { super.initState(); _load(); _searchCtrl.addListener(_applyFilters); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    List<BatchLog> all;
    if (widget.filterBatchId != null) {
      all = await BatchLogStorage.getByBatchId(widget.filterBatchId!);
    } else {
      all = await BatchLogStorage.getAll();
    }
    setState(() { _logs = all; _filtered = all; _isLoading = false; });
  }

  Future<void> _applyFilters() async {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _logs.where((l) {
        if (_dateFrom != null) {
          final start = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
          if (l.dateTime.isBefore(start)) return false;
        }
        if (_dateTo != null) {
          final end = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
          if (l.dateTime.isAfter(end)) return false;
        }
        if (q.isNotEmpty) {
          return l.batchNumber.toLowerCase().contains(q) ||
              l.productName.toLowerCase().contains(q) ||
              l.productSku.toLowerCase().contains(q) ||
              l.action.toLowerCase().contains(q) ||
              l.reason.toLowerCase().contains(q) ||
              l.field.toLowerCase().contains(q);
        }
        return true;
      }).toList();
    });
  }

  Future<void> _pickDate(bool isFrom) async {
    final p = await showDatePicker(context: context, initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
    if (p != null) { setState(() { if (isFrom) { _dateFrom = p; } else { _dateTo = p; } }); _applyFilters(); }
  }

  void _clearFilters() { setState(() { _dateFrom = null; _dateTo = null; _searchCtrl.clear(); _filtered = _logs; }); }

  void _snack(String msg, Color bg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  String _fmtDate(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  String _fmtTime(DateTime d) => '${_pad(d.hour)}:${_pad(d.minute)}';
  String _fmtDateTime(DateTime d) => '${_fmtDate(d)} ${_fmtTime(d)}';
  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<void> _exportExcel() async {
    if (_filtered.isEmpty) { _snack('No logs to export', Colors.orange); return; }
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Batch Logs'];
      excel.delete('Sheet1');

      final headerStyle = xl.CellStyle(bold: true, fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: xl.ExcelColor.fromHexString('#00695C'), horizontalAlign: xl.HorizontalAlign.Center);
      final titleStyle = xl.CellStyle(bold: true, fontSize: 14);
      final subtitleStyle = xl.CellStyle(bold: true, fontSize: 11, fontColorHex: xl.ExcelColor.fromHexString('#555555'));

      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = xl.TextCellValue('FlavianoPOS - PRO - Batch Update Logs');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

      String dateRange = 'Date Range: All';
      if (_dateFrom != null || _dateTo != null) {
        dateRange = 'Date Range: ${_dateFrom != null ? _fmtDate(_dateFrom!) : "Start"} to ${_dateTo != null ? _fmtDate(_dateTo!) : "Present"}';
      }
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = xl.TextCellValue(dateRange);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = subtitleStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = xl.TextCellValue('Generated: ${_fmtDateTime(DateTime.now())} | Total: ${_filtered.length} logs');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).cellStyle = subtitleStyle;

      final headers = ['Date/Time', 'Batch #', 'Product', 'SKU', 'Action', 'Reason', 'Field', 'Old Value', 'New Value'];
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 4));
        cell.value = xl.TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
      }

      for (var i = 0; i < _filtered.length; i++) {
        final l = _filtered[i];
        final row = i + 5;
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue(_fmtDateTime(l.dateTime));
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.TextCellValue(l.batchNumber);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.TextCellValue(l.productName);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.TextCellValue(l.productSku);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xl.TextCellValue(l.action);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = xl.TextCellValue(l.reason);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = xl.TextCellValue(l.field);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = xl.TextCellValue(l.oldValue);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = xl.TextCellValue(l.newValue);
      }

      sheet.setColumnWidth(0, 18); sheet.setColumnWidth(1, 16); sheet.setColumnWidth(2, 22);
      sheet.setColumnWidth(3, 14); sheet.setColumnWidth(4, 12); sheet.setColumnWidth(5, 20);
      sheet.setColumnWidth(6, 16); sheet.setColumnWidth(7, 18); sheet.setColumnWidth(8, 18);

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        await saveFileBytes('batch_logs_$ts.xlsx', fileBytes);
        if (mounted) _snack('Excel exported successfully!', Colors.green.shade700);
      }
    } catch (e) {
      if (mounted) _snack('Excel export error: $e', Colors.red);
    }
  }

  Future<void> _exportPdf() async {
    if (_filtered.isEmpty) { _snack('No logs to export', Colors.orange); return; }
    try {
      final pdf = pw.Document();
      String dateRange = 'All Dates';
      if (_dateFrom != null || _dateTo != null) {
        dateRange = '${_dateFrom != null ? _fmtDate(_dateFrom!) : "Start"} to ${_dateTo != null ? _fmtDate(_dateTo!) : "Present"}';
      }

      final created = _filtered.where((l) => l.action == 'Created').length;
      final updated = _filtered.where((l) => l.action == 'Updated').length;

      final reasonCounts = <String, int>{};
      for (final l in _filtered) {
        if (l.reason.isNotEmpty) reasonCounts[l.reason] = (reasonCounts[l.reason] ?? 0) + 1;
      }

      final dataRows = _filtered.map((l) => [
        _fmtDateTime(l.dateTime), l.batchNumber, l.productName,
        l.action, l.reason, l.field, l.oldValue, l.newValue,
      ]).toList();

      const rowsPerPage = 22;
      final chunks = <List<List<String>>>[];
      for (var i = 0; i < dataRows.length; i += rowsPerPage) {
        chunks.add(dataRows.sublist(i, i + rowsPerPage > dataRows.length ? dataRows.length : i + rowsPerPage));
      }

      for (var pageIdx = 0; pageIdx < chunks.length; pageIdx++) {
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (pageIdx == 0) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(color: PdfColors.teal800, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('FlavianoPOS - PRO', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text('BATCH UPDATE LOGS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('Date Range: $dateRange', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                    pw.Text('Generated: ${_fmtDateTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey300)),
                  ]),
                ]),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(color: PdfColors.teal50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
                  _pdfStat('Total Logs', '${_filtered.length}'),
                  _pdfStat('Created', '$created'),
                  _pdfStat('Updated', '$updated'),
                  ...reasonCounts.entries.take(4).map((e) => _pdfStat(e.key, '${e.value}')),
                ]),
              ),
              pw.SizedBox(height: 8),
            ],
            if (pageIdx > 0) ...[
              pw.Text('Batch Logs (continued)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
              pw.SizedBox(height: 8),
            ],
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
              headerAlignment: pw.Alignment.center,
              cellStyle: const pw.TextStyle(fontSize: 6.5),
              cellAlignment: pw.Alignment.centerLeft,
              headerPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              headers: ['Date/Time', 'Batch #', 'Product', 'Action', 'Reason', 'Field', 'Old Value', 'New Value'],
              data: chunks[pageIdx],
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Total Logs: ${_filtered.length}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Page ${pageIdx + 1} of ${chunks.length}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('System-generated document from FlavianoPOS - PRO', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
            ]),
          ]),
        ));
      }

      final pdfBytes = await pdf.save();
      final ts = DateTime.now().millisecondsSinceEpoch;
      await saveFileBytes('batch_logs_$ts.pdf', pdfBytes);
      if (mounted) _snack('PDF exported successfully!', Colors.green.shade700);
    } catch (e) {
      if (mounted) _snack('PDF export error: $e', Colors.red);
    }
  }

  static pw.Widget _pdfStat(String label, String value) => pw.Column(children: [
    pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
    pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
  ]);

  @override
  Widget build(BuildContext context) {
    final title = widget.filterBatchNumber != null ? 'Logs: ${widget.filterBatchNumber}' : 'Batch Update Logs';
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700], foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export',
            onSelected: (v) {
              if (v == 'excel') _exportExcel();
              if (v == 'pdf') _exportPdf();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'excel', child: Row(children: [
                Icon(Icons.table_chart, color: Colors.green, size: 20), SizedBox(width: 10), Text('Export to Excel')])),
              const PopupMenuItem(value: 'pdf', child: Row(children: [
                Icon(Icons.picture_as_pdf, color: Colors.red, size: 20), SizedBox(width: 10), Text('Export to PDF')])),
            ],
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), child: Column(children: [
          TextField(controller: _searchCtrl, decoration: InputDecoration(
            hintText: 'Search batch#, product, reason...', prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _applyFilters(); }) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(vertical: 0), isDense: true, filled: true, fillColor: Colors.grey[100])),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: InkWell(onTap: () => _pickDate(true), child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: Colors.grey[100]),
              child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: Colors.grey), const SizedBox(width: 6),
                Text(_dateFrom != null ? _fmtDate(_dateFrom!) : 'From', style: TextStyle(fontSize: 13, color: _dateFrom != null ? Colors.black87 : Colors.grey))])))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('-')),
            Expanded(child: InkWell(onTap: () => _pickDate(false), child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: Colors.grey[100]),
              child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: Colors.grey), const SizedBox(width: 6),
                Text(_dateTo != null ? _fmtDate(_dateTo!) : 'To', style: TextStyle(fontSize: 13, color: _dateTo != null ? Colors.black87 : Colors.grey))])))),
            const SizedBox(width: 6),
            if (_dateFrom != null || _dateTo != null || _searchCtrl.text.isNotEmpty)
              IconButton(icon: const Icon(Icons.filter_alt_off, color: Colors.red, size: 22), onPressed: _clearFilters),
          ]),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${_filtered.length} log(s)', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            Row(children: [
              _statChip('Created', _filtered.where((l) => l.action == 'Created').length, Colors.green),
              const SizedBox(width: 6),
              _statChip('Updated', _filtered.where((l) => l.action == 'Updated').length, Colors.blue),
            ]),
          ],
        )),
        Expanded(child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text('No batch logs found', style: TextStyle(color: Colors.grey[500], fontSize: 16))]))
            : LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        showCheckboxColumn: false,
                        headingRowColor: WidgetStateProperty.all(Colors.teal.shade700),
                        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                        dataTextStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                        columnSpacing: 12, horizontalMargin: 10,
                        columns: const [
                          DataColumn(label: Text('Date/Time')),
                          DataColumn(label: Text('Batch #')),
                          DataColumn(label: Text('Product')),
                          DataColumn(label: Text('Action')),
                          DataColumn(label: Text('Reason')),
                          DataColumn(label: Text('Field')),
                          DataColumn(label: Text('Old')),
                          DataColumn(label: Text('New')),
                        ],
                        rows: List.generate(_filtered.length, (i) {
                          final l = _filtered[i];
                          return DataRow(
                            color: WidgetStateProperty.all(i.isEven ? Colors.white : Colors.grey.shade50),
                            cells: [
                              DataCell(Text(_fmtDateTime(l.dateTime), style: const TextStyle(fontSize: 11))),
                              DataCell(Text(l.batchNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(l.productName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                Text(l.productSku, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                              ])),
                              DataCell(_actionChip(l.action)),
                              DataCell(_reasonChip(l.reason)),
                              DataCell(Text(l.field, style: const TextStyle(fontSize: 11))),
                              DataCell(Text(l.oldValue, style: TextStyle(fontSize: 11, color: Colors.red[700], decoration: l.oldValue.isNotEmpty ? TextDecoration.lineThrough : null))),
                              DataCell(Text(l.newValue, style: TextStyle(fontSize: 11, color: Colors.green[700], fontWeight: FontWeight.w600))),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              )),
      ]),
    );
  }

  Widget _actionChip(String action) {
    Color bg, fg;
    switch (action) {
      case 'Created': bg = Colors.green.shade50; fg = Colors.green.shade700; break;
      case 'Updated': bg = Colors.blue.shade50; fg = Colors.blue.shade700; break;
      case 'Deleted': bg = Colors.red.shade50; fg = Colors.red.shade700; break;
      default: bg = Colors.orange.shade50; fg = Colors.orange.shade700; break;
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(action, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)));
  }

  Widget _reasonChip(String reason) {
    Color bg, fg;
    switch (reason.toUpperCase()) {
      case 'SOLD': bg = Colors.blue.shade50; fg = Colors.blue.shade700; break;
      case 'RETURN TO VENDOR': bg = Colors.purple.shade50; fg = Colors.purple.shade700; break;
      case 'DAMAGE': bg = Colors.red.shade50; fg = Colors.red.shade700; break;
      case 'CHARGED TO EMPLOYEE': bg = Colors.orange.shade50; fg = Colors.orange.shade700; break;
      case 'EXPIRED': bg = Colors.grey.shade200; fg = Colors.grey.shade700; break;
      case 'CORRECTION': bg = Colors.teal.shade50; fg = Colors.teal.shade700; break;
      case 'NEW BATCH': bg = Colors.green.shade50; fg = Colors.green.shade700; break;
      default: bg = Colors.grey.shade100; fg = Colors.grey.shade600; break;
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(reason.isEmpty ? '-' : reason, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: fg)));
  }

  Widget _statChip(String label, int count, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(8)),
    child: Text('$label: $count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)));
}
