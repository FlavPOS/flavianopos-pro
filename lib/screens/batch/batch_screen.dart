import 'package:flutter/material.dart';
import '../../services/device_assignment_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import '../../utils/download_helper.dart';
import '../../models/batch_model.dart';
import '../../models/batch_log_model.dart';
import 'add_batch_screen.dart';
import 'batch_log_screen.dart';

class BatchScreen extends StatefulWidget {
  const BatchScreen({super.key});
  @override
  State<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<BatchScreen> {
  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  List<ProductBatch> _batches = [];
  bool _loading = true;
  String _branchId = '';
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filterStatus = 'All';

  List<ProductBatch> get _filtered {
    var list = _batches.where((b) {
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        if (!b.productName.toLowerCase().contains(q) &&
            !b.batchNumber.toLowerCase().contains(q) &&
            !b.productSku.toLowerCase().contains(q) &&
            !b.supplier.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_filterStatus == 'Expired') return b.isExpired;
      if (_filterStatus == 'Near Expiry') return b.isNearExpiry;
      if (_filterStatus == 'Warning') return b.isWarning;
      if (_filterStatus == 'Fresh') return b.isFresh;
      if (_filterStatus == 'Depleted') return b.quantity == 0;
      return true;
    }).toList();
    list.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return list;
  }

  int get _expiredCount => _batches.where((b) => b.isExpired).length;
  int get _nearExpiryCount => _batches.where((b) => b.isNearExpiry).length;
  int get _freshCount => _batches.where((b) => b.isFresh).length;

  void _addBatch() async {
    final result = await Navigator.push(context,
      MaterialPageRoute(builder: (context) => const AddBatchScreen()));
    if (result != null && result is ProductBatch) {
      ProductBatch.addBatch(result);
      _loadBatches();
      _snack('Batch ${result.batchNumber} added!');
    }
  }

  void _editBatch(ProductBatch batch) async {
    final result = await Navigator.push(context,
      MaterialPageRoute(builder: (context) => AddBatchScreen(batch: batch)));
    if (result != null && result is ProductBatch) {
      ProductBatch.updateBatch(batch.id, result);
      setState(() {
        final i = _batches.indexWhere((b) => b.id == batch.id);
        if (i >= 0) _batches[i] = result;
      });
      _snack('Batch updated!');
    }
  }

  void _deleteBatch(ProductBatch batch) {
    String selectedReason = 'ZERO STOCK';
    final customCtrl = TextEditingController();
    bool isOther = false;
    const reasons = ['ZERO STOCK', 'EXPIRED', 'DAMAGE', 'RETURN TO VENDOR', 'DISCONTINUE', 'OTHER'];
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.delete_forever, color: Colors.red, size: 28),
          const SizedBox(width: 10),
          const Expanded(child: Text('Delete Batch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Batch: ${batch.batchNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('Product: ${batch.productName}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              Text('SKU: ${batch.productSku} | Qty: ${batch.quantity}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ]),
          ),
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerLeft, child: Text('Reason for Deletion:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          const SizedBox(height: 8),
          ...(reasons.map((r) => RadioListTile<String>(
            value: r, groupValue: selectedReason, dense: true, visualDensity: VisualDensity.compact,
            activeColor: Colors.red[700],
            title: Text(r, style: const TextStyle(fontSize: 13)),
            onChanged: (v) => setDlgState(() { selectedReason = v!; isOther = v == 'OTHER'; }),
          ))),
          if (isOther) ...[
            const SizedBox(height: 8),
            TextField(controller: customCtrl, autofocus: true,
              decoration: InputDecoration(hintText: 'Enter custom reason...', isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          ],
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Confirm Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              final reason = isOther ? (customCtrl.text.trim().isEmpty ? 'OTHER' : customCtrl.text.trim().toUpperCase()) : selectedReason;
              await BatchLogStorage.saveLogs([
                BatchLog(
                  id: 'LOG-${DateTime.now().millisecondsSinceEpoch}',
                  batchId: batch.id, batchNumber: batch.batchNumber,
                  productName: batch.productName, productSku: batch.productSku,
                  action: 'Deleted', reason: reason, field: 'Batch Removed',
                  oldValue: 'Qty: ${batch.quantity}, Cost: ${batch.costPrice.toStringAsFixed(2)}',
                  newValue: '', dateTime: DateTime.now(),
                ),
              ]);
              ProductBatch.deleteBatch(batch.id);
              _loadBatches();
              if (context.mounted) Navigator.pop(ctx);
              _snack('Batch deleted & logged');
            },
          ),
        ],
      ),
    ));
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) => '${_pad(d.month)}/${_pad(d.day)}/${d.year}';
  String _fmtDateTime(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)} ${_pad(d.hour)}:${_pad(d.minute)}';

  Future<void> _exportExcel() async {
    final data = _filtered;
    if (data.isEmpty) { _snack('No batches to export'); return; }
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Batch Management'];
      excel.delete('Sheet1');

      final hStyle = xl.CellStyle(bold: true, fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: xl.ExcelColor.fromHexString('#00695C'), horizontalAlign: xl.HorizontalAlign.Center);
      final titleStyle = xl.CellStyle(bold: true, fontSize: 14);
      final subStyle = xl.CellStyle(bold: true, fontSize: 11, fontColorHex: xl.ExcelColor.fromHexString('#555555'));
      final expStyle = xl.CellStyle(fontColorHex: xl.ExcelColor.fromHexString('#D32F2F'), bold: true);
      final nearStyle = xl.CellStyle(fontColorHex: xl.ExcelColor.fromHexString('#E65100'), bold: true);
      final freshStyle = xl.CellStyle(fontColorHex: xl.ExcelColor.fromHexString('#2E7D32'), bold: true);

      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = xl.TextCellValue('FlavianoPOS - PRO - Batch Management Report');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = xl.TextCellValue(
        'Filter: $_filterStatus | Generated: ${_fmtDateTime(DateTime.now())} | Total: ${data.length} batches');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = subStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = xl.TextCellValue(
        'Expired: $_expiredCount | Near Expiry: $_nearExpiryCount | Fresh: $_freshCount');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).cellStyle = subStyle;

      final headers = ['#', 'Product', 'SKU', 'Batch #', 'MFG Date', 'Expiry Date', 'Days Left', 'Status', 'Qty', 'Original Qty', 'Cost Price', 'Supplier', 'Notes'];
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 4));
        cell.value = xl.TextCellValue(headers[c]);
        cell.cellStyle = hStyle;
      }

      for (var i = 0; i < data.length; i++) {
        final b = data[i];
        final row = i + 5;
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.IntCellValue(i + 1);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.TextCellValue(b.productName);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.TextCellValue(b.productSku);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.TextCellValue(b.batchNumber);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xl.TextCellValue(_fmtDate(b.manufacturedDate));
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = xl.TextCellValue(_fmtDate(b.expiryDate));
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = xl.IntCellValue(b.daysUntilExpiry);
        final statusCell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row));
        statusCell.value = xl.TextCellValue(b.statusLabel);
        if (b.isExpired) { statusCell.cellStyle = expStyle; }
        else if (b.isNearExpiry) { statusCell.cellStyle = nearStyle; }
        else if (b.isFresh) { statusCell.cellStyle = freshStyle; }
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = xl.IntCellValue(b.quantity);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = xl.IntCellValue(b.originalQty);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = xl.DoubleCellValue(b.costPrice);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row)).value = xl.TextCellValue(b.supplier);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row)).value = xl.TextCellValue(b.notes);
      }

      sheet.setColumnWidth(0, 5); sheet.setColumnWidth(1, 22); sheet.setColumnWidth(2, 12);
      sheet.setColumnWidth(3, 16); sheet.setColumnWidth(4, 12); sheet.setColumnWidth(5, 12);
      sheet.setColumnWidth(6, 10); sheet.setColumnWidth(7, 14); sheet.setColumnWidth(8, 8);
      sheet.setColumnWidth(9, 10); sheet.setColumnWidth(10, 12); sheet.setColumnWidth(11, 18);
      sheet.setColumnWidth(12, 20);

      final bytes = excel.save();
      if (bytes != null) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        await saveFileBytes('batch_management_$ts.xlsx', bytes);
        if (mounted) _snack('Excel exported!');
      }
    } catch (e) {
      if (mounted) _snack('Export error: $e');
    }
  }

  Future<void> _exportPdf() async {
    final data = _filtered;
    if (data.isEmpty) { _snack('No batches to export'); return; }
    try {
      final pdf = pw.Document();

      final dataRows = data.asMap().entries.map((e) {
        final b = e.value;
        return [
          '${e.key + 1}', b.productName, b.productSku, b.batchNumber,
          _fmtDate(b.manufacturedDate), _fmtDate(b.expiryDate),
          '${b.daysUntilExpiry}d', b.statusLabel,
          '${b.quantity}/${b.originalQty}', b.costPrice.toStringAsFixed(2), b.supplier,
        ];
      }).toList();

      const rowsPerPage = 20;
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
                    pw.Text('BATCH MANAGEMENT REPORT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('Filter: $_filterStatus', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                    pw.Text('Generated: ${_fmtDateTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey300)),
                  ]),
                ]),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(color: PdfColors.teal50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
                  _pdfStat('Total', '${data.length}'),
                  _pdfStat('Expired', '$_expiredCount'),
                  _pdfStat('Near Expiry', '$_nearExpiryCount'),
                  _pdfStat('Fresh', '$_freshCount'),
                ]),
              ),
              pw.SizedBox(height: 8),
            ],
            if (pageIdx > 0) ...[
              pw.Text('Batch Management (continued)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
              pw.SizedBox(height: 8),
            ],
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
              headerAlignment: pw.Alignment.center,
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {0: pw.Alignment.center, 6: pw.Alignment.center, 8: pw.Alignment.center, 9: pw.Alignment.centerRight},
              headerPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              headers: ['#', 'Product', 'SKU', 'Batch #', 'MFG', 'Expiry', 'Days', 'Status', 'Qty', 'Cost', 'Supplier'],
              data: chunks[pageIdx],
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Total: ${data.length} batches', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Page ${pageIdx + 1} of ${chunks.length}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('System-generated from FlavianoPOS - PRO', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
            ]),
          ]),
        ));
      }

      final pdfBytes = await pdf.save();
      final ts = DateTime.now().millisecondsSinceEpoch;
      await saveFileBytes('batch_management_$ts.pdf', pdfBytes);
      if (mounted) _snack('PDF exported!');
    } catch (e) {
      if (mounted) _snack('Export error: $e');
    }
  }

  static pw.Widget _pdfStat(String label, String value) => pw.Column(children: [
    pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
    pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
  ]);

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  Color _statusColor(ProductBatch b) {
    if (b.isExpired) return Colors.red;
    if (b.quantity == 0) return Colors.grey;
    if (b.isNearExpiry) return Colors.orange;
    if (b.isWarning) return Colors.amber;
    return Colors.green;
  }

  IconData _statusIcon(ProductBatch b) {
    if (b.isExpired) return Icons.error;
    if (b.quantity == 0) return Icons.block;
    if (b.isNearExpiry) return Icons.warning;
    if (b.isWarning) return Icons.access_time;
    return Icons.check_circle;
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _loadBatches() async {
    setState(() => _loading = true);
    final assign = await DeviceAssignmentService().read();
    _branchId = (assign['branchId'] ?? '').toString();
    debugPrint('[BATCH-LIST] Loading for branchId: $_branchId');
    await ProductBatch.loadFromDB(branchId: _branchId);
    if (!mounted) return;
    setState(() {
      _batches = List.from(ProductBatch.allBatches);
      _loading = false;
    });
    debugPrint('[BATCH-LIST] Loaded ${_batches.length} batches');
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['All', 'Expired', 'Near Expiry', 'Warning', 'Fresh', 'Depleted'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Management', style: TextStyle(fontWeight: FontWeight.bold)),
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
          IconButton(icon: const Icon(Icons.history), tooltip: 'Batch Logs',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BatchLogScreen()))),
        ],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12),
          child: Row(children: [
            _statCard('Total', '${_batches.length}', Icons.inventory_2, Colors.teal),
            const SizedBox(width: 6),
            _statCard('Expired', '$_expiredCount', Icons.error, Colors.red),
            const SizedBox(width: 6),
            _statCard('Near Exp', '$_nearExpiryCount', Icons.warning, Colors.orange),
            const SizedBox(width: 6),
            _statCard('Fresh', '$_freshCount', Icons.check_circle, Colors.green),
          ]),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search batch, product, supplier...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty ? IconButton(icon: const Icon(Icons.clear),
                onPressed: () { _searchCtrl.clear; setState(() => _query = ''); }) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(vertical: 0)),
            onChanged: (v) => setState(() => _query = v)),
        ),
        SizedBox(height: 44,
          child: ListView(scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: filters.map((f) {
              final sel = _filterStatus == f;
              return Padding(padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f, style: TextStyle(fontSize: 12,
                    color: sel ? Colors.white : Colors.teal[700], fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  selected: sel,
                  selectedColor: Colors.teal[700],
                  checkmarkColor: Colors.white,
                  onSelected: (_) => setState(() => _filterStatus = f)),
              );
            }).toList()),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Text('${_filtered.length} batches', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const Spacer(),
            Text('Sorted by: Expiry (FEFO)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ]),
        ),
        Expanded(
          child: _filtered.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text('No batches found', style: TextStyle(color: Colors.grey[500])),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final b = _filtered[i];
                  final sc = _statusColor(b);
                  final si = _statusIcon(b);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: sc.withAlpha(80))),
                    child: InkWell(
                      onTap: () => _editBatch(b),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: sc.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                              child: Icon(si, color: sc, size: 24)),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(b.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('${b.batchNumber}  |  SKU: ${b.productSku}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ])),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: sc.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                              child: Text(b.statusLabel,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sc))),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') _editBatch(b);
                                if (v == 'delete') _deleteBatch(b);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                              ]),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            _dateChip(Icons.factory, 'MFG: ${_fmtDate(b.manufacturedDate)}', Colors.blue),
                            const SizedBox(width: 6),
                            _dateChip(Icons.event_busy, 'EXP: ${_fmtDate(b.expiryDate)}', sc),
                            const Spacer(),
                            Text('${b.quantity} / ${b.originalQty} pcs',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: b.isExpired ? 1.0 : (1 - (b.daysUntilExpiry / 365)).clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(sc))),
                          const SizedBox(height: 4),
                          Row(children: [
                            Text(b.expiryText, style: TextStyle(fontSize: 10, color: sc, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            if (b.supplier.isNotEmpty)
                              Text(b.supplier, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                          ]),
                        ]),
                      ),
                    ),
                  );
                }),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBatch,
        backgroundColor: Colors.teal[700], foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Batch')),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) => Expanded(
    child: Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600]), textAlign: TextAlign.center),
        ]))));

  Widget _dateChip(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color), const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    ]));
}
