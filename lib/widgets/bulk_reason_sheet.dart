import 'package:flutter/material.dart';
import '../models/batch_model.dart';

/// v1.0.40 — Bulk Reason Update Sheet
/// Shows a modal with reason radio buttons for updating multiple batches at once
class BulkReasonSheet extends StatefulWidget {
  final List<ProductBatch> batches;
  const BulkReasonSheet({super.key, required this.batches});

  @override
  State<BulkReasonSheet> createState() => _BulkReasonSheetState();
}

class _BulkReasonSheetState extends State<BulkReasonSheet> {
  String? _selectedReason;
  final _qtyController = TextEditingController();
  final _noteController = TextEditingController();

  static const _teal = Color(0xFF0D9488);
  static const _tealDark = Color(0xFF0F766E);

  static const List<Map<String, dynamic>> _reasons = [
    {'code': 'SOLD', 'label': 'SOLD', 'icon': Icons.point_of_sale, 'color': Colors.green},
    {'code': 'RETURN_VENDOR', 'label': 'RETURN TO VENDOR', 'icon': Icons.assignment_return, 'color': Colors.blue},
    {'code': 'DAMAGE', 'label': 'DAMAGE', 'icon': Icons.broken_image, 'color': Colors.red},
    {'code': 'CHARGED_EMPLOYEE', 'label': 'CHARGED TO EMPLOYEE', 'icon': Icons.person, 'color': Colors.orange},
    {'code': 'EXPIRED', 'label': 'EXPIRED', 'icon': Icons.event_busy, 'color': Colors.deepOrange},
    {'code': 'CORRECTION', 'label': 'CORRECTION', 'icon': Icons.build, 'color': Colors.purple},
    {'code': 'OTHER', 'label': 'OTHER', 'icon': Icons.more_horiz, 'color': Colors.grey},
  ];

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: const [
                Icon(Icons.edit_note, color: _teal),
                SizedBox(width: 8),
                Text(
                  'Reason for Update',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Batch summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Changes (${widget.batches.length}):',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  ...widget.batches.take(3).map((b) => Text(
                    '▶ ${b.productName} (Batch #${b.batchNumber})',
                    style: const TextStyle(fontSize: 12),
                  )),
                  if (widget.batches.length > 3)
                    Text(
                      '... and ${widget.batches.length - 3} more',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Qty change input
            const Text(
              'Qty Change (optional):',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g., -5 (deduct) or +10 (add)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),

            // Reason radio list
            const Text(
              'Select Reason:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._reasons.map((r) => RadioListTile<String>(
              value: r['code'] as String,
              groupValue: _selectedReason,
              onChanged: (v) => setState(() => _selectedReason = v),
              title: Row(
                children: [
                  Icon(r['icon'] as IconData, color: r['color'] as Color, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    r['label'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              activeColor: _teal,
              contentPadding: EdgeInsets.zero,
              dense: true,
            )),

            // Note field (only when OTHER selected)
            if (_selectedReason == 'OTHER') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Specify reason',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Buttons
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _selectedReason == null ? null : () {
                    final qty = int.tryParse(_qtyController.text);
                    Navigator.pop(context, {
                      'reason': _selectedReason,
                      'qtyChange': qty,
                      'note': _noteController.text.trim().isEmpty
                        ? null : _noteController.text.trim(),
                    });
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm Update'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tealDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
