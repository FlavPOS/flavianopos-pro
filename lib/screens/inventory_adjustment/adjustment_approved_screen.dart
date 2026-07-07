import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:printing/printing.dart';
import 'adjustment_v3_model.dart';
import 'adjustment_approved_detail_screen.dart';

class AdjustmentApprovedScreen extends StatefulWidget {
  final String branch;
  final String userName;

  const AdjustmentApprovedScreen({
    super.key,
    required this.branch,
    required this.userName,
  });

  @override
  State<AdjustmentApprovedScreen> createState() =>
      _AdjustmentApprovedScreenState();
}

class _AdjustmentApprovedScreenState extends State<AdjustmentApprovedScreen> {
  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);

  List<AdjustmentV3> _approved = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await AdjustmentV3Dao.getByStatus(
      AdjustmentStatus.approved,
      branchCode: widget.branch,
    );
    if (!mounted) return;
    setState(() {
      _approved = list;
      _loading = false;
    });
  }

  Future<void> _openDetail(AdjustmentV3 doc) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdjustmentApprovedDetailScreen(
          adjustmentId: doc.adjustmentId,
          branch: widget.branch,
          userName: widget.userName,
        ),
      ),
    );
    if (result == true || result == null) _load();
  }

  Future<void> _exportExcel() async {
    if (_approved.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No approved records to export'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final excel = Excel.createExcel();
      final sheet = excel['Approved Adjustments'];
      excel.setDefaultSheet('Approved Adjustments');
      excel.delete('Sheet1');

      // Header row
      final headers = [
        'Date',
        'Adj Ref#',
        'SKU',
        'Product',
        'Qty Adjusted',
        'Total @ Cost',
        'Reason Code',
        'Reason Name',
        'Prepared By',
        'Approved By',
      ];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#22C55E'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      // Data rows — one per line item
      int rowIndex = 1;
      for (final doc in _approved) {
        final items = await AdjustmentV3Dao.getItems(doc.adjustmentId);
        String date = doc.approvedAt;
        try {
          final dt = DateTime.parse(doc.approvedAt.isNotEmpty
              ? doc.approvedAt
              : doc.createdAt);
          date = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {}

        final ref = doc.docNumber.isEmpty ? doc.adjustmentId : doc.docNumber;
        final preparedBy = doc.createdByName;
        final approvedBy = doc.approvedByRole.isNotEmpty
            ? '${doc.approvedBy} (${doc.approvedByRole})'
            : doc.approvedBy;

        for (final item in items) {
          final sign = item.direction < 0 ? '-' : '+';
          final qtyStr = '$sign${item.qty}';
          final cost = item.qty * item.unitCost * item.direction;

          final row = [
            date,
            ref,
            item.sku,
            item.productName,
            qtyStr,
            cost.toStringAsFixed(2),
            item.reasonCode,
            item.reasonName,
            preparedBy,
            approvedBy,
          ];

          for (var c = 0; c < row.length; c++) {
            sheet.cell(CellIndex.indexByColumnRow(
                    columnIndex: c, rowIndex: rowIndex))
                .value = TextCellValue(row[c]);
          }
          rowIndex++;
        }
      }

      // Auto-size (approximate)
      for (var i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 18);
      }

      final bytes = excel.save();
      if (bytes == null) throw 'Failed to encode Excel';

      final now = DateTime.now();
      final filename =
          'ApprovedAdjustments_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.xlsx';

      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: filename,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported: $filename'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 20),
            SizedBox(width: 8),
            Text('Approved',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view_rounded),
            tooltip: 'Export to Excel',
            onPressed: _exportExcel,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _approved.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _approved.length,
                  itemBuilder: (context, index) => _buildCard(_approved[index]),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                size: 64, color: _green),
          ),
          const SizedBox(height: 12),
          const Text('No approved adjustments',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
        ],
      ),
    );
  }

  Widget _buildCard(AdjustmentV3 doc) {
    String date = doc.approvedAt;
    try {
      final dt = DateTime.parse(doc.approvedAt.isNotEmpty
          ? doc.approvedAt
          : doc.createdAt);
      date = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(doc),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: _green, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.docNumber.isEmpty
                          ? doc.adjustmentId
                          : doc.docNumber,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text('Approved by: ${doc.approvedBy}',
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 11)),
                    Text(date,
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('APPROVED',
                    style: TextStyle(
                        color: _green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
