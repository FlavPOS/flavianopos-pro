import 'package:flutter/material.dart';
import 'adjustment_reason_v3_model.dart';

/// Simple minimal settings for reason codes.
class AdjustmentReasonSettingsV3 extends StatefulWidget {
  const AdjustmentReasonSettingsV3({super.key});

  @override
  State<AdjustmentReasonSettingsV3> createState() =>
      _AdjustmentReasonSettingsV3State();
}

class _AdjustmentReasonSettingsV3State
    extends State<AdjustmentReasonSettingsV3> {
  static const _purple = Color(0xFF6A3AF5);
  static const _red = Color(0xFFEF4444);
  static const _green = Color(0xFF22C55E);
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);
  static const _divider = Color(0xFFE5E7EB);

  List<AdjustmentReasonV3> _reasons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AdjustmentReasonV3Dao.seedDefaults();
    final list = await AdjustmentReasonV3Dao.getAll(activeOnly: false);
    if (!mounted) return;
    setState(() {
      _reasons = list;
      _loading = false;
    });
  }

  // Auto-generate next 2-digit code
  String _nextCode() {
    final codes = _reasons
        .map((r) => int.tryParse(r.reasonCode) ?? 0)
        .toList();
    codes.sort();
    final next = codes.isEmpty ? 1 : codes.last + 1;
    return next.toString().padLeft(2, '0');
  }

  Future<void> _addOrEdit({AdjustmentReasonV3? existing}) async {
    final codeCtrl = TextEditingController(
        text: existing?.reasonCode ?? _nextCode());
    final nameCtrl = TextEditingController(text: existing?.reasonName ?? '');
    int previewDirection = existing?.direction ?? -1;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setD) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            title: Text(existing == null ? 'Add Reason' : 'Edit Reason'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: codeCtrl,
                    enabled: existing == null,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Code',
                      hintText: 'e.g. 01, 02, 10',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    onChanged: (v) => setD(() {
                      previewDirection =
                          AdjustmentReasonV3.detectDirection(v);
                    }),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Cycle Count (-)',
                      helperText: 'Include (-) or (+) at the end',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: (previewDirection < 0 ? _red : _green)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      previewDirection < 0
                          ? 'This will DEDUCT stock'
                          : 'This will ADD stock',
                      style: TextStyle(
                        color: previewDirection < 0 ? _red : _green,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final code = codeCtrl.text.trim();
                  final name = nameCtrl.text.trim();
                  if (code.isEmpty || name.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Code and Name are required'),
                        backgroundColor: _red,
                      ),
                    );
                    return;
                  }
                  if (existing == null &&
                      _reasons.any((r) => r.reasonCode == code)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Code already exists'),
                        backgroundColor: _red,
                      ),
                    );
                    return;
                  }
                  final now = DateTime.now().toIso8601String();
                  final reason = AdjustmentReasonV3(
                    reasonCode: code,
                    reasonName: name,
                    direction: AdjustmentReasonV3.detectDirection(name),
                    iconName: '',
                    isActive: existing?.isActive ?? true,
                    sortOrder: int.tryParse(code) ?? _reasons.length + 1,
                    createdAt: existing?.createdAt ?? now,
                    updatedAt: now,
                  );
                  if (existing == null) {
                    await AdjustmentReasonV3Dao.insert(reason);
                  } else {
                    await AdjustmentReasonV3Dao.update(reason);
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, true);
                },
                child: Text(existing == null ? 'Add' : 'Save'),
              ),
            ],
          );
        });
      },
    );
    if (saved == true) _load();
  }

  Future<void> _delete(AdjustmentReasonV3 r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete?'),
        content: Text('Remove "${r.reasonName}"?',
            style: const TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AdjustmentReasonV3Dao.delete(r.reasonCode);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Reason Codes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add',
            onPressed: () => _addOrEdit(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reasons.isEmpty
              ? const Center(
                  child: Text('No reasons — tap + to add',
                      style: TextStyle(color: _textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _reasons.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: _divider,
                  ),
                  itemBuilder: (context, index) {
                    final r = _reasons[index];
                    return _buildTile(r);
                  },
                ),
    );
  }

  Widget _buildTile(AdjustmentReasonV3 r) {
    final color = r.isNegative ? _red : _green;
    return Material(
      color: _card,
      child: InkWell(
        onLongPress: () => _showActions(r),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Code
              SizedBox(
                width: 30,
                child: Text(
                  r.reasonCode,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // Name (with color for the (-) or (+) part in tint)
              Expanded(
                child: Text(
                  r.reasonName,
                  style: TextStyle(
                    fontSize: 14,
                    color: r.isActive ? color : _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Menu button
              InkWell(
                onTap: () => _showActions(r),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.more_vert_rounded,
                      size: 18, color: _textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(AdjustmentReasonV3 r) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '${r.reasonCode} ${r.reasonName}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: _purple),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _addOrEdit(existing: r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: _red),
              title: const Text('Delete',
                  style: TextStyle(color: _red)),
              onTap: () {
                Navigator.pop(ctx);
                _delete(r);
              },
            ),
          ],
        ),
      ),
    );
  }
}
