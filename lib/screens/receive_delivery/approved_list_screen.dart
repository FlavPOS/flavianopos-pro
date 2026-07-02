// lib/screens/receive_delivery/approved_list_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xl;
import 'package:printing/printing.dart';
import '../../models/product_model.dart';
import '../../widgets/receive_delivery/approved_list_table.dart';
import 'approved_detail_screen.dart';
import 'delivery_model.dart';

class ApprovedListScreen extends StatefulWidget {
  final List<Product> products;
  const ApprovedListScreen({super.key, required this.products});

  @override
  State<ApprovedListScreen> createState() => _ApprovedListScreenState();
}

class _ApprovedListScreenState extends State<ApprovedListScreen> {
  List<DeliveryRecord> _approved = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadApproved();
  }

  Future<void> _loadApproved() async {
    setState(() => _loading = true);
    final list = await DeliveryStorage.getByStatus(DeliveryStatus.approved);
    if (mounted) {
      setState(() {
        _approved = list;
        _loading = false;
      });
    }
  }

  List<ApprovedItem> get _items => _approved.map((d) {
    DateTime? aprDate;
    try { if (d.approvedDate.isNotEmpty) aprDate = DateTime.parse(d.approvedDate); } catch (_) {}
    return ApprovedItem(
      drNumber: d.refNumber.isEmpty ? '(no DR)' : d.refNumber,
      supplier: d.supplier,
      date: d.dateTime,
      itemsCount: d.totalItems,
      totalQty: d.totalQuantity,
      totalValue: d.totalRetail,
      approvedBy: d.approvedBy,
      approvedDate: aprDate,
    );
  }).toList();

  DeliveryRecord? _findRecord(ApprovedItem item) {
    for (final d in _approved) {
      if (d.refNumber == item.drNumber && d.dateTime == item.date && d.totalRetail == item.totalValue) {
        return d;
      }
    }
    return null;
  }

  Future<void> _openDetail(ApprovedItem item) async {
    final record = _findRecord(item);
    if (record == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ApprovedDetailScreen(record: record)));
    _loadApproved();
  }

  Future<void> _exportAll() async {
    if (_approved.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No approved deliveries to export'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    try {
      final excel = xl.Excel.createExcel();
      excel.delete('Sheet1');

      final hStyle = xl.CellStyle(bold: true,
        fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: xl.ExcelColor.fromHexString('#16A34A'),
        horizontalAlign: xl.HorizontalAlign.Center);
      final titleStyle = xl.CellStyle(bold: true, fontSize: 14,
        fontColorHex: xl.ExcelColor.fromHexString('#0D4020'));
      final subStyle = xl.CellStyle(bold: true, fontSize: 11,
        fontColorHex: xl.ExcelColor.fromHexString('#555555'));
      final totalStyle = xl.CellStyle(bold: true,
        backgroundColorHex: xl.ExcelColor.fromHexString('#DCFCE7'),
        fontColorHex: xl.ExcelColor.fromHexString('#0D4020'));

      final s1 = excel['SUMMARY'];
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
          xl.TextCellValue('FlavianoPOS PRO - Approved Deliveries Export');
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
          xl.TextCellValue('Total: ${_approved.length} deliveries    |    Generated: ${DateFormat("yyyy-MM-dd HH:mm").format(DateTime.now())}');
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = subStyle;

      final headers1 = ['#', 'DR #', 'Supplier', 'Driver', 'Plate #', 'Delivery Date',
        'Received By', 'Approved By', 'Approved Date',
        'Total Items', 'Total Qty', 'Total Cost', 'Total Retail', 'Notes'];
      for (var c = 0; c < headers1.length; c++) {
        final cell = s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3));
        cell.value = xl.TextCellValue(headers1[c]);
        cell.cellStyle = hStyle;
      }

      double grandCost = 0, grandRetail = 0;
      int grandItems = 0, grandQty = 0;

      for (var i = 0; i < _approved.length; i++) {
        final d = _approved[i];
        final row = i + 4;
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.IntCellValue(i + 1);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.TextCellValue(d.refNumber);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.TextCellValue(d.supplier);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.TextCellValue(d.driverName);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xl.TextCellValue(d.plateNumber);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = xl.TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(d.dateTime));
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = xl.TextCellValue(d.receivedBy);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = xl.TextCellValue(d.approvedBy);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = xl.TextCellValue(d.approvedDate);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = xl.IntCellValue(d.totalItems);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = xl.IntCellValue(d.totalQuantity);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row)).value = xl.DoubleCellValue(d.totalCost);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row)).value = xl.DoubleCellValue(d.totalRetail);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row)).value = xl.TextCellValue(d.notes);
        grandItems += d.totalItems;
        grandQty += d.totalQuantity;
        grandCost += d.totalCost;
        grandRetail += d.totalRetail;
      }

      final totalRow = _approved.length + 4;
      for (var c = 0; c < headers1.length; c++) {
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRow)).cellStyle = totalStyle;
      }
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRow)).value = xl.TextCellValue('GRAND TOTAL');
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: totalRow)).value = xl.IntCellValue(grandItems);
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: totalRow)).value = xl.IntCellValue(grandQty);
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: totalRow)).value = xl.DoubleCellValue(grandCost);
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: totalRow)).value = xl.DoubleCellValue(grandRetail);

      final widths1 = [5.0, 12.0, 25.0, 15.0, 12.0, 18.0, 15.0, 15.0, 18.0, 10.0, 12.0, 14.0, 14.0, 25.0];
      for (var i = 0; i < widths1.length; i++) { s1.setColumnWidth(i, widths1[i]); }

      final s2 = excel['ITEMS_AND_BATCHES'];
      final headers2 = ['#', 'DR #', 'Supplier', 'SKU', 'Product', 'Batch #',
        'MFG Date', 'EXP Date', 'Qty', 'Cost', 'Retail', 'Line Total',
        'Approved By', 'Approved Date'];
      for (var c = 0; c < headers2.length; c++) {
        final cell = s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = xl.TextCellValue(headers2[c]);
        cell.cellStyle = hStyle;
      }

      int rowIdx = 1;
      int seq = 1;
      for (final d in _approved) {
        for (final item in d.items) {
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx)).value = xl.IntCellValue(seq);
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx)).value = xl.TextCellValue(d.refNumber);
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx)).value = xl.TextCellValue(d.supplier);
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx)).value = xl.TextCellValue(item.sku);
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx)).value = xl.TextCellValue(item.itemName);
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx)).value = xl.TextCellValue(item.batchNumber);
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIdx)).value = xl.TextCellValue(item.mfgDate);
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIdx)).value = xl.TextCellValue(item.expDate);
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIdx)).value = xl.IntCellValue(item.quantity);
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIdx)).value = xl.DoubleCellValue(item.cost);
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIdx)).value = xl.DoubleCellValue(item.retail);
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIdx)).value = xl.DoubleCellValue(item.quantity * item.retail);
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIdx)).value = xl.TextCellValue(d.approvedBy);
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: rowIdx)).value = xl.TextCellValue(d.approvedDate);
          rowIdx++;
          seq++;
        }
      }
      final widths2 = [5.0, 12.0, 20.0, 12.0, 25.0, 12.0, 12.0, 12.0, 10.0, 10.0, 10.0, 14.0, 15.0, 18.0];
      for (var i = 0; i < widths2.length; i++) { s2.setColumnWidth(i, widths2[i]); }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Excel encoding failed');
      final filename = 'Approved_Deliveries_${DateFormat("yyyyMMdd_HHmmss").format(DateTime.now())}.xlsx';
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: filename);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Exported: ${_approved.length} deliveries -> $filename'),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ApprovedListTable(
                items: _items,
                onBack: () => Navigator.pop(context),
                onRefresh: _loadApproved,
                onExportAll: _exportAll,
                onView: _openDetail,
              ),
      ),
    );
  }
}
