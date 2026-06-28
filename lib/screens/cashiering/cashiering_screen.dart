// lib/screens/cashiering/cashiering_screen.dart
import 'package:flutter/material.dart';
import '../../services/daily_lock_service.dart';
import '../../models/user_model.dart';
import '../../models/settings_model.dart';
import '../../utils/sound_helper.dart';
import '../../services/cashier_session_service.dart';
import '../../models/product_model.dart';
import '../../models/cart_item_model.dart';
import '../../widgets/product_card_widget.dart';
import '../../widgets/cart_item_widget.dart';
import 'payment_dialog.dart';
import 'receipt_screen.dart';
import '../../models/discount_record_model.dart';
import '../../models/transaction_model.dart';
import "../../services/branch_inventory_service.dart";
import "../../services/device_assignment_service.dart";

class TransactionDiscount {
  final String type;
  final String? idNumber;
  final String? name;
  final int? age;
  final double percentage;
  final double fixedAmount;
  final bool isPercentage;

  TransactionDiscount({
    required this.type,
    this.idNumber,
    this.name,
    this.age,
    this.percentage = 0,
    this.fixedAmount = 0,
    this.isPercentage = true,
  });

  double calculateDiscount(double subtotal) {
    if (isPercentage) return subtotal * (percentage / 100);
    return fixedAmount.clamp(0, subtotal);
  }

  String get label {
    switch (type) {
      case 'Senior': return '👴 Senior (20%)';
      case 'PWD': return '♿ PWD (20%)';
      case 'Employee': return '🏢 Employee (${percentage.toInt()}%)';
      case 'Manual': return isPercentage ? '✏️ Manual (${percentage.toInt()}%)' : '✏️ Manual (${fixedAmount.toStringAsFixed(2)})';
      default: return type;
    }
  }

  String get shortLabel {
    switch (type) {
      case 'Senior': return 'SC-20%';
      case 'PWD': return 'PWD-20%';
      case 'Employee': return 'EMP-${percentage.toInt()}%';
      case 'Manual': return isPercentage ? 'MAN-${percentage.toInt()}%' : 'MAN-${fixedAmount.toStringAsFixed(0)}';
      default: return type;
    }
  }
}

class CashieringScreen extends StatefulWidget {
  final String userName;
  final String branch;
  const CashieringScreen({super.key, required this.userName, required this.branch});
  @override
  State<CashieringScreen> createState() => _CashieringScreenState();
}

class _CashieringScreenState extends State<CashieringScreen> {
  // ═══ PHASE B1.2: Branch-Aware Stock Cache ═══
  Map<String, int> _branchStock = {};
  String _binvBranchId = "";
  bool _binvLoaded = false;

  Future<void> _loadBranchStock() async {
    try {
      final assign = await DeviceAssignmentService().read();
      final bid = (assign["branchId"] ?? "").toString();
      _binvBranchId = bid;
      if (bid.isEmpty) {
        print("[POS-B1.2] no branchId, fallback to global stock");
        if (mounted) setState(() => _binvLoaded = true);
        return;
      }
      final map = await BranchInventoryService.getStockMapForBranch(bid);
      if (!mounted) return;
      setState(() {
        _branchStock = map;
        _binvLoaded = true;
      });
      print("[POS-B1.2] loaded ${map.length} products for branch=$bid");
    } catch (e) {
      print("[POS-B1.2] ERROR: $e");
      if (mounted) setState(() => _binvLoaded = true);
    }
  }

  int _stockOf(Product p) {
    if (!_binvLoaded) return p.stockQty;
    if (_binvBranchId.isNotEmpty) return _branchStock[p.id] ?? 0;
    return p.stockQty;
  }
  // ═══ END PHASE B1.2 ═══

  List<Product> get _products => Product.allProducts;
  final List<CartItem> _cart = [];
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';
  int _transactionCount = 0;
  TransactionDiscount? _txnDiscount;

  List<String> get _categories {
    final cats = _products.map((p) => p.category).toSet().toList();
    cats.sort();
    return ['All', ...cats];
  }

  List<Product> get _filteredProducts {
    return _products.where((p) {
      final matchesCategory = _selectedCategory == 'All' || p.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.sku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.barcode.contains(_searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  double get _cartSubtotal => _cart.fold(0, (sum, item) => sum + item.subtotal);
  double get _itemDiscountTotal => _cart.fold(0, (sum, item) => sum + item.discountAmount);
  double get _txnDiscountAmount {
    if (_txnDiscount == null) return 0;
    return _txnDiscount!.calculateDiscount(_cartSubtotal);
  }
  double get _totalDiscount => _itemDiscountTotal + _txnDiscountAmount;
  double get _totalAmount => (_cartSubtotal - _txnDiscountAmount).clamp(0, double.infinity);
  int get _totalItems => _cart.fold(0, (sum, item) => sum + item.quantity);

  void _addToCart(Product product) {
    // Quick-add without popup if setting is OFF
    if (!AppSettings.qtyPopupOnTap) {
      setState(() {
        final idx = _cart.indexWhere((item) => item.product.id == product.id);
        if (idx >= 0) {
          if (AppSettings.allowNegativeStock || _cart[idx].quantity < _stockOf(product)) {
            _cart[idx].quantity++;
          } else { _showSnackBar("Maximum stock reached"); }
        } else {
          _cart.add(CartItem(product: product)); SoundHelper.click();
        }
      });
      return;
    }
    final existingIndex = _cart.indexWhere((item) => item.product.id == product.id);
    final currentQty = existingIndex >= 0 ? _cart[existingIndex].quantity : 0;
    final qtyController = TextEditingController(text: currentQty > 0 ? '$currentQty' : '1');
    int qty = currentQty > 0 ? currentQty : 1;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.add_shopping_cart, color: Colors.green[700]),
            const SizedBox(width: 8),
            Expanded(child: Text(product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Price: ${product.sellingPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, color: Colors.green[700], fontWeight: FontWeight.bold)),
                  Text('Stock: ${_stockOf(product)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ]),
                if (currentQty > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(6)),
                    child: Text('In cart: $currentQty', style: TextStyle(fontSize: 11, color: Colors.orange[700], fontWeight: FontWeight.w600)),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                onPressed: () { if (qty > 1) { qty--; qtyController.text = '$qty'; setDialogState(() {}); } },
                icon: const Icon(Icons.remove_circle_outline, size: 32), color: Colors.red,
              ),
              SizedBox(width: 80, child: TextField(
                controller: qtyController, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8)),
                onChanged: (v) { qty = int.tryParse(v) ?? 1; setDialogState(() {}); },
              )),
              IconButton(
                onPressed: () { if (AppSettings.allowNegativeStock || qty < _stockOf(product)) { qty++; qtyController.text = '$qty'; setDialogState(() {}); } },
                icon: const Icon(Icons.add_circle_outline, size: 32), color: Colors.green,
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
              for (final q in [1, 2, 3, 5, 10, 20, 50])
                if (AppSettings.allowNegativeStock || q <= _stockOf(product))
                  GestureDetector(
                    onTap: () { qty = q; qtyController.text = '$q'; setDialogState(() {}); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: qty == q ? Colors.green[700] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: qty == q ? Colors.green[700]! : Colors.grey[300]!),
                      ),
                      child: Text('$q', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                        color: qty == q ? Colors.white : Colors.grey[700])),
                    ),
                  ),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text((product.sellingPrice * qty).toStringAsFixed(2),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[700])),
              ]),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () {
                if (qty <= 0) return;
                if (!AppSettings.allowNegativeStock && qty > _stockOf(product)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Max stock is ${_stockOf(product)}'), backgroundColor: Colors.red));
                  return;
                }
                setState(() {
                  if (existingIndex >= 0) {
                    _cart[existingIndex].quantity = qty;
                  } else {
                    final item = CartItem(product: product);
                    item.quantity = qty;
                    _cart.add(item);
                  }
                });
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: Text(existingIndex >= 0 ? 'Update Cart' : 'Add to Cart'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ],
        ),
      ),
    );
  }
  void _incrementItem(int index) {
    setState(() {
      if (AppSettings.allowNegativeStock || _cart[index].quantity < _stockOf(_cart[index].product)) {
        _cart[index].quantity++;
      } else {
        _showSnackBar('Maximum stock reached');
      }
    });
  }

  void _decrementItem(int index) {

    setState(() {
      if (_cart[index].quantity > 1) {
        _cart[index].quantity--;
      } else {
        _cart.removeAt(index);
      }
    });
  }

  void _removeItem(int index) {
    final itemName = _cart[index].product.name;
    setState(() => _cart.removeAt(index));
    _showSnackBar('$itemName removed from cart');
  }

  void _clearCart() {
    if (_cart.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Remove all items and discounts from the cart?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { setState(() { _cart.clear(); _txnDiscount = null; }); Navigator.pop(ctx); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // DISCOUNT SELECTOR - Scrollable DraggableSheet
  // ──────────────────────────────────────────────────────────
  void _showDiscountSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.75,
        minChildSize: 0.35,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const Center(child: Text('Select Discount Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(height: 4),
              Center(child: Text('Subtotal: ${_cartSubtotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
              const SizedBox(height: 16),
              _discountOption(ctx, '👴', 'Senior Citizen', '20% Discount', Colors.blue, () {
                Navigator.pop(ctx);
                _showIdFormDialog('Senior', 20);
              }),
              const SizedBox(height: 8),
              _discountOption(ctx, '♿', 'PWD', '20% Discount', Colors.purple, () {
                Navigator.pop(ctx);
                _showIdFormDialog('PWD', 20);
              }),
              const SizedBox(height: 8),
              _discountOption(ctx, '🏢', 'Employee', '10% Discount', Colors.teal, () {
                Navigator.pop(ctx);
                _showEmployeeFormDialog();
              }),
              const SizedBox(height: 8),
              _discountOption(ctx, '✏️', 'Manual Discount', 'Custom Amount or %', Colors.orange, () {
                Navigator.pop(ctx);
                _showManualDiscountDialog();
              }),
              if (_txnDiscount != null) ...[
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: () { setState(() => _txnDiscount = null); Navigator.pop(ctx); _showSnackBar('Discount removed'); },
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  label: const Text('Remove Current Discount', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                )),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _discountOption(BuildContext ctx, String emoji, String title, String subtitle, Color color, VoidCallback onTap) {
    final isActive = _txnDiscount?.type == title.split(' ').first;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? color.withAlpha(20) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? color : Colors.grey[300]!, width: isActive ? 2 : 1),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ])),
          if (isActive) Icon(Icons.check_circle, color: color, size: 24)
          else Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        ]),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // SENIOR / PWD ID FORM
  // ──────────────────────────────────────────────────────────
  void _showIdFormDialog(String type, double percentage) {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(type == 'Senior' ? Icons.elderly : Icons.accessible,
            color: type == 'Senior' ? Colors.blue : Colors.purple, size: 28),
          const SizedBox(width: 10),
          Text('$type Discount', style: const TextStyle(fontSize: 18)),
        ]),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Discount:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('${percentage.toInt()}% OFF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green[700])),
                ]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: idCtrl,
                decoration: InputDecoration(
                  labelText: '$type ID Number *',
                  prefixIcon: const Icon(Icons.badge),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey[50]),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey[50]),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ageCtrl,
                decoration: InputDecoration(
                  labelText: 'Age *',
                  prefixIcon: const Icon(Icons.cake),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey[50]),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final age = int.tryParse(v);
                  if (age == null || age < 1 || age > 150) return 'Invalid age';
                  if (type == 'Senior' && age < 60) return 'Must be 60 years or older';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    type == 'Senior'
                        ? 'Per RA 9994 - 20% discount for Senior Citizens'
                        : 'Per RA 10754 - 20% discount for PWD',
                    style: TextStyle(fontSize: 11, color: Colors.orange[800]))),
                ]),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              setState(() {
                _txnDiscount = TransactionDiscount(
                  type: type, idNumber: idCtrl.text.trim(), name: nameCtrl.text.trim(),
                  age: int.tryParse(ageCtrl.text.trim()), percentage: percentage, isPercentage: true);
              });
              Navigator.pop(ctx);
              _showSnackBar('$type discount applied - ${percentage.toInt()}% OFF');
            },
            icon: const Icon(Icons.check),
            label: const Text('Apply Discount'),
            style: ElevatedButton.styleFrom(
              backgroundColor: type == 'Senior' ? Colors.blue : Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // EMPLOYEE DISCOUNT FORM
  // ──────────────────────────────────────────────────────────
  void _showEmployeeFormDialog() {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final pctCtrl = TextEditingController(text: '10');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.badge, color: Colors.teal[700], size: 28),
          const SizedBox(width: 10),
          const Text('Employee Discount', style: TextStyle(fontSize: 18)),
        ]),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: idCtrl,
                decoration: InputDecoration(
                  labelText: 'Employee ID *',
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey[50]),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Employee Name *',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey[50]),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: pctCtrl,
                decoration: InputDecoration(
                  labelText: 'Discount % *',
                  prefixIcon: const Icon(Icons.percent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey[50], hintText: 'Default: 10%'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final pct = double.tryParse(v);
                  if (pct == null || pct <= 0 || pct > 50) return 'Enter 1-50%';
                  return null;
                },
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final pct = double.tryParse(pctCtrl.text.trim()) ?? 10;
              setState(() {
                _txnDiscount = TransactionDiscount(
                  type: 'Employee', idNumber: idCtrl.text.trim(), name: nameCtrl.text.trim(),
                  percentage: pct, isPercentage: true);
              });
              Navigator.pop(ctx);
              _showSnackBar('Employee discount applied - ${pct.toInt()}% OFF');
            },
            icon: const Icon(Icons.check),
            label: const Text('Apply Discount'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // MANUAL DISCOUNT DIALOG
  // ──────────────────────────────────────────────────────────
  void _showManualDiscountDialog() {
    final amountCtrl = TextEditingController();
    bool isPercentage = true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.edit, color: Colors.orange[700], size: 28),
            const SizedBox(width: 10),
            const Text('Manual Discount', style: TextStyle(fontSize: 18)),
          ]),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Subtotal:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(_cartSubtotal.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700])),
                  ]),
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('% Percentage'), icon: Icon(Icons.percent, size: 16)),
                    ButtonSegment(value: false, label: Text('P Fixed'), icon: Icon(Icons.attach_money, size: 16)),
                  ],
                  selected: {isPercentage},
                  onSelectionChanged: (v) => setD(() => isPercentage = v.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountCtrl,
                  decoration: InputDecoration(
                    labelText: isPercentage ? 'Discount Percentage (%)' : 'Discount Amount (P)',
                    prefixIcon: Icon(isPercentage ? Icons.percent : Icons.payments),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: Colors.grey[50]),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final val = double.tryParse(v);
                    if (val == null || val <= 0) return 'Enter a valid amount';
                    if (isPercentage && val > AppSettings.maxDiscountPercent) return 'Max ${AppSettings.maxDiscountPercent}%';
                    if (!isPercentage && val > _cartSubtotal) return 'Cannot exceed subtotal';
                    return null;
                  },
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final val = double.tryParse(amountCtrl.text.trim()) ?? 0;
                // PIN check for high discount
                if (AppSettings.requirePinDiscount && isPercentage && val > AppSettings.pinDiscountThreshold) {
                  final pinCtrl = TextEditingController();
                  Navigator.pop(ctx);
                  showDialog(context: context, builder: (pCtx) => AlertDialog(
                    title: const Text("Manager PIN Required"),
                    content: TextField(controller: pinCtrl, obscureText: true, maxLength: 6,
                      decoration: InputDecoration(labelText: "PIN for ${val.toInt()}% discount",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(pCtx), child: const Text("Cancel")),
                      ElevatedButton(onPressed: () {
                        final mgrCheck = AppUser.allUsers.where((u) => (u.role == 'Admin' || u.role == 'Manager') && u.pin == pinCtrl.text.trim()).firstOrNull;
                        if (mgrCheck == null) { _showSnackBar("Invalid Manager PIN"); Navigator.pop(pCtx); return; }
                        setState(() { _txnDiscount = TransactionDiscount(type: "Manual", percentage: val, fixedAmount: 0, isPercentage: true); });
                        Navigator.pop(pCtx); _showSnackBar("Manual discount applied");
                      }, child: const Text("Confirm")),
                    ]));
                  return;
                }
                setState(() {
                  _txnDiscount = TransactionDiscount(
                    type: 'Manual', percentage: isPercentage ? val : 0,
                    fixedAmount: isPercentage ? 0 : val, isPercentage: isPercentage);
                });
                Navigator.pop(ctx);
                _showSnackBar('Manual discount applied');
              },
              icon: const Icon(Icons.check),
              label: const Text('Apply'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // PER-ITEM DISCOUNT
  // ──────────────────────────────────────────────────────────
  void _showItemDiscountDialog(int index) {
    final discountController = TextEditingController(
      text: _cart[index].discount > 0 ? _cart[index].discount.toString() : '');
    String discountType = _cart[index].discountType;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Item Discount: ${_cart[index].product.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'fixed', label: Text('P Fixed')),
              ButtonSegment(value: 'percentage', label: Text('% Percent')),
            ],
            selected: {discountType},
            onSelectionChanged: (value) { discountType = value.first; (ctx as Element).markNeedsBuild(); },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: discountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: discountType == 'percentage' ? 'Discount %' : 'Discount Amount (P)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () { setState(() { _cart[index].discount = 0; _cart[index].discountType = 'fixed'; }); Navigator.pop(ctx); },
            child: const Text('Remove Discount')),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(discountController.text) ?? 0;
              setState(() { _cart[index].discount = value; _cart[index].discountType = discountType; });
              Navigator.pop(ctx);
            },
            child: const Text('Apply')),
        ],
      ),
    );
  }

  void _processPayment() async {
    // 🛡️ EOD LOCK GUARD — paranoid double-check before payment
    if (await DailyLockService.isLocked()) {
      if (!mounted) return;
      await DailyLockService.showCashierLockedDialog(context, action: "process payment");
      return;
    }
    if (_cart.isEmpty) { _showSnackBar('Cart is empty!'); return; }
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => PaymentDialog(
        totalAmount: _totalAmount,
        onPaymentComplete: (method, amountPaid) {
          _transactionCount++;
          final txnId = 'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
          final cartCopy = List<CartItem>.from(_cart);
          final total = _totalAmount;
          final disc = _totalDiscount;
          final now = DateTime.now();

          // Save discount record if transaction has discount
          if (_txnDiscount != null && _txnDiscountAmount > 0) {
            final discItems = cartCopy.map((c) {
              final gross = c.product.sellingPrice * c.quantity;
              final discAmt = _txnDiscount!.calculateDiscount(c.subtotal);
              return DiscountItemRecord(
                itemName: c.product.name,
                sku: c.product.sku,
                qty: c.quantity,
                unitPrice: c.product.sellingPrice,
                grossAmount: gross,
                discountAmount: discAmt,
                netAmount: c.subtotal - discAmt,
              );
            }).toList();

            DiscountRecord.addRecord(DiscountRecord(
              transactionId: txnId,
              dateTime: now,
              discountType: _txnDiscount!.type,
              customerName: _txnDiscount!.name,
              idNumber: _txnDiscount!.idNumber,
              age: _txnDiscount!.age,
              discountPercentage: _txnDiscount!.percentage,
              fixedDiscount: _txnDiscount!.fixedAmount,
              isPercentage: _txnDiscount!.isPercentage,
              items: discItems,
              totalGross: _cartSubtotal,
              totalDiscount: _txnDiscountAmount,
              totalNet: total,
              cashier: widget.userName,
              branch: widget.branch,
            ));
          }

          Navigator.pop(ctx);
          // ── Save Transaction ──────────────────────────────
          final txnItems = cartCopy.map((c) => TransactionItem(
            name: c.product.name, sku: c.product.sku, qty: c.quantity,
            price: c.product.sellingPrice, discount: c.discount, discountType: c.discountType,
          )).toList();

          Transaction.addTransaction(Transaction(
            id: txnId, items: txnItems, subtotal: _cartSubtotal,
            totalDiscount: disc, tax: AppSettings.vatEnabled ? (total - (total / (1 + AppSettings.vatRate / 100))) : 0, total: total,
            paymentMethod: method, amountPaid: amountPaid, change: amountPaid - total,
            cashier: widget.userName, branch: widget.branch, dateTime: now,
          ));

          // ═══════════════════════════════════════════════════════════════
          // 🏪 PHASE B1: Branch-Aware Stock Decrement (Dual Write)
          // ═══════════════════════════════════════════════════════════════
          () async {
            try {
              final assign = await DeviceAssignmentService().read();
              final binvBranchId = (assign["branchId"] ?? "").toString();
              if (binvBranchId.isNotEmpty) {
                for (final item in cartCopy) {
                  final ok = await BranchInventoryService.decrementStock(
                    binvBranchId,
                    item.product.id,
                    item.quantity,
                  );
                  print("[POS-B1] decrement ${item.product.name} qty=${item.quantity} ok=$ok");
                }
                print("[POS-B1] ✅ Branch stock decremented for branchId=$binvBranchId");
              } else {
                print("[POS-B1] ⚠️ no branchId assigned, BINV decrement SKIPPED");
              }
            } catch (e) {
              print("[POS-B1] ❌ ERROR in BINV decrement: $e");
            }
          }();
          // ═══════════════════════════════════════════════════════════════

          // ── Deduct Stock ──────────────────────────────────
          for (final item in cartCopy) {
            final pIdx = Product.allProducts.indexWhere((p) => p.id == item.product.id);
            if (pIdx >= 0) {
              final p = Product.allProducts[pIdx];
              Product.updateProduct(p.id, Product(
                id: p.id, name: p.name, sku: p.sku, category: p.category,
                sellingPrice: p.sellingPrice, costPrice: p.costPrice,
                stockQty: AppSettings.allowNegativeStock ? (p.stockQty - item.quantity) : (p.stockQty - item.quantity).clamp(0, 999999),
                reorderLevel: p.reorderLevel, barcode: p.barcode, imagePath: p.imagePath, imageUrl: p.imageUrl, unit: p.unit,
              ));
            }
          }
          // 🔄 Phase B1.2: refresh branch stock cache after sale
          _loadBranchStock();

          // ── Update Active Cashier Session ──
          () async {
            try {
              final session = await CashierSessionService.getActiveSession(widget.userName);
              if (session != null) {
                double cashAdd = 0, gcashAdd = 0, mayaAdd = 0, cardAdd = 0, otherAdd = 0;
                final pm = method.toLowerCase();
                if (pm.contains('cash')) cashAdd = total;
                else if (pm.contains('gcash')) gcashAdd = total;
                else if (pm.contains('maya')) mayaAdd = total;
                else if (pm.contains('card')) cardAdd = total;
                else otherAdd = total;

                await CashierSessionService.updateSessionTotals(session.id, {
                  'cashSales': session.cashSales + cashAdd,
                  'gcashSales': session.gcashSales + gcashAdd,
                  'mayaSales': session.mayaSales + mayaAdd,
                  'cardSales': session.cardSales + cardAdd,
                  'otherSales': session.otherSales + otherAdd,
                  'totalDiscounts': session.totalDiscounts + disc,
                  'transactionCount': session.transactionCount + 1,
                });
              }
            } catch (_) {}
          }();

          SoundHelper.success();
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              items: cartCopy, totalAmount: total, totalDiscount: disc,
              paymentMethod: method, amountPaid: amountPaid, change: amountPaid - total,
              transactionId: txnId, branch: widget.branch, cashier: widget.userName, dateTime: now),
          )).then((_) { setState(() { _cart.clear(); _txnDiscount = null; }); });
        },
      ),
    );
  }

  void _showSnackBar(String message) { SoundHelper.click();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2)));
  }


  // ═════════════════════════════════════════════════════════════
  // 🛡️ EOD LOCK GUARD — block cashiering after Z Report
  // ═════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _loadBranchStock();  // Phase B1.2: load branch-aware stock
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (await DailyLockService.isLocked()) {
        if (!mounted) return;
        await DailyLockService.showCashierLockedDialog(
          context, action: 'process transactions',
        );
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashiering', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700], foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text('TXN: $_transactionCount', style: const TextStyle(fontSize: 12)))),
          IconButton(icon: const Icon(Icons.delete_sweep), onPressed: _clearCart, tooltip: 'Clear Cart'),
        ],
      ),
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(children: [
      Expanded(flex: 3, child: _buildProductsSection()),
      SizedBox(width: 350, child: _buildCartSection()),
    ]);
  }

  Widget _buildNarrowLayout() {
    return Column(children: [
      Expanded(child: _buildProductsSection()),
      if (_cart.isNotEmpty)
        GestureDetector(
          onTap: () => _showCartBottomSheet(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFF1565C0),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 8, offset: const Offset(0, -2))]),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(8)),
                child: Text('$_totalItems', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('View Cart', style: TextStyle(color: Colors.white, fontSize: 16)),
                if (_txnDiscount != null)
                  Text(_txnDiscount!.shortLabel, style: TextStyle(color: Colors.yellow[200], fontSize: 11)),
              ]),
              const Spacer(),
              Text(_totalAmount.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ]),
          ),
        ),
    ]);
  }

  Widget _buildProductsSection() {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search product, SKU, or barcode...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
            : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true, fillColor: Colors.grey[50], contentPadding: const EdgeInsets.symmetric(vertical: 0)),
        onChanged: (value) => setState(() => _searchQuery = value))),
      SizedBox(height: 40, child: ListView.builder(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index]; final isSelected = _selectedCategory == cat;
          return Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(
            label: Text(cat), selected: isSelected,
            onSelected: (selected) => setState(() => _selectedCategory = cat),
            selectedColor: Colors.green[100], checkmarkColor: Colors.green[800],
            labelStyle: TextStyle(fontSize: 12, color: isSelected ? Colors.green[800] : Colors.grey[700])));
        })),
      const SizedBox(height: 8),
      Expanded(child: _filteredProducts.isEmpty
        ? const Center(child: Text('No products found', style: TextStyle(color: Colors.grey)))
        : GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160, childAspectRatio: 0.75, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: _filteredProducts.length,
          itemBuilder: (context, index) {
            return ProductCard(product: _filteredProducts[index], onTap: () => _addToCart(_filteredProducts[index]));
          })),
    ]);
  }

  // ──────────────────────────────────────────────────────────
  // CART SECTION - with transaction discount
  // ──────────────────────────────────────────────────────────
  Widget _buildCartSection() {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[50], border: Border(left: BorderSide(color: Colors.grey[300]!))),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(12), color: Colors.grey[200],
          child: Row(children: [
            const Icon(Icons.shopping_cart, size: 20), const SizedBox(width: 8),
            const Text('Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(12)),
              child: Text('$_totalItems items', style: const TextStyle(color: Colors.white, fontSize: 12))),
          ])),
        Expanded(
          child: _cart.isEmpty
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 8), Text('Cart is empty', style: TextStyle(color: Colors.grey)),
                Text('Tap a product to add', style: TextStyle(color: Colors.grey, fontSize: 12))]))
            : ListView.builder(itemCount: _cart.length, itemBuilder: (context, index) {
                return CartItemWidget(
                  cartItem: _cart[index],
                  onIncrement: () => _incrementItem(index),
                  onDecrement: () => _decrementItem(index),
                  onRemove: () => _removeItem(index),
                  onDiscount: () => _showItemDiscountDialog(index),
                  onTap: () => _addToCart(_cart[index].product));
              }),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.grey.withAlpha(50), blurRadius: 4, offset: const Offset(0, -2))]),
          child: Column(children: [
            // Discount Button
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: _cart.isNotEmpty ? _showDiscountSelector : null,
              icon: Icon(_txnDiscount != null ? Icons.discount : Icons.local_offer, size: 18),
              label: Text(_txnDiscount != null ? _txnDiscount!.label : 'Add Discount (SC / PWD / Employee)',
                style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _txnDiscount != null ? Colors.green[700] : Colors.grey[700],
                side: BorderSide(color: _txnDiscount != null ? Colors.green[400]! : Colors.grey[300]!),
                backgroundColor: _txnDiscount != null ? Colors.green[50] : null,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
            const SizedBox(height: 8),
            // Discount Info
            if (_txnDiscount != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  if (_txnDiscount!.name != null)
                    Row(children: [
                      Icon(Icons.person, size: 14, color: Colors.blue[700]), const SizedBox(width: 6),
                      Text(_txnDiscount!.name ?? '', style: TextStyle(fontSize: 11, color: Colors.blue[800])),
                    ]),
                  if (_txnDiscount!.idNumber != null)
                    Row(children: [
                      Icon(Icons.badge, size: 14, color: Colors.blue[700]), const SizedBox(width: 6),
                      Text('ID: ${_txnDiscount!.idNumber}', style: TextStyle(fontSize: 11, color: Colors.blue[800])),
                    ]),
                  if (_txnDiscount!.age != null)
                    Row(children: [
                      Icon(Icons.cake, size: 14, color: Colors.blue[700]), const SizedBox(width: 6),
                      Text('Age: ${_txnDiscount!.age}', style: TextStyle(fontSize: 11, color: Colors.blue[800])),
                    ]),
                ]),
              ),
              const SizedBox(height: 6),
            ],
            // Subtotal
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Subtotal:', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              Text(_cartSubtotal.toStringAsFixed(2), style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            ]),
            // Item Discount
            if (_itemDiscountTotal > 0)
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Item Discount:', style: TextStyle(color: Colors.red[400], fontSize: 12)),
                Text('-${_itemDiscountTotal.toStringAsFixed(2)}', style: TextStyle(color: Colors.red[400], fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            // Transaction Discount
            if (_txnDiscountAmount > 0)
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${_txnDiscount!.type} Discount:', style: const TextStyle(color: Colors.red, fontSize: 12)),
                Text('-${_txnDiscountAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ]),
            const Divider(height: 12),
            // Total
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('TOTAL:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(_totalAmount.toStringAsFixed(2),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
            ]),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: _cart.isNotEmpty ? _processPayment : null,
                icon: const Icon(Icons.payment),
                label: const Text('PAY NOW', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ]),
        ),
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────
  // CART BOTTOM SHEET (mobile)
  // ──────────────────────────────────────────────────────────
  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4, expand: false,
              builder: (context, scrollController) {
                return Column(children: [
                  Container(margin: const EdgeInsets.only(top: 8), width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                    const Text('Shopping Cart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(), Text('$_totalItems items'),
                  ])),
                  const Divider(height: 1),
                  Expanded(child: ListView.builder(
                    controller: scrollController, itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      return CartItemWidget(
                        cartItem: _cart[index],
                        onIncrement: () { _incrementItem(index); setSheetState(() {}); },
                        onDecrement: () { _decrementItem(index); setSheetState(() {}); if (_cart.isEmpty) Navigator.pop(ctx); },
                        onRemove: () { _removeItem(index); setSheetState(() {}); if (_cart.isEmpty) Navigator.pop(ctx); },
                        onDiscount: () { _showItemDiscountDialog(index); },
                        onTap: () { Navigator.pop(ctx); _addToCart(_cart[index].product); });
                    },
                  )),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.grey.withAlpha(50), blurRadius: 4, offset: const Offset(0, -2))]),
                    child: Column(children: [
                      // Discount button
                      SizedBox(width: double.infinity, child: OutlinedButton.icon(
                        onPressed: () { Navigator.pop(ctx); _showDiscountSelector(); },
                        icon: Icon(_txnDiscount != null ? Icons.discount : Icons.local_offer, size: 16),
                        label: Text(_txnDiscount != null ? _txnDiscount!.label : 'Add Discount',
                          style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _txnDiscount != null ? Colors.green[700] : Colors.grey[700],
                          side: BorderSide(color: _txnDiscount != null ? Colors.green[400]! : Colors.grey[300]!),
                          backgroundColor: _txnDiscount != null ? Colors.green[50] : null,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
                      const SizedBox(height: 8),
                      // Discount breakdown
                      if (_txnDiscountAmount > 0)
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('${_txnDiscount!.type} Disc:', style: const TextStyle(color: Colors.red, fontSize: 12)),
                          Text('-${_txnDiscountAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Total', style: TextStyle(fontSize: 12)),
                          Text(_totalAmount.toStringAsFixed(2),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                        ]),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () { Navigator.pop(ctx); _processPayment(); },
                          icon: const Icon(Icons.payment), label: const Text('PAY NOW'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
                      ]),
                    ]),
                  ),
                ]);
              },
            );
          },
        );
      },
    );
  }
}
