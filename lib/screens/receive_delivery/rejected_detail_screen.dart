// lib/screens/receive_delivery/rejected_detail_screen.dart
// Read-only REJECTED delivery viewer with prominent rejection reason
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xl;
import 'package:printing/printing.dart';
import '../../utils/receive_delivery_theme.dart';
import 'delivery_model.dart';

class RejectedDetailScreen extends StatefulWidget {
  final DeliveryRecord record;
  const RejectedDetailScreen({super.key, required this.record});

  @override
  State<RejectedDetailScreen> createState() => _RejectedDetailScreenState();
}

class _RejectedDetailScreenState extends State<RejectedDetailScreen> {
  static const _red       = Color(0xFFEF4444);
  static const _redLight  = Color(0xFFFEE2E2);
  static const _border    = Color(0xFFE5E7EB);
  static const _muted     = Color(0xFF6B7280);

  bool _processing = false;
  bool _deliveryInfoExpanded = true;
  int? _expandedIndex;

  final _int = NumberFormat.decimalPattern();
  final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);

  List<_SkuGroup> get _groups {
    final map = <String, _SkuGroup>{};
    for (final item in widget.record.items) {
      final key = item.sku.isEmpty ? item.productId : item.sku;
      map.putIfAbsent(key, () => _SkuGroup(sku: item.sku, productId: item.productId, itemName: item.itemName, batches: [])).batches.add(item);
    }
    return map.values.toList();
  }

  // ═══════════════ EXCEL EXPORT (Single Rejected DR) ═══════════════
  Future<void> _exportExcel() async {
    setState(() => _processing = true);
    try {
      final d = widget.record;
      final excel = xl.Excel.createExcel();
      excel.delete('Sheet1');

      final hStyle = xl.CellStyle(bold: true,
        fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: xl.ExcelColor.fromHexString('#EF4444'),
        horizontalAlign: xl.HorizontalAlign.Center);
      final titleStyle = xl.CellStyle(bold: true, fontSize: 14, fontColorHex: xl.ExcelColor.fromHexString('#7F1D1D'));
      final reasonStyle = xl.CellStyle(bold: true, fontSize: 11,
        backgroundColorHex: xl.ExcelColor.fromHexString('#FEE2E2'),
        fontColorHex: xl.ExcelColor.fromHexString('#7F1D1D'));

      // SUMMARY sheet
      final s1 = excel['SUMMARY'];
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = xl.TextCellValue('FlavianoPOS PRO - Rejected Delivery');
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = xl.TextCellValue('DR #: ${d.refNumber}    |    Status: REJECTED    |    Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');

      // Prominent rejection reason
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value = xl.TextCellValue('REJECTION REASON:');
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).cellStyle = reasonStyle;
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value = xl.TextCellValue(d.rejectionReason.isEmpty ? '-' : d.rejectionReason);
      s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).cellStyle = reasonStyle;

      final headers1 = ['Field', 'Value'];
      for (var c = 0; c < headers1.length; c++) {
        final cell = s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 5));
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
        ['Submitted By', d.submittedBy],
        ['Submitted Date', d.submittedDate],
        ['Rejected By', d.rejectedBy],
        ['Rejected Date', d.rejectedDate],
        ['Rejection Reason', d.rejectionReason],
        ['Total Items', '${d.totalItems}'],
        ['Total Qty', '${d.totalQuantity}'],
        ['Total Cost', d.totalCost.toStringAsFixed(2)],
        ['Total Retail', d.totalRetail.toStringAsFixed(2)],
        ['Notes', d.notes],
      ];
      for (var i = 0; i < fields.length; i++) {
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 6 + i)).value = xl.TextCellValue(fields[i][0]);
        s1.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 6 + i)).value = xl.TextCellValue(fields[i][1]);
      }
      s1.setColumnWidth(0, 22);
      s1.setColumnWidth(1, 45);

      // ITEMS_AND_BATCHES sheet
      final s2 = excel['ITEMS_AND_BATCHES'];
      final headers2 = ['#', 'DR #', 'SKU', 'Product', 'Batch #', 'MFG Date', 'EXP Date', 'Qty', 'Cost', 'Retail', 'Line Total', 'Rejected By', 'Rejected Date', 'Reason'];
      for (var c = 0; c < headers2.length; c++) {
        final cell = s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = xl.TextCellValue(headers2[c]);
        cell.cellStyle = hStyle;
      }
      int rowIdx = 1, idx = 1;
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
        s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIdx)).value = xl.TextCellValue(d.rejectedBy);
        s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIdx)).value = xl.TextCellValue(d.rejectedDate);
        s2.cell(xl.CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: rowIdx)).value = xl.TextCellValue(d.rejectionReason);
        rowIdx++;
        idx++;
      }
      final widths = [5.0, 12.0, 12.0, 30.0, 12.0, 12.0, 12.0, 10.0, 10.0, 10.0, 14.0, 15.0, 18.0, 25.0];
      for (var i = 0; i < widths.length; i++) { s2.setColumnWidth(i, widths[i]); }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Excel encoding failed');
      final filename = 'DR_${d.refNumber}_REJECTED.xlsx';
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: filename);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Excel exported: $filename'),
        backgroundColor: _red, behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

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
      ]));
  }


  // ═══════════════ BATCH LIST DIALOG ═══════════════
  void _showProductInfo(_SkuGroup group) {
    final totalQty = group.batches.fold<int>(0, (s, b) => s + b.quantity);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 700, maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                decoration: const BoxDecoration(
                  color: _redLight,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(children: [
                  const Icon(Icons.inventory_2_outlined, color: _red, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Batch List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 20)),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 100, child: Text('Total Qty:', style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                          Expanded(child: Text('${_int.format(totalQty)} pcs', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        ]),
                      ),
                      const Divider(),
                      const Text('Batch Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      // Header row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                        child: Row(children: const [
                          Expanded(flex: 3, child: Text('BATCH #', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151), letterSpacing: 0.6))),
                          Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151), letterSpacing: 0.6))),
                          Expanded(flex: 2, child: Text('MFG', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151), letterSpacing: 0.6))),
                          Expanded(flex: 2, child: Text('EXP', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151), letterSpacing: 0.6))),
                        ]),
                      ),
                      // Data rows
                      ...group.batches.asMap().entries.map((entry) {
                        final i = entry.key;
                        final b = entry.value;
                        String mfg = b.mfgDate.isEmpty ? '-' : b.mfgDate.split('T').first;
                        String exp = b.expDate.isEmpty ? '-' : b.expDate.split('T').first;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: i.isEven ? Colors.white : const Color(0xFFFEF7F7),
                            border: Border(bottom: BorderSide(color: _border, width: 0.5)),
                          ),
                          child: Row(children: [
                            Expanded(flex: 3, child: Text(b.batchNumber.isEmpty ? '-' : b.batchNumber, style: const TextStyle(fontSize: 13))),
                            Expanded(flex: 2, child: Text('${_int.format(b.quantity)} pcs', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _red))),
                            Expanded(flex: 2, child: Text(mfg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
                            Expanded(flex: 2, child: Text(exp, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
                          ]),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: _border))),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.record;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0, backgroundColor: _red, foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.cancel_outlined, size: 20),
            SizedBox(width: 8),
            Text('View Rejected', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
          ]),
          Text('${_groups.length} Item${_groups.length == 1 ? "" : "s"}',
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
        ]),
        actions: [
          IconButton(onPressed: _processing ? null : _exportExcel, tooltip: 'Export Excel', icon: const Icon(Icons.table_chart, color: Colors.white, size: 22)),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(36),
          child: Container(width: double.infinity, color: _red,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              Flexible(child: Text('DR#: ${d.refNumber}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: const Text('REJECTED', style: TextStyle(color: _red, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
            ]))),
      ),
      body: Stack(children: [
        LayoutBuilder(builder: (context, cons) {
          final w = cons.maxWidth;
          final cols = w >= 800 ? 3 : 2;
          return ListView(padding: const EdgeInsets.all(12), children: [
            // ═══ REJECTION REASON BANNER (Prominent) ═══
            Container(
              decoration: BoxDecoration(
                color: _redLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _red, width: 1.5),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: const [
                  Icon(Icons.cancel_outlined, color: _red, size: 22),
                  SizedBox(width: 8),
                  Text('REJECTION REASON', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _red, letterSpacing: 0.5)),
                ]),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                  child: Text(d.rejectionReason.isEmpty ? '(No reason provided)' : d.rejectionReason,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF7F1D1D), fontStyle: FontStyle.italic, height: 1.4)),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _info('Rejected By', d.rejectedBy, Icons.person)),
                  const SizedBox(width: 8),
                  Expanded(child: _info("Rejected Date", ReceiveDeliveryTheme.fmtDateTime(d.rejectedDate), Icons.calendar_today)),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            // Delivery Info
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                InkWell(
                  onTap: () => setState(() => _deliveryInfoExpanded = !_deliveryInfoExpanded),
                  child: Row(children: [
                    const Icon(Icons.description_outlined, size: 18, color: _red),
                    const SizedBox(width: 8),
                    const Text("Delivery Information", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Icon(_deliveryInfoExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 22, color: _muted),
                  ]),
                ),
                Visibility(
                  visible: _deliveryInfoExpanded,
                  child: Column(children: [
                    const SizedBox(height: 12),
                    LayoutBuilder(builder: (ctx, c) {
                      final colW = (c.maxWidth - (cols - 1) * 8) / cols;
                      return Wrap(spacing: 8, runSpacing: 8, children: [
                        SizedBox(width: colW, child: _info("DR # / Reference", d.refNumber, Icons.receipt_long)),
                        SizedBox(width: colW, child: _info("Supplier", d.supplier, Icons.business)),
                        SizedBox(width: colW, child: _info("Driver", d.driverName, Icons.person)),
                        SizedBox(width: colW, child: _info("Plate #", d.plateNumber, Icons.local_shipping)),
                        SizedBox(width: colW, child: _info("Received By", d.receivedBy, Icons.assignment_ind)),
                        SizedBox(width: colW, child: _info("Notes", d.notes, Icons.note_alt_outlined)),
                      ]);
                    }),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            // Items
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.inventory_2_outlined, size: 18, color: _red),
                  const SizedBox(width: 8),
                  const Text('Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(10)),
                    child: Text('${_groups.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 10),
                for (int i = 0; i < _groups.length; i++)
                  _SkuAccordionRow(group: _groups[i], index: i, isExpanded: _expandedIndex == i,
                    screenWidth: w,
                    onToggle: () => setState(() => _expandedIndex = _expandedIndex == i ? null : i),
                    intFmt: _int, onViewDetails: () => _showProductInfo(_groups[i])),
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
  Widget _miniInfo(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color ?? const Color(0xFF111827))),
      ],
    );
  }
  static const _red       = Color(0xFFEF4444);
  static const _redLight  = Color(0xFFFEE2E2);
  static const _border    = Color(0xFFE5E7EB);
  static const _muted     = Color(0xFF6B7280);

  final _SkuGroup group;
  final int index;
  final bool isExpanded;
  final double screenWidth;
  final VoidCallback onToggle;
  final NumberFormat intFmt;
  final VoidCallback? onViewDetails;

  const _SkuAccordionRow({required this.group, required this.index, required this.isExpanded, required this.screenWidth, required this.onToggle, required this.intFmt, this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    final totalQty = group.batches.fold<int>(0, (s, b) => s + b.quantity);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: isExpanded ? _redLight.withValues(alpha: 0.3) : Colors.white,
        border: Border.all(color: isExpanded ? _red.withValues(alpha: 0.4) : _border),
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
                decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(6)),
                child: Text('${intFmt.format(totalQty)} pcs', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
              const SizedBox(width: 4),
              if (screenWidth >= 600 && onViewDetails != null) IconButton(
                onPressed: onViewDetails,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'View Details',
                icon: const Icon(Icons.visibility_outlined, size: 18, color: _red),
              ),
              AnimatedRotation(turns: isExpanded ? 0.5 : 0, duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.expand_more, size: 22, color: _red)),
            ])))),
        if (isExpanded)
          Container(width: double.infinity,
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _border))),
            padding: const EdgeInsets.all(8),
            child: screenWidth >= 600
              // ═══ WIDE SCREEN: ERP TABLE ═══
              ? Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.grey[50], border: Border(bottom: BorderSide(color: _border))),
                    child: Row(children: [
                      const Expanded(flex: 3, child: Text('BATCH #', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151), letterSpacing: 0.6))),
                      const Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151), letterSpacing: 0.6))),
                      const Expanded(flex: 2, child: Text('MFG', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151), letterSpacing: 0.6))),
                      const Expanded(flex: 2, child: Text('EXP', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151), letterSpacing: 0.6))),
                      if (screenWidth >= 800) const Expanded(flex: 2, child: Text('RETAIL', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151), letterSpacing: 0.6))),
                      if (screenWidth >= 1000) const Expanded(flex: 2, child: Text('TOTAL @ RETAIL', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151), letterSpacing: 0.6))),
                    ]),
                  ),
                  for (int i = 0; i < group.batches.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFEF7F7), border: Border(bottom: BorderSide(color: _border, width: 0.5))),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(group.batches[i].batchNumber.isEmpty ? '-' : group.batches[i].batchNumber, style: const TextStyle(fontSize: 13))),
                        Expanded(flex: 2, child: Text('${intFmt.format(group.batches[i].quantity)} pcs', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _red))),
                        Expanded(flex: 2, child: Text(group.batches[i].mfgDate.isEmpty ? '-' : group.batches[i].mfgDate.split('T').first, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
                        Expanded(flex: 2, child: Text(group.batches[i].expDate.isEmpty ? '-' : group.batches[i].expDate.split('T').first, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
                        if (screenWidth >= 800) Expanded(flex: 2, child: Text(' ${group.batches[i].retail.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                        if (screenWidth >= 1000) Expanded(flex: 2, child: Text(' ${(group.batches[i].retail * group.batches[i].quantity).toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                      ]),
                    ),
                ])
              // ═══ PHONE: BEAUTIFUL CARDS ═══
              : Column(children: group.batches.map((b) {
              String mfg = b.mfgDate.isEmpty ? '-' : b.mfgDate.split('T').first;
              String exp = b.expDate.isEmpty ? '-' : b.expDate.split('T').first;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.qr_code, size: 12, color: _muted),
                      const SizedBox(width: 4),
                      Text(
                        'Batch #' + (b.batchNumber.isEmpty ? '-' : b.batchNumber),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: _miniInfo('Qty', intFmt.format(b.quantity) + ' pcs', color: _red)),
                      Expanded(child: _miniInfo('MFG', mfg)),
                      Expanded(child: _miniInfo('EXP', exp)),
                    ]),
                  ],
                ),
              );
            }).toList())),
      ]),
    );
  }
}
