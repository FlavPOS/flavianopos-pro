// lib/screens/receive_delivery/rejected_list_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xl;
import 'package:printing/printing.dart';
import '../../models/product_model.dart';
import '../../widgets/receive_delivery/rejected_list_table.dart';
import 'rejected_detail_screen.dart';
import 'delivery_model.dart';

class RejectedListScreen extends StatefulWidget {
  final List<Product> products;
  const RejectedListScreen({super.key, required this.products});

  @override
  State<RejectedListScreen> createState() => _RejectedListScreenState();
}

class _RejectedListScreenState extends State<RejectedListScreen> {
  List<DeliveryRecord> _rejected = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRejected();
  }

  Future<void> _loadRejected() async {
    setState(() => _loading = true);
    final list = await DeliveryStorage.getByStatus(DeliveryStatus.rejected);
    if (mounted) {
      setState(() {
        _rejected = list;
        _loading = false;
      });
    }
  }

  List<RejectedItem> get _items => _rejected.map((d) {
    DateTime? rjDate;
    try { if (d.rejectedDate.isNotEmpty) rjDate = DateTime.parse(d.rejectedDate); } catch (_) {}
    return RejectedItem(
      drNumber: d.refNumber.isEmpty ? '(no DR)' : d.refNumber,
      supplier: d.supplier,
      date: d.dateTime,
      itemsCount: d.totalItems,
      totalQty: d.totalQuantity,
      totalValue: d.totalRetail,
      reason: d.rejectionReason,
      rejectedBy: d.rejectedBy,
      rejectedDate: rjDate,
    );
  }).toList();

  DeliveryRecord? _findRecord(RejectedItem item) {
    for (final d in _rejected) {
      if (d.refNumber == item.drNumber && d.dateTime == item.date && d.totalRetail == item.totalValue) {
        return d;
      }
    }
    return null;
  }

  Future<void> _openDetail(RejectedItem item) async {
    final record = _findRecord(item);
    if (record == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RejectedDetailScreen(record: record)));
    _loadRejected();
  }

  // ═══════════════ EXPORT ALL TO EXCEL (with reasons) ═══════════════
  Future<void> _exportAll() async {
    if (_rejected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No rejected deliveries to export'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    try {
      final excel = xl.Excel.createExcel();
      excel.delete('Sheet1');

      final hStyle = xl.CellStyle(bold: true,
        fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: xl.ExcelColor.fromHexString('#EF4444'),
        horizontalAlign: xl.HorizontalAlign.Center);
      final titleStyle = xl.CellStyle(bold: true, fontSize: 14,
        fontColorHex: xl.ExcelColor.fromHexString('#7F1D1D'));
      final subStyle = xl.CellStyle(bold: true, fontSize: 11,
        fontColorHex: xl.ExcelColor.fromHexString('#555555'));
      final totalStyle = xl.CellStyle(bold: true,
        backgroundColorHex: xl.ExcelColor.fromHexString('#FEE2E2'),
        fontColorHex: xl.ExcelColor.fromHexString('#7F1D1D'));

      // ── SUMMARY sheet ──
      final s1 = excel['SUMMARY'];
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
          xl.TextCellValue('FlavianoPOS PRO - Rejected Deliveries Export');
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
          xl.TextCellValue('Total: ${_rejected.length} rejected deliveries    |    Generated: ${DateFormat("yyyy-MM-dd HH:mm").format(DateTime.now())}');
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = subStyle;

      final headers1 = ['#', 'DR #', 'Supplier', 'Driver', 'Plate #', 'Delivery Date',
        'Received By', 'Submitted By', 'Rejected By', 'Rejected Date',
        'REJECTION REASON',
        'Total Items', 'Total Qty', 'Total Cost', 'Total Retail', 'Notes'];
      for (var c = 0; c < headers1.length; c++) {
        final cell = s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3));
        cell.value = xl.TextCellValue(headers1[c]);
        cell.cellStyle = hStyle;
      }

      double grandCost = 0, grandRetail = 0;
      int grandItems = 0, grandQty = 0;

      for (var i = 0; i < _rejected.length; i++) {
        final d = _rejected[i];
        final row = i + 4;
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.IntCellValue(i + 1);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.TextCellValue(d.refNumber);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.TextCellValue(d.supplier);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.TextCellValue(d.driverName);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xl.TextCellValue(d.plateNumber);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = xl.TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(d.dateTime));
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = xl.TextCellValue(d.receivedBy);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = xl.TextCellValue(d.submittedBy);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = xl.TextCellValue(d.rejectedBy);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = xl.TextCellValue(d.rejectedDate);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = xl.TextCellValue(d.rejectionReason);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row)).value = xl.IntCellValue(d.totalItems);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row)).value = xl.IntCellValue(d.totalQuantity);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row)).value = xl.DoubleCellValue(d.totalCost);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: row)).value = xl.DoubleCellValue(d.totalRetail);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: row)).value = xl.TextCellValue(d.notes);
        grandItems += d.totalItems;
        grandQty += d.totalQuantity;
        grandCost += d.totalCost;
        grandRetail += d.totalRetail;
      }

      final totalRow = _rejected.length + 4;
      for (var c = 0; c < headers1.length; c++) {
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRow)).cellStyle = totalStyle;
      }
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRow)).value = xl.TextCellValue('GRAND TOTAL');
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: totalRow)).value = xl.IntCellValue(grandItems);
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: totalRow)).value = xl.IntCellValue(grandQty);
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: totalRow)).value = xl.DoubleCellValue(grandCost);
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: totalRow)).value = xl.DoubleCellValue(grandRetail);

      final widths1 = [5.0, 12.0, 22.0, 15.0, 12.0, 18.0, 15.0, 15.0, 15.0, 18.0, 30.0, 10.0, 12.0, 14.0, 14.0, 25.0];
      for (var i = 0; i < widths1.length; i++) { s1.setColumnWidth(i, widths1[i]); }

      // ── ITEMS_AND_BATCHES sheet (with reasons) ──
      final s2 = excel['ITEMS_AND_BATCHES'];
      final headers2 = ['#', 'DR #', 'Supplier', 'SKU', 'Product', 'Batch #',
        'MFG Date', 'EXP Date', 'Qty', 'Cost', 'Retail', 'Line Total',
        'Rejected By', 'Rejected Date', 'REJECTION REASON'];
      for (var c = 0; c < headers2.length; c++) {
        final cell = s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = xl.TextCellValue(headers2[c]);
        cell.cellStyle = hStyle;
      }

      int rowIdx = 1;
      int seq = 1;
      for (final d in _rejected) {
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
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIdx)).value = xl.TextCellValue(d.rejectedBy);
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: rowIdx)).value = xl.TextCellValue(d.rejectedDate);
          s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: rowIdx)).value = xl.TextCellValue(d.rejectionReason);
          rowIdx++;
          seq++;
        }
      }
      final widths2 = [5.0, 12.0, 20.0, 12.0, 25.0, 12.0, 12.0, 12.0, 10.0, 10.0, 10.0, 14.0, 15.0, 18.0, 30.0];
      for (var i = 0; i < widths2.length; i++) { s2.setColumnWidth(i, widths2[i]); }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Excel encoding failed');
      final filename = 'Rejected_Deliveries_${DateFormat("yyyyMMdd_HHmmss").format(DateTime.now())}.xlsx';
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: filename);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Exported: ${_rejected.length} rejected -> $filename'),
        backgroundColor: const Color(0xFFEF4444),
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
            : RejectedListTable(
                items: _items,
                onBack: () => Navigator.pop(context),
                onRefresh: _loadRejected,
                onExportAll: _exportAll,
                onView: _openDetail,
              ),
      ),
    );
  }
}
