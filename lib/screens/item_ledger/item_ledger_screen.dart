import '../../utils/download_helper.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import '../../models/product_model.dart';
import '../../models/transaction_model.dart';
import '../stock_adjustment/adjustment_model.dart';
import '../../models/stock_transfer_model.dart';
import '../../models/exchange_model.dart';
import '../receive_delivery/delivery_model.dart';

class LedgerEntry {
  final DateTime date;
  final String type;
  final String reference;
  final int qtyIn;
  final int qtyOut;
  int balance;
  LedgerEntry({required this.date, required this.type, required this.reference, this.qtyIn = 0, this.qtyOut = 0, this.balance = 0});
}

class ItemLedgerScreen extends StatefulWidget {
  final List<Product> products;
  const ItemLedgerScreen({super.key, required this.products});
  @override
  State<ItemLedgerScreen> createState() => _ItemLedgerScreenState();
}

class _ItemLedgerScreenState extends State<ItemLedgerScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Product? _selectedProduct;
  List<LedgerEntry> _ledgerEntries = [];
  bool _isLoading = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return [];
    return widget.products.where((p) =>
        p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p.sku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p.barcode.contains(_searchQuery)).toList();
  }

  void _selectProduct(Product p) {
    setState(() { _selectedProduct = p; _searchQuery = ''; _searchCtrl.text = p.name; });
    _buildLedger();
  }

  Future<void> _buildLedger() async {
    if (_selectedProduct == null) return;
    setState(() => _isLoading = true);
    final p = _selectedProduct!;
    final List<LedgerEntry> entries = [];

    final txns = Transaction.allTransactions;
    for (final t in txns) {
      for (final item in t.items) {
        if (item.sku == p.sku) {
          if (t.status == 'voided') {
            entries.add(LedgerEntry(date: t.dateTime, type: 'Sale', reference: t.id, qtyOut: item.qty));
            entries.add(LedgerEntry(date: t.voidedAt ?? t.dateTime, type: 'Void', reference: '${t.id} (Voided)', qtyIn: item.qty));
          } else if (t.status == 'refunded') {
            entries.add(LedgerEntry(date: t.dateTime, type: 'Sale', reference: t.id, qtyOut: item.qty));
            entries.add(LedgerEntry(date: t.refundedAt ?? t.dateTime, type: 'Refund', reference: '${t.id} (Refunded)', qtyIn: item.qty));
          } else {
            entries.add(LedgerEntry(date: t.dateTime, type: 'Sale', reference: t.id, qtyOut: item.qty));
          }
        }
      }
    }

    try {
      final deliveries = await DeliveryStorage.getAll();
      for (final d in deliveries) {
        for (final item in d.items) {
          if (item.sku == p.sku || item.productId == p.id) {
            entries.add(LedgerEntry(date: d.dateTime, type: 'Delivery', reference: d.refNumber, qtyIn: item.quantity));
          }
        }
      }
    } catch (_) {}

    try {
      final adjustments = await AdjustmentStorage.getAll();
      for (final a in adjustments) {
        if (a.sku == p.sku) {
          final isIn = a.adjustmentType.toLowerCase().contains('add') || a.adjustmentType.toLowerCase().contains('in');
          entries.add(LedgerEntry(date: a.dateTime, type: 'Adjustment', reference: a.id,
            qtyIn: isIn ? a.quantity : 0, qtyOut: isIn ? 0 : a.quantity));
        }
      }
    } catch (_) {}

    // Stock Transfers (Inbound & Outbound)
    try {
      final transfers = await StockTransferStorage.getAll();
      for (final tr in transfers) {
        if (tr.status == 'Cancelled') continue;
        for (final item in tr.items) {
          if (item.itemCode == p.sku) {
            // Outbound (from this branch)
            entries.add(LedgerEntry(date: tr.transferDate, type: 'Transfer Out',
              reference: '${tr.transferNo} -> ${tr.toBranchName}', qtyOut: item.qtyTransferred));
            // Inbound (received)
            if (tr.status == 'Received' && item.qtyReceived > 0) {
              entries.add(LedgerEntry(date: tr.receivedDate ?? tr.transferDate, type: 'Transfer In',
                reference: '${tr.transferNo} <- ${tr.fromBranchName}', qtyIn: item.qtyReceived));
            }
          }
        }
      }
    } catch (_) {}



    // ═══ EXCHANGE TRACKING ═══
    try {
      final exchanges = await Exchange.getAll();
      for (final exc in exchanges) {
        final excDate = DateTime.tryParse(exc.dateCreated) ?? DateTime.now();

        // RETURNED item (stock came back IN)
        if (exc.returnedItemSku == p.sku) {
          entries.add(LedgerEntry(
            date: excDate,
            type: 'Exchange In',
            reference: '${exc.exchangeNumber} (Returned)',
            qtyIn: exc.returnedQty,
          ));
        }

        // NEW items (stock went OUT to customer)
        // Multi-item format: "Item1 x2 | Item2 x1"
        // SKU format: "SKU1 | SKU2"
        final skus = exc.newItemSku.split(' | ').map((s) => s.trim()).toList();
        final names = exc.newItemName.split(' | ').map((s) => s.trim()).toList();

        for (int i = 0; i < skus.length; i++) {
          if (skus[i] == p.sku) {
            // Parse quantity from name (format: "Product Name x2")
            int qty = 1;
            if (i < names.length) {
              final match = RegExp(r'x(\d+)$').firstMatch(names[i]);
              if (match != null) {
                qty = int.tryParse(match.group(1) ?? '1') ?? 1;
              }
            }
            entries.add(LedgerEntry(
              date: excDate,
              type: 'Exchange Out',
              reference: '${exc.exchangeNumber} (Replacement)',
              qtyOut: qty,
            ));
          }
        }
      }
    } catch (_) {}

    entries.sort((a, b) => a.date.compareTo(b.date));

    final totalIn = entries.fold(0, (s, e) => s + e.qtyIn);
    final totalOut = entries.fold(0, (s, e) => s + e.qtyOut);
    final beginningStock = p.stockQty - totalIn + totalOut;

    final List<LedgerEntry> finalEntries = [];
    finalEntries.add(LedgerEntry(date: entries.isNotEmpty ? entries.first.date.subtract(const Duration(seconds: 1)) : DateTime.now(),
      type: 'Beginning', reference: 'Opening Balance', balance: beginningStock));

    int running = beginningStock;
    for (final e in entries) {
      running = running + e.qtyIn - e.qtyOut;
      e.balance = running;
      finalEntries.add(e);
    }

    List<LedgerEntry> filtered = finalEntries;
    if (_dateFrom != null || _dateTo != null) {
      filtered = finalEntries.where((e) {
        if (e.type == 'Beginning') return true;
        if (_dateFrom != null) {
          final start = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
          if (e.date.isBefore(start)) return false;
        }
        if (_dateTo != null) {
          final end = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
          if (e.date.isAfter(end)) return false;
        }
        return true;
      }).toList();
    }

    setState(() { _ledgerEntries = filtered; _isLoading = false; });
  }

  Future<void> _pickDate(bool isFrom) async {
    final d = await showDatePicker(context: context, initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) { setState(() { if (isFrom) { _dateFrom = d; } else { _dateTo = d; } }); _buildLedger(); }
  }

  void _clearFilters() { setState(() { _dateFrom = null; _dateTo = null; }); _buildLedger(); }

  // ══════════════════════════════════════════════
  //  EXPORT TO EXCEL
  // ══════════════════════════════════════════════
  Future<void> _exportExcel() async {
    if (_ledgerEntries.isEmpty || _selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export')));
      return;
    }
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Item Ledger'];
      excel.delete('Sheet1');

      final headerStyle = xl.CellStyle(
        bold: true,
        fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: xl.ExcelColor.fromHexString('#1565C0'),
        horizontalAlign: xl.HorizontalAlign.Center,
      );
      final titleStyle = xl.CellStyle(bold: true, fontSize: 14);
      final subtitleStyle = xl.CellStyle(bold: true, fontSize: 11, fontColorHex: xl.ExcelColor.fromHexString('#555555'));

      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = xl.TextCellValue('Item Ledger Report');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = xl.TextCellValue('Product: ${_selectedProduct!.name}');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = subtitleStyle;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = xl.TextCellValue('SKU: ${_selectedProduct!.sku} | Current Stock: ${_selectedProduct!.stockQty}');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).cellStyle = subtitleStyle;

      String dateRange = 'Date Range: All';
      if (_dateFrom != null || _dateTo != null) {
        dateRange = 'Date Range: ${_dateFrom != null ? _fmtDate(_dateFrom!) : "Start"} to ${_dateTo != null ? _fmtDate(_dateTo!) : "Present"}';
      }
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value = xl.TextCellValue(dateRange);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).cellStyle = subtitleStyle;

      final headers = ['Date', 'Type', 'Reference', 'Qty In', 'Qty Out', 'Balance'];
      for (var c = 0; c < headers.length; c++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 5));
        cell.value = xl.TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
      }

      for (var i = 0; i < _ledgerEntries.length; i++) {
        final e = _ledgerEntries[i];
        final row = i + 6;
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
            xl.TextCellValue(e.type == 'Beginning' ? '-' : _fmtDateTime(e.date));
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.TextCellValue(e.type);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.TextCellValue(e.reference);
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
            e.qtyIn > 0 ? xl.IntCellValue(e.qtyIn) : xl.TextCellValue('');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
            e.qtyOut > 0 ? xl.IntCellValue(e.qtyOut) : xl.TextCellValue('');
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = xl.IntCellValue(e.balance);

        if (e.balance < 0) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).cellStyle =
              xl.CellStyle(bold: true, fontColorHex: xl.ExcelColor.fromHexString('#D32F2F'));
        }
      }

      sheet.setColumnWidth(0, 20);
      sheet.setColumnWidth(1, 14);
      sheet.setColumnWidth(2, 22);
      sheet.setColumnWidth(3, 10);
      sheet.setColumnWidth(4, 10);
      sheet.setColumnWidth(5, 10);

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fName = 'ledger_${_selectedProduct!.sku}_$timestamp.xlsx';
        await saveFileBytes(fName, fileBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Excel exported successfully!'),
            backgroundColor: Colors.green[700],
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel export error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ══════════════════════════════════════════════
  //  EXPORT TO PDF
  // ══════════════════════════════════════════════
  Future<void> _exportPdf() async {
    if (_ledgerEntries.isEmpty || _selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export')));
      return;
    }
    try {
      final pdf = pw.Document();
      final p = _selectedProduct!;

      String dateRange = 'All Dates';
      if (_dateFrom != null || _dateTo != null) {
        dateRange = '${_dateFrom != null ? _fmtDate(_dateFrom!) : "Start"} to ${_dateTo != null ? _fmtDate(_dateTo!) : "Present"}';
      }

      const rowsPerPage = 28;
      final chunks = <List<LedgerEntry>>[];
      for (var i = 0; i < _ledgerEntries.length; i += rowsPerPage) {
        chunks.add(_ledgerEntries.sublist(i, i + rowsPerPage > _ledgerEntries.length ? _ledgerEntries.length : i + rowsPerPage));
      }

      for (var pageIdx = 0; pageIdx < chunks.length; pageIdx++) {
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) {
            return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (pageIdx == 0) ...[
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Item Ledger Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.SizedBox(height: 4),
                    pw.Text('Product: ${p.name}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('SKU: ${p.sku} | Current Stock: ${p.stockQty}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('FlavianoPOS - PRO', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.Text('Date Range: $dateRange', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Generated: ${_fmtDateTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ]),
                ]),
                pw.SizedBox(height: 6),
                pw.Divider(color: PdfColors.blue800, thickness: 2),
                pw.SizedBox(height: 8),
              ],
              if (pageIdx > 0) ...[
                pw.Text('Item Ledger - ${p.name} (continued)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.SizedBox(height: 8),
              ],
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                headerAlignment: pw.Alignment.center,
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                },
                headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                headers: ['Date', 'Type', 'Reference', 'Qty In', 'Qty Out', 'Balance'],
                data: chunks[pageIdx].map((e) => [
                  e.type == 'Beginning' ? '-' : _fmtDateTime(e.date),
                  e.type,
                  e.reference,
                  e.qtyIn > 0 ? '+${e.qtyIn}' : '',
                  e.qtyOut > 0 ? '-${e.qtyOut}' : '',
                  '${e.balance}',
                ]).toList(),
              ),
              pw.Spacer(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Total Entries: ${_ledgerEntries.length}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                pw.Text('Page ${pageIdx + 1} of ${chunks.length}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                pw.Text('Current Balance: ${_ledgerEntries.last.balance}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              ]),
            ]);
          },
        ));
      }

      final pdfBytes = await pdf.save();
      final ts = DateTime.now().millisecondsSinceEpoch;
      await saveFileBytes('ledger_${_selectedProduct!.sku}_$ts.pdf', pdfBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('PDF exported successfully!'),
          backgroundColor: Colors.green[700],
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF export error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _fmtDate(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  String _fmtDateTime(DateTime d) => '${_fmtDate(d)} ${_pad(d.hour)}:${_pad(d.minute)}';
  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Ledger', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[700], foregroundColor: Colors.white,
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
                Icon(Icons.table_chart, color: Colors.green, size: 20), SizedBox(width: 10),
                Text('Export to Excel'),
              ])),
              const PopupMenuItem(value: 'pdf', child: Row(children: [
                Icon(Icons.picture_as_pdf, color: Colors.red, size: 20), SizedBox(width: 10),
                Text('Export to PDF'),
              ])),
            ],
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.all(12), child: Column(children: [
          TextField(controller: _searchCtrl, decoration: InputDecoration(
            hintText: 'Search product by name, SKU, barcode...', prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); setState(() { _searchQuery = ''; }); }) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true, filled: true, fillColor: Colors.grey[100]),
            onChanged: (v) => setState(() => _searchQuery = v)),
        ])),
        if (_searchQuery.isNotEmpty && _selectedProduct == null || (_searchQuery.isNotEmpty && _searchCtrl.text != _selectedProduct?.name))
          Container(constraints: const BoxConstraints(maxHeight: 200), margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
            child: ListView.builder(shrinkWrap: true, itemCount: _filteredProducts.length, itemBuilder: (_, i) {
              final p = _filteredProducts[i];
              return ListTile(dense: true, leading: const Icon(Icons.inventory_2, color: Colors.blue),
                title: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('${p.sku} | Stock: ${p.stockQty} | C:${p.costPrice.toStringAsFixed(2)} R:${p.sellingPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                onTap: () => _selectProduct(p));
            })),
        if (_selectedProduct != null) Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue[700], borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.inventory_2, color: Colors.white, size: 28)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_selectedProduct!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis, maxLines: 2),
              Text('SKU: ${_selectedProduct!.sku}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _chip('Stock: ${_selectedProduct!.stockQty}', Colors.blue),
                _chip('Cost: ${_selectedProduct!.costPrice.toStringAsFixed(2)}', Colors.green),
                _chip('Retail: ${_selectedProduct!.sellingPrice.toStringAsFixed(2)}', Colors.orange),
              ]),
            ])),
            IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () {
              setState(() { _selectedProduct = null; _ledgerEntries = []; _searchCtrl.clear(); _searchQuery = ''; });
            }),
          ])),
        if (_selectedProduct != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
          Expanded(child: InkWell(onTap: () => _pickDate(true), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: Colors.white),
            child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: Colors.grey), const SizedBox(width: 6),
              Text(_dateFrom != null ? _fmtDate(_dateFrom!) : 'From', style: TextStyle(fontSize: 13, color: _dateFrom != null ? Colors.black87 : Colors.grey))])))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('-')),
          Expanded(child: InkWell(onTap: () => _pickDate(false), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: Colors.white),
            child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: Colors.grey), const SizedBox(width: 6),
              Text(_dateTo != null ? _fmtDate(_dateTo!) : 'To', style: TextStyle(fontSize: 13, color: _dateTo != null ? Colors.black87 : Colors.grey))])))),
          if (_dateFrom != null || _dateTo != null) IconButton(icon: const Icon(Icons.filter_alt_off, color: Colors.red, size: 20), onPressed: _clearFilters),
        ])),
        if (_selectedProduct != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${_ledgerEntries.length} entries', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            if (_ledgerEntries.isNotEmpty) Text('Current Balance: ${_ledgerEntries.last.balance}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue[700])),
          ])),
        Expanded(child: _selectedProduct == null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 10),
              Text('Search and select a product', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              Text('to view its stock movement history', style: TextStyle(color: Colors.grey[400], fontSize: 13))]))
          : _isLoading ? const Center(child: CircularProgressIndicator())
          : _ledgerEntries.isEmpty
            ? Center(child: Text('No ledger entries found', style: TextStyle(color: Colors.grey[500])))
            : LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        showCheckboxColumn: false,
                        headingRowColor: WidgetStateProperty.all(Colors.blue.shade700),
                        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                        dataTextStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                        columnSpacing: 16,
                        horizontalMargin: 12,
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Reference')),
                          DataColumn(label: Text('Qty In'), numeric: true),
                          DataColumn(label: Text('Qty Out'), numeric: true),
                          DataColumn(label: Text('Balance'), numeric: true),
                        ],
                        rows: List.generate(_ledgerEntries.length, (i) {
                          final e = _ledgerEntries[i];
                          return DataRow(
                            color: WidgetStateProperty.all(i.isEven ? Colors.white : Colors.grey.shade50),
                            cells: [
                              DataCell(Text(e.type == 'Beginning' ? '-' : _fmtDateTime(e.date), style: const TextStyle(fontSize: 11))),
                              DataCell(_typeChip(e.type)),
                              DataCell(Text(e.reference, style: const TextStyle(fontSize: 11))),
                              DataCell(Text(e.qtyIn > 0 ? '+${e.qtyIn}' : '', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                              DataCell(Text(e.qtyOut > 0 ? '-${e.qtyOut}' : '', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                              DataCell(Text('${e.balance}', style: TextStyle(fontWeight: FontWeight.bold, color: e.balance < 0 ? Colors.red : Colors.blue[800]))),
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

  Widget _typeChip(String type) {
    Color bg; Color fg;
    switch (type) {
      case 'Beginning': bg = Colors.grey.shade200; fg = Colors.grey.shade700; break;
      case 'Sale': bg = Colors.red.shade50; fg = Colors.red.shade700; break;
      case 'Delivery': bg = Colors.green.shade50; fg = Colors.green.shade700; break;
      case 'Adjustment': bg = Colors.orange.shade50; fg = Colors.orange.shade700; break;
      default: bg = Colors.grey.shade100; fg = Colors.grey; break;
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)));
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)));
}
