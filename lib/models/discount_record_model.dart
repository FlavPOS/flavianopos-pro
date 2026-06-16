// lib/models/discount_record_model.dart
import '../helpers/database_helper.dart';

class DiscountItemRecord {
  final String itemName;
  final String sku;
  final int qty;
  final double unitPrice;
  final double grossAmount;
  final double discountAmount;
  final double netAmount;

  DiscountItemRecord({
    required this.itemName, this.sku = '', required this.qty,
    required this.unitPrice, required this.grossAmount,
    required this.discountAmount, required this.netAmount,
  });

  Map<String, dynamic> toMap() => {
    'itemName': itemName, 'sku': sku, 'qty': qty,
    'unitPrice': unitPrice, 'grossAmount': grossAmount,
    'discountAmount': discountAmount, 'netAmount': netAmount,
  };

  factory DiscountItemRecord.fromMap(Map<String, dynamic> m) => DiscountItemRecord(
    itemName: m['itemName'] ?? '', sku: m['sku'] ?? '',
    qty: m['qty'] ?? 0, unitPrice: (m['unitPrice'] ?? 0).toDouble(),
    grossAmount: (m['grossAmount'] ?? 0).toDouble(),
    discountAmount: (m['discountAmount'] ?? 0).toDouble(),
    netAmount: (m['netAmount'] ?? 0).toDouble(),
  );
}

class DiscountRecord {
  final int? dbId; // AUTO INCREMENT id from DB (null for new records)
  final String transactionId;
  final DateTime dateTime;
  final String discountType;
  final String? customerName;
  final String? idNumber;
  final int? age;
  final double discountPercentage;
  final double fixedDiscount;
  final bool isPercentage;
  final List<DiscountItemRecord> items;
  final double totalGross;
  final double totalDiscount;
  final double totalNet;
  final String cashier;
  final String branch;

  DiscountRecord({
    this.dbId,
    required this.transactionId, required this.dateTime,
    required this.discountType, this.customerName, this.idNumber,
    this.age, this.discountPercentage = 0, this.fixedDiscount = 0,
    this.isPercentage = true, required this.items,
    required this.totalGross, required this.totalDiscount,
    required this.totalNet, required this.cashier, required this.branch,
  });

  int get totalUnits => items.fold(0, (s, i) => s + i.qty);

  Map<String, dynamic> toMap() => {
    'transactionId': transactionId,
    'dateTime': dateTime.toIso8601String(),
    'discountType': discountType,
    'customerName': customerName ?? '',
    'idNumber': idNumber ?? '',
    'age': age,
    'discountPercentage': discountPercentage,
    'fixedDiscount': fixedDiscount,
    'isPercentage': isPercentage ? 1 : 0,
    'totalGross': totalGross,
    'totalDiscount': totalDiscount,
    'totalNet': totalNet,
    'cashier': cashier,
    'branch': branch,
  };

  factory DiscountRecord.fromMap(Map<String, dynamic> m, List<DiscountItemRecord> items) => DiscountRecord(
    dbId: m['id'] as int?,
    transactionId: m['transactionId'] ?? '',
    dateTime: DateTime.tryParse(m['dateTime'] ?? '') ?? DateTime.now(),
    discountType: m['discountType'] ?? '',
    customerName: m['customerName'],
    idNumber: m['idNumber'],
    age: m['age'] as int?,
    discountPercentage: (m['discountPercentage'] ?? 0).toDouble(),
    fixedDiscount: (m['fixedDiscount'] ?? 0).toDouble(),
    isPercentage: (m['isPercentage'] ?? 1) == 1,
    items: items,
    totalGross: (m['totalGross'] ?? 0).toDouble(),
    totalDiscount: (m['totalDiscount'] ?? 0).toDouble(),
    totalNet: (m['totalNet'] ?? 0).toDouble(),
    cashier: m['cashier'] ?? '',
    branch: m['branch'] ?? '',
  );

  // ══════════ In-Memory Cache + SQLite Backend ══════════

  static List<DiscountRecord> _records = [];
  static bool _loaded = false;

  static List<DiscountRecord> get allRecords {
    if (!_loaded) return _records;
    return _records;
  }

  static Future<void> loadFromDB() async {
    final db = DatabaseHelper();
    final rows = await db.getAllDiscountRecords();
    _records = [];
    for (final row in rows) {
      final id = row['id'] as int;
      final itemRows = await db.getDiscountItems(id);
      final items = itemRows.map((r) => DiscountItemRecord.fromMap(r)).toList();
      _records.add(DiscountRecord.fromMap(row, items));
    }
    _loaded = true;
  }

  static void addRecord(DiscountRecord record) {
    _records.insert(0, record);
    // Save to DB
    DatabaseHelper().insertDiscountWithItems(
      record.toMap(),
      record.items.map((i) => i.toMap()).toList(),
    ).catchError((_) => 0);
  }

  static void clearRecords() {
    _records.clear();
    DatabaseHelper().clearDiscountRecords().catchError((_) => null);
  }

  static List<DiscountRecord> getByType(String type) {
    if (type == 'All') return _records;
    return _records.where((r) => r.discountType == type).toList();
  }

  static List<DiscountRecord> getByDateRange(DateTime start, DateTime end) {
    return _records.where((r) =>
      r.dateTime.isAfter(start) && r.dateTime.isBefore(end.add(const Duration(days: 1)))
    ).toList();
  }
}
