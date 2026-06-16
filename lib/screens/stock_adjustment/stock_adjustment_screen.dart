import 'package:flutter/material.dart';
import '../../models/settings_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/product_model.dart';
import '../../models/adjustment_item.dart';
import 'adjustment_model.dart';
import 'adjustment_history_screen.dart';
import '../inventory/inventory_screen.dart';

class StockAdjustmentScreen extends StatefulWidget {
  final Product? initialProduct;
  final String branch;

  const StockAdjustmentScreen({super.key, this.initialProduct, required this.branch});

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  final List<AdjustmentItem> _items = [];


  final Map<String, IconData> _reasonIcons = {
    'Delivery': Icons.local_shipping,
    'Damaged': Icons.broken_image,
    'Expired': Icons.event_busy,
    'Return': Icons.assignment_return,
    'Recount': Icons.calculate,
    'Transfer': Icons.swap_horiz,
    'Data Entry Error': Icons.edit_note,
    'Returned by Customer': Icons.person_off,
    'Marketing Sample': Icons.campaign,
    'Other': Icons.more_horiz,
  };

  List<String> get _reasons => _reasonIcons.keys.toList();

  String _formatCompact(double v) {
    if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(1)}Bn';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  String _formatCurrency(double amount) {
    final prefix = amount < 0 ? '-' : '';
    return '$prefix${_formatCompact(amount.abs())}';
  }

  double _itemCostAdj(AdjustmentItem item) {
    final qty = item.quantity.toDouble();
    final cost = item.product.costPrice;
    return item.isAdd ? (qty * cost) : -(qty * cost);
  }

  double get _grandTotalCostAdj {
    double total = 0;
    for (var item in _items) {
      total += _itemCostAdj(item);
    }
    return total;
  }

  int get _addCount => _items.where((i) => i.isAdd).length;
  int get _deductCount => _items.where((i) => !i.isAdd).length;

  @override
  void initState() {
    super.initState();
    if (widget.initialProduct != null) {
      final item = AdjustmentItem(product: widget.initialProduct!);
      _items.add(item);
      WidgetsBinding.instance.addPostFrameCallback((_) {

      });
    }
  }

  @override
  void dispose() {
    for (var item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _showSnackBar(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color ?? Colors.blue[700],
        behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    );
  }

  // ══════════════════════════════════════════════
  //  SAVE ALL ADJUSTMENTS
  // ══════════════════════════════════════════════
  Future<void> _saveAllAdjustments() async {
    // Validate
    for (var item in _items) {
      item.quantity = int.tryParse(item.qtyController.text) ?? 0;
      if (item.quantity <= 0) {
        _showSnackBar('Please enter valid qty for ${item.product.name}', color: Colors.red);
        return;
      }
      if (!item.isAdd && item.quantity > item.product.stockQty) {
        _showSnackBar('Cannot deduct more than current stock (${item.product.stockQty}) for ${item.product.name}', color: Colors.red);
        return;
      }
    }

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog();

    // Manager PIN check
    if (AppSettings.requirePinVoid && mounted) {
      final pinCtrl = TextEditingController();
      final pinOk = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Manager PIN Required'),
        content: TextField(controller: pinCtrl, obscureText: true, maxLength: 4,
          decoration: InputDecoration(labelText: 'Enter Manager PIN',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            if (pinCtrl.text == '1234') { Navigator.pop(ctx, true); }
            else { _showSnackBar('Invalid PIN', color: Colors.red); }
          }, child: const Text('Confirm')),
        ]));
      if (pinOk != true) return;
    }
    if (confirmed != true) return;

    // Manager PIN check
    if (AppSettings.requirePinVoid) {
      final pinCtrl = TextEditingController();
      final pinOk = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Manager PIN Required'),
        content: TextField(controller: pinCtrl, obscureText: true, maxLength: 4,
          decoration: InputDecoration(labelText: 'Enter Manager PIN',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            if (pinCtrl.text == '1234') { Navigator.pop(ctx, true); }
            else { _showSnackBar('Invalid PIN', color: Colors.red); }
          }, child: const Text('Confirm')),
        ]));
      if (pinOk != true) return;
    }

    final List<AdjustmentRecord> records = [];
    for (var item in _items) {
      final record = AdjustmentRecord(
        id: 'ADJ-${DateTime.now().millisecondsSinceEpoch}-${_items.indexOf(item)}',
        sku: item.product.sku,
        itemName: item.product.name,
        cost: item.product.costPrice,
        retail: item.product.sellingPrice,
        adjustmentType: item.isAdd ? 'Add' : 'Deduct',
        quantity: item.quantity,
        oldStock: item.product.stockQty,
        newStock: item.newStock,
        reason: item.selectedReason,
        notes: item.notesController.text,
        dateTime: DateTime.now(),
        
      );
      records.add(record);
      await AdjustmentStorage.saveAdjustment(record);

      final updated = item.updatedProduct;
      Product.updateProduct(updated.id, updated);
    }

    if (!mounted) return;

    _showPostSaveDialog(records);
  }

  // ══════════════════════════════════════════════
  //  CONFIRMATION DIALOG (before save)
  // ══════════════════════════════════════════════
  Future<bool?> _showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.blue[700]),
          const SizedBox(width: 8),
          const Text('Confirm Adjustment', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _confirmStat('Items', '${_items.length}', Colors.blue),
                    _confirmStat('Adds', '$_addCount', Colors.green),
                    _confirmStat('Deducts', '$_deductCount', Colors.red),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(item.isAdd ? Icons.add_circle : Icons.remove_circle,
                        color: item.isAdd ? Colors.green : Colors.red, size: 20),
                      title: Text(item.product.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('${item.product.stockQty} → ${item.newStock}  |  ${item.selectedReason}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      trailing: Text('${item.isAdd ? "+" : "-"}${item.quantity}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                          color: item.isAdd ? Colors.green[700] : Colors.red[700])),
                    );
                  },
                ),
              ),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Net Cost Impact:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_formatCurrency(_grandTotalCostAdj),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                    color: _grandTotalCostAdj >= 0 ? Colors.green[700] : Colors.red[700])),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Confirm & Save'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ],
      ),
    );
  }

  Widget _confirmStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]);
  }

  // ══════════════════════════════════════════════
  //  POST-SAVE DIALOG
  // ══════════════════════════════════════════════
  void _showPostSaveDialog(List<AdjustmentRecord> records) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green, size: 28),
          SizedBox(width: 8),
          Text('Adjustment Saved!', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Text('${records.length} item(s) adjusted successfully.\nStock has been updated.'),
        actions: [
          _dialogBtn(icon: Icons.print, label: 'Print Receipt', color: Colors.purple,
            onTap: () { Navigator.pop(ctx); _printReceipts(records); }),
          _dialogBtn(icon: Icons.history, label: 'View History', color: Colors.blue,
            onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const AdjustmentHistoryScreen())); }),
          _dialogBtn(icon: Icons.check, label: 'Done', color: Colors.green,
            onTap: () {
              Navigator.pop(ctx);
              setState(() { _items.clear(); });

            }),
        ],
      ),
    );
  }

  Widget _dialogBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 18),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  // ══════════════════════════════════════════════
  //  A4 PDF FOR FILING & AUDIT
  // ══════════════════════════════════════════════
  pw.Document _buildReceiptsPdf(List<AdjustmentRecord> records) {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';
    final timeStr = '${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
    final addCount = records.where((r) => r.adjustmentType == 'Add').length;
    final deductCount = records.where((r) => r.adjustmentType == 'Deduct').length;
    final totalAdd = records.where((r) => r.adjustmentType == 'Add').fold(0, (s, r) => s + r.quantity);
    final totalDeduct = records.where((r) => r.adjustmentType == 'Deduct').fold(0, (s, r) => s + r.quantity);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (ctx) => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('FlavianoPOS - PRO', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text(widget.branch, style: const pw.TextStyle(fontSize: 11)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('STOCK ADJUSTMENT REPORT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Date: $dateStr  Time: $timeStr', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Reference #: ADJ-${now.millisecondsSinceEpoch.toString().substring(5)}', style: const pw.TextStyle(fontSize: 9)),
          ]),
        ]),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 2),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          _pdfInfoBox('Total Items', '${records.length}'),
          pw.SizedBox(width: 16),
          _pdfInfoBox('Additions', '+$totalAdd ($addCount items)'),
          pw.SizedBox(width: 16),
          _pdfInfoBox('Deductions', '-$totalDeduct ($deductCount items)'),
        ]),
        pw.SizedBox(height: 8),
      ]),
      footer: (ctx) => pw.Column(children: [
        pw.Divider(),
        pw.SizedBox(height: 30),
        pw.Row(children: [
          pw.Expanded(child: pw.Column(children: [
            pw.Container(width: 180, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1))),
              child: pw.Padding(padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Center(child: pw.Text('Prepared By', style: const pw.TextStyle(fontSize: 9))))),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('Signature over Printed Name', style: const pw.TextStyle(fontSize: 7))),
            pw.Center(child: pw.Text('Date: _______________', style: const pw.TextStyle(fontSize: 7))),
          ])),
          pw.Expanded(child: pw.Column(children: [
            pw.Container(width: 180, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1))),
              child: pw.Padding(padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Center(child: pw.Text('Checked By', style: const pw.TextStyle(fontSize: 9))))),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('Signature over Printed Name', style: const pw.TextStyle(fontSize: 7))),
            pw.Center(child: pw.Text('Date: _______________', style: const pw.TextStyle(fontSize: 7))),
          ])),
          pw.Expanded(child: pw.Column(children: [
            pw.Container(width: 180, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1))),
              child: pw.Padding(padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Center(child: pw.Text('Approved By', style: const pw.TextStyle(fontSize: 9))))),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('Signature over Printed Name', style: const pw.TextStyle(fontSize: 7))),
            pw.Center(child: pw.Text('Date: _______________', style: const pw.TextStyle(fontSize: 7))),
          ])),
        ]),
        pw.SizedBox(height: 12),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Generated by FlavianoPOS - PRO', style: const pw.TextStyle(fontSize: 7)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7)),
        ]),
      ]),
      build: (ctx) => [
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(0.6),
            1: pw.FlexColumnWidth(2.5),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(0.7),
            4: pw.FlexColumnWidth(0.7),
            5: pw.FlexColumnWidth(0.7),
            6: pw.FlexColumnWidth(0.7),
            7: pw.FlexColumnWidth(2),
            8: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: ['#', 'Product / SKU', 'Type', 'Qty', 'Old', 'New', 'Diff', 'Reason', 'Notes']
                .map((h) => pw.Padding(padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)))
                .toList()),
            ...records.asMap().entries.map((e) {
              final i = e.key; final r = e.value;
              final diff = r.newStock - r.oldStock;
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : PdfColors.grey50),
                children: [
                  _cell('${i + 1}'),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(r.itemName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text(r.sku, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                  ])),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(color: r.adjustmentType == 'Add' ? PdfColors.green50 : PdfColors.red50, borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Text(r.adjustmentType, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: r.adjustmentType == 'Add' ? PdfColors.green800 : PdfColors.red800), textAlign: pw.TextAlign.center))),
                  _cell('${r.quantity}'),
                  _cell('${r.oldStock}'),
                  _cell('${r.newStock}'),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${diff > 0 ? '+' : ''}$diff',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: diff > 0 ? PdfColors.green700 : PdfColors.red700), textAlign: pw.TextAlign.center)),
                  _cell(r.reason),
                  _cell(r.notes),
                ]);
            }),
          ]),
        pw.SizedBox(height: 12),
        pw.Container(padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Total Adjustments: ${records.length}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text('Additions: +$totalAdd | Deductions: -$totalDeduct', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ])),
        pw.SizedBox(height: 8),
        pw.Text('Remarks: ________________________________________________________________________', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 4),
        pw.Text('________________________________________________________________________', style: const pw.TextStyle(fontSize: 9)),
      ],
    ));
    return pdf;
  }

  pw.Widget _pdfInfoBox(String label, String value) => pw.Expanded(
    child: pw.Container(padding: const pw.EdgeInsets.all(6), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ])));

  pw.Widget _cell(String t) => pw.Padding(padding: const pw.EdgeInsets.all(4),
    child: pw.Text(t, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center));


  Future<void> _printReceipts(List<AdjustmentRecord> records) async {
    final pdf = _buildReceiptsPdf(records);
    final bytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  // ══════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📦 Stock Adjustment', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[700], foregroundColor: Colors.white, elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'history') Navigator.push(context, MaterialPageRoute(builder: (_) => const AdjustmentHistoryScreen()));
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'history', child: ListTile(
                leading: Icon(Icons.history, color: Colors.blue), title: Text('Adjustment History'), contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          if (_items.isNotEmpty) _buildSummaryCards(),
          Expanded(
            child: _items.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _items.length,
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    itemBuilder: (context, index) {
                      return _buildItemCard(_items[index]);
                    },
                  ),








          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  SUMMARY CARDS
  // ══════════════════════════════════════════════
  Widget _buildSummaryCards() {
    final net = _grandTotalCostAdj;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      color: Colors.white,
      child: Row(children: [
        _summaryCard('Items', '${_items.length}', Icons.inventory_2, Colors.blue),
        const SizedBox(width: 6),
        _summaryCard('Adds', '$_addCount', Icons.add_circle, Colors.green),
        const SizedBox(width: 6),
        _summaryCard('Deducts', '$_deductCount', Icons.remove_circle, Colors.red),
        const SizedBox(width: 6),
        _summaryCard('Cost Impact', _formatCurrency(net),
          net >= 0 ? Icons.trending_up : Icons.trending_down,
          net >= 0 ? Colors.green : Colors.red),
      ]),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color))),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  EMPTY STATE
  // ══════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.tune, size: 60, color: Colors.blue[300]),
          ),
          const SizedBox(height: 20),
          Text('No Items to Adjust', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text('Tap "+ Add Product" below to start', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addProduct,
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700], foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  ADD PRODUCT
  // ══════════════════════════════════════════════
  void _addProduct() async {
    final product = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => InventoryScreen(branch: widget.branch, isSelecting: true)),
    );
    if (product != null && mounted) {
      // Check duplicate
      if (_items.any((i) => i.product.id == product.id)) {
        _showSnackBar('${product.name} is already in the list', color: Colors.orange[700]);
        return;
      }
      final item = AdjustmentItem(product: product);
      setState(() => _items.add(item));

    }
  }

  // ══════════════════════════════════════════════
  //  ITEM CARD (Enhanced)
  // ══════════════════════════════════════════════
  Widget _buildItemCard(AdjustmentItem item) {
    final costAdj = _itemCostAdj(item);
    final isAdd = item.isAdd;
    final accentColor = isAdd ? Colors.green : Colors.red;

    return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(children: [
              // Accent bar
              Container(width: 5, color: accentColor),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Header row
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(isAdd ? Icons.add_circle : Icons.remove_circle, color: accentColor, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.product.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Text('SKU: ${item.product.sku}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                            child: Text(item.product.category, style: TextStyle(fontSize: 9, color: Colors.blue[700], fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ])),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 20),
                        onPressed: () {
                          final index = _items.indexOf(item);
                          if (index >= 0) {
                            setState(() => _items.removeAt(index));

                          }
                        },
                      ),
                    ]),

                    const SizedBox(height: 10),

                    // Stock preview
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentColor.withValues(alpha: 0.15)),
                      ),
                      child: Row(children: [
                        Text('Stock:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(width: 6),
                        Text('${item.product.stockQty}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, size: 16, color: accentColor),
                        ),
                        Text('${item.newStock}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accentColor)),
                        const Spacer(),
                        Text('${isAdd ? "+" : "-"}${item.quantity}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accentColor)),
                      ]),
                    ),

                    const SizedBox(height: 10),

                    // Add/Deduct toggle + Qty row
                    Row(children: [
                      _typeChip(item, 'Add', true),
                      const SizedBox(width: 6),
                      _typeChip(item, 'Deduct', false),
                      const Spacer(),
                      // Qty stepper
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          InkWell(
                            onTap: () {
                              final q = (int.tryParse(item.qtyController.text) ?? 0) - 1;
                              if (q >= 0) {
                                item.qtyController.text = '$q';
                                setState(() => item.quantity = q);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: const BorderRadius.horizontal(left: Radius.circular(7))),
                              child: const Icon(Icons.remove, size: 18),
                            ),
                          ),
                          SizedBox(
                            width: 55,
                            child: TextField(
                              controller: item.qtyController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                              onChanged: (v) => setState(() => item.quantity = int.tryParse(v) ?? 0),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              final q = (int.tryParse(item.qtyController.text) ?? 0) + 1;
                              item.qtyController.text = '$q';
                              setState(() => item.quantity = q);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: const BorderRadius.horizontal(right: Radius.circular(7))),
                              child: const Icon(Icons.add, size: 18),
                            ),
                          ),
                        ]),
                      ),
                    ]),

                    const SizedBox(height: 10),

                    // Reason dropdown with icon
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: item.selectedReason,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Reason',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            prefixIcon: Icon(_reasonIcons[item.selectedReason] ?? Icons.more_horiz, size: 18, color: Colors.blue[700]),
                          ),
                          items: _reasons.map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),





                          )).toList(),
                          onChanged: (v) { if (v != null) setState(() => item.selectedReason = v); },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: item.notesController,
                          decoration: InputDecoration(
                            labelText: 'Notes (optional)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 8),

                    // Cost impact row
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      decoration: BoxDecoration(
                        color: costAdj >= 0 ? Colors.green[50] : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Cost Impact (${item.product.costPrice.toStringAsFixed(2)} x ${item.quantity})',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        Text(_formatCurrency(costAdj),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                            color: costAdj >= 0 ? Colors.green[700] : Colors.red[700])),
                      ]),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
    );
  }

  Widget _typeChip(AdjustmentItem item, String label, bool isAddType) {
    final selected = item.isAdd == isAddType;
    final color = isAddType ? Colors.green : Colors.red;
    return GestureDetector(
      onTap: () => setState(() => item.isAdd = isAddType),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey[300]!),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isAddType ? Icons.add : Icons.remove, size: 14,
            color: selected ? Colors.white : Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey[600])),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  BOTTOM BAR
  // ══════════════════════════════════════════════
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _addProduct,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue[700],
                side: BorderSide(color: Colors.blue[700]!),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _items.isEmpty ? null : _saveAllAdjustments,
              icon: const Icon(Icons.save),
              label: Text('Save All (${_items.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700], foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
