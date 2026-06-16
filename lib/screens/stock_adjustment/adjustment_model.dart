// lib/screens/stock_adjustment/adjustment_model.dart
import '../../helpers/database_helper.dart';

class AdjustmentRecord {
  final String id;
  final String itemName;
  final String sku;
  final String adjustmentType;
  final int quantity;
  final int oldStock;
  final int newStock;
  final String reason;
  final String notes;
  final DateTime dateTime;
  final double cost;
  final double retail;

  AdjustmentRecord({
    required this.id, required this.itemName, required this.sku,
    required this.adjustmentType, required this.quantity,
    required this.oldStock, required this.newStock,
    required this.reason, required this.notes, required this.dateTime,
    required this.cost, required this.retail,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'itemName': itemName, 'sku': sku,
    'adjustmentType': adjustmentType, 'quantity': quantity,
    'oldStock': oldStock, 'newStock': newStock,
    'reason': reason, 'notes': notes,
    'dateTime': dateTime.toIso8601String(),
    'cost': cost, 'retail': retail,
  };

  factory AdjustmentRecord.fromJson(Map<String, dynamic> json) => AdjustmentRecord(
    id: json['id'] ?? '', itemName: json['itemName'] ?? '',
    sku: json['sku'] ?? '', adjustmentType: json['adjustmentType'] ?? '',
    quantity: json['quantity'] ?? 0, oldStock: json['oldStock'] ?? 0,
    newStock: json['newStock'] ?? 0, reason: json['reason'] ?? '',
    notes: json['notes'] ?? '',
    dateTime: DateTime.tryParse(json['dateTime'] ?? '') ?? DateTime.now(),
    cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
    retail: (json['retail'] as num?)?.toDouble() ?? 0.0,
  );

  Map<String, dynamic> toMap() => toJson();
  factory AdjustmentRecord.fromMap(Map<String, dynamic> m) => AdjustmentRecord.fromJson(m);
}

class AdjustmentStorage {
  static Future<void> saveAdjustment(AdjustmentRecord record) async {
    await DatabaseHelper().insertAdjustmentRecord(record.toMap());
  }

  static Future<List<AdjustmentRecord>> getAll() async {
    final rows = await DatabaseHelper().getAllAdjustmentRecords();
    return rows.map((r) => AdjustmentRecord.fromMap(r)).toList();
  }

  static Future<List<AdjustmentRecord>> getFiltered({
    DateTime? dateFrom, DateTime? dateTo, String searchQuery = '',
  }) async {
    final rows = await DatabaseHelper().getFilteredAdjustments(
      dateFrom: dateFrom != null ? DateTime(dateFrom.year, dateFrom.month, dateFrom.day).toIso8601String() : null,
      dateTo: dateTo != null ? DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59).toIso8601String() : null,
      search: searchQuery.trim(),
    );
    return rows.map((r) => AdjustmentRecord.fromMap(r)).toList();
  }

  static String exportToCsv(List<AdjustmentRecord> records) {
    final buf = StringBuffer();
    buf.writeln('Date,Time,Item,SKU,Type,Quantity,Old Stock,New Stock,Reason,Notes,Cost,Retail');
    for (final r in records) {
      final date = '${r.dateTime.year}-${_pad(r.dateTime.month)}-${_pad(r.dateTime.day)}';
      final time = '${_pad(r.dateTime.hour)}:${_pad(r.dateTime.minute)}:${_pad(r.dateTime.second)}';
      buf.writeln('$date,$time,"${r.itemName}","${r.sku}",${r.adjustmentType},${r.quantity},${r.oldStock},${r.newStock},"${r.reason}","${r.notes}",${r.cost},${r.retail}');
    }
    return buf.toString();
  }

  static Future<void> clearAll() async {
    await DatabaseHelper().clearAdjustmentRecords();
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
