// lib/widgets/transfer_batch_picker.dart
// v1.0.48 — Batch Picker for Stock Transfer
import 'package:flutter/material.dart';
import '../models/batch_model.dart';

class TransferBatchPick {
  final String batchId;
  final String batchNumber;
  final String lotNumber;
  final DateTime mfgDate;
  final DateTime expiryDate;
  final int availableQty;
  final int transferQty;
  final double unitCost;

  TransferBatchPick({
    required this.batchId,
    required this.batchNumber,
    required this.lotNumber,
    required this.mfgDate,
    required this.expiryDate,
    required this.availableQty,
    required this.transferQty,
    required this.unitCost,
  });

  Map<String, dynamic> toMap() => {
    'batchId': batchId,
    'batchNumber': batchNumber,
    'lotNumber': lotNumber,
    'mfgDate': mfgDate.toIso8601String(),
    'expiryDate': expiryDate.toIso8601String(),
    'availableQty': availableQty,
    'transferQty': transferQty,
    'unitCost': unitCost,
  };

  factory TransferBatchPick.fromMap(Map<String, dynamic> m) => TransferBatchPick(
    batchId: m['batchId'] ?? '',
    batchNumber: m['batchNumber'] ?? '',
    lotNumber: m['lotNumber'] ?? '',
    mfgDate: DateTime.tryParse(m['mfgDate'] ?? '') ?? DateTime.now(),
    expiryDate: DateTime.tryParse(m['expiryDate'] ?? '') ?? DateTime.now(),
    availableQty: (m['availableQty'] as num?)?.toInt() ?? 0,
    transferQty: (m['transferQty'] as num?)?.toInt() ?? 0,
    unitCost: (m['unitCost'] as num?)?.toDouble() ?? 0.0,
  );
}

class TransferBatchPickerDialog extends StatefulWidget {
  final String productName;
  final String productSku;
  final List<ProductBatch> availableBatches;
  final List<TransferBatchPick> initialSelections;

  const TransferBatchPickerDialog({
    super.key,
    required this.productName,
    required this.productSku,
    required this.availableBatches,
    this.initialSelections = const [],
  });

  @override
  State<TransferBatchPickerDialog> createState() => _TransferBatchPickerDialogState();
}

class _TransferBatchPickerDialogState extends State<TransferBatchPickerDialog> {
  static const _purple = Color(0xFF8B5CF6);
  static const _orange = Color(0xFFF59E0B);
  static const _green = Color(0xFF22C55E);

  late List<ProductBatch> _batches;
  late Map<String, TextEditingController> _controllers;
  late Map<String, int> _qtyMap;

  @override
  void initState() {
    super.initState();
    _batches = List.from(widget.availableBatches)
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    _controllers = {};
    _qtyMap = {};
    for (final b in _batches) {
      final existing = widget.initialSelections.where((s) => s.batchId == b.id).toList();
      final initQty = existing.isNotEmpty ? existing.first.transferQty : 0;
      _qtyMap[b.id] = initQty;
      _controllers[b.id] = TextEditingController(text: initQty > 0 ? initQty.toString() : '');
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  int get _totalSelected => _qtyMap.values.fold(0, (sum, q) => sum + q);
  int get _totalAvailable => _batches.fold(0, (sum, b) => sum + b.quantity);

  void _clearAll() {
    setState(() {
      for (final id in _qtyMap.keys) {
        _qtyMap[id] = 0;
        _controllers[id]!.text = '';
      }
    });
  }

  void _confirm() {
    final selections = <TransferBatchPick>[];
    for (final b in _batches) {
      final qty = _qtyMap[b.id] ?? 0;
      if (qty > 0) {
        selections.add(TransferBatchPick(
          batchId: b.id, batchNumber: b.batchNumber, lotNumber: b.lotNumber,
          mfgDate: b.manufacturedDate, expiryDate: b.expiryDate,
          availableQty: b.quantity, transferQty: qty, unitCost: b.costPrice,
        ));
      }
    }
    Navigator.pop(context, selections);
  }

  @override
  Widget build(BuildContext context) {
    final activeBatches = _batches.where((b) =>
      b.status == 'ACTIVE' && b.quantity > 0 && !b.isExpired).toList();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600, maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: _purple, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(children: [
                const Icon(Icons.inventory_2, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Select Batches', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('${widget.productName} (${widget.productSku})', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                Text('$_totalAvailable pcs', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            Padding(padding: const EdgeInsets.all(12), child: Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _clearAll,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear All'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700, padding: const EdgeInsets.symmetric(vertical: 10)),
              )),
            ])),
            Expanded(child: activeBatches.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No available batches', style: TextStyle(color: Colors.grey, fontSize: 13))))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: activeBatches.length,
                  itemBuilder: (context, i) {
                    final b = activeBatches[i];
                    final isFEFO = i == 0;
                    final ctrl = _controllers[b.id]!;
                    final qty = _qtyMap[b.id] ?? 0;
                    final isSelected = qty > 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? _purple.withValues(alpha: 0.05) : Colors.white,
                        border: Border.all(color: isSelected ? _purple : (isFEFO ? _orange.withValues(alpha: 0.4) : Colors.grey.shade300), width: isSelected ? 1.5 : 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.qr_code_2, size: 16, color: isSelected ? _purple : Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Expanded(child: Text(
                            'Batch #${b.batchNumber}${b.lotNumber.isNotEmpty ? " \u00B7 Lot #${b.lotNumber}" : ""}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          )),
                          if (isFEFO) Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(4)),
                            child: const Text('FEFO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.calendar_today, size: 10, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('MFG: ${_fmt(b.manufacturedDate)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                          const SizedBox(width: 12),
                          Icon(Icons.event_busy, size: 10, color: b.isNearExpiry ? _orange : Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('EXP: ${_fmt(b.expiryDate)}',
                            style: TextStyle(fontSize: 10, color: b.isNearExpiry ? _orange : Colors.grey.shade700, fontWeight: b.isNearExpiry ? FontWeight.bold : FontWeight.normal)),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: Text('Available: ${b.quantity} pcs', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _green))),
                          SizedBox(width: 100, child: TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: '0', isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              labelText: 'Qty', labelStyle: const TextStyle(fontSize: 10),
                            ),
                            onChanged: (v) {
                              final parsed = int.tryParse(v) ?? 0;
                              setState(() {
                                _qtyMap[b.id] = parsed.clamp(0, b.quantity);
                                if (parsed > b.quantity) {
                                  ctrl.text = b.quantity.toString();
                                  ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
                                }
                              });
                            },
                          )),
                        ]),
                      ]),
                    );
                  },
                )),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(top: BorderSide(color: Colors.grey.shade200)), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Total Selected:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text('$_totalSelected pcs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _totalSelected > 0 ? _purple : Colors.grey)),
                ])),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _totalSelected > 0 ? _confirm : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm'),
                  style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
}
