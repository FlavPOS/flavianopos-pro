import 'package:sqflite/sqflite.dart';
import '../../helpers/database_helper.dart';

/// Status of an adjustment document in the workflow.
class AdjustmentStatus {
  static const String draft     = 'DRAFT';
  static const String submitted = 'SUBMITTED';
  static const String approved  = 'APPROVED';
  static const String rejected  = 'REJECTED';
}

/// Adjustment document header.
class AdjustmentV3 {
  final String adjustmentId;
  final String docNumber;
  final String status;
  final String branchCode;
  final String branchName;
  final String createdByName;
  final String createdByPin;
  final String createdById;
  final String deviceId;
  final int totalItems;
  final int totalPositive;
  final int totalNegative;
  final String notes;
  final String submittedAt;
  final String approvedAt;
  final String approvedBy;
  final String rejectedAt;
  final String rejectedBy;
  final String rejectionReason;
  final String syncStatus;
  final String submittedBy;
  final String approvedByPin;
  final String approvedByRole;
  final String createdAt;
  final String updatedAt;

  const AdjustmentV3({
    required this.adjustmentId,
    this.docNumber = '',
    this.status = AdjustmentStatus.draft,
    required this.branchCode,
    this.branchName = '',
    this.createdByName = '',
    this.createdByPin = '',
    this.createdById = '',
    this.deviceId = '',
    this.totalItems = 0,
    this.totalPositive = 0,
    this.totalNegative = 0,
    this.notes = '',
    this.submittedAt = '',
    this.approvedAt = '',
    this.approvedBy = '',
    this.rejectedAt = '',
    this.rejectedBy = '',
    this.rejectionReason = '',
    this.syncStatus = 'PENDING',
    this.submittedBy = '',
    this.approvedByPin = '',
    this.approvedByRole = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'adjustment_id': adjustmentId,
    'doc_number': docNumber,
    'status': status,
    'branch_code': branchCode,
    'branch_name': branchName,
    'created_by_name': createdByName,
    'created_by_pin': createdByPin,
    'created_by_id': createdById,
    'device_id': deviceId,
    'total_items': totalItems,
    'total_positive': totalPositive,
    'total_negative': totalNegative,
    'notes': notes,
    'submitted_at': submittedAt,
    'approved_at': approvedAt,
    'approved_by': approvedBy,
    'rejected_at': rejectedAt,
    'rejected_by': rejectedBy,
    'rejection_reason': rejectionReason,
    'sync_status': syncStatus,
    'submitted_by': submittedBy,
    'approved_by_pin': approvedByPin,
    'approved_by_role': approvedByRole,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory AdjustmentV3.fromMap(Map<String, dynamic> m) => AdjustmentV3(
    adjustmentId: (m['adjustment_id'] ?? '') as String,
    docNumber: (m['doc_number'] ?? '') as String,
    status: (m['status'] ?? 'DRAFT') as String,
    branchCode: (m['branch_code'] ?? '') as String,
    branchName: (m['branch_name'] ?? '') as String,
    createdByName: (m['created_by_name'] ?? '') as String,
    createdByPin: (m['created_by_pin'] ?? '') as String,
    createdById: (m['created_by_id'] ?? '') as String,
    deviceId: (m['device_id'] ?? '') as String,
    totalItems: (m['total_items'] as num?)?.toInt() ?? 0,
    totalPositive: (m['total_positive'] as num?)?.toInt() ?? 0,
    totalNegative: (m['total_negative'] as num?)?.toInt() ?? 0,
    notes: (m['notes'] ?? '') as String,
    submittedAt: (m['submitted_at'] ?? '') as String,
    approvedAt: (m['approved_at'] ?? '') as String,
    approvedBy: (m['approved_by'] ?? '') as String,
    rejectedAt: (m['rejected_at'] ?? '') as String,
    rejectedBy: (m['rejected_by'] ?? '') as String,
    rejectionReason: (m['rejection_reason'] ?? '') as String,
    syncStatus: (m['sync_status'] ?? 'PENDING') as String,
    submittedBy: (m['submitted_by'] ?? '') as String,
    approvedByPin: (m['approved_by_pin'] ?? '') as String,
    approvedByRole: (m['approved_by_role'] ?? '') as String,
    createdAt: (m['created_at'] ?? '') as String,
    updatedAt: (m['updated_at'] ?? '') as String,
  );
}

/// Line item of an adjustment.
class AdjustmentV3Item {
  final int? itemId;
  final String adjustmentId;
  final String productId;
  final String sku;
  final String productName;
  final String category;
  final int qty;
  final String reasonCode;
  final String reasonName;
  final int direction;
  final double unitCost;
  final String notes;
  final String createdAt;

  const AdjustmentV3Item({
    this.itemId,
    required this.adjustmentId,
    required this.productId,
    required this.sku,
    required this.productName,
    this.category = '',
    required this.qty,
    required this.reasonCode,
    required this.reasonName,
    required this.direction,
    this.unitCost = 0,
    this.notes = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    if (itemId != null) 'item_id': itemId,
    'adjustment_id': adjustmentId,
    'product_id': productId,
    'sku': sku,
    'product_name': productName,
    'category': category,
    'qty': qty,
    'reason_code': reasonCode,
    'reason_name': reasonName,
    'direction': direction,
    'unit_cost': unitCost,
    'notes': notes,
    'created_at': createdAt,
  };

  factory AdjustmentV3Item.fromMap(Map<String, dynamic> m) => AdjustmentV3Item(
    itemId: (m['item_id'] as num?)?.toInt(),
    adjustmentId: (m['adjustment_id'] ?? '') as String,
    productId: (m['product_id'] ?? '') as String,
    sku: (m['sku'] ?? '') as String,
    productName: (m['product_name'] ?? '') as String,
    category: (m['category'] ?? '') as String,
    qty: (m['qty'] as num?)?.toInt() ?? 0,
    reasonCode: (m['reason_code'] ?? '') as String,
    reasonName: (m['reason_name'] ?? '') as String,
    direction: (m['direction'] as num?)?.toInt() ?? -1,
    unitCost: (m['unit_cost'] as num?)?.toDouble() ?? 0,
    notes: (m['notes'] ?? '') as String,
    createdAt: (m['created_at'] ?? '') as String,
  );
}

/// Data Access Object for AdjustmentV3.
class AdjustmentV3Dao {
  static const String _tHeader = 'adjustments_v3';
  static const String _tItems  = 'adjustment_v3_items';

  /// Save an adjustment (header + items) atomically.
  static Future<String> save({
    required AdjustmentV3 header,
    required List<AdjustmentV3Item> items,
  }) async {
    final db = await DatabaseHelper().database;
    await db.transaction((txn) async {
      // Upsert header
      await txn.insert(
        _tHeader,
        header.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // Delete old items for this adjustment
      await txn.delete(_tItems,
          where: 'adjustment_id = ?', whereArgs: [header.adjustmentId]);
      // Insert new items
      for (final item in items) {
        await txn.insert(_tItems, item.toMap());
      }
    });
    return header.adjustmentId;
  }

  /// Get all adjustments filtered by status.
  static Future<List<AdjustmentV3>> getByStatus(String status,
      {String? branchCode}) async {
    final db = await DatabaseHelper().database;
    final where = branchCode != null
        ? 'status = ? AND branch_code = ?'
        : 'status = ?';
    final args = branchCode != null ? [status, branchCode] : [status];
    final rows = await db.query(_tHeader,
        where: where,
        whereArgs: args,
        orderBy: 'created_at DESC');
    return rows.map(AdjustmentV3.fromMap).toList();
  }

  /// Count by status (for hub badges).
  static Future<int> countByStatus(String status,
      {String? branchCode}) async {
    final db = await DatabaseHelper().database;
    final where = branchCode != null
        ? 'status = ? AND branch_code = ?'
        : 'status = ?';
    final args = branchCode != null ? [status, branchCode] : [status];
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM $_tHeader WHERE $where',
      args,
    );
    return (result.first['c'] as num?)?.toInt() ?? 0;
  }

  /// Get one adjustment by ID.
  static Future<AdjustmentV3?> getById(String adjustmentId) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(_tHeader,
        where: 'adjustment_id = ?',
        whereArgs: [adjustmentId],
        limit: 1);
    if (rows.isEmpty) return null;
    return AdjustmentV3.fromMap(rows.first);
  }

  /// Get all items of an adjustment.
  static Future<List<AdjustmentV3Item>> getItems(String adjustmentId) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(_tItems,
        where: 'adjustment_id = ?',
        whereArgs: [adjustmentId],
        orderBy: 'item_id ASC');
    return rows.map(AdjustmentV3Item.fromMap).toList();
  }

  /// Delete adjustment + all items (cascade).
  static Future<void> delete(String adjustmentId) async {
    final db = await DatabaseHelper().database;
    await db.transaction((txn) async {
      await txn.delete(_tItems,
          where: 'adjustment_id = ?', whereArgs: [adjustmentId]);
      await txn.delete(_tHeader,
          where: 'adjustment_id = ?', whereArgs: [adjustmentId]);
    });
  }

  /// Update status only (e.g., DRAFT → SUBMITTED).
  static Future<void> updateStatus({
    required String adjustmentId,
    required String newStatus,
    String? approvedBy,
    String? approvedByPin,
    String? approvedByRole,
    String? submittedBy,
    String? rejectedBy,
    String? rejectionReason,
  }) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toIso8601String();
    final updates = <String, dynamic>{
      'status': newStatus,
      'updated_at': now,
    };
    switch (newStatus) {
      case 'SUBMITTED':
        updates['submitted_at'] = now;
        if (submittedBy != null) updates['submitted_by'] = submittedBy;
        break;
      case 'APPROVED':
        updates['approved_at'] = now;
        if (approvedBy != null) updates['approved_by'] = approvedBy;
        if (approvedByPin != null) updates['approved_by_pin'] = approvedByPin;
        if (approvedByRole != null) updates['approved_by_role'] = approvedByRole;
        break;
      case 'REJECTED':
        updates['rejected_at'] = now;
        if (rejectedBy != null) updates['rejected_by'] = rejectedBy;
        if (rejectionReason != null) updates['rejection_reason'] = rejectionReason;
        break;
    }
    await db.update(_tHeader, updates,
        where: 'adjustment_id = ?', whereArgs: [adjustmentId]);
  }

  /// Generate next unique adjustment ID.
  static String generateId({required String branchCode}) {
    final now = DateTime.now();
    final ts = now.millisecondsSinceEpoch;
    return 'ADJ-$branchCode-$ts';
  }
}


