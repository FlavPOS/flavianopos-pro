// lib/screens/cashiering/refund_mode_screen.dart
// v1.0.63+148 - Refund Mode Screen (Phase 1)
import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import '../../helpers/database_helper.dart';

class RefundModeScreen extends StatefulWidget {
  final Transaction originalTransaction;
  final List<TransactionItem> originalItems;
  const RefundModeScreen({
    super.key,
    required this.originalTransaction,
    required this.originalItems,
  });

  @override
  State<RefundModeScreen> createState() => _RefundModeScreenState();
}

class _RefundModeScreenState extends State<RefundModeScreen> {
  final Map<int, bool> _selected = {};
  final Map<int, int> _qtyToRefund = {};
  String _reason = 'Customer Request';
  bool _processing = false;

  final List<String> _reasons = [
    'Defective', 'Wrong Item', 'Customer Request',
    'Expired', 'Damaged', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.originalItems.length; i++) {
      _selected[i] = false;
      _qtyToRefund[i] = widget.originalItems[i].qty;
    }
  }

  double get _refundTotal {
    double t = 0;
    for (int i = 0; i < widget.originalItems.length; i++) {
      if (_selected[i] == true) {
        final it = widget.originalItems[i];
        final q = _qtyToRefund[i] ?? 0;
        t += it.price * q;
      }
    }
    return t;
  }

  int get _selectedCount => _selected.values.where((v) => v).length;

  Future<void> _processRefund() async {
    if (_selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item to refund')),
      );
      return;
    }
    setState(() => _processing = true);

    bool isFull = true;
    for (int i = 0; i < widget.originalItems.length; i++) {
      final origQ = widget.originalItems[i].qty;
      final refQ = _qtyToRefund[i] ?? 0;
      if (_selected[i] != true || refQ < origQ) {
        isFull = false;
        break;
      }
    }

    final txn = widget.originalTransaction;
    txn.status = isFull ? 'refunded' : 'partial_refund';
    txn.refundAmount = _refundTotal;
    txn.refundMethod = txn.paymentMethod;
    txn.refundedBy = 'admin';
    txn.refundedAt = DateTime.now();

    try {
      await DatabaseHelper().updateTransaction(txn.id, txn.toMap());
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refund failed: ' + e.toString())),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _processing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Refund processed: PHP ' + _refundTotal.toStringAsFixed(2))),
    );
    Navigator.pop(context, true);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ORIGINAL TRANSACTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[900])),
              const SizedBox(height: 8),
              Text('Receipt #: ' + txn.id, style: const TextStyle(fontSize: 13)),
              Text('Date: ' + txn.dateTime.toString().substring(0, 16), style: const TextStyle(fontSize: 13)),
              Text('Cashier: ' + txn.cashier, style: const TextStyle(fontSize: 13)),
              Text('Branch: ' + txn.branch, style: const TextStyle(fontSize: 13)),
              Text('Original Total: PHP ' + txn.total.toStringAsFixed(2), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text('Payment Method: ' + txn.paymentMethod, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red[900])),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: widget.originalItems.length,
            itemBuilder: (ctx, i) {
              final it = widget.originalItems[i];
              final sel = _selected[i] ?? false;
              final q = _qtyToRefund[i] ?? it.qty;
              return Card(
                color: sel ? Colors.red[50] : null,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    Row(children: [
                      Checkbox(
                        value: sel,
                        activeColor: Colors.red[700],
                        onChanged: (v) => setState(() => _selected[i] = v ?? false),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('SKU: ' + it.sku + ' - PHP ' + it.price.toStringAsFixed(2) + ' x ' + it.qty.toString(),
                              style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                      if (sel) Text('PHP ' + (it.price * q).toStringAsFixed(2),
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700])),
                    ]),
                    if (sel) Padding(
                      padding: const EdgeInsets.only(left: 40),
                      child: Row(children: [
                        const Text('Refund Qty: ', style: TextStyle(fontSize: 12)),
                        IconButton(
                          iconSize: 20,
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: q > 1 ? () => setState(() => _qtyToRefund[i] = q - 1) : null,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(6)),
                          child: Text(q.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        IconButton(
                          iconSize: 20,
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: q < it.qty ? () => setState(() => _qtyToRefund[i] = q + 1) : null,
                        ),
                        Text('/ ' + it.qty.toString() + ' orig', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ]),
                    ),
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
              value: _reason,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL REFUND:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('PHP ' + _refundTotal.toStringAsFixed(2),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.red[700])),
              ],
            ),
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
                onPressed: (_processing || _selectedCount == 0) ? null : _processRefund,
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
