// lib/screens/reports/transaction_detail_screen.dart
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/transaction_model.dart';
import '../../models/settings_model.dart';
import '../../models/product_model.dart';
import '../../utils/export_helper.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Transaction transaction;
  final VoidCallback onUpdate;
  const TransactionDetailScreen({super.key, required this.transaction, required this.onUpdate});
  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  Transaction get t => widget.transaction;

  String _formatDate(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.month}/${dt.day}/${dt.year} $h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  Color _statusColor() {
    switch (t.status) { case 'voided': return Colors.red; case 'refunded': return Colors.orange;
      default: return Colors.green; }
  }

  void _restoreStock() {
    for (final item in t.items) {
      final pIdx = Product.allProducts.indexWhere((p) => p.sku == item.sku);
      if (pIdx >= 0) {
        final p = Product.allProducts[pIdx];
        Product.updateProduct(p.id, Product(
          id: p.id, name: p.name, sku: p.sku, category: p.category,
          sellingPrice: p.sellingPrice, costPrice: p.costPrice,
          stockQty: p.stockQty + item.qty,
          reorderLevel: p.reorderLevel, barcode: p.barcode,
        ));
      }
    }
  }

  void _voidTxn() {

    final reasonCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Void Transaction', style: TextStyle(color: Colors.red)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: reasonCtrl, decoration: InputDecoration(labelText: 'Reason *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 12),
        TextField(controller: pinCtrl, decoration: InputDecoration(labelText: 'Manager PIN *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            obscureText: true, maxLength: 6),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          if (reasonCtrl.text.trim().isEmpty) { _snack('Enter reason'); return; }
          final mgrV = AppUser.allUsers.where((u) => (u.role == 'Admin' || u.role == 'Manager') && u.pin == pinCtrl.text.trim()).firstOrNull;
          if (AppSettings.requirePinVoid && mgrV == null) { _snack('Invalid Manager PIN'); return; }
          setState(() { t.status = 'voided'; t.voidReason = reasonCtrl.text.trim();
            t.voidedBy = mgrV?.name ?? 'admin'; t.voidedAt = DateTime.now(); }); _restoreStock();
          widget.onUpdate(); Navigator.pop(ctx); _snack('Transaction voided');
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Void')),
      ]));
  }

  void _refundTxn() {
    String method = t.paymentMethod;
    final pinCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('Refund', style: TextStyle(color: Colors.orange)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Amount:'), Text(t.total.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
            ])),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: method,
            decoration: InputDecoration(labelText: 'Refund Via',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: ['Cash', 'GCash', 'Maya'].map((m) =>
                DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => setD(() => method = v!)),
          if (AppSettings.requirePinVoid) ...[
            const SizedBox(height: 12),
            TextField(controller: pinCtrl, obscureText: true, maxLength: 6,
              decoration: InputDecoration(labelText: 'Manager PIN *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            final mgrR = AppUser.allUsers.where((u) => (u.role == 'Admin' || u.role == 'Manager') && u.pin == pinCtrl.text.trim()).firstOrNull;
            if (AppSettings.requirePinVoid && mgrR == null) { _snack('Invalid Manager PIN'); return; }
            setState(() { t.status = 'refunded'; t.refundAmount = t.total;
              t.refundMethod = method; t.refundedBy = mgrR?.name ?? 'admin'; t.refundedAt = DateTime.now(); }); _restoreStock();
            widget.onUpdate(); Navigator.pop(ctx); _snack('Refunded ${t.total.toStringAsFixed(2)}');
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: const Text('Refund')),
        ])));
  }

  // ═══════════════════════════════════════════════════════════════
  // ★ FIX: Real PDF export using ExportHelper
  // ═══════════════════════════════════════════════════════════════
  void _exportPdf() {
    // ── Build subtitle with transaction summary ──
    final lines = <String>[
      'Date: ${_formatDate(t.dateTime)}',
      'Status: ${t.status.toUpperCase()}',
      'Branch: ${t.branch}  |  Cashier: ${t.cashier}',
      'Payment: ${t.paymentMethod}  |  Paid: ${t.amountPaid.toStringAsFixed(2)}  |  Change: ${t.change.toStringAsFixed(2)}',
    ];

    if (t.status == 'voided') {
      lines.add('VOIDED - Reason: ${t.voidReason}  |  By: ${t.voidedBy}');
      if (t.voidedAt != null) lines.add('Voided At: ${_formatDate(t.voidedAt!)}');
    }
    if (t.status == 'refunded') {
      lines.add('REFUNDED - ${t.refundAmount.toStringAsFixed(2)} via ${t.refundMethod}  |  By: ${t.refundedBy}');
      if (t.refundedAt != null) lines.add('Refunded At: ${_formatDate(t.refundedAt!)}');
    }

    // ── Build item rows ──
    final headers = ['#', 'Item Name', 'SKU', 'Qty', 'Price', 'Subtotal'];
    final rows = <List<String>>[];
    for (int i = 0; i < t.items.length; i++) {
      final item = t.items[i];
      rows.add([
        '${i + 1}',
        item.name,
        item.sku,
        '${item.qty}',
        item.price.toStringAsFixed(2),
        item.subtotal.toStringAsFixed(2),
      ]);
    }

    // ── Add summary rows at the bottom ──
    rows.add(['', '', '', '', '', '']);  // blank spacer row
    rows.add(['', '', '', '', 'Subtotal:', t.subtotal.toStringAsFixed(2)]);
    if (t.totalDiscount > 0) {
      rows.add(['', '', '', '', 'Discount:', '-${t.totalDiscount.toStringAsFixed(2)}']);
    }
    rows.add(['', '', '', '', 'VAT (12%):', t.tax.toStringAsFixed(2)]);
    rows.add(['', '', '', '', 'TOTAL:', t.total.toStringAsFixed(2)]);
    rows.add(['', '', '', '', 'Paid:', t.amountPaid.toStringAsFixed(2)]);
    rows.add(['', '', '', '', 'Change:', t.change.toStringAsFixed(2)]);

    // ── Export ──
    final safeId = t.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    ExportHelper.exportPdf(
      title: 'Transaction Receipt - ${t.id}',
      subtitle: lines.join('\n'),
      headers: headers,
      rows: rows,
      fileName: 'Receipt_${safeId}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    _snack('✅ Receipt PDF exported!');
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(title: const Text('Transaction Details', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.teal[700], foregroundColor: Colors.white),
      body: Column(children: [
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
          Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(width: double.infinity, padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [Colors.teal[700]!, Colors.teal[500]!])),
              child: Column(children: [
                Text(t.id, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_formatDate(t.dateTime), style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12)),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: _statusColor().withAlpha(80), borderRadius: BorderRadius.circular(20)),
                  child: Text(t.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                const SizedBox(height: 12),
                Text(t.total.toStringAsFixed(2), style: TextStyle(color: Colors.white, fontSize: 28,
                    fontWeight: FontWeight.bold,
                    decoration: t.status == 'voided' ? TextDecoration.lineThrough : null)),
              ]))),
          const SizedBox(height: 16),

          // Items
          Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.shopping_bag, size: 18, color: Colors.teal[700]),
                  const SizedBox(width: 8),
                  Text('Items (${t.totalQty})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal[800])),
                ]),
                const Divider(),
                ...t.items.map((item) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(flex: 5, child: Text(item.name, style: const TextStyle(fontSize: 13))),
                    Expanded(flex: 3, child: Text('${item.qty} x ${item.price.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]), textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text(item.subtotal.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
                  ]))),
              ]))),
          const SizedBox(height: 12),

          // Summary
          Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              _row('Subtotal', t.subtotal.toStringAsFixed(2)),
              if (t.totalDiscount > 0) _row('Discount', '-${t.totalDiscount.toStringAsFixed(2)}', color: Colors.red),
              _row('VAT (12%)', t.tax.toStringAsFixed(2)),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('TOTAL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(t.total.toStringAsFixed(2), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const Divider(),
              _row('Payment', t.paymentMethod),
              _row('Paid', t.amountPaid.toStringAsFixed(2)),
              _row('Change', t.change.toStringAsFixed(2)),
              _row('Cashier', t.cashier),
              _row('Branch', t.branch),
            ]))),

          if (t.status == 'voided') ...[
            const SizedBox(height: 12),
            Card(color: Colors.red[50], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                Row(children: [const Icon(Icons.block, color: Colors.red, size: 18), const SizedBox(width: 8),
                  const Text('Void Details', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))]),
                const Divider(),
                _row('Reason', t.voidReason, color: Colors.red),
                _row('Voided By', t.voidedBy, color: Colors.red),
                if (t.voidedAt != null) _row('Voided At', _formatDate(t.voidedAt!), color: Colors.red),
              ]))),
          ],

          if (t.status == 'refunded') ...[
            const SizedBox(height: 12),
            Card(color: Colors.orange[50], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                Row(children: [const Icon(Icons.undo, color: Colors.orange, size: 18), const SizedBox(width: 8),
                  const Text('Refund Details', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))]),
                const Divider(),
                _row('Amount', t.refundAmount.toStringAsFixed(2), color: Colors.orange),
                _row('Method', t.refundMethod, color: Colors.orange),
                _row('Refunded By', t.refundedBy, color: Colors.orange),
                if (t.refundedAt != null) _row('Refunded At', _formatDate(t.refundedAt!), color: Colors.orange),
              ]))),
          ],
          const SizedBox(height: 16),
        ]))),

        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8, offset: const Offset(0, -2))]),
          child: SafeArea(child: Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _snack('No printer detected. Configure in Settings > Printer Settings.'),
              icon: const Icon(Icons.print, size: 18), label: const Text('Reprint', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)))),
            const SizedBox(width: 8),
            // ★ FIX: Now calls real _exportPdf() instead of fake snackbar
            Expanded(child: OutlinedButton.icon(
              onPressed: _exportPdf,
              icon: Icon(Icons.picture_as_pdf, size: 18, color: Colors.red[700]),
              label: const Text('PDF', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)))),
            if (t.status == 'completed') ...[
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: _voidTxn,
                icon: const Icon(Icons.block, size: 18, color: Colors.red),
                label: const Text('Void', style: TextStyle(fontSize: 12, color: Colors.red)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(
                onPressed: _refundTxn,
                icon: const Icon(Icons.undo, size: 18), label: const Text('Refund', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12)))),
            ],
          ]))),
      ]),
    );
  }

  Widget _row(String label, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 12, color: color ?? Colors.grey[600])),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    ]));
}
