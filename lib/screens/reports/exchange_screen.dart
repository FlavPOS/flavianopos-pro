import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/exchange_model.dart';
import '../../models/transaction_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../helpers/database_helper.dart';
import '../../services/branch_inventory_service.dart'; // v1.0.60+138
import '../../services/device_assignment_service.dart'; // v1.0.60+138

// Helper class for replacement items list
class _ReplacementEntry {
  final Product product;
  int quantity = 1;
  _ReplacementEntry({required this.product});
  double get total => product.sellingPrice * quantity;
}

class ExchangeScreen extends StatefulWidget {
  final Transaction transaction;
  final String currentUser, branch;
  const ExchangeScreen({super.key, required this.transaction, required this.currentUser, required this.branch});
  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  TransactionItem? _selectedItem;
  final List<_ReplacementEntry> _replacements = [];
  final _reasonCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String _reason = 'Damaged';
  bool _processing = false;
  static const _reasons = ['Damaged', 'Defective', 'Wrong Size', 'Wrong Item', 'Wrong Color', 'Other'];

  @override
  void dispose() { _reasonCtrl.dispose(); _pinCtrl.dispose(); super.dispose(); }

  double get _replacementTotal => _replacements.fold<double>(0, (sum, r) => sum + r.total);
  double get _originalPrice => _selectedItem?.price ?? 0;
  double get _priceDiff => _replacementTotal - _originalPrice;
  bool get _canProcess => _selectedItem != null && _replacements.isNotEmpty && _replacementTotal >= _originalPrice;
  int get _totalQty => _replacements.fold<int>(0, (sum, r) => sum + r.quantity);

  void _addReplacementItem() async {
    final existingSkus = _replacements.map((r) => r.product.sku).toSet();
    final products = Product.allProducts.where((p) => p.stockQty > 0 && p.sku != (_selectedItem?.sku ?? '') && !existingSkus.contains(p.sku)).toList();
    final searchCtrl = TextEditingController();
    final result = await showModalBottomSheet<Product>(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final q = searchCtrl.text.toLowerCase();
        final filtered = q.isEmpty ? products : products.where((p) => p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q) || p.barcode.toLowerCase().contains(q)).toList();
        return DraggableScrollableSheet(initialChildSize: 0.8, minChildSize: 0.4, maxChildSize: 0.95, expand: false,
          builder: (_, sc) => Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            const Text('Add Replacement Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
            if (_replacements.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4),
              child: Text('Current total: ${_replacementTotal.toStringAsFixed(2)} | Need: ${_originalPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: _replacementTotal >= _originalPrice ? Colors.green[700] : Colors.orange[700]))),
            const SizedBox(height: 12),
            TextField(controller: searchCtrl, onChanged: (_) => setS(() {}),
              decoration: InputDecoration(hintText: 'Search product...', prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10))),
            const SizedBox(height: 12),
            Expanded(child: filtered.isEmpty
              ? Center(child: Text('No products available', style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(controller: sc, itemCount: filtered.length, itemBuilder: (_, i) {
                  final p = filtered[i];
                  return Card(child: ListTile(dense: true,
                    leading: CircleAvatar(radius: 16, backgroundColor: Colors.blue[50], child: Icon(Icons.shopping_bag, size: 18, color: Colors.blue[700])),
                    title: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: Text('SKU: ${p.sku} | Stock: ${p.stockQty} | ${p.sellingPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    trailing: const Icon(Icons.add_circle, color: Colors.green),
                    onTap: () => Navigator.pop(ctx, p)));
                })),
          ])));
      }));
    if (result != null) setState(() => _replacements.add(_ReplacementEntry(product: result)));
  }

  void _incrementQty(_ReplacementEntry entry) {
    if (entry.quantity < entry.product.stockQty) {
      setState(() => entry.quantity++);
    } else {
      _snack('Max stock reached');
    }
  }

  void _decrementQty(_ReplacementEntry entry) {
    if (entry.quantity > 1) {
      setState(() => entry.quantity--);
    }
  }

  void _removeItem(_ReplacementEntry entry) {
    setState(() => _replacements.remove(entry));
  }

  Future<void> _processExchange() async {
    if (!_canProcess) return;
    if (_pinCtrl.text.trim().isEmpty) { _snack('Enter Manager PIN'); return; }
    final mgr = AppUser.allUsers.where((u) => (u.role == 'Admin' || u.role == 'Manager') && u.pin == _pinCtrl.text.trim()).firstOrNull;
    if (mgr == null) { _snack('Invalid Manager PIN'); return; }
    final reason = _reason == 'Other' ? _reasonCtrl.text.trim() : _reason;
    if (reason.isEmpty) { _snack('Enter reason'); return; }

    setState(() => _processing = true);
    try {
      final now = DateTime.now();
      final excNum = await Exchange.generateExchangeNumber();
      final diff = _priceDiff;

      // v1.0.60+138 - Use BranchInventoryService (per-branch + Firebase sync)
      final assign = await DeviceAssignmentService().read();
      final branchId = (assign['branchId'] ?? '').toString();
      if (branchId.isEmpty) {
        debugPrint('[EXCHANGE-STOCK] No branchId - skipping inventory changes');
      } else {
        // Return old item stock (increment branch inventory)
        final oldIdx = Product.allProducts.indexWhere((p) => p.sku == _selectedItem!.sku);
        if (oldIdx >= 0) {
          final old = Product.allProducts[oldIdx];
          final ok = await BranchInventoryService.incrementStock(branchId, old.id, 1);
          if (ok) {
            debugPrint('[EXCHANGE-STOCK] Returned 1 x ${old.name} to $branchId');
          } else {
            debugPrint('[EXCHANGE-STOCK] Failed to return ${old.name} to $branchId');
          }
        } else {
          debugPrint('[EXCHANGE-STOCK] Old product not found for SKU: ${_selectedItem!.sku}');
        }

        // Deduct ALL new items stock (decrement branch inventory)
        int deducted = 0;
        for (final entry in _replacements) {
          final newP = entry.product;
          final freshIdx = Product.allProducts.indexWhere((p) => p.sku == newP.sku);
          if (freshIdx < 0) {
            debugPrint('[EXCHANGE-STOCK] New product not found for SKU: ${newP.sku}');
            continue;
          }
          final fresh = Product.allProducts[freshIdx];
          final ok = await BranchInventoryService.decrementStock(branchId, fresh.id, entry.quantity);
          if (ok) {
            deducted++;
            debugPrint('[EXCHANGE-STOCK] Deducted ${entry.quantity} x ${fresh.name} from $branchId');
          } else {
            debugPrint('[EXCHANGE-STOCK] Failed to deduct ${fresh.name} from $branchId');
          }
        }
        debugPrint('[EXCHANGE-STOCK] Summary: 1 returned, $deducted deducted at $branchId');
      }

      // Combine items into pipe-separated strings for storage
      final allNames = _replacements.map((r) => '${r.product.name} x${r.quantity}').join(' | ');
      final allSkus = _replacements.map((r) => r.product.sku).join(' | ');

      // Save exchange record (multi-item stored as concatenated string)
      final exchange = Exchange(id: 'EXC-${now.millisecondsSinceEpoch}', exchangeNumber: excNum,
        originalTxnId: widget.transaction.id, exchangeDate: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        returnedItemName: _selectedItem!.name, returnedItemSku: _selectedItem!.sku, returnedQty: 1, returnedPrice: _selectedItem!.price,
        newItemName: allNames, newItemSku: allSkus, newQty: _totalQty, newPrice: _replacementTotal,
        priceDifference: diff, amountPaid: diff > 0 ? diff : 0, reason: reason,
        processedBy: widget.currentUser, approvedBy: mgr.name, branch: widget.branch,
        dateCreated: now.toIso8601String());
      await Exchange.create(exchange);


      // === UPDATE ORIGINAL TRANSACTION ITEMS ===
      try {
        // 1. Delete the exchanged item from transaction
        await DatabaseHelper().deleteTransactionItem(widget.transaction.id, _selectedItem!.sku);

        // 2. Insert all replacement items
        for (final entry in _replacements) {
          await DatabaseHelper().insertTransactionItem({
            'transactionId': widget.transaction.id,
            'name': entry.product.name,
            'sku': entry.product.sku,
            'qty': entry.quantity,
            'price': entry.product.sellingPrice,
            'discount': 0,
            'discountType': 'fixed',
            'discountAmount': 0,
          });
        }

        // 3. Recalculate transaction subtotal & total
        final allItems = await DatabaseHelper().getTransactionItems(widget.transaction.id);
        double newSubtotal = 0;
        for (final item in allItems) {
          newSubtotal += ((item['price'] as num?)?.toDouble() ?? 0) * ((item['qty'] as num?)?.toInt() ?? 0);
        }
        final newTotal = newSubtotal - widget.transaction.totalDiscount;

        // 4. Update transaction with new totals
        await DatabaseHelper().updateTransaction(widget.transaction.id, {
          'subtotal': newSubtotal,
          'totalDiscount': widget.transaction.totalDiscount,
          'total': newTotal,
        });
      } catch (e) {
        // Log but don't fail the exchange itself
        // ignore: avoid_print
        print('Transaction update warning: $e');
      }
      // v1.0.60+138.1 - Reload Transaction cache so Sales History shows new items + total
      try {
        await Transaction.loadFromDB();
        debugPrint('[EXCHANGE-REFRESH] Reloaded Transaction cache after exchange');
      } catch (e) {
        debugPrint('[EXCHANGE-REFRESH] Failed to reload: $e');
      }
      setState(() => _processing = false);
      if (mounted) {
        _showReceiptAndPrint(exchange);
      }
    } catch (e) { setState(() => _processing = false); _snack('Error: $e'); }
  }

  void _showReceiptAndPrint(Exchange exc) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [const Icon(Icons.check_circle, color: Colors.green), const SizedBox(width: 8),
        const Text('Exchange Complete!', style: TextStyle(fontSize: 16))]),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        _receiptLine('Exchange #', exc.exchangeNumber),
        _receiptLine('Date', exc.exchangeDate),
        const Divider(),
        _receiptLine('Returned', exc.returnedItemName),
        _receiptLine('Price', exc.returnedPrice.toStringAsFixed(2)),
        const Divider(),
        const Text('New Item(s):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        ..._replacements.map((r) => _receiptLine('  ${r.product.name} x${r.quantity}', r.total.toStringAsFixed(2))),
        const Divider(),
        _receiptLine('Total Replacement', exc.newPrice.toStringAsFixed(2)),
        if (exc.priceDifference > 0) _receiptLine('Price Difference', '+${exc.priceDifference.toStringAsFixed(2)}'),
        _receiptLine('Approved By', exc.approvedBy),
        _receiptLine('Date', exc.exchangeDate),
      ])),
      actions: [
        TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context, true); }, child: const Text('Close')),
        ElevatedButton.icon(icon: const Icon(Icons.print, size: 16), label: const Text('Print PDF'),
          onPressed: () async { Navigator.pop(ctx); await _printPdf(exc); if (mounted) Navigator.pop(context, true); }),
      ],
    ));
  }

  Widget _receiptLine(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: const TextStyle(fontSize: 12)), Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]));

  Future<void> _printPdf(Exchange exc) async {
    try {
      // Show loading
      if (mounted) _snack('Generating PDF...');

      final pdf = pw.Document();
      final newItemsList = exc.newItemName.split(' | ');

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('EXCHANGE RECEIPT',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 16),
              pw.Divider(),
              _pdfRow('Exchange #:', exc.exchangeNumber),
              _pdfRow('Original Txn:', exc.originalTxnId),
              _pdfRow('Date:', exc.exchangeDate),
              _pdfRow('Branch:', exc.branch),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.Text('RETURNED ITEM:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              _pdfRow('Item:', exc.returnedItemName),
              _pdfRow('SKU:', exc.returnedItemSku),
              _pdfRow('Price:', exc.returnedPrice.toStringAsFixed(2)),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.Text('NEW ITEMS:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ...newItemsList.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text('  • $item', style: const pw.TextStyle(fontSize: 10)),
              )),
              pw.SizedBox(height: 4),
              pw.Divider(),
              _pdfRow('Total Replacement:', exc.newPrice.toStringAsFixed(2)),
              if (exc.priceDifference > 0)
                _pdfRow('Price Difference:', '+${exc.priceDifference.toStringAsFixed(2)}'),
              if (exc.amountPaid > 0)
                _pdfRow('Amount Paid:', exc.amountPaid.toStringAsFixed(2)),
              pw.SizedBox(height: 8),
              _pdfRow('Reason:', exc.reason),
              _pdfRow('Processed By:', exc.processedBy),
              _pdfRow('Approved By:', exc.approvedBy),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.Center(
                child: pw.Text('Thank you!',
                  style: const pw.TextStyle(fontSize: 9))),
            ],
          ),
        ),
      ));

      // Try share first (more reliable on Android)
      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Exchange_${exc.exchangeNumber}.pdf',
      );
    } catch (e) {
      if (mounted) _snack('PDF error: $e');
    }
  }

  pw.Widget _pdfRow(String l, String v) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(l, style: const pw.TextStyle(fontSize: 10)), pw.Text(v, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))]));

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, elevation: 0,
        title: const Text('Exchange Item', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Original Transaction Info
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.receipt_long, size: 18, color: Colors.blue), const SizedBox(width: 8),
              Text('Original Transaction: ${widget.transaction.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
            const Divider(),
            const Text('Select item to exchange:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ...widget.transaction.items.map((item) => RadioListTile<TransactionItem>(
              title: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text('SKU: ${item.sku} | Qty: ${item.qty} | ${item.price.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              value: item, groupValue: _selectedItem, dense: true, visualDensity: VisualDensity.compact,
              activeColor: Colors.blue[700],
              onChanged: (v) => setState(() { _selectedItem = v; _replacements.clear(); }))),
          ])),
        const SizedBox(height: 16),

        // Reason for Exchange
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.notes, size: 18, color: Colors.orange), SizedBox(width: 8),
              Text('Reason for Exchange', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: _reasons.map((r) => ChoiceChip(label: Text(r, style: TextStyle(fontSize: 11, color: _reason == r ? Colors.white : Colors.grey[700])),
              selected: _reason == r, selectedColor: Colors.orange, onSelected: (_) => setState(() => _reason = r))).toList()),
            if (_reason == 'Other') ...[const SizedBox(height: 8),
              TextField(controller: _reasonCtrl, decoration: InputDecoration(hintText: 'Enter reason...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true))],
          ])),
        const SizedBox(height: 16),

        // Replacement Items (MULTI!)
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.swap_horiz, size: 18, color: Colors.green), const SizedBox(width: 8),
              const Text('Replacement Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              if (_selectedItem != null) TextButton.icon(
                icon: const Icon(Icons.add_circle, size: 18, color: Colors.green),
                label: Text(_replacements.isEmpty ? 'Select' : 'Add Item', style: const TextStyle(fontSize: 12)),
                onPressed: _addReplacementItem)]),
            if (_selectedItem == null)
              Padding(padding: const EdgeInsets.all(12), child: Text('Select an item to exchange first', style: TextStyle(color: Colors.grey[400], fontSize: 12)))
            else if (_replacements.isEmpty)
              Padding(padding: const EdgeInsets.all(12), child: Text('No replacement items added. Tap "Select" to add.', style: TextStyle(color: Colors.grey[400], fontSize: 12)))
            else ...[
              const Divider(),
              ..._replacements.map((entry) => Container(margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green[100]!)),
                child: Row(children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entry.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${entry.product.sellingPrice.toStringAsFixed(2)} each = ${entry.total.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  ])),
                  // Qty controls
                  Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green[200]!)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      InkWell(onTap: () => _decrementQty(entry),
                        child: Container(padding: const EdgeInsets.all(6), child: Icon(Icons.remove, size: 14, color: entry.quantity > 1 ? Colors.green[700] : Colors.grey))),
                      Container(width: 28, alignment: Alignment.center, child: Text('${entry.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      InkWell(onTap: () => _incrementQty(entry),
                        child: Container(padding: const EdgeInsets.all(6), child: Icon(Icons.add, size: 14, color: Colors.green[700]))),
                    ])),
                  IconButton(icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20), onPressed: () => _removeItem(entry),
                    constraints: const BoxConstraints(), padding: const EdgeInsets.all(4)),
                ]))),
              const SizedBox(height: 8),
              const Divider(),
              // Totals
              Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Original Value:', style: TextStyle(fontSize: 12)),
                  Text(_originalPrice.toStringAsFixed(2), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ])),
              Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Replacement Total ($_totalQty ${_totalQty == 1 ? "item" : "items"}):', style: const TextStyle(fontSize: 12)),
                  Text(_replacementTotal.toStringAsFixed(2), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ])),
              const Divider(),
              // Status card
              if (_priceDiff > 0) Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                child: Row(children: [const Icon(Icons.info_outline, size: 16, color: Colors.orange), const SizedBox(width: 8),
                  Text('Customer pays difference: ${_priceDiff.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange[800]))])),
              if (_priceDiff == 0 && _replacements.isNotEmpty) Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [Icon(Icons.check, size: 16, color: Colors.green), SizedBox(width: 8),
                  Text('Exact match — no payment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green))])),
              if (_replacementTotal < _originalPrice) Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                child: Row(children: [const Icon(Icons.warning, size: 16, color: Colors.red), const SizedBox(width: 8),
                  Expanded(child: Text('Total too low! Add more items (need ${(_originalPrice - _replacementTotal).toStringAsFixed(2)} more)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[800])))])),
            ],
          ])),
        const SizedBox(height: 16),

        // Manager Approval
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.lock, size: 18, color: Colors.red), SizedBox(width: 8),
              Text('Manager Approval', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
            const SizedBox(height: 8),
            TextField(controller: _pinCtrl, obscureText: true, keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: 'Manager PIN *', prefixIcon: const Icon(Icons.lock_outline, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true)),
          ])),
        const SizedBox(height: 16),

        // Process Exchange Button
        SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton.icon(
            onPressed: _canProcess && !_processing ? _processExchange : null,
            icon: _processing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.swap_horiz),
            label: Text(_processing ? 'Processing...' : 'Process Exchange', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
      ])),
    );
  }
}
