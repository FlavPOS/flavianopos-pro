// ============================================================
// TRANSFER HISTORY - FlavianoPOS - PRO
// View all transfers, filter, export Excel/PDF
// ============================================================
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import '../../models/product_model.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import '../../utils/download_helper.dart';
import '../../models/stock_transfer_model.dart';
import 'transfer_detail_screen.dart';

class TransferHistoryScreen extends StatefulWidget {
  final String currentUser;
  const TransferHistoryScreen({super.key, required this.currentUser});
  @override
  State<TransferHistoryScreen> createState() => _TransferHistoryScreenState();
}

class _TransferHistoryScreenState extends State<TransferHistoryScreen> {
  List<StockTransfer> _allTransfers = [];
  bool _isLoading = true;
  String _statusFilter = 'All';
  final _searchCtrl = TextEditingController();
  String _query = '';

  final _statuses = ['All', 'In Transit', 'Received', 'Cancelled'];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final all = await StockTransferStorage.getAll();
    setState(() { _allTransfers = all; _isLoading = false; });
  }

  List<StockTransfer> get _filtered {
    return _allTransfers.where((t) {
      if (_statusFilter != 'All' && t.status != _statusFilter) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        return t.transferNo.toLowerCase().contains(q) ||
          t.fromBranchName.toLowerCase().contains(q) ||
          t.toBranchName.toLowerCase().contains(q) ||
          t.preparedBy.toLowerCase().contains(q) ||
          t.items.any((i) => i.itemName.toLowerCase().contains(q) || i.batchNumber.toLowerCase().contains(q));
      }
      return true;
    }).toList();
  }

  void _snack(String msg, [Color? bg]) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  String _pad(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) => '${_pad(d.month)}/${_pad(d.day)}/${d.year}';
  String _fmtDateTime(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)} ${_pad(d.hour)}:${_pad(d.minute)}';

  Color _statusColor(String status) {
    switch (status) {
      case 'In Transit': return Colors.orange;
      case 'Received': return Colors.green;
      case 'Cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'In Transit': return Icons.local_shipping;
      case 'Received': return Icons.check_circle;
      case 'Cancelled': return Icons.cancel;
      default: return Icons.drafts;
    }
  }

  // ---- Cancel Transfer ----
  Future<void> _cancelTransfer(StockTransfer t) async {
    if (t.isReceived) { _snack('Cannot cancel received transfer', Colors.red); return; }
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Cancel Transfer'),
      content: Text('Cancel ${t.transferNo}? Stock will be restored to source branch.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Cancel Transfer')),
      ],
    ));
    if (confirmed != true) return;

    // Restore stock to source branch
    for (final item in t.items) {
      final products = Product.allProducts;
      final pIdx = products.indexWhere((p) => p.id == item.itemId);
      if (pIdx >= 0) {
        final p = products[pIdx];
        Product.updateProduct(p.id, Product(
          id: p.id, name: p.name, sku: p.sku, category: p.category,
          sellingPrice: p.sellingPrice, costPrice: p.costPrice, stockQty: p.stockQty + item.qtyTransferred,
          reorderLevel: p.reorderLevel, barcode: p.barcode,
        ));
      }
    }

    t.status = 'Cancelled';
    t.updatedAt = DateTime.now();
    await StockTransferStorage.updateTransfer(t);
    await _load();
    if (mounted) _snack('${t.transferNo} cancelled, stock restored', Colors.orange);
  }

  // ---- Export Excel ----
  Future<void> _exportExcel() async {
    final data = _filtered;
    if (data.isEmpty) { _snack('No transfers to export', Colors.orange); return; }
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Transfer History'];
      excel.delete('Sheet1');

      final hStyle = xl.CellStyle(bold: true, fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: xl.ExcelColor.fromHexString('#1565C0'), horizontalAlign: xl.HorizontalAlign.Center);
      final titleStyle = xl.CellStyle(bold: true, fontSize: 14);
      final subStyle = xl.CellStyle(bold: true, fontSize: 11, fontColorHex: xl.ExcelColor.fromHexString('#555555'));

      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = xl.TextCellValue('FlavianoPOS - PRO - Stock Transfer History');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = xl.TextCellValue(
        'Filter: $_statusFilter | Generated: ${_fmtDateTime(DateTime.now())} | Total: ${data.length}');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = subStyle;

      final headers = ['#', 'Transfer No.', 'Date', 'From Branch', 'To Branch', 'Items', 'Total Qty', 'Total Cost', 'Status', 'Prepared By', 'Received By', 'Received Date'];
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3));
        cell.value = xl.TextCellValue(headers[c]);
        cell.cellStyle = hStyle;
      }

      for (var i = 0; i < data.length; i++) {
        final t = data[i];
        final row = i + 4;
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.IntCellValue(i + 1);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.TextCellValue(t.transferNo);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.TextCellValue(_fmtDate(t.transferDate));
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.TextCellValue(t.fromBranchName);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xl.TextCellValue(t.toBranchName);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = xl.IntCellValue(t.totalItems);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = xl.IntCellValue(t.totalQtyTransferred);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = xl.DoubleCellValue(t.totalCost);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = xl.TextCellValue(t.status);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = xl.TextCellValue(t.preparedBy);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = xl.TextCellValue(t.receivedBy);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row)).value = xl.TextCellValue(t.receivedDate != null ? _fmtDate(t.receivedDate!) : '');
      }

      // Item details sheet
      final detailSheet = excel['Transfer Items'];
      final dHeaders = ['Transfer No.', 'Item Code', 'Item Name', 'Batch #', 'MFG Date', 'Expiry Date', 'Category', 'Qty Transferred', 'Qty Received', 'Cost', 'Total Cost'];
      for (var c = 0; c < dHeaders.length; c++) {
        final cell = detailSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = xl.TextCellValue(dHeaders[c]);
        cell.cellStyle = hStyle;
      }
      var dRow = 1;
      for (final t in data) {
        for (final item in t.items) {
          detailSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: dRow)).value = xl.TextCellValue(t.transferNo);
          detailSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: dRow)).value = xl.TextCellValue(item.itemCode);
          detailSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: dRow)).value = xl.TextCellValue(item.itemName);
          detailSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: dRow)).value = xl.TextCellValue(item.batchNumber);
          detailSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: dRow)).value = xl.TextCellValue(item.fmtDate(item.manufacturedDate));
          detailSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: dRow)).value = xl.TextCellValue(item.fmtDate(item.expiryDate));
          detailSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: dRow)).value = xl.TextCellValue(item.category);
          detailSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: dRow)).value = xl.IntCellValue(item.qtyTransferred);
          detailSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: dRow)).value = xl.IntCellValue(item.qtyReceived);
          detailSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: dRow)).value = xl.DoubleCellValue(item.cost);
          detailSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: dRow)).value = xl.DoubleCellValue(item.totalCost);
          dRow++;
        }
      }

      sheet.setColumnWidth(0, 5); sheet.setColumnWidth(1, 20); sheet.setColumnWidth(2, 12);
      sheet.setColumnWidth(3, 18); sheet.setColumnWidth(4, 18); sheet.setColumnWidth(5, 8);
      sheet.setColumnWidth(6, 10); sheet.setColumnWidth(7, 12); sheet.setColumnWidth(8, 12);
      sheet.setColumnWidth(9, 14); sheet.setColumnWidth(10, 14); sheet.setColumnWidth(11, 14);

      final bytes = excel.save();
      if (bytes != null) {
        await saveFileBytes('transfer_history_${DateTime.now().millisecondsSinceEpoch}.xlsx', bytes);
        if (mounted) _snack('Excel exported (2 sheets)!', Colors.green.shade700);
      }
    } catch (e) { if (mounted) _snack('Export error: $e', Colors.red); }
  }

  // ---- Export PDF (Landscape) ----
  Future<void> _exportPdf() async {
    final data = _filtered;
    if (data.isEmpty) { _snack('No transfers to export', Colors.orange); return; }
    try {
      final pdf = pw.Document();
      final rows = data.asMap().entries.map((e) {
        final t = e.value;
        return ['${e.key + 1}', t.transferNo, _fmtDate(t.transferDate),
          t.fromBranchName, t.toBranchName, '${t.totalItems}',
          '${t.totalQtyTransferred}', t.totalCost.toStringAsFixed(2),
          t.status, t.preparedBy, t.receivedBy];
      }).toList();

      const rpp = 18;
      final chunks = <List<List<String>>>[];
      for (var i = 0; i < rows.length; i += rpp) {
        chunks.add(rows.sublist(i, i + rpp > rows.length ? rows.length : i + rpp));
      }

      for (var p = 0; p < chunks.length; p++) {
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (p == 0) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(color: PdfColors.blue800, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('FlavianoPOS - PRO', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text('STOCK TRANSFER HISTORY', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('Filter: $_statusFilter', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                    pw.Text('Generated: ${_fmtDateTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey300)),
                  ]),
                ]),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
                  _pdfStat('Total', '${data.length}'),
                  _pdfStat('In Transit', '${data.where((t) => t.isInTransit).length}'),
                  _pdfStat('Received', '${data.where((t) => t.isReceived).length}'),
                  _pdfStat('Cancelled', '${data.where((t) => t.isCancelled).length}'),
                ]),
              ),
              pw.SizedBox(height: 8),
            ],
            if (p > 0) ...[
              pw.Text('Transfer History (continued)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.SizedBox(height: 8),
            ],
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              headerAlignment: pw.Alignment.center,
              cellStyle: const pw.TextStyle(fontSize: 6.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {0: pw.Alignment.center, 5: pw.Alignment.center, 6: pw.Alignment.center, 7: pw.Alignment.centerRight},
              headerPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              headers: ['#', 'Transfer No.', 'Date', 'From', 'To', 'Items', 'Qty', 'Cost', 'Status', 'Prepared', 'Received'],
              data: chunks[p],
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Total: ${data.length} transfers', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Page ${p + 1} of ${chunks.length}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('FlavianoPOS - PRO', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
            ]),
          ]),
        ));
      }

      final pdfBytes = await pdf.save();
      await saveFileBytes('transfer_history_${DateTime.now().millisecondsSinceEpoch}.pdf', pdfBytes);
      if (mounted) _snack('PDF exported!', Colors.green.shade700);
    } catch (e) { if (mounted) _snack('Export error: $e', Colors.red); }
  }

  static pw.Widget _pdfStat(String label, String value) => pw.Column(children: [
    pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
    pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
  ]);

  @override
  Widget build(BuildContext context) {
    final data = _filtered;
    final inTransitCount = _allTransfers.where((t) => t.isInTransit).length;
    final receivedCount = _allTransfers.where((t) => t.isReceived).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800], foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download), tooltip: 'Export',
            onSelected: (v) { if (v == 'excel') _exportExcel(); if (v == 'pdf') _exportPdf(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'excel', child: Row(children: [
                Icon(Icons.table_chart, color: Colors.green, size: 20), SizedBox(width: 10), Text('Export to Excel')])),
              const PopupMenuItem(value: 'pdf', child: Row(children: [
                Icon(Icons.picture_as_pdf, color: Colors.red, size: 20), SizedBox(width: 10), Text('Export to PDF')])),
            ],
          ),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator())
        : Column(children: [
          // Stats
          Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            _statCard('Total', '${_allTransfers.length}', Icons.swap_horiz, Colors.blue),
            const SizedBox(width: 6),
            _statCard('In Transit', '$inTransitCount', Icons.local_shipping, Colors.orange),
            const SizedBox(width: 6),
            _statCard('Received', '$receivedCount', Icons.check_circle, Colors.green),
          ])),
          // Search
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(controller: _searchCtrl,
              decoration: InputDecoration(hintText: 'Search transfer, branch, item, batch...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty ? IconButton(icon: const Icon(Icons.clear),
                  onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); }) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true, filled: true, fillColor: Colors.grey[100]),
              onChanged: (v) => setState(() => _query = v))),
          // Status filter chips
          SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: _statuses.map((s) {
              final sel = _statusFilter == s;
              return Padding(padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s, style: TextStyle(fontSize: 12,
                    color: sel ? Colors.white : Colors.blue[800], fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  selected: sel, selectedColor: Colors.blue[800], checkmarkColor: Colors.white,
                  onSelected: (_) => setState(() => _statusFilter = s)));
            }).toList())),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('${data.length} transfer(s)', style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
          // List
          Expanded(child: data.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.swap_horiz, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text('No transfers found', style: TextStyle(color: Colors.grey[500])),
              ]))
            : RefreshIndicator(onRefresh: _load, child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: data.length,
                itemBuilder: (_, i) {
                  final t = data[i];
                  final sc = _statusColor(t.status);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: sc.withAlpha(60))),
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(
                          builder: (_) => TransferDetailScreen(transfer: t, currentUser: widget.currentUser)));
                        _load();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: sc.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                            child: Icon(_statusIcon(t.status), color: sc, size: 22)),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.transferNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(_fmtDate(t.transferDate), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          ])),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: sc.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                            child: Text(t.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sc))),
                          if (t.isInTransit) PopupMenuButton<String>(
                            onSelected: (v) { if (v == 'cancel') _cancelTransfer(t); },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'cancel', child: Text('Cancel', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.store, size: 14, color: Colors.grey[500]),
                          Text(' ${t.fromBranchName}', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward, size: 12, color: sc),
                          const SizedBox(width: 6),
                          Icon(Icons.store_mall_directory, size: 14, color: Colors.grey[500]),
                          Text(' ${t.toBranchName}', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Text('${t.totalItems} items', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          const SizedBox(width: 10),
                          Text('Qty: ${t.totalQtyTransferred}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          const SizedBox(width: 10),
                          Text('Cost: ${t.totalCost.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          const Spacer(),
                          Text(t.preparedBy, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                        ]),
                      ])),
                    ),
                  );
                },
              )),
          ),
        ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) => Expanded(
    child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
      ])));
}
