import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../models/branch_model.dart';
import '../../services/device_assignment_service.dart';
import '../../services/branch_inventory_service.dart';
import '../inventory/inventory_screen.dart';
import '../inventory_adjustment/approver_pin_dialog_v3.dart';
import 'transfer_v3_model.dart';

/// Outbound Transfer Prepared Screen
/// Create/edit transfer document before submission
class TransferPreparedScreen extends StatefulWidget {
  final String branch;
  final String userName;
  final String? draftId; // If editing existing draft

  const TransferPreparedScreen({
    super.key,
    required this.branch,
    required this.userName,
    this.draftId,
  });

  @override
  State<TransferPreparedScreen> createState() => _TransferPreparedScreenState();
}

class _TransferPreparedScreenState extends State<TransferPreparedScreen> {
  static const _purple = Color(0xFF8B5CF6);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);
  static const _green = Color(0xFF22C55E);
  static const _bg = Color(0xFFF5F6FA);
  static const _card = Color(0xFFFFFFFF);
  static const _textPrimary = Color(0xFF111827);
  static const _textSecondary = Color(0xFF6B7280);
  static const _divider = Color(0xFFE5E7EB);

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final List<_TrItem> _items = [];
  String _searchQuery = '';

  // Branch context
  String _fromBranchId = '';
  String _fromBranchName = '';
  Branch? _selectedDestination;
  List<Branch> _availableBranches = [];

  // Stock tracking
  final Map<String, int> _stockMap = {};
  bool _loading = true;
  String? _existingDraftId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final assign = await DeviceAssignmentService().read();
      _fromBranchId = (assign['branchId'] ?? '').toString();
      _fromBranchName = (assign['branchName'] ?? '').toString();

      // Load all branches (excluding own branch)
      if (Branch.allBranches.isEmpty) await Branch.loadFromDB();
      _availableBranches = Branch.allBranches
          .where((b) => b.id != _fromBranchId)
          .toList();

      // Load current branch stock
      final stockMap = await BranchInventoryService.getStockMapForBranch(_fromBranchId);
      _stockMap.clear();
      _stockMap.addAll(stockMap);

      // Load existing draft if editing
      if (widget.draftId != null) {
        await _loadDraft(widget.draftId!);
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      debugPrint('[TRANSFER-PREP] Init error: PHOLDERR');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDraft(String draftId) async {
    final draft = await TransferV3Dao.getById(draftId);
    if (draft == null) return;
    final items = await TransferV3Dao.getItems(draftId);
    if (!mounted) return;

    // Set destination
    try {
      _selectedDestination = _availableBranches.firstWhere(
        (b) => b.id == draft.receivingBranchId,
      );
    } catch (_) {}

    _notesCtrl.text = draft.notes;
    _existingDraftId = draftId;

    // Load items
    for (final di in items) {
      Product? prod;
      try {
        prod = Product.allProducts.firstWhere((p) => p.id == di.productId);
      } catch (_) {
        prod = Product(
          id: di.productId, sku: di.sku, name: di.productName,
          category: di.category, costPrice: di.unitCost,
          sellingPrice: 0, stockQty: 0,
        );
      }
      _items.add(_TrItem(
        product: prod,
        qtyCtrl: TextEditingController(text: di.issuedQty.toString()),
        qty: di.issuedQty,
      ));
    }
    setState(() {});
  }

  int _currentStockOf(_TrItem item) {
    return _stockMap[item.product.id] ?? 0;
  }

  bool _wouldGoNegative(_TrItem item) {
    return item.qty > _currentStockOf(item);
  }

  int get _totalQty => _items.fold(0, (sum, i) => sum + i.qty);
  double get _totalCost => _items.fold(0.0, (sum, i) => sum + (i.qty * i.product.costPrice));

  List<_TrItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    final q = _searchQuery.toLowerCase();
    return _items.where((i) =>
      i.product.name.toLowerCase().contains(q) ||
      i.product.sku.toLowerCase().contains(q)
    ).toList();
  }

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
      _items.add(_TrItem(
        product: product,
        qtyCtrl: TextEditingController(text: '1'),
        qty: 1,
      ));
    });
  }

  void _removeItem(_TrItem item) {
    setState(() {
      _items.remove(item);
    });
    item.qtyCtrl.dispose();
  }

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? _purple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveDraft() async {
    // Validate destination
    if (_selectedDestination == null) {
      _showSnack('Please select destination branch', color: _red);
      return;
    }
    if (_items.isEmpty) {
      _showSnack('Add at least one item', color: _red);
      return;
    }

    try {
      final transferId = _existingDraftId ?? TransferV3Dao.generateId(
        fromBranch: _fromBranchId,
        toBranch: _selectedDestination!.id,
      );
      final now = DateTime.now().toIso8601String();

      final header = TransferV3(
        transferId: transferId,
        docNumber: 'IST-${DateTime.now().millisecondsSinceEpoch}',
        status: TransferStatus.draft,
        issuingBranchId: _fromBranchId,
        issuingBranchName: _fromBranchName,
        receivingBranchId: _selectedDestination!.id,
        receivingBranchName: _selectedDestination!.name,
        preparedBy: widget.userName,
        preparedDate: now,
        totalItems: _items.length,
        totalIssuedQty: _totalQty,
        totalCost: _totalCost,
        notes: _notesCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      final items = _items.map((i) => TransferV3Item(
        transferId: transferId,
        productId: i.product.id,
        sku: i.product.sku,
        productName: i.product.name,
        category: i.product.category,
        issuedQty: i.qty,
        unitCost: i.product.costPrice,
        createdAt: now,
      )).toList();

      await TransferV3Dao.save(header: header, items: items);
      if (!mounted) return;
      _showSnack('Draft saved (${_items.length} items)', color: _purple);
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
    // Validation
    if (_selectedDestination == null) {
      _showSnack('Please select destination branch', color: _red);
      return;
    }
    if (_items.isEmpty) {
      _showSnack('Add at least one item', color: _red);
      return;
    }

    // Insufficient stock check
    final invalidItems = _items.where(_wouldGoNegative).toList();
    if (invalidItems.isNotEmpty) {
      _showInsufficientStockDialog(invalidItems);
      return;
    }

    // Validate qty > 0
    for (final item in _items) {
      if (item.qty <= 0) {
        _showSnack('Invalid qty for ${item.product.name}', color: _red);
        return;
      }
    }

    // Confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.send_rounded, color: _purple),
            const SizedBox(width: 8),
            const Text('Submit Transfer?'),
          ],
        ),
        content: Text(
          'Submit ${_items.length} items to ${_selectedDestination?.name} for manager approval?',
          style: const TextStyle(fontSize: 13, color: _textSecondary),
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
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    // Manager PIN
    final pin = await ApproverPinDialog.show(
      context: context,
      title: 'Submit Transfer',
      headerColor: _purple,
      subtitle: 'PIN required to submit',
      allowedRoles: const ['Supervisor', 'Manager', 'Admin'],
    );
    if (pin == null || !mounted) return;

    try {
      final transferId = _existingDraftId ?? TransferV3Dao.generateId(
        fromBranch: _fromBranchId,
        toBranch: _selectedDestination!.id,
      );
      final now = DateTime.now().toIso8601String();

      final header = TransferV3(
        transferId: transferId,
        docNumber: 'IST-${DateTime.now().millisecondsSinceEpoch}',
        status: TransferStatus.submitted,
        issuingBranchId: _fromBranchId,
        issuingBranchName: _fromBranchName,
        receivingBranchId: _selectedDestination!.id,
        receivingBranchName: _selectedDestination!.name,
        preparedBy: widget.userName,
        preparedDate: now,
        submittedBy: pin.userName,
        submittedDate: now,
        totalItems: _items.length,
        totalIssuedQty: _totalQty,
        totalCost: _totalCost,
        notes: _notesCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      final items = _items.map((i) => TransferV3Item(
        transferId: transferId,
        productId: i.product.id,
        sku: i.product.sku,
        productName: i.product.name,
        category: i.product.category,
        issuedQty: i.qty,
        unitCost: i.product.costPrice,
        createdAt: now,
      )).toList();

      await TransferV3Dao.save(header: header, items: items);
      if (!mounted) return;
      _showSnack('Submitted for approval (${_items.length} items)', color: _green);
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
      _showSnack('Submit failed: $e', color: _red);
    }
  }

  void _showInsufficientStockDialog(List<_TrItem> invalidItems) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            const Text('Insufficient Stock'),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The following items exceed available stock:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...invalidItems.map((item) {
              final current = _currentStockOf(item);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      'Available: $current  •  Requested: ${item.qty}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.draftId != null ? 'Edit Transfer' : 'Prepare Transfer',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildBranchSection(),
                _buildSearchBar(),
                Expanded(
                  child: _items.isEmpty ? _buildEmpty() : _buildList(),
                ),
              ],
            ),
      bottomNavigationBar: _items.isEmpty ? null : _buildBottomBar(),
    );
  }

  Widget _buildBranchSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warehouse_rounded, size: 16, color: _purple),
              const SizedBox(width: 6),
              const Text('From', style: TextStyle(fontSize: 11, color: _textSecondary)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_fromBranchId ($_fromBranchName)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.local_shipping_rounded, size: 16, color: _green),
              const SizedBox(width: 6),
              const Text('To  ', style: TextStyle(fontSize: 11, color: _textSecondary)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: _divider),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Branch>(
                      isExpanded: true,
                      value: _selectedDestination,
                      hint: const Text('Select destination branch', style: TextStyle(fontSize: 13)),
                      items: _availableBranches.map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(
                          '${b.id} / ${b.name}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      )).toList(),
                      onChanged: (b) => setState(() => _selectedDestination = b),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
            prefixIcon: Icon(Icons.search_rounded, color: _textSecondary, size: 22),
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
            child: const Icon(Icons.local_shipping_rounded, size: 64, color: _purple),
          ),
          const SizedBox(height: 16),
          const Text('No items yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 4),
          const Text('Tap + to add products', style: TextStyle(fontSize: 14, color: _textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _addProduct,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final filtered = _filteredItems;
    if (filtered.isEmpty) {
      return const Center(child: Text('No matching items', style: TextStyle(color: _textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildItemCard(filtered[index]),
    );
  }

  Widget _buildItemCard(_TrItem item) {
    final invalid = _wouldGoNegative(item);
    final current = _currentStockOf(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: invalid ? Border.all(color: _red, width: 1.5) : null,
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
                        style: const TextStyle(fontWeight: FontWeight.bold, color: _purple),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    labelStyle: const TextStyle(fontSize: 11, color: _textSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: invalid ? _red : _divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: invalid ? _red : _purple, width: 1.5),
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
          Row(
            children: [
              Icon(
                invalid ? Icons.warning_rounded : Icons.inventory_2_outlined,
                size: 12,
                color: invalid ? _red : _textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Available: $current pcs',
                style: TextStyle(
                  fontSize: 11,
                  color: invalid ? _red : _textSecondary,
                  fontWeight: invalid ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (invalid) ...[
                const Spacer(),
                Text(
                  '⚠️ Exceeds available',
                  style: TextStyle(
                    fontSize: 11,
                    color: _red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummary(),
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
                      foregroundColor: _purple,
                      side: const BorderSide(color: _purple, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(Icons.shopping_bag_outlined, 'Items', '${_items.length}'),
          Container(width: 1, height: 24, color: _divider),
          _stat(Icons.add_rounded, 'Qty', '$_totalQty pcs'),
          Container(width: 1, height: 24, color: _divider),
          _stat(Icons.sell_outlined, 'Cost', _totalCost.toStringAsFixed(2)),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: _purple),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary)),
          ],
        ),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _TrItem {
  final Product product;
  final TextEditingController qtyCtrl;
  int qty;

  _TrItem({
    required this.product,
    required this.qtyCtrl,
    required this.qty,
  });
}
