import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/settings_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/product_model.dart';
import '../../models/batch_model.dart';
import '../../utils/approver_pin_dialog.dart';
import 'delivery_model.dart';
import '../../helpers/database_helper.dart';
import "../../services/branch_inventory_service.dart";
import "../../services/device_assignment_service.dart";
import "../../services/firebase_config_service.dart";
import "../../services/firebase_realtime_service.dart";

class ReceiveDeliveryScreen extends StatefulWidget {
  final List<Product> products;
  final DeliveryRecord? existingDraft; const ReceiveDeliveryScreen({super.key, required this.products, this.existingDraft});
  @override
  State<ReceiveDeliveryScreen> createState() => _ReceiveDeliveryScreenState();
}

class _BatchEntry {
  final batchCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  DateTime? mfgDate;
  DateTime? expDate;
  int get qty => int.tryParse(qtyCtrl.text) ?? 0;
  void dispose() { batchCtrl.dispose(); qtyCtrl.dispose(); }
}

class _DeliveryItem {
  Product product;
  TextEditingController qtyController;
  List<_BatchEntry> batches;
  _DeliveryItem({required this.product}) : qtyController = TextEditingController(), batches = [];
  int get totalBatchQty => batches.fold(0, (s, b) => s + b.qty);
  void updateQtyFromBatches() { final t = totalBatchQty; qtyController.text = t > 0 ? t.toString() : ''; }
}

class _ReceiveDeliveryScreenState extends State<ReceiveDeliveryScreen> {
  // ═══ RESPONSIVE HELPERS (matches Inventory module) ═══
  double _scale() {
    final w = MediaQuery.of(context).size.width;
    return (w / 400).clamp(0.85, 1.8);
  }
  double _rs(double size) => size * _scale();

  // ═══ NUMBER FORMATTING (matches Inventory) ═══
  String _fmtInt(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  // ═══ BRANCH IDENTITY (matches Inventory header) ═══
  String _branchNameDisplay = "";
  String _companyCodeDisplay = "";

  final _refCtrl = TextEditingController();

  // ═══ PHASE B2: Branch-Aware Stock Cache ═══
  Map<String, int> _branchStock = {};
  String _binvBranchId = "";
  bool _binvLoaded = false;

  Future<void> _loadBranchStock() async {
    try {
      final assign = await DeviceAssignmentService().read();
      final bid = (assign["branchId"] ?? "").toString();
      _binvBranchId = bid;
      if (bid.isEmpty) {
        print("[RCV-B2] no branchId, fallback to global");
        if (mounted) setState(() => _binvLoaded = true);
        return;
      }
      final map = await BranchInventoryService.getStockMapForBranch(bid);
      if (!mounted) return;
      setState(() { _branchStock = map; _binvLoaded = true; });
      print("[RCV-B2] loaded ${map.length} products for branch=$bid");
    } catch (e) {
      print("[RCV-B2] ERROR: $e");
      if (mounted) setState(() => _binvLoaded = true);
    }
  }

  int _stockOf(Product p) {
    if (!_binvLoaded) return p.stockQty;
    if (_binvBranchId.isNotEmpty) return _branchStock[p.id] ?? 0;
    return p.stockQty;
  }

  @override
  void initState() {
    super.initState();
    _loadBranchStock();
    _loadExistingDraft();
    // ═══ Load branch identity (matches Inventory pattern) ═══
    () async {
      final assign = await DeviceAssignmentService().read();
      if (mounted) {
        setState(() {
          _branchNameDisplay = (assign["branchName"] ?? "").toString();
          _companyCodeDisplay = (assign["companyCode"] ?? "").toString();
        });
      }
    }();
  }
  // ═══ END PHASE B2 ═══

  void _loadExistingDraft() {
    final draft = widget.existingDraft;
    if (draft == null) return;

    _refCtrl.text = draft.refNumber;
    _supplierCtrl.text = draft.supplier;
    _driverCtrl.text = draft.driverName;
    _plateCtrl.text = draft.plateNumber;
    _receivedByCtrl.text = draft.receivedBy;
    _notesCtrl.text = draft.notes;

    for (final itemRec in draft.items) {
      Product? product;
      for (final p in widget.products) {
        if (p.id == itemRec.productId || p.sku == itemRec.sku) {
          product = p;
          break;
        }
      }
      if (product == null) continue;

      // ═══ GROUP BY SKU: reuse existing item or create new ═══
      final existingIdx = _items.indexWhere((x) => x.product.id == product!.id);
      _DeliveryItem di;
      if (existingIdx >= 0) {
        di = _items[existingIdx];
      } else {
        di = _DeliveryItem(product: product);
        di.qtyController.addListener(() => setState(() {}));
        _items.add(di);
      }

      // Add batch to the item (either new or existing)
      if (itemRec.batchNumber.isNotEmpty) {
        final batch = _BatchEntry();
        batch.batchCtrl.text = itemRec.batchNumber;
        batch.qtyCtrl.text = itemRec.quantity.toString();
        try {
          if (itemRec.mfgDate.isNotEmpty) batch.mfgDate = DateTime.parse(itemRec.mfgDate);
        } catch (_) {}
        try {
          if (itemRec.expDate.isNotEmpty) batch.expDate = DateTime.parse(itemRec.expDate);
        } catch (_) {}
        di.batches.add(batch);
      }

      // Update total qty from all batches
      di.updateQtyFromBatches();
    }

    if (mounted) setState(() {});
  }

  final _supplierCtrl = TextEditingController();
  final _driverCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _receivedByCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final List<_DeliveryItem> _items = [];
  String _searchQuery = '';
  bool _headerExpanded = true;

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return [];
    return widget.products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || p.sku.toLowerCase().contains(_searchQuery.toLowerCase()) || p.barcode.contains(_searchQuery)).toList();
  }

  int get _totalQty => _items.fold(0, (s, i) => s + (int.tryParse(i.qtyController.text) ?? 0));
  double get _totalCost => _items.fold(0.0, (s, i) => s + (int.tryParse(i.qtyController.text) ?? 0) * i.product.costPrice);
  double get _totalRetail => _items.fold(0.0, (s, i) => s + (int.tryParse(i.qtyController.text) ?? 0) * i.product.sellingPrice);

  void _addItem(Product p) {
    final existingIdx = _items.indexWhere((i) => i.product.id == p.id);
    if (existingIdx >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Adding another batch to ${p.name}'), backgroundColor: Colors.blue, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)));
      WidgetsBinding.instance.addPostFrameCallback((_) { _showBatchPopup(existingIdx); });
      return;
    }
    final di = _DeliveryItem(product: p);
    di.qtyController.addListener(() => setState(() {}));
    _items.add(di); setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) { _showBatchPopup(_items.length - 1); });
  }

  void _removeItem(int i) { setState(() { for (var b in _items[i].batches) { b.dispose(); } _items[i].qtyController.dispose(); _items.removeAt(i); }); }

  // ═══ PHASE 2B: Product Picker Modal (real implementation) ═══
  void _showAddItemModal() {
    final searchCtrl = TextEditingController();
    String localQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filtered = widget.products.where((p) {
            {
              if (localQuery.isEmpty) return true;
              final q = localQuery.toLowerCase();
              return p.name.toLowerCase().contains(q) ||
                     p.sku.toLowerCase().contains(q) ||
                     p.barcode.toLowerCase().contains(q);
            }
            return false;
          }).toList();

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Select Product',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: 'Search by name, SKU, barcode...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search, color: Colors.orange[700], size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (v) => setModalState(() => localQuery = v),
                  ),
                ),
                // Product list - SKU + Name only
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            localQuery.isEmpty ? 'All products added' : 'No matches found',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                          itemBuilder: (_, i) {
                            final p = filtered[i];
                            return ListTile(
                              onTap: () {
                                Navigator.pop(ctx);
                                _addItem(p);
                              },
                              leading: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.sku,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  Future<void> _showBatchPopup(int itemIndex) async {
    final item = _items[itemIndex];
    final List<_BatchEntry> workingBatches = [];
    for (final b in item.batches) { final copy = _BatchEntry(); copy.batchCtrl.text = b.batchCtrl.text; copy.qtyCtrl.text = b.qtyCtrl.text; copy.mfgDate = b.mfgDate; copy.expDate = b.expDate; workingBatches.add(copy); }
    if (workingBatches.isEmpty) workingBatches.add(_BatchEntry());
    final result = await showDialog<List<_BatchEntry>>(context: context, barrierDismissible: false,
      builder: (ctx) => _BatchPopupDialog(productName: item.product.name, productSku: item.product.sku, batches: workingBatches));
    if (result != null) { for (var b in item.batches) { b.dispose(); } item.batches = result; item.updateQtyFromBatches(); setState(() {}); }
    else { for (var b in workingBatches) { b.dispose(); } }
  }

  Future<void> _saveDelivery() async {
    if (_refCtrl.text.trim().isEmpty) { _snack('Please enter DR / Reference #'); return; }
    if (_items.isEmpty) { _snack('Please add at least one item'); return; }
    for (final item in _items) {
      if (item.batches.isEmpty || item.totalBatchQty <= 0) { _snack('${item.product.name}: Please add batch details'); return; }
      for (final b in item.batches) {
        if (b.batchCtrl.text.trim().isEmpty) { _snack('${item.product.name}: Batch number required'); return; }
        if (b.mfgDate == null || b.expDate == null) { _snack('${item.product.name}: MFG and EXP dates required for batch ${b.batchCtrl.text}'); return; }
        if (b.expDate!.isBefore(b.mfgDate!)) { _snack('${item.product.name}: EXP cannot be before MFG'); return; }
        if (b.qty <= 0) { _snack('${item.product.name}: Batch ${b.batchCtrl.text} qty must be > 0'); return; }
      }
    }
    try {
      final List<DeliveryItemRecord> recs = [];
      final updated = List<Product>.from(widget.products);
      int totalItems = 0; double tCost = 0, tRetail = 0; int tQty = 0;
      final refNumber = _refCtrl.text.trim(); final now = DateTime.now();
      for (var item in _items) {
        final qty = item.totalBatchQty;
        if (qty > 0) {
          totalItems++; tQty += qty; tCost += qty * item.product.costPrice; tRetail += qty * item.product.sellingPrice;
          final idx = updated.indexWhere((p) => p.id == item.product.id);
          if (idx >= 0) {
            final old = updated[idx]; final ns = old.stockQty + qty;
            // ═══ PHASE B2: Branch-Aware Stock Increment (Dual Write) ═══
            try {
              final assign = await DeviceAssignmentService().read();
              final bid = (assign["branchId"] ?? "").toString();
              if (bid.isNotEmpty) {
                final ok = await BranchInventoryService.incrementStock(bid, old.id, qty);
                print("[RCV-B2] +$qty to ${old.name} branch=$bid ok=$ok");
              } else {
                print("[RCV-B2] no branchId, BINV increment SKIPPED");
              }
            } catch (e) {
              print("[RCV-B2] ERROR in BINV increment: $e");
            }
            // ═══ END PHASE B2 ═══
            for (final be in item.batches) {
              if (be.qty <= 0) continue;
              recs.add(DeliveryItemRecord(productId: old.id, itemName: old.name, sku: old.sku, quantity: be.qty, oldStock: old.stockQty, newStock: ns, cost: old.costPrice, retail: old.sellingPrice, batchNumber: be.batchCtrl.text.trim(), mfgDate: be.mfgDate != null ? _fmtDateISO(be.mfgDate!) : '', expDate: be.expDate != null ? _fmtDateISO(be.expDate!) : ''));
            }
            updated[idx] = Product(id: old.id, sku: old.sku, name: old.name, category: old.category, unit: old.unit, costPrice: old.costPrice, sellingPrice: old.sellingPrice, stockQty: ns, reorderLevel: old.reorderLevel, barcode: old.barcode, imagePath: old.imagePath, imageUrl: old.imageUrl);
          }
          for (final be in item.batches) {
            if (be.qty <= 0) continue;
            final batchNum = be.batchCtrl.text.trim();
            final existingIdx = ProductBatch.allBatches.indexWhere((b) => b.productId == item.product.id && b.batchNumber == batchNum);
            if (existingIdx >= 0) { final existing = ProductBatch.allBatches[existingIdx]; ProductBatch.updateBatch(existing.id, existing.copyWith(quantity: existing.quantity + be.qty)); }
            else { final batchId = 'B-${now.millisecondsSinceEpoch}-${item.product.id}-$batchNum';
              ProductBatch.addBatch(ProductBatch(id: batchId, productId: item.product.id, productName: item.product.name, productSku: item.product.sku, batchNumber: batchNum, manufacturedDate: be.mfgDate!, expiryDate: be.expDate!, quantity: be.qty, originalQty: be.qty, costPrice: item.product.costPrice, supplier: _supplierCtrl.text.trim(), notes: 'DR# $refNumber', dateAdded: now)); }
          }
        }
      }
      // 🏪 Phase 2: Read current branch identity for tagging delivery
      final assign = await DeviceAssignmentService().read();
      final myBranchId = (assign["branchId"] ?? "").toString();
      final myBranchName = (assign["branchName"] ?? "").toString();
      // Build initial record (status set based on user choice below)
      final recordId = widget.existingDraft?.id ?? now.millisecondsSinceEpoch.toString();

      // 💾 Show dialog: Save as Draft OR Submit for Approval
      final choice = await _showSaveOrSubmitDialog(refNumber, _supplierCtrl.text.trim(), totalItems, tQty, tRetail);
      if (choice == null) return; // User cancelled

      final isDraft = choice == 'DRAFT';

      // ═══ USER PIN VERIFICATION for SUBMIT (skip for DRAFT) ═══
      Map<String, dynamic>? pinUser;
      if (!isDraft) {
        pinUser = await _showUserPinDialog();
        if (pinUser == null) return;
      }
      final userName = pinUser?["name"] ?? "";

      final record = DeliveryRecord(
        id: recordId,
        refNumber: refNumber,
        supplier: _supplierCtrl.text.trim(),
        driverName: _driverCtrl.text.trim(),
        plateNumber: _plateCtrl.text.trim(),
        receivedBy: _receivedByCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        items: recs,
        totalItems: totalItems,
        totalQuantity: tQty,
        totalCost: tCost,
        totalRetail: tRetail,
        dateTime: now,
        branchId: myBranchId,
        branchName: myBranchName,
        status: isDraft ? DeliveryStatus.draft : DeliveryStatus.submitted,
        submittedDate: isDraft ? '' : now.toIso8601String(),
        submittedBy: isDraft ? '' : userName,
        lastEditedDate: now.toIso8601String(),
        syncStatus: 'Pending',
      );

      await DeliveryStorage.saveDelivery(record);

      if (isDraft) {
        // Draft: skip Firebase upload + product stock update
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.description_outlined, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Draft saved: ${record.refNumber}')),
            ]),
            backgroundColor: const Color(0xFF7C3AED),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, updated); // back to dashboard
        return;
      }

      // Submitted: Upload to Firebase (branchSubmittedDelivery) + update stocks
      _uploadToSubmittedFirebase(record);
      _logApprovalHistory(record.id, 'Submitted', userName, '');
      for (final u in updated) { Product.updateProduct(u.id, u); }
      _loadBranchStock();
      if (!mounted) return;
      _showPostSaveDialog(record, updated);
    } catch (e) { if (mounted) _snack('Error saving: $e'); }
  }

  // ☁️ PHASE 4: Upload delivery to Firebase under branchReceivedDelivery/{branchId}

  // ═══ WORKFLOW: Save as Draft OR Submit dialog ═══
  Future<String?> _showSaveOrSubmitDialog(String refNumber, String supplier, int totalItems, int totalQty, double totalRetail) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.orange[700],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Save Delivery',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: Column(
                      children: [
                        _summaryRow('DR#:', refNumber.isEmpty ? '-' : refNumber),
                        const SizedBox(height: 6),
                        _summaryRow('Supplier:', supplier.isEmpty ? '-' : supplier),
                        const SizedBox(height: 6),
                        _summaryRow('Items:', '$totalItems'),
                        const SizedBox(height: 6),
                        _summaryRow('Qty:', '${_fmtInt(totalQty)} pcs'),
                        const SizedBox(height: 6),
                        Divider(color: Colors.grey[300], height: 1),
                        const SizedBox(height: 8),
                        _summaryRow('Total @ Retail:', '\u20B1${_fmtInt(totalRetail.toInt())}', bold: true, highlight: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, 'DRAFT'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.description_outlined, color: Color(0xFF7C3AED), size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Save as Draft', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                                  SizedBox(height: 2),
                                  Text('Continue editing later', style: TextStyle(fontSize: 11, color: Color(0xFF7C3AED))),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, color: Color(0xFF7C3AED), size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, 'SUBMIT'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: const [
                            Icon(Icons.send_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Submit for Approval', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                  SizedBox(height: 2),
                                  Text('Requires user PIN verification', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                    child: Text('Cancel', style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ═══ USER PIN VERIFICATION DIALOG ═══
  Future<Map<String, dynamic>?> _showUserPinDialog() async {
    return await showApproverPinDialog(
      context,
      themeColor: Colors.orange.shade700,
      title: 'Verify User',
      subtitle: 'Enter your PIN to submit',
      actionLabel: 'Verify & Submit',
      actionIcon: Icons.check_circle_outline,
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, bool highlight = false}) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: highlight ? Colors.black87 : Colors.grey[700], fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: highlight ? 14 : 12, color: highlight ? Colors.orange[800] : Colors.black87, fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }

  // ═══ WORKFLOW: Upload to branchSubmittedDelivery (Multi-branch tier only) ═══
  Future<void> _uploadToSubmittedFirebase(DeliveryRecord record) async {
    try {
      final cfg = await FirebaseConfigService().load();
      if (cfg == null) {
        debugPrint('[SUBMIT-SYNC] SOLO tier - skip Firebase');
        return;
      }
      final assign = await DeviceAssignmentService().read();
      final companyCode = (assign['companyCode'] ?? '').toString();
      final branchId = (assign['branchId'] ?? '').toString();
      if (companyCode.isEmpty || branchId.isEmpty) {
        debugPrint('[SUBMIT-SYNC] Skip: missing companyCode or branchId');
        return;
      }
      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      final path = 'companies/$companyCode/branchSubmittedDelivery/$branchId/${record.id}';
      await db.ref(path).set(record.toJson());
      debugPrint('[SUBMIT-SYNC] Uploaded to: $path');
    } catch (e) {
      debugPrint('[SUBMIT-SYNC] Error: $e');
    }
  }

  // ═══ WORKFLOW: Log to approval_history (audit trail) ═══
  Future<void> _logApprovalHistory(String deliveryId, String action, String user, String remarks) async {
    try {
      final entry = {
        'id': 'H-${DateTime.now().millisecondsSinceEpoch}',
        'deliveryId': deliveryId,
        'action': action,
        'user': user,
        'date': DateTime.now().toIso8601String(),
        'remarks': remarks,
      };
      await DatabaseHelper().insertApprovalHistory(entry);
      debugPrint('[APPROVAL-HISTORY] Logged: $action for $deliveryId');
    } catch (e) {
      debugPrint('[APPROVAL-HISTORY] Error: $e');
    }
  }

  Future<void> _uploadDeliveryToFirebase(DeliveryRecord record) async {
    try {
      final cfg = await FirebaseConfigService().load();
      if (cfg == null) {
        debugPrint("[DELIVERY-SYNC] FAIL: no config");
        return;
      }
      final assign = await DeviceAssignmentService().read();
      final companyCode = (assign["companyCode"] ?? "").toString();
      final branchId = (assign["branchId"] ?? "").toString();
      if (companyCode.isEmpty || branchId.isEmpty) {
        debugPrint("[DELIVERY-SYNC] FAIL: companyCode or branchId empty");
        return;
      }
      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) {
        debugPrint("[DELIVERY-SYNC] FAIL: db NULL");
        return;
      }
      final path = "companies/$companyCode/branchReceivedDelivery/$branchId/${record.id}";
      await db.ref(path).set(record.toJson());
      debugPrint("[DELIVERY-SYNC] SUCCESS: $path");
    } catch (e) {
      debugPrint("[DELIVERY-SYNC] EXCEPTION: $e");
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  String _pad(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  String _fmtDateISO(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

  void _showPostSaveDialog(DeliveryRecord r, List<Product> up) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 30), SizedBox(width: 10), Expanded(child: Text('Delivery Saved!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('DR#: ${r.refNumber}\n${r.totalItems} items  |  +${r.totalQuantity} pcs\nCost: ${r.totalCost.toStringAsFixed(2)}\nRetail: ${r.totalRetail.toStringAsFixed(2)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.5)),
        const SizedBox(height: 20),
        
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.check), label: const Text('Done'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () { Navigator.pop(ctx); Navigator.pop(context, up); })),
      ])));
  }

  Widget _dlgBtn(IconData ic, String lbl, Color bg, VoidCallback onTap) => SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: Icon(ic, color: Colors.white), label: Text(lbl, style: const TextStyle(color: Colors.white)),
    style: ElevatedButton.styleFrom(backgroundColor: bg, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: onTap));

  pw.Document _buildA4Pdf(DeliveryRecord r) {
    final pdf = pw.Document();
    final date = '${r.dateTime.year}-${_pad(r.dateTime.month)}-${_pad(r.dateTime.day)}';
    final time = '${_pad(r.dateTime.hour)}:${_pad(r.dateTime.minute)}:${_pad(r.dateTime.second)}';

    // Page 1: TRUCKER COPY
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(8 * PdfPageFormat.mm),
      build: (ctx) => _buildPdfPageContent(r, date, time, "TRUCKER COPY"),
    ));

    // Page 2: STORE COPY (For BIR Audit)
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(8 * PdfPageFormat.mm),
      build: (ctx) => _buildPdfPageContent(r, date, time, "STORE COPY"),
    ));

    return pdf;
  }

  List<pw.Widget> _buildPdfPageContent(DeliveryRecord r, String date, String time, String copyLabel) {
    // Group items by itemName + sku
    final Map<String, List<DeliveryItemRecord>> grouped = {};
    for (final item in r.items) {
      final key = '${item.itemName}||${item.sku}';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    // Build item table rows
    final List<pw.TableRow> itemTableRows = [];

    // Header row
    itemTableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blue700),
        children: [
          _pdfTableCell('#', bold: true, color: PdfColors.white, align: pw.Alignment.center),
          _pdfTableCell('Description', bold: true, color: PdfColors.white),
          _pdfTableCell('Qty', bold: true, color: PdfColors.white, align: pw.Alignment.centerRight),
          _pdfTableCell('Unit Retail', bold: true, color: PdfColors.white, align: pw.Alignment.centerRight),
          _pdfTableCell('Total @ Retail', bold: true, color: PdfColors.white, align: pw.Alignment.centerRight),
        ],
      ),
    );

    int itemNumber = 0;
    grouped.forEach((key, batches) {
      itemNumber++;
      final parts = key.split('||');
      final itemName = parts[0];
      final sku = parts[1];

      // Item header row (product name)
      itemTableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _pdfTableCell('$itemNumber', bold: true, align: pw.Alignment.center),
            _pdfTableCell('$itemName  ($sku)', bold: true),
            _pdfTableCell('', align: pw.Alignment.centerRight),
            _pdfTableCell('', align: pw.Alignment.centerRight),
            _pdfTableCell('', align: pw.Alignment.centerRight),
          ],
        ),
      );

      // Batch rows
      int itemQtyTotal = 0;
      double itemRetailTotal = 0;
      for (final b in batches) {
        itemTableRows.add(
          pw.TableRow(
            children: [
              _pdfTableCell(''),
              _pdfTableCell(
                '   Batch: ${b.batchNumber.isEmpty ? "-" : b.batchNumber}    MFG: ${b.mfgDate.isEmpty ? "-" : b.mfgDate}    EXP: ${b.expDate.isEmpty ? "-" : b.expDate}',
              ),
              _pdfTableCell(_fmtMoney(b.quantity.toDouble()), align: pw.Alignment.centerRight),
              _pdfTableCell(b.retail.toStringAsFixed(2), align: pw.Alignment.centerRight),
              _pdfTableCell(_fmtMoney(b.retail * b.quantity), align: pw.Alignment.centerRight),
            ],
          ),
        );
        itemQtyTotal += b.quantity;
        itemRetailTotal += b.retail * b.quantity;
      }

      // Item Subtotal (blue accent)
      itemTableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            _pdfTableCell(''),
            _pdfTableCell('   ITEM SUBTOTAL', bold: true, color: PdfColors.blue800),
            _pdfTableCell(_fmtMoney(itemQtyTotal.toDouble()), bold: true, color: PdfColors.blue800, align: pw.Alignment.centerRight),
            _pdfTableCell('-', bold: true, color: PdfColors.blue800, align: pw.Alignment.centerRight),
            _pdfTableCell(_fmtMoney(itemRetailTotal), bold: true, color: PdfColors.blue800, align: pw.Alignment.centerRight),
          ],
        ),
      );
    });

    // Fallback if no items
    if (grouped.isEmpty) {
      itemTableRows.add(
        pw.TableRow(
          children: [
            _pdfTableCell('-', align: pw.Alignment.center),
            _pdfTableCell('No items'),
            _pdfTableCell('-', align: pw.Alignment.centerRight),
            _pdfTableCell('-', align: pw.Alignment.centerRight),
            _pdfTableCell('-', align: pw.Alignment.centerRight),
          ],
        ),
      );
    }

    // Branch name (uppercase, fallback to DELIVERY)
    final branchName = _branchNameDisplay.isEmpty ? 'DELIVERY' : _branchNameDisplay.toUpperCase();

    return [
        // ═══ COPY LABEL BANNER (Blue bordered box) ═══
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blue700, width: 1.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue700,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Text(
                      'DR',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    copyLabel,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue700, width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Text(
                  'Serial: DR-${r.refNumber}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        // ═══ COMPACT BLUE BANNER (title + BIR in one box) ═══
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: const pw.BoxDecoration(color: PdfColors.blue700),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                '$branchName - DELIVERY RECEIVING REPORT',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 1,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'TIN: TO-BE-ASSIGNED   |   MIN: TO-BE-ASSIGNED   |   PTU: TO-BE-ASSIGNED',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.white),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 1, color: PdfColors.blue700),
        pw.SizedBox(height: 6),

        // ═══ DOCUMENT INFO (3-column with icon prefixes) ═══
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfInfoRow('Date', date),
                  _pdfInfoRow('Time', time),
                  _pdfInfoRow('DR #', r.refNumber),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfInfoRow('Supplier', r.supplier.isEmpty ? '-' : r.supplier),
                  _pdfInfoRow('Driver', r.driverName.isEmpty ? '-' : r.driverName),
                  _pdfInfoRow('Plate #', r.plateNumber.isEmpty ? '-' : r.plateNumber),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfInfoRow('Received By', r.receivedBy.isEmpty ? '-' : r.receivedBy),
                  _pdfInfoRow('Total Items', '${grouped.length}'),
                  _pdfInfoRow('Total Qty', _fmtMoney(r.totalQuantity.toDouble()) + ' pcs'),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 1, color: PdfColors.blue700),
        pw.SizedBox(height: 6),

        // ═══ ITEMS TABLE (Custom-built with pw.Table) ═══
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(30),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FixedColumnWidth(70),
            3: const pw.FixedColumnWidth(65),
            4: const pw.FixedColumnWidth(85),
          },
          children: itemTableRows,
        ),
        pw.SizedBox(height: 10),

        // ═══ SUMMARY (Two-box layout: Totals + Grand Total) ═══
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            // Left box: Totals
            pw.Container(
              width: 180,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue700, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Items:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('${grouped.length}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Qty:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('${_fmtMoney(r.totalQuantity.toDouble())} pcs', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 10),
            // Right box: Grand Total (dark accent)
            pw.Container(
              width: 250,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue900, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'GRAND TOTAL @ RETAIL',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue900,
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'PHP ${_fmtMoney(r.totalRetail)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ═══ NOTES (if any) ═══
        if (r.notes.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              'Notes: ${r.notes}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],

        pw.SizedBox(height: 20),

        // ═══ SIGNATURES (Formal 3-column with labels) ═══
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _pdfSignatureBlock('Received By'),
            _pdfSignatureBlock('Checked By'),
            _pdfSignatureBlock('Approved By'),
          ],
        ),
        pw.SizedBox(height: 10),

        // ═══ FOOTER (Blue accent bar) ═══
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.blue700, width: 1),
            ),
          ),
          child: pw.Center(
            child: pw.Text(
              'System-generated  |  Accreditation: PENDING  |  Machine ID: TO-BE-ASSIGNED',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
    ];
  }

  // Helper: Table cell builder
  static pw.Widget _pdfTableCell(String text, {bool bold = false, PdfColor color = PdfColors.black, pw.Alignment align = pw.Alignment.centerLeft}) {
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  // Helper: Format money with commas
  static String _fmtMoney(double n) {
    final str = n.toStringAsFixed(2);
    final parts = str.split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final formatted = intPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$formatted.$decPart';
  }

  // Helper: Signature block with formal styling
  static pw.Widget _pdfSignatureBlock(String label) {
    return pw.Container(
      width: 200,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 12,
                height: 12,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 25),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.blue700, width: 1.5),
              ),
            ),
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              'Name / Signature / Date',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfInfoRow(String l, String v) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1), child: pw.Row(children: [pw.SizedBox(width: 70, child: pw.Text('$l:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))), pw.Text(v, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))]));
  static pw.Widget _pdfSignature(String l) => pw.Column(children: [pw.SizedBox(height: 30), pw.Container(width: 140, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey600))), child: pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Text(l, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)))))]);

  Future<void> _printA4(DeliveryRecord r, List<Product> up) async { final pdf = _buildA4Pdf(r); await Printing.layoutPdf(onLayout: (_) async => pdf.save(), name: 'DR_${r.refNumber}'); if (mounted) Navigator.pop(context, up); }
  Future<void> _savePdf(DeliveryRecord r, List<Product> up) async { final pdf = _buildA4Pdf(r); await Printing.sharePdf(bytes: await pdf.save(), filename: 'DR_${r.refNumber}.pdf'); if (mounted) Navigator.pop(context, up); }

  @override
  void dispose() { _refCtrl.dispose(); _supplierCtrl.dispose(); _driverCtrl.dispose(); _plateCtrl.dispose(); _receivedByCtrl.dispose(); _notesCtrl.dispose(); _searchCtrl.dispose();
    for (var i in _items) { for (var b in i.batches) { b.dispose(); } i.qtyController.dispose(); } super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final activeItems = _items.where((i) => (int.tryParse(i.qtyController.text) ?? 0) > 0).length;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_shipping,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    "New Delivery • ${activeItems} ${activeItems == 1 ? 'Item' : 'Items'}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveDelivery,
            icon: const Icon(Icons.save_rounded, color: Colors.white, size: 20),
            label: const Text(
              'SAVE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            width: double.infinity,
            color: Colors.orange[700],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'DR#: ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Flexible(
                  child: Text(
                    _refCtrl.text.isEmpty ? '\u2014' : _refCtrl.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'DRAFT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
      body: Column(children: [
        Container(decoration: BoxDecoration(color: Colors.white),
          child: Column(children: [
            InkWell(onTap: () => setState(() => _headerExpanded = !_headerExpanded),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Row(children: [
                Icon(Icons.description_outlined, color: Colors.orange[700], size: 22), const SizedBox(width: 8),
                Text('Delivery Information', style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.bold)),
                const Spacer(),
                const SizedBox.shrink(),
                const SizedBox(width: 8), Icon(_headerExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white70, size: 20)]))),
            AnimatedCrossFade(duration: const Duration(milliseconds: 250), crossFadeState: _headerExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond, secondChild: const SizedBox.shrink(),
              firstChild: Container(padding: const EdgeInsets.fromLTRB(12, 12, 12, 12), child: Column(children: [
                Row(children: [Expanded(child: _proField(_refCtrl, 'DR # / Reference *', Icons.receipt)), const SizedBox(width: 8), Expanded(child: _proField(_supplierCtrl, 'Supplier', Icons.business))]),
                const SizedBox(height: 8),
                Row(children: [Expanded(child: _proField(_driverCtrl, 'Driver', Icons.person_outline)), const SizedBox(width: 8), Expanded(child: _proField(_plateCtrl, 'Plate #', Icons.directions_car_outlined))]),
                const SizedBox(height: 8),
                Row(children: [Expanded(child: _proField(_receivedByCtrl, 'Received By', Icons.assignment_ind_outlined)), const SizedBox(width: 8), Expanded(child: _proField(_notesCtrl, 'Notes / Remarks', Icons.note_outlined))])]))),
          ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)), child: Icon(Icons.list_alt_rounded, size: 16, color: Colors.blue[700])),
          const SizedBox(width: 8), Text('Delivery Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800])), const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.blue[700], borderRadius: BorderRadius.circular(10)), child: Text('${_items.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          const Spacer(), Material(color: Colors.orange[700], borderRadius: BorderRadius.circular(20), child: InkWell(onTap: _showAddItemModal, borderRadius: BorderRadius.circular(20), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add, color: Colors.white, size: 16), SizedBox(width: 4), Text('ADD ITEM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5))]))))])),
        Expanded(child: _items.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle), child: Icon(Icons.local_shipping_outlined, size: 48, color: Colors.blue[200])),
              const SizedBox(height: 12), Text('No items added yet', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
              const SizedBox(height: 4), Text('Search and add products above', style: TextStyle(color: Colors.grey[400], fontSize: 12))]))
          : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), itemCount: _items.length, itemBuilder: (_, i) {
              final item = _items[i]; final qty = int.tryParse(item.qtyController.text) ?? 0; final lc = qty * item.product.costPrice; final lr = qty * item.product.sellingPrice; final hasBatches = item.batches.isNotEmpty && item.totalBatchQty > 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasBatches ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                    width: hasBatches ? 0.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showBatchPopup(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.product.sku,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: hasBatches ? Colors.green : Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            hasBatches ? '${_fmtInt(qty)} pcs' : 'TAP',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: hasBatches ? Colors.white : Colors.orange[800],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _removeItem(i),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.close, color: Colors.red[400], size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })),
        if (_items.isNotEmpty) Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1))),
          child: Row(
            children: [
              _summaryColumn(Icons.inventory_2, 'Items', '$activeItems'),
              _summaryDivider(),
              _summaryColumn(Icons.add_box, 'Qty', '${_fmtInt(_totalQty)} pcs'),
              _summaryDivider(),
              _summaryColumn(Icons.sell, 'Retail', '\u20B1${_fmtInt(_totalRetail.toInt())}'),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _proField(TextEditingController c, String label, IconData ic) => TextField(
    controller: c,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
      prefixIcon: Icon(ic, size: 18, color: Colors.orange[700]),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.orange[700]!, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
    ),
  );

  Widget _chip(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color.withOpacity(0.8))));

  Widget _summaryColumn(IconData ic, String label, String value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ic, size: 13, color: Colors.orange[700]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.grey[300],
    );
  }

}

class _BatchPopupDialog extends StatefulWidget {
  final String productName; final String productSku; final List<_BatchEntry> batches;
  const _BatchPopupDialog({required this.productName, required this.productSku, required this.batches});
  @override
  State<_BatchPopupDialog> createState() => _BatchPopupDialogState();
}

class _BatchPopupDialogState extends State<_BatchPopupDialog> {
  late List<_BatchEntry> _batches;
  @override
  void initState() { super.initState(); _batches = widget.batches; for (var b in _batches) { b.qtyCtrl.addListener(() => setState(() {})); } }
  int get _totalQty => _batches.fold(0, (s, b) => s + b.qty);
  void _addBatch() { final e = _BatchEntry(); e.qtyCtrl.addListener(() => setState(() {})); setState(() => _batches.add(e)); }
  void _removeBatch(int i) { setState(() { _batches[i].dispose(); _batches.removeAt(i); }); }
  Future<void> _pickDate(BuildContext context, _BatchEntry entry, bool isMfg) async {
    final initial = isMfg ? (entry.mfgDate ?? DateTime.now()) : (entry.expDate ?? DateTime.now().add(const Duration(days: 365)));
    final first = isMfg ? DateTime(2020) : (entry.mfgDate ?? DateTime(2020));
    final last = isMfg ? DateTime.now().add(const Duration(days: 365)) : DateTime(2040);
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
    if (picked != null) { setState(() { if (isMfg) { entry.mfgDate = picked; } else { entry.expDate = picked; } }); }
  }
  String? _validate() {
    if (_batches.isEmpty) return 'Add at least one batch';
    for (int i = 0; i < _batches.length; i++) { final b = _batches[i];
      if (b.batchCtrl.text.trim().isEmpty) return 'Batch #${i + 1}: Number required';
      if (b.mfgDate == null) return 'Batch #${i + 1}: MFG date required'; if (b.expDate == null) return 'Batch #${i + 1}: EXP date required';
      if (b.expDate!.isBefore(b.mfgDate!)) return 'Batch #${i + 1}: EXP before MFG'; if (b.qty <= 0) return 'Batch #${i + 1}: Qty must be > 0'; }
    return null;
  }
  void _save() { final err = _validate(); if (err != null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red)); return; } Navigator.pop(context, _batches); }
  String _fmtD(DateTime? d) => d == null ? 'Select' : '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Dialog(insetPadding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85, maxWidth: MediaQuery.of(context).size.width < 600 ? MediaQuery.of(context).size.width * 0.95 : MediaQuery.of(context).size.width < 1024 ? 700 : MediaQuery.of(context).size.width < 1440 ? 900 : 1100),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFE65100), Color(0xFFEF6C00)]), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(children: [const Icon(Icons.inventory_2, color: Colors.white), const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Batch Encoding', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text('${widget.productName} (${widget.productSku})', style: const TextStyle(color: Colors.white70, fontSize: 12))])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)), child: Text('Total: $_totalQty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)))])),
          Flexible(child: ListView.builder(shrinkWrap: true, padding: const EdgeInsets.all(12), itemCount: _batches.length,
            itemBuilder: (_, i) { final b = _batches[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = MediaQuery.of(context).size.width > 600;
                      // Field widgets (reusable)
                      final batchField = TextField(
                        controller: b.batchCtrl,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Batch Number *',
                          isDense: true,
                          prefixIcon: const Icon(Icons.tag, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                      );
                      final qtyField = TextField(
                        controller: b.qtyCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: 'Qty *',
                          isDense: true,
                          prefixIcon: const Icon(Icons.numbers, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                      );
                      final mfgField = InkWell(
                        onTap: () => _pickDate(context, b, true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'MFG Date *',
                            isDense: true,
                            prefixIcon: Icon(Icons.calendar_today, size: 16, color: Colors.green[700]),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                          child: Text(
                            _fmtD(b.mfgDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: b.mfgDate != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                      );
                      final expField = InkWell(
                        onTap: () => _pickDate(context, b, false),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'EXP Date *',
                            isDense: true,
                            prefixIcon: Icon(Icons.event_busy, size: 16, color: Colors.red[700]),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                          child: Text(
                            _fmtD(b.expDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: b.expDate != null
                                  ? (b.expDate!.isBefore(DateTime.now()) ? Colors.red : Colors.black87)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      );

                      return Column(
                        children: [
                          // Header row (always horizontal)
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.orange[100],
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('Batch ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const Spacer(),
                              if (_batches.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _removeBatch(i),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // All 4 fields (responsive: 1 row on big screen, stacked on small)
                          if (isWide)
                            Row(children: [
                              Expanded(flex: 3, child: batchField),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: qtyField),
                              const SizedBox(width: 8),
                              Expanded(flex: 3, child: mfgField),
                              const SizedBox(width: 8),
                              Expanded(flex: 3, child: expField),
                            ])
                          else ...[
                            batchField,
                            const SizedBox(height: 8),
                            qtyField,
                            const SizedBox(height: 8),
                            mfgField,
                            const SizedBox(height: 8),
                            expField,
                          ],
                        ],
                      );
                    },
                  ),
                ),
              );
            })),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add Batch'), style: OutlinedButton.styleFrom(foregroundColor: Colors.orange[700], side: BorderSide(color: Colors.orange[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _addBatch)),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, null), style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Cancel'))),
                const SizedBox(width: 10), Expanded(flex: 2, child: ElevatedButton.icon(icon: const Icon(Icons.check), label: Text('Save Batches ($_totalQty pcs)'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _save))])])),
        ])));
  }
}
