// lib/screens/receive_delivery/delivery_model.dart
import '../../helpers/database_helper.dart';

class DeliveryItemRecord {
  final String productId;
  final String itemName;
  final String sku;
  final int quantity;
  final int oldStock;
  final int newStock;
  final double cost;
  final double retail;
  final String batchNumber;
  final String mfgDate;
  final String expDate;

  DeliveryItemRecord({
    required this.productId, required this.itemName, required this.sku,
    required this.quantity, required this.oldStock, required this.newStock,
    required this.cost, required this.retail,
    this.batchNumber = '', this.mfgDate = '', this.expDate = '',
  });

  Map<String, dynamic> toJson() => {
    'productId': productId, 'itemName': itemName, 'sku': sku,
    'quantity': quantity, 'oldStock': oldStock, 'newStock': newStock,
    'cost': cost, 'retail': retail,
    'batchNumber': batchNumber, 'mfgDate': mfgDate, 'expDate': expDate,
  };

  factory DeliveryItemRecord.fromJson(Map<String, dynamic> json) => DeliveryItemRecord(
    productId: json['productId'] ?? '', itemName: json['itemName'] ?? '',
    sku: json['sku'] ?? '', quantity: json['quantity'] ?? 0,
    oldStock: json['oldStock'] ?? 0, newStock: json['newStock'] ?? 0,
    cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
    retail: (json['retail'] as num?)?.toDouble() ?? 0.0,
    batchNumber: json['batchNumber'] ?? '', mfgDate: json['mfgDate'] ?? '',
    expDate: json['expDate'] ?? '',
  );

  Map<String, dynamic> toMap() => toJson();
  factory DeliveryItemRecord.fromMap(Map<String, dynamic> m) => DeliveryItemRecord.fromJson(m);
}

class DeliveryRecord {
  final String id;
  final String refNumber;
  final String supplier;
  final String driverName;
  final String plateNumber;
  final String receivedBy;
  final String notes;
  final List<DeliveryItemRecord> items;
  final int totalItems;
  final int totalQuantity;
  final double totalCost;
  final double totalRetail;
  final DateTime dateTime;

  DeliveryRecord({
    required this.id, required this.refNumber, required this.supplier,
    required this.driverName, required this.plateNumber,
    required this.receivedBy, required this.notes, required this.items,
    required this.totalItems, required this.totalQuantity,
    required this.totalCost, required this.totalRetail,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'refNumber': refNumber, 'supplier': supplier,
    'driverName': driverName, 'plateNumber': plateNumber,
    'receivedBy': receivedBy, 'notes': notes,
    'items': items.map((e) => e.toJson()).toList(),
    'totalItems': totalItems, 'totalQuantity': totalQuantity,
    'totalCost': totalCost, 'totalRetail': totalRetail,
    'dateTime': dateTime.toIso8601String(),
  };

  factory DeliveryRecord.fromJson(Map<String, dynamic> json) => DeliveryRecord(
    id: json['id'] ?? '', refNumber: json['refNumber'] ?? '',
    supplier: json['supplier'] ?? '', driverName: json['driverName'] ?? '',
    plateNumber: json['plateNumber'] ?? '', receivedBy: json['receivedBy'] ?? '',
    notes: json['notes'] ?? '',
    items: (json['items'] as List<dynamic>?)?.map((e) => DeliveryItemRecord.fromJson(e)).toList() ?? [],
    totalItems: json['totalItems'] ?? 0, totalQuantity: json['totalQuantity'] ?? 0,
    totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0.0,
    totalRetail: (json['totalRetail'] as num?)?.toDouble() ?? 0.0,
    dateTime: DateTime.tryParse(json['dateTime'] ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'refNumber': refNumber, 'supplier': supplier,
    'driverName': driverName, 'plateNumber': plateNumber,
    'receivedBy': receivedBy, 'notes': notes,
    'totalItems': totalItems, 'totalQuantity': totalQuantity,
    'totalCost': totalCost, 'totalRetail': totalRetail,
    'dateTime': dateTime.toIso8601String(),
  };

  factory DeliveryRecord.fromMap(Map<String, dynamic> m, List<DeliveryItemRecord> items) => DeliveryRecord(
    id: m['id'] ?? '', refNumber: m['refNumber'] ?? '',
    supplier: m['supplier'] ?? '', driverName: m['driverName'] ?? '',
    plateNumber: m['plateNumber'] ?? '', receivedBy: m['receivedBy'] ?? '',
    notes: m['notes'] ?? '', items: items,
    totalItems: m['totalItems'] ?? items.length,
    totalQuantity: m['totalQuantity'] ?? items.fold(0, (s, i) => s + i.quantity),
    totalCost: (m['totalCost'] as num?)?.toDouble() ?? 0.0,
    totalRetail: (m['totalRetail'] as num?)?.toDouble() ?? 0.0,
    dateTime: DateTime.tryParse(m['dateTime'] ?? '') ?? DateTime.now(),
  );
}

class DeliveryStorage {
  static Future<void> saveDelivery(DeliveryRecord record) async {
    final itemMaps = record.items.map((i) => i.toMap()).toList();
    await DatabaseHelper().insertDeliveryWithItems(record.toMap(), itemMaps);
  }

  static Future<List<DeliveryRecord>> getAll() async {
    final db = DatabaseHelper();
    final rows = await db.getAllDeliveryRecords();
    List<DeliveryRecord> result = [];
    for (final row in rows) {
      final itemRows = await db.getDeliveryItems(row['id']);
      final items = itemRows.map((r) => DeliveryItemRecord.fromMap(r)).toList();
      result.add(DeliveryRecord.fromMap(row, items));
    }
    return result;
  }

  static Future<List<DeliveryRecord>> getFiltered({
    DateTime? dateFrom, DateTime? dateTo, String searchQuery = '',
  }) async {
    final db = DatabaseHelper();
    final rows = await db.getFilteredDeliveries(
      dateFrom: dateFrom != null ? DateTime(dateFrom.year, dateFrom.month, dateFrom.day).toIso8601String() : null,
      dateTo: dateTo != null ? DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59).toIso8601String() : null,
      search: searchQuery.trim(),
    );
    List<DeliveryRecord> result = [];
    for (final row in rows) {
      final itemRows = await db.getDeliveryItems(row['id']);
      final items = itemRows.map((r) => DeliveryItemRecord.fromMap(r)).toList();
      result.add(DeliveryRecord.fromMap(row, items));
    }
    return result;
  }

  static Future<List<DeliveryRecord>> getDaily({DateTime? date}) async {
    final d = date ?? DateTime.now();
    final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final db = DatabaseHelper();
    final rows = await db.getDailyDeliveries(dateStr);
    List<DeliveryRecord> result = [];
    for (final row in rows) {
      final itemRows = await db.getDeliveryItems(row['id']);
      final items = itemRows.map((r) => DeliveryItemRecord.fromMap(r)).toList();
      result.add(DeliveryRecord.fromMap(row, items));
    }
    return result;
  }

  static Future<void> clearAll() async {
    await DatabaseHelper().clearDeliveryRecords();
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
