import 'dart:convert';
import '../../models/settings_model.dart';
import 'dart:typed_data';
import 'dart:io';
// lib/screens/inventory/inventory_screen.dart
import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import 'add_edit_product_screen.dart';
import '../../utils/export_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as exc;
import '../../helpers/database_helper.dart';
import '../../models/user_model.dart';
import '../../services/branch_inventory_service.dart';
import '../../services/device_assignment_service.dart';

class InventoryScreen extends StatefulWidget {
  final String branch;
  final String role;
  final List<String> permissions;
  final bool isSelecting;

  const InventoryScreen({
    super.key, 
    required this.branch,
    this.role = "",
    this.permissions = const [],
    this.isSelecting = false,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // ═══ TIER 2: Responsive Sizing Helpers ═══
  double _scale() {
    final w = MediaQuery.of(context).size.width;
    return (w / 400).clamp(0.85, 1.8);
  }
  double _rs(double size) => size * _scale();
  // ═══ END TIER 2 helpers ═══

  // ===== BRANCH-AWARE STOCK (Phase A) =====
  Map<String, int> _branchStock = {};
  bool _stockLoading = true;

  bool get _isHeadOffice {
    final r = widget.role.toLowerCase().trim();
    return r == "admin" || r == "companyadmin";
  }

  int _stockOf(Product p) => _branchStock[p.id] ?? 0;

  Future<void> _loadBranchStock() async {
    if (mounted) setState(() => _stockLoading = true);
    try {
      Map<String, int> map;
      if (_isHeadOffice) {
        map = await BranchInventoryService.getStockMapAllBranches();
      } else {
        final assign = await DeviceAssignmentService().read();
        final bid = (assign["branchId"] ?? "").toString();
        map = await BranchInventoryService.getStockMapForBranch(bid);
      }
      if (!mounted) return;
      setState(() {
        _branchStock = map;
        _stockLoading = false;
      });
    } catch (e) {
      debugPrint("[INV] _loadBranchStock error: $e");
      if (mounted) setState(() => _stockLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBranchStock();
  }

  bool get _canEdit {
    final r = widget.role.toLowerCase().trim();
    return r == "admin" || r == "companyadmin" || widget.permissions.contains("Manage Products");
  }
  List<Product> get _products => Product.allProducts;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortBy = 'name';
  bool _sortAscending = true;
  bool _showLowStockOnly = false;

  List<String> get _categories {
    final cats = _products.map((p) => p.category).toSet().toList();
    cats.sort();
    return ['All', ...cats];
  }

  List<Product> get _filteredProducts {
    var filtered =
        _products.where((p) {
          final matchesCategory =
              _selectedCategory == 'All' || p.category == _selectedCategory;
          final matchesSearch =
              _searchQuery.isEmpty ||
              p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              p.sku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              p.barcode.contains(_searchQuery);
          final matchesLowStock =
              !_showLowStockOnly || _stockOf(p) <= p.reorderLevel;
          return matchesCategory && matchesSearch && matchesLowStock;
        }).toList();

    filtered.sort((a, b) {
      int result;
      switch (_sortBy) {
        case 'name':
          result = a.name.compareTo(b.name);
          break;
        case 'price':
          result = a.sellingPrice.compareTo(b.sellingPrice);
          break;
        case 'stock':
          result = _stockOf(a).compareTo(_stockOf(b));
          break;
        case 'sku':
          result = a.sku.compareTo(b.sku);
          break;
        default:
          result = a.name.compareTo(b.name);
      }
      return _sortAscending ? result : -result;
    });

    return filtered;
  }

  int get _totalProducts => _products.length;
  int get _lowStockCount =>
      _products.where((p) => _stockOf(p) <= p.reorderLevel).length;
  int get _outOfStockCount => _products.where((p) => _stockOf(p) == 0).length;
  double get _totalInventoryValue =>
      _products.fold(0, (sum, p) => sum + (p.costPrice * _stockOf(p)));

  String _formatCompact(double v) {
    if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(1)}Bn';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }
  void _addProduct(Product product) {
    setState(() {
      Product.addProduct(product);
    });
  }

  void _updateProduct(Product oldProduct, Product newProduct) {
    setState(() {
      final index = _products.indexWhere((p) => p.id == oldProduct.id);
      if (index >= 0) {
        _products[index] = newProduct;
        Product.updateProduct(oldProduct.id, newProduct);
      }
    });
  }

  void _deleteProduct(Product product) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Product'),
            content: Text('Are you sure you want to delete "${product.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    Product.removeProduct(product.id);
                  });
                  Navigator.pop(ctx);
                  _showSnackBar('${product.name} deleted');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  // ═══════════════════════════════════════════════════════════════
  // EXPORT - choose All / Low Stock / Out of Stock
  // ═══════════════════════════════════════════════════════════════

  List<Product> _getStockList(String type) {
    switch (type) {
      case 'low': return _products.where((p) => _stockOf(p) <= p.reorderLevel && _stockOf(p) > 0).toList();
      case 'out': return _products.where((p) => _stockOf(p) == 0).toList();
      case 'critical': return _products.where((p) => _stockOf(p) <= p.reorderLevel).toList();
      default: return _filteredProducts;
    }
  }

  void _showExportMenu(String format) {
    final lowCount = _products.where((p) => _stockOf(p) <= p.reorderLevel && _stockOf(p) > 0).length;
    showDialog(
      context: context,
      
      builder: (ctx) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Text('Export to ${format == "excel" ? "Excel" : "PDF"}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Choose which items to export', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 16),
          _exportTile('All Products', '${_filteredProducts.length} items', Icons.inventory_2, Colors.blue,
            () { Navigator.pop(ctx); _doExport(format, 'all'); }),
          _exportTile('Low Stock', '$lowCount items', Icons.warning, Colors.orange,
            () { Navigator.pop(ctx); _doExport(format, 'low'); }),
          _exportTile('Out of Stock', '$_outOfStockCount items', Icons.error_outline, Colors.red,
            () { Navigator.pop(ctx); _doExport(format, 'out'); }),
          _exportTile('Critical (Low + Out)', '${_products.where((p) => _stockOf(p) <= p.reorderLevel).length} items',
            Icons.crisis_alert, Colors.deepOrange,
            () { Navigator.pop(ctx); _doExport(format, 'critical'); }),
          const SizedBox(height: 8),
        ]))));
  }

  Widget _exportTile(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ListTile(
      leading: CircleAvatar(backgroundColor: color.withAlpha(30), child: Icon(icon, color: color, size: 22)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap));

  Future<void> _importItems() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null || result.files.isEmpty) {
        _showSnackBar('No file selected');
        return;
      }
      final file = result.files.single;
      Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        _showSnackBar('Cannot read file');
        return;
      }
      final excel = exc.Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first]!;
      final rows = sheet.rows;
      if (rows.isEmpty) {
        _showSnackBar('Empty spreadsheet');
        return;
      }

      // Parse header row
      final headers = rows[0].map((c) => c?.value?.toString().trim().toLowerCase() ?? '').toList();
      int colSku = headers.indexOf('sku');
      int colName = headers.indexWhere((h) => h.contains('product') || h.contains('name'));
      int colCat = headers.indexWhere((h) => h.contains('category'));
      int colCost = headers.indexWhere((h) => h.contains('cost'));
      int colSell = headers.indexWhere((h) => h.contains('selling') || h.contains('price'));
      int colStock = headers.indexWhere((h) => h.contains('stock') || h.contains('qty'));
      int colReorder = headers.indexWhere((h) => h.contains('reorder'));
      int colBarcode = headers.indexWhere((h) => h.contains('barcode'));

      if (colName < 0) {
        _showSnackBar('Missing Product Name column in header row');
        return;
      }

      String cellVal(List<exc.Data?> row, int col) {
        if (col < 0 || col >= row.length) return '';
        return row[col]?.value?.toString().trim() ?? '';
      }

      int added = 0;
      int updated = 0;

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final name = cellVal(row, colName);
        if (name.isEmpty) continue;

        final sku = cellVal(row, colSku);
        final category = cellVal(row, colCat).isNotEmpty ? cellVal(row, colCat) : 'Uncategorized';
        final costPrice = double.tryParse(cellVal(row, colCost)) ?? 0;
        final sellingPrice = double.tryParse(cellVal(row, colSell)) ?? 0;
        final stockQty = int.tryParse(cellVal(row, colStock)) ?? 0;
        final reorderLevel = int.tryParse(cellVal(row, colReorder)) ?? 5;
        final barcode = cellVal(row, colBarcode);

        final existingIdx = sku.isNotEmpty
            ? Product.allProducts.indexWhere((p) => p.sku.toLowerCase() == sku.toLowerCase())
            : -1;

        if (existingIdx >= 0) {
          final existing = Product.allProducts[existingIdx];
          Product.updateProduct(existing.id, Product(
            id: existing.id, name: name, sku: sku.isNotEmpty ? sku : existing.sku,
            category: category, costPrice: costPrice > 0 ? costPrice : existing.costPrice,
            sellingPrice: sellingPrice > 0 ? sellingPrice : existing.sellingPrice,
            stockQty: stockQty > 0 ? stockQty : existing.stockQty,
            reorderLevel: reorderLevel, barcode: barcode.isNotEmpty ? barcode : existing.barcode,
          ));
          updated++;
        } else {
          final newId = 'IMP-${DateTime.now().millisecondsSinceEpoch}-$i';
          Product.addProduct(Product(
            id: newId, name: name, sku: sku.isNotEmpty ? sku : 'SKU-$newId',
            category: category, costPrice: costPrice, sellingPrice: sellingPrice,
            stockQty: stockQty, reorderLevel: reorderLevel, barcode: barcode,
          ));
          added++;
        }
      }

      setState(() {});
      _showSnackBar('Imported: $added new, $updated updated');
    } catch (e) {
      _showSnackBar('Import error: $e');
    }
  }

  void _downloadTemplate() {
    ExportHelper.exportExcel(
      headers: ['SKU', 'Product Name', 'Category', 'Cost Price', 'Selling Price', 'Stock Qty', 'Reorder Level', 'Barcode'],
      rows: [
        ['BEV-001', 'Coca-Cola 1.5L', 'Beverages', '45.00', '65.00', '120', '20', '4800100123456'],
        ['SNK-001', 'Piattos Cheese', 'Snacks', '18.00', '28.00', '150', '30', '4800100223456'],
        ['RCE-001', 'Sinandomeng Rice 5kg', 'Rice and Grains', '220.00', '280.00', '50', '10', '4800100323456'],
      ],
      sheetName: 'Import Template',
      fileName: 'FlavianoPOS_Import_Template.xlsx',
    );
    _showSnackBar('Template downloaded! Fill in your items and import.');
  }

  void _doExport(String format, String type) {
    final data = _getStockList(type);
    final label = type == 'low' ? 'Low_Stock' : type == 'out' ? 'Out_of_Stock' : type == 'critical' ? 'Critical' : 'All';
    final displayLabel = label.replaceAll('_', ' ');
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No $displayLabel items to export.'), backgroundColor: Colors.orange[800]));
      return;
    }
    if (format == 'excel') {
      ExportHelper.exportExcel(
        headers: ['SKU', 'Name', 'Category', 'Unit', 'Cost', 'Selling Price', 'Stock', 'Reorder Level', 'Barcode', 'Status'],
        rows: data.map((p) => [
          p.sku, p.name, p.category, p.unit,
          p.costPrice.toStringAsFixed(2), p.sellingPrice.toStringAsFixed(2),
          _stockOf(p).toString(), p.reorderLevel.toString(), p.barcode,
          _stockOf(p) == 0 ? 'OUT OF STOCK' : _stockOf(p) <= p.reorderLevel ? 'LOW STOCK' : 'OK',
        ]).toList(),
        sheetName: 'Inventory_$label',
        fileName: 'Inventory_${label}_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel exported ($displayLabel - ${data.length} items)!'), backgroundColor: Colors.green));
    } else {
      ExportHelper.exportPdf(
        title: 'Inventory Report - $displayLabel',
        subtitle: '${data.length} products  |  Branch: ${widget.branch}',
        headers: ['SKU', 'Name', 'Category', 'Unit', 'Cost', 'Price', 'Stock', 'Reorder', 'Status'],
        rows: data.map((p) => [
          p.sku, p.name, p.category, p.unit,
          p.costPrice.toStringAsFixed(2), p.sellingPrice.toStringAsFixed(2),
          _stockOf(p).toString(), p.reorderLevel.toString(),
          _stockOf(p) == 0 ? 'OUT OF STOCK' : _stockOf(p) <= p.reorderLevel ? 'LOW STOCK' : 'OK',
        ]).toList(),
        fileName: 'Inventory_${label}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF exported ($displayLabel - ${data.length} items)!'), backgroundColor: Colors.green));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isSelecting ? 'Select a Product' : '📦 Inventory',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [

          // 🏢/🏪 VIEW MODE BADGE (read-only indicator)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isHeadOffice ? Colors.purple[700] : Colors.green[700],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white70, width: 1),
              ),
              child: Center(
                child: Text(
                  _isHeadOffice
                      ? "🏢 ALL"
                      : (widget.branch.isEmpty ? "🏪 BRANCH" : "🏪 ${widget.branch.toUpperCase()}"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // 🔄 REFRESH BRANCH STOCK
          IconButton(
            icon: _stockLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: _isHeadOffice ? "Refresh All Branches Stock" : "Refresh Branch Stock",
            onPressed: _stockLoading ? null : () async {
              final messenger = ScaffoldMessenger.of(context);
              await _loadBranchStock();
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(_isHeadOffice
                    ? "🏢 Reloaded all branches: ${_branchStock.length} products"
                    : "🏪 Reloaded ${widget.branch}: ${_branchStock.length} products"),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          // 🐛 B2.1 DEBUG: BINV Sync Status
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.yellowAccent),
            tooltip: "Show last BINV sync status",
            onPressed: () {
              final st = BranchInventoryService.lastSyncStatus;
              final dt = BranchInventoryService.lastSyncDetail;
              final tm = BranchInventoryService.lastSyncTime?.toIso8601String() ?? "never";
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("🐛 Last BINV Firebase Sync"),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Status: $st", style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: st == "SUCCESS" ? Colors.green : Colors.red,
                          fontSize: 16,
                        )),
                        const SizedBox(height: 12),
                        const Text("Detail:", style: TextStyle(fontWeight: FontWeight.bold)),
                        SelectableText(dt, style: const TextStyle(fontFamily: "monospace", fontSize: 12)),
                        const SizedBox(height: 12),
                        Text("Time: $tm"),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
                  ],
                ),
              );
            },
          ),

          // Low Stock Filter Toggle
          IconButton(
            icon: Icon(
              _showLowStockOnly ? Icons.warning : Icons.warning_amber_outlined,
              color: _showLowStockOnly ? Colors.yellow : Colors.white,
            ),
            tooltip: 'Show Low Stock Only',
            onPressed: () {
              setState(() => _showLowStockOnly = !_showLowStockOnly);
            },
          ),
          // Sort Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort By',
            onSelected: (value) {
              setState(() {
                if (_sortBy == value) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = value;
                  _sortAscending = true;
                }
              });
            },
            itemBuilder:
                (context) => [
                  _buildSortMenuItem('name', 'Name'),
                  _buildSortMenuItem('sku', 'SKU'),
                  _buildSortMenuItem('price', 'Price'),
                  _buildSortMenuItem('stock', 'Stock Qty'),
                ],
          ),
          // More Options
          if (!widget.isSelecting)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'excel':
                  _showExportMenu('excel');
                  break;
                case 'pdf':
                  _showExportMenu('pdf');
                  break;
                case 'import':
_importItems();
                  break;
                case 'template':
                  _downloadTemplate();
                  break;
                case 'delete_all':
                  _showDeleteAllConfirmation();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'excel',
                    child: ListTile(
                      leading: Icon(Icons.table_chart, color: Colors.green),
                      title: Text('Export Excel'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'pdf',
                    child: ListTile(
                      leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                      title: Text('Export PDF'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (_isHeadOffice) const PopupMenuDivider(),
                  if (_isHeadOffice) const PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: Icon(Icons.file_upload, color: Colors.purple),
                      title: Text('Import Items (Excel)'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'template',
                    child: ListTile(
                      leading: Icon(Icons.download, color: Colors.blue),
                      title: Text('Download Template'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (_isHeadOffice) const PopupMenuDivider(),
                  if (_isHeadOffice) const PopupMenuItem(
                    value: 'delete_all',
                    child: ListTile(
                      leading: Icon(Icons.delete_forever, color: Colors.red),
                      title: Text('Delete All Items', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          if (!widget.isSelecting)
          _buildSummaryCards(),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, SKU, or barcode...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Category Filter
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = cat);
                    },
                    selectedColor: Colors.orange[100],
                    checkmarkColor: Colors.orange[800],
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.orange[800] : Colors.grey[700],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),

          // Results Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_filteredProducts.length} products found',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                Text(
                  'Sort: $_sortBy ${_sortAscending ? "↑" : "↓"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Product List
          Expanded(
            child:
                _filteredProducts.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No products found',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        return _buildProductListItem(_filteredProducts[index]);
                      },
                    ),
          ),
        ],
      ),

      // FAB - Add Product
      floatingActionButton: widget.isSelecting
          ? null
          : !_isHeadOffice ? null : FloatingActionButton.extended(
              onPressed: () => _navigateToAddProduct(),
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
    );
  }

  // === Summary Cards ===
  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildSummaryCard(
            'Total Products',
            '$_totalProducts',
            Icons.inventory_2,
            Colors.blue,
          ),
          const SizedBox(width: 8),
          _buildSummaryCard(
            'Low Stock',
            '$_lowStockCount',
            Icons.warning_amber,
            Colors.orange,
          ),
          const SizedBox(width: 8),
          _buildSummaryCard(
            'Out of Stock',
            '$_outOfStockCount',
            Icons.error_outline,
            Colors.red,
          ),
          const SizedBox(width: 8),
          _buildSummaryCard(
            'Inv. Value',
            _formatCompact(_totalInventoryValue),
            Icons.account_balance_wallet,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: _rs(2)),
        padding: EdgeInsets.all(_rs(10)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(_rs(14)),
          border: Border.all(
            color: color.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(_rs(6)),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: _rs(18)),
            ),
            SizedBox(height: _rs(6)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: _rs(18),
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            SizedBox(height: _rs(2)),
            Text(
              label,
              style: TextStyle(
                fontSize: _rs(9.5),
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // === Product List Item ===
  Widget _buildProductThumb(Product product, IconData icon, Color color) {
    if (product.imagePath != null && product.imagePath!.isNotEmpty) {
      try {
        String b64 = product.imagePath!;
        if (b64.contains(',')) b64 = b64.split(',').last;
        if (b64.length > 200) {
          final bytes = base64Decode(b64);
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              Uint8List.fromList(bytes),
              width: 48, height: 48, fit: BoxFit.cover,
              errorBuilder: (c, e, s) => _buildIconFallback(icon, color),
            ),
          );
        }
      } catch (_) {}
    }
    return _buildIconFallback(icon, color);
  }

  Widget _buildIconFallback(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildProductListItem(Product product) {
    final bool lowStock = _stockOf(product) <= product.reorderLevel;
    final bool outOfStock = _stockOf(product) == 0;

    IconData categoryIcon;
    Color categoryColor;
    switch (product.category) {
      case 'Beverages':
        categoryIcon = Icons.local_drink;
        categoryColor = Colors.blue;
        break;
      case 'Snacks':
        categoryIcon = Icons.cookie;
        categoryColor = Colors.orange;
        break;
      case 'Rice & Grains':
        categoryIcon = Icons.rice_bowl;
        categoryColor = Colors.brown;
        break;
      case 'Canned Goods':
        categoryIcon = Icons.inventory;
        categoryColor = Colors.red;
        break;
      case 'Personal Care':
        categoryIcon = Icons.soap;
        categoryColor = Colors.teal;
        break;
      default:
        categoryIcon = Icons.shopping_bag;
        categoryColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            outOfStock
                ? const BorderSide(color: Colors.red, width: 1.5)
                : lowStock
                ? const BorderSide(color: Colors.orange, width: 1.5)
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => widget.isSelecting
            ? Navigator.pop(context, product)
            : _showProductDetails(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product Image or Icon
              _buildProductThumb(product, categoryIcon, categoryColor),
              const SizedBox(width: 12),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          product.sku,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            product.category,
                            style: TextStyle(
                              fontSize: 9,
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          product.sellingPrice.toStringAsFixed(2),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppSettings.showCostPrice ? 'Cost: ${product.costPrice.toStringAsFixed(2)}' : '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Stock & Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Stock Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          outOfStock
                              ? Colors.red[50]
                              : lowStock
                              ? Colors.orange[50]
                              : Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            outOfStock
                                ? Colors.red
                                : lowStock
                                ? Colors.orange
                                : Colors.green,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      outOfStock
                          ? 'OUT'
                          : '${_stockOf(product)} ${product.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            outOfStock
                                ? Colors.red
                                : lowStock
                                ? Colors.orange[800]
                                : Colors.green[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Action Buttons
                  if (!widget.isSelecting && _isHeadOffice)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit
                      InkWell(
                        onTap: () => _navigateToEditProduct(product),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Colors.orange[600],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Delete
                      InkWell(
                        onTap: () => _deleteProduct(product),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          if (_sortBy == value)
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: Colors.orange,
            ),
        ],
      ),
    );
  }

  // === Navigation Methods ===
  void _navigateToAddProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEditProductScreen(readOnly: !_canEdit)),
    );
    if (result != null && result is Product) {
      _addProduct(result);
      _showSnackBar('${result.name} added successfully!');
    }
  }

  void _navigateToEditProduct(Product product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditProductScreen(product: product, readOnly: !_canEdit),
      ),
    );
    if (result != null && result is Product) {
      _updateProduct(product, result);
      _showSnackBar('${result.name} updated successfully!');
    }
  }

  void _showProductDetails(Product product) {
    final profit = product.sellingPrice - product.costPrice;
    final margin = (profit / product.sellingPrice) * 100;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Details
                _buildDetailRow('SKU', product.sku),
                _buildDetailRow('Category', product.category),
                _buildDetailRow('Unit', product.unit),
                _buildDetailRow('Barcode', product.barcode.isNotEmpty ? product.barcode : 'N/A'),
                const Divider(height: 20),
                AppSettings.showCostPrice ? _buildDetailRow('Cost Price', product.costPrice.toStringAsFixed(2)) : const SizedBox(),
                _buildDetailRow('Selling Price', product.sellingPrice.toStringAsFixed(2)),
                AppSettings.showCostPrice ? _buildDetailRow('Profit', '${profit.toStringAsFixed(2)} (${margin.toStringAsFixed(1)}%)') : const SizedBox(),
                const Divider(height: 20),
                _buildDetailRow('Stock Qty', '${_stockOf(product)} ${product.unit}'),
                _buildDetailRow('Reorder Level', '${product.reorderLevel} ${product.unit}'),
                AppSettings.showCostPrice ? _buildDetailRow('Stock Value', (product.costPrice * _stockOf(product)).toStringAsFixed(2)) : const SizedBox(),
                const SizedBox(height: 16),

                // Buttons
                if (_isHeadOffice) Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _navigateToEditProduct(product);
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // ── DELETE ALL ITEMS (3-Step Confirmation) ──
  // ══════════════════════════════════════════════

  void _showDeleteAllConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete All Items', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to delete ALL ${_products.length} products, including their batches and stock data.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ This action CANNOT be undone!',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () { Navigator.pop(ctx); _showTypeDeleteConfirmation(); },
            child: const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTypeDeleteConfirmation() {
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Type Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Type "DELETE ALL" to confirm:', style: TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Type DELETE ALL'),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (confirmCtrl.text.trim().toUpperCase() == 'DELETE ALL') {
                Navigator.pop(ctx);
                _showDeletePinDialog();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please type "DELETE ALL" exactly'), backgroundColor: Colors.orange),
                );
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeletePinDialog() {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.purple),
            SizedBox(width: 8),
            Text('Manager PIN Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter Manager PIN to proceed:'),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter PIN',
                prefixIcon: Icon(Icons.pin),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final mgr = AppUser.allUsers.where((u) => (u.role == 'Admin' || u.role == 'Manager') && u.pin == pinCtrl.text.trim()).firstOrNull;
              if (mgr != null) {
                Navigator.pop(ctx);
                _executeDeleteAll();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid Manager PIN'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeleteAll() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.purple)),
    );
    try {
      final count = _products.length;
      final db = await DatabaseHelper().database;
      await db.delete('batches');
      await db.delete('products');
      Product.allProducts.clear();
      if (mounted) {
        Navigator.pop(context);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Successfully deleted $count products and all related batches!')),
            ]),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting items: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
