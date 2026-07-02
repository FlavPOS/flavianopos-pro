// lib/screens/receive_delivery/submitted_detail_screen.dart
// Professional ERP-style READ-ONLY submitted delivery viewer
// Groups batches under single SKU row with lazy accordion expansion.
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
  static const _border    = Color(0xFFE5E7EB);
  static const _muted     = Color(0xFF6B7280);

  bool _processing = false;
  int? _expandedIndex; // Only 1 accordion at a time

  // ═══════════════ FORMATTERS ═══════════════
  final _int = NumberFormat.decimalPattern();
  final _peso = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
  String _fmtDT(DateTime d) => DateFormat('MM/dd/yyyy HH:mm').format(d);
  String _fmtISO(String iso, {bool short = false}) {
    try {
      final d = DateTime.parse(iso);
      return short ? DateFormat('MM/dd/yy').format(d) : _fmtDT(d);
    } catch (_) { return iso; }
  }

  // ═══════════════ GROUP BATCHES BY SKU ═══════════════
  List<_SkuGroup> get _groups {
    final map = <String, _SkuGroup>{};
    for (final item in widget.record.items) {
      final key = item.sku.isEmpty ? item.productId : item.sku;
      map.putIfAbsent(key, () => _SkuGroup(
        sku: item.sku,
        productId: item.productId,
        itemName: item.itemName,
        batches: [],
      )).batches.add(item);
    }
    return map.values.toList();
  }

  // ═══════════════ ROLE-BASED PIN ═══════════════
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
                  style: TextStyle(fontSize: 12, color: _muted)),
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
                final users = await DatabaseHelper().getAllUsers();
                final valid = users.any((u) {
                  final role = (u['role'] ?? '').toString().toLowerCase();
                  final userPin = (u['pin'] ?? '').toString();
                  final active = u['isActive'] == 1 || u['isActive'] == true;
                  final auth = role.contains('supervisor') || role.contains('manager') || role.contains('admin');
                  return active && auth && userPin == pin;
                });
                if (valid) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Invalid PIN or insufficient role'),
                    backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
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
          Text('Approve Delivery?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DR#: ${d.refNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('Supplier: ${d.supplier}', style: const TextStyle(fontSize: 12)),
            Text('Items: ${d.totalItems} · Qty: ${_int.format(d.totalQuantity)}', style: const TextStyle(fontSize: 12)),
            Text('Total: ${_peso.format(d.totalRetail)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
        'deliveryId': d.id, 'action': 'Approved',
        'user': approver, 'date': now.toIso8601String(), 'remarks': '',
      });
      final updated = d.copyWith(
        status: DeliveryStatus.approved,
        approvedDate: now.toIso8601String(), approvedBy: approver,
      );
      _moveFirebase(d.id, 'branchSubmittedDelivery', 'branchReceivedDelivery', updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 8), Expanded(child: Text('Approved: ${d.refNumber}'))]),
        backgroundColor: _green, behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _processing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
            Text('DR#: ${d.refNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            const Text('Reason for rejection: *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: reasonCtrl, maxLines: 3, autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. Damaged items, Wrong quantity...',
                hintStyle: const TextStyle(fontSize: 12, color: _muted),
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
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Please provide a reason'), backgroundColor: Colors.red));
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
        'deliveryId': d.id, 'action': 'Rejected',
        'user': rejecter, 'date': now.toIso8601String(), 'remarks': reason,
      });
      final updated = d.copyWith(
        status: DeliveryStatus.rejected,
        rejectedDate: now.toIso8601String(), rejectedBy: rejecter, rejectionReason: reason,
      );
      _moveFirebase(d.id, 'branchSubmittedDelivery', 'branchRejectedDelivery', updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [const Icon(Icons.cancel, color: Colors.white),
          const SizedBox(width: 8), Expanded(child: Text('Rejected: ${d.refNumber}'))]),
        backgroundColor: Colors.red[600], behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _processing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _moveFirebase(String id, String from, String to, DeliveryRecord upd) async {
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
      await db.ref('companies/$companyCode/$from/$branchId/$id').remove();
      await db.ref('companies/$companyCode/$to/$branchId/$id').set(upd.toJson());
    } catch (e) {
      debugPrint('[WORKFLOW] Move error: $e');
    }
  }

  // ═══════════════ VIEW DETAILS DIALOG ═══════════════
  void _showProductInfo(_SkuGroup group) {
    final totalQty = group.batches.fold<int>(0, (s, b) => s + b.quantity);
    final first = group.batches.first;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 700,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                decoration: const BoxDecoration(
                  color: _blueLight,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(children: [
                  const Icon(Icons.inventory_2_outlined, color: _blue, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Product Information',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 20)),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('SKU', group.sku),
                      _kv('Description', group.itemName),
                      _kv('Cost', _peso.format(first.cost)),
                      _kv('Retail', _peso.format(first.retail)),
                      _kv('Old Stock', _int.format(first.oldStock)),
                      _kv('New Stock', _int.format(first.newStock)),
                      _kv('Total Qty', '${_int.format(totalQty)} pcs'),
                      _kv('Number of Batches', '${group.batches.length}'),
                      const Divider(),
                      const Text('Batch Details:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: _BatchTable(batches: group.batches, screenWidth: 999999),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: _border))),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text('$k:', style: const TextStyle(fontSize: 12, color: _muted))),
        Expanded(child: Text(v.isEmpty ? '-' : v,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  // ═══════════════ INFO FIELD (Read-only) ═══════════════
  Widget _infoField(String label, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: _muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
              const SizedBox(height: 2),
              Text(value.isEmpty ? '-' : value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }

  // ═══════════════ BUILD ═══════════════
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
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
            ]),
            Text('${_groups.length} Items',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _processing ? null : _showRejectDialog,
            tooltip: 'Reject',
            icon: const Icon(Icons.cancel_outlined, color: Colors.white, size: 24),
          ),
          IconButton(
            onPressed: _processing ? null : _confirmApprove,
            tooltip: 'Approve',
            icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Container(
            width: double.infinity, color: _blue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              Flexible(
                child: Text('DR#: ${d.refNumber}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
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
        LayoutBuilder(builder: (context, cons) {
          final width = cons.maxWidth;
          final infoCols = width >= 800 ? 3 : 2;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _deliveryInfoCard(d, infoCols, width),
              const SizedBox(height: 12),
              _deliveryItemsCard(width),
              if (d.submittedBy.isNotEmpty) ...[
                const SizedBox(height: 12),
                _submissionInfoCard(d),
              ],
              const SizedBox(height: 8),
            ],
          );
        }),
        if (_processing)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ]),
      bottomNavigationBar: _footer(d),
    );
  }

  Widget _deliveryInfoCard(DeliveryRecord d, int cols, double width) {
    final fields = [
      ('DR # / Reference', d.refNumber, Icons.receipt_long),
      ('Supplier',         d.supplier,   Icons.business),
      ('Driver',           d.driverName, Icons.person),
      ('Plate #',          d.plateNumber, Icons.local_shipping),
      ('Received By',      d.receivedBy, Icons.assignment_ind),
      ('Notes / Remarks',  d.notes,      Icons.note_alt_outlined),
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.description_outlined, size: 18, color: _blue),
          SizedBox(width: 8),
          Text('Delivery Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (ctx, c) {
          final colW = (c.maxWidth - (cols - 1) * 8) / cols;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in fields) SizedBox(width: colW, child: _infoField(f.$1, f.$2, f.$3)),
          ]);
        }),
      ]),
    );
  }

  Widget _deliveryItemsCard(double width) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.inventory_2_outlined, size: 18, color: _blue),
          const SizedBox(width: 8),
          const Text('Delivery Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(10)),
            child: Text('${_groups.length}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 10),
        for (int i = 0; i < _groups.length; i++)
          _SkuAccordionRow(
            group: _groups[i],
            index: i,
            isExpanded: _expandedIndex == i,
            screenWidth: width,
            onToggle: () => setState(() => _expandedIndex = _expandedIndex == i ? null : i),
            onViewDetails: () => _showProductInfo(_groups[i]),
            intFmt: _int,
            pesoFmt: _peso,
            fmtISO: _fmtISO,
          ),
      ]),
    );
  }

  Widget _submissionInfoCard(DeliveryRecord d) {
    return Container(
      decoration: BoxDecoration(color: _blueLight, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.send, size: 16, color: _blue),
          SizedBox(width: 8),
          Text('Submission Info',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _blue)),
        ]),
        const SizedBox(height: 6),
        _kv('Submitted By', d.submittedBy),
        _kv('Submitted Date', d.submittedDate.isEmpty ? '-' : _fmtISO(d.submittedDate)),
      ]),
    );
  }

  Widget _footer(DeliveryRecord d) {
    return Container(
      decoration: BoxDecoration(color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))]),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(top: false,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _fStat('Items', '${_groups.length}', Icons.inventory_2_outlined),
          _fStat('Qty', '${_int.format(d.totalQuantity)} pcs', Icons.numbers),
          _fStat('Retail', _peso.format(d.totalRetail), Icons.sell),
        ]),
      ),
    );
  }

  Widget _fStat(String label, String value, IconData icon) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.orange[700]),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
      ]),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    ]);
  }
}

// ═══════════════ GROUPED SKU MODEL ═══════════════
class _SkuGroup {
  final String sku;
  final String productId;
  final String itemName;
  final List<DeliveryItemRecord> batches;
  _SkuGroup({required this.sku, required this.productId, required this.itemName, required this.batches});
}

// ═══════════════ ACCORDION ROW ═══════════════
class _SkuAccordionRow extends StatelessWidget {
  static const _blue      = Color(0xFF2563EB);
  static const _blueLight = Color(0xFFDBEAFE);
  static const _border    = Color(0xFFE5E7EB);
  static const _green     = Color(0xFF16A34A);

  final _SkuGroup group;
  final int index;
  final bool isExpanded;
  final double screenWidth;
  final VoidCallback onToggle;
  final VoidCallback onViewDetails;
  final NumberFormat intFmt;
  final NumberFormat pesoFmt;
  final String Function(String, {bool short}) fmtISO;

  const _SkuAccordionRow({
    required this.group,
    required this.index,
    required this.isExpanded,
    required this.screenWidth,
    required this.onToggle,
    required this.onViewDetails,
    required this.intFmt,
    required this.pesoFmt,
    required this.fmtISO,
  });

  @override
  Widget build(BuildContext context) {
    final totalQty = group.batches.fold<int>(0, (s, b) => s + b.quantity);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isExpanded ? _blueLight.withValues(alpha: 0.3) : Colors.white,
        border: Border.all(color: isExpanded ? _blue.withValues(alpha: 0.4) : _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        // ─── Header Row ───
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)),
                  child: Text(group.sku,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(group.itemName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(6)),
                  child: Text('${intFmt.format(totalQty)} pcs',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onViewDetails,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'View Details',
                  icon: const Icon(Icons.visibility_outlined, size: 18, color: _blue),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(Icons.expand_more, size: 22, color: _blue),
                ),
              ]),
            ),
          ),
        ),
        // ─── Expanded Batch Content (Lazy) ───
        if (isExpanded)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              padding: const EdgeInsets.all(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: screenWidth < 600 ? 250 : (screenWidth < 1200 ? 350 : 450),
                ),
                child: _BatchTable(batches: group.batches, screenWidth: screenWidth),
              ),
            ),
          ),
      ]),
    );
  }
}

// ═══════════════ BATCH TABLE (Responsive) ═══════════════
class _BatchTable extends StatelessWidget {
  static const _border   = Color(0xFFE5E7EB);
  static const _headerBg = Color(0xFFF9FAFB);
  static const _rowOdd   = Color(0xFFF8F9FC);
  static const _muted    = Color(0xFF6B7280);

  final List<DeliveryItemRecord> batches;
  final double screenWidth;

  const _BatchTable({required this.batches, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    final intFmt = NumberFormat.decimalPattern();
    final pesoFmt = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);
    String fmtDate(String iso) {
      try { return DateFormat('MM/dd/yy').format(DateTime.parse(iso)); } catch (_) { return iso; }
    }

    // ── Phone: Stacked cards ──
    if (screenWidth < 600) {
      return ListView.builder(
        itemCount: batches.length,
        itemBuilder: (_, i) {
          final b = batches[i];
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: i.isEven ? Colors.white : _rowOdd,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.qr_code, size: 12, color: _muted),
                const SizedBox(width: 4),
                Text('Batch #${b.batchNumber.isEmpty ? "-" : b.batchNumber}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: _mini('Qty', '${intFmt.format(b.quantity)} pcs')),
                Expanded(child: _mini('MFG', fmtDate(b.mfgDate))),
                Expanded(child: _mini('EXP', fmtDate(b.expDate))),
              ]),
            ]),
          );
        },
      );
    }

    // ── Tablet/Desktop: Compact ERP table ──
    final showCost   = screenWidth >= 800;
    final showRetail = screenWidth >= 1200;

    return SingleChildScrollView(
      child: Table(
        columnWidths: {
          0: const FlexColumnWidth(1.4),
          1: const FlexColumnWidth(1.4),
          2: const FlexColumnWidth(1.1),
          3: const FlexColumnWidth(1.1),
          if (showCost) 4: const FlexColumnWidth(1.0),
          if (showRetail) 5: const FlexColumnWidth(1.0),
        },
        border: TableBorder(
          horizontalInside: BorderSide(color: _border, width: 0.5),
        ),
        children: [
          // ─── Sticky Header ───
          TableRow(
            decoration: const BoxDecoration(color: _headerBg,
              border: Border(bottom: BorderSide(color: _border))),
            children: [
              _hCell('BATCH #'),
              _hCell('QTY', align: TextAlign.right),
              _hCell('MFG', align: TextAlign.center),
              _hCell('EXP', align: TextAlign.center),
              if (showCost) _hCell('COST', align: TextAlign.right),
              if (showRetail) _hCell('RETAIL', align: TextAlign.right),
            ],
          ),
          // ─── Data Rows ───
          for (int i = 0; i < batches.length; i++)
            TableRow(
              decoration: BoxDecoration(color: i.isEven ? Colors.white : _rowOdd),
              children: [
                _dCell(batches[i].batchNumber.isEmpty ? '-' : batches[i].batchNumber),
                _dCell('${intFmt.format(batches[i].quantity)} pcs', align: TextAlign.right, bold: true),
                _dCell(fmtDate(batches[i].mfgDate), align: TextAlign.center),
                _dCell(fmtDate(batches[i].expDate), align: TextAlign.center),
                if (showCost) _dCell(pesoFmt.format(batches[i].cost), align: TextAlign.right),
                if (showRetail) _dCell(pesoFmt.format(batches[i].retail), align: TextAlign.right),
              ],
            ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9, color: _muted, fontWeight: FontWeight.w500)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _hCell(String label, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(label, textAlign: align,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: Color(0xFF374151), letterSpacing: 0.5)),
    );
  }

  Widget _dCell(String value, {TextAlign align = TextAlign.left, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(value, textAlign: align,
          overflow: TextOverflow.ellipsis, maxLines: 1,
          style: TextStyle(fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF111827))),
    );
  }
}
