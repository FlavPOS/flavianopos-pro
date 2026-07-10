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

  static const List<String> _reasons = [
    'SOLD', 'RETURN TO VENDOR', 'DAMAGE',
    'CHARGED TO EMPLOYEE', 'EXPIRED', 'CORRECTION', 'OTHER',
  ];

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

  void _genBatch() {
    final now = DateTime.now();
    final n = 'LOT-${now.year}-${now.millisecondsSinceEpoch.toString().substring(7)}';
    setState(() => _batchCtrl.text = n);
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
        // Get current branchId from device assignment
        final assign = await DeviceAssignmentService().read();
        final branchId = (assign['branchId'] ?? '').toString();
        final branchName = (assign['branchName'] ?? '').toString();
        final lotNumber = _lotCtrl.text.trim();
        
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
          final changes = <MapEntry<String, List<String>>>[];
          void check(String field, String oldVal, String newVal) { if (oldVal != newVal) changes.add(MapEntry(field, [oldVal, newVal])); }
          check("Batch #", old.batchNumber, batchNumber);
          check("Quantity", old.quantity.toString(), qty.toString());
          check("Cost Price", old.costPrice.toStringAsFixed(2), cost.toStringAsFixed(2));
          check("Mfg Date", _fmtD(old.manufacturedDate), _fmtD(_mfgDate));
          check("Expiry Date", _fmtD(old.expiryDate), _fmtD(_expDate));
          check("Supplier", old.supplier, _supplierCtrl.text.trim());
          check("Notes", old.notes, _notesCtrl.text.trim());
          if (changes.isEmpty) { _snack("No changes detected"); return; }
          final reason = await _showReasonDialog(changes);
          if (reason == null) return;
          final now = DateTime.now();
          final logs = <BatchLog>[];
          for (var i = 0; i < changes.length; i++) {
            final c = changes[i];
            logs.add(BatchLog(id: "LOG-${now.millisecondsSinceEpoch}-$i", batchId: batch.id, batchNumber: batchNumber, productName: _productName ?? "", productSku: _productSku ?? "", action: "Updated", reason: reason, field: c.key, oldValue: c.value[0], newValue: c.value[1], dateTime: now));
          }
          try { await BatchLogStorage.saveLogs(logs); } catch (_) {}
        } else {
          final now = DateTime.now();
          try { await BatchLogStorage.saveLogs([BatchLog(id: "LOG-${now.millisecondsSinceEpoch}", batchId: batch.id, batchNumber: batchNumber, productName: _productName ?? "", productSku: _productSku ?? "", action: "Created", reason: "New Batch", field: "New Batch", oldValue: "", newValue: "Qty: $qty, Cost: ${cost.toStringAsFixed(2)}", dateTime: now)]); } catch (_) {}
        }
        if (mounted) Navigator.pop(context, batch);
      } catch (e) { _snack("Save error: $e"); }
    }
  }
  Future<String?> _showReasonDialog(List<MapEntry<String, List<String>>> changes) async {
    String selectedReason = _reasons[0];
    final customCtrl = TextEditingController();
    bool isOther = false;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.edit_note, color: Colors.teal[700], size: 28),
            const SizedBox(width: 10),
            const Expanded(child: Text('Reason for Update', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ]),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Changes (${changes.length}):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                const SizedBox(height: 4),
                ...changes.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Icon(Icons.arrow_right, size: 16, color: Colors.blue[600]),
                    Text('${c.key}: ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    Flexible(child: Text('${c.value[0]} \u2192 ${c.value[1]}', style: TextStyle(fontSize: 11, color: Colors.grey[700]))),
                  ]),
                )),
              ]),
            ),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Select Reason:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            const SizedBox(height: 8),
            ...(_reasons.map((r) => RadioListTile<String>(
              value: r, groupValue: selectedReason, dense: true, visualDensity: VisualDensity.compact,
              activeColor: Colors.teal[700],
              title: Text(r, style: const TextStyle(fontSize: 13)),
              onChanged: (v) => setDlgState(() { selectedReason = v!; isOther = v == 'OTHER'; }),
            ))),
            if (isOther) ...[
              const SizedBox(height: 8),
              TextField(
                controller: customCtrl, autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter custom reason...', isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Confirm Update'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                final reason = isOther ? (customCtrl.text.trim().isEmpty ? 'OTHER' : customCtrl.text.trim().toUpperCase()) : selectedReason;
                Navigator.pop(ctx, reason);
              },
            ),
          ],
        ),
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
              const SizedBox(width: 8),
              ElevatedButton.icon(onPressed: _genBatch,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Auto', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _qtyCtrl,
                decoration: _dec('Quantity', Icons.numbers),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return 'Invalid';
                  return null;
                })),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _costCtrl,
                decoration: _dec('Cost Price (P)', Icons.money),
                keyboardType: TextInputType.number)),
            ]),
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
            if (_isEditing) ...[
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 44,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('VIEW UPDATE LOGS', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.teal[700],
                    side: BorderSide(color: Colors.teal[700]!, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BatchLogScreen(filterBatchId: widget.batch!.id, filterBatchNumber: widget.batch!.batchNumber))))),
            ],
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
