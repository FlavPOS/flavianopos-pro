// lib/screens/receive_delivery/submitted_list_screen.dart
import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../helpers/database_helper.dart';
import '../../services/firebase_config_service.dart';
import '../../services/firebase_realtime_service.dart';
import '../../services/device_assignment_service.dart';
import '../../widgets/receive_delivery/submitted_list_table.dart';
import 'submitted_detail_screen.dart';
import 'delivery_model.dart';

class SubmittedListScreen extends StatefulWidget {
  final List<Product> products;
  const SubmittedListScreen({super.key, required this.products});

  @override
  State<SubmittedListScreen> createState() => _SubmittedListScreenState();
}

class _SubmittedListScreenState extends State<SubmittedListScreen> {
  List<DeliveryRecord> _submitted = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmitted();
  }

  Future<void> _loadSubmitted() async {
    setState(() => _loading = true);
    final list = await DeliveryStorage.getByStatus(DeliveryStatus.submitted);
    if (mounted) {
      setState(() {
        _submitted = list;
        _loading = false;
      });
    }
  }

  List<SubmittedItem> get _items => _submitted.map((d) => SubmittedItem(
    drNumber: d.refNumber.isEmpty ? '(no DR)' : d.refNumber,
    supplier: d.supplier,
    date: d.dateTime,
    itemsCount: d.totalItems,
    totalQty: d.totalQuantity,
    totalValue: d.totalRetail,
    submittedBy: d.submittedBy,
  )).toList();

  DeliveryRecord? _findRecord(SubmittedItem item) {
    for (final d in _submitted) {
      if (d.refNumber == item.drNumber &&
          d.dateTime == item.date &&
          d.totalRetail == item.totalValue) {
        return d;
      }
    }
    return null;
  }

  String _fmtInt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _fmtDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _fmtEditedFull(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${_fmtDate(d)} ${_fmtTime(d)}';
    } catch (_) { return iso; }
  }

  // ═══ ROLE-BASED PIN VERIFICATION ═══
  Future<bool> _verifyApproverPin() async {
    final pinCtrl = TextEditingController();
    bool obscure = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(children: const [
            Icon(Icons.lock_outline, color: Color(0xFF2563EB), size: 24),
            SizedBox(width: 10),
            Text('Approver PIN Required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Only Supervisor, Manager, or Admin can approve/reject.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                obscureText: obscure,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Enter PIN',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setStateD(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final pin = pinCtrl.text.trim();
                if (pin.isEmpty) return;
                // Verify PIN against users with Supervisor/Manager/Admin roles
                final users = await DatabaseHelper().getAllUsers();
                final valid = users.any((u) {
                  final role = (u['role'] ?? '').toString().toLowerCase();
                  final userPin = (u['pin'] ?? '').toString();
                  final isActive = u['isActive'] == 1 || u['isActive'] == true;
                  final hasAuth = role.contains('supervisor') ||
                                  role.contains('manager') ||
                                  role.contains('admin');
                  return isActive && hasAuth && userPin == pin;
                });
                if (valid) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid PIN or insufficient role'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Future<void> _confirmApprove(SubmittedItem item) async {
    final d = _findRecord(item);
    if (d == null) return;

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
            const Text('Requires Supervisor / Manager / Admin PIN.',
                style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
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
    if (confirm != true) return;

    final pinOk = await _verifyApproverPin();
    if (!pinOk) return;

    await _approve(d);
  }

  Future<void> _approve(DeliveryRecord d) async {
    try {
      final now = DateTime.now();
      final assign = await DeviceAssignmentService().read();
      final approver = (assign['userName'] ?? assign['userDisplayName'] ?? '').toString();

      await DeliveryStorage.updateStatus(d.id, {
        'status': DeliveryStatus.approved,
        'approvedDate': now.toIso8601String(),
        'approvedBy': approver,
        'syncStatus': 'Pending',
      });

      await DatabaseHelper().insertApprovalHistory({
        'id': 'H-${now.millisecondsSinceEpoch}',
        'deliveryId': d.id,
        'action': 'Approved',
        'user': approver,
        'date': now.toIso8601String(),
        'remarks': '',
      });

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

  Future<void> _showRejectDialog(SubmittedItem item) async {
    final d = _findRecord(item);
    if (d == null) return;

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
            const SizedBox(height: 8),
            const Text('Requires Supervisor / Manager / Admin PIN.',
                style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
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

    if (reason == null || reason.isEmpty) return;

    final pinOk = await _verifyApproverPin();
    if (!pinOk) return;

    await _reject(d, reason);
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

  Future<void> _moveDeliveryFirebase(String deliveryId, String fromNode, String toNode, DeliveryRecord updated) async {
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

      await db.ref('companies/$companyCode/$fromNode/$branchId/$deliveryId').remove();
      await db.ref('companies/$companyCode/$toNode/$branchId/$deliveryId').set(updated.toJson());
      debugPrint('[WORKFLOW] Moved $deliveryId: $fromNode -> $toNode');
    } catch (e) {
      debugPrint('[WORKFLOW] Move error: $e');
    }
  }

  void _showDetails(SubmittedItem item) async {
    final d = _findRecord(item);
    if (d == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SubmittedDetailScreen(record: d)),
    );
    if (result == true) _loadSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SubmittedListTable(
                items: _items,
                onBack: () => Navigator.pop(context),
                onRefresh: _loadSubmitted,
                onView: _showDetails,
              ),
      ),
    );
  }
}
