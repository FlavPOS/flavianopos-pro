import 'package:sqflite/sqflite.dart';
import '../../helpers/database_helper.dart';

/// Enterprise IST Status Flow (SAP-grade)
class TransferStatus {
  static const String draft              = 'DRAFT';
  static const String submitted          = 'SUBMITTED';
  static const String approved           = 'APPROVED';
  static const String floating           = 'FLOATING';
  static const String received           = 'RECEIVED';
  static const String partiallyReceived  = 'PARTIALLY_RECEIVED';
  static const String closed             = 'CLOSED';
  static const String rejected           = 'REJECTED';

  static const Map<String, int> statusColors = {
    draft: 0xFF8B5CF6,
    submitted: 0xFF3B82F6,
    approved: 0xFF06B6D4,
    floating: 0xFFF59E0B,
    received: 0xFF22C55E,
    partiallyReceived: 0xFFEAB308,
    closed: 0xFF64748B,
    rejected: 0xFFEF4444,
  };
}

/// IST Document Header
class TransferV3 {
  final String transferId;
  final String docNumber;
  final String status;
  final String issuingBranchId;
  final String issuingBranchName;
  final String receivingBranchId;
  final String receivingBranchName;
  final String preparedBy;
  final String preparedById;
  final String preparedDate;
  final String submittedBy;
  final String submittedDate;
  final String approvedBy;
  final String approvedByPin;
  final String approvedByRole;
  final String approvedDate;
  final String dispatchedBy;
  final String dispatchedDate;
  final String receivedBy;
  final String receivedByPin;
  final String receivedDate;
  final String varianceApprovedBy;
  final String varianceApprovedDate;
  final String rejectedBy;
  final String rejectedDate;
  final String rejectionReason;
  final String closedDate;
  final int totalItems;
  final int totalIssuedQty;
  final int totalReceivedQty;
  final int totalFloatingQty;
  final int totalShortQty;
  final double totalCost;
  final String notes;
  final String varianceNotes;
  final String syncStatus;
  final String createdAt;
  final String updatedAt;

  const TransferV3({
    required this.transferId,
    this.docNumber = '',
    this.status = TransferStatus.draft,
    required this.issuingBranchId,
    this.issuingBranchName = '',
    required this.receivingBranchId,
    this.receivingBranchName = '',
    this.preparedBy = '',
    this.preparedById = '',
    required this.preparedDate,
    this.submittedBy = '',
    this.submittedDate = '',
    this.approvedBy = '',
    this.approvedByPin = '',
    this.approvedByRole = '',
    this.approvedDate = '',
    this.dispatchedBy = '',
    this.dispatchedDate = '',
    this.receivedBy = '',
    this.receivedByPin = '',
    this.receivedDate = '',
    this.varianceApprovedBy = '',
    this.varianceApprovedDate = '',
    this.rejectedBy = '',
    this.rejectedDate = '',
    this.rejectionReason = '',
    this.closedDate = '',
    this.totalItems = 0,
    this.totalIssuedQty = 0,
    this.totalReceivedQty = 0,
    this.totalFloatingQty = 0,
    this.totalShortQty = 0,
    this.totalCost = 0,
    this.notes = '',
    this.varianceNotes = '',
    this.syncStatus = 'PENDING',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'transfer_id': transferId,
    'doc_number': docNumber,
    'status': status,
    'issuing_branch_id': issuingBranchId,
    'issuing_branch_name': issuingBranchName,
    'receiving_branch_id': receivingBranchId,
    'receiving_branch_name': receivingBranchName,
    'prepared_by': preparedBy,
    'prepared_by_id': preparedById,
    'prepared_date': preparedDate,
    'submitted_by': submittedBy,
    'submitted_date': submittedDate,
    'approved_by': approvedBy,
    'approved_by_pin': approvedByPin,
    'approved_by_role': approvedByRole,
    'approved_date': approvedDate,
    'dispatched_by': dispatchedBy,
    'dispatched_date': dispatchedDate,
    'received_by': receivedBy,
    'received_by_pin': receivedByPin,
    'received_date': receivedDate,
    'variance_approved_by': varianceApprovedBy,
    'variance_approved_date': varianceApprovedDate,
    'rejected_by': rejectedBy,
    'rejected_date': rejectedDate,
    'rejection_reason': rejectionReason,
    'closed_date': closedDate,
    'total_items': totalItems,
    'total_issued_qty': totalIssuedQty,
    'total_received_qty': totalReceivedQty,
    'total_floating_qty': totalFloatingQty,
    'total_short_qty': totalShortQty,
    'total_cost': totalCost,
    'notes': notes,
    'variance_notes': varianceNotes,
    'sync_status': syncStatus,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory TransferV3.fromMap(Map<String, dynamic> m) => TransferV3(
    transferId: (m['transfer_id'] ?? '') as String,
    docNumber: (m['doc_number'] ?? '') as String,
    status: (m['status'] ?? 'DRAFT') as String,
    issuingBranchId: (m['issuing_branch_id'] ?? '') as String,
    issuingBranchName: (m['issuing_branch_name'] ?? '') as String,
    receivingBranchId: (m['receiving_branch_id'] ?? '') as String,
    receivingBranchName: (m['receiving_branch_name'] ?? '') as String,
    preparedBy: (m['prepared_by'] ?? '') as String,
    preparedById: (m['prepared_by_id'] ?? '') as String,
    preparedDate: (m['prepared_date'] ?? '') as String,
    submittedBy: (m['submitted_by'] ?? '') as String,
    submittedDate: (m['submitted_date'] ?? '') as String,
    approvedBy: (m['approved_by'] ?? '') as String,
    approvedByPin: (m['approved_by_pin'] ?? '') as String,
    approvedByRole: (m['approved_by_role'] ?? '') as String,
    approvedDate: (m['approved_date'] ?? '') as String,
    dispatchedBy: (m['dispatched_by'] ?? '') as String,
    dispatchedDate: (m['dispatched_date'] ?? '') as String,
    receivedBy: (m['received_by'] ?? '') as String,
    receivedByPin: (m['received_by_pin'] ?? '') as String,
    receivedDate: (m['received_date'] ?? '') as String,
    varianceApprovedBy: (m['variance_approved_by'] ?? '') as String,
    varianceApprovedDate: (m['variance_approved_date'] ?? '') as String,
    rejectedBy: (m['rejected_by'] ?? '') as String,
    rejectedDate: (m['rejected_date'] ?? '') as String,
    rejectionReason: (m['rejection_reason'] ?? '') as String,
    closedDate: (m['closed_date'] ?? '') as String,
    totalItems: (m['total_items'] as num?)?.toInt() ?? 0,
    totalIssuedQty: (m['total_issued_qty'] as num?)?.toInt() ?? 0,
    totalReceivedQty: (m['total_received_qty'] as num?)?.toInt() ?? 0,
    totalFloatingQty: (m['total_floating_qty'] as num?)?.toInt() ?? 0,
    totalShortQty: (m['total_short_qty'] as num?)?.toInt() ?? 0,
    totalCost: (m['total_cost'] as num?)?.toDouble() ?? 0,
    notes: (m['notes'] ?? '') as String,
    varianceNotes: (m['variance_notes'] ?? '') as String,
    syncStatus: (m['sync_status'] ?? 'PENDING') as String,
    createdAt: (m['created_at'] ?? '') as String,
    updatedAt: (m['updated_at'] ?? '') as String,
  );
}

/// IST Line Item
// v1.0.48 — Batch tracking for transfer items
class TransferItemBatch {
  final int? id;
  final String transferId;
  final String productId;
  final String batchId;
  final String batchNumber;
  final String lotNumber;
  final DateTime mfgDate;
  final DateTime expiryDate;
  final int transferQty;
  final double unitCost;
  final int receivedQty;      // v1.0.56 — actual received qty per batch
  final int postbackQty;      // v1.0.56 — reserved for Phase 2B postback
  final String shortReason;   // v1.0.57 — variance reason (SHORT: RETURN/DAMAGED/MISSING, OVERAGE: EXTRA_PACKED/BONUS/UNKNOWN)
  final String varianceNotes; // v1.0.57 — optional notes for variance context

  const TransferItemBatch({
    this.id,
    required this.transferId,
    required this.productId,
    required this.batchId,
    required this.batchNumber,
    required this.lotNumber,
    required this.mfgDate,
    required this.expiryDate,
    required this.transferQty,
    required this.unitCost,
    this.receivedQty = 0,       // v1.0.56
    this.postbackQty = 0,       // v1.0.56
    this.shortReason = '',      // v1.0.57 — variance reason
    this.varianceNotes = '',    // v1.0.57 — optional notes
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'transferId': transferId,
    'productId': productId,
    'batchId': batchId,
    'batchNumber': batchNumber,
    'lotNumber': lotNumber,
    'mfgDate': mfgDate.toIso8601String(),
    'expiryDate': expiryDate.toIso8601String(),
    'transferQty': transferQty,
    'unitCost': unitCost,
    'receivedQty': receivedQty,       // v1.0.56
    'postbackQty': postbackQty,       // v1.0.56
    'shortReason': shortReason,       // v1.0.57
    'varianceNotes': varianceNotes,   // v1.0.57
  };

  factory TransferItemBatch.fromMap(Map<String, dynamic> m) => TransferItemBatch(
    id: m['id'] as int?,
    transferId: (m['transferId'] ?? '').toString(),
    productId: (m['productId'] ?? '').toString(),
    batchId: (m['batchId'] ?? '').toString(),
    batchNumber: (m['batchNumber'] ?? '').toString(),
    lotNumber: (m['lotNumber'] ?? '').toString(),
    mfgDate: DateTime.tryParse(m['mfgDate'] ?? '') ?? DateTime.now(),
    expiryDate: DateTime.tryParse(m['expiryDate'] ?? '') ?? DateTime.now(),
    transferQty: (m['transferQty'] as num?)?.toInt() ?? 0,
    unitCost: (m['unitCost'] as num?)?.toDouble() ?? 0.0,
    receivedQty: (m['receivedQty'] as num?)?.toInt() ?? 0,       // v1.0.56
    postbackQty: (m['postbackQty'] as num?)?.toInt() ?? 0,       // v1.0.56
    shortReason: (m['shortReason'] ?? '').toString(),            // v1.0.57
    varianceNotes: (m['varianceNotes'] ?? '').toString(),        // v1.0.57
  );
}

class TransferV3Item {
  final int? itemId;
  final String transferId;
  final String productId;
  final String sku;
  final String productName;
  final String category;
  final int issuedQty;
  final int receivedQty;
  final int shortQty;
  final String varianceReason;
  final double unitCost;
  final String notes;
  final String createdAt;

  const TransferV3Item({
    this.itemId,
    required this.transferId,
    required this.productId,
    required this.sku,
    required this.productName,
    this.category = '',
    required this.issuedQty,
    this.receivedQty = 0,
    this.shortQty = 0,
    this.varianceReason = '',
    this.unitCost = 0,
    this.notes = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    if (itemId != null) 'item_id': itemId,
    'transfer_id': transferId,
    'product_id': productId,
    'sku': sku,
    'product_name': productName,
    'category': category,
    'issued_qty': issuedQty,
    'received_qty': receivedQty,
    'short_qty': shortQty,
    'variance_reason': varianceReason,
    'unit_cost': unitCost,
    'notes': notes,
    'created_at': createdAt,
  };

  factory TransferV3Item.fromMap(Map<String, dynamic> m) => TransferV3Item(
    itemId: (m['item_id'] as num?)?.toInt(),
    transferId: (m['transfer_id'] ?? '') as String,
    productId: (m['product_id'] ?? '') as String,
    sku: (m['sku'] ?? '') as String,
    productName: (m['product_name'] ?? '') as String,
    category: (m['category'] ?? '') as String,
    issuedQty: (m['issued_qty'] as num?)?.toInt() ?? 0,
    receivedQty: (m['received_qty'] as num?)?.toInt() ?? 0,
    shortQty: (m['short_qty'] as num?)?.toInt() ?? 0,
    varianceReason: (m['variance_reason'] ?? '') as String,
    unitCost: (m['unit_cost'] as num?)?.toDouble() ?? 0,
    notes: (m['notes'] ?? '') as String,
    createdAt: (m['created_at'] ?? '') as String,
  );

  int get floatingQty => issuedQty - receivedQty - shortQty;
}

/// DAO for TransferV3
class TransferV3Dao {
  static const String _tHeader = 'interstore_transfers_v3';
  static const String _tItems = 'interstore_transfer_items_v3';

  static Future<String> save({
    required TransferV3 header,
    required List<TransferV3Item> items,
    List<TransferItemBatch> batches = const [],
  }) async {
    final db = await DatabaseHelper().database;
    await db.transaction((txn) async {
      await txn.insert(_tHeader, header.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(_tItems,
          where: 'transfer_id = ?', whereArgs: [header.transferId]);
      for (final item in items) {
        await txn.insert(_tItems, item.toMap());
      }
      // v1.0.48 — Save batches
      await txn.execute("CREATE TABLE IF NOT EXISTS transfer_item_batches (id INTEGER PRIMARY KEY AUTOINCREMENT, transferId TEXT NOT NULL, productId TEXT NOT NULL, batchId TEXT NOT NULL, batchNumber TEXT DEFAULT '', lotNumber TEXT DEFAULT '', mfgDate TEXT DEFAULT '', expiryDate TEXT DEFAULT '', transferQty INTEGER DEFAULT 0, unitCost REAL DEFAULT 0, receivedQty INTEGER DEFAULT 0, postbackQty INTEGER DEFAULT 0, shortReason TEXT DEFAULT '', varianceNotes TEXT DEFAULT '')");
      // v1.0.56/57 — Safe migrations for existing DBs (idempotent)
      try { await txn.execute("ALTER TABLE transfer_item_batches ADD COLUMN receivedQty INTEGER DEFAULT 0"); } catch (_) {}
      try { await txn.execute("ALTER TABLE transfer_item_batches ADD COLUMN postbackQty INTEGER DEFAULT 0"); } catch (_) {}
      try { await txn.execute("ALTER TABLE transfer_item_batches ADD COLUMN shortReason TEXT DEFAULT ''"); } catch (_) {}
      try { await txn.execute("ALTER TABLE transfer_item_batches ADD COLUMN varianceNotes TEXT DEFAULT ''"); } catch (_) {}
      await txn.delete('transfer_item_batches',
          where: 'transferId = ?', whereArgs: [header.transferId]);
      for (final batch in batches) {
        await txn.insert('transfer_item_batches', batch.toMap());
      }
    });
    return header.transferId;
  }

  static Future<List<TransferV3>> getByStatus(
    String status, String branchId, String direction,
  ) async {
    final db = await DatabaseHelper().database;
    final col = direction == 'inbound' ? 'receiving_branch_id' : 'issuing_branch_id';
    final rows = await db.query(_tHeader,
        where: 'status = ? AND $col = ?',
        whereArgs: [status, branchId],
        orderBy: 'created_at DESC');
    return rows.map(TransferV3.fromMap).toList();
  }

  static Future<List<TransferV3>> getByStatuses(
    List<String> statuses, String branchId, String direction,
  ) async {
    final db = await DatabaseHelper().database;
    final col = direction == 'inbound' ? 'receiving_branch_id' : 'issuing_branch_id';
    final placeholders = statuses.map((_) => '?').join(',');
    final rows = await db.rawQuery(
      'SELECT * FROM $_tHeader WHERE status IN ($placeholders) AND $col = ? ORDER BY created_at DESC',
      [...statuses, branchId],
    );
    return rows.map(TransferV3.fromMap).toList();
  }

  static Future<int> countByStatus(
    String status, String branchId, String direction,
  ) async {
    final db = await DatabaseHelper().database;
    final col = direction == 'inbound' ? 'receiving_branch_id' : 'issuing_branch_id';
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM $_tHeader WHERE status = ? AND $col = ?',
      [status, branchId],
    );
    return (result.first['c'] as num?)?.toInt() ?? 0;
  }

  static Future<int> countByStatuses(
    List<String> statuses, String branchId, String direction,
  ) async {
    final db = await DatabaseHelper().database;
    final col = direction == 'inbound' ? 'receiving_branch_id' : 'issuing_branch_id';
    final placeholders = statuses.map((_) => '?').join(',');
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM $_tHeader WHERE status IN ($placeholders) AND $col = ?',
      [...statuses, branchId],
    );
    return (result.first['c'] as num?)?.toInt() ?? 0;
  }

  static Future<TransferV3?> getById(String transferId) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(_tHeader,
        where: 'transfer_id = ?',
        whereArgs: [transferId],
        limit: 1);
    if (rows.isEmpty) return null;
    return TransferV3.fromMap(rows.first);
  }

  static Future<List<TransferV3Item>> getItems(String transferId) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(_tItems,
        where: 'transfer_id = ?',
        whereArgs: [transferId],
        orderBy: 'item_id ASC');
    return rows.map(TransferV3Item.fromMap).toList();
  }

  static Future<void> delete(String transferId) async {
    final db = await DatabaseHelper().database;
    await db.transaction((txn) async {
      await txn.delete(_tItems, where: 'transfer_id = ?', whereArgs: [transferId]);
      await txn.delete(_tHeader, where: 'transfer_id = ?', whereArgs: [transferId]);
    });
  }

  static Future<void> updateStatus({
    required String transferId,
    required String newStatus,
    Map<String, dynamic>? extraFields,
  }) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toIso8601String();
    final updates = <String, dynamic>{
      'status': newStatus,
      'updated_at': now,
    };
    switch (newStatus) {
      case 'SUBMITTED': updates['submitted_date'] = now; break;
      case 'APPROVED': updates['approved_date'] = now; break;
      case 'FLOATING': updates['dispatched_date'] = now; break;
      case 'RECEIVED':
      case 'PARTIALLY_RECEIVED': updates['received_date'] = now; break;
      case 'CLOSED': updates['closed_date'] = now; break;
      case 'REJECTED': updates['rejected_date'] = now; break;
    }
    if (extraFields != null) updates.addAll(extraFields);
    await db.update(_tHeader, updates,
        where: 'transfer_id = ?', whereArgs: [transferId]);
  }

  static Future<void> updateItemReceived({
    required String transferId,
    required int itemId,
    required int receivedQty,
    required int shortQty,
    String varianceReason = '',
  }) async {
    final db = await DatabaseHelper().database;
    await db.update(_tItems, {
      'received_qty': receivedQty,
      'short_qty': shortQty,
      'variance_reason': varianceReason,
    }, where: 'item_id = ?', whereArgs: [itemId]);
  }

  static String generateId({required String fromBranch, required String toBranch}) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'IST-$fromBranch-$toBranch-$ts';
  }

  // v1.0.48 — Load all batches for a transfer
  static Future<List<TransferItemBatch>> getBatches(String transferId) async {
    final db = await DatabaseHelper().database;
    try {
      await db.execute("CREATE TABLE IF NOT EXISTS transfer_item_batches (id INTEGER PRIMARY KEY AUTOINCREMENT, transferId TEXT NOT NULL, productId TEXT NOT NULL, batchId TEXT NOT NULL, batchNumber TEXT DEFAULT '', lotNumber TEXT DEFAULT '', mfgDate TEXT DEFAULT '', expiryDate TEXT DEFAULT '', transferQty INTEGER DEFAULT 0, unitCost REAL DEFAULT 0, receivedQty INTEGER DEFAULT 0, postbackQty INTEGER DEFAULT 0, shortReason TEXT DEFAULT '', varianceNotes TEXT DEFAULT '')");
      // v1.0.56/57 — safe migrations for existing DBs
      try { await db.execute("ALTER TABLE transfer_item_batches ADD COLUMN receivedQty INTEGER DEFAULT 0"); } catch (_) {}
      try { await db.execute("ALTER TABLE transfer_item_batches ADD COLUMN postbackQty INTEGER DEFAULT 0"); } catch (_) {}
      try { await db.execute("ALTER TABLE transfer_item_batches ADD COLUMN shortReason TEXT DEFAULT ''"); } catch (_) {}
      try { await db.execute("ALTER TABLE transfer_item_batches ADD COLUMN varianceNotes TEXT DEFAULT ''"); } catch (_) {}
    } catch (_) {}
    final rows = await db.query('transfer_item_batches',
        where: 'transferId = ?', whereArgs: [transferId]);
    return rows.map(TransferItemBatch.fromMap).toList();
  }

  // v1.0.48 — Load batches for specific product
  /// v1.0.56 — Update receivedQty on a transfer_item_batches row
  static Future<void> updateBatchReceivedQty({
    required int batchTableId,
    required int receivedQty,
  }) async {
    final db = await DatabaseHelper().database;
    await db.update(
      'transfer_item_batches',
      {'receivedQty': receivedQty},
      where: 'id = ?',
      whereArgs: [batchTableId],
    );
  }

  static Future<List<TransferItemBatch>> getBatchesForItem(
      String transferId, String productId) async {
    final db = await DatabaseHelper().database;
    try {
      await db.execute("CREATE TABLE IF NOT EXISTS transfer_item_batches (id INTEGER PRIMARY KEY AUTOINCREMENT, transferId TEXT NOT NULL, productId TEXT NOT NULL, batchId TEXT NOT NULL, batchNumber TEXT DEFAULT '', lotNumber TEXT DEFAULT '', mfgDate TEXT DEFAULT '', expiryDate TEXT DEFAULT '', transferQty INTEGER DEFAULT 0, unitCost REAL DEFAULT 0, receivedQty INTEGER DEFAULT 0, postbackQty INTEGER DEFAULT 0, shortReason TEXT DEFAULT '', varianceNotes TEXT DEFAULT '')");
      // v1.0.56/57 — safe migrations for existing DBs
      try { await db.execute("ALTER TABLE transfer_item_batches ADD COLUMN receivedQty INTEGER DEFAULT 0"); } catch (_) {}
      try { await db.execute("ALTER TABLE transfer_item_batches ADD COLUMN postbackQty INTEGER DEFAULT 0"); } catch (_) {}
      try { await db.execute("ALTER TABLE transfer_item_batches ADD COLUMN shortReason TEXT DEFAULT ''"); } catch (_) {}
      try { await db.execute("ALTER TABLE transfer_item_batches ADD COLUMN varianceNotes TEXT DEFAULT ''"); } catch (_) {}
    } catch (_) {}
    final rows = await db.query('transfer_item_batches',
        where: 'transferId = ? AND productId = ?',
        whereArgs: [transferId, productId]);
    return rows.map(TransferItemBatch.fromMap).toList();
  }
}
