// lib/models/batch_log_model.dart
import '../helpers/database_helper.dart';

class BatchLog {
  final String id;
  final String batchId;
  final String batchNumber;
  final String productName;
  final String productSku;
  final String action;
  final String reason;
  final String field;
  final String oldValue;
  final String newValue;
  final DateTime dateTime;

  BatchLog({
    required this.id, required this.batchId, required this.batchNumber,
    required this.productName, required this.productSku,
    required this.action, this.reason = '', required this.field,
    this.oldValue = '', this.newValue = '', required this.dateTime,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'batchId': batchId, 'batchNumber': batchNumber,
    'productName': productName, 'productSku': productSku,
    'action': action, 'reason': reason, 'field': field,
    'oldValue': oldValue, 'newValue': newValue,
    'dateTime': dateTime.toIso8601String(),
  };

  factory BatchLog.fromJson(Map<String, dynamic> j) => BatchLog(
    id: j['id'] ?? '', batchId: j['batchId'] ?? '',
    batchNumber: j['batchNumber'] ?? '', productName: j['productName'] ?? '',
    productSku: j['productSku'] ?? '', action: j['action'] ?? '',
    reason: j['reason'] ?? '', field: j['field'] ?? '',
    oldValue: j['oldValue'] ?? '', newValue: j['newValue'] ?? '',
    dateTime: DateTime.tryParse(j['dateTime'] ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => toJson();

  factory BatchLog.fromMap(Map<String, dynamic> m) => BatchLog.fromJson(m);
}

class BatchLogStorage {
  static Future<void> saveLog(BatchLog log) async {
    await DatabaseHelper().insertBatchLog(log.toMap());
  }

  static Future<void> saveLogs(List<BatchLog> logs) async {
    await DatabaseHelper().bulkInsertBatchLogs(logs.map((l) => l.toMap()).toList());
  }

  static Future<List<BatchLog>> getAll() async {
    final rows = await DatabaseHelper().getAllBatchLogs();
    return rows.map((r) => BatchLog.fromMap(r)).toList();
  }

  static Future<List<BatchLog>> getByBatchId(String batchId) async {
    final rows = await DatabaseHelper().getBatchLogsByBatchId(batchId);
    return rows.map((r) => BatchLog.fromMap(r)).toList();
  }

  static Future<List<BatchLog>> getFiltered({
    DateTime? dateFrom, DateTime? dateTo, String searchQuery = '',
  }) async {
    final rows = await DatabaseHelper().getFilteredBatchLogs(
      dateFrom: dateFrom != null ? DateTime(dateFrom.year, dateFrom.month, dateFrom.day).toIso8601String() : null,
      dateTo: dateTo != null ? DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59).toIso8601String() : null,
      search: searchQuery.trim(),
    );
    return rows.map((r) => BatchLog.fromMap(r)).toList();
  }

  static Future<void> clearAll() async {
    await DatabaseHelper().clearBatchLogs();
  }
}
