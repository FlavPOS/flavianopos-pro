// lib/screens/receive_delivery/submitted_list_screen.dart
import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../helpers/database_helper.dart';
import '../../services/firebase_config_service.dart';
import '../../services/firebase_realtime_service.dart';
import '../../services/device_assignment_service.dart';
import 'delivery_model.dart';

class SubmittedListScreen extends StatefulWidget {
  final List<Product> products;
  const SubmittedListScreen({super.key, required this.products});

  @override
  State<SubmittedListScreen> createState() => _SubmittedListScreenState();
}

class _SubmittedListScreenState extends State<SubmittedListScreen> {
  List<DeliveryRecord> _submitted = [];
  List<DeliveryRecord> _filtered = [];
  final _searchCtrl = TextEditingController();
  String _sortBy = 'newest';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmitted();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSubmitted() async {
    setState(() => _loading = true);
    final list = await DeliveryStorage.getByStatus(DeliveryStatus.submitted);
    if (mounted) {
      setState(() {
        _submitted = list;
        _applyFiltersSort();
        _loading = false;
      });
    }
  }

  void _applyFiltersSort() {
    List<DeliveryRecord> filtered = List.from(_submitted);
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((d) {
        return d.refNumber.toLowerCase().contains(q) ||
               d.supplier.toLowerCase().contains(q) ||
               d.submittedBy.toLowerCase().contains(q);
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
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.send_rounded, size: 20),
              SizedBox(width: 8),
              Text('SUBMITTED', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ]),
            Text('${_submitted.length} pending approval', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.sort_rounded, size: 22), tooltip: 'Sort', onPressed: _showSortDialog),
          IconButton(icon: const Icon(Icons.refresh_rounded, size: 22), tooltip: 'Refresh', onPressed: _loadSubmitted),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF2563EB),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _applyFiltersSort(),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search DR#, supplier, submitter...',
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
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadSubmitted,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 1024) {
                              return Column(
                                children: [
                                  _buildTableHeader(),
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      itemCount: _filtered.length,
                                      itemBuilder: (_, i) => _buildTableRow(_filtered[i]),
                                    ),
                                  ),
                                ],
                              );
                            }
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Color(0xFFDBEAFE), shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded, size: 60, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 16),
          Text(_searchCtrl.text.isEmpty ? 'No pending submissions' : 'No matches found',
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(height: 6),
          Text(_searchCtrl.text.isEmpty ? 'Submitted deliveries appear here' : 'Try a different search',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }


  Widget _buildTableHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: _headerText('DATE')),
          Expanded(flex: 2, child: _headerText('DR #')),
          Expanded(flex: 2, child: _headerText('SUPPLIER')),
          Expanded(flex: 2, child: _headerText('TOTAL', align: TextAlign.right)),
          Expanded(flex: 2, child: _headerText('ITEMS / QTY', align: TextAlign.center)),
          Expanded(flex: 2, child: _headerText('STATUS', align: TextAlign.center)),
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
        color: Color(0xFF2563EB),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTableRow(DeliveryRecord d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.15)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showDetails(d),
          child: Row(
            children: [
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
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DR: ${d.refNumber.isEmpty ? "-" : d.refNumber}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  d.supplier.isEmpty ? '-' : d.supplier,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '\u20B1${_fmtInt(d.totalRetail.toInt())}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${d.totalItems} \u00B7 ${_fmtInt(d.totalQuantity)} pcs',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'PENDING',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(DeliveryRecord d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2), width: 1),
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
                    decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(6)),
                    child: Text('DR: ${d.refNumber.isEmpty ? "-" : d.refNumber}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(10)),
                    child: const Text('PENDING', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(d.supplier.isEmpty ? '(No supplier)' : d.supplier,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${_fmtDate(d.dateTime)} · ${_fmtTime(d.dateTime)}', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  const Spacer(),
                  Icon(Icons.inventory_2_outlined, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${d.totalItems} items · ${_fmtInt(d.totalQuantity)} pcs', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.sell_outlined, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Total: ₱${_fmtInt(d.totalRetail.toInt())}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                  if (d.submittedBy.isNotEmpty) ...[
                    const Spacer(),
                    Icon(Icons.person_outline, size: 11, color: Colors.grey[500]),
                    const SizedBox(width: 3),
                    Text('by ${d.submittedBy}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ],
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(d),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Reject', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[600],
                        side: BorderSide(color: Colors.red[300]!, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmApprove(d),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
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

  Future<void> _confirmApprove(DeliveryRecord d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: const [
          Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 26),
          SizedBox(width: 10),
          Text('Approve Delivery?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DR#: ${d.refNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Supplier: ${d.supplier}', style: const TextStyle(fontSize: 12)),
            Text('Items: ${d.totalItems} · Qty: ${_fmtInt(d.totalQuantity)}', style: const TextStyle(fontSize: 12)),
            Text('Total: ₱${_fmtInt(d.totalRetail.toInt())}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('This will approve the delivery and mark it as received.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirm == true) await _approve(d);
  }

  Future<void> _approve(DeliveryRecord d) async {
    try {
      final now = DateTime.now();
      final assign = await DeviceAssignmentService().read();
      final approver = (assign['userName'] ?? assign['userDisplayName'] ?? '').toString();

      // Update SQLite
      await DeliveryStorage.updateStatus(d.id, {
        'status': DeliveryStatus.approved,
        'approvedDate': now.toIso8601String(),
        'approvedBy': approver,
        'syncStatus': 'Pending',
      });

      // Log to approval_history
      await DatabaseHelper().insertApprovalHistory({
        'id': 'H-${now.millisecondsSinceEpoch}',
        'deliveryId': d.id,
        'action': 'Approved',
        'user': approver,
        'date': now.toIso8601String(),
        'remarks': '',
      });

      // Firebase: Move from branchSubmittedDelivery to branchReceivedDelivery
      final updated = d.copyWith(
        status: DeliveryStatus.approved,
        approvedDate: now.toIso8601String(),
        approvedBy: approver,
      );
      _moveDeliveryFirebase(d.id, 'branchSubmittedDelivery', 'branchReceivedDelivery', updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Approved: ${d.refNumber}')),
          ]),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      _loadSubmitted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showRejectDialog(DeliveryRecord d) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: const [
          Icon(Icons.cancel_outlined, color: Colors.red, size: 26),
          SizedBox(width: 10),
          Text('Reject Delivery?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DR#: ${d.refNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            const Text('Reason for rejection: *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. Damaged items, Wrong quantity...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(10),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final txt = reasonCtrl.text.trim();
              if (txt.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx, txt);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) await _reject(d, reason);
  }

  Future<void> _reject(DeliveryRecord d, String reason) async {
    try {
      final now = DateTime.now();
      final assign = await DeviceAssignmentService().read();
      final rejecter = (assign['userName'] ?? assign['userDisplayName'] ?? '').toString();

      await DeliveryStorage.updateStatus(d.id, {
        'status': DeliveryStatus.rejected,
        'rejectedDate': now.toIso8601String(),
        'rejectedBy': rejecter,
        'rejectionReason': reason,
        'syncStatus': 'Pending',
      });

      await DatabaseHelper().insertApprovalHistory({
        'id': 'H-${now.millisecondsSinceEpoch}',
        'deliveryId': d.id,
        'action': 'Rejected',
        'user': rejecter,
        'date': now.toIso8601String(),
        'remarks': reason,
      });

      final updated = d.copyWith(
        status: DeliveryStatus.rejected,
        rejectedDate: now.toIso8601String(),
        rejectedBy: rejecter,
        rejectionReason: reason,
      );
      _moveDeliveryFirebase(d.id, 'branchSubmittedDelivery', 'branchRejectedDelivery', updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.cancel, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Rejected: ${d.refNumber}')),
          ]),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      _loadSubmitted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // Firebase move: DELETE from oldNode, UPLOAD to newNode (Multi-branch tier only)
  Future<void> _moveDeliveryFirebase(String deliveryId, String fromNode, String toNode, DeliveryRecord updated) async {
    try {
      final cfg = await FirebaseConfigService().load();
      if (cfg == null) return; // SOLO tier - skip
      final assign = await DeviceAssignmentService().read();
      final companyCode = (assign['companyCode'] ?? '').toString();
      final branchId = (assign['branchId'] ?? '').toString();
      if (companyCode.isEmpty || branchId.isEmpty) return;

      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;

      // Delete from old node
      await db.ref('companies/$companyCode/$fromNode/$branchId/$deliveryId').remove();
      // Upload to new node
      await db.ref('companies/$companyCode/$toNode/$branchId/$deliveryId').set(updated.toJson());
      debugPrint('[WORKFLOW] Moved $deliveryId: $fromNode -> $toNode');
    } catch (e) {
      debugPrint('[WORKFLOW] Move error: $e');
    }
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
              const Text('Delivery Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            _detailRow('Submitted Date', d.submittedDate.isEmpty ? '-' : _fmtEditedFull(d.submittedDate)),
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

  String _fmtEditedFull(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${_fmtDate(d)} ${_fmtTime(d)}';
    } catch (_) { return iso; }
  }

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
      leading: Icon(icon, color: selected ? const Color(0xFF2563EB) : Colors.grey[600], size: 20),
      title: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      trailing: selected ? const Icon(Icons.check, color: Color(0xFF2563EB), size: 20) : null,
      onTap: () { setState(() => _sortBy = value); _applyFiltersSort(); Navigator.pop(ctx); },
    );
  }
}
