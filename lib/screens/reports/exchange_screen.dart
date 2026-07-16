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

// v1.0.61+143 - Return entry with per-item reason
class _ReturnEntry {
  final TransactionItem item;
  String reason;
  _ReturnEntry({required this.item, this.reason = 'Damaged'});
}

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
  // v1.0.61+143 - Multi-item exchange support
  final List<_ReturnEntry> _returnedItems = [];
  final List<_ReplacementEntry> _replacements = [];
  final _reasonCtrl = TextEditingController();
  // v1.0.61+145 - Additional cash received field
  final _cashCtrl = TextEditingController();
  double _cashReceived = 0;
  final _pinCtrl = TextEditingController();
  String _reason = 'Damaged';
  bool _processing = false;
  static const _reasons = ['Damaged', 'Defective', 'Wrong Size', 'Wrong Item', 'Wrong Color', 'Other'];

  @override
  void dispose() { _reasonCtrl.dispose(); _pinCtrl.dispose(); _cashCtrl.dispose(); super.dispose(); }

  double get _replacementTotal => _replacements.fold<double>(0, (sum, r) => sum + r.total);
  // v1.0.61+143 - Sum of all selected returned items
  double get _originalPrice => _returnedItems.fold<double>(0, (sum, r) => sum + (r.item.price * r.item.qty));
  double get _priceDiff => _replacementTotal - _originalPrice;
  // v1.0.61+145 - Change calculation for customer
  double get _change => _cashReceived - _priceDiff;
  // v1.0.61+143 - Multi-item validation
  // v1.0.61+145 - Also require sufficient cash if difference > 0
  bool get _canProcess => _returnedItems.isNotEmpty && _replacements.isNotEmpty && _replacementTotal >= _originalPrice && (_priceDiff <= 0 || _cashReceived >= _priceDiff);
  int get _totalQty => _replacements.fold<int>(0, (sum, r) => sum + r.quantity);

  void _addReplacementItem() async {
    // v1.0.61+143 - Exclude all returned items SKUs
    final existingSkus = _replacements.map((r) => r.product.sku).toSet();
    final returnedSkus = _returnedItems.map((r) => r.item.sku).toSet();
    final products = Product.allProducts.where((p) => p.stockQty > 0 && !returnedSkus.contains(p.sku) && !existingSkus.contains(p.sku)).toList();
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

    // v1.0.60+140 - PRE-FLIGHT stock check to prevent partial failures
    // Verify ALL replacement items have sufficient stock BEFORE making any changes
    try {
      final assignCheck = await DeviceAssignmentService().read();
      final branchIdCheck = (assignCheck['branchId'] ?? '').toString();
      if (branchIdCheck.isNotEmpty) {
        final insufficientItems = <String>[];
        for (final entry in _replacements) {
          final current = await BranchInventoryService.getStock(
            branchIdCheck, entry.product.id,
          );
          if (current < entry.quantity) {
            insufficientItems.add(
              '${entry.product.name}: need ${entry.quantity}, have $current'
            );
          }
        }
        if (insufficientItems.isNotEmpty) {
          debugPrint('[EXCHANGE-PREFLIGHT] Blocked: ${insufficientItems.join("; ")}');
          _snack('Insufficient stock: ${insufficientItems.first}');
          return;  // BLOCK entire exchange
        }
        debugPrint('[EXCHANGE-PREFLIGHT] All replacement items have sufficient stock');
      }
    } catch (e) {
      debugPrint('[EXCHANGE-PREFLIGHT] Check failed: $e');
      _snack('Stock check failed - please try again');
      return;
    }

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
        // v1.0.61+143 - Return stock for ALL returned items
        int returnedCount = 0;
        for (final returnEntry in _returnedItems) {
          final oldIdx = Product.allProducts.indexWhere((p) => p.sku == returnEntry.item.sku);
          if (oldIdx < 0) {
            debugPrint('[EXCHANGE-STOCK] Old product not found for SKU: ${returnEntry.item.sku}');
            continue;
          }
          final old = Product.allProducts[oldIdx];
          final ok = await BranchInventoryService.incrementStock(branchId, old.id, returnEntry.item.qty);
          if (ok) {
            returnedCount++;
            debugPrint('[EXCHANGE-STOCK] Returned ${returnEntry.item.qty} x ${old.name} (${returnEntry.reason}) to $branchId');
          } else {
            debugPrint('[EXCHANGE-STOCK] Failed to return ${old.name} to $branchId');
          }
        }
        debugPrint('[EXCHANGE-STOCK] Returned $returnedCount items total');

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

      // v1.0.61+143 - Multi-item exchange records (JSON in existing fields)
      final returnedNames = _returnedItems.map((r) => '${r.item.name} x${r.item.qty} (${r.reason})').join(' | ');
      final returnedSkus = _returnedItems.map((r) => r.item.sku).join(' | ');
      final returnedQtyTotal = _returnedItems.fold<int>(0, (sum, r) => sum + r.item.qty);
      final combinedReasons = _returnedItems.map((r) => r.reason).toSet().join(', ');
      final allNames = _replacements.map((r) => '${r.product.name} x${r.quantity}').join(' | ');
      final allSkus = _replacements.map((r) => r.product.sku).join(' | ');

      // Save exchange record (multi-item stored as concatenated string with reasons)
      final exchange = Exchange(id: 'EXC-${now.millisecondsSinceEpoch}', exchangeNumber: excNum,
        originalTxnId: widget.transaction.id, exchangeDate: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        returnedItemName: returnedNames, returnedItemSku: returnedSkus, returnedQty: returnedQtyTotal, returnedPrice: _originalPrice,
        newItemName: allNames, newItemSku: allSkus, newQty: _totalQty, newPrice: _replacementTotal,
        priceDifference: diff, amountPaid: _cashReceived, reason: combinedReasons.isEmpty ? reason : combinedReasons,
        processedBy: widget.currentUser, approvedBy: mgr.name, branch: widget.branch,
        dateCreated: now.toIso8601String());
      await Exchange.create(exchange);


      // === UPDATE ORIGINAL TRANSACTION ITEMS ===
      try {
        // v1.0.61+143 - Delete ALL returned items from transaction
        for (final returnEntry in _returnedItems) {
          await DatabaseHelper().deleteTransactionItem(widget.transaction.id, returnEntry.item.sku);
        }

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

      // v1.0.60+142 - Sync updated transaction to Firebase
      try {
        final updatedTxn = Transaction.allTransactions
            .firstWhere((tx) => tx.id == widget.transaction.id,
                        orElse: () => widget.transaction);
        Transaction.updateTransaction(widget.transaction.id, updatedTxn);
        debugPrint('[EXCHANGE-SYNC] Transaction updated for Firebase sync');
      } catch (e) {
        debugPrint('[EXCHANGE-SYNC] Failed: $e');
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
        // v1.0.60+141 - Return true to trigger parent refresh
        TextButton(onPressed: () { 
          Navigator.pop(ctx); // Close receipt dialog
          Navigator.pop(context, true); // Return to Sales History with refresh signal
        }, child: const Text('Close')),
        ElevatedButton.icon(icon: const Icon(Icons.print, size: 16), label: const Text('Print PDF'),
          // v1.0.60+141 - Return true after PDF print to refresh parent
          onPressed: () async { 
            Navigator.pop(ctx); 
            await _printPdf(exc); 
            if (mounted) Navigator.pop(context, true); 
          }),
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
            const Text('Select items to exchange (check multiple):', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            // v1.0.61+143 - Multi-select with per-item reason
            ...widget.transaction.items.map((item) {
              final existingIdx = _returnedItems.indexWhere((r) => r.item.sku == item.sku);
              final isSelected = existingIdx >= 0;
              final currentReason = isSelected ? _returnedItems[existingIdx].reason : 'Damaged';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[50] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: isSelected,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      activeColor: Colors.blue[700],
                      title: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text('SKU: ${item.sku} | Qty: ${item.qty} | ${item.price.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _returnedItems.add(_ReturnEntry(item: item));
                        } else {
                          _returnedItems.removeWhere((r) => r.item.sku == item.sku);
                          if (_returnedItems.isEmpty) _replacements.clear();
                        }
                      }),
                    ),
                    if (isSelected) Padding(
                      padding: const EdgeInsets.fromLTRB(56, 0, 12, 8),
                      child: DropdownButtonFormField<String>(
                        initialValue: currentReason,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Reason for exchange',
                          labelStyle: const TextStyle(fontSize: 11),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                        items: _reasons.map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r, style: const TextStyle(fontSize: 12)),
                        )).toList(),
                        onChanged: (v) => setState(() {
                          _returnedItems[existingIdx].reason = v ?? 'Damaged';
                        }),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ])),
        const SizedBox(height: 16),

        // v1.0.61+144 - Reason chips removed (per-item reasons in checkboxes above)
        const SizedBox(height: 16),

        // Replacement Items (MULTI!)
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.swap_horiz, size: 18, color: Colors.green), const SizedBox(width: 8),
              const Text('Replacement Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              // v1.0.61+143 - Multi-item check
              if (_returnedItems.isNotEmpty) TextButton.icon(
                icon: const Icon(Icons.add_circle, size: 18, color: Colors.green),
                label: Text(_replacements.isEmpty ? 'Select' : 'Add Item', style: const TextStyle(fontSize: 12)),
                onPressed: _addReplacementItem)]),
            if (_returnedItems.isEmpty)
              Padding(padding: const EdgeInsets.all(12), child: Text('Select item(s) to exchange first', style: TextStyle(color: Colors.grey[400], fontSize: 12)))
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

        // v1.0.61+146 - Additional Cash Received (only when customer owes money)
        if (_priceDiff > 0)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.payments, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Additional Cash Received', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                Text('*', style: TextStyle(color: Colors.red[700], fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 6),
              Text('Difference to collect: \${_priceDiff.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, color: Colors.orange[800], fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              TextField(
                controller: _cashCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: 'PHP ',
                  hintText: _priceDiff.toStringAsFixed(2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (v) => setState(() {
                  _cashReceived = double.tryParse(v) ?? 0;
                }),
              ),
              if (_cashReceived >= _priceDiff && _priceDiff > 0) Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('Change: \${_change.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[800])),
                ]),
              ),
              if (_cashReceived > 0 && _cashReceived < _priceDiff) Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.warning, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Insufficient - need \${(_priceDiff - _cashReceived).toStringAsFixed(2)} more',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[800]))),
                ]),
              ),
            ]),
          ),
        if (_priceDiff > 0) const SizedBox(height: 16),

        // v1.0.61+146 - Additional Cash Received
        if (_priceDiff > 0)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.payments, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Additional Cash Received', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                Text('*', style: TextStyle(color: Colors.red[700], fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 6),
              Text('Difference: \${_priceDiff.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, color: Colors.orange[800], fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              TextField(
                controller: _cashCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: 'PHP ',
                  hintText: _priceDiff.toStringAsFixed(2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (v) => setState(() {
                  _cashReceived = double.tryParse(v) ?? 0;
                }),
              ),
              if (_cashReceived >= _priceDiff && _priceDiff > 0) Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('Change: \${_change.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[800])),
                ]),
              ),
              if (_cashReceived > 0 && _cashReceived < _priceDiff) Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.warning, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Need \${(_priceDiff - _cashReceived).toStringAsFixed(2)} more',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[800]))),
                ]),
              ),
            ]),
          ),
        if (_priceDiff > 0) const SizedBox(height: 16),

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
