import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/settings_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/product_model.dart';
import '../../models/batch_model.dart';
import 'delivery_model.dart';
import 'delivery_history_screen.dart';
import "../../services/branch_inventory_service.dart";
import "../../services/device_assignment_service.dart";
import "../../services/firebase_config_service.dart";
import "../../services/firebase_realtime_service.dart";

class ReceiveDeliveryScreen extends StatefulWidget {
  final List<Product> products;
  const ReceiveDeliveryScreen({super.key, required this.products});
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
  }
  // ═══ END PHASE B2 ═══

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
    if (_items.any((i) => i.product.id == p.id)) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p.name} already added'), behavior: SnackBarBehavior.floating)); return; }
    final di = _DeliveryItem(product: p);
    di.qtyController.addListener(() => setState(() {}));
    _items.add(di); setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) { _showBatchPopup(_items.length - 1); });
  }

  void _removeItem(int i) { setState(() { for (var b in _items[i].batches) { b.dispose(); } _items[i].qtyController.dispose(); _items.removeAt(i); }); }

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
    if (AppSettings.requirePinVoid && mounted) {
      final pinCtrl = TextEditingController();
      final pinOk = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Manager PIN Required'),
        content: TextField(controller: pinCtrl, obscureText: true, maxLength: 6, decoration: InputDecoration(labelText: 'Enter Manager PIN', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () { final mgr = AppUser.allUsers.where((u) => (u.role == 'Admin' || u.role == 'Manager') && u.pin == pinCtrl.text.trim()).firstOrNull; if (mgr != null) { Navigator.pop(ctx, true); } else { _snack('Invalid Manager PIN'); } }, child: const Text('Confirm'))]));
      if (pinOk != true) return;
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
            updated[idx] = Product(id: old.id, sku: old.sku, name: old.name, category: old.category, unit: old.unit, costPrice: old.costPrice, sellingPrice: old.sellingPrice, stockQty: ns, reorderLevel: old.reorderLevel, barcode: old.barcode);
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
      final record = DeliveryRecord(id: now.millisecondsSinceEpoch.toString(), refNumber: refNumber, supplier: _supplierCtrl.text.trim(), driverName: _driverCtrl.text.trim(), plateNumber: _plateCtrl.text.trim(), receivedBy: _receivedByCtrl.text.trim(), notes: _notesCtrl.text.trim(), items: recs, totalItems: totalItems, totalQuantity: tQty, totalCost: tCost, totalRetail: tRetail, dateTime: now, branchId: myBranchId, branchName: myBranchName);
      await DeliveryStorage.saveDelivery(record);
      for (final u in updated) { Product.updateProduct(u.id, u); }
      // 🔄 Phase B2: refresh branch stock cache after delivery
      _loadBranchStock();
      if (!mounted) return;
      _showPostSaveDialog(record, updated);
    } catch (e) { if (mounted) _snack('Error saving: $e'); }
  }

  // ☁️ PHASE 4: Upload delivery to Firebase under branchReceivedDelivery/{branchId}
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
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) {
        debugPrint("[DELIVERY-SYNC] FAIL: db NULL");
        return;
      }
      final path = "companies/$companyCode/branchReceivedDelivery/$branchId/${record.id}";
      await db.ref(path).set(record.toJson());
      debugPrint("[DELIVERY-SYNC] ✅ Uploaded: $path");
    } catch (e) {
      debugPrint("[DELIVERY-SYNC] ❌ Error: $e");
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
        _dlgBtn(Icons.print, 'Print A4', const Color(0xFF2196F3), () { Navigator.pop(ctx); _printA4(r, up); }),
        const SizedBox(height: 10),
        _dlgBtn(Icons.picture_as_pdf, 'Save PDF', const Color(0xFF4CAF50), () { Navigator.pop(ctx); _savePdf(r, up); }),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.check), label: const Text('Done'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () { Navigator.pop(ctx); Navigator.pop(context, up); })),
      ])));
  }

  Widget _dlgBtn(IconData ic, String lbl, Color bg, VoidCallback onTap) => SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: Icon(ic, color: Colors.white), label: Text(lbl, style: const TextStyle(color: Colors.white)),
    style: ElevatedButton.styleFrom(backgroundColor: bg, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: onTap));

  pw.Document _buildA4Pdf(DeliveryRecord r) {
    final pdf = pw.Document(); final date = '${r.dateTime.year}-${_pad(r.dateTime.month)}-${_pad(r.dateTime.day)}'; final time = '${_pad(r.dateTime.hour)}:${_pad(r.dateTime.minute)}:${_pad(r.dateTime.second)}';
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4.landscape, margin: const pw.EdgeInsets.all(20 * PdfPageFormat.mm),
      build: (pw.Context ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(width: double.infinity, padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: const pw.BoxDecoration(color: PdfColors.blue800, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
          child: pw.Column(children: [pw.Text('FlavianoPOS - PRO', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)), pw.SizedBox(height: 2), pw.Text('DELIVERY RECEIVING REPORT', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.yellow, letterSpacing: 2))])),
        pw.SizedBox(height: 12),
        pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_pdfInfoRow('Date', date), _pdfInfoRow('Time', time), _pdfInfoRow('DR #', r.refNumber)]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_pdfInfoRow('Supplier', r.supplier.isEmpty ? '-' : r.supplier), _pdfInfoRow('Driver', r.driverName.isEmpty ? '-' : r.driverName), _pdfInfoRow('Plate #', r.plateNumber.isEmpty ? '-' : r.plateNumber)]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [_pdfInfoRow('Received By', r.receivedBy.isEmpty ? '-' : r.receivedBy), _pdfInfoRow('Total Items', '${r.totalItems}'), _pdfInfoRow('Total Qty', '+${r.totalQuantity} pcs')])])),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white), headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700), cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignments: {0: pw.Alignment.center, 6: pw.Alignment.center, 7: pw.Alignment.centerRight, 8: pw.Alignment.centerRight, 9: pw.Alignment.centerRight, 10: pw.Alignment.centerRight},
          headerPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5), cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4), oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          headers: ['#', 'Item', 'SKU', 'Batch #', 'MFG', 'EXP', 'Qty', 'Unit Cost', 'Unit Retail', 'Total Cost', 'Total Retail'],
          data: [for (int i = 0; i < r.items.length; i++) ['${i + 1}', r.items[i].itemName, r.items[i].sku, r.items[i].batchNumber.isEmpty ? '-' : r.items[i].batchNumber, r.items[i].mfgDate.isEmpty ? '-' : r.items[i].mfgDate, r.items[i].expDate.isEmpty ? '-' : r.items[i].expDate, '${r.items[i].quantity}', r.items[i].cost.toStringAsFixed(2), r.items[i].retail.toStringAsFixed(2), (r.items[i].cost * r.items[i].quantity).toStringAsFixed(2), (r.items[i].retail * r.items[i].quantity).toStringAsFixed(2)]]),
        pw.SizedBox(height: 4),
        pw.Container(width: double.infinity, padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: pw.BoxDecoration(color: PdfColors.blue50, border: pw.Border.all(color: PdfColors.blue200), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [pw.Text('Items: ${r.totalItems}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text('Qty: +${r.totalQuantity}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)), pw.Text('Cost: ${r.totalCost.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text('Retail: ${r.totalRetail.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800))])),
        pw.SizedBox(height: 8),
        if (r.notes.isNotEmpty) ...[pw.Container(width: double.infinity, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(color: PdfColors.amber50, border: pw.Border.all(color: PdfColors.amber200), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))), child: pw.Text('Notes: ${r.notes}', style: const pw.TextStyle(fontSize: 9))), pw.SizedBox(height: 8)],
        pw.Spacer(), pw.Divider(color: PdfColors.grey400), pw.SizedBox(height: 8),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [_pdfSignature('Received By'), _pdfSignature('Checked By'), _pdfSignature('Approved By')]),
        pw.SizedBox(height: 12), pw.Center(child: pw.Text('System-generated document from FlavianoPOS - PRO', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)))])));
    return pdf;
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
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(elevation: 0, title: const Text('\u{1F4E6} Receive Delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.history_rounded, size: 22), tooltip: 'History', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveryHistoryScreen()))),
          TextButton.icon(onPressed: _saveDelivery, icon: const Icon(Icons.save_rounded, color: Colors.white, size: 20), label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)))]),
      body: Column(children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          child: Column(children: [
            InkWell(onTap: () => setState(() => _headerExpanded = !_headerExpanded),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Row(children: [
                Icon(Icons.receipt_long, color: Colors.white.withOpacity(0.8), size: 16), const SizedBox(width: 8),
                Text(_refCtrl.text.isEmpty ? 'Delivery Info' : 'DR# ${_refCtrl.text}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500)),
                const Spacer(),
                if (_supplierCtrl.text.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)), child: Text(_supplierCtrl.text, style: const TextStyle(color: Colors.white, fontSize: 10))),
                const SizedBox(width: 8), Icon(_headerExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white70, size: 20)]))),
            AnimatedCrossFade(duration: const Duration(milliseconds: 250), crossFadeState: _headerExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond, secondChild: const SizedBox.shrink(),
              firstChild: Container(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: Column(children: [
                Row(children: [Expanded(child: _proField(_refCtrl, 'DR # / Reference *', Icons.receipt)), const SizedBox(width: 8), Expanded(child: _proField(_supplierCtrl, 'Supplier', Icons.business))]),
                const SizedBox(height: 8),
                Row(children: [Expanded(child: _proField(_driverCtrl, 'Driver', Icons.person_outline)), const SizedBox(width: 8), Expanded(child: _proField(_plateCtrl, 'Plate #', Icons.directions_car_outlined))]),
                const SizedBox(height: 8),
                Row(children: [Expanded(child: _proField(_receivedByCtrl, 'Received By', Icons.assignment_ind_outlined)), const SizedBox(width: 8), Expanded(child: _proField(_notesCtrl, 'Notes / Remarks', Icons.note_outlined))])]))),
          ])),
        Container(padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]),
            child: TextField(controller: _searchCtrl, style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(hintText: '\u{1F50D} Search product by name, SKU, or barcode...', hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.blue[300], size: 20),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: Icon(Icons.clear, color: Colors.grey[400], size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); }) : null,
                border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              onChanged: (v) => setState(() => _searchQuery = v)))),
        if (_searchQuery.isNotEmpty && _filteredProducts.isNotEmpty)
          Container(constraints: const BoxConstraints(maxHeight: 200), margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))]),
            child: ListView.separated(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 4), separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[100]), itemCount: _filteredProducts.length,
              itemBuilder: (_, i) { final p = _filteredProducts[i]; final added = _items.any((x) => x.product.id == p.id);
                return ListTile(dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  leading: CircleAvatar(radius: 16, backgroundColor: added ? Colors.grey[200] : Colors.blue[50], child: Icon(added ? Icons.check : Icons.add, size: 16, color: added ? Colors.grey : Colors.blue[700])),
                  title: Text(p.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: added ? Colors.grey : Colors.black87)),
                  subtitle: Row(children: [_chip(p.sku, Colors.indigo), const SizedBox(width: 4), _chip('Stock: ${_stockOf(p)}', _stockOf(p) <= p.reorderLevel ? Colors.red : Colors.green), const SizedBox(width: 4), _chip('C:${p.costPrice.toStringAsFixed(0)}', Colors.teal)]),
                  trailing: added ? const Text('Added', style: TextStyle(fontSize: 9, color: Colors.grey)) : null, onTap: added ? null : () => _addItem(p)); })),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)), child: Icon(Icons.list_alt_rounded, size: 16, color: Colors.blue[700])),
          const SizedBox(width: 8), Text('Delivery Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800])), const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.blue[700], borderRadius: BorderRadius.circular(10)), child: Text('${_items.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          const Spacer(), if (_items.isNotEmpty) Text('Total: $_totalQty pcs', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500))])),
        Expanded(child: _items.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle), child: Icon(Icons.local_shipping_outlined, size: 48, color: Colors.blue[200])),
              const SizedBox(height: 12), Text('No items added yet', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
              const SizedBox(height: 4), Text('Search and add products above', style: TextStyle(color: Colors.grey[400], fontSize: 12))]))
          : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), itemCount: _items.length, itemBuilder: (_, i) {
              final item = _items[i]; final qty = int.tryParse(item.qtyController.text) ?? 0; final lc = qty * item.product.costPrice; final lr = qty * item.product.sellingPrice; final hasBatches = item.batches.isNotEmpty && item.totalBatchQty > 0;
              return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: hasBatches ? const Color(0xFF4CAF50) : const Color(0xFFFF9800), width: hasBatches ? 0.5 : 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
                child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => _showBatchPopup(i),
                  child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 28, height: 28, decoration: BoxDecoration(gradient: LinearGradient(colors: hasBatches ? [const Color(0xFF43A047), const Color(0xFF66BB6A)] : [const Color(0xFFEF6C00), const Color(0xFFFFA726)]), borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 2), const SizedBox(height: 3),
                        Row(children: [_chip(item.product.sku, Colors.indigo), const SizedBox(width: 4), _chip('Stock: ${_stockOf(item.product)}', Colors.blueGrey)]), const SizedBox(height: 3),
                        Row(children: [_chip('C: ${item.product.costPrice.toStringAsFixed(2)}', Colors.teal), const SizedBox(width: 4), _chip('R: ${item.product.sellingPrice.toStringAsFixed(2)}', Colors.blue)])])),
                      Column(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(gradient: LinearGradient(colors: hasBatches ? [const Color(0xFF43A047), const Color(0xFF66BB6A)] : [const Color(0xFFEF6C00), const Color(0xFFFFA726)]), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: (hasBatches ? Colors.green : Colors.orange).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]),
                          child: Text(qty > 0 ? '$qty' : 'TAP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white))),
                        const SizedBox(height: 4), Text(hasBatches ? '${item.batches.length} batch${item.batches.length > 1 ? 'es' : ''}' : 'No batch', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: hasBatches ? Colors.green[700] : Colors.orange[700])),
                        const SizedBox(height: 4), InkWell(onTap: () => _removeItem(i), borderRadius: BorderRadius.circular(12),
                          child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)), child: Icon(Icons.close, color: Colors.red[400], size: 16)))])]),
                    if (item.batches.isNotEmpty) ...[const Divider(height: 14, thickness: 0.5),
                      for (final b in item.batches) if (b.qty > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
                        Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(4)), child: Icon(Icons.inventory_2_outlined, size: 11, color: Colors.teal[600])),
                        const SizedBox(width: 6), Expanded(child: Text('${b.batchCtrl.text}  \u2022  MFG: ${b.mfgDate != null ? _fmtDate(b.mfgDate!) : "?"}  \u2022  EXP: ${b.expDate != null ? _fmtDate(b.expDate!) : "?"}', style: TextStyle(fontSize: 10, color: Colors.teal[700]))),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(6)), child: Text('${b.qty}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal[800])))]))],
                    if (!hasBatches) Padding(padding: const EdgeInsets.only(top: 8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.touch_app_rounded, size: 14, color: Colors.orange[700]), const SizedBox(width: 6), Text('Tap to add batch details', style: TextStyle(fontSize: 11, color: Colors.orange[700], fontWeight: FontWeight.w500))]))),
                    if (qty > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('Cost: ${lc.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green[700])), const SizedBox(width: 16), Text('Retail: ${lr.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue[700]))]))),
                  ])))); })),
        if (_items.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1565C0)])),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_summaryChip(Icons.inventory_2, '$activeItems Items'), _summaryChip(Icons.add_box, '+$_totalQty pcs'), _summaryChip(Icons.payments, 'C: ${_totalCost.toStringAsFixed(0)}'), _summaryChip(Icons.sell, 'R: ${_totalRetail.toStringAsFixed(0)}')])),
        Container(padding: const EdgeInsets.fromLTRB(16, 10, 16, 16), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -3))]),
          child: SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(onPressed: _saveDelivery, icon: const Icon(Icons.local_shipping_rounded, size: 22),
            label: Text('RECEIVE ${_items.length} ITEMS  (+$_totalQty pcs)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, elevation: 3, shadowColor: Colors.blue.withOpacity(0.4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))))),
      ]),
    );
  }

  Widget _proField(TextEditingController c, String label, IconData ic) => TextField(controller: c, style: const TextStyle(fontSize: 12, color: Colors.white),
    decoration: InputDecoration(labelText: label, labelStyle: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)), prefixIcon: Icon(ic, size: 16, color: Colors.white.withOpacity(0.7)), isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
      filled: true, fillColor: Colors.white.withOpacity(0.12)));

  Widget _chip(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color.withOpacity(0.8))));

  Widget _summaryChip(IconData ic, String text) => Row(children: [Icon(ic, size: 13, color: Colors.white70), const SizedBox(width: 4), Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))]);
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
      child: ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85, maxWidth: 500),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF00695C), Color(0xFF00897B)]), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(children: [const Icon(Icons.inventory_2, color: Colors.white), const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Batch Encoding', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text('${widget.productName} (${widget.productSku})', style: const TextStyle(color: Colors.white70, fontSize: 12))])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)), child: Text('Total: $_totalQty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)))])),
          Flexible(child: ListView.builder(shrinkWrap: true, padding: const EdgeInsets.all(12), itemCount: _batches.length,
            itemBuilder: (_, i) { final b = _batches[i];
              return Card(margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 2,
                child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
                  Row(children: [CircleAvatar(radius: 12, backgroundColor: Colors.teal[100], child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal[800]))),
                    const SizedBox(width: 8), Text('Batch ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const Spacer(),
                    if (_batches.length > 1) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), constraints: const BoxConstraints(), padding: EdgeInsets.zero, onPressed: () => _removeBatch(i))]),
                  const SizedBox(height: 8),
                  Row(children: [Expanded(flex: 3, child: TextField(controller: b.batchCtrl, style: const TextStyle(fontSize: 13), decoration: InputDecoration(labelText: 'Batch Number *', isDense: true, prefixIcon: const Icon(Icons.tag, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)))),
                    const SizedBox(width: 8), Expanded(flex: 2, child: TextField(controller: b.qtyCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center, decoration: InputDecoration(labelText: 'Qty *', isDense: true, prefixIcon: const Icon(Icons.numbers, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10))))]),
                  const SizedBox(height: 8),
                  Row(children: [Expanded(child: InkWell(onTap: () => _pickDate(context, b, true), child: InputDecorator(decoration: InputDecoration(labelText: 'MFG Date *', isDense: true, prefixIcon: Icon(Icons.calendar_today, size: 16, color: Colors.green[700]), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)), child: Text(_fmtD(b.mfgDate), style: TextStyle(fontSize: 12, color: b.mfgDate != null ? Colors.black87 : Colors.grey))))),
                    const SizedBox(width: 8), Expanded(child: InkWell(onTap: () => _pickDate(context, b, false), child: InputDecorator(decoration: InputDecoration(labelText: 'EXP Date *', isDense: true, prefixIcon: Icon(Icons.event_busy, size: 16, color: Colors.red[700]), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)), child: Text(_fmtD(b.expDate), style: TextStyle(fontSize: 12, color: b.expDate != null ? (b.expDate!.isBefore(DateTime.now()) ? Colors.red : Colors.black87) : Colors.grey)))))])])));
            })),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add Batch'), style: OutlinedButton.styleFrom(foregroundColor: Colors.teal[700], side: BorderSide(color: Colors.teal[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _addBatch)),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, null), style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Cancel'))),
                const SizedBox(width: 10), Expanded(flex: 2, child: ElevatedButton.icon(icon: const Icon(Icons.check), label: Text('Save Batches ($_totalQty pcs)'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _save))])])),
        ])));
  }
}
