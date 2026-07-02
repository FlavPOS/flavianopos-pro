// lib/screens/receive_delivery/submitted_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../helpers/database_helper.dart';
import '../../services/device_assignment_service.dart';
import '../../services/firebase_config_service.dart';
import '../../services/firebase_realtime_service.dart';
import 'delivery_model.dart';

class SubmittedDetailScreen extends StatefulWidget {
  final DeliveryRecord record;

  const SubmittedDetailScreen({super.key, required this.record});

  @override
  State<SubmittedDetailScreen> createState() => _SubmittedDetailScreenState();
}

class _SubmittedDetailScreenState extends State<SubmittedDetailScreen> {
  static const _blue      = Color(0xFF2563EB);
  static const _blueLight = Color(0xFFDBEAFE);
  static const _green     = Color(0xFF16A34A);

  bool _processing = false;

  String _fmtInt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _fmtDT(DateTime d) => DateFormat('MM/dd/yyyy HH:mm').format(d);

  String _fmtISO(String iso) {
    try { return _fmtDT(DateTime.parse(iso)); } catch (_) { return iso; }
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
            Icon(Icons.lock_outline, color: _blue, size: 24),
            SizedBox(width: 10),
            Text('Approver PIN Required',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final pin = pinCtrl.text.trim();
                if (pin.isEmpty) return;
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: _blue, foregroundColor: Colors.white),
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Future<void> _confirmApprove() async {
    final d = widget.record;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: const [
          Icon(Icons.check_circle_outline, color: _green, size: 26),
          SizedBox(width: 10),
          Text('Approve Delivery?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DR#: ${d.refNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('Supplier: ${d.supplier}', style: const TextStyle(fontSize: 12)),
            Text('Items: ${d.totalItems} · Qty: ${_fmtInt(d.totalQuantity)}',
                style: const TextStyle(fontSize: 12)),
            Text('Total: ₱${_fmtInt(d.totalRetail.toInt())}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Requires Supervisor / Manager / Admin PIN.',
                style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!await _verifyApproverPin()) return;
    await _doApprove(d);
  }

  Future<void> _doApprove(DeliveryRecord d) async {
    setState(() => _processing = true);
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
      _moveFirebase(d.id, 'branchSubmittedDelivery', 'branchReceivedDelivery', updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Approved: ${d.refNumber}')),
          ]),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _processing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showRejectDialog() async {
    final d = widget.record;
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
            Text('DR#: ${d.refNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            const Text('Reason for rejection: *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final t = reasonCtrl.text.trim();
              if (t.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx, t);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;
    if (!await _verifyApproverPin()) return;
    await _doReject(d, reason);
  }

  Future<void> _doReject(DeliveryRecord d, String reason) async {
    setState(() => _processing = true);
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
      _moveFirebase(d.id, 'branchSubmittedDelivery', 'branchRejectedDelivery', updated);

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
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _processing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _moveFirebase(String deliveryId, String fromNode, String toNode, DeliveryRecord updated) async {
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
    } catch (e) {
      debugPrint('[WORKFLOW] Move error: $e');
    }
  }

  void _showItemBatches(DeliveryItemRecord item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)),
            child: Text(item.sku,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[800])),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(item.itemName, style: const TextStyle(fontSize: 14))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('SKU', item.sku),
            _row('Quantity', '${item.quantity} pcs'),
            _row('Old Stock', '${item.oldStock}'),
            _row('New Stock', '${item.newStock}'),
            _row('Cost', '₱${item.cost.toStringAsFixed(2)}'),
            _row('Retail', '₱${item.retail.toStringAsFixed(2)}'),
            if (item.batchNumber.isNotEmpty) ...[
              const Divider(),
              const Text('Batch Info:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              _row('Batch #', item.batchNumber),
              _row('MFG Date', item.mfgDate.isEmpty ? '-' : _fmtISO(item.mfgDate)),
              _row('EXP Date', item.expDate.isEmpty ? '-' : _fmtISO(item.expDate)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text('$label:', style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
        Expanded(
            child: Text(value.isEmpty ? '-' : value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _infoField(String label, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(value.isEmpty ? '-' : value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.record;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.visibility_outlined, size: 20),
              SizedBox(width: 8),
              Text('View Submitted',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ]),
            Text('${d.totalItems} Item${d.totalItems == 1 ? "" : "s"}',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _processing ? null : _showRejectDialog,
            icon: const Icon(Icons.cancel_outlined, color: Colors.white, size: 18),
            label: const Text('REJECT',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          TextButton.icon(
            onPressed: _processing ? null : _confirmApprove,
            icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            label: const Text('APPROVE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Container(
            width: double.infinity,
            color: _blue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              Text('DR#: ${d.refNumber}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: const Text('SUBMITTED',
                    style: TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ]),
          ),
        ),
      ),
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // ═══ Delivery Info Card ═══
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [
                    Icon(Icons.description_outlined, size: 18, color: _blue),
                    SizedBox(width: 8),
                    Text('Delivery Information',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _infoField('DR # / Reference', d.refNumber, Icons.receipt_long)),
                    const SizedBox(width: 8),
                    Expanded(child: _infoField('Supplier', d.supplier, Icons.business)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _infoField('Driver', d.driverName, Icons.person)),
                    const SizedBox(width: 8),
                    Expanded(child: _infoField('Plate #', d.plateNumber, Icons.local_shipping)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _infoField('Received By', d.receivedBy, Icons.assignment_ind)),
                    const SizedBox(width: 8),
                    Expanded(child: _infoField('Notes / Remarks', d.notes, Icons.note_alt_outlined)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ═══ Delivery Items ═══
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.inventory_2_outlined, size: 18, color: _blue),
                    const SizedBox(width: 8),
                    const Text('Delivery Items',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(10)),
                      child: Text('${d.items.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  ...d.items.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showItemBatches(item),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)),
                              child: Text(item.sku,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(item.itemName,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(6)),
                              child: Text('${_fmtInt(item.quantity)} pcs',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.visibility_outlined, size: 16, color: _blue),
                          ]),
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ═══ Submission Info ═══
            if (d.submittedBy.isNotEmpty)
              Container(
                decoration: BoxDecoration(color: _blueLight, borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Icon(Icons.send, size: 16, color: _blue),
                      SizedBox(width: 8),
                      Text('Submission Info',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _blue)),
                    ]),
                    const SizedBox(height: 6),
                    _row('Submitted By', d.submittedBy),
                    _row('Submitted Date', d.submittedDate.isEmpty ? '-' : _fmtISO(d.submittedDate)),
                  ],
                ),
              ),
          ],
        ),
        // Loading overlay
        if (_processing)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[300]!))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _footerStat('Items', '${d.totalItems}', Icons.inventory_2_outlined),
          _footerStat('Qty', '${_fmtInt(d.totalQuantity)} pcs', Icons.numbers),
          _footerStat('Retail', '₱${_fmtInt(d.totalRetail.toInt())}', Icons.sell),
        ]),
      ),
    );
  }

  Widget _footerStat(String label, String value, IconData icon) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.orange[700]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ]),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    ]);
  }
}
