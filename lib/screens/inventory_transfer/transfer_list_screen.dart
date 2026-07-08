import 'package:flutter/material.dart';
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
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
                    controller: scrollCtrl,
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
              ],
            );
          },
        );
      },
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
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _transfers.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _transfers.length,
                  itemBuilder: (context, index) => _buildCard(_transfers[index]),
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
}
