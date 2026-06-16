// lib/models/batch_model.dart
import '../helpers/database_helper.dart';

class ProductBatch {
  final String id;
  final String productId;
  final String productName;
  final String productSku;
  final String batchNumber;
  final DateTime manufacturedDate;
  final DateTime expiryDate;
  final int quantity;
  final int originalQty;
  final double costPrice;
  final String supplier;
  final String notes;
  final DateTime dateAdded;

  ProductBatch({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.batchNumber,
    required this.manufacturedDate,
    required this.expiryDate,
    required this.quantity,
    required this.originalQty,
    this.costPrice = 0,
    this.supplier = '',
    this.notes = '',
    required this.dateAdded,
  });

  ProductBatch copyWith({
    String? id, String? productId, String? productName, String? productSku,
    String? batchNumber, DateTime? manufacturedDate, DateTime? expiryDate,
    int? quantity, int? originalQty, double? costPrice,
    String? supplier, String? notes, DateTime? dateAdded,
  }) {
    return ProductBatch(
      id: id ?? this.id, productId: productId ?? this.productId,
      productName: productName ?? this.productName, productSku: productSku ?? this.productSku,
      batchNumber: batchNumber ?? this.batchNumber,
      manufacturedDate: manufacturedDate ?? this.manufacturedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      quantity: quantity ?? this.quantity, originalQty: originalQty ?? this.originalQty,
      costPrice: costPrice ?? this.costPrice, supplier: supplier ?? this.supplier,
      notes: notes ?? this.notes, dateAdded: dateAdded ?? this.dateAdded,
    );
  }

  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;
  bool get isExpired => DateTime.now().isAfter(expiryDate);
  bool get isNearExpiry => !isExpired && daysUntilExpiry <= 30;
  bool get isWarning => !isExpired && daysUntilExpiry <= 90 && daysUntilExpiry > 30;
  bool get isFresh => daysUntilExpiry > 90;
  double get usedPercent => originalQty > 0 ? ((originalQty - quantity) / originalQty) * 100 : 0;

  String get statusLabel {
    if (isExpired) return 'EXPIRED';
    if (quantity == 0) return 'DEPLETED';
    if (isNearExpiry) return 'NEAR EXPIRY';
    if (isWarning) return 'WARNING';
    return 'FRESH';

  }
  String get expiryText {
    if (isExpired) return 'Expired ${-daysUntilExpiry} days ago';
    return 'Expires in $daysUntilExpiry days';
  }

  Map<String, dynamic> toMap() => {
    'id': id, 'productId': productId, 'productName': productName,
    'productSku': productSku, 'batchNumber': batchNumber,
    'manufacturedDate': manufacturedDate.toIso8601String(),
    'expiryDate': expiryDate.toIso8601String(),
    'quantity': quantity, 'originalQty': originalQty,
    'costPrice': costPrice, 'supplier': supplier,
    'notes': notes, 'dateAdded': dateAdded.toIso8601String(),
  };

  factory ProductBatch.fromMap(Map<String, dynamic> m) => ProductBatch(
    id: m['id'] ?? '', productId: m['productId'] ?? '',
    productName: m['productName'] ?? '', productSku: m['productSku'] ?? '',
    batchNumber: m['batchNumber'] ?? '',
    manufacturedDate: DateTime.tryParse(m['manufacturedDate'] ?? '') ?? DateTime.now(),
    expiryDate: DateTime.tryParse(m['expiryDate'] ?? '') ?? DateTime.now(),
    quantity: m['quantity'] ?? 0, originalQty: m['originalQty'] ?? 0,
    costPrice: (m['costPrice'] ?? 0).toDouble(),
    supplier: m['supplier'] ?? '', notes: m['notes'] ?? '',
    dateAdded: DateTime.tryParse(m['dateAdded'] ?? '') ?? DateTime.now(),
  );

  static List<ProductBatch> _allBatches = [];
  static bool _loaded = false;

  static List<ProductBatch> get allBatches {
    if (!_loaded && _allBatches.isEmpty) _allBatches = [];
    return _allBatches;
  }

  static Future<void> loadFromDB() async {
    final db = DatabaseHelper();
    final rows = await db.getAllBatches();
    if (rows.isEmpty) {
      _allBatches = [];
    } else {
      _allBatches = rows.map((r) => ProductBatch.fromMap(r)).toList();
    }
    _loaded = true;
  }

  static void addBatch(ProductBatch b) {
    _allBatches = allBatches;
    _allBatches.insert(0, b);
    DatabaseHelper().insertBatch(b.toMap()).catchError((_) => 0);
  }

  static void updateBatch(String id, ProductBatch u) {
    final i = _allBatches.indexWhere((b) => b.id == id);
    if (i >= 0) _allBatches[i] = u;
    DatabaseHelper().updateBatch(id, u.toMap()).catchError((_) => 0);
  }

  static void deleteBatch(String id) {
    _allBatches.removeWhere((b) => b.id == id);
    DatabaseHelper().deleteBatch(id).catchError((_) => 0);
  }

  static List<ProductBatch> getSampleBatches() {
    final now = DateTime.now();
    return [
      ProductBatch(id: 'B-001', productId: 'CND-001', productName: 'Argentina Corned Beef',
        productSku: 'CND-001', batchNumber: 'LOT-2025-001',
        manufacturedDate: DateTime(2025, 1, 15), expiryDate: DateTime(2026, 1, 15),
        quantity: 50, originalQty: 60, costPrice: 32, supplier: 'CDO Foodsphere',
        dateAdded: now.subtract(const Duration(days: 120))),
      ProductBatch(id: 'B-002', productId: 'CND-001', productName: 'Argentina Corned Beef',
        productSku: 'CND-001', batchNumber: 'LOT-2025-045',
        manufacturedDate: DateTime(2025, 3, 10), expiryDate: DateTime(2026, 3, 10),
        quantity: 45, originalQty: 50, costPrice: 32, supplier: 'CDO Foodsphere',
        dateAdded: now.subtract(const Duration(days: 60))),
      ProductBatch(id: 'B-003', productId: 'BEV-001', productName: 'Coca-Cola 1.5L',
        productSku: 'BEV-001', batchNumber: 'LOT-2025-100',
        manufacturedDate: DateTime(2025, 4, 1), expiryDate: now.add(const Duration(days: 15)),
        quantity: 80, originalQty: 120, costPrice: 42, supplier: 'Coca-Cola Bottlers PH',
        dateAdded: now.subtract(const Duration(days: 45))),
      ProductBatch(id: 'B-004', productId: 'BEV-002', productName: 'Sprite 1.5L',
        productSku: 'BEV-002', batchNumber: 'LOT-2025-101',
        manufacturedDate: DateTime(2025, 2, 1), expiryDate: now.subtract(const Duration(days: 5)),
        quantity: 10, originalQty: 85, costPrice: 42, supplier: 'Coca-Cola Bottlers PH',
        dateAdded: now.subtract(const Duration(days: 90))),
      ProductBatch(id: 'B-005', productId: 'SNK-003', productName: 'Chippy Garlic Vinegar',
        productSku: 'SNK-003', batchNumber: 'LOT-2025-200',
        manufacturedDate: DateTime(2025, 5, 1), expiryDate: now.add(const Duration(days: 60)),
        quantity: 100, originalQty: 180, costPrice: 8, supplier: 'Jack n Jill',
        dateAdded: now.subtract(const Duration(days: 30))),
      ProductBatch(id: 'B-006', productId: 'SNK-001', productName: 'Piattos Cheese',
        productSku: 'SNK-001', batchNumber: 'LOT-2025-201',
        manufacturedDate: DateTime(2025, 5, 15), expiryDate: now.add(const Duration(days: 200)),
        quantity: 150, originalQty: 150, costPrice: 18, supplier: 'Jack n Jill',
        dateAdded: now.subtract(const Duration(days: 15))),
    ];
  }
}
