// lib/screens/receive_delivery/draft_list_screen.dart
import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../helpers/database_helper.dart';
import 'delivery_model.dart';
import 'receive_delivery_screen.dart';

class DraftListScreen extends StatefulWidget {
  final List<Product> products;
  const DraftListScreen({super.key, required this.products});

  @override
  State<DraftListScreen> createState() => _DraftListScreenState();
}

class _DraftListScreenState extends State<DraftListScreen> {
  List<DeliveryRecord> _drafts = [];
  List<DeliveryRecord> _filtered = [];
  final _searchCtrl = TextEditingController();
  String _sortBy = 'newest'; // newest, oldest, supplier, dr
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDrafts() async {
    setState(() => _loading = true);
    final list = await DeliveryStorage.getByStatus(DeliveryStatus.draft);
    if (mounted) {
      setState(() {
        _drafts = list;
        _applyFiltersSort();
        _loading = false;
      });
    }
  }

  void _applyFiltersSort() {
    List<DeliveryRecord> filtered = List.from(_drafts);

    // Search filter
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((d) {
        return d.refNumber.toLowerCase().contains(q) ||
               d.supplier.toLowerCase().contains(q);
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'oldest':
        filtered.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        break;
      case 'supplier':
        filtered.sort((a, b) => a.supplier.compareTo(b.supplier));
        break;
      case 'dr':
        filtered.sort((a, b) => a.refNumber.compareTo(b.refNumber));
        break;
      case 'newest':
      default:
        filtered.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        break;
    }

    setState(() => _filtered = filtered);
  }

  String _fmtDate(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  String _fmtTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  String _fmtInt(int n) => n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF7C3AED), // Purple
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.description_outlined, size: 20),
              SizedBox(width: 8),
              Text('DRAFT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ]),
            Text(
              '${_drafts.length} saved · Not submitted',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded, size: 22),
            tooltip: 'Sort',
            onPressed: _showSortDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Refresh',
            onPressed: _loadDrafts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: const Color(0xFF7C3AED),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _applyFiltersSort(),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search DR# or supplier...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFiltersSort();
                        },
                      )
                    : null,
              ),
            ),
          ),
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadDrafts,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // TABLE VIEW for desktop (> 1024px)
                            if (constraints.maxWidth > 1024) {
                              return Column(
                                children: [
                                  _buildTableHeader(),
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      itemCount: _filtered.length,
                                      itemBuilder: (_, i) => _buildDraftRow(_filtered[i]),
                                    ),
                                  ),
                                ],
                              );
                            }
                            // GRID VIEW for phone/tablet
                            int columns = constraints.maxWidth < 600 ? 1 : 2;
                            return GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                childAspectRatio: 2.4,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) => _buildDraftCard(_filtered[i]),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFFEDE9FE), shape: BoxShape.circle),
            child: Icon(Icons.description_outlined, size: 60, color: const Color(0xFF7C3AED)),
          ),
          const SizedBox(height: 16),
          Text(
            _searchCtrl.text.isEmpty ? 'No drafts yet' : 'No matches found',
            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            _searchCtrl.text.isEmpty ? 'Draft deliveries appear here' : 'Try a different search',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }


  // ═══ TABLE VIEW (Desktop > 1024px) ═══
  Widget _buildTableHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: _headerText('DATE')),
          Expanded(flex: 2, child: _headerText('DR #')),
          Expanded(flex: 2, child: _headerText('SUPPLIER')),
          Expanded(flex: 2, child: _headerText('TOTAL', align: TextAlign.right)),
          Expanded(flex: 2, child: _headerText('ITEMS / QTY', align: TextAlign.center)),
          Expanded(flex: 2, child: _headerText('ACTIONS', align: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _headerText(String text, {TextAlign align = TextAlign.left}) {
    return Text(
      text,
      textAlign: align,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFF7C3AED),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDraftRow(DeliveryRecord d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.15)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openDraft(d),
          child: Row(
            children: [
              // DATE
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${_fmtDate(d.dateTime)} ${_fmtTime(d.dateTime)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              // DR #
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DR: ${d.refNumber.isEmpty ? "-" : d.refNumber}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // SUPPLIER
              Expanded(
                flex: 2,
                child: Text(
                  d.supplier.isEmpty ? '-' : d.supplier,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // TOTAL
              Expanded(
                flex: 2,
                child: Text(
                  '\u20B1${_fmtInt(d.totalRetail.toInt())}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              // ITEMS / QTY
              Expanded(
                flex: 2,
                child: Text(
                  '${d.totalItems} \u00B7 ${_fmtInt(d.totalQuantity)} pcs',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
              // ACTIONS
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _confirmDelete(d),
                      icon: const Icon(Icons.delete_outline, size: 14),
                      label: const Text('Del', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[600],
                        side: BorderSide(color: Colors.red[300]!),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () => _openDraft(d),
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Continue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraftCard(DeliveryRecord d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDraft(d),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'DR: ${d.refNumber.isEmpty ? "-" : d.refNumber}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'DRAFT',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Supplier
                Text(
                  d.supplier.isEmpty ? '(No supplier)' : d.supplier,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Date + time
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${_fmtDate(d.dateTime)} · ${_fmtTime(d.dateTime)}', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                    const Spacer(),
                    Icon(Icons.inventory_2_outlined, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${d.totalItems} items · ${_fmtInt(d.totalQuantity)} pcs', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  ],
                ),
                const SizedBox(height: 4),
                // Total
                Row(
                  children: [
                    Icon(Icons.sell_outlined, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('Total: ₱${_fmtInt(d.totalRetail.toInt())}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                    if (d.lastEditedDate.isNotEmpty) ...[
                      const Spacer(),
                      Icon(Icons.edit_outlined, size: 11, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Text('Edited: ${_fmtEdited(d.lastEditedDate)}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                // Actions
                Row(
                  children: [
                    // Delete
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmDelete(d),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[600],
                          side: BorderSide(color: Colors.red[300]!, width: 1),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Continue
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _openDraft(d),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Continue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtEdited(String iso) {
    try {
      final d = DateTime.parse(iso);
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return _fmtDate(d);
    } catch (_) {
      return '';
    }
  }

  Future<void> _openDraft(DeliveryRecord d) async {
    // Open Receive Delivery in edit mode (Phase F will handle real edit)
    // For now: just open Receive Delivery with existing products
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceiveDeliveryScreen(products: widget.products)),
    );
    _loadDrafts(); // Refresh on return
  }

  Future<void> _confirmDelete(DeliveryRecord d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
          SizedBox(width: 10),
          Text('Delete Draft?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'This will permanently delete draft:\nDR#: ${d.refNumber}\n\nThis action cannot be undone.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DeliveryStorage.deleteDelivery(d.id);
      _loadDrafts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Draft deleted'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sort By', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _sortOption(ctx, 'newest', 'Newest first', Icons.arrow_downward),
            _sortOption(ctx, 'oldest', 'Oldest first', Icons.arrow_upward),
            _sortOption(ctx, 'supplier', 'By Supplier', Icons.business),
            _sortOption(ctx, 'dr', 'By DR#', Icons.receipt),
          ],
        ),
      ),
    );
  }

  Widget _sortOption(BuildContext ctx, String value, String label, IconData icon) {
    final selected = _sortBy == value;
    return ListTile(
      leading: Icon(icon, color: selected ? const Color(0xFF7C3AED) : Colors.grey[600], size: 20),
      title: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      trailing: selected ? const Icon(Icons.check, color: Color(0xFF7C3AED), size: 20) : null,
      onTap: () {
        setState(() => _sortBy = value);
        _applyFiltersSort();
        Navigator.pop(ctx);
      },
    );
  }
}
