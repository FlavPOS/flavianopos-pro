import 'package:flutter/material.dart';
import 'adjustment_reason_v3_model.dart';

/// Settings screen for managing custom reason codes.
/// Add/edit/delete reasons with live direction preview.
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

  // ─── Add/Edit Dialog ───────────────────────────────────
  Future<void> _addOrEdit({AdjustmentReasonV3? existing}) async {
    final codeCtrl = TextEditingController(text: existing?.reasonCode ?? '');
    final nameCtrl = TextEditingController(text: existing?.reasonName ?? '');
    int previewDirection = existing?.direction ?? -1;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setD) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  existing == null
                      ? Icons.add_circle_rounded
                      : Icons.edit_rounded,
                  color: _purple,
                ),
                const SizedBox(width: 8),
                Text(existing == null ? 'Add Reason' : 'Edit Reason'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: codeCtrl,
                    enabled: existing == null,
                    decoration: InputDecoration(
                      labelText: 'Reason Code',
                      hintText: 'e.g. 1, 2, 3',
                      prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
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
                      labelText: 'Reason Name',
                      hintText: 'e.g. Cycle Count (-)',
                      helperText: 'Use (-) for negative, (+) for positive',
                      helperMaxLines: 2,
                      prefixIcon: const Icon(Icons.label_rounded, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (previewDirection < 0 ? _red : _green)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: previewDirection < 0 ? _red : _green,
                          width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          previewDirection < 0
                              ? Icons.remove_circle_rounded
                              : Icons.add_circle_rounded,
                          color: previewDirection < 0 ? _red : _green,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                previewDirection < 0
                                    ? 'Negative Adjustment'
                                    : 'Positive Adjustment',
                                style: TextStyle(
                                  color: previewDirection < 0 ? _red : _green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                previewDirection < 0
                                    ? 'Will deduct from stock'
                                    : 'Will add to stock',
                                style: TextStyle(
                                  color: previewDirection < 0 ? _red : _green,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                  // Check duplicate code (only for new reasons)
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
                    iconName: existing?.iconName ?? 'warning_amber_rounded',
                    isActive: existing?.isActive ?? true,
                    sortOrder: existing?.sortOrder ?? (_reasons.length + 1),
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

  // ─── Delete Confirmation ───────────────────────────────
  Future<void> _delete(AdjustmentReasonV3 r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _red),
            SizedBox(width: 8),
            Text('Delete Reason?'),
          ],
        ),
        content: Text(
          'Remove "\${r.reasonName}"?',
          style: const TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
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

  // ─── Toggle Active ─────────────────────────────────────
  Future<void> _toggleActive(AdjustmentReasonV3 r) async {
    final now = DateTime.now().toIso8601String();
    await AdjustmentReasonV3Dao.update(AdjustmentReasonV3(
      reasonCode: r.reasonCode,
      reasonName: r.reasonName,
      direction: r.direction,
      iconName: r.iconName,
      isActive: !r.isActive,
      sortOrder: r.sortOrder,
      createdAt: r.createdAt,
      updatedAt: now,
    ));
    _load();
  }

  // ─── BUILD ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, size: 20),
            SizedBox(width: 8),
            Text(
              'Reason Codes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Reason',
            onPressed: () => _addOrEdit(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reasons.isEmpty
              ? _buildEmpty()
              : _buildList(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tune_rounded, size: 64, color: _purple),
          ),
          const SizedBox(height: 16),
          const Text(
            'No reasons yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap + to add your first reason',
            style: TextStyle(fontSize: 14, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // Group by direction
    final negatives = _reasons.where((r) => r.isNegative).toList();
    final positives = _reasons.where((r) => r.isPositive).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (negatives.isNotEmpty) ...[
          _buildSectionHeader('NEGATIVE — DEDUCTS STOCK', _red,
              Icons.remove_circle_rounded),
          const SizedBox(height: 6),
          ...negatives.map(_buildTile),
          const SizedBox(height: 16),
        ],
        if (positives.isNotEmpty) ...[
          _buildSectionHeader('POSITIVE — ADDS STOCK', _green,
              Icons.add_circle_rounded),
          const SizedBox(height: 6),
          ...positives.map(_buildTile),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSectionHeader(String label, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(AdjustmentReasonV3 r) {
    final activeOpacity = r.isActive ? 1.0 : 0.5;
    return Opacity(
      opacity: activeOpacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider),
        ),
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: r.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(r.icon, color: r.color, size: 22),
          ),
          title: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: r.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.reasonCode,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: r.color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.reasonName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: _textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  r.isNegative
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 12,
                  color: r.color,
                ),
                const SizedBox(width: 4),
                Text(
                  r.isNegative ? 'Deducts stock' : 'Adds stock',
                  style: TextStyle(
                    color: r.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!r.isActive) ...[
                  const SizedBox(width: 8),
                  const Text('(inactive)',
                      style: TextStyle(
                          fontSize: 11,
                          color: _textSecondary,
                          fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: _textSecondary),
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  _addOrEdit(existing: r);
                  break;
                case 'toggle':
                  _toggleActive(r);
                  break;
                case 'delete':
                  _delete(r);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 18, color: _purple),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(
                      r.isActive
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                      color: _textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(r.isActive ? 'Deactivate' : 'Activate'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, size: 18, color: _red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: _red)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
