// lib/screens/cashiering/refund_mode_screen.dart
// v1.0.71+157 - Full-Only Refund (v152)
import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import '../../helpers/database_helper.dart';
import '../../helpers/sync_bridge.dart';
import '../../services/branch_inventory_service.dart';
import '../../services/cashier_session_service.dart';
import 'refund_receipt_screen.dart';

class RefundModeScreen extends StatefulWidget {
  final Transaction originalTransaction;
  final List<TransactionItem> originalItems;
  final String? preApprovedBy;
  const RefundModeScreen({
    super.key,
    required this.originalTransaction,
    required this.originalItems,
    this.preApprovedBy,
  });
  @override
  State<RefundModeScreen> createState() => _RefundModeScreenState();
}

class _RefundModeScreenState extends State<RefundModeScreen> {
  String _reason = 'Customer Request';
  bool _processing = false;
  final List<String> _reasons = ['Defective','Wrong Item','Customer Request','Expired','Damaged','Other'];

  double get _refundTotal => widget.originalTransaction.total;

  Future<void> _processRefund() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_amber, color: Colors.red[700]),
          const SizedBox(width: 8),
          const Text('Confirm Full Refund'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Refund Amount: PHP ' + _refundTotal.toStringAsFixed(2),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Method: ' + widget.originalTransaction.paymentMethod),
          Text('Reason: ' + _reason),
          Text('Items to restore: ' + widget.originalItems.length.toString()),
          const SizedBox(height: 12),
          const Text('This will refund the ENTIRE transaction.',
            style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
            child: const Text('CONFIRM REFUND'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processing = true);
    final String approver = widget.preApprovedBy ?? 'admin';
    final txn = widget.originalTransaction;
    txn.status = 'refunded';
    txn.refundAmount = _refundTotal;
    txn.refundMethod = txn.paymentMethod;
    txn.refundedBy = approver;
    txn.refundedAt = DateTime.now();

    try {
      int itemsRestored = 0;
      for (final it in widget.originalItems) {
        if (it.sku.isNotEmpty && it.qty > 0) {
          final ok = await BranchInventoryService.incrementStock(txn.branch, it.sku, it.qty);
          if (ok) itemsRestored++;
        }
      }
      await DatabaseHelper().updateTransaction(txn.id, txn.toMap());

      try {
        final activeSessions = await CashierSessionService.getAllActiveShifts();
        if (activeSessions.isNotEmpty) {
          final s = activeSessions.first;
          final Map<String, dynamic> updates = {'totalRefunds': s.totalRefunds + _refundTotal};
          if (txn.paymentMethod.toLowerCase() == 'cash') {
            updates['cashSales'] = (s.cashSales - _refundTotal).clamp(0, double.infinity);
          }
          await CashierSessionService.updateSessionTotals(s.id, updates);
        }
      } catch (e) { debugPrint('[v152] drawer: ' + e.toString()); }

      try { await SyncBridge.enqueueTransaction(txn, op: 'refund'); }
      catch (e) { debugPrint('[v152] sync: ' + e.toString()); }

      if (!mounted) return;
      setState(() => _processing = false);
      final now = DateTime.now();
      final refundNumber = 'RFN-' + now.year.toString() +
        now.month.toString().padLeft(2, '0') +
        now.day.toString().padLeft(2, '0') + '-' +
        (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      final Map<int, int> refundQtyMap = {};
      for (int i = 0; i < widget.originalItems.length; i++) {
        refundQtyMap[i] = widget.originalItems[i].qty;
      }
      await Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => RefundReceiptScreen(
          originalTransaction: txn,
          refundedItems: widget.originalItems,
          refundQuantities: refundQtyMap,
          refundTotal: _refundTotal,
          refundReason: _reason,
          approvedBy: approver,
          refundNumber: refundNumber,
          refundDateTime: now,
        )),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refund failed: ' + e.toString()), backgroundColor: Colors.red[700]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final txn = widget.originalTransaction;
    return Scaffold(
      appBar: AppBar(
        title: const Text('REFUND MODE', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.red[50],
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ORIGINAL TRANSACTION',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[900])),
            const SizedBox(height: 8),
            Text('Receipt #: ' + txn.id, style: const TextStyle(fontSize: 13)),
            Text('Date: ' + txn.dateTime.toString().substring(0, 16), style: const TextStyle(fontSize: 13)),
            Text('Cashier: ' + txn.cashier, style: const TextStyle(fontSize: 13)),
            Text('Branch: ' + txn.branch, style: const TextStyle(fontSize: 13)),
            Text('Original Total: PHP ' + txn.total.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            Text('Payment Method: ' + txn.paymentMethod,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red[900])),
          ]),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          child: Row(children: [
            Icon(Icons.inventory_2, size: 16, color: Colors.red[700]),
            const SizedBox(width: 6),
            Text('ITEMS TO REFUND (' + widget.originalItems.length.toString() + ')',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[900])),
            const Spacer(),
            Text('All items will be refunded',
              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey[600])),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: widget.originalItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (ctx, i) {
              final it = widget.originalItems[i];
              final lineTotal = it.price * it.qty;
              return Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    Icon(Icons.check_circle, color: Colors.red[700], size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('SKU: ' + it.sku + ' - ' + it.qty.toString() + ' x PHP ' + it.price.toStringAsFixed(2),
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ]),
                    ),
                    Text('PHP ' + lineTotal.toStringAsFixed(2),
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700])),
                  ]),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey[100],
          child: Column(children: [
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(
                labelText: 'Refund Reason',
                prefixIcon: Icon(Icons.help_outline),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => _reason = v ?? 'Customer Request'),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('TOTAL REFUND:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('PHP ' + _refundTotal.toStringAsFixed(2),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.red[700])),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                Icon(Icons.lock, size: 14, color: Colors.orange[800]),
                const SizedBox(width: 6),
                Expanded(child: Text('Refund method locked to original: ' + txn.paymentMethod,
                  style: TextStyle(fontSize: 11, color: Colors.orange[900]))),
              ]),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _processing ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('CANCEL'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _processing ? null : _processRefund,
                icon: _processing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle),
                label: Text(_processing ? 'PROCESSING...' : 'PROCESS REFUND'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
