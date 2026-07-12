import 'package:flutter/material.dart';
import '../../services/device_assignment_service.dart';
import '../../models/batch_model.dart';
import '../../models/batch_log_model.dart';
import '../../models/product_model.dart';
import '../inventory/inventory_screen.dart';
import 'batch_log_screen.dart';

class AddBatchScreen extends StatefulWidget {
  final ProductBatch? batch;
  final String? preselectedProductId;
  final String? preselectedProductName;
  final String? preselectedProductSku;
  const AddBatchScreen({super.key, this.batch, this.preselectedProductId, this.preselectedProductName, this.preselectedProductSku});
  @override
  State<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends State<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _batchCtrl;
  late TextEditingController _lotCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _supplierCtrl;
  late TextEditingController _notesCtrl;
  DateTime? _mfgDate;
  DateTime? _expDate;
  String? _productId;
  String? _productName;
  String? _productSku;


  bool get _isEditing => widget.batch != null;

  @override
  void initState() {
    super.initState();
    final b = widget.batch;
    _batchCtrl = TextEditingController(text: b?.batchNumber ?? '');
    _lotCtrl = TextEditingController(text: b?.lotNumber ?? '');
    _qtyCtrl = TextEditingController(text: b != null ? b.quantity.toString() : '');
    _costCtrl = TextEditingController(text: b != null ? b.costPrice.toString() : '');
    _supplierCtrl = TextEditingController(text: b?.supplier ?? '');
    _notesCtrl = TextEditingController(text: b?.notes ?? '');
    _mfgDate = b?.manufacturedDate;
    _expDate = b?.expiryDate;
    _productId = b?.productId ?? widget.preselectedProductId;
    _productName = b?.productName ?? widget.preselectedProductName;
    _productSku = b?.productSku ?? widget.preselectedProductSku;
  }

  @override
  void dispose() {
    _batchCtrl.dispose(); _lotCtrl.dispose(); _qtyCtrl.dispose(); _costCtrl.dispose();
    _supplierCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final result = await Navigator.push(context,
      MaterialPageRoute(builder: (context) => const InventoryScreen(branch: 'Main Branch', isSelecting: true)));
    if (result != null && result is Product) {
      setState(() {
        _productId = result.id;
        _productName = result.name;
        _productSku = result.sku;
        if (_costCtrl.text.isEmpty) _costCtrl.text = result.costPrice.toString();
      });
    }
  }

  Future<void> _pickDate(bool isMfg) async {
    final now = DateTime.now();
    final initial = isMfg ? (_mfgDate ?? now) : (_expDate ?? now.add(const Duration(days: 365)));
    final first = isMfg ? DateTime(2020) : now.subtract(const Duration(days: 30));
    final last = isMfg ? now : DateTime(2035);
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
    if (picked != null) {
      setState(() { if (isMfg) { _mfgDate = picked; } else { _expDate = picked; } });
    }
  }

  String _fmtD(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (_productId == null) { _snack("Please select a product"); return; }
        if (_mfgDate == null) { _snack("Please select manufactured date"); return; }
        if (_expDate == null) { _snack("Please select expiry date"); return; }
        if (_expDate!.isBefore(_mfgDate!)) { _snack("Expiry must be after manufactured date"); return; }
        final qty = int.tryParse(_qtyCtrl.text) ?? 0;
        final cost = double.tryParse(_costCtrl.text) ?? 0;
        final batchNumber = _batchCtrl.text.trim();
        debugPrint('[ADD-BATCH] Save started');
        debugPrint('[ADD-BATCH] batch=$batchNumber qty=$qty cost=$cost');
        // Get current branchId from device assignment
        final assign = await DeviceAssignmentService().read();
        final branchId = (assign['branchId'] ?? '').toString();
        final branchName = (assign['branchName'] ?? '').toString();
        final lotNumber = _lotCtrl.text.trim();
        debugPrint('[ADD-BATCH] branchId=$branchId productId=$_productId lot=$lotNumber');
        
        // ═══ DUPLICATE CHECK (only for NEW batches, not edits) ═══
        if (!_isEditing) {
          final existing = await ProductBatch.findExistingBatch(
            productId: _productId!,
            batchNumber: batchNumber,
            lotNumber: lotNumber,
            branchId: branchId,
          );
          if (existing != null && mounted) {
            // Batch already exists — show dialog to add qty
            final shouldAdd = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                title: const Text('Batch Already Exists', style: TextStyle(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('This batch is already registered:',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Product: ${existing.productName}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Batch #: ${existing.batchNumber}',
                            style: const TextStyle(fontSize: 12)),
                          if (existing.lotNumber.isNotEmpty)
                            Text('Lot #: ${existing.lotNumber}',
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 6),
                          Text('Current Qty: ${existing.quantity} pcs',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                          Text('Add $qty pcs → Total: ${existing.quantity + qty} pcs',
                            style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.add),
                    label: Text('Add $qty to Existing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
            
            if (shouldAdd == true) {
              // Add qty to existing batch
              await ProductBatch.addQuantityToBatch(existing.id, qty);
              if (mounted) {
                _snack('✅ Added $qty to batch ${existing.batchNumber}');
                Navigator.pop(context, existing);
              }
              return;
            } else {
              // User cancelled
              return;
            }
          }
        }
        
        debugPrint('[ADD-BATCH] Creating ProductBatch...');
        final batch = ProductBatch(
          id: widget.batch?.id ?? "B-${DateTime.now().millisecondsSinceEpoch}",
          productId: _productId!, productName: _productName ?? "",
          productSku: _productSku ?? "", batchNumber: batchNumber,
          lotNumber: lotNumber,
          manufacturedDate: _mfgDate!, expiryDate: _expDate!,
          quantity: qty, originalQty: widget.batch?.originalQty ?? qty,
          costPrice: cost, supplier: _supplierCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          dateAdded: widget.batch?.dateAdded ?? DateTime.now(),
          branchId: branchId,
          branchName: branchName,
          source: widget.batch?.source ?? 'MANUAL',
          sourceDocId: widget.batch?.sourceDocId ?? '',
          status: 'ACTIVE',
        );
        if (_isEditing) {
          final old = widget.batch!;
          // v1.0.41 — Always show reason dialog (removed no-changes blocker)
          final reason = await _showReasonDialog([]);
          if (reason == null) return;
          final now = DateTime.now();

          // Branch by action reason
          ProductBatch finalBatch;
          if (reason == 'CHANGE QTY') {
            // Just update qty from form
            finalBatch = batch;
          } else {
            // ALREADY RETURNED / SOLD / ADJUSTED — close batch
            final statusMap = {
              'ALREADY RETURNED': 'RETURNED',
              'ALREADY SOLD': 'SOLD',
              'ALREADY ADJUSTED': 'ADJUSTED',
            };
            final newStatus = statusMap[reason] ?? 'CLOSED';
            finalBatch = ProductBatch(
              id: batch.id,
              productId: batch.productId,
              productName: batch.productName,
              productSku: batch.productSku,
              batchNumber: batch.batchNumber,
              lotNumber: batch.lotNumber,
              manufacturedDate: batch.manufacturedDate,
              expiryDate: batch.expiryDate,
              quantity: 0,
              originalQty: batch.originalQty,
              costPrice: batch.costPrice,
              supplier: batch.supplier,
              notes: '${batch.notes} | Marked as $reason on ${_fmtD(now)}'.trim(),
              dateAdded: batch.dateAdded,
              branchId: batch.branchId,
              branchName: batch.branchName,
              source: batch.source,
              sourceDocId: batch.sourceDocId,
              status: newStatus,
            );
          }

          // Log the action
          try {
            await BatchLogStorage.saveLogs([BatchLog(
              id: "LOG-${now.millisecondsSinceEpoch}",
              batchId: batch.id,
              batchNumber: batchNumber,
              productName: _productName ?? "",
              productSku: _productSku ?? "",
              action: reason == 'CHANGE QTY' ? 'Qty Changed' : 'Batch Closed',
              reason: reason,
              field: reason,
              oldValue: 'Qty: ${old.quantity}, Status: ${old.status}',
              newValue: 'Qty: ${finalBatch.quantity}, Status: ${finalBatch.status}',
              dateTime: now,
            )]);
          } catch (_) {}

          // Update in DB + Firebase
          debugPrint('[UPDATE-BATCH] Reason: $reason, newStatus: ${finalBatch.status}');
          ProductBatch.updateBatch(batch.id, finalBatch);
          debugPrint('[UPDATE-BATCH] ✅ Batch ${batch.batchNumber} updated');

          if (mounted) {
            _snack('✅ Batch updated: $reason');
            Navigator.pop(context, finalBatch);
          }
          return;
        } else {
          final now = DateTime.now();
          // ═══ CRITICAL FIX: Actually save the new batch! ═══
          debugPrint('[ADD-BATCH] Calling ProductBatch.addBatch...');
          ProductBatch.addBatch(batch);
          debugPrint('[ADD-BATCH] ✅ Saved to SQLite + Firebase queue');
          try { await BatchLogStorage.saveLogs([BatchLog(id: "LOG-${now.millisecondsSinceEpoch}", batchId: batch.id, batchNumber: batchNumber, productName: _productName ?? "", productSku: _productSku ?? "", action: "Created", reason: "New Batch", field: "New Batch", oldValue: "", newValue: "Qty: $qty, Cost: ${cost.toStringAsFixed(2)}", dateTime: now)]); } catch (_) {}
        }
        
        // v1.0.41 — Edit branch handles its own navigation above
        if (mounted) Navigator.pop(context, batch);
      } catch (e) { _snack("Save error: $e"); }
    }
  }
  Future<String?> _showReasonDialog(List<MapEntry<String, List<String>>> changes) async {
    // v1.0.41 — 4 action cards (CHANGE QTY / RETURNED / SOLD / ADJUSTED)
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.edit_note, color: Colors.teal[700], size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Update Batch #${widget.batch?.batchNumber ?? ""}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          )),
        ]),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose action:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF6B7280))),
              ),
              const SizedBox(height: 12),
              _actionCard(ctx, 'CHANGE QTY', 'Update quantity only',
                Icons.edit_note, Colors.teal),
              const SizedBox(height: 8),
              _actionCard(ctx, 'ALREADY RETURNED', 'Returned to vendor',
                Icons.assignment_return, Colors.blue),
              const SizedBox(height: 8),
              _actionCard(ctx, 'ALREADY SOLD', 'All units sold',
                Icons.point_of_sale, Colors.green),
              const SizedBox(height: 8),
              _actionCard(ctx, 'ALREADY ADJUSTED', 'Stock adjusted',
                Icons.build, Colors.purple),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(BuildContext ctx, String code, String subtitle,
      IconData icon, MaterialColor color) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, code),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.shade200, width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color.shade700, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(code, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold,
                color: color.shade900,
              )),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(
                fontSize: 12, color: color.shade700,
              )),
            ],
          )),
          Icon(Icons.chevron_right, color: color.shade400),
        ]),
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Batch' : 'Add Batch', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[700], foregroundColor: Colors.white,
        actions: [
          if (_isEditing) IconButton(icon: const Icon(Icons.history), tooltip: 'View Logs',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => BatchLogScreen(filterBatchId: widget.batch!.id, filterBatchNumber: widget.batch!.batchNumber)))),
          TextButton.icon(onPressed: _save,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sec('Product', Icons.shopping_bag),
            const SizedBox(height: 12),
            InkWell(
              onTap: _isEditing ? null : _pickProduct,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity, padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: _productId != null ? Colors.teal[300]! : Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(12),
                  color: _productId != null ? Colors.teal[50] : Colors.grey[50]),
                child: _productId != null
                  ? Row(children: [
                      Icon(Icons.check_circle, color: Colors.teal[700], size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_productName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('SKU: ${_productSku ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ])),
                      if (!_isEditing) Icon(Icons.swap_horiz, color: Colors.teal[700]),
                    ])
                  : Row(children: [
                      Icon(Icons.add_circle_outline, color: Colors.grey[500]),
                      const SizedBox(width: 10),
                      Text('Tap to select product', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    ]),
              ),
            ),
            const SizedBox(height: 24),
            _sec('Batch Information', Icons.inventory_2),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _batchCtrl,
                decoration: _dec('Batch #', Icons.tag),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
              )),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: _lotCtrl,
                decoration: _dec('Lot # (optional)', Icons.confirmation_number),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _qtyCtrl,
                decoration: _dec('Quantity', Icons.numbers),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return 'Invalid';
                  return null;
                })),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _costCtrl,
                decoration: _dec('Cost Price (P)', Icons.money),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              )),
            ]),
            const SizedBox(height: 12),
            
            // ═══ TOTAL VALUE DISPLAY (auto-calc) ═══
            AnimatedBuilder(
              animation: Listenable.merge([_qtyCtrl, _costCtrl]),
              builder: (context, _) {
                final qty = int.tryParse(_qtyCtrl.text) ?? 0;
                final cost = double.tryParse(_costCtrl.text) ?? 0.0;
                final total = qty * cost;
                final hasValue = total > 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: hasValue ? const Color(0xFFCCFBF1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasValue ? const Color(0xFF0D9488) : Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: hasValue ? const Color(0xFF0F766E) : Colors.grey[500],
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Total Value',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasValue ? const Color(0xFF0F766E) : Colors.grey[600],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '₱ ${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: hasValue ? const Color(0xFF0D9488) : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            _sec('Dates', Icons.calendar_month),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _dateField('Manufactured', _mfgDate, true)),
              const SizedBox(width: 12),
              Expanded(child: _dateField('Expiry Date', _expDate, false)),
            ]),
            if (_mfgDate != null && _expDate != null) ...[
              const SizedBox(height: 8),
              _shelfLife(),
            ],
            const SizedBox(height: 24),
            _sec('Supplier & Notes', Icons.local_shipping),
            const SizedBox(height: 12),
            TextFormField(controller: _supplierCtrl,
              decoration: _dec('Supplier (Optional)', Icons.business),
              textCapitalization: TextCapitalization.words),
            const SizedBox(height: 12),
            TextFormField(controller: _notesCtrl,
              decoration: _dec('Notes (Optional)', Icons.note), maxLines: 2),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 50,
              child: ElevatedButton.icon(onPressed: _save,
                icon: Icon(_isEditing ? Icons.save : Icons.add),
                label: Text(_isEditing ? 'UPDATE BATCH' : 'ADD BATCH',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),

          ]),
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime? date, bool isMfg) {
    final has = date != null;
    return InkWell(
      onTap: () => _pickDate(isMfg),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: has ? Colors.teal[300]! : Colors.grey[400]!),
          borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(isMfg ? Icons.factory : Icons.event_busy, size: 18, color: has ? Colors.teal[700] : Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            Text(_fmtD(date), style: TextStyle(fontSize: 13, fontWeight: has ? FontWeight.w600 : FontWeight.normal,
              color: has ? Colors.black87 : Colors.grey[500])),
          ])),
        ]),
      ),
    );
  }

  Widget _shelfLife() {
    final days = _expDate!.difference(_mfgDate!).inDays;
    final rem = _expDate!.difference(DateTime.now()).inDays;
    final exp = rem < 0;
    final c = exp ? Colors.red : rem <= 30 ? Colors.orange : Colors.green;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.withAlpha(20), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(exp ? Icons.error : rem <= 30 ? Icons.warning : Icons.check_circle, size: 18, color: c),
        const SizedBox(width: 8),
        Text('Shelf Life: $days days', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(exp ? 'EXPIRED' : '$rem days left', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c)),
      ]),
    );
  }

  Widget _sec(String t, IconData i) => Row(children: [
    Icon(i, size: 20, color: Colors.teal[700]), const SizedBox(width: 8),
    Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal[800])),
  ]);

  InputDecoration _dec(String l, IconData i) => InputDecoration(
    labelText: l, prefixIcon: Icon(i),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));
}
