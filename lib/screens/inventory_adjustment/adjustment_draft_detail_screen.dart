import 'package:flutter/material.dart';
import 'adjustment_v3_model.dart';
import 'adjustment_prepared_screen.dart';

/// Draft Detail — full screen view of a single draft with actions.
class AdjustmentDraftDetailScreen extends StatefulWidget {
  final String draftId;
  final String branch;
  final String userName;

  const AdjustmentDraftDetailScreen({
    super.key,
    required this.draftId,
    required this.branch,
    required this.userName,
  });

  @override
  State<AdjustmentDraftDetailScreen> createState() =>
      _AdjustmentDraftDetailScreenState();
}

class _AdjustmentDraftDetailScreenState
    extends State<AdjustmentDraftDetailScreen> {
  static const _purple = Color(0xFF8B5CF6);
  static const _red = Color(0xFFEF4444);
  static const _green = Color(0xFF22C55E);
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);
  static const _divider = Color(0xFFE5E7EB);

  AdjustmentV3? _draft;
  List<AdjustmentV3Item> _items = [];
  bool _loading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await AdjustmentV3Dao.getById(widget.draftId);
    final it = await AdjustmentV3Dao.getItems(widget.draftId);
    if (!mounted) return;
    setState(() {
      _draft = d;
      _items = it;
      _loading = false;
    });
  }

  String _thousands(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '${buf.toString()}.${parts[1]}';
  }

  List<AdjustmentV3Item> get _filtered {
    if (_searchQuery.isEmpty) return _items;
    final q = _searchQuery.toLowerCase();
    return _items.where((i) =>
      i.productName.toLowerCase().contains(q) ||
      i.sku.toLowerCase().contains(q)
    ).toList();
  }

  int get _totalQty => _items.fold(0, (s, i) => s + i.qty);
  double get _totalCost =>
      _items.fold(0.0, (s, i) => s + (i.qty * i.unitCost * i.direction));

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? _purple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Back to Prepared (edit mode) ───────────────────────
  Future<void> _backToPrepared() async {
    // Navigate to Prepared with draftId — it will preload the items
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AdjustmentPreparedScreen(
          branch: widget.branch,
          userName: widget.userName,
          draftId: widget.draftId,
        ),
      ),
    );
  }

  // ─── Submit Draft → SUBMITTED status ────────────────────
  Future<void> _submitDraft() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.send_rounded, color: _purple),
            SizedBox(width: 8),
            Text('Submit for Approval?'),
          ],
        ),
        content: const Text(
          'Once submitted, this draft can no longer be edited. It will require manager approval to apply changes to inventory.',
          style: TextStyle(fontSize: 13, color: _textSecondary),
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await AdjustmentV3Dao.updateStatus(
        adjustmentId: widget.draftId,
        newStatus: AdjustmentStatus.submitted,
      );
      if (!mounted) return;
      _showSnack('Draft submitted for approval', color: _green);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Submit failed: SUBMITERR', color: _red);
    }
  }

  // ─── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Draft',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            if (_draft != null)
              Text(
                _draft!.docNumber.isEmpty ? _draft!.adjustmentId : _draft!.docNumber,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: _items.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
                ),
              ],
            ),
      bottomNavigationBar: _items.isEmpty ? null : _buildBottomBar(),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (q) => setState(() => _searchQuery = q),
          decoration: const InputDecoration(
            hintText: 'Search SKU or Product',
            hintStyle: TextStyle(color: _textSecondary),
            prefixIcon: Icon(Icons.search_rounded,
                color: _textSecondary, size: 22),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
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
            child: const Icon(Icons.description_rounded,
                size: 64, color: _purple),
          ),
          const SizedBox(height: 12),
          const Text('Empty draft',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
        ],
      ),
    );
  }

  Widget _buildList() {
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return const Center(
        child: Text('No matching items',
            style: TextStyle(color: _textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return _buildItemCard(filtered[index]);
      },
    );
  }

  Widget _buildItemCard(AdjustmentV3Item item) {
    final color = item.direction < 0 ? _red : _green;
    final sign = item.direction < 0 ? '-' : '+';
    final cost = item.qty * item.unitCost * item.direction;
    final costSign = cost < 0 ? '-' : (cost > 0 ? '+' : '');
    final costStr = _thousands(cost.abs());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Qty badge (leading)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$sign${item.qty}',
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              // SKU + Name
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                        color: _textPrimary, fontSize: 14),
                    children: [
                      TextSpan(
                        text: '${item.sku} ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _purple,
                        ),
                      ),
                      TextSpan(
                        text: item.productName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Reason (code + name)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _divider),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    item.reasonCode,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary),
                  ),
                ),
                Expanded(
                  child: Text(
                    item.reasonName,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Cost Impact
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cost Impact',
                style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500),
              ),
              Text(
                '$costSign$costStr',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSummaryStrip(),
        Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: const BoxDecoration(color: _card),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _backToPrepared,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Prepared'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _purple,
                    side: const BorderSide(color: _purple, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _submitDraft,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Submit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStrip() {
    final total = _totalCost;
    final costColor = total == 0
        ? _textPrimary
        : (total < 0 ? _red : _green);
    final sign = total >= 0 ? '+' : '-';
    final costLabel = total == 0 ? '0.00' : '$sign${_thousands(total.abs())}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(
            icon: Icons.shopping_bag_outlined,
            label: 'Items',
            value: '${_items.length}',
            color: _textPrimary,
          ),
          Container(width: 1, height: 30, color: _divider),
          _buildStat(
            icon: Icons.add_rounded,
            label: 'Qty',
            value: '$_totalQty pcs',
            color: _textPrimary,
          ),
          Container(width: 1, height: 30, color: _divider),
          _buildStat(
            icon: Icons.sell_outlined,
            label: 'Cost',
            value: costLabel,
            color: costColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _purple),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
