// lib/screens/receive_delivery/rejected_list_screen.dart
import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../helpers/database_helper.dart';
import '../../services/firebase_config_service.dart';
import '../../services/firebase_realtime_service.dart';
import '../../services/device_assignment_service.dart';
import 'delivery_model.dart';

class RejectedListScreen extends StatefulWidget {
  final List<Product> products;
  const RejectedListScreen({super.key, required this.products});

  @override
  State<RejectedListScreen> createState() => _RejectedListScreenState();
}

class _RejectedListScreenState extends State<RejectedListScreen> {
  List<DeliveryRecord> _rejected = [];
  List<DeliveryRecord> _filtered = [];
  final _searchCtrl = TextEditingController();
  String _sortBy = 'newest';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRejected();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _loadRejected() async {
    setState(() => _loading = true);
    final list = await DeliveryStorage.getByStatus(DeliveryStatus.rejected);
    if (mounted) {
      setState(() {
        _rejected = list;
        _applyFiltersSort();
        _loading = false;
      });
    }
  }

  void _applyFiltersSort() {
    List<DeliveryRecord> filtered = List.from(_rejected);
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((d) {
        return d.refNumber.toLowerCase().contains(q) ||
               d.supplier.toLowerCase().contains(q) ||
               d.rejectedBy.toLowerCase().contains(q);
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
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.cancel_outlined, size: 20),
              SizedBox(width: 8),
              Text('REJECTED', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ]),
            Text('${_rejected.length} rejected deliveries', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.sort_rounded, size: 22), onPressed: _showSortDialog),
          IconButton(icon: const Icon(Icons.refresh_rounded, size: 22), onPressed: _loadRejected),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFFDC2626),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _applyFiltersSort(),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search DR#, supplier, rejecter...',
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
                        onRefresh: _loadRejected,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            int columns;
                            if (constraints.maxWidth < 600) {
                              columns = 1;
                            } else if (constraints.maxWidth < 1200) {
                              columns = 2;
                            } else {
                              columns = 3;
                            }
                            return GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                childAspectRatio: 2.4,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) => _buildCard(_filtered[i]),
                            );
                          },
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
            decoration: const BoxDecoration(color: Color(0xFFFECACA), shape: BoxShape.circle),
            child: const Icon(Icons.cancel_outlined, size: 60, color: Color(0xFFDC2626)),
          ),
          const SizedBox(height: 16),
          Text(_searchCtrl.text.isEmpty ? 'No rejected deliveries' : 'No matches found',
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCard(DeliveryRecord d) {
    DateTime? rejectedDate;
    try { rejectedDate = DateTime.parse(d.rejectedDate); } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.2), width: 1),
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
                    decoration: BoxDecoration(color: const Color(0xFFFECACA), borderRadius: BorderRadius.circular(6)),
                    child: Text('DR: ${d.refNumber.isEmpty ? "-" : d.refNumber}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(10)),
                    child: const Text('REJECTED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(d.supplier.isEmpty ? '(No supplier)' : d.supplier,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                if (rejectedDate != null) Row(children: [
                  Icon(Icons.event_busy_outlined, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Rejected: ${_fmtDate(rejectedDate)} · ${_fmtTime(rejectedDate)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                ]),
                if (rejectedDate != null) const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.inventory_2_outlined, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${d.totalItems} items · ${_fmtInt(d.totalQuantity)} pcs',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  const Spacer(),
                  Text('₱${_fmtInt(d.totalRetail.toInt())}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                ]),
                if (d.rejectionReason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0xFFFECACA).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6)),
                    child: Row(children: [
                      Icon(Icons.info_outline, size: 12, color: Colors.red[700]),
                      const SizedBox(width: 4),
                      Expanded(child: Text('Reason: ${d.rejectionReason}',
                          style: TextStyle(fontSize: 11, color: Colors.red[900], fontStyle: FontStyle.italic))),
                    ]),
                  ),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(d),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[400]!, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmResubmit(d),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Resubmit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmResubmit(DeliveryRecord d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: const [
          Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 26),
          SizedBox(width: 10),
          Text('Resubmit Delivery?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DR#: ${d.refNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Previous reason: ${d.rejectionReason}',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.red)),
            const SizedBox(height: 8),
            const Text('This will resubmit the delivery for approval again.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: const Text('Resubmit'),
          ),
        ],
      ),
    );
    if (confirm == true) await _resubmit(d);
  }

  Future<void> _resubmit(DeliveryRecord d) async {
    try {
      final now = DateTime.now();
      final assign = await DeviceAssignmentService().read();
      final user = (assign['userName'] ?? assign['userDisplayName'] ?? '').toString();

      await DeliveryStorage.updateStatus(d.id, {
        'status': DeliveryStatus.submitted,
        'submittedDate': now.toIso8601String(),
        'submittedBy': user,
        'rejectedDate': '',
        'rejectedBy': '',
        'rejectionReason': '',
        'syncStatus': 'Pending',
      });

      await DatabaseHelper().insertApprovalHistory({
        'id': 'H-${now.millisecondsSinceEpoch}',
        'deliveryId': d.id,
        'action': 'Resubmitted',
        'user': user,
        'date': now.toIso8601String(),
        'remarks': 'Resubmitted after rejection',
      });

      final updated = d.copyWith(
        status: DeliveryStatus.submitted,
        submittedDate: now.toIso8601String(),
        submittedBy: user,
        rejectedDate: '',
        rejectedBy: '',
        rejectionReason: '',
      );
      _moveFirebase(d.id, 'branchRejectedDelivery', 'branchSubmittedDelivery', updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.refresh_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Resubmitted: ${d.refNumber}')),
          ]),
          backgroundColor: const Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadRejected();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _confirmDelete(DeliveryRecord d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
          SizedBox(width: 10),
          Text('Delete Delivery?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Text('This will permanently delete:\nDR#: ${d.refNumber}\n\nThis cannot be undone.',
            style: const TextStyle(fontSize: 13)),
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
      _deleteFromFirebase(d.id, 'branchRejectedDelivery');
      _loadRejected();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Deleted'), backgroundColor: Colors.red[600], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _moveFirebase(String id, String fromNode, String toNode, DeliveryRecord updated) async {
    try {
      final cfg = await FirebaseConfigService().load();
      if (cfg == null) return;
      final assign = await DeviceAssignmentService().read();
      final companyCode = (assign['companyCode'] ?? '').toString();
      final branchId = (assign['branchId'] ?? '').toString();
      if (companyCode.isEmpty || branchId.isEmpty) return;
      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/$fromNode/$branchId/$id').remove();
      await db.ref('companies/$companyCode/$toNode/$branchId/$id').set(updated.toJson());
    } catch (e) { debugPrint('[WORKFLOW] Move error: $e'); }
  }

  Future<void> _deleteFromFirebase(String id, String node) async {
    try {
      final cfg = await FirebaseConfigService().load();
      if (cfg == null) return;
      final assign = await DeviceAssignmentService().read();
      final companyCode = (assign['companyCode'] ?? '').toString();
      final branchId = (assign['branchId'] ?? '').toString();
      if (companyCode.isEmpty || branchId.isEmpty) return;
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/$node/$branchId/$id').remove();
    } catch (e) { debugPrint('[WORKFLOW] Delete error: $e'); }
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
              const Text('Rejected Delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const Divider(),
            if (d.rejectionReason.isNotEmpty) Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFECACA).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rejection Reason:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[900])),
                  const SizedBox(height: 3),
                  Text(d.rejectionReason, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            _detailRow('DR #', d.refNumber),
            _detailRow('Supplier', d.supplier),
            _detailRow('Driver', d.driverName),
            _detailRow('Plate #', d.plateNumber),
            _detailRow('Submitted By', d.submittedBy),
            _detailRow('Rejected By', d.rejectedBy),
            _detailRow('Rejected Date', d.rejectedDate.isEmpty ? '-' : _fmtFull(d.rejectedDate)),
            _detailRow('Total Items', '${d.totalItems}'),
            _detailRow('Total Qty', '${_fmtInt(d.totalQuantity)} pcs'),
            _detailRow('Total @ Retail', '₱${_fmtInt(d.totalRetail.toInt())}'),
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
      leading: Icon(icon, color: selected ? const Color(0xFFDC2626) : Colors.grey[600], size: 20),
      title: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      trailing: selected ? const Icon(Icons.check, color: Color(0xFFDC2626), size: 20) : null,
      onTap: () { setState(() => _sortBy = value); _applyFiltersSort(); Navigator.pop(ctx); },
    );
  }
}
