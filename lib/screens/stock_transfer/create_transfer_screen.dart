// ============================================================
import '../../models/user_model.dart';
import '../../models/settings_model.dart';
// CREATE OUTBOUND TRANSFER - QuickPOS Pro
// Select items with batch info, validate stock, post transfer
// ============================================================
import 'package:flutter/material.dart';
import '../../models/stock_transfer_model.dart';
import '../../models/product_model.dart';
import '../../models/batch_model.dart';
import '../../models/branch_model.dart';
import '../../services/device_assignment_service.dart';
import '../../services/device_id_service.dart';

class CreateTransferScreen extends StatefulWidget {
  final String currentUser;
  final String currentBranch;
  const CreateTransferScreen({super.key, required this.currentUser, required this.currentBranch});
  @override
  State<CreateTransferScreen> createState() => _CreateTransferScreenState();
}

class _CreateTransferScreenState extends State<CreateTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remarksCtrl = TextEditingController();
  final _approvedByCtrl = TextEditingController();
  String? _fromBranchId, _fromBranchName, _toBranchId, _toBranchName;
  String _currentDeviceId = '';
  DateTime _transferDate = DateTime.now();
  final List<_TransferLineItem> _lineItems = [];
  bool _isSaving = false;
  String _transferNo = '';

  @override
  void initState() {
    super.initState();
    _loadTransferNo();
    _loadCurrentBranchFromDevice();
    final branches = Branch.allBranches;
    for (final b in branches) {
      if (b.name == widget.currentBranch || b.id == widget.currentBranch) {
        _fromBranchId = b.id;
        _fromBranchName = b.name;
        break;
      }
    }
  }

  // STX LOCKED FROM BRANCH - auto-load from device assignment
  Future<void> _loadCurrentBranchFromDevice() async {
    try {
      final assign = await DeviceAssignmentService().read();
      final deviceBranchId = (assign['branchId'] ?? '').toString();
      final deviceBranchName = (assign['branchName'] ?? '').toString();
      final deviceId = await DeviceIdService().getOrCreate();
      
      if (mounted && deviceBranchId.isNotEmpty) {
        setState(() {
          _fromBranchId = deviceBranchId;
          _fromBranchName = deviceBranchName;
          _currentDeviceId = deviceId;
        });
      }
    } catch (e) {
      // Fallback to widget.currentBranch (existing behavior)
    }
  }

  @override
  void dispose() { _remarksCtrl.dispose(); _approvedByCtrl.dispose(); super.dispose(); }

  Future<void> _loadTransferNo() async {
    final no = await StockTransferStorage.generateTransferNo();
    setState(() => _transferNo = no);
  }

  void _snack(String msg, [Color? bg]) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  String _pad(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) => '${_pad(d.month)}/${_pad(d.day)}/${d.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _transferDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)), lastDate: DateTime.now().add(const Duration(days: 7)));
    if (picked != null) setState(() => _transferDate = picked);
  }

  Future<void> _addItem() async {
    final products = Product.allProducts;
    final batches = ProductBatch.allBatches;
    final result = await showModalBottomSheet<_TransferLineItem>(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ItemBatchPicker(products: products, batches: batches, existingItems: _lineItems),
    );
    if (result != null) setState(() => _lineItems.add(result));
  }

  void _removeItem(int index) => setState(() => _lineItems.removeAt(index));

  void _editQty(int index) {
    final item = _lineItems[index];
    final ctrl = TextEditingController(text: item.qty.toString());
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Edit Qty: ${item.itemName}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Batch: ${item.batchNumber}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text('Available: ${item.availableStock}', style: TextStyle(fontSize: 12, color: Colors.teal[700])),
        const SizedBox(height: 12),
        TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true,
          decoration: InputDecoration(labelText: 'Quantity', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          final newQty = int.tryParse(ctrl.text) ?? 0;
          if (newQty <= 0) { _snack('Qty must be > 0', Colors.red); return; }
          if (newQty > item.availableStock) { _snack('Exceeds stock (${item.availableStock})', Colors.red); return; }
          setState(() => _lineItems[index] = item.copyWithQty(newQty));
          Navigator.pop(ctx);
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white),
          child: const Text('Update')),
      ],
    ));
  }

  Future<void> _postTransfer() async {
    if (_isSaving) return;
    if (_fromBranchId == null || _toBranchId == null) { _snack('Select both branches', Colors.red); return; }
    if (_fromBranchId == _toBranchId) { _snack('From and To branch cannot be the same', Colors.red); return; }
    if (_lineItems.isEmpty) { _snack('Add at least one item', Colors.red); return; }
    for (final item in _lineItems) {
      if (item.qty <= 0) { _snack('${item.itemName}: qty must be > 0', Colors.red); return; }
      if (item.qty > item.availableStock) {
        _snack('${item.itemName}: exceeds stock (${item.availableStock})', Colors.red); return;
      }
    }
    setState(() => _isSaving = true);

    // Manager PIN check
    if (AppSettings.requirePinVoid && mounted) {
      final pinCtrl = TextEditingController();
      final pinOk = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Manager PIN Required'),
        content: TextField(controller: pinCtrl, obscureText: true, maxLength: 6,
          decoration: InputDecoration(labelText: 'Enter Manager PIN',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            final mgr = AppUser.allUsers.where((u) => (u.role == 'Admin' || u.role == 'Manager') && u.pin == pinCtrl.text.trim()).firstOrNull;
            if (mgr != null) { Navigator.pop(ctx, true); }
            else { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Invalid Manager PIN'), backgroundColor: Colors.red)); }
          }, child: const Text('Confirm')),
        ]));
      if (pinOk != true) return;
    }
    try {
      final now = DateTime.now();
      final transferItems = _lineItems.map((li) => TransferItem(
        itemId: li.productId, itemCode: li.itemCode, itemName: li.itemName,
        category: li.category, unit: 'pcs',
        batchId: li.batchId, batchNumber: li.batchNumber,
        manufacturedDate: li.mfgDate, expiryDate: li.expDate,
        qtyTransferred: li.qty, cost: li.cost,
      )).toList();
      final transfer = StockTransfer(
        id: 'TF-${now.millisecondsSinceEpoch}',
        transferNo: _transferNo, transferDate: _transferDate,
        fromBranchId: _fromBranchId!, fromBranchName: _fromBranchName ?? '',
        toBranchId: _toBranchId!, toBranchName: _toBranchName ?? '',
        status: 'In Transit', preparedBy: widget.currentUser,
        approvedBy: _approvedByCtrl.text.trim(), remarks: _remarksCtrl.text.trim(),
        items: transferItems, createdAt: now,
        fromDeviceId: _currentDeviceId, toDeviceId: '',
      );
      for (final li in _lineItems) {
        final products = Product.allProducts;
        final pIdx = products.indexWhere((p) => p.id == li.productId);
        if (pIdx >= 0) {
          final p = products[pIdx];
          final newStock = AppSettings.allowNegativeStock ? (p.stockQty - li.qty) : (p.stockQty - li.qty).clamp(0, 999999);
          Product.updateProduct(p.id, Product(
            id: p.id, name: p.name, sku: p.sku, category: p.category,
            sellingPrice: p.sellingPrice, costPrice: p.costPrice, stockQty: newStock,
            reorderLevel: p.reorderLevel, barcode: p.barcode,
          ));

          // Deduct batch quantity
          if (li.batchId.isNotEmpty) {
            final bIdx = ProductBatch.allBatches.indexWhere((b) => b.id == li.batchId);
            if (bIdx >= 0) {
              final batch = ProductBatch.allBatches[bIdx];
              final newBatchQty = (batch.quantity - li.qty).clamp(0, 999999);
              ProductBatch.updateBatch(batch.id, batch.copyWith(quantity: newBatchQty));
            }
          }
        }
      }
      final ledgerEntries = _lineItems.map((li) {
        final currentStock = Product.allProducts.firstWhere((p) => p.id == li.productId,
          orElse: () => Product(id: '', name: '', sku: '', category: '', sellingPrice: 0, costPrice: 0, stockQty: 0)).stockQty;
        return TransferLedgerEntry(
          id: 'TL-${now.millisecondsSinceEpoch}-${li.productId}',
          date: now, referenceNo: _transferNo,
          itemId: li.productId, itemCode: li.itemCode, itemName: li.itemName,
          branchId: _fromBranchId!, branchName: _fromBranchName ?? '',
          movementType: 'Stock Transfer Out',
          batchNumber: li.batchNumber, manufacturedDate: li.mfgDate, expiryDate: li.expDate,
          beginningBalance: currentStock + li.qty,
          qtyOut: li.qty, endingBalance: currentStock,
          user: widget.currentUser, remarks: 'Transfer to ${_toBranchName ?? ""}',
        );
      }).toList();
      await StockTransferStorage.addTransfer(transfer);
      await StockTransferStorage.saveLedger(ledgerEntries);
      if (mounted) {
        _snack('Transfer $_transferNo posted!', Colors.green.shade700);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branches = Branch.allBranches.where((b) => b.isActive).toList();
    final totalQty = _lineItems.fold(0, (s, i) => s + i.qty);
    final totalCost = _lineItems.fold(0.0, (s, i) => s + (i.cost * i.qty));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Outbound Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800], foregroundColor: Colors.white,
      ),
      body: Form(key: _formKey, child: Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.all(14), child: Column(children: [
          Row(children: [
            Expanded(child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.tag, size: 18, color: Colors.blue[800]),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Transfer No.', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  Text(_transferNo.isEmpty ? 'Loading...' : _transferNo,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue[800])),
                ]),
              ]),
            )),
            const SizedBox(width: 10),
            Expanded(child: InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.calendar_today, size: 18, color: Colors.blue[800]),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Date', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    Text(_fmtDate(_transferDate), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue[800])),
                  ]),
                ]),
              ),
            )),
          ]),
          const SizedBox(height: 10),
          // STX LOCKED FROM BRANCH - device branch, read-only
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue[300]!, width: 1),
              borderRadius: BorderRadius.circular(10),
              color: Colors.blue[50],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              Icon(Icons.store, color: Colors.blue[700], size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('From Branch', style: TextStyle(fontSize: 10, color: Colors.blue[700], fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      _fromBranchName?.isNotEmpty == true ? _fromBranchName! : 'Loading...',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.lock_outline, color: Colors.blue[600], size: 18),
            ]),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _toBranchId,
            decoration: InputDecoration(labelText: 'To Branch *', prefixIcon: const Icon(Icons.store_mall_directory),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true),
            items: branches.where((b) => b.id != _fromBranchId).map((b) => DropdownMenuItem(value: b.id,
              child: Text(b.name, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) { final b = branches.firstWhere((x) => x.id == v);
              setState(() { _toBranchId = b.id; _toBranchName = b.name; }); },
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _approvedByCtrl,
              decoration: InputDecoration(labelText: 'Approved By', prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _remarksCtrl,
              decoration: InputDecoration(labelText: 'Remarks', prefixIcon: const Icon(Icons.note),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true))),
          ]),
        ])),
        Container(color: Colors.blue[800], padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            Text('${_lineItems.length} items', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 16),
            Text('Qty: $totalQty', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 16),
            Text('Cost: ${totalCost.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const Spacer(),
            ElevatedButton.icon(onPressed: _addItem,
              icon: const Icon(Icons.add, size: 16), label: const Text('Add Item', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue[800],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
          ]),
        ),
        Expanded(child: _lineItems.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 10),
              Text('No items added yet', style: TextStyle(color: Colors.grey[500])),
              const SizedBox(height: 8),
              Text('Tap "Add Item" to select products with batch', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _lineItems.length,
              itemBuilder: (_, i) {
                final item = _lineItems[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: item.isExpired ? Colors.red.withAlpha(80) : item.isNearExpiry ? Colors.orange.withAlpha(80) : Colors.blue.withAlpha(40))),
                  child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                        child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('${item.itemCode} | ${item.category}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ])),
                      InkWell(onTap: () => _editQty(i),
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.blue[700], borderRadius: BorderRadius.circular(8)),
                          child: Text('${item.qty}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
                      const SizedBox(width: 6),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => _removeItem(i), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                    ]),
                    const SizedBox(height: 8),
                    Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.isExpired ? Colors.red[50] : item.isNearExpiry ? Colors.orange[50] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        Icon(Icons.inventory_2, size: 14, color: item.isExpired ? Colors.red : Colors.teal[700]),
                        const SizedBox(width: 6),
                        Text('Batch: ${item.batchNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                        Icon(Icons.factory, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Text('MFG: ${item.mfgDateStr}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        const SizedBox(width: 10),
                        Icon(Icons.event_busy, size: 12, color: item.isExpired ? Colors.red : item.isNearExpiry ? Colors.orange : Colors.grey[500]),
                        const SizedBox(width: 3),
                        Text('EXP: ${item.expDateStr}', style: TextStyle(fontSize: 10,
                          color: item.isExpired ? Colors.red : item.isNearExpiry ? Colors.orange : Colors.grey[600],
                          fontWeight: item.isExpired || item.isNearExpiry ? FontWeight.bold : FontWeight.normal)),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text('Stock: ${item.availableStock}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(width: 12),
                      Text('Cost: ${item.cost.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const Spacer(),
                      Text('Total: ${(item.cost * item.qty).toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                    ]),
                  ])),
                );
              }),
        ),
      ])),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8, offset: const Offset(0, -2))]),
        child: SafeArea(child: SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _postTransfer,
            icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
            label: Text(_isSaving ? 'POSTING...' : 'POST TRANSFER',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
      ),
    );
  }
}

class _TransferLineItem {
  final String productId;
  final String itemCode;
  final String itemName;
  final String category;
  final String batchId;
  final String batchNumber;
  final DateTime? mfgDate;
  final DateTime? expDate;
  final int availableStock;
  final double cost;
  int qty;

  _TransferLineItem({
    required this.productId, required this.itemCode, required this.itemName,
    this.category = '', this.batchId = '', this.batchNumber = '',
    this.mfgDate, this.expDate, required this.availableStock,
    this.cost = 0, this.qty = 1,
  });

  bool get isExpired => expDate != null && expDate!.isBefore(DateTime.now());
  bool get isNearExpiry => !isExpired && expDate != null && expDate!.difference(DateTime.now()).inDays <= 30;
  String _fmtD(DateTime? d) {
    if (d == null) return 'N/A';
    return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  }
  String get mfgDateStr => _fmtD(mfgDate);
  String get expDateStr => _fmtD(expDate);

  _TransferLineItem copyWithQty(int newQty) => _TransferLineItem(
    productId: productId, itemCode: itemCode, itemName: itemName,
    category: category, batchId: batchId, batchNumber: batchNumber,
    mfgDate: mfgDate, expDate: expDate, availableStock: availableStock,
    cost: cost, qty: newQty,
  );
}

class _ItemBatchPicker extends StatefulWidget {
  final List<Product> products;
  final List<ProductBatch> batches;
  final List<_TransferLineItem> existingItems;
  const _ItemBatchPicker({required this.products, required this.batches, required this.existingItems});
  @override
  State<_ItemBatchPicker> createState() => _ItemBatchPickerState();
}

class _ItemBatchPickerState extends State<_ItemBatchPicker> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Product? _selectedProduct;

  List<Product> get _filtered => widget.products.where((p) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q) || p.barcode.toLowerCase().contains(q);
  }).toList();

  List<ProductBatch> get _productBatches {
    if (_selectedProduct == null) return [];
    return widget.batches.where((b) => b.productId == _selectedProduct!.id && b.quantity > 0 && !b.isExpired).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
      builder: (ctx, scroll) => Column(children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Icon(_selectedProduct == null ? Icons.search : Icons.inventory_2, color: Colors.blue[800]),
            const SizedBox(width: 8),
            Text(_selectedProduct == null ? 'Select Product' : 'Select Batch', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_selectedProduct != null) TextButton.icon(
              onPressed: () => setState(() => _selectedProduct = null),
              icon: const Icon(Icons.arrow_back, size: 16), label: const Text('Back')),
          ]),
        ),
        if (_selectedProduct == null) ...[
          Padding(padding: const EdgeInsets.all(12),
            child: TextField(controller: _searchCtrl, autofocus: true,
              decoration: InputDecoration(hintText: 'Search by name, SKU, barcode...', prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true, filled: true, fillColor: Colors.grey[100]),
              onChanged: (v) => setState(() => _query = v))),
          Expanded(child: ListView.builder(
            controller: scroll, padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final p = _filtered[i];
              final batchCount = widget.batches.where((b) => b.productId == p.id && b.quantity > 0).length;
              return ListTile(
                leading: CircleAvatar(backgroundColor: Colors.blue[50],
                  child: Text(p.name[0], style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold))),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text('${p.sku} | Stock: ${p.stockQty} | $batchCount batch(es)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                trailing: Icon(Icons.chevron_right, color: Colors.blue[800]),
                onTap: () => setState(() { _selectedProduct = p; }),
              );
            },
          )),
        ] else ...[
          Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.shopping_bag, color: Colors.blue[800], size: 18),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_selectedProduct!.name, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800])),
                Text('${_selectedProduct!.sku} | Stock: ${_selectedProduct!.stockQty}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ])),
            ]),
          ),
          if (_productBatches.isEmpty)
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 8),
              Text('No available batches', style: TextStyle(color: Colors.grey[500])),
              const SizedBox(height: 4),
              Text('(Expired or zero stock batches hidden)', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            ])))
          else
            Expanded(child: ListView.builder(
              controller: scroll, padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _productBatches.length,
              itemBuilder: (_, i) {
                final b = _productBatches[i];
                final alreadyAdded = widget.existingItems.any((e) => e.batchId == b.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: b.isNearExpiry ? Colors.orange.withAlpha(80) : Colors.blue.withAlpha(40))),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    leading: Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: b.isNearExpiry ? Colors.orange[50] : Colors.teal[50], borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.inventory_2, size: 20, color: b.isNearExpiry ? Colors.orange : Colors.teal[700])),
                    title: Text(b.batchNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('MFG: ${_fmtD(b.manufacturedDate)}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        const SizedBox(width: 10),
                        Text('EXP: ${_fmtD(b.expiryDate)}', style: TextStyle(fontSize: 10,
                          color: b.isNearExpiry ? Colors.orange : Colors.grey[600],
                          fontWeight: b.isNearExpiry ? FontWeight.bold : FontWeight.normal)),
                      ]),
                      Text('Available: ${b.quantity} pcs | Cost: ${b.costPrice.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    ]),
                    trailing: alreadyAdded
                      ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                          child: const Text('Added', style: TextStyle(fontSize: 10, color: Colors.grey)))
                      : Icon(Icons.add_circle, color: Colors.blue[800]),
                    onTap: alreadyAdded ? null : () {
                      Navigator.pop(context, _TransferLineItem(
                        productId: _selectedProduct!.id, itemCode: _selectedProduct!.sku,
                        itemName: _selectedProduct!.name, category: _selectedProduct!.category,
                        batchId: b.id, batchNumber: b.batchNumber,
                        mfgDate: b.manufacturedDate, expDate: b.expiryDate,
                        availableStock: b.quantity, cost: b.costPrice, qty: 1,
                      ));
                    },
                  ),
                );
              },
            )),
        ],
      ]),
    );
  }

  String _fmtD(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
}
