// lib/screens/receive_delivery/delivery_model.dart
import '../../helpers/database_helper.dart';

// ═══ Status Constants ═══
class DeliveryStatus {
  static const String draft = 'Draft';
  static const String submitted = 'Submitted';
  static const String approved = 'Approved';
  static const String rejected = 'Rejected';
}

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
  final String lotNumber;
  final String mfgDate;
  final String expDate;

  DeliveryItemRecord({
    required this.productId, required this.itemName, required this.sku,
    required this.quantity, required this.oldStock, required this.newStock,
    required this.cost, required this.retail,
    this.batchNumber = '', this.lotNumber = '', this.mfgDate = '', this.expDate = '',
  });

  Map<String, dynamic> toJson() => {
    'productId': productId, 'itemName': itemName, 'sku': sku,
    'quantity': quantity, 'oldStock': oldStock, 'newStock': newStock,
    'cost': cost, 'retail': retail,
    'batchNumber': batchNumber, 'lotNumber': lotNumber, 'mfgDate': mfgDate, 'expDate': expDate,
  };

  factory DeliveryItemRecord.fromJson(Map<String, dynamic> json) => DeliveryItemRecord(
    productId: json['productId'] ?? '', itemName: json['itemName'] ?? '',
    sku: json['sku'] ?? '', quantity: json['quantity'] ?? 0,
    oldStock: json['oldStock'] ?? 0, newStock: json['newStock'] ?? 0,
    cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
    retail: (json['retail'] as num?)?.toDouble() ?? 0.0,
    batchNumber: json['batchNumber'] ?? '', lotNumber: json['lotNumber'] ?? '', mfgDate: json['mfgDate'] ?? '',
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
  final String branchId;
  final String branchName;

  // ═══ WORKFLOW FIELDS (Phase A) ═══
  final String status;
  final String submittedDate;
  final String submittedBy;
  final String approvedDate;
  final String approvedBy;
  final String rejectedDate;
  final String rejectedBy;
  final String rejectionReason;
  final String lastEditedDate;
  final String syncStatus;

  DeliveryRecord({
    required this.id, required this.refNumber, required this.supplier,
    required this.driverName, required this.plateNumber,
    required this.receivedBy, required this.notes, required this.items,
    required this.totalItems, required this.totalQuantity,
    required this.totalCost, required this.totalRetail,
    required this.dateTime,
    this.branchId = '',
    this.branchName = '',
    this.status = 'Draft',
    this.submittedDate = '',
    this.submittedBy = '',
    this.approvedDate = '',
    this.approvedBy = '',
    this.rejectedDate = '',
    this.rejectedBy = '',
    this.rejectionReason = '',
    this.lastEditedDate = '',
    this.syncStatus = 'Pending',
  });

  // copyWith for status changes
  DeliveryRecord copyWith({
    String? status,
    String? submittedDate,
    String? submittedBy,
    String? approvedDate,
    String? approvedBy,
    String? rejectedDate,
    String? rejectedBy,
    String? rejectionReason,
    String? lastEditedDate,
    String? syncStatus,
  }) => DeliveryRecord(
    id: id, refNumber: refNumber, supplier: supplier,
    driverName: driverName, plateNumber: plateNumber,
    receivedBy: receivedBy, notes: notes, items: items,
    totalItems: totalItems, totalQuantity: totalQuantity,
    totalCost: totalCost, totalRetail: totalRetail,
    dateTime: dateTime, branchId: branchId, branchName: branchName,
    status: status ?? this.status,
    submittedDate: submittedDate ?? this.submittedDate,
    submittedBy: submittedBy ?? this.submittedBy,
    approvedDate: approvedDate ?? this.approvedDate,
    approvedBy: approvedBy ?? this.approvedBy,
    rejectedDate: rejectedDate ?? this.rejectedDate,
    rejectedBy: rejectedBy ?? this.rejectedBy,
    rejectionReason: rejectionReason ?? this.rejectionReason,
    lastEditedDate: lastEditedDate ?? this.lastEditedDate,
    syncStatus: syncStatus ?? this.syncStatus,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'refNumber': refNumber, 'supplier': supplier,
    'driverName': driverName, 'plateNumber': plateNumber,
    'receivedBy': receivedBy, 'notes': notes,
    'items': items.map((e) => e.toJson()).toList(),
    'totalItems': totalItems, 'totalQuantity': totalQuantity,
    'totalCost': totalCost, 'totalRetail': totalRetail,
    'dateTime': dateTime.toIso8601String(),
    'branchId': branchId,
    'branchName': branchName,
    'status': status,
    'submittedDate': submittedDate,
    'submittedBy': submittedBy,
    'approvedDate': approvedDate,
    'approvedBy': approvedBy,
    'rejectedDate': rejectedDate,
    'rejectedBy': rejectedBy,
    'rejectionReason': rejectionReason,
    'lastEditedDate': lastEditedDate,
    'syncStatus': syncStatus,
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
    branchId: json['branchId'] ?? '',
    branchName: json['branchName'] ?? '',
    status: json['status'] ?? 'Draft',
    submittedDate: json['submittedDate'] ?? '',
    submittedBy: json['submittedBy'] ?? '',
    approvedDate: json['approvedDate'] ?? '',
    approvedBy: json['approvedBy'] ?? '',
    rejectedDate: json['rejectedDate'] ?? '',
    rejectedBy: json['rejectedBy'] ?? '',
    rejectionReason: json['rejectionReason'] ?? '',
    lastEditedDate: json['lastEditedDate'] ?? '',
    syncStatus: json['syncStatus'] ?? 'Pending',
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'refNumber': refNumber, 'supplier': supplier,
    'driverName': driverName, 'plateNumber': plateNumber,
    'receivedBy': receivedBy, 'notes': notes,
    'totalItems': totalItems, 'totalQuantity': totalQuantity,
    'totalCost': totalCost, 'totalRetail': totalRetail,
    'dateTime': dateTime.toIso8601String(),
    'branchId': branchId,
    'branchName': branchName,
    'status': status,
    'submittedDate': submittedDate,
    'submittedBy': submittedBy,
    'approvedDate': approvedDate,
    'approvedBy': approvedBy,
    'rejectedDate': rejectedDate,
    'rejectedBy': rejectedBy,
    'rejectionReason': rejectionReason,
    'lastEditedDate': lastEditedDate,
    'syncStatus': syncStatus,
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
    branchId: m['branchId'] ?? '',
    branchName: m['branchName'] ?? '',
    status: m['status'] ?? 'Draft',
    submittedDate: m['submittedDate'] ?? '',
    submittedBy: m['submittedBy'] ?? '',
    approvedDate: m['approvedDate'] ?? '',
    approvedBy: m['approvedBy'] ?? '',
    rejectedDate: m['rejectedDate'] ?? '',
    rejectedBy: m['rejectedBy'] ?? '',
    rejectionReason: m['rejectionReason'] ?? '',
    lastEditedDate: m['lastEditedDate'] ?? '',
    syncStatus: m['syncStatus'] ?? 'Pending',
  );
}

// ═══ Approval History Model ═══
class ApprovalHistoryRecord {
  final String id;
  final String deliveryId;
  final String action;
  final String user;
  final String date;
  final String remarks;

  ApprovalHistoryRecord({
    required this.id,
    required this.deliveryId,
    required this.action,
    required this.user,
    required this.date,
    this.remarks = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'deliveryId': deliveryId,
    'action': action,
    'user': user,
    'date': date,
    'remarks': remarks,
  };

  factory ApprovalHistoryRecord.fromMap(Map<String, dynamic> m) => ApprovalHistoryRecord(
    id: m['id'] ?? '',
    deliveryId: m['deliveryId'] ?? '',
    action: m['action'] ?? '',
    user: m['user'] ?? '',
    date: m['date'] ?? '',
    remarks: m['remarks'] ?? '',
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

  // ═══ NEW: Filter by status ═══
  static Future<List<DeliveryRecord>> getByStatus(String status, {String? branchId}) async {
    final db = DatabaseHelper();
    final rows = await db.getAllDeliveryRecords();
    List<DeliveryRecord> result = [];
    for (final row in rows) {
      if ((row['status'] ?? 'Draft') != status) continue;
      // Branch filter — only show current branch's data
      if (branchId != null && branchId.isNotEmpty) {
        final rowBranchId = (row['branchId'] ?? '').toString();
        if (rowBranchId != branchId) continue;
      }
      final itemRows = await db.getDeliveryItems(row['id']);
      final items = itemRows.map((r) => DeliveryItemRecord.fromMap(r)).toList();
      result.add(DeliveryRecord.fromMap(row, items));
    }
    // Sort by dateTime DESC
    result.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return result;
  }

  // ═══ NEW: Count by status ═══
  static Future<int> countByStatus(String status, {String? branchId}) async {
    final list = await getByStatus(status, branchId: branchId);
    return list.length;
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

  // ═══ NEW: Update status (used by workflow) ═══
  static Future<void> updateStatus(String deliveryId, Map<String, dynamic> updates) async {
    final db = DatabaseHelper();
    await db.updateDeliveryRecord(deliveryId, updates);
  }

  // ═══ NEW: Delete delivery ═══
  static Future<void> deleteDelivery(String deliveryId) async {
    final db = DatabaseHelper();
    await db.deleteDeliveryRecord(deliveryId);
  }

  static Future<void> clearAll() async {
    await DatabaseHelper().clearDeliveryRecords();
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
