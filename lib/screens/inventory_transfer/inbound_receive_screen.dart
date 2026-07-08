import 'package:flutter/material.dart';
import '../../services/branch_inventory_service.dart';
import '../../services/device_assignment_service.dart';
import '../../services/firebase_realtime_service.dart';
import '../../services/firebase_config_service.dart';
import '../../helpers/database_helper.dart';
import '../inventory_adjustment/approver_pin_dialog_v3.dart';
import 'transfer_v3_model.dart';

class InboundReceiveScreen extends StatefulWidget {
  final String transferId;
  final String branch;
  final String userName;

  const InboundReceiveScreen({
    super.key,
    required this.transferId,
    required this.branch,
    required this.userName,
  });

  @override
  State<InboundReceiveScreen> createState() => _InboundReceiveScreenState();
}

class _InboundReceiveScreenState extends State<InboundReceiveScreen> {
  static const _amber = Color(0xFFF59E0B);
  static const _green = Color(0xFF22C55E);
  static const _yellow = Color(0xFFEAB308);
  static const _red = Color(0xFFEF4444);
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);
  static const _divider = Color(0xFFE5E7EB);

  TransferV3? _doc;
  final List<_ReceiveItem> _items = [];
  bool _loading = true;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.receivedCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await TransferV3Dao.getById(widget.transferId);
    final it = await TransferV3Dao.getItems(widget.transferId);
    if (!mounted) return;

    _items.clear();
    for (final item in it) {
      _items.add(_ReceiveItem(
        item: item,
        receivedCtrl: TextEditingController(text: item.issuedQty.toString()),
        receivedQty: item.issuedQty,
      ));
    }

    setState(() {
      _doc = d;
      _loading = false;
    });
  }

  int get _totalIssued => _items.fold(0, (s, i) => s + i.item.issuedQty);
  int get _totalReceived => _items.fold(0, (s, i) => s + i.receivedQty);
  int get _totalShort => _totalIssued - _totalReceived;
  bool get _hasVariance => _totalShort > 0;
  bool get _allRejected => _totalReceived == 0;

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? _green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmReceipt() async {
    if (_actionInProgress) return;
    for (final item in _items) {
      if (item.receivedQty < 0 || item.receivedQty > item.item.issuedQty) {
        _showSnack('Invalid received qty for ${item.item.productName}', color: _red);
        return;
      }
    }
    if (_allRejected) {
      _showSnack('If receiving nothing, use Reject instead', color: _red);
      return;
    }

    final result = await ApproverPinDialog.show(
      context: context,
      title: _hasVariance ? 'Partial Receipt' : 'Confirm Receipt',
      headerColor: _hasVariance ? _yellow : _green,
      subtitle: _hasVariance
          ? 'Stock will be added with variance recorded'
          : 'Stock will be added to your branch',
      allowedRoles: const ['Supervisor', 'Manager', 'Admin'],
    );
    if (result == null || !mounted) return;

    _actionInProgress = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _hasVariance ? _yellow : _green),
                const SizedBox(height: 12),
                const Text('Receiving into inventory...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final now = DateTime.now().toIso8601String();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final assign = await DeviceAssignmentService().read();
      final companyCode = (assign['companyCode'] ?? '').toString();
      final realBranchId = (assign['branchId'] ?? '').toString();

      final newStatus = _hasVariance
          ? TransferStatus.partiallyReceived
          : TransferStatus.received;

      await TransferV3Dao.updateStatus(
        transferId: widget.transferId,
        newStatus: newStatus,
        extraFields: {
          'received_by': result.userName,
          'received_by_pin': result.userPin,
          'received_date': now,
          'total_received_qty': _totalReceived,
          'total_short_qty': _totalShort,
        },
      );

      for (final ri in _items) {
        if (ri.item.itemId != null) {
          await TransferV3Dao.updateItemReceived(
            transferId: widget.transferId,
            itemId: ri.item.itemId!,
            receivedQty: ri.receivedQty,
            shortQty: ri.item.issuedQty - ri.receivedQty,
            varianceReason: '',
          );
        }
      }

      int successCount = 0;
      for (final ri in _items) {
        if (ri.receivedQty > 0) {
          final ok = await BranchInventoryService.incrementStock(
            realBranchId,
            ri.item.productId,
            ri.receivedQty,
          );
          if (ok) successCount++;
        }
      }

      final db = await DatabaseHelper().database;
      for (final ri in _items) {
        if (ri.receivedQty <= 0) continue;
        final currentSOH = await BranchInventoryService.getStock(
            realBranchId, ri.item.productId);
        final movementId =
            'MOV-TRI-${widget.transferId}-${ri.item.itemId ?? _items.indexOf(ri)}';

        try {
          await db.insert('stock_movements', {
            'movement_id': movementId,
            'movement_type': 'TRANSFER_IN',
            'sku': ri.item.sku,
            'product_id': ri.item.productId,
            'product_name': ri.item.productName,
            'barcode': '',
            'qty_before': (currentSOH - ri.receivedQty).toDouble(),
            'qty_change': ri.receivedQty.toDouble(),
            'qty_after': currentSOH.toDouble(),
            'unit_cost': ri.item.unitCost,
            'reason_code': 'TRANSFER',
            'reason_note': 'From ${_doc!.issuingBranchId} (${_doc!.issuingBranchName})',
            'reference_no': widget.transferId,
            'batch_no': '',
            'branch_code': realBranchId,
            'branch_name': _doc!.receivingBranchName,
            'user_pin': '',
            'user_name': widget.userName,
            'approved_by_pin': result.userPin,
            'approved_by_name': result.userName,
            'local_timestamp': nowMs,
            'sync_status': 'SYNCED',
            'z_report_id': '',
            'created_at': now,
            'updated_at': now,
          });

          try {
            if (FirebaseRealtimeService.instance.isInitialized) {
              final fb = FirebaseRealtimeService.instance.db;
              if (fb != null && companyCode.isNotEmpty) {
                await fb.ref(
                  'companies/$companyCode/stockMovements/$realBranchId/$movementId'
                ).set({
                  'movement_id': movementId,
                  'movement_type': 'TRANSFER_IN',
                  'sku': ri.item.sku,
                  'product_id': ri.item.productId,
                  'product_name': ri.item.productName,
                  'qty_before': (currentSOH - ri.receivedQty).toDouble(),
                  'qty_change': ri.receivedQty.toDouble(),
                  'qty_after': currentSOH.toDouble(),
                  'reference_no': widget.transferId,
                  'branch_code': realBranchId,
                  'approved_by_name': result.userName,
                  'created_at': now,
                });
              }
            }
          } catch (_) {}
        } catch (e) {
          debugPrint('[INBOUND-RECEIVE] Ledger insert failed: $e');
        }
      }

      try {
        if (!FirebaseRealtimeService.instance.isInitialized) {
          final cfg = await FirebaseConfigService().load();
          if (cfg != null) {
            await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
          }
        }
        final fb = FirebaseRealtimeService.instance.db;
        if (fb != null && companyCode.isNotEmpty) {
          await fb.ref('companies/$companyCode/interStoreTransfers/${widget.transferId}').update({
            'status': newStatus,
            'receivedBy': result.userName,
            'receivedByPin': result.userPin,
            'receivedDate': now,
            'totalReceivedQty': _totalReceived,
            'totalShortQty': _totalShort,
            'updatedAt': now,
          });
          await fb.ref('companies/$companyCode/inboundTransfers/$realBranchId/${widget.transferId}').update({
            'status': newStatus,
            'receivedDate': now,
          });
          debugPrint('[INBOUND-RECEIVE] Firebase status updated');
        }
      } catch (e) {
        debugPrint('[INBOUND-RECEIVE] Firebase sync failed: $e');
      }

      if (!mounted) return;
      Navigator.pop(context);
      await _load();
      if (!mounted) return;

      _showSnack(
        _hasVariance
            ? 'Partially received — $successCount items ($_totalShort short)'
            : 'Received — $successCount item(s) added to inventory',
        color: _hasVariance ? _yellow : _green,
      );

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      _showSnack('Receive failed: $e', color: _red);
    } finally {
      _actionInProgress = false;
    }
  }

  Future<void> _reject() async {
    if (_actionInProgress) return;
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: _red),
            SizedBox(width: 8),
            Text('Reject Transfer'),
          ],
        ),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'Why are you rejecting?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final pin = await ApproverPinDialog.show(
      context: context,
      title: 'Reject Transfer',
      headerColor: _red,
      subtitle: 'PIN required to confirm rejection',
      allowedRoles: const ['Supervisor', 'Manager', 'Admin'],
    );
    if (pin == null || !mounted) return;

    _actionInProgress = true;
    try {
      await TransferV3Dao.updateStatus(
        transferId: widget.transferId,
        newStatus: TransferStatus.rejected,
        extraFields: {
          'rejected_by': pin.userName,
          'rejected_date': DateTime.now().toIso8601String(),
          'rejection_reason': reasonCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      _showSnack('Transfer rejected — sender will be notified', color: _red);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Reject failed: $e', color: _red);
    } finally {
      _actionInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Receive Transfer',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            if (_doc != null)
              Text(
                _doc!.docNumber.isEmpty ? _doc!.transferId : _doc!.docNumber,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildBanner(),
                Expanded(child: _buildList()),
              ],
            ),
      bottomNavigationBar: _items.isEmpty || _loading ? null : _buildBottomBar(),
    );
  }

  Widget _buildBanner() {
    return Container(
      color: _amber.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: _amber, size: 20),
              const SizedBox(width: 8),
              const Text('READY TO RECEIVE',
                  style: TextStyle(color: _amber, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          if (_doc != null) ...[
            const SizedBox(height: 6),
            Text('From: ${_doc!.issuingBranchId} (${_doc!.issuingBranchName})',
                style: const TextStyle(color: _textSecondary, fontSize: 11)),
            Text('Approved by: ${_doc!.approvedBy}',
                style: const TextStyle(color: _textSecondary, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_items.isEmpty) return const Center(child: Text('No items'));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _items.length,
      itemBuilder: (context, index) => _buildItemCard(_items[index]),
    );
  }

  Widget _buildItemCard(_ReceiveItem ri) {
    final isPartial = ri.receivedQty < ri.item.issuedQty;
    final isRejected = ri.receivedQty == 0;
    final borderColor = isRejected
        ? _red
        : (isPartial ? _yellow : _green);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ri.item.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('SKU: ${ri.item.sku}',
                        style: const TextStyle(color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('ISSUED', style: TextStyle(fontSize: 10, color: _textSecondary)),
                  Text('${ri.item.issuedQty} pcs',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Received:', style: TextStyle(fontSize: 12, color: _textSecondary)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: ri.receivedCtrl,
                  onChanged: (v) {
                    setState(() {
                      ri.receivedQty = int.tryParse(v) ?? 0;
                      if (ri.receivedQty < 0) ri.receivedQty = 0;
                      if (ri.receivedQty > ri.item.issuedQty) {
                        ri.receivedQty = ri.item.issuedQty;
                        ri.receivedCtrl.text = ri.item.issuedQty.toString();
                      }
                    });
                  },
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: borderColor),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('/ ${ri.item.issuedQty} pcs',
                  style: const TextStyle(fontSize: 12, color: _textSecondary)),
              const Spacer(),
              if (isPartial && !isRejected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _yellow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Short ${ri.item.issuedQty - ri.receivedQty}',
                      style: const TextStyle(color: _yellow, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              if (isRejected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Not receiving',
                      style: TextStyle(color: _red, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummary(),
          Container(
            padding: EdgeInsets.only(
              left: 12, right: 12, top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: const BoxDecoration(color: _card),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _actionInProgress ? null : _reject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _red,
                      side: const BorderSide(color: _red, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _actionInProgress ? null : _confirmReceipt,
                    icon: Icon(_hasVariance ? Icons.warning_rounded : Icons.check_rounded, size: 18),
                    label: Text(_hasVariance ? 'Confirm Partial' : 'Confirm Full'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasVariance ? _yellow : _green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryStat(Icons.local_shipping_rounded, 'Issued', '$_totalIssued', _textPrimary),
          Container(width: 1, height: 26, color: _divider),
          _summaryStat(Icons.check_circle_rounded, 'Received', '$_totalReceived', _green),
          Container(width: 1, height: 26, color: _divider),
          _summaryStat(
            Icons.warning_rounded,
            'Short',
            '$_totalShort',
            _totalShort > 0 ? _yellow : _textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(IconData icon, String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _ReceiveItem {
  final TransferV3Item item;
  final TextEditingController receivedCtrl;
  int receivedQty;

  _ReceiveItem({
    required this.item,
    required this.receivedCtrl,
    required this.receivedQty,
  });
}
