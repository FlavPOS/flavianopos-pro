// lib/screens/receive_delivery/approved_list_screen.dart
import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import 'delivery_model.dart';

class ApprovedListScreen extends StatefulWidget {
  final List<Product> products;
  const ApprovedListScreen({super.key, required this.products});

  @override
  State<ApprovedListScreen> createState() => _ApprovedListScreenState();
}

class _ApprovedListScreenState extends State<ApprovedListScreen> {
  List<DeliveryRecord> _approved = [];
  List<DeliveryRecord> _filtered = [];
  final _searchCtrl = TextEditingController();
  String _sortBy = 'newest';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadApproved();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _loadApproved() async {
    setState(() => _loading = true);
    final list = await DeliveryStorage.getByStatus(DeliveryStatus.approved);
    if (mounted) {
      setState(() {
        _approved = list;
        _applyFiltersSort();
        _loading = false;
      });
    }
  }

  void _applyFiltersSort() {
    List<DeliveryRecord> filtered = List.from(_approved);
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((d) {
        return d.refNumber.toLowerCase().contains(q) ||
               d.supplier.toLowerCase().contains(q) ||
               d.approvedBy.toLowerCase().contains(q);
      }).toList();
    }
    switch (_sortBy) {
      case 'oldest': filtered.sort((a, b) => a.dateTime.compareTo(b.dateTime)); break;
      case 'supplier': filtered.sort((a, b) => a.supplier.compareTo(b.supplier)); break;
      case 'dr': filtered.sort((a, b) => a.refNumber.compareTo(b.refNumber)); break;
      case 'newest':
      default: filtered.sort((a, b) => b.dateTime.compareTo(a.dateTime)); break;
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
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.check_circle_outline, size: 20),
              SizedBox(width: 8),
              Text('APPROVED', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ]),
            Text('${_approved.length} approved deliveries', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.sort_rounded, size: 22), onPressed: _showSortDialog),
          IconButton(icon: const Icon(Icons.refresh_rounded, size: 22), onPressed: _loadApproved),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF16A34A),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _applyFiltersSort(),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search DR#, supplier, approver...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); _applyFiltersSort(); })
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _loadApproved,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _buildCard(_filtered[i]),
                        ),
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
            decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline, size: 60, color: Color(0xFF16A34A)),
          ),
          const SizedBox(height: 16),
          Text(_searchCtrl.text.isEmpty ? 'No approved deliveries yet' : 'No matches found',
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCard(DeliveryRecord d) {
    DateTime? approvedDate;
    try { approvedDate = DateTime.parse(d.approvedDate); } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDetails(d),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                    child: Text('DR: ${d.refNumber.isEmpty ? "-" : d.refNumber}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(10)),
                    child: const Text('APPROVED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(d.supplier.isEmpty ? '(No supplier)' : d.supplier,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                if (approvedDate != null) Row(children: [
                  Icon(Icons.event_available_outlined, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Approved: ${_fmtDate(approvedDate)} · ${_fmtTime(approvedDate)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                ]),
                if (approvedDate != null) const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.inventory_2_outlined, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${d.totalItems} items · ${_fmtInt(d.totalQuantity)} pcs',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  const Spacer(),
                  if (d.approvedBy.isNotEmpty) ...[
                    Icon(Icons.person_outline, size: 11, color: Colors.grey[500]),
                    const SizedBox(width: 3),
                    Text('by ${d.approvedBy}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ],
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.sell_outlined, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Total: ₱${_fmtInt(d.totalRetail.toInt())}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(DeliveryRecord d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(children: [
              const Text('Approved Delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const Divider(),
            _detailRow('DR #', d.refNumber),
            _detailRow('Supplier', d.supplier),
            _detailRow('Driver', d.driverName),
            _detailRow('Plate #', d.plateNumber),
            _detailRow('Received By', d.receivedBy),
            _detailRow('Submitted By', d.submittedBy),
            _detailRow('Approved By', d.approvedBy),
            _detailRow('Approved Date', d.approvedDate.isEmpty ? '-' : _fmtFull(d.approvedDate)),
            _detailRow('Total Items', '${d.totalItems}'),
            _detailRow('Total Qty', '${_fmtInt(d.totalQuantity)} pcs'),
            _detailRow('Total @ Retail', '₱${_fmtInt(d.totalRetail.toInt())}'),
            if (d.notes.isNotEmpty) _detailRow('Notes', d.notes),
            const Divider(),
            const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            ...d.items.map((i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)),
                  child: Text(i.sku, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(i.itemName, style: const TextStyle(fontSize: 12))),
                Text('${i.quantity}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  String _fmtFull(String iso) { try { final d = DateTime.parse(iso); return '${_fmtDate(d)} ${_fmtTime(d)}'; } catch (_) { return iso; } }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text('$label:', style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
          Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
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
      leading: Icon(icon, color: selected ? const Color(0xFF16A34A) : Colors.grey[600], size: 20),
      title: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      trailing: selected ? const Icon(Icons.check, color: Color(0xFF16A34A), size: 20) : null,
      onTap: () { setState(() => _sortBy = value); _applyFiltersSort(); Navigator.pop(ctx); },
    );
  }
}
