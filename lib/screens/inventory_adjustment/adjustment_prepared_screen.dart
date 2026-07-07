import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../inventory/inventory_screen.dart';
import 'adjustment_reason_v3_model.dart';
import 'adjustment_v3_model.dart';

/// Prepared Adjustment — create/edit list of adjustments before submission.
class AdjustmentPreparedScreen extends StatefulWidget {
  final String branch;
  final String userName;
  final String? draftId;

  const AdjustmentPreparedScreen({
    super.key,
    required this.branch,
    required this.userName,
    this.draftId,
  });

  @override
  State<AdjustmentPreparedScreen> createState() =>
      _AdjustmentPreparedScreenState();
}

class _AdjustmentPreparedScreenState extends State<AdjustmentPreparedScreen> {
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);
  static const _green = Color(0xFF22C55E);
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);
  static const _divider = Color(0xFFE5E7EB);

  final TextEditingController _searchCtrl = TextEditingController();
  final List<_AdjItem> _items = [];
  String _searchQuery = '';
  String? _existingDraftId;

  // Reasons loaded from DB
  List<AdjustmentReasonV3> _dbReasons = [];
  bool _loadingReasons = true;

  @override
  void initState() {
    super.initState();
    _loadReasons();
  }

  Future<void> _loadReasons() async {
    await AdjustmentReasonV3Dao.seedDefaults();
    final list = await AdjustmentReasonV3Dao.getAll(activeOnly: true);
    if (!mounted) return;
    setState(() {
      _dbReasons = list;
      _loadingReasons = false;
    });
    if (widget.draftId != null) {
      await _loadDraft(widget.draftId!);
    }
  }

  Future<void> _loadDraft(String draftId) async {
    final draft = await AdjustmentV3Dao.getById(draftId);
    if (draft == null) return;
    final draftItems = await AdjustmentV3Dao.getItems(draftId);
    if (!mounted) return;

    final loaded = <_AdjItem>[];
    for (final di in draftItems) {
      Product? prod;
      try {
        prod = Product.allProducts.firstWhere((p) => p.id == di.productId);
      } catch (_) {
        prod = Product(
          id: di.productId,
          sku: di.sku,
          name: di.productName,
          category: di.category,
          costPrice: di.unitCost,
          sellingPrice: 0,
          stockQty: 0,
        );
      }
      final reason = _dbReasons.firstWhere(
        (r) => r.reasonCode == di.reasonCode,
        orElse: () => _dbReasons.isNotEmpty
            ? _dbReasons.first
            : AdjustmentReasonV3(
                reasonCode: di.reasonCode,
                reasonName: di.reasonName,
                direction: di.direction,
                createdAt: '',
                updatedAt: '',
              ),
      );
      loaded.add(_AdjItem(
        product: prod,
        qtyCtrl: TextEditingController(text: di.qty.toString()),
        qty: di.qty,
      )..reason = reason);
    }

    setState(() {
      _existingDraftId = draftId;
      _items.addAll(loaded);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final item in _items) {
      item.qtyCtrl.dispose();
    }
    super.dispose();
  }

  // ─── Filtered items ─────────────────────────────────────
  List<_AdjItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    final q = _searchQuery.toLowerCase();
    return _items.where((i) =>
      i.product.name.toLowerCase().contains(q) ||
      i.product.sku.toLowerCase().contains(q)
    ).toList();
  }

  // ─── Actions ────────────────────────────────────────────
  Future<void> _addProduct() async {
    final product = await Navigator.push<Product>(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryScreen(
          branch: widget.branch,
          isSelecting: true,
        ),
      ),
    );
    if (product == null || !mounted) return;

    if (_items.any((i) => i.product.id == product.id)) {
      _showSnack('${product.name} already added', color: _amber);
      return;
    }

    setState(() {
      _items.add(_AdjItem(
        product: product,
        qtyCtrl: TextEditingController(text: '1'),
        qty: 1,
      ));
    });
  }

  void _removeItem(_AdjItem item) {
    setState(() {
      _items.remove(item);
    });
    item.qtyCtrl.dispose();
  }

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? _amber,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveDraft() async {
    if (_items.isEmpty) {
      _showSnack('Add at least one item', color: _red);
      return;
    }
    try {
      final adjustmentId = _existingDraftId ??
          AdjustmentV3Dao.generateId(branchCode: widget.branch);
      final now = DateTime.now().toIso8601String();
      final positives = _items.where((i) => i.reason?.isPositive == true).length;
      final negatives = _items.where((i) => i.reason?.isNegative == true).length;

      final header = AdjustmentV3(
        adjustmentId: adjustmentId,
        docNumber: 'DRAFT-${DateTime.now().millisecondsSinceEpoch}',
        status: AdjustmentStatus.draft,
        branchCode: widget.branch,
        branchName: widget.branch,
        createdByName: widget.userName,
        totalItems: _items.length,
        totalPositive: positives,
        totalNegative: negatives,
        createdAt: now,
        updatedAt: now,
      );

      final items = _items.map((i) {
        return AdjustmentV3Item(
          adjustmentId: adjustmentId,
          productId: i.product.id,
          sku: i.product.sku,
          productName: i.product.name,
          category: i.product.category,
          qty: i.qty,
          reasonCode: i.reason?.reasonCode ?? '',
          reasonName: i.reason?.reasonName ?? '',
          direction: i.reason?.direction ?? -1,
          unitCost: i.product.costPrice,
          createdAt: now,
        );
      }).toList();

      await AdjustmentV3Dao.save(header: header, items: items);
      if (!mounted) return;
      _showSnack('Draft saved (${_items.length} items)', color: _amber);
      setState(() {
        for (final item in _items) {
          item.qtyCtrl.dispose();
        }
        _items.clear();
      });
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Save failed: $e', color: _red);
    }
  }

  Future<void> _submit() async {
    if (_items.isEmpty) {
      _showSnack('Add at least one item', color: _red);
      return;
    }
    for (final item in _items) {
      if (item.reason == null) {
        _showSnack('Select reason for ${item.product.name}', color: _red);
        return;
      }
      if (item.qty <= 0) {
        _showSnack('Enter valid qty for ${item.product.name}', color: _red);
        return;
      }
    }
    // TODO: Submit for approval
    _showSnack('Submitted for approval (${_items.length} items)', color: _green);
  }

  // ─── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.draftId != null ? 'Edit Draft' : 'Prepared Adjustment',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Product',
            onPressed: _addProduct,
          ),
        ],
      ),
      body: _loadingReasons
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: _items.isEmpty ? _buildEmpty() : _buildList(),
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
              color: _amber.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_rounded,
                size: 64, color: _amber),
          ),
          const SizedBox(height: 16),
          const Text(
            'No items yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap + to add products',
            style: TextStyle(fontSize: 14, color: _textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _addProduct,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _amber,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final filtered = _filteredItems;
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

  // Grand totals for summary strip
  int get _totalQty {
    return _items.fold<int>(0, (sum, i) => sum + i.qty);
  }

  double get _totalCostImpact {
    return _items.fold<double>(0.0, (sum, i) => sum + _itemCostImpact(i));
  }

  // Calculate cost impact per item: qty × unitCost × direction
  double _itemCostImpact(_AdjItem item) {
    final direction = item.reason?.direction ?? 0;
    return item.qty * item.product.costPrice * direction;
  }

  String _formatCost(double amount) {
    final sign = amount >= 0 ? '+' : '-';
    return '$sign${_thousands(amount.abs())}';
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

  Widget _buildItemCard(_AdjItem item) {
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
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(color: _textPrimary, fontSize: 14),
                    children: [
                      TextSpan(
                        text: '${item.product.sku} ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _amber,
                        ),
                      ),
                      TextSpan(
                        text: item.product.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: item.qtyCtrl,
                  onChanged: (v) {
                    setState(() {
                      item.qty = int.tryParse(v) ?? 0;
                    });
                  },
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    labelStyle: const TextStyle(
                        fontSize: 11, color: _textSecondary),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _amber, width: 1.5),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: _red, size: 20),
                onPressed: () => _removeItem(item),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _divider),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AdjustmentReasonV3>(
                value: item.reason,
                isExpanded: true,
                hint: const Row(
                  children: [
                    Icon(Icons.chevron_right_rounded,
                        color: _textSecondary, size: 18),
                    SizedBox(width: 6),
                    Text('Select reason',
                        style: TextStyle(
                            color: _textSecondary, fontSize: 13)),
                  ],
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: _textSecondary),
                items: _dbReasons.map((r) {
                  return DropdownMenuItem<AdjustmentReasonV3>(
                    value: r,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            r.reasonCode,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            r.reasonName,
                            style: TextStyle(
                              color: r.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (r) => setState(() => item.reason = r),
                selectedItemBuilder: (context) => _dbReasons.map((r) {
                  return Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          r.reasonCode,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          r.reasonName,
                          style: TextStyle(
                            color: r.color,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          // ── COST IMPACT ROW ──
          if (item.reason != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cost Impact',
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatCost(_itemCostImpact(item)),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _itemCostImpact(item) < 0 ? _red : _green,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryStrip() {
    final total = _totalCostImpact;
    final costColor = total == 0
        ? _textPrimary
        : (total < 0 ? _red : _green);
    final sign = total >= 0 ? '+' : '-';
    final costLabel = total == 0
        ? '0.00'
        : '$sign${_thousands(total.abs())}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryStat(
            icon: Icons.shopping_bag_outlined,
            iconColor: _amber,
            label: 'Items',
            value: '${_items.length}',
            valueColor: _textPrimary,
          ),
          _dividerV(),
          _buildSummaryStat(
            icon: Icons.add_rounded,
            iconColor: _amber,
            label: 'Qty',
            value: '$_totalQty pcs',
            valueColor: _textPrimary,
          ),
          _dividerV(),
          _buildSummaryStat(
            icon: Icons.sell_outlined,
            iconColor: _amber,
            label: 'Cost',
            value: costLabel,
            valueColor: costColor,
          ),
        ],
      ),
    );
  }

  Widget _dividerV() {
    return Container(
      width: 1,
      height: 32,
      color: _divider,
    );
  }

  Widget _buildSummaryStat({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
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
            color: valueColor,
          ),
        ),
      ],
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
                  onPressed: _saveDraft,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Draft'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _amber,
                side: const BorderSide(color: _amber, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Submit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _amber,
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
}

// ─── Item Model (in-memory) ──────────────────────────────
class _AdjItem {
  final Product product;
  final TextEditingController qtyCtrl;
  int qty;
  AdjustmentReasonV3? reason;

  _AdjItem({
    required this.product,
    required this.qtyCtrl,
    required this.qty,
  });
}
