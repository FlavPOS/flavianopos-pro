import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pdf_pkg;
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import 'package:printing/printing.dart';
import 'transfer_v3_model.dart';
import 'transfer_prepared_screen.dart';
import 'transfer_submitted_detail_screen.dart';

/// Outbound Draft/Submitted List Screen — reusable for both
class TransferListScreen extends StatefulWidget {
  final String branch;
  final String userName;
  final String branchId;
  final String status; // TransferStatus.draft, submitted, etc.
  final String title;
  final Color themeColor;

  const TransferListScreen({
    super.key,
    required this.branch,
    required this.userName,
    required this.branchId,
    required this.status,
    required this.title,
    required this.themeColor,
  });

  @override
  State<TransferListScreen> createState() => _TransferListScreenState();
}

class _TransferListScreenState extends State<TransferListScreen> {
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);
  static const _divider = Color(0xFFE5E7EB);
  static const _red = Color(0xFFEF4444);

  List<TransferV3> _transfers = [];
  bool _loading = true;
  
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TransferV3> get _filteredTransfers {
    if (_searchQuery.isEmpty) return _transfers;
    final q = _searchQuery.toLowerCase();
    return _transfers.where((doc) {
      return doc.transferId.toLowerCase().contains(q) ||
          doc.docNumber.toLowerCase().contains(q) ||
          doc.status.toLowerCase().contains(q) ||
          doc.receivingBranchId.toLowerCase().contains(q) ||
          doc.receivingBranchName.toLowerCase().contains(q) ||
          doc.issuingBranchId.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<TransferV3> list;

    if (widget.status == TransferStatus.approved) {
      // Approved list shows ALL approved-and-beyond statuses (history)
      list = await TransferV3Dao.getByStatuses(
        [
          TransferStatus.approved,
          TransferStatus.floating,
          TransferStatus.partiallyReceived,
          TransferStatus.received,
          TransferStatus.closed,
        ],
        widget.branchId,
        'outbound',
      );
    } else if (widget.status == TransferStatus.floating) {
      // In-Transit shows floating + partially received (live tracking)
      list = await TransferV3Dao.getByStatuses(
        [TransferStatus.floating, TransferStatus.partiallyReceived],
        widget.branchId,
        'outbound',
      );
    } else {
      list = await TransferV3Dao.getByStatus(
        widget.status,
        widget.branchId,
        'outbound',
      );
    }
    if (!mounted) return;
    setState(() {
      _transfers = list;
      _loading = false;
    });
  }

  Future<void> _openDetail(TransferV3 doc) async {
    if (widget.status == TransferStatus.submitted) {
      // Submitted → open full detail screen with Approve/Reject actions
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransferSubmittedDetailScreen(
            transferId: doc.transferId,
            branch: widget.branch,
            userName: widget.userName,
          ),
        ),
      );
      _load();
    } else {
      // Draft → popup with edit button
      _showDetailsSheet(doc);
    }
  }

  Future<void> _editDraft(TransferV3 doc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransferPreparedScreen(
          branch: widget.branch,
          userName: widget.userName,
          draftId: doc.transferId,
        ),
      ),
    );
    _load();
  }

  Future<void> _deleteDoc(TransferV3 doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _red),
            SizedBox(width: 8),
            Text('Delete Transfer?'),
          ],
        ),
        content: const Text(
          'This will permanently delete this transfer document.',
          style: TextStyle(color: _textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await TransferV3Dao.delete(doc.transferId);
      _load();
    }
  }

  Future<void> _showDetailsSheet(TransferV3 doc) async {
    final items = await TransferV3Dao.getItems(doc.transferId);
    if (!mounted) return;
    // Full-screen dialog (better UX than bottom sheet)
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) {
          return Scaffold(
            backgroundColor: _bg,
            body: SafeArea(
              child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.themeColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doc.docNumber.isEmpty ? doc.transferId : doc.docNumber,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            Text('To: ${doc.receivingBranchId} (${doc.receivingBranchName})',
                                style: const TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                      // Print + PDF for ALL statuses (enterprise standard)
                      IconButton(
                        icon: const Icon(Icons.print_rounded, color: Colors.white),
                        tooltip: 'Reprint IST',
                        onPressed: () async {
                          await _printPdf(doc, items);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                        tooltip: 'Export PDF',
                        onPressed: () async {
                          await _downloadPdf(doc, items);
                        },
                      ),
                      // Edit for drafts
                      if (widget.status == TransferStatus.draft)
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: Colors.white),
                          tooltip: 'Continue Editing',
                          onPressed: () {
                            Navigator.pop(ctx);
                            _editDraft(doc);
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _divider),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text('SKU: ${item.sku}',
                                      style: const TextStyle(
                                          color: _textSecondary, fontSize: 11)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: widget.themeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('${item.issuedQty}',
                                      style: TextStyle(
                                          color: widget.themeColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 2),
                                Text('pcs',
                                    style: const TextStyle(
                                        color: _textSecondary, fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                _buildPopupSummary(items),
              ],
            ),
          ),
        );
      },
    ));
  }

  Widget _buildPopupSummary(List<TransferV3Item> items) {
    final totalQty = items.fold<int>(0, (s, i) => s + i.issuedQty);
    final totalRetail = items.fold<double>(0.0, (s, i) => s + (i.issuedQty * i.unitCost));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _popupStat(Icons.shopping_bag_outlined, 'Items', '${items.length}'),
          Container(width: 1, height: 26, color: _divider),
          _popupStat(Icons.add_rounded, 'Qty', '$totalQty pcs'),
          Container(width: 1, height: 26, color: _divider),
          _popupStat(Icons.sell_outlined, 'Retail', totalRetail.toStringAsFixed(2)),
        ],
      ),
    );
  }

  Widget _popupStat(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: widget.themeColor),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print All',
            onPressed: _printAllList,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Export PDF (All)',
            onPressed: _downloadAllListPdf,
          ),
          IconButton(
            icon: const Icon(Icons.table_view_rounded),
            tooltip: 'Export to Excel',
            onPressed: _exportExcel,
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: _filteredTransfers.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredTransfers.length,
                          itemBuilder: (context, index) =>
                              _buildCard(_filteredTransfers[index]),
                        ),
                ),
              ],
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
              color: widget.themeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_rounded, size: 64, color: widget.themeColor),
          ),
          const SizedBox(height: 12),
          Text('No ${widget.title.toLowerCase()} yet',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
        ],
      ),
    );
  }

  Widget _buildCard(TransferV3 doc) {
    String date = doc.createdAt;
    try {
      final dt = DateTime.parse(doc.createdAt);
      date =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.themeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.status == TransferStatus.draft
                          ? Icons.description_rounded
                          : Icons.send_rounded,
                      color: widget.themeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.docNumber.isEmpty ? doc.transferId : doc.docNumber,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _textPrimary,
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text('To: ${doc.receivingBranchId} (${doc.receivingBranchName})',
                            style: const TextStyle(
                                color: _textSecondary, fontSize: 11)),
                        Text(date,
                            style: const TextStyle(
                                color: _textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (widget.status == TransferStatus.draft)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: _textSecondary),
                      onSelected: (v) {
                        if (v == 'delete') _deleteDoc(doc);
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: _red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: _red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _stat(Icons.inventory_2_outlined, '${doc.totalItems} items', widget.themeColor),
                  const SizedBox(width: 8),
                  _stat(Icons.add_rounded, '${doc.totalIssuedQty} pcs', widget.themeColor),
                  const Spacer(),
                  _buildStatusBadge(doc.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'DRAFT':
        color = const Color(0xFF8B5CF6);
        label = 'Draft';
        break;
      case 'SUBMITTED':
        color = const Color(0xFF3B82F6);
        label = 'Submitted';
        break;
      case 'APPROVED':
        color = const Color(0xFF06B6D4);
        label = 'Approved';
        break;
      case 'FLOATING':
        color = const Color(0xFFF59E0B);
        label = 'In-Transit';
        break;
      case 'PARTIALLY_RECEIVED':
        color = const Color(0xFFEAB308);
        label = 'Partial';
        break;
      case 'RECEIVED':
        color = const Color(0xFF22C55E);
        label = 'Received';
        break;
      case 'CLOSED':
        color = const Color(0xFF64748B);
        label = 'Closed';
        break;
      case 'REJECTED':
        color = _red;
        label = 'Rejected';
        break;
      default:
        color = _textSecondary;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }


  Future<void> _exportExcel() async {
    if (_transfers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No records to export'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Create Excel — use default Sheet1 to avoid conflicts
      final excel = xl.Excel.createExcel();
      final sheet = excel['Sheet1'];

      final headers = [
        'Date', 'IST No.', 'From Branch', 'To Branch',
        'SKU', 'Product Name', 'Qty', 'Retail Value',
        'Prepared By', 'Approved By', 'Status',
      ];

      // Write header row with styling
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(headers[i]);
        cell.cellStyle = xl.CellStyle(
          bold: true,
          backgroundColorHex: xl.ExcelColor.fromHexString('#3B82F6'),
          fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
          horizontalAlign: xl.HorizontalAlign.Center,
        );
      }

      int rowIndex = 1;
      for (final doc in _transfers) {
        final items = await TransferV3Dao.getItems(doc.transferId);
        String date = doc.createdAt;
        try {
          final dt = DateTime.parse(doc.createdAt);
          date = '${dt.year}-${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")}';
        } catch (_) {}

        final ref = doc.docNumber.isEmpty ? doc.transferId : doc.docNumber;
        final approvedBy = doc.approvedByRole.isNotEmpty
            ? '${doc.approvedBy} (${doc.approvedByRole})'
            : doc.approvedBy;

        for (final item in items) {
          final retail = item.issuedQty * item.unitCost;
          final row = [
            date, ref,
            '${doc.issuingBranchId} (${doc.issuingBranchName})',
            '${doc.receivingBranchId} (${doc.receivingBranchName})',
            item.sku, item.productName,
            item.issuedQty.toString(),
            retail.toStringAsFixed(2),
            doc.preparedBy,
            approvedBy.isEmpty ? '—' : approvedBy,
            doc.status,
          ];

          for (var c = 0; c < row.length; c++) {
            sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex))
                .value = xl.TextCellValue(row[c]);
          }
          rowIndex++;
        }
      }

      for (var i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 18);
      }

      final bytes = excel.save();
      if (bytes == null) throw 'Failed to encode Excel';

      final now = DateTime.now();
      final filename = '${widget.title.replaceAll(" ", "_")}_${now.year}${now.month.toString().padLeft(2, "0")}${now.day.toString().padLeft(2, "0")}.xlsx';

      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: filename,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported: $filename'),
          backgroundColor: widget.themeColor,
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


  // ═══ PDF Generator + Print/Download ═══
  Future<Uint8List> _generatePdf(TransferV3 doc, List<TransferV3Item> items) async {
    final pdf = pw.Document();
    // ignore: unused_local_variable
    final now = DateTime.now();
    final totalQty = items.fold<int>(0, (s, i) => s + i.issuedQty);
    final totalRetail = items.fold<double>(0.0, (s, i) => s + (i.issuedQty * i.unitCost));

    // 14x8.5 inch Landscape (Legal Landscape)
    // Note: PDF uses points (1 inch = 72 points)
    final pageFormat = pdf_pkg.PdfPageFormat(
      14 * pdf_pkg.PdfPageFormat.inch,
      8.5 * pdf_pkg.PdfPageFormat.inch,
      marginAll: 20,
    );

    // Items per page: ~15 items fits comfortably per copy on 14" landscape
    // Two copies per page = 15 items shown twice
    const itemsPerPage = 15;
    final totalPages = (items.length / itemsPerPage).ceil().clamp(1, 999);

    // Build one copy (either ISSUING or RECEIVING)
    pw.Widget buildCopy({
      required String copyLabel,
      required List<TransferV3Item> pageItems,
      required int startIdx,
      required int currentPage,
      required int totalPagesCount,
    }) {
      return pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.0)),
        padding: const pw.EdgeInsets.all(6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Header black bar
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: pw.BoxDecoration(
                color: pdf_pkg.PdfColor.fromInt(0xFF000000),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('STOCK TRANSFER · ${doc.status}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: pdf_pkg.PdfColor.fromInt(0xFFFFFFFF),
                      )),
                  pw.Row(
                    children: [
                      pw.Text('Page $currentPage of $totalPagesCount  |  ',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: pdf_pkg.PdfColor.fromInt(0xFFFFFFFF),
                          )),
                      pw.Text(copyLabel,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: pdf_pkg.PdfColor.fromInt(0xFFFFFFFF),
                          )),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),

            // FROM/TO row
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.4)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('FROM',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${doc.issuingBranchId} · ${doc.issuingBranchName}',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 3),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.4)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TO',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text('${doc.receivingBranchId} · ${doc.receivingBranchName}',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 3),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.4)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('IST No.',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text(doc.docNumber.isEmpty ? doc.transferId : doc.docNumber,
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 3),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.4)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('DATE CREATED',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text(_pdfDate(doc.createdAt),
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),

            // Items table
            pw.Table(
              border: pw.TableBorder.all(width: 0.4),
              columnWidths: {
                0: const pw.FixedColumnWidth(28),
                1: const pw.FixedColumnWidth(65),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FixedColumnWidth(45),
                4: const pw.FixedColumnWidth(60),
                5: const pw.FixedColumnWidth(75),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: pdf_pkg.PdfColor.fromInt(0xFF000000)),
                  children: [
                    _p4H('#', white: true),
                    _p4H('SKU', white: true),
                    _p4H('Product Description', white: true),
                    _p4H('Qty', white: true),
                    _p4H('Unit @', white: true),
                    _p4H('Retail Value', white: true),
                  ],
                ),
                ...pageItems.asMap().entries.map((entry) {
                  final rowIdx = entry.key;
                  final item = entry.value;
                  final retail = item.issuedQty * item.unitCost;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: rowIdx % 2 == 0
                          ? pdf_pkg.PdfColor.fromInt(0xFFF5F5F5)
                          : pdf_pkg.PdfColor.fromInt(0xFFFFFFFF),
                    ),
                    children: [
                      _p4C((startIdx + rowIdx + 1).toString()),
                      _p4C(item.sku, bold: true),
                      _p4C(item.productName, bold: true),
                      _p4CR(item.issuedQty.toString()),
                      _p4CR(item.unitCost.toStringAsFixed(2)),
                      _p4CR(retail.toStringAsFixed(2), bold: true),
                    ],
                  );
                }),
                // Only show grand total on LAST page
                if (currentPage == totalPagesCount)
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: pdf_pkg.PdfColor.fromInt(0xFFE0E0E0)),
                    children: [
                      _p4C(''),
                      _p4C(''),
                      _p4C('GRAND TOTAL', bold: true),
                      _p4CR('$totalQty pcs', bold: true),
                      _p4C(''),
                      _p4CR(totalRetail.toStringAsFixed(2), bold: true),
                    ],
                  ),
              ],
            ),

            // Signature blocks ONLY on last page
            if (currentPage == totalPagesCount) ...[
              pw.SizedBox(height: 6),
              pw.Row(
                children: [
                  pw.Expanded(child: _p4Sig('Prepared By', doc.preparedBy)),
                  pw.SizedBox(width: 3),
                  pw.Expanded(child: _p4Sig('Approved By', doc.approvedBy, role: doc.approvedByRole)),
                  pw.SizedBox(width: 3),
                  pw.Expanded(child: _p4Sig('Received By', doc.receivedBy)),
                  pw.SizedBox(width: 3),
                  pw.Expanded(child: _p4Sig('Date Received', _pdfDate(doc.receivedDate))),
                ],
              ),
            ] else ...[
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(color: pdf_pkg.PdfColor.fromInt(0xFFF5F5F5)),
                child: pw.Center(
                  child: pw.Text(
                    '— Continued on next page —',
                    style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Generate pages
    for (int pageNum = 1; pageNum <= totalPages; pageNum++) {
      final startIdx = (pageNum - 1) * itemsPerPage;
      final endIdx = (startIdx + itemsPerPage).clamp(0, items.length);
      final pageItems = items.sublist(startIdx, endIdx);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(15),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ISSUING COPY
              buildCopy(
                copyLabel: 'ISSUING STORE COPY',
                pageItems: pageItems,
                startIdx: startIdx,
                currentPage: pageNum,
                totalPagesCount: totalPages,
              ),
              pw.SizedBox(height: 3),
              // Tear line
              pw.Center(
                child: pw.Text(
                  '- - - - - - - - - - - - - - - - - - -  TEAR OR FOLD HERE  - - - - - - - - - - - - - - - - - - -',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.SizedBox(height: 3),
              // RECEIVING COPY
              buildCopy(
                copyLabel: 'RECEIVING STORE COPY',
                pageItems: pageItems,
                startIdx: startIdx,
                currentPage: pageNum,
                totalPagesCount: totalPages,
              ),
              pw.Spacer(),
              pw.Text(
                'Generated: PHOLD_GEN',
                style: const pw.TextStyle(fontSize: 7),
              ),
            ],
          ),
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _p4H(String text, {bool white = false}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
    alignment: pw.Alignment.center,
    child: pw.Text(text, style: pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: white ? pdf_pkg.PdfColor.fromInt(0xFFFFFFFF) : pdf_pkg.PdfColor.fromInt(0xFF000000),
    )),
  );

  static pw.Widget _p4C(String text, {bool bold = false}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
    child: pw.Text(text, style: pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    )),
  );

  static pw.Widget _p4CR(String text, {bool bold = false}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
    alignment: pw.Alignment.centerRight,
    child: pw.Text(text, style: pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    )),
  );

  static pw.Widget _p4Sig(String label, String name, {String role = ''}) => pw.Container(
    padding: const pw.EdgeInsets.all(5),
    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.4)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          height: 20,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 0.4)),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.Text(
          name.isEmpty ? '________________' : name,
          style: const pw.TextStyle(fontSize: 10),
        ),
        if (role.isNotEmpty)
          pw.Text('($role)', style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
  );

  static String _pdfDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")}';
    } catch (_) {
      return iso;
    }
  }

  static pw.Widget _pdfHCell(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
    alignment: pw.Alignment.center,
    child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
  );

  static pw.Widget _pdfCell(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 5),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
  );

  static pw.Widget _pdfCellR(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 5),
    alignment: pw.Alignment.centerRight,
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
  );


  Future<void> _printPdf(TransferV3 doc, List<TransferV3Item> items) async {
    try {
      final bytes = await _generatePdf(doc, items);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e'), backgroundColor: _red),
      );
    }
  }

  Future<void> _downloadPdf(TransferV3 doc, List<TransferV3Item> items) async {
    try {
      final bytes = await _generatePdf(doc, items);
      final docNum = doc.docNumber.isEmpty ? doc.transferId : doc.docNumber;
      await Printing.sharePdf(bytes: bytes, filename: 'IST-$docNum.pdf');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('PDF downloaded'), backgroundColor: widget.themeColor),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e'), backgroundColor: _red),
      );
    }
  }


  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      color: _bg,
      child: Container(
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
        child: TextField(
          controller: _searchCtrl,
          onChanged: (q) => setState(() => _searchQuery = q),
          decoration: InputDecoration(
            hintText: 'Search IST No., branch, or status...',
            hintStyle: const TextStyle(color: _textSecondary, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: _textSecondary, size: 22),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: _textSecondary),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _generateAllPdf() async {
    final pdf = pw.Document();
    final now = DateTime.now();

    final allData = <Map<String, dynamic>>[];
    int grandItems = 0;
    int grandQty = 0;
    double grandRetail = 0;

    for (final doc in _transfers) {
      final items = await TransferV3Dao.getItems(doc.transferId);
      final docQty = items.fold<int>(0, (s, i) => s + i.issuedQty);
      final docRetail = items.fold<double>(0.0, (s, i) => s + (i.issuedQty * i.unitCost));
      grandItems += items.length;
      grandQty += docQty;
      grandRetail += docRetail;
      allData.add({'doc': doc, 'items': items, 'qty': docQty, 'retail': docRetail});
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pdf_pkg.PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: pdf_pkg.PdfColor.fromInt(0xFFF3F4F6),
              border: pw.Border.all(color: pdf_pkg.PdfColor.fromInt(0xFF6B7280), width: 0.5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FLAV POS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 3),
                    pw.Text('${widget.title.toUpperCase()} REPORT', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('${_transfers.length} Documents', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Generated: ${now.year}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")} ${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}',
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.3)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Text('Total Docs: ${_transfers.length}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Total Items: $grandItems', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Total Qty: $grandQty pcs', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Total Retail: ${grandRetail.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: pdf_pkg.PdfColor.fromInt(0xFF6B7280), width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(90),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FixedColumnWidth(40),
              4: const pw.FixedColumnWidth(50),
              5: const pw.FixedColumnWidth(70),
              6: const pw.FixedColumnWidth(70),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: pdf_pkg.PdfColor.fromInt(0xFFF3F4F6)),
                children: [
                  _pdfHCell('IST No.'),
                  _pdfHCell('From'),
                  _pdfHCell('To'),
                  _pdfHCell('Items'),
                  _pdfHCell('Qty'),
                  _pdfHCell('Retail'),
                  _pdfHCell('Status'),
                ],
              ),
              ...allData.map((row) {
                final d = row['doc'] as TransferV3;
                return pw.TableRow(children: [
                  _pdfCell(d.docNumber.isEmpty ? d.transferId : d.docNumber),
                  _pdfCell('${d.issuingBranchId} ${d.issuingBranchName}'),
                  _pdfCell('${d.receivingBranchId} ${d.receivingBranchName}'),
                  _pdfCellR((row['items'] as List).length.toString()),
                  _pdfCellR((row['qty'] as int).toString()),
                  _pdfCellR((row['retail'] as double).toStringAsFixed(2)),
                  _pdfCell(d.status),
                ]);
              }),
            ],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  Future<void> _printAllList() async {
    if (_transfers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No records to print'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    try {
      final bytes = await _generateAllPdf();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e'), backgroundColor: _red),
      );
    }
  }

  Future<void> _downloadAllListPdf() async {
    if (_transfers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No records to export'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    try {
      final bytes = await _generateAllPdf();
      final now = DateTime.now();
      final filename = '${widget.title.replaceAll(" ", "_")}_Report_${now.year}${now.month.toString().padLeft(2, "0")}${now.day.toString().padLeft(2, "0")}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF downloaded: $filename'), backgroundColor: widget.themeColor),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e'), backgroundColor: _red),
      );
    }
  }
}
