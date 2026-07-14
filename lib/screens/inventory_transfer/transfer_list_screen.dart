import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pdf_pkg;
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import 'package:printing/printing.dart';
import 'transfer_v3_model.dart';
import 'transfer_prepared_screen.dart';
import 'inbound_receive_screen.dart';
import 'transfer_submitted_detail_screen.dart';

/// Outbound Draft/Submitted List Screen — reusable for both
class TransferListScreen extends StatefulWidget {
  final String branch;
  final String userName;
  final String branchId;
  final String status; // TransferStatus.draft, submitted, etc.
  final String title;
  final Color themeColor;
  final String direction;

  const TransferListScreen({
    super.key,
    required this.branch,
    required this.userName,
    required this.branchId,
    required this.status,
    required this.title,
    required this.themeColor,
    this.direction = 'outbound',
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
        widget.direction,
      );
    } else if (widget.status == TransferStatus.floating) {
      // In-Transit shows floating + partially received (live tracking)
      list = await TransferV3Dao.getByStatuses(
        [TransferStatus.floating, TransferStatus.partiallyReceived],
        widget.branchId,
        widget.direction,
      );
    } else {
      list = await TransferV3Dao.getByStatus(
        widget.status,
        widget.branchId,
        widget.direction,
      );
    }
    if (!mounted) return;
    setState(() {
      _transfers = list;
      _loading = false;
    });
  }

  Future<void> _openDetail(TransferV3 doc) async {
    // ═══ INBOUND ROUTING ═══
    // If inbound direction + FLOATING/PARTIALLY_RECEIVED → open InboundReceiveScreen
    if (widget.direction == 'inbound' &&
        (doc.status == TransferStatus.floating ||
         doc.status == TransferStatus.partiallyReceived)) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InboundReceiveScreen(
            transferId: doc.transferId,
            branch: widget.branch,
            userName: widget.userName,
          ),
        ),
      );
      _load();
      return;
    }

    // ═══ OUTBOUND SUBMITTED ═══
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
      // Draft OR read-only → popup with details
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
    // v1.0.49 — Load batches for expandable display
    final allBatches = await TransferV3Dao.getBatches(doc.transferId);
    final batchMap = <String, List<TransferItemBatch>>{};
    for (final b in allBatches) {
      batchMap.putIfAbsent(b.productId, () => []).add(b);
    }
    debugPrint('[LIST-VIEW] Loaded ${allBatches.length} batches for ${doc.transferId}');
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
                          await _printPdf(doc, items, batchMap);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                        tooltip: 'Export PDF',
                        onPressed: () async {
                          await _downloadPdf(doc, items, batchMap);
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
                      // v1.0.49 — Expandable batch card
                      final itemBatches = batchMap[item.productId] ?? [];
                      return _ExpandableItemCard(
                        productName: item.productName,
                        sku: item.sku,
                        issuedQty: item.issuedQty,
                        themeColor: widget.themeColor,
                        batches: itemBatches,
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

      // v1.0.55 — Add BATCHES sheet (Option B)
      final batchSheet = excel['BATCHES'];
      // v1.0.58+119 — Full variance tracking in BATCHES sheet
      final batchHeaders = [
        'IST No.', 'From Branch', 'To Branch', 'SKU', 'Product Name',
        'Batch #', 'Lot #', 'MFG Date', 'EXP Date',
        'Issued Qty', 'Received Qty', 'Short/Overage', 'Reason', 'Notes', 'Postback Qty',
        'Unit Cost', 'Total @ Retail', 'Status',
      ];
      for (var i = 0; i < batchHeaders.length; i++) {
        final cell = batchSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = xl.TextCellValue(batchHeaders[i]);
        cell.cellStyle = xl.CellStyle(
          bold: true,
          backgroundColorHex: xl.ExcelColor.fromHexString('#065F46'),
          fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
          horizontalAlign: xl.HorizontalAlign.Center,
        );
      }

      int batchRow = 1;
      for (final doc in _transfers) {
        final items = await TransferV3Dao.getItems(doc.transferId);
        final allBatches = await TransferV3Dao.getBatches(doc.transferId);
        if (allBatches.isEmpty) continue;
        final itemsBySku = <String, TransferV3Item>{
          for (final it in items) it.productId: it,
        };
        final ref = doc.docNumber.isEmpty ? doc.transferId : doc.docNumber;
        for (final b in allBatches) {
          final it = itemsBySku[b.productId];
          if (it == null) continue;
          final mfgStr = '${b.mfgDate.year.toString().padLeft(4,'0')}-${b.mfgDate.month.toString().padLeft(2,'0')}-${b.mfgDate.day.toString().padLeft(2,'0')}';
          final expStr = '${b.expiryDate.year.toString().padLeft(4,'0')}-${b.expiryDate.month.toString().padLeft(2,'0')}-${b.expiryDate.day.toString().padLeft(2,'0')}';
          // v1.0.58+119 — Variance-aware Excel row (uses receivedQty when available)
          final actualReceived = b.receivedQty > 0 ? b.receivedQty : b.transferQty;
          final variance = actualReceived - b.transferQty; // -N=short, +N=overage
          final total = actualReceived * b.unitCost; // Retail based on RECEIVED
          final varianceStr = variance == 0
              ? '-'
              : variance < 0
                  ? '${variance}'  // negative sign for short
                  : '+${variance}'; // + prefix for overage
          final brow = [
            ref,
            '${doc.issuingBranchId} (${doc.issuingBranchName})',
            '${doc.receivingBranchId} (${doc.receivingBranchName})',
            it.sku, it.productName,
            b.batchNumber, b.lotNumber,
            mfgStr, expStr,
            b.transferQty.toString(),           // Issued Qty
            actualReceived.toString(),          // Received Qty
            varianceStr,                        // Short/Overage
            b.shortReason,                      // Reason
            b.varianceNotes,                    // Notes
            b.postbackQty > 0 ? b.postbackQty.toString() : '',  // Postback Qty
            b.unitCost.toStringAsFixed(2),
            total.toStringAsFixed(2),
            doc.status,
          ];
          for (var c = 0; c < brow.length; c++) {
            final cell = batchSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: batchRow));
            cell.value = xl.TextCellValue(brow[c]);
            // v1.0.58+119 — Color code by variance type
            if (variance < 0) {
              // Short — yellow tint
              cell.cellStyle = xl.CellStyle(backgroundColorHex: xl.ExcelColor.fromHexString('#FEF3C7'));
            } else if (variance > 0) {
              // Overage — blue tint
              cell.cellStyle = xl.CellStyle(backgroundColorHex: xl.ExcelColor.fromHexString('#DBEAFE'));
            }
          }
          batchRow++;
        }
      }
      for (var i = 0; i < batchHeaders.length; i++) {
        batchSheet.setColumnWidth(i, 16);
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
  Future<Uint8List> _generatePdf(TransferV3 doc, List<TransferV3Item> items, Map<String, List<TransferItemBatch>> batchesByProduct) async {
    final pdf = pw.Document();
    // ignore: unused_local_variable
    final now = DateTime.now();
    final totalQty = items.fold<int>(0, (s, i) => s + i.issuedQty);
    final totalRetail = items.fold<double>(0.0, (s, i) => s + (i.issuedQty * i.unitCost));

    final pageFormat = pdf_pkg.PdfPageFormat.a4.landscape;
    const itemsPerPage = 20;
    final totalPages = (items.length / itemsPerPage).ceil().clamp(1, 999);

    // Build one copy (either ISSUING or RECEIVING)
    pw.Widget buildCopy({
      required String copyLabel,
      required List<TransferV3Item> pageItems,
      required int startIdx,
      required int currentPage,
      required int totalPagesCount,
    }) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // ═══ TITLE ROW ═══
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 1.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Stock Transfer',
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(width: 8),
                    pw.Text('· ${doc.status}',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Text(copyLabel,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          // ═══ INFO TABLE (From/To/Date/IST) ═══
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(90),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(90),
              3: const pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(children: [
                _p4Info('From Branch', bold: true),
                _p4Info('${doc.issuingBranchId} (${doc.issuingBranchName})'),
                _p4Info('Date Created', bold: true),
                _p4Info(_pdfDate(doc.createdAt)),
              ]),
              pw.TableRow(children: [
                _p4Info('To Branch', bold: true),
                _p4Info('${doc.receivingBranchId} (${doc.receivingBranchName})'),
                _p4Info('IST No.', bold: true),
                _p4Info(doc.docNumber.isEmpty ? doc.transferId : doc.docNumber),
              ]),
            ],
          ),
          pw.SizedBox(height: 6),

          // ═══ ITEMS TABLE ═══
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(70),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(55),
              3: const pw.FixedColumnWidth(75),
              4: const pw.FixedColumnWidth(85),
            },
            children: [
              // Header
              pw.TableRow(children: [
                _p4H('SKU'),
                _p4H('Product Name'),
                _p4H('Unit Retail'),
                _p4H('Issued'),
                _p4H('Received'),
                _p4H('Short +/-'),
                _p4H('Retail Value'),
                _p4H('Variance Value'),
                _p4H('Reason'),
                _p4H('Notes'),
              ]),
              // Data rows — v1.0.55 with batch sub-rows
              ...pageItems.expand<pw.TableRow>((item) {
                final batches = batchesByProduct[item.productId] ?? [];
                final rows = <pw.TableRow>[];

                if (batches.isEmpty) {
                  final retail = item.issuedQty * item.unitCost;
                  rows.add(pw.TableRow(children: [
                    _p4C(item.sku),
                    _p4C(item.productName),
                    _p4CR(item.unitCost.toStringAsFixed(2)),
                    _p4CR(item.issuedQty.toString()),
                    _p4CR(item.issuedQty.toString()),
                    _p4CR('-'),
                    _p4CR(retail.toStringAsFixed(2)),
                    _p4CR('-'),
                    _p4CR('-'),
                    _p4CR('-'),
                  ]));
                } else {
                  // Product header row (bold, 10 cols)
                  rows.add(pw.TableRow(children: [
                    _p4C(item.sku, bold: true),
                    _p4C(item.productName, bold: true),
                    _p4C(''), _p4C(''), _p4C(''), _p4C(''),
                    _p4C(''), _p4C(''), _p4C(''), _p4C(''),
                  ]));

                  // v1.0.58+124 — 10-column batch loop with Variance Value
                  int itemIssued = 0;
                  int itemReceived = 0;
                  double itemTotal = 0;
                  double itemVariance = 0;
                  for (final b in batches) {
                    final actualReceived = b.receivedQty > 0 ? b.receivedQty : b.transferQty;
                    final variance = actualReceived - b.transferQty;
                    final bTotal = actualReceived * b.unitCost;
                    final varianceValue = variance * b.unitCost;
                    itemIssued += b.transferQty;
                    itemReceived += actualReceived;
                    itemTotal += bTotal;
                    itemVariance += varianceValue;
                    final mfgStr = '${b.mfgDate.year.toString().padLeft(4,'0')}-${b.mfgDate.month.toString().padLeft(2,'0')}-${b.mfgDate.day.toString().padLeft(2,'0')}';
                    final expStr = '${b.expiryDate.year.toString().padLeft(4,'0')}-${b.expiryDate.month.toString().padLeft(2,'0')}-${b.expiryDate.day.toString().padLeft(2,'0')}';
                    final info = '   Batch: ${b.batchNumber}  Lot: ${b.lotNumber}  MFG: $mfgStr  EXP: $expStr';
                    final shortStr = variance == 0 ? '-' : (variance < 0 ? variance.toString() : '+$variance');
                    rows.add(pw.TableRow(children: [
                      _p4C(''),
                      _p4C(info),
                      _p4CR(b.unitCost.toStringAsFixed(2)),
                      _p4CR(b.transferQty.toString()),
                      _p4CR(actualReceived.toString()),
                      _p4CR(shortStr),
                      _p4CR(bTotal.toStringAsFixed(2)),
                      _p4CR(variance == 0 ? '-' : varianceValue.toStringAsFixed(2)),
                      _p4CR(b.shortReason.isEmpty ? '-' : b.shortReason),
                      _p4CR(b.varianceNotes.isEmpty ? '-' : b.varianceNotes),
                    ]));
                  }

                  // ITEM SUBTOTAL (light-blue, 10 cols)
                  final itemVarQty = itemReceived - itemIssued;
                  final itemShortStr = itemVarQty == 0 ? '-' : (itemVarQty < 0 ? itemVarQty.toString() : '+$itemVarQty');
                  rows.add(pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: pdf_pkg.PdfColor.fromInt(0xFFE3F2FD),
                    ),
                    children: [
                      _p4C(''),
                      _p4C('ITEM SUBTOTAL', bold: true),
                      _p4CR('-', bold: true),
                      _p4CR(itemIssued.toString(), bold: true),
                      _p4CR(itemReceived.toString(), bold: true),
                      _p4CR(itemShortStr, bold: true),
                      _p4CR(itemTotal.toStringAsFixed(2), bold: true),
                      _p4CR(itemVariance == 0 ? '-' : itemVariance.toStringAsFixed(2), bold: true),
                      _p4CR('-', bold: true),
                      _p4CR('-', bold: true),
                    ],
                  ));
                }
                return rows;
              }),
              // v1.0.58+124 — Grand total (10 cols)
              if (currentPage == totalPagesCount)
                pw.TableRow(children: [
                  _p4C(''),
                  _p4C('Grand Total', bold: true),
                  _p4CR('-', bold: true),
                  _p4CR(totalQty.toString(), bold: true),
                  _p4CR(totalQty.toString(), bold: true),
                  _p4CR('-', bold: true),
                  _p4CR(totalRetail.toStringAsFixed(2), bold: true),
                  _p4CR('-', bold: true),
                  _p4CR('-', bold: true),
                  _p4CR('-', bold: true),
                ]),
              // Empty rows (10 cols)
              for (int i = 0; i < 6; i++)
                pw.TableRow(children: [
                  _p4Empty(), _p4Empty(), _p4Empty(), _p4Empty(), _p4Empty(),
                  _p4Empty(), _p4Empty(), _p4Empty(), _p4Empty(), _p4Empty(),
                ]),
            ],
          ),

          // Continued notice for non-last pages
          if (currentPage != totalPagesCount) ...[
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text('— Continued on next page —',
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
            ),
          ],

          // ═══ SIGNATURES (only on last page) ═══
          if (currentPage == totalPagesCount) ...[
            pw.Spacer(),
            pw.Row(
              children: [
                pw.Expanded(child: _p4Sig('Prepared By:', doc.preparedBy)),
                pw.SizedBox(width: 12),
                pw.Expanded(child: _p4Sig('Approved By:', doc.approvedBy)),
                pw.SizedBox(width: 12),
                pw.Expanded(child: _p4Sig('Received By:', doc.receivedBy)),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                    child: pw.Text('Date Received',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    // Generate pages — 1 A4 per copy
    for (int pageNum = 1; pageNum <= totalPages; pageNum++) {
      final startIdx = (pageNum - 1) * itemsPerPage;
      final endIdx = (startIdx + itemsPerPage).clamp(0, items.length);
      final pageItems = items.sublist(startIdx, endIdx);

      // ISSUING COPY
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => buildCopy(
            copyLabel: 'ISSUING STORE COPY',
            pageItems: pageItems,
            startIdx: startIdx,
            currentPage: pageNum,
            totalPagesCount: totalPages,
          ),
        ),
      );

      // RECEIVING COPY
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => buildCopy(
            copyLabel: 'RECEIVING STORE COPY',
            pageItems: pageItems,
            startIdx: startIdx,
            currentPage: pageNum,
            totalPagesCount: totalPages,
          ),
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _p4Info(String text, {bool bold = false}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
    child: pw.Text(text, style: pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    )),
  );

  static pw.Widget _p4H(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
    alignment: pw.Alignment.center,
    child: pw.Text(text, style: pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
    )),
  );

  static pw.Widget _p4C(String text, {bool bold = false}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    child: pw.Text(text, style: pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    )),
  );

  static pw.Widget _p4CR(String text, {bool bold = false}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    alignment: pw.Alignment.centerRight,
    child: pw.Text(text, style: pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    )),
  );

  static pw.Widget _p4Empty() => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: pw.Text(' ', style: const pw.TextStyle(fontSize: 10)),
  );

  static pw.Widget _p4Sig(String label, String name) => pw.Container(
    padding: const pw.EdgeInsets.only(top: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(width: 0.6)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(name.isEmpty ? '________________' : name,
            style: const pw.TextStyle(fontSize: 10)),
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


  Future<void> _printPdf(TransferV3 doc, List<TransferV3Item> items, Map<String, List<TransferItemBatch>> batchMap) async {
    try {
      final bytes = await _generatePdf(doc, items, batchMap);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e'), backgroundColor: _red),
      );
    }
  }

  Future<void> _downloadPdf(TransferV3 doc, List<TransferV3Item> items, Map<String, List<TransferItemBatch>> batchMap) async {
    try {
      final bytes = await _generatePdf(doc, items, batchMap);
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

// v1.0.49 — Expandable card showing batches
class _ExpandableItemCard extends StatefulWidget {
  final String productName;
  final String sku;
  final int issuedQty;
  final Color themeColor;
  final List<TransferItemBatch> batches;

  const _ExpandableItemCard({
    required this.productName,
    required this.sku,
    required this.issuedQty,
    required this.themeColor,
    required this.batches,
  });

  @override
  State<_ExpandableItemCard> createState() => _ExpandableItemCardState();
}

class _ExpandableItemCardState extends State<_ExpandableItemCard> {
  static const _card = Color(0xFFFFFFFF);
  static const _divider = Color(0xFFE5E7EB);
  static const _textSecondary = Color(0xFF6B7280);
  bool _expanded = false;

  // v1.0.50 — Show batches in full popup dialog on long-press
  Future<void> _showBatchesDialog(BuildContext ctx0) async {
    await showDialog(
      context: ctx0,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.themeColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(children: [
                  const Icon(Icons.qr_code_2, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.productName,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('SKU: ${widget.sku}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  )),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${widget.issuedQty}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const Text('pcs', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.themeColor.withValues(alpha: 0.08),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(children: [
                  Icon(Icons.inventory_2, size: 16, color: widget.themeColor),
                  const SizedBox(width: 8),
                  Text('${widget.batches.length} ${widget.batches.length == 1 ? "batch" : "batches"} selected',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.themeColor)),
                ]),
              ),
              Flexible(child: ListView.builder(
                padding: const EdgeInsets.all(12),
                shrinkWrap: true,
                itemCount: widget.batches.length,
                itemBuilder: (context, i) {
                  final b = widget.batches[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: widget.themeColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: widget.themeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.qr_code_2, size: 14, color: widget.themeColor),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'Batch #${b.batchNumber}${b.lotNumber.isNotEmpty ? " · Lot #${b.lotNumber}" : ""}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          )),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: Builder(builder: (_) {
                            // v1.0.57+109 — Variance-aware display
                            final hasVariance = b.receivedQty != b.transferQty || b.shortReason.isNotEmpty;
                            final displayQty = hasVariance ? b.receivedQty : b.transferQty;
                            final variance = b.receivedQty - b.transferQty;
                            final varColor = variance < 0
                                ? const Color(0xFFF59E0B)
                                : variance > 0
                                    ? const Color(0xFF3B82F6)
                                    : widget.themeColor;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(hasVariance ? 'Received' : 'Qty', style: const TextStyle(fontSize: 10, color: _textSecondary)),
                                Text('$displayQty pcs',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: varColor)),
                                if (hasVariance) Text(
                                  variance < 0
                                      ? 'Issued ${b.transferQty} · Short ${-variance}${b.shortReason.isNotEmpty ? " · ${b.shortReason}" : ""}'
                                      : variance > 0
                                          ? 'Issued ${b.transferQty} · +$variance${b.shortReason.isNotEmpty ? " · ${b.shortReason}" : ""}'
                                          : 'Issued ${b.transferQty}',
                                  style: TextStyle(fontSize: 9, color: varColor, fontWeight: FontWeight.w600),
                                ),
                              ],
                            );
                          })),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('MFG', style: TextStyle(fontSize: 10, color: _textSecondary)),
                              Text('${b.mfgDate.year}-${b.mfgDate.month.toString().padLeft(2, '0')}-${b.mfgDate.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          )),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('EXP', style: TextStyle(fontSize: 10, color: _textSecondary)),
                              Text('${b.expiryDate.year}-${b.expiryDate.month.toString().padLeft(2, '0')}-${b.expiryDate.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          )),
                        ]),
                      ],
                    ),
                  );
                },
              )),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final hasBatches = widget.batches.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: hasBatches ? () => setState(() => _expanded = !_expanded) : null,
            onLongPress: hasBatches ? () => _showBatchesDialog(context) : null,  // v1.0.50
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.productName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('SKU: ${widget.sku}',
                            style: const TextStyle(color: _textSecondary, fontSize: 11)),
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
                        child: Text('${widget.issuedQty}',
                            style: TextStyle(color: widget.themeColor, fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 2),
                      const Text('pcs', style: TextStyle(color: _textSecondary, fontSize: 10)),
                    ],
                  ),
                  if (hasBatches) ...[
                    const SizedBox(width: 6),
                    Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: widget.themeColor),
                  ],
                ],
              ),
            ),
          ),
          if (_expanded && hasBatches)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: widget.batches.map((b) => Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.qr_code_2, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          'Batch #${b.batchNumber}${b.lotNumber.isNotEmpty ? " · Lot #${b.lotNumber}" : ""}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        )),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(child: Builder(builder: (_) {
                          // v1.0.57+109 — Variance-aware inline
                          final hasVariance = b.receivedQty != b.transferQty || b.shortReason.isNotEmpty;
                          final displayQty = hasVariance ? b.receivedQty : b.transferQty;
                          final variance = b.receivedQty - b.transferQty;
                          final varColor = variance < 0
                              ? const Color(0xFFF59E0B)
                              : variance > 0
                                  ? const Color(0xFF3B82F6)
                                  : widget.themeColor;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(hasVariance ? 'Received' : 'Qty', style: const TextStyle(fontSize: 10, color: _textSecondary)),
                              Text('$displayQty pcs',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: varColor)),
                              if (hasVariance) Text(
                                variance < 0
                                    ? 'Issued ${b.transferQty} · Short ${-variance}${b.shortReason.isNotEmpty ? " · ${b.shortReason}" : ""}'
                                    : variance > 0
                                        ? 'Issued ${b.transferQty} · +$variance${b.shortReason.isNotEmpty ? " · ${b.shortReason}" : ""}'
                                        : 'Issued ${b.transferQty}',
                                style: TextStyle(fontSize: 9, color: varColor, fontWeight: FontWeight.w600),
                              ),
                            ],
                          );
                        })),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('MFG', style: TextStyle(fontSize: 10, color: _textSecondary)),
                            Text('${b.mfgDate.year}-${b.mfgDate.month.toString().padLeft(2, '0')}-${b.mfgDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 12)),
                          ],
                        )),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('EXP', style: TextStyle(fontSize: 10, color: _textSecondary)),
                            Text('${b.expiryDate.year}-${b.expiryDate.month.toString().padLeft(2, '0')}-${b.expiryDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 12)),
                          ],
                        )),
                      ]),
                    ],
                  ),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

