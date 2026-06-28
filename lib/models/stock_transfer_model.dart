// ============================================================
// STOCK TRANSFER MODEL - QuickPOS Pro (SQLite Backend)
// ============================================================
import '../helpers/database_helper.dart';

// ---- Transfer Item (with Batch Info) ----
class TransferItem {
  final String itemId;
  final String itemCode;
  final String itemName;
  final String category;
  final String unit;
  final String batchId;
  final String batchNumber;
  final DateTime? manufacturedDate;
  final DateTime? expiryDate;
  final int qtyTransferred;
  int qtyReceived;
  final double cost;
  final String remarks;

  TransferItem({
    required this.itemId, required this.itemCode, required this.itemName,
    this.category = '', this.unit = 'pcs',
    this.batchId = '', this.batchNumber = '',
    this.manufacturedDate, this.expiryDate,
    required this.qtyTransferred, this.qtyReceived = 0,
    this.cost = 0, this.remarks = '',
  });

  double get totalCost => cost * qtyTransferred;
  double get receivedCost => cost * qtyReceived;
  int get daysUntilExpiry => expiryDate != null ? expiryDate!.difference(DateTime.now()).inDays : 999;
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get isNearExpiry => !isExpired && daysUntilExpiry <= 30;

  String fmtDate(DateTime? d) {
    if (d == null) return '';
    return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  }
  String get mfgDateStr => fmtDate(manufacturedDate);
  String get expDateStr => fmtDate(expiryDate);
  String get batchSummary => batchNumber.isNotEmpty
    ? '$batchNumber | MFG: $mfgDateStr | EXP: $expDateStr'
    : 'No Batch';

  Map<String, dynamic> toJson() => {
    'itemId': itemId, 'itemCode': itemCode, 'itemName': itemName,
    'category': category, 'unit': unit,
    'batchId': batchId, 'batchNumber': batchNumber,
    'manufacturedDate': manufacturedDate?.toIso8601String(),
    'expiryDate': expiryDate?.toIso8601String(),
    'qtyTransferred': qtyTransferred, 'qtyReceived': qtyReceived,
    'cost': cost, 'remarks': remarks,
  };

  factory TransferItem.fromJson(Map<String, dynamic> j) => TransferItem(
    itemId: j['itemId'] ?? '', itemCode: j['itemCode'] ?? '',
    itemName: j['itemName'] ?? '', category: j['category'] ?? '',
    unit: j['unit'] ?? 'pcs',
    batchId: j['batchId'] ?? '', batchNumber: j['batchNumber'] ?? '',
    manufacturedDate: j['manufacturedDate'] != null ? DateTime.tryParse(j['manufacturedDate']) : null,
    expiryDate: j['expiryDate'] != null ? DateTime.tryParse(j['expiryDate']) : null,
    qtyTransferred: j['qtyTransferred'] ?? 0,
    qtyReceived: j['qtyReceived'] ?? 0,
    cost: (j['cost'] ?? 0).toDouble(), remarks: j['remarks'] ?? '',
  );

  Map<String, dynamic> toMap() => toJson();
  factory TransferItem.fromMap(Map<String, dynamic> m) => TransferItem.fromJson(m);
}

// ---- Stock Transfer ----
class StockTransfer {
  final String id;
  final String transferNo;
  final DateTime transferDate;
  final String fromBranchId;
  final String fromBranchName;
  final String toBranchId;
  final String toBranchName;
  // STX DEVICE FIELDS - device-based filtering
  final String fromDeviceId;
  final String toDeviceId;
  String status;
  final String preparedBy;
  String approvedBy;
  String receivedBy;
  DateTime? receivedDate;
  String remarks;
  final List<TransferItem> items;
  final DateTime createdAt;
  DateTime updatedAt;

  StockTransfer({
    required this.id, required this.transferNo, required this.transferDate,
    required this.fromBranchId, required this.fromBranchName,
    required this.toBranchId, required this.toBranchName,
    this.fromDeviceId = "", this.toDeviceId = "",
    this.status = 'Draft', required this.preparedBy, this.approvedBy = '',
    this.receivedBy = '', this.receivedDate, this.remarks = '',
    required this.items, required this.createdAt, DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  int get totalItems => items.length;
  int get totalQtyTransferred => items.fold(0, (s, i) => s + i.qtyTransferred);
  int get totalQtyReceived => items.fold(0, (s, i) => s + i.qtyReceived);
  double get totalCost => items.fold(0, (s, i) => s + i.totalCost);
  bool get isInTransit => status == 'In Transit';
  bool get isReceived => status == 'Received';
  bool get isCancelled => status == 'Cancelled';
  bool get isDraft => status == 'Draft';
  int get expiredItemCount => items.where((i) => i.isExpired).length;
  int get nearExpiryItemCount => items.where((i) => i.isNearExpiry).length;

  Map<String, dynamic> toJson() => {
    'id': id, 'transferNo': transferNo,
    'transferDate': transferDate.toIso8601String(),
    'fromBranchId': fromBranchId, 'fromBranchName': fromBranchName,
    'toBranchId': toBranchId, 'toBranchName': toBranchName,
    'fromDeviceId': fromDeviceId, 'toDeviceId': toDeviceId,
    'status': status, 'preparedBy': preparedBy, 'approvedBy': approvedBy,
    'receivedBy': receivedBy,
    'receivedDate': receivedDate?.toIso8601String(),
    'remarks': remarks,
    'items': items.map((i) => i.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory StockTransfer.fromJson(Map<String, dynamic> j) => StockTransfer(
    id: j['id'] ?? '', transferNo: j['transferNo'] ?? '',
    transferDate: DateTime.tryParse(j['transferDate'] ?? '') ?? DateTime.now(),
    fromBranchId: j['fromBranchId'] ?? '', fromBranchName: j['fromBranchName'] ?? '',
    toBranchId: j['toBranchId'] ?? '', toBranchName: j['toBranchName'] ?? '',
    fromDeviceId: j['fromDeviceId'] ?? '', toDeviceId: j['toDeviceId'] ?? '',
    status: j['status'] ?? 'Draft', preparedBy: j['preparedBy'] ?? '',
    approvedBy: j['approvedBy'] ?? '', receivedBy: j['receivedBy'] ?? '',
    receivedDate: j['receivedDate'] != null ? DateTime.tryParse(j['receivedDate']) : null,
    remarks: j['remarks'] ?? '',
    items: (j['items'] as List<dynamic>?)?.map((i) => TransferItem.fromJson(i as Map<String, dynamic>)).toList() ?? [],
    createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
    updatedAt: j['updatedAt'] != null ? DateTime.tryParse(j['updatedAt']) : null,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'transferNo': transferNo,
    'transferDate': transferDate.toIso8601String(),
    'fromBranchId': fromBranchId, 'fromBranchName': fromBranchName,
    'toBranchId': toBranchId, 'toBranchName': toBranchName,
    'fromDeviceId': fromDeviceId, 'toDeviceId': toDeviceId,
    'status': status, 'preparedBy': preparedBy, 'approvedBy': approvedBy,
    'receivedBy': receivedBy,
    'receivedDate': receivedDate?.toIso8601String(),
    'remarks': remarks,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory StockTransfer.fromMap(Map<String, dynamic> m, List<TransferItem> items) => StockTransfer(
    id: m['id'] ?? '', transferNo: m['transferNo'] ?? '',
    transferDate: DateTime.tryParse(m['transferDate'] ?? '') ?? DateTime.now(),
    fromBranchId: m['fromBranchId'] ?? '', fromBranchName: m['fromBranchName'] ?? '',
    toBranchId: m['toBranchId'] ?? '', toBranchName: m['toBranchName'] ?? '',
    fromDeviceId: m['fromDeviceId'] ?? '', toDeviceId: m['toDeviceId'] ?? '',
    status: m['status'] ?? 'Draft', preparedBy: m['preparedBy'] ?? '',
    approvedBy: m['approvedBy'] ?? '', receivedBy: m['receivedBy'] ?? '',
    receivedDate: m['receivedDate'] != null ? DateTime.tryParse(m['receivedDate']) : null,
    remarks: m['remarks'] ?? '', items: items,
    createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
    updatedAt: m['updatedAt'] != null ? DateTime.tryParse(m['updatedAt']) : null,
  );
}

// ---- Transfer Ledger Entry ----
class TransferLedgerEntry {
  final String id;
  final String transferId;
  final String referenceNo;
  final String itemId;
  final String itemCode;
  final String itemName;
  final String batchId;
  final String batchNumber;
  final String branchId;
  final String branchName;
  final String movementType;
  final DateTime? manufacturedDate;
  final DateTime? expiryDate;
  final int beginningBalance;
  final int qtyIn;
  final int qtyOut;
  final int endingBalance;
  final double cost;
  final String user;
  final DateTime date;
  final String remarks;

  TransferLedgerEntry({
    required this.id, this.transferId = '', this.referenceNo = '',
    this.itemId = '', this.itemCode = '', this.itemName = '',
    this.batchId = '', this.batchNumber = '',
    this.branchId = '', this.branchName = '',
    this.movementType = '',
    this.manufacturedDate, this.expiryDate,
    this.beginningBalance = 0, this.qtyIn = 0, this.qtyOut = 0,
    this.endingBalance = 0, this.cost = 0, this.user = '',
    required this.date, this.remarks = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'transferId': transferId, 'referenceNo': referenceNo,
    'itemId': itemId, 'itemCode': itemCode, 'itemName': itemName,
    'batchId': batchId, 'batchNumber': batchNumber,
    'branchId': branchId, 'branchName': branchName,
    'movementType': movementType,
    'manufacturedDate': manufacturedDate?.toIso8601String(),
    'expiryDate': expiryDate?.toIso8601String(),
    'beginningBalance': beginningBalance,
    'qtyIn': qtyIn, 'qtyOut': qtyOut, 'endingBalance': endingBalance,
    'cost': cost, 'user': user,
    'date': date.toIso8601String(), 'remarks': remarks,
  };

  factory TransferLedgerEntry.fromJson(Map<String, dynamic> j) => TransferLedgerEntry(
    id: j['id'] ?? '', transferId: j['transferId'] ?? '',
    referenceNo: j['referenceNo'] ?? '', itemId: j['itemId'] ?? '',
    itemCode: j['itemCode'] ?? '', itemName: j['itemName'] ?? '',
    batchId: j['batchId'] ?? '', batchNumber: j['batchNumber'] ?? '',
    branchId: j['branchId'] ?? '', branchName: j['branchName'] ?? '',
    movementType: j['movementType'] ?? '',
    manufacturedDate: j['manufacturedDate'] != null ? DateTime.tryParse(j['manufacturedDate']) : null,
    expiryDate: j['expiryDate'] != null ? DateTime.tryParse(j['expiryDate']) : null,
    beginningBalance: j['beginningBalance'] ?? 0,
    qtyIn: j['qtyIn'] ?? 0, qtyOut: j['qtyOut'] ?? 0,
    endingBalance: j['endingBalance'] ?? 0,
    cost: (j['cost'] ?? 0).toDouble(), user: j['user'] ?? '',
    date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
    remarks: j['remarks'] ?? '',
  );

  Map<String, dynamic> toMap() => toJson();
  factory TransferLedgerEntry.fromMap(Map<String, dynamic> m) => TransferLedgerEntry.fromJson(m);
}

// ---- Storage (SQLite Backend) ----
class StockTransferStorage {
  static String generateTransferNo() {
    final now = DateTime.now();
    final date = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final seq = '${now.hour}${now.minute}${now.second}'.padLeft(6, '0');
    return 'TRF-$date-$seq';
  }

  static Future<void> saveAll(List<StockTransfer> transfers) async {
    final db = DatabaseHelper();
    for (final t in transfers) {
      await db.insertTransferWithItems(t.toMap(), t.items.map((i) => i.toMap()).toList());
    }
  }

  static Future<List<StockTransfer>> getAll() async {
    final db = DatabaseHelper();
    final rows = await db.getAllStockTransfers();
    List<StockTransfer> result = [];
    for (final row in rows) {
      final itemRows = await db.getTransferItems(row['id']);
      final items = itemRows.map((r) => TransferItem.fromMap(r)).toList();
      result.add(StockTransfer.fromMap(row, items));
    }
    return result;
  }

  static Future<void> add(StockTransfer t) async {
    await DatabaseHelper().insertTransferWithItems(t.toMap(), t.items.map((i) => i.toMap()).toList());
  }

  static Future<void> addTransfer(StockTransfer t) async => add(t);

  static Future<void> update(StockTransfer t) async {
    final db = DatabaseHelper();
    await db.updateStockTransfer(t.id, t.toMap());
    await db.replaceTransferItems(t.id, t.items.map((i) => i.toMap()).toList());
  }

  static Future<void> updateTransfer(StockTransfer t) async => update(t);

  static Future<List<StockTransfer>> getByStatus(String status) async {
    final db = DatabaseHelper();
    final rows = await db.getTransfersByStatus(status);
    List<StockTransfer> result = [];
    for (final row in rows) {
      final itemRows = await db.getTransferItems(row['id']);
      final items = itemRows.map((r) => TransferItem.fromMap(r)).toList();
      result.add(StockTransfer.fromMap(row, items));
    }
    return result;
  }

  static Future<StockTransfer?> getById(String id) async {
    final db = DatabaseHelper();
    final row = await db.getStockTransferById(id);
    if (row == null) return null;
    final itemRows = await db.getTransferItems(id);
    final items = itemRows.map((r) => TransferItem.fromMap(r)).toList();
    return StockTransfer.fromMap(row, items);
  }

  static Future<void> saveLedger(List<TransferLedgerEntry> entries) async {
    await DatabaseHelper().bulkInsertLedgerEntries(entries.map((e) => e.toMap()).toList());
  }

  static Future<List<TransferLedgerEntry>> getLedger() async {
    final rows = await DatabaseHelper().getAllLedgerEntries();
    return rows.map((r) => TransferLedgerEntry.fromMap(r)).toList();
  }

  static Future<List<TransferLedgerEntry>> getLedgerByItem(String itemId) async {
    final rows = await DatabaseHelper().getLedgerByItem(itemId);
    return rows.map((r) => TransferLedgerEntry.fromMap(r)).toList();
  }

  static Future<List<TransferLedgerEntry>> getLedgerByRef(String refNo) async {
    final rows = await DatabaseHelper().getLedgerByRef(refNo);
    return rows.map((r) => TransferLedgerEntry.fromMap(r)).toList();
  }

  static Future<List<TransferLedgerEntry>> getLedgerByBatch(String batchNumber) async {
    final rows = await DatabaseHelper().getLedgerByBatch(batchNumber);
    return rows.map((r) => TransferLedgerEntry.fromMap(r)).toList();
  }


  // STX BRANCH FILTERED - get inbound transfers for current device's branch only
  static Future<List<StockTransfer>> getInboundForBranch(String branchId) async {
    if (branchId.isEmpty) return [];
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'stock_transfers',
      where: 'toBranchId = ? AND status = ?',
      whereArgs: [branchId, 'In Transit'],
      orderBy: 'transferDate DESC',
    );
    final List<StockTransfer> result = [];
    for (final row in rows) {
      final itemRows = await DatabaseHelper().getTransferItems(row['id'] as String);
      final items = itemRows.map((r) => TransferItem.fromMap(r)).toList();
      result.add(StockTransfer.fromMap(row, items));
    }
    return result;
  }

  // STX BRANCH FILTERED - dashboard stats for current device's branch only
  static Future<Map<String, int>> getDashboardStatsForBranch(String branchId) async {
    if (branchId.isEmpty) {
      return {'inTransit': 0, 'receivedToday': 0, 'outboundToday': 0, 'pendingReceive': 0};
    }
    final all = await getAll();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // INBOUND (to current branch): In Transit
    final inTransit = all.where((t) =>
      t.toBranchId == branchId && t.status == 'In Transit'
    ).length;
    
    // RECEIVED today (to current branch)
    final receivedToday = all.where((t) =>
      t.toBranchId == branchId && 
      t.status == 'Received' && 
      t.receivedDate != null && 
      t.receivedDate!.isAfter(today)
    ).length;
    
    // OUTBOUND today (from current branch)
    final outboundToday = all.where((t) =>
      t.fromBranchId == branchId && 
      t.transferDate.isAfter(today) && 
      t.status != 'Cancelled'
    ).length;
    
    // PENDING RECEIVE (to current branch, In Transit - same as inTransit)
    return {
      'inTransit': inTransit,
      'receivedToday': receivedToday,
      'outboundToday': outboundToday,
      'pendingReceive': inTransit,
    };
  }

  static Future<Map<String, int>> getDashboardStats() async {
    final all = await getAll();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return {
      'inTransit': all.where((t) => t.status == 'In Transit').length,
      'receivedToday': all.where((t) => t.status == 'Received' && t.receivedDate != null && t.receivedDate!.isAfter(today)).length,
      'outboundToday': all.where((t) => t.transferDate.isAfter(today) && t.status != 'Cancelled').length,
      'pendingReceive': all.where((t) => t.status == 'In Transit').length,
    };
  }

  static Future<void> loadFromDB() async {
    await getAll();
  }
}
