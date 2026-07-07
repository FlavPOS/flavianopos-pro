import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../models/adjustment_item.dart';
import '../../models/user_model.dart';
import '../../models/branch_model.dart';
import 'adjustment_model.dart';
import '../../helpers/database_helper.dart';
import '../../helpers/sync_bridge.dart';
import '../../services/branch_inventory_service.dart';
import '../../services/device_assignment_service.dart';
import '../../services/device_id_service.dart';
import '../inventory/inventory_screen.dart';
import '../../models/settings_model.dart';
import 'widgets/adjustment_theme.dart';
import 'widgets/stat_card.dart';
import 'widgets/premium_search_bar.dart';
import 'widgets/product_card_collapsed.dart';
import 'widgets/product_card_expanded.dart';
import 'widgets/empty_state_v2.dart';
import 'widgets/add_product_fab.dart';
import 'widgets/bottom_action_bar.dart';

/// Premium v2 redesign of Stock Adjustment screen.
/// Enterprise UI inspired by SAP Fiori, Oracle Fusion, Zoho Inventory.
class StockAdjustmentScreenV2 extends StatefulWidget {
  final String branch;
  final String userName;

  const StockAdjustmentScreenV2({
    super.key,
    required this.branch,
    required this.userName,
  });

  @override
  State<StockAdjustmentScreenV2> createState() =>
      _StockAdjustmentScreenV2State();
}

class _StockAdjustmentScreenV2State extends State<StockAdjustmentScreenV2> {
  final List<AdjustmentItem> _items = [];
  final Set<String> _expandedIds = {};
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final List<String> _reasons = [
    'Receiving Error',
    'Damaged',
    'Expired',
    'Stock Count Correction',
    'Supplier Return',
    'Customer Return',
    'Others',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  // ─── Computed properties ────────────────────────────────
  int get _itemsCount => _items.length;
  int get _addsCount => _items.where((i) => i.isAdd).length;
  int get _deductsCount => _items.where((i) => !i.isAdd).length;

  double get _totalCostImpact {
    double total = 0;
    for (final item in _items) {
      final impact = item.quantity * item.product.costPrice;
      total += item.isAdd ? impact : -impact;
    }
    return total;
  }

  List<AdjustmentItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    final q = _searchQuery.toLowerCase();
    return _items.where((i) {
      return i.product.name.toLowerCase().contains(q) ||
             i.product.sku.toLowerCase().contains(q);
    }).toList();
  }

  // ─── Actions ────────────────────────────────────────────
  void _showSnackBar(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? AdjTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdjTheme.radiusSmall),
        ),
      ),
    );
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

    // Check duplicate
    if (_items.any((i) => i.product.id == product.id)) {
      _showSnackBar('${product.name} is already added',
          color: AdjTheme.warning);
      return;
    }

    // Load branch-specific stock
    final assign = await DeviceAssignmentService().read();
    String bCode = (assign['branchId'] ?? '').toString();
    final role = (assign['role'] ?? '').toString().toLowerCase();
    final isHO = bCode.isEmpty ||
        bCode.toUpperCase() == 'HEADOFFICE' ||
        role == 'admin' || role == 'headoffice' || role == 'companyadmin';
    if (isHO) {
      if (Branch.allBranches.isEmpty) await Branch.loadFromDB();
      bCode = Branch.getHeadOffice()?.id ?? 'HO001';
    }
    final branchStock =
        await BranchInventoryService.getStock(bCode, product.id);

    if (!mounted) return;
    setState(() {
      final item = AdjustmentItem(product: product, currentStock: branchStock);
      item.quantity = 1;
      item.qtyController.text = '1';
      _items.add(item);
      _expandedIds.add(product.id); // Auto-expand newly added
    });
  }

  void _removeItem(AdjustmentItem item) {
    setState(() {
      _items.remove(item);
      _expandedIds.remove(item.product.id);
    });
    item.dispose();
  }

  void _toggleExpanded(String productId) {
    setState(() {
      if (_expandedIds.contains(productId)) {
        _expandedIds.remove(productId);
      } else {
        _expandedIds.add(productId);
      }
    });
  }

  Future<void> _saveAllAdjustments() async {
    // Validation
    if (_items.isEmpty) {
      _showSnackBar('Add at least one product', color: AdjTheme.warning);
      return;
    }
    for (final item in _items) {
      if (item.quantity <= 0) {
        _showSnackBar('Enter valid qty for ${item.product.name}',
            color: AdjTheme.danger);
        _expandedIds.add(item.product.id);
        setState(() {});
        return;
      }
      if (!item.isAdd && item.quantity > item.currentStock) {
        _showSnackBar(
          'Cannot deduct more than ${item.currentStock} for ${item.product.name}',
          color: AdjTheme.danger,
        );
        return;
      }
      if (item.selectedReason.isEmpty) {
        _showSnackBar('Select reason for ${item.product.name}',
            color: AdjTheme.danger);
        _expandedIds.add(item.product.id);
        setState(() {});
        return;
      }
    }

    // Confirmation dialog
    final confirmed = await _showConfirmationDialog();
    if (confirmed != true || !mounted) return;

    // Manager PIN (existing logic)
    if (AppSettings.requirePinVoid) {
      final pinOk = await _showManagerPinDialog();
      if (pinOk != true || !mounted) return;
    }

    // Detect branch context
    final assign = await DeviceAssignmentService().read();
    String branchCode = (assign['branchId'] ?? '').toString();
    final role = (assign['role'] ?? '').toString().toLowerCase();
    final deviceId = await DeviceIdService().getOrCreate();
    final isHeadOffice = branchCode.isEmpty ||
        branchCode.toUpperCase() == 'HEADOFFICE' ||
        role == 'admin' || role == 'headoffice' || role == 'companyadmin';
    if (isHeadOffice) {
      if (Branch.allBranches.isEmpty) await Branch.loadFromDB();
      final ho = Branch.getHeadOffice();
      branchCode = ho?.id ?? 'HO001';
    }
    final branchInfo = Branch.findByCode(branchCode);
    final branchName = branchInfo?.name ?? widget.branch;
    final currentUser = AppUser.allUsers.firstWhere(
      (u) => u.name == widget.userName || u.username == widget.userName,
      orElse: () => AppUser(
        id: 'unknown',
        name: widget.userName,
        username: '',
        pin: '',
        role: 'Cashier',
        branch: widget.branch,
        joinDate: DateTime.now(),
      ),
    );

    // Save loop
    final List<AdjustmentRecord> records = [];
    for (final item in _items) {
      final currentBranchStock =
          await BranchInventoryService.getStock(branchCode, item.product.id);
      final newBranchStock = item.isAdd
          ? currentBranchStock + item.quantity
          : currentBranchStock - item.quantity;

      final record = AdjustmentRecord(
        id: 'ADJ-${DateTime.now().millisecondsSinceEpoch}-${_items.indexOf(item)}',
        sku: item.product.sku,
        itemName: item.product.name,
        productId: item.product.id,
        cost: item.product.costPrice,
        retail: item.product.sellingPrice,
        adjustmentType: item.isAdd ? 'Add' : 'Deduct',
        quantity: item.quantity,
        oldStock: currentBranchStock,
        newStock: newBranchStock,
        reason: item.selectedReason,
        notes: item.notesController.text,
        dateTime: DateTime.now(),
        branchCode: branchCode,
        branchName: branchName,
        createdBy: widget.userName,
        createdByUserId: currentUser.id,
        deviceId: deviceId,
      );
      records.add(record);

      await AdjustmentStorage.saveAdjustment(record);

      // Unified ledger
      try {
        final movId = 'MOV-ADJ-$branchCode-${DateTime.now().millisecondsSinceEpoch}-${item.product.id}';
        final qtyChange = item.isAdd ? item.quantity : -item.quantity;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final nowIso = DateTime.now().toIso8601String();
        final movement = {
          'movement_id': movId,
          'movement_type': 'ADJUSTMENT',
          'sku': item.product.sku,
          'product_id': item.product.id,
          'product_name': item.product.name,
          'barcode': item.product.barcode,
          'qty_before': currentBranchStock.toDouble(),
          'qty_change': qtyChange.toDouble(),
          'qty_after': newBranchStock.toDouble(),
          'unit_cost': item.product.costPrice,
          'reason_code': item.selectedReason,
          'reason_note': item.notesController.text,
          'reference_no': record.id,
          'batch_no': '',
          'branch_code': branchCode,
          'branch_name': branchName,
          'user_pin': currentUser.pin,
          'user_name': widget.userName,
          'approved_by_pin': '',
          'approved_by_name': '',
          'local_timestamp': nowMs,
          'sync_status': 'PENDING',
          'z_report_id': '',
          'created_at': nowIso,
          'updated_at': nowIso,
        };
        final db = await DatabaseHelper().database;
        await db.insert('stock_movements', movement);
        try {
          await SyncBridge.enqueueMovement(movement, op: 'create');
        } catch (e) {
          debugPrint('[MOV] Firebase enqueue FAILED: $e');
        }
      } catch (e) {
        debugPrint('[MOV] Ledger write FAILED: $e');
      }

      await BranchInventoryService.setStock(
          branchCode, item.product.id, newBranchStock);
      await SyncBridge.enqueueAdjustment(record, op: 'create');
    }

    if (!mounted) return;
    _showSnackBar('Saved ${records.length} adjustment(s) successfully',
        color: AdjTheme.success);
    setState(() {
      _items.clear();
      _expandedIds.clear();
    });
  }

  Future<bool?> _showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdjTheme.radiusCard),
        ),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AdjTheme.primary),
            const SizedBox(width: AdjTheme.s2),
            const Text('Confirm Adjustments'),
          ],
        ),
        content: Text(
          'Save ${_items.length} adjustment(s) with total cost impact ${AdjTheme.peso(_totalCostImpact)}?',
          style: AdjTheme.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdjTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showManagerPinDialog() {
    final pinCtrl = TextEditingController();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdjTheme.radiusCard),
        ),
        title: const Text('Manager PIN Required'),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          maxLength: 6,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Enter Manager PIN',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdjTheme.radiusSmall),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final mgr = AppUser.allUsers.where((u) =>
                  (u.role == 'Admin' || u.role == 'Manager') &&
                  u.pin == pinCtrl.text.trim()).firstOrNull;
              if (mgr != null) {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Invalid Manager PIN'),
                  backgroundColor: AdjTheme.danger,
                ));
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // ─── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdjTheme.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTopSection(),
          Expanded(child: _buildListSection()),
        ],
      ),
      floatingActionButton: AddProductFab(
        onPressed: _addProduct,
        tooltip: 'Add Product',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _items.isEmpty ? null : BottomActionBar(
        itemCount: _itemsCount,
        totalCostImpact: _totalCostImpact,
        isEnabled: _items.isNotEmpty,
        onSave: _saveAllAdjustments,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AdjTheme.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Row(
        children: [
          Icon(Icons.inventory_2_rounded, size: 22),
          SizedBox(width: AdjTheme.s2),
          Text('Stock Adjustment',
              style: TextStyle(
                fontFamily: AdjTheme.fontFamily,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildTopSection() {
    return Container(
      padding: const EdgeInsets.all(AdjTheme.s3),
      color: AdjTheme.bg,
      child: Column(
        children: [
          StatCardRow(
            itemCount: _itemsCount,
            addsCount: _addsCount,
            deductsCount: _deductsCount,
            costImpact: _totalCostImpact,
          ),
          const SizedBox(height: AdjTheme.s3),
          PremiumSearchBar(
            controller: _searchCtrl,
            onChanged: (q) => setState(() => _searchQuery = q),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection() {
    if (_items.isEmpty) {
      return EmptyStateV2(onAddPressed: _addProduct);
    }
    final filtered = _filteredItems;
    if (filtered.isEmpty) {
      return Center(
        child: Text('No results for "$_searchQuery"',
            style: AdjTheme.body.copyWith(color: AdjTheme.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: AdjTheme.s3, vertical: AdjTheme.s2),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final isExpanded = _expandedIds.contains(item.product.id);
        final costImpact = item.quantity * item.product.costPrice;

        return AnimatedSize(
          duration: AdjTheme.animNormal,
          curve: AdjTheme.curveEmphasized,
          child: isExpanded
              ? ProductCardExpanded(
                  productName: item.product.name,
                  sku: item.product.sku,
                  category: item.product.category,
                  imagePath: item.product.imageUrl,
                  currentStock: item.currentStock,
                  newStock: item.newStock,
                  quantity: item.quantity,
                  isAdd: item.isAdd,
                  costImpact: costImpact,
                  selectedReason: item.selectedReason.isEmpty
                      ? null
                      : item.selectedReason,
                  reasons: _reasons,
                  remarksController: item.notesController,
                  onQtyChanged: (v) => setState(() {
                    item.quantity = v;
                    item.qtyController.text = v.toString();
                  }),
                  onTypeChanged: (add) => setState(() => item.isAdd = add),
                  onReasonChanged: (r) => setState(() {
                    item.selectedReason = r ?? '';
                  }),
                  onClose: () => _removeItem(item),
                )
              : ProductCardCollapsed(
                  productName: item.product.name,
                  sku: item.product.sku,
                  category: item.product.category,
                  imagePath: item.product.imageUrl,
                  currentStock: item.currentStock,
                  newStock: item.newStock,
                  quantity: item.quantity,
                  isAdd: item.isAdd,
                  costImpact: costImpact,
                  isExpanded: false,
                  onTap: () => _toggleExpanded(item.product.id),
                ),
        );
      },
    );
  }
}
