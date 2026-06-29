// lib/models/product_model.dart
import '../helpers/database_helper.dart';
import '../helpers/sync_bridge.dart';
import 'sync_queue_model.dart';

class Product {
  final String id;
  final String sku;
  final String name;
  final String category;
  final String unit;
  final double costPrice;
  final double sellingPrice;
  final int stockQty;
  final int reorderLevel;
  final String barcode;
  final String? imagePath;
  final String imageUrl;

  Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    this.unit = 'pcs',
    required this.costPrice,
    required this.sellingPrice,
    required this.stockQty,
    this.reorderLevel = 10,
    this.barcode = '',
    this.imageUrl = '',
    this.imagePath,
  });

  // ══════════ SQLite Serialization ══════════

  Map<String, dynamic> toMap() => {
    'id': id, 'sku': sku, 'name': name, 'category': category, 'unit': unit,
    'costPrice': costPrice, 'sellingPrice': sellingPrice, 'stockQty': stockQty,
    'reorderLevel': reorderLevel, 'barcode': barcode,
    'imagePath': imagePath, 'imageUrl': imageUrl,
  };

  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id: m['id'] ?? '', sku: m['sku'] ?? '', name: m['name'] ?? '',
    category: m['category'] ?? '', unit: m['unit'] ?? 'pcs',
    costPrice: (m['costPrice'] ?? 0).toDouble(),
    sellingPrice: (m['sellingPrice'] ?? 0).toDouble(),
    stockQty: m['stockQty'] ?? 0, reorderLevel: m['reorderLevel'] ?? 10,
    barcode: m['barcode'] ?? '', imagePath: m['imagePath'],
    imageUrl: m['imageUrl'] ?? '',
  );

  // ══════════ In-Memory Cache + SQLite Backend ══════════

  static List<Product> _allProducts = [];
  static bool _loaded = false;

  static List<Product> get allProducts {
    if (!_loaded && _allProducts.isEmpty) {
      _allProducts = [];
    }
    return _allProducts;
  }

  /// Call once at app startup (after DB init)
  static Future<void> loadFromDB() async {
    final db = DatabaseHelper();
    final rows = await db.getAllProducts();
    if (rows.isEmpty) {
      _allProducts = [];
    } else {
      _allProducts = rows.map((r) => Product.fromMap(r)).toList();
    }
    _loaded = true;
  }

  static void updateProduct(String id, Product newProduct) {
    final index = _allProducts.indexWhere((p) => p.id == id);
    if (index >= 0) _allProducts[index] = newProduct;
    // Write to DB (fire & forget)
    DatabaseHelper().updateProduct(id, newProduct.toMap()).catchError((_) => 0);
    SyncBridge.enqueueProduct(newProduct, op: SyncOp.update);
  }

  static void addProduct(Product product) {
    _allProducts.add(product);
    DatabaseHelper().insertProduct(product.toMap()).catchError((_) => 0);
    SyncBridge.enqueueProduct(product, op: SyncOp.create);
  }

  static void removeProduct(String id) {
    _allProducts.removeWhere((p) => p.id == id);
    DatabaseHelper().deleteProduct(id).catchError((_) => 0);
    final removed = _allProducts.firstWhere((p) => p.id == id, orElse: () => Product(id: id, sku: "", name: "", stockQty: 0, category: "", costPrice: 0, sellingPrice: 0));
    SyncBridge.enqueueProduct(removed, op: SyncOp.delete);
  }

  // ══════════ Sample Data ══════════

  static List<Product> getSampleProducts() {
    return [
      Product(id: '1', sku: 'BEV-001', name: 'Coca-Cola 1.5L', category: 'Beverages', costPrice: 45.00, sellingPrice: 65.00, stockQty: 120, barcode: '4800100123456'),
      Product(id: '2', sku: 'BEV-002', name: 'Sprite 1.5L', category: 'Beverages', costPrice: 45.00, sellingPrice: 65.00, stockQty: 85, barcode: '4800100223456'),
      Product(id: '3', sku: 'BEV-003', name: 'Royal 500ml', category: 'Beverages', costPrice: 12.00, sellingPrice: 20.00, stockQty: 200, barcode: '4800100323456'),
      Product(id: '4', sku: 'SNK-001', name: 'Piattos Cheese', category: 'Snacks', costPrice: 18.00, sellingPrice: 28.00, stockQty: 150, barcode: '4800100423456'),
      Product(id: '5', sku: 'CND-001', name: 'Argentina Corned Beef', category: 'Canned Goods', costPrice: 32.00, sellingPrice: 48.00, stockQty: 95, barcode: '4800100523456'),
      Product(id: '6', sku: 'CND-002', name: 'Century Tuna Flakes', category: 'Canned Goods', costPrice: 28.00, sellingPrice: 42.00, stockQty: 110, barcode: '4800100623457'),
      Product(id: '7', sku: 'SNK-003', name: 'Chippy Garlic Vinegar', category: 'Snacks', costPrice: 8.00, sellingPrice: 15.00, stockQty: 180, barcode: '4800100723457'),
      Product(id: '8', sku: 'HYG-002', name: 'Head & Shoulders 180ml', category: 'Personal Care', costPrice: 95.00, sellingPrice: 140.00, stockQty: 60, barcode: '4800100823456'),
      Product(id: '9', sku: 'RCG-001', name: 'Jasmine Rice 5kg', category: 'Rice & Grains', costPrice: 240.00, sellingPrice: 320.00, stockQty: 35, barcode: '4800100923456'),
      Product(id: '10', sku: 'RCG-002', name: 'Sinandomeng Rice 5kg', category: 'Rice & Grains', costPrice: 210.00, sellingPrice: 280.00, stockQty: 50, barcode: '4800101023456'),
      Product(id: '11', sku: 'CND-003', name: 'Nova Country Cheddar', category: 'Canned Goods', costPrice: 16.00, sellingPrice: 25.00, stockQty: 130, barcode: '4800101123456'),
      Product(id: '12', sku: 'HYG-001', name: 'Safeguard Soap 135g', category: 'Personal Care', costPrice: 32.00, sellingPrice: 48.00, stockQty: 90, barcode: '4800101223456'),
      Product(id: '13', sku: 'SNK-002', name: 'Oishi Prawn Crackers', category: 'Snacks', costPrice: 10.00, sellingPrice: 18.00, stockQty: 160, barcode: '4800101323456'),
      Product(id: '14', sku: 'HYG-003', name: 'Colgate Fresh 150ml', category: 'Personal Care', costPrice: 65.00, sellingPrice: 95.00, stockQty: 75, barcode: '4800100623456'),
      Product(id: '15', sku: 'SNK-004', name: 'SkyFlakes Crackers', category: 'Snacks', costPrice: 35.00, sellingPrice: 52.00, stockQty: 100, barcode: '4800100723456'),
    ];
  }
}
