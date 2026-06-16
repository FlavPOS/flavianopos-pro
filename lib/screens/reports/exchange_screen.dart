import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/exchange_model.dart';
import '../../models/transaction_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';

class ExchangeScreen extends StatefulWidget {
  final Transaction transaction;
  final String currentUser, branch;
  const ExchangeScreen({super.key, required this.transaction, required this.currentUser, required this.branch});
  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  TransactionItem? _selectedItem;
  Product? _newProduct;
  final _reasonCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String _reason = 'Damaged';
  bool _processing = false;
  static const _reasons = ['Damaged', 'Defective', 'Wrong Size', 'Wrong Item', 'Wrong Color', 'Other'];

  @override
  void dispose() { _reasonCtrl.dispose(); _pinCtrl.dispose(); super.dispose(); }

  double get _priceDiff => (_newProduct?.sellingPrice ?? 0) - (_selectedItem?.price ?? 0);
  bool get _canProcess => _selectedItem != null && _newProduct != null && (_newProduct!.sellingPrice >= (_selectedItem?.price ?? 0));

  void _selectReplacement() async {
    final products = Product.allProducts.where((p) => p.stockQty > 0 && p.sku != (_selectedItem?.sku ?? '')).toList();
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
            const Text('Select Replacement Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
            if (_selectedItem != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Min price: ${_selectedItem!.price.toStringAsFixed(2)} (same or higher)', style: TextStyle(fontSize: 11, color: Colors.orange[700]))),
            const SizedBox(height: 12),
            TextField(controller: searchCtrl, onChanged: (_) => setS(() {}),
              decoration: InputDecoration(hintText: 'Search product...', prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10))),
            const SizedBox(height: 8),
            Expanded(child: ListView.builder(controller: sc, itemCount: filtered.length,
              itemBuilder: (_, i) { final p = filtered[i]; final canSelect = p.sellingPrice >= (_selectedItem?.price ?? 0);
                return Card(margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(dense: true,
                    leading: CircleAvatar(radius: 18, backgroundColor: canSelect ? Colors.blue[50] : Colors.red[50],
                      child: Icon(Icons.inventory_2, size: 18, color: canSelect ? Colors.blue : Colors.red)),
                    title: Text(p.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: canSelect ? Colors.black87 : Colors.grey)),
                    subtitle: Text('SKU: ${p.sku} | Stock: ${p.stockQty} | ${p.sellingPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: canSelect ? Colors.grey[600] : Colors.grey)),
                    trailing: canSelect ? const Icon(Icons.chevron_right, color: Colors.blue) : Text('Too low', style: TextStyle(fontSize: 10, color: Colors.red[300])),
                    onTap: canSelect ? () => Navigator.pop(ctx, p) : null)); })),
          ])));
      }));
    if (result != null) setState(() => _newProduct = result);
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

      // Return old item stock
      final oldIdx = Product.allProducts.indexWhere((p) => p.sku == _selectedItem!.sku);
      if (oldIdx >= 0) {
        final old = Product.allProducts[oldIdx];
        Product.updateProduct(old.id, Product(id: old.id, name: old.name, sku: old.sku, category: old.category,
          sellingPrice: old.sellingPrice, costPrice: old.costPrice, stockQty: old.stockQty + 1,
          reorderLevel: old.reorderLevel, barcode: old.barcode, imagePath: old.imagePath, imageUrl: old.imageUrl, unit: old.unit));
      }

      // Deduct new item stock
      final newP = _newProduct!;
      Product.updateProduct(newP.id, Product(id: newP.id, name: newP.name, sku: newP.sku, category: newP.category,
        sellingPrice: newP.sellingPrice, costPrice: newP.costPrice, stockQty: newP.stockQty - 1,
        reorderLevel: newP.reorderLevel, barcode: newP.barcode, imagePath: newP.imagePath, imageUrl: newP.imageUrl, unit: newP.unit));

      // Save exchange record
      final exchange = Exchange(id: 'EXC-${now.millisecondsSinceEpoch}', exchangeNumber: excNum,
        originalTxnId: widget.transaction.id, exchangeDate: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        returnedItemName: _selectedItem!.name, returnedItemSku: _selectedItem!.sku, returnedQty: 1, returnedPrice: _selectedItem!.price,
        newItemName: newP.name, newItemSku: newP.sku, newQty: 1, newPrice: newP.sellingPrice,
        priceDifference: diff, amountPaid: diff > 0 ? diff : 0, reason: reason,
        processedBy: widget.currentUser, approvedBy: mgr.name, branch: widget.branch,
        dateCreated: now.toIso8601String());
      await Exchange.create(exchange);

      setState(() => _processing = false);
      if (mounted) {
        _showReceiptAndPrint(exchange);
      }
    } catch (e) { setState(() => _processing = false); _snack('Error: $e'); }
  }

  void _showReceiptAndPrint(Exchange exc) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 28), const SizedBox(width: 8),
        const Expanded(child: Text('Exchange Complete!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))]),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _receiptLine('Exchange #', exc.exchangeNumber),
        _receiptLine('Original TXN', exc.originalTxnId),
        const Divider(),
        const Text('RETURNED ITEM:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
        _receiptLine(exc.returnedItemName, exc.returnedPrice.toStringAsFixed(2)),
        _receiptLine('Reason', exc.reason),
        const SizedBox(height: 8),
        const Text('NEW ITEM:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
        _receiptLine(exc.newItemName, exc.newPrice.toStringAsFixed(2)),
        const Divider(),
        if (exc.priceDifference > 0) _receiptLine('Price Difference', '+${exc.priceDifference.toStringAsFixed(2)}'),
        _receiptLine('Approved By', exc.approvedBy),
        _receiptLine('Date', exc.exchangeDate),
      ])),
      actions: [
        TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context, true); }, child: const Text('Close')),
        ElevatedButton.icon(icon: const Icon(Icons.print, size: 18), label: const Text('Print Receipt'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
          onPressed: () => _printReceipt(exc)),
      ]));
  }

  Future<void> _printReceipt(Exchange exc) async {
    final pdf = pw.Document();
    for (final copy in ['CUSTOMER COPY', 'CASHIER COPY']) {
      pdf.addPage(pw.Page(pageFormat: PdfPageFormat.roll80, margin: const pw.EdgeInsets.all(8),
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Text('EXCHANGE RECEIPT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text(copy, style: const pw.TextStyle(fontSize: 8)),
          pw.Divider(),
          pw.SizedBox(height: 4),
          _pdfRow('Exchange #:', exc.exchangeNumber), _pdfRow('Date:', exc.exchangeDate),
          _pdfRow('Original TXN:', exc.originalTxnId), _pdfRow('Branch:', exc.branch),
          pw.SizedBox(height: 6), pw.Divider(),
          pw.Text('RETURNED ITEM', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          _pdfRow(exc.returnedItemName, '${exc.returnedPrice.toStringAsFixed(2)}'),
          _pdfRow('SKU:', exc.returnedItemSku), _pdfRow('Reason:', exc.reason),
          pw.SizedBox(height: 6), pw.Divider(),
          pw.Text('NEW ITEM', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          _pdfRow(exc.newItemName, '${exc.newPrice.toStringAsFixed(2)}'),
          _pdfRow('SKU:', exc.newItemSku),
          pw.Divider(),
          if (exc.priceDifference > 0) _pdfRow('Price Difference:', '+${exc.priceDifference.toStringAsFixed(2)}'),
          if (exc.amountPaid > 0) _pdfRow('Amount Paid:', exc.amountPaid.toStringAsFixed(2)),
          pw.SizedBox(height: 8),
          _pdfRow('Processed By:', exc.processedBy), _pdfRow('Approved By:', exc.approvedBy),
          pw.SizedBox(height: 8), pw.Divider(),
          pw.Text('Thank you!', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('FlavianoPOS - PRO', style: const pw.TextStyle(fontSize: 8)),
        ])));
    }
    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  pw.Widget _pdfRow(String l, String v) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(l, style: const pw.TextStyle(fontSize: 9)), pw.Text(v, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))]));

  Widget _receiptLine(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: TextStyle(fontSize: 12, color: Colors.grey[700])), Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]));

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(elevation: 0, backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white,
        title: const Text('Exchange Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Original Transaction
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.receipt, size: 18, color: Color(0xFF1565C0)), const SizedBox(width: 8),
              Text('Original Transaction: ${widget.transaction.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
            const Divider(),
            const Text('Select item to exchange:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...widget.transaction.items.map((item) => RadioListTile<TransactionItem>(
              value: item, groupValue: _selectedItem, dense: true, visualDensity: VisualDensity.compact,
              activeColor: const Color(0xFF1565C0),
              title: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text('SKU: ${item.sku} | Qty: ${item.qty} | ${item.price.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              onChanged: (v) => setState(() { _selectedItem = v; _newProduct = null; }))),
          ])),
        const SizedBox(height: 16),

        // Reason
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

        // Replacement Item
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.swap_horiz, size: 18, color: Colors.green), const SizedBox(width: 8),
              const Text('Replacement Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const Spacer(),
              if (_selectedItem != null) TextButton.icon(icon: const Icon(Icons.search, size: 16), label: const Text('Select', style: TextStyle(fontSize: 12)), onPressed: _selectReplacement)]),
            if (_selectedItem == null) Padding(padding: const EdgeInsets.all(12), child: Text('Select an item to exchange first', style: TextStyle(color: Colors.grey[400], fontSize: 12))),
            if (_newProduct != null) ...[const Divider(),
              ListTile(dense: true, contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 18, backgroundColor: Colors.green[50], child: const Icon(Icons.check_circle, color: Colors.green, size: 20)),
                title: Text(_newProduct!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('SKU: ${_newProduct!.sku} | ${_newProduct!.sellingPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
              if (_priceDiff > 0) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                child: Row(children: [const Icon(Icons.info_outline, size: 16, color: Colors.orange), const SizedBox(width: 8),
                  Text('Customer pays difference: ${_priceDiff.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange[800]))])),
              if (_priceDiff == 0) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [Icon(Icons.check, size: 16, color: Colors.green), SizedBox(width: 8),
                  Text('Same price — no additional payment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green))])),
            ],
          ])),
        const SizedBox(height: 16),

        // Manager PIN
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.lock, size: 18, color: Colors.red), SizedBox(width: 8),
              Text('Manager Approval', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
            const SizedBox(height: 8),
            TextField(controller: _pinCtrl, obscureText: true, keyboardType: TextInputType.number, maxLength: 6,
              decoration: InputDecoration(labelText: 'Manager PIN *', prefixIcon: const Icon(Icons.lock_outline, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), counterText: '')),
          ])),
        const SizedBox(height: 24),

        // Process Button
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
          onPressed: (_canProcess && !_processing) ? _processExchange : null,
          icon: _processing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.swap_horiz),
          label: Text(_processing ? 'Processing...' : 'Process Exchange', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey[300],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
        const SizedBox(height: 16),
      ])),
    );
  }
}
