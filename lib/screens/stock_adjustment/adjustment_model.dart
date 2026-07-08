// lib/screens/stock_adjustment/adjustment_model.dart
// Enterprise multi-branch stock adjustment record
import '../../helpers/database_helper.dart';

class AdjustmentRecord {
  final String id;
  final String itemName;
  final String sku;
  final String productId;                    // NEW: Product ID reference
  final String adjustmentType;                // 'Add' | 'Deduct'
  final int quantity;
  final int oldStock;
  final int newStock;
  final String reason;
  final String notes;
  final DateTime dateTime;
  final double cost;
  final double retail;

  // NEW: Branch Code Architecture
  final String branchCode;                    // HO001, BR001 (system key)
  final String branchName;                    // Display name

  // NEW: Audit Trail
  final String createdBy;                     // Username who made it
  final String createdByUserId;               // User ID
  final String approvedBy;                    // Manager who approved
  final String approvedByUserId;
  final String deviceId;                      // Audit trail

  // NEW: Sync tracking
  final String syncStatus;                    // pending | synced | failed
  final String firebaseId;

  AdjustmentRecord({
    required this.id,
    required this.itemName,
    required this.sku,
    this.productId = '',
    required this.adjustmentType,
    required this.quantity,
    required this.oldStock,
    required this.newStock,
    required this.reason,
    required this.notes,
    required this.dateTime,
    required this.cost,
    required this.retail,
    this.branchCode = '',                     // NEW
    this.branchName = '',                     // NEW
    this.createdBy = '',                      // NEW
    this.createdByUserId = '',                // NEW
    this.approvedBy = '',                     // NEW
    this.approvedByUserId = '',               // NEW
    this.deviceId = '',                       // NEW
    this.syncStatus = 'pending',              // NEW
    this.firebaseId = '',                     // NEW
  });

  // Calculated properties
  int get qtyDifference => adjustmentType == 'Add' ? quantity : -quantity;
  double get costImpact => quantity * cost * (adjustmentType == 'Add' ? 1 : -1);
  String get displayLabel => '$branchCode - $itemName';

  Map<String, dynamic> toJson() => {
    'id': id,
    'itemName': itemName,
    'sku': sku,
    'productId': productId,
    'adjustmentType': adjustmentType,
    'quantity': quantity,
    'oldStock': oldStock,
    'newStock': newStock,
    'reason': reason,
    'notes': notes,
    'dateTime': dateTime.toIso8601String(),
    'cost': cost,
    'retail': retail,
    'branchCode': branchCode,
    'branchName': branchName,
    'createdBy': createdBy,
    'createdByUserId': createdByUserId,
    'approvedBy': approvedBy,
    'approvedByUserId': approvedByUserId,
    'deviceId': deviceId,
    'syncStatus': syncStatus,
    'firebaseId': firebaseId,
  };

  factory AdjustmentRecord.fromJson(Map<String, dynamic> json) => AdjustmentRecord(
    id: json['id']?.toString() ?? '',
    itemName: json['itemName']?.toString() ?? '',
    sku: json['sku']?.toString() ?? '',
    productId: json['productId']?.toString() ?? '',
    adjustmentType: json['adjustmentType']?.toString() ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    oldStock: (json['oldStock'] as num?)?.toInt() ?? 0,
    newStock: (json['newStock'] as num?)?.toInt() ?? 0,
    reason: json['reason']?.toString() ?? '',
    notes: json['notes']?.toString() ?? '',
    dateTime: DateTime.tryParse(json['dateTime']?.toString() ?? '') ?? DateTime.now(),
    cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
    retail: (json['retail'] as num?)?.toDouble() ?? 0.0,
    branchCode: json['branchCode']?.toString() ?? '',
    branchName: json['branchName']?.toString() ?? '',
    createdBy: json['createdBy']?.toString() ?? '',
    createdByUserId: json['createdByUserId']?.toString() ?? '',
    approvedBy: json['approvedBy']?.toString() ?? '',
    approvedByUserId: json['approvedByUserId']?.toString() ?? '',
    deviceId: json['deviceId']?.toString() ?? '',
    syncStatus: json['syncStatus']?.toString() ?? 'pending',
    firebaseId: json['firebaseId']?.toString() ?? '',
  );

  Map<String, dynamic> toMap() => toJson();
  factory AdjustmentRecord.fromMap(Map<String, dynamic> m) => AdjustmentRecord.fromJson(m);

  AdjustmentRecord copyWith({
    String? syncStatus,
    String? firebaseId,
    String? approvedBy,
    String? approvedByUserId,
  }) => AdjustmentRecord(
    id: id,
    itemName: itemName,
    sku: sku,
    productId: productId,
    adjustmentType: adjustmentType,
    quantity: quantity,
    oldStock: oldStock,
    newStock: newStock,
    reason: reason,
    notes: notes,
    dateTime: dateTime,
    cost: cost,
    retail: retail,
    branchCode: branchCode,
    branchName: branchName,
    createdBy: createdBy,
    createdByUserId: createdByUserId,
    approvedBy: approvedBy ?? this.approvedBy,
    approvedByUserId: approvedByUserId ?? this.approvedByUserId,
    deviceId: deviceId,
    syncStatus: syncStatus ?? this.syncStatus,
    firebaseId: firebaseId ?? this.firebaseId,
  );
}

class AdjustmentStorage {
  static Future<void> saveAdjustment(AdjustmentRecord record) async {
    await DatabaseHelper().insertAdjustmentRecord(record.toMap());
  }

  static Future<List<AdjustmentRecord>> getAll() async {
    final rows = await DatabaseHelper().getAllAdjustmentRecords();
    return rows.map((r) => AdjustmentRecord.fromMap(r)).toList();
  }

  /// NEW: Get adjustments for specific branch only
  static Future<List<AdjustmentRecord>> getForBranch(String branchCode) async {
    final all = await getAll();
    return all.where((a) => a.branchCode == branchCode).toList();
  }

  static Future<List<AdjustmentRecord>> getFiltered({
    DateTime? dateFrom,
    DateTime? dateTo,
    String searchQuery = '',
    String? branchCode,                       // NEW: Optional branch filter
  }) async {
    final rows = await DatabaseHelper().getFilteredAdjustments(
      dateFrom: dateFrom != null ? DateTime(dateFrom.year, dateFrom.month, dateFrom.day).toIso8601String() : null,
      dateTo: dateTo != null ? DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59).toIso8601String() : null,
      search: searchQuery.trim(),
    );
    var records = rows.map((r) => AdjustmentRecord.fromMap(r)).toList();

    // Apply branch filter if provided
    if (branchCode != null && branchCode.isNotEmpty) {
      records = records.where((a) => a.branchCode == branchCode).toList();
    }

    return records;
  }

  static String exportToCsv(List<AdjustmentRecord> records) {
    final buf = StringBuffer();
    buf.writeln('Date,Time,Branch,Item,SKU,Type,Quantity,Old Stock,New Stock,Reason,Notes,Cost,Retail,Created By,Approved By');
    for (final r in records) {
      final date = '${r.dateTime.year}-${_pad(r.dateTime.month)}-${_pad(r.dateTime.day)}';
      final time = '${_pad(r.dateTime.hour)}:${_pad(r.dateTime.minute)}:${_pad(r.dateTime.second)}';
      buf.writeln('$date,$time,"${r.branchCode}","${r.itemName}","${r.sku}",${r.adjustmentType},${r.quantity},${r.oldStock},${r.newStock},"${r.reason}","${r.notes}",${r.cost},${r.retail},"${r.createdBy}","${r.approvedBy}"');
    }
    return buf.toString();
  }

  static Future<void> clearAll() async {
    await DatabaseHelper().clearAdjustmentRecords();
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
