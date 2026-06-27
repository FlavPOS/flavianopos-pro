import 'package:flutter/foundation.dart';
import '../models/cashier_session_model.dart';
import '../models/incident_report_model.dart';
import '../helpers/database_helper.dart';
import '../helpers/sync_queue_dao.dart';
import '../models/sync_queue_model.dart';
import '../models/user_model.dart';
import '../models/branch_model.dart';
import '../models/product_model.dart';
import '../models/batch_model.dart';
import '../models/transaction_model.dart';
import '../models/z_report_model.dart';
import '../services/setup_mode_service.dart';
import '../services/firebase_config_service.dart';
import '../services/firebase_realtime_service.dart';
import '../services/device_assignment_service.dart';
import '../services/device_id_service.dart';

/// Central sync bridge.
/// Every model's add/update/delete static method calls into here.
/// In Solo Store mode this is a no-op.
/// In Multiple Store mode it enqueues + uploads to Firebase.
class SyncBridge {
  SyncBridge._();

  static final _queue = SyncQueueDao();
  static final _modeSvc = SetupModeService();
  static final _cfgSvc = FirebaseConfigService();
  static final _assignSvc = DeviceAssignmentService();
  static final _deviceSvc = DeviceIdService();

  static Future<bool> _isMultiple() async {
    return (await _modeSvc.getSetupMode()) == SetupModeService.modeMultiple;
  }

  static Future<Map<String, String>> _context() async {
    final cfg = await _cfgSvc.load();
    final assign = await _assignSvc.read();
    final deviceId = await _deviceSvc.getOrCreate();
    return {
      'companyCode': cfg?.companyCode ?? '',
      'branchId': assign['branchId'] ?? '',
      'branchName': assign['branchName'] ?? '',
      'deviceId': deviceId,
    };
  }

  // ═══════════════════════ USER ═══════════════════════
  static Future<void> enqueueUser(AppUser user, {required String op}) async {
    if (!await _isMultiple()) return;
    final ctx = await _context();
    final companyCode = ctx['companyCode']!;
    if (companyCode.isEmpty) return;

    final branchId = (user.branch.isNotEmpty)
        ? await _resolveBranchIdByName(user.branch)
        : ctx['branchId']!;

    final payload = _userToFirebasePayload(user, companyCode, branchId, ctx);

    if (op == SyncOp.delete) {
      await _queue.enqueue(
        entityType: 'user', entityId: user.id, operation: op,
        firebasePath: 'companies/$companyCode/users/${user.id}',
        payload: payload, companyId: companyCode, branchId: branchId,
        deviceId: ctx['deviceId']!, priority: SyncPriority.p1Critical,
      );
      _fireAndForget(() => _deleteUserOnFirebase(companyCode, user.id, branchId));
      return;
    }

    await _queue.enqueue(
      entityType: 'user', entityId: user.id, operation: op,
      firebasePath: 'companies/$companyCode/users/${user.id}',
      payload: payload, companyId: companyCode, branchId: branchId,
      deviceId: ctx['deviceId']!, priority: SyncPriority.p1Critical,
    );
    if (branchId.isNotEmpty) {
      await _queue.enqueue(
        entityType: 'userByBranch', entityId: user.id, operation: op,
        firebasePath: 'companies/$companyCode/usersByBranch/$branchId/${user.id}',
        payload: payload, companyId: companyCode, branchId: branchId,
        deviceId: ctx['deviceId']!, priority: SyncPriority.p1Critical,
      );
    }
    _fireAndForget(() => _uploadUserToFirebase(companyCode, user.id, branchId, payload));
  }

  static Map<String, dynamic> _userToFirebasePayload(
      AppUser u, String companyCode, String branchId, Map<String, String> ctx) {
    return {
      'userId': u.id,
      'companyCode': companyCode,
      'username': u.username,
      'fullName': u.name,
      'role': u.role,
      'roleName': u.role,
      'branchId': branchId,
      'branchName': u.branch,
      'createdByDeviceId': ctx['deviceId'],
      'email': u.email,
      'phone': u.phone,
      'permissions': u.permissions,
      'isMainBranchUser': u.role == 'Admin',
      'isCompanyAdmin': u.role == 'Admin',
      'isBranchAdmin': u.role == 'Manager',
      'isActive': u.isActive,
      'createdAt': u.joinDate.toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'lastModifiedAt': DateTime.now().toUtc().toIso8601String(),
      'isDeleted': false,
    };
  }

  static Future<void> _uploadUserToFirebase(
      String companyCode, String userId, String branchId, Map<String, dynamic> payload) async {
    try {
      final cfg = await _cfgSvc.load();
      if (cfg == null) return;
      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/users/$userId').set(payload);
      if (branchId.isNotEmpty) {
        await db.ref('companies/$companyCode/usersByBranch/$branchId/$userId').set(payload);
      }
      await _markQueueSynced('user', userId);
      await _markQueueSynced('userByBranch', userId);
      await _markRowSynced('users', 'id', userId);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ user upload failed: $e');
    }
  }

  static Future<void> _deleteUserOnFirebase(
      String companyCode, String userId, String branchId) async {
    try {
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/users/$userId').remove();
      if (branchId.isNotEmpty) {
        await db.ref('companies/$companyCode/usersByBranch/$branchId/$userId').remove();
      }
      await _markQueueSynced('user', userId);
      await _markQueueSynced('userByBranch', userId);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ user delete failed: $e');
    }
  }

  // ═══════════════════════ BRANCH ═══════════════════════
  static Future<void> enqueueBranch(Branch b, {required String op}) async {
    if (!await _isMultiple()) return;
    final ctx = await _context();
    final companyCode = ctx['companyCode']!;
    if (companyCode.isEmpty) return;

    final payload = _branchToFirebasePayload(b, companyCode, ctx);
    final path = 'companies/$companyCode/branches/${b.id}';

    await _queue.enqueue(
      entityType: 'branch', entityId: b.id, operation: op,
      firebasePath: path, payload: payload,
      companyId: companyCode, branchId: b.id, deviceId: ctx['deviceId']!,
      priority: SyncPriority.p1Critical,
    );

    if (op == SyncOp.delete) {
      _fireAndForget(() => _deleteBranchOnFirebase(companyCode, b.id));
    } else {
      _fireAndForget(() => _uploadBranchToFirebase(companyCode, b.id, payload));
    }
  }

  static Map<String, dynamic> _branchToFirebasePayload(
      Branch b, String companyCode, Map<String, String> ctx) {
    return {
      'branchId': b.id,
      'companyCode': companyCode,
      'branchCode': b.name.toUpperCase().replaceAll(RegExp(r'\s+'), '-'),
      'branchName': b.name,
      'address': b.address,
      'phone': b.phone,
      'email': b.email,
      'manager': b.manager,
      'isActive': b.isActive,
      'isMainBranch': false,
      'createdAt': b.createdDate.toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'createdByDeviceId': ctx['deviceId'],
      'isDeleted': false,
    };
  }

  static Future<void> _uploadBranchToFirebase(
      String companyCode, String branchId, Map<String, dynamic> payload) async {
    try {
      final cfg = await _cfgSvc.load();
      if (cfg == null) return;
      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/branches/$branchId').set(payload);
      await _markQueueSynced('branch', branchId);
      await _markRowSynced('branches', 'id', branchId);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ branch upload failed: $e');
    }
  }

  static Future<void> _deleteBranchOnFirebase(
      String companyCode, String branchId) async {
    try {
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/branches/$branchId').remove();
      await _markQueueSynced('branch', branchId);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ branch delete failed: $e');
    }
  }

  // ═══════════════════════ HELPERS ═══════════════════════
  static Future<String> _resolveBranchIdByName(String branchName) async {
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query('branches',
          where: 'LOWER(name) = LOWER(?)', whereArgs: [branchName], limit: 1);
      if (rows.isNotEmpty) return rows.first['id'].toString();
    } catch (_) {}
    return '';
  }

  static Future<void> _markQueueSynced(String entityType, String entityId) async {
    try {
      final db = await DatabaseHelper().database;
      await db.update('sync_queue',
          {'status': SyncStatus.synced,
           'updatedAt': DateTime.now().toUtc().toIso8601String(),
           'errorMessage': null},
          where: 'entityType = ? AND entityId = ?',
          whereArgs: [entityType, entityId]);
    } catch (_) {}
  }

  static Future<void> _markRowSynced(String table, String pkCol, String pkVal) async {
    try {
      final db = await DatabaseHelper().database;
      await db.update(table,
          {'syncStatus': SyncStatus.synced,
           'lastSyncedAt': DateTime.now().toUtc().toIso8601String()},
          where: '$pkCol = ?', whereArgs: [pkVal]);
    } catch (_) {}
  }

  static void _fireAndForget(Future<void> Function() task) {
    task().catchError((_) {});
  }

  // ═══════════════════ PRODUCT (Head Office only writes) ═══════════════════
  static Future<void> enqueueProduct(Product p, {required String op}) async {
    if (!await _isMultiple()) return;
    // 🛡️ Role check: only Admin can sync product master changes
    final dbCheck = await DatabaseHelper().database;
    final roleRows = await dbCheck.rawQuery(
      "SELECT role FROM users WHERE lastLogin IS NOT NULL ORDER BY lastLogin DESC LIMIT 1"
    );
    if (roleRows.isNotEmpty) {
      final viewerRole = (roleRows.first["role"] ?? "").toString();
      if (viewerRole != "Admin") {
        if (kDebugMode) debugPrint("🔒 Non-Admin tried to sync product — blocked");
        return;
      }
    }
    final ctx = await _context();
    final companyCode = ctx['companyCode']!;
    if (companyCode.isEmpty) return;

    final payload = {
      'productId': p.id,
      'companyCode': companyCode,
      'name': p.name,
      'sku': p.sku,
      'barcode': p.barcode,
      'category': p.category,
      'unit': p.unit,
      'costPrice': p.costPrice,
      'sellingPrice': p.sellingPrice,
      'stockQty': p.stockQty,
      'reorderLevel': p.reorderLevel,
      'imageUrl': p.imageUrl,
      'isActive': true,
      'createdByDeviceId': ctx['deviceId'],
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'isDeleted': op == SyncOp.delete,
    };
    final path = 'companies/$companyCode/products/${p.id}';
    await _queue.enqueue(
      entityType: 'product', entityId: p.id, operation: op,
      firebasePath: path, payload: payload,
      companyId: companyCode, branchId: ctx['branchId']!,
      deviceId: ctx['deviceId']!,
      priority: SyncPriority.p2MasterData,
    );
    if (op == SyncOp.delete) {
      _fireAndForget(() => _deleteProductOnFirebase(companyCode, p.id));
    } else {
      _fireAndForget(() => _uploadProductToFirebase(companyCode, p.id, payload));
    }
  }

  static Future<void> _uploadProductToFirebase(
      String companyCode, String productId, Map<String, dynamic> payload) async {
    try {
      final cfg = await _cfgSvc.load();
      if (cfg == null) return;
      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/products/$productId').set(payload);
      await _markQueueSynced('product', productId);
      await _markRowSynced('products', 'id', productId);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ product upload failed: $e');
    }
  }

  static Future<void> _deleteProductOnFirebase(
      String companyCode, String productId) async {
    try {
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/products/$productId').remove();
      await _markQueueSynced('product', productId);
    } catch (_) {}
  }

  // ═══════════════════ BATCH (per-branch physical stock) ═══════════════════
  static Future<void> enqueueBatch(ProductBatch b, {required String op}) async {
    if (!await _isMultiple()) return;
    final ctx = await _context();
    final companyCode = ctx['companyCode']!;
    final branchId = ctx['branchId']!;
    if (companyCode.isEmpty || branchId.isEmpty) return;

    final payload = {
      'batchId': b.id,
      'productId': b.productId,
      'productName': b.productName,
      'productSku': b.productSku,
      'batchNumber': b.batchNumber,
      'manufacturedDate': b.manufacturedDate.toIso8601String(),
      'expiryDate': b.expiryDate.toIso8601String(),
      'quantity': b.quantity,
      'originalQty': b.originalQty,
      'costPrice': b.costPrice,
      'supplier': b.supplier,
      'notes': b.notes,
      'branchId': branchId,
      'companyCode': companyCode,
      'deviceId': ctx['deviceId'],
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'isDeleted': op == SyncOp.delete,
    };
    final path = 'companies/$companyCode/batches/$branchId/${b.id}';
    await _queue.enqueue(
      entityType: 'batch', entityId: b.id, operation: op,
      firebasePath: path, payload: payload,
      companyId: companyCode, branchId: branchId,
      deviceId: ctx['deviceId']!,
      priority: SyncPriority.p2MasterData,
    );
    if (op == SyncOp.delete) {
      _fireAndForget(() => _deleteBatchOnFirebase(companyCode, branchId, b.id));
    } else {
      _fireAndForget(() => _uploadBatchToFirebase(companyCode, branchId, b.id, payload));
    }
  }

  static Future<void> _uploadBatchToFirebase(
      String companyCode, String branchId, String batchId,
      Map<String, dynamic> payload) async {
    try {
      final cfg = await _cfgSvc.load();
      if (cfg == null) return;
      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/batches/$branchId/$batchId').set(payload);
      await _markQueueSynced('batch', batchId);
      await _markRowSynced('batches', 'id', batchId);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ batch upload failed: $e');
    }
  }

  static Future<void> _deleteBatchOnFirebase(
      String companyCode, String branchId, String batchId) async {
    try {
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/batches/$branchId/$batchId').remove();
      await _markQueueSynced('batch', batchId);
    } catch (_) {}
  }

  // ═══════════════════ SALES TRANSACTIONS (per-branch) ═══════════════════
  static Future<void> enqueueTransaction(Transaction t, {required String op}) async {
    if (!await _isMultiple()) return;
    final ctx = await _context();
    final companyCode = ctx['companyCode']!;
    final branchId = ctx['branchId']!;
    if (companyCode.isEmpty || branchId.isEmpty) return;

    final payload = {
      'txnId': t.id,
      'companyCode': companyCode,
      'branchId': branchId,
      'branchName': ctx['branchName'] ?? '',
      'subtotal': t.subtotal,
      'totalDiscount': t.totalDiscount,
      'tax': t.tax,
      'total': t.total,
      'paymentMethod': t.paymentMethod,
      'amountPaid': t.amountPaid,
      'change': t.change,
      'cashier': t.cashier,
      'branch': t.branch,
      'dateTime': t.dateTime.toIso8601String(),
      'status': t.status,
      'voidReason': t.voidReason,
      'voidedBy': t.voidedBy,
      'voidedAt': t.voidedAt?.toIso8601String(),
      'refundAmount': t.refundAmount,
      'itemCount': t.items.length,
      'items': t.items.map((i) => i.toMap()).toList(),
      'deviceId': ctx['deviceId'],
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'isDeleted': op == SyncOp.delete,
    };
    final path = 'companies/$companyCode/sales/$branchId/${t.id}';
    await _queue.enqueue(
      entityType: 'transaction', entityId: t.id, operation: op,
      firebasePath: path, payload: payload,
      companyId: companyCode, branchId: branchId,
      deviceId: ctx['deviceId']!,
      priority: SyncPriority.p4Transactional,
    );
    if (op == SyncOp.delete) {
      _fireAndForget(() => _deleteTransactionOnFirebase(companyCode, branchId, t.id));
    } else {
      _fireAndForget(() => _uploadTransactionToFirebase(companyCode, branchId, t.id, payload));
    }
  }

  static Future<void> _uploadTransactionToFirebase(
      String companyCode, String branchId, String txnId,
      Map<String, dynamic> payload) async {
    try {
      final cfg = await _cfgSvc.load();
      if (cfg == null) return;
      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/sales/$branchId/$txnId').set(payload);
      await _markQueueSynced('transaction', txnId);
      await _markRowSynced('transactions', 'id', txnId);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ transaction upload failed: $e');
    }
  }

  static Future<void> _deleteTransactionOnFirebase(
      String companyCode, String branchId, String txnId) async {
    try {
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/sales/$branchId/$txnId').remove();
      await _markQueueSynced('transaction', txnId);
    } catch (_) {}
  }

  // ═══════════════════ Z REPORTS (per-branch end-of-shift snapshots) ═══════════════════
  static Future<void> enqueueZReport(ZReportRecord r, {required String op}) async {
    if (!await _isMultiple()) return;
    final ctx = await _context();
    final companyCode = ctx['companyCode']!;
    final branchId = ctx['branchId']!;
    if (companyCode.isEmpty || branchId.isEmpty) return;

    // 💰 Fetch denominations from local SQLite to include in Firebase payload
    final denomList = <Map<String, dynamic>>[];
    try {
      final db2 = await DatabaseHelper().database;
      final rows = await db2.query(
        "denomination_records",
        where: "sessionId = ? AND type = ?",
        whereArgs: [r.reportId, "ending"],
        orderBy: "denomination DESC",
      );
      for (final dr in rows) {
        denomList.add({
          "denomination": (dr["denomination"] as num?)?.toDouble() ?? 0,
          "quantity": (dr["quantity"] as num?)?.toInt() ?? 0,
          "total": (dr["total"] as num?)?.toDouble() ?? 0,
        });
      }
      if (kDebugMode) debugPrint("💰 Firebase Z Report: ${denomList.length} denoms attached");
    } catch (e) {
      if (kDebugMode) debugPrint("⚠️ Denom fetch for sync failed: $e");
    }

    final payload = {
      'reportId': r.reportId,
      'reportDate': r.reportDate.toIso8601String(),
      'generatedAt': r.generatedAt.toIso8601String(),
      'branch': r.branch,
      'branchId': branchId,
      'branchName': ctx['branchName'] ?? '',
      'cashier': r.cashier,
      'companyCode': companyCode,
      'grossSales': r.grossSales,
      'totalDiscount': r.totalDiscount,
      'netSales': r.netSales,
      'totalTransactions': r.totalTransactions,
      'averageTransaction': r.averageTransaction,
      'beginningCash': r.beginningCash,
      'endingCash': r.endingCash,
      'expectedCash': r.expectedCash,
      'overShort': r.overShort,
      'voidedCount': r.voidedCount,
      'voidedAmount': r.voidedAmount,
      'refundedCount': r.refundedCount,
      'refundedAmount': r.refundedAmount,
      'paymentBreakdownJson': (r.toMap()['paymentBreakdownJson'] ?? '').toString(),
      'voidedTransactionsJson': (r.toMap()['voidedTransactionsJson'] ?? '').toString(),
      'allTransactionsJson': (r.toMap()['allTransactionsJson'] ?? '').toString(),
      'deviceId': ctx['deviceId'],
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'isDeleted': op == SyncOp.delete,
      "denominations": denomList,
    };
    final path = 'companies/$companyCode/zReports/$branchId/${r.reportId}';
    await _queue.enqueue(
      entityType: 'zReport', entityId: r.reportId, operation: op,
      firebasePath: path, payload: payload,
      companyId: companyCode, branchId: branchId,
      deviceId: ctx['deviceId']!,
      priority: SyncPriority.p4Transactional,
    );
    _fireAndForget(() => _uploadZReportToFirebase(companyCode, branchId, r.reportId, payload));
  }

  static Future<void> _uploadZReportToFirebase(
      String companyCode, String branchId, String reportId,
      Map<String, dynamic> payload) async {
    try {
      final cfg = await _cfgSvc.load();
      if (cfg == null) return;
      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/zReports/$branchId/$reportId').set(payload);
      await _markQueueSynced('zReport', reportId);
      await _markRowSynced('z_reports', 'reportId', reportId);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Z Report upload failed: $e');
    }
  }

  // ═══════════════════ INCIDENT REPORTS (variance audit) ═══════════════════
  static Future<void> enqueueIncidentReport(IncidentReport ir, {required String op}) async {
    // BYPASS MODE CHECK FOR SYNC — sync if Firebase config exists
    final _fbCfg = await _cfgSvc.load();
    if (_fbCfg == null) return;
    final ctx = await _context();
    final companyCode = ctx['companyCode']!;
    final branchId = ctx['branchId']!;
    if (companyCode.isEmpty || branchId.isEmpty) return;

    final payload = {
      'id': ir.id,
      'irNumber': ir.irNumber,
      'sessionId': ir.sessionId,
      'cashierId': ir.cashierId,
      'cashierName': ir.cashierName,
      'branch': ir.branch,
      'branchId': branchId,
      'branchName': ctx['branchName'] ?? '',
      'companyCode': companyCode,
      'variance': ir.variance,
      'varianceType': ir.varianceType,
      'reason': ir.reason,
      'remarks': ir.remarks,
      'attachmentPath': ir.attachmentPath,
      'createdBy': ir.createdBy,
      'createdAt': ir.createdAt.toIso8601String(),
      'approvedBy': ir.approvedBy,
      'approvedAt': ir.approvedAt?.toIso8601String() ?? '',
      'status': ir.status,
      'deviceId': ctx['deviceId'],
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'isDeleted': op == SyncOp.delete,
    };
    if (kDebugMode) debugPrint("📋 Firebase IR: ${ir.irNumber} for ${ir.cashierName}");
    final path = 'companies/$companyCode/incidentReports/$branchId/${ir.id}';
    await _queue.enqueue(
      entityType: 'incidentReport', entityId: ir.id, operation: op,
      firebasePath: path, payload: payload,
      companyId: companyCode, branchId: branchId,
      deviceId: ctx['deviceId']!,
      priority: SyncPriority.p4Transactional,
    );
    _fireAndForget(() => _uploadIncidentReportToFirebase(companyCode, branchId, ir.id, payload));
  }


  // ═══════════════════ READ INCIDENT REPORTS FROM FIREBASE ═══════════════════
  // ✅ NEW METHOD — Read incident reports from Firebase (used by Cashier Report)
  // BIR-safe: skips records with isDeleted = true
  static Future<List<Map<String, dynamic>>> readIncidentReportsFromFirebase() async {
    try {
      final cfg = await _cfgSvc.load();
      if (cfg == null) return [];
      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return [];

      final ctx = await _context();
      final companyCode = ctx['companyCode']!;
      final branchId = ctx['branchId']!;
      if (companyCode.isEmpty || branchId.isEmpty) return [];

      final snap = await db
          .ref('companies/$companyCode/incidentReports/$branchId')
          .get()
          .timeout(const Duration(seconds: 10));

      if (!snap.exists) return [];

      final List<Map<String, dynamic>> irs = [];
      for (final child in snap.children) {
        try {
          final raw = child.value as Map<dynamic, dynamic>;
          final map = raw.map((k, v) => MapEntry(k.toString(), v));
          // ✅ BIR-safe soft delete
          if (map['isDeleted'] == true) continue;
          irs.add(map);
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Skipped malformed IR: $e');
        }
      }
      if (kDebugMode) debugPrint('☁️ Read ${irs.length} incident reports from Firebase');
      return irs;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Read Firebase incident reports failed: $e');
      return [];
    }
  }

  static Future<void> _uploadIncidentReportToFirebase(
      String companyCode, String branchId, String irId,
      Map<String, dynamic> payload) async {
    try {
      final cfg = await _cfgSvc.load();
      if (cfg == null) return;
      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/incidentReports/$branchId/$irId').set(payload);
      await _markQueueSynced('incidentReport', irId);
      await _markRowSynced('incident_reports', 'id', irId);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ IR upload failed: $e');
    }
  }

  // ═══════════════════ CASHIER SESSIONS (shift records) ═══════════════════
  static Future<void> enqueueCashierSession(CashierSession s, {required String op}) async {
    // BYPASS MODE CHECK FOR SYNC — sync if Firebase config exists
    final _fbCfg = await _cfgSvc.load();
    if (_fbCfg == null) return;
    final ctx = await _context();
    final companyCode = ctx['companyCode']!;
    final branchId = ctx['branchId']!;
    if (companyCode.isEmpty || branchId.isEmpty) return;

    // �� Fetch denominations
    final denomList = <Map<String, dynamic>>[];
    try {
      final db2 = await DatabaseHelper().database;
      final rows = await db2.query(
        "denomination_records",
        where: "sessionId = ? AND type = ?",
        whereArgs: [s.id, "ending"],
        orderBy: "denomination DESC",
      );
      for (final dr in rows) {
        denomList.add({
          "denomination": (dr["denomination"] as num?)?.toDouble() ?? 0,
          "quantity": (dr["quantity"] as num?)?.toInt() ?? 0,
          "total": (dr["total"] as num?)?.toDouble() ?? 0,
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint("⚠️ Cashier session denom fetch failed: $e");
    }

    final payload = {
      'id': s.id,
      'shiftId': s.shiftId,
      'cashierId': s.cashierId,
      'cashierName': s.cashierName,
      'branch': s.branch,
      'branchId': branchId,
      'branchName': ctx['branchName'] ?? '',
      'companyCode': companyCode,
      'beginningCash': s.beginningCash,
      'beginningSource': s.beginningSource,
      'beginningRemarks': s.beginningRemarks,
      'endingCashDeclared': s.endingCashDeclared,
      'systemExpectedCash': s.systemExpectedCash,
      'variance': s.variance,
      'varianceType': s.varianceType,
      'status': s.status,
      'openedAt': s.openedAt.toIso8601String(),
      'closedAt': s.closedAt?.toIso8601String() ?? '',
      'cashSales': s.cashSales,
      'gcashSales': s.gcashSales,
      'mayaSales': s.mayaSales,
      'cardSales': s.cardSales,
      'otherSales': s.otherSales,
      'totalRefunds': s.totalRefunds,
      'totalVoids': s.totalVoids,
      'totalDiscounts': s.totalDiscounts,
      'totalExchanges': s.totalExchanges,
      'transactionCount': s.transactionCount,
      'denominations': denomList,
      'deviceId': ctx['deviceId'],
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'isDeleted': op == SyncOp.delete,
    };
    if (kDebugMode) debugPrint("💼 Firebase Cashier Session: ${s.id} status=${s.status} denoms=${denomList.length}");
    final path = 'companies/$companyCode/cashierSessions/$branchId/${s.id}';
    await _queue.enqueue(
      entityType: 'cashierSession', entityId: s.id, operation: op,
      firebasePath: path, payload: payload,
      companyId: companyCode, branchId: branchId,
      deviceId: ctx['deviceId']!,
      priority: SyncPriority.p4Transactional,
    );
    _fireAndForget(() => _uploadCashierSessionToFirebase(companyCode, branchId, s.id, payload));
  }


  // ═══════════════════ READ CASHIER SESSIONS FROM FIREBASE ═══════════════════
  // ✅ NEW METHOD — Read sessions from Firebase (used by Cashier Report)
  // BIR-safe: skips records with isDeleted = true (soft delete pattern)

  // PHASE 3: Read users from Firebase (multi-device sync)
  // Returns ALL users including soft-deleted (UI will filter)
  // BIR-safe: same pattern as readCashierSessionsFromFirebase

  // PHASE 3 FIX: READ FROM BOTH PATHS
  // Reads users from companies/{code}/users (User Module created)
  // AND companies/{code}/usersByBranch/{branch}/{user} (Branch Wizard created)
  // Deduplicates by userId
  static Future<List<Map<String, dynamic>>> readUsersFromFirebase() async {
    try {
      final cfg = await _cfgSvc.load();
      if (cfg == null) return [];
      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return [];

      final ctx = await _context();
      final companyCode = ctx['companyCode']!;
      if (companyCode.isEmpty) return [];

      final List<Map<String, dynamic>> allUsers = [];
      final Set<String> seenIds = {};

      // PATH 1: companies/{code}/users/ (User Module created users)
      try {
        final snap1 = await db
            .ref('companies/$companyCode/users')
            .get()
            .timeout(const Duration(seconds: 10));
        if (snap1.exists) {
          for (final child in snap1.children) {
            try {
              final raw = child.value as Map<dynamic, dynamic>;
              final map = raw.map((k, v) => MapEntry(k.toString(), v));
              final id = (map["userId"] ?? map["id"] ?? "").toString();
              if (id.isEmpty || seenIds.contains(id)) continue;
              seenIds.add(id);
              allUsers.add(map);
            } catch (_) {}
          }
        }
      } catch (_) {}

      // PATH 2: companies/{code}/usersByBranch/{branch}/{user} (Branch Wizard)
      try {
        final snap2 = await db
            .ref('companies/$companyCode/usersByBranch')
            .get()
            .timeout(const Duration(seconds: 10));
        if (snap2.exists) {
          for (final branchNode in snap2.children) {
            for (final userNode in branchNode.children) {
              try {
                final raw = userNode.value as Map<dynamic, dynamic>;
                final map = raw.map((k, v) => MapEntry(k.toString(), v));
                final id = (map["userId"] ?? map["id"] ?? "").toString();
                if (id.isEmpty || seenIds.contains(id)) continue;
                seenIds.add(id);
                allUsers.add(map);
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      return allUsers;
    } catch (_) {
      return [];
    }
  }


  static Future<List<Map<String, dynamic>>> readCashierSessionsFromFirebase() async {
    try {
      final cfg = await _cfgSvc.load();
      if (cfg == null) return [];
      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return [];

      final ctx = await _context();
      final companyCode = ctx['companyCode']!;
      final branchId = ctx['branchId']!;
      if (companyCode.isEmpty || branchId.isEmpty) return [];

      final snap = await db
          .ref('companies/$companyCode/cashierSessions/$branchId')
          .get()
          .timeout(const Duration(seconds: 10));

      if (!snap.exists) return [];

      final List<Map<String, dynamic>> sessions = [];
      for (final child in snap.children) {
        try {
          final raw = child.value as Map<dynamic, dynamic>;
          final map = raw.map((k, v) => MapEntry(k.toString(), v));
          // ✅ BIR-safe soft delete: skip records marked as deleted
          if (map['isDeleted'] == true) continue;
          sessions.add(map);
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Skipped malformed session: $e');
        }
      }
      if (kDebugMode) debugPrint('☁️ Read ${sessions.length} sessions from Firebase');
      return sessions;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Read Firebase sessions failed: $e');
      return [];
    }
  }

  static Future<void> _uploadCashierSessionToFirebase(
      String companyCode, String branchId, String sessionId,
      Map<String, dynamic> payload) async {
    try {
      final cfg = await _cfgSvc.load();
      if (cfg == null) return;
      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/cashierSessions/$branchId/$sessionId').set(payload);
      await _markQueueSynced('cashierSession', sessionId);
      await _markRowSynced('cashier_sessions', 'id', sessionId);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Cashier Session upload failed: $e');
    }
  }

  // ═══════════════════ AUDIT TRAIL (re-declare, manager override) ═══════════════════
  static Future<void> enqueueAuditTrail(Map<String, dynamic> audit, {required String op}) async {
    if (!await _isMultiple()) return;
    final ctx = await _context();
    final companyCode = ctx['companyCode']!;
    final branchId = ctx['branchId']!;
    if (companyCode.isEmpty || branchId.isEmpty) return;

    final auditId = audit['id'] ?? 'AUDIT-${DateTime.now().millisecondsSinceEpoch}';
    final payload = {
      ...audit,
      'id': auditId,
      'branchId': branchId,
      'branchName': ctx['branchName'] ?? '',
      'companyCode': companyCode,
      'deviceId': ctx['deviceId'],
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'isDeleted': op == SyncOp.delete,
    };
    if (kDebugMode) debugPrint("📜 Firebase Audit Trail: ${audit['action']} by ${audit['performedBy']}");
    final path = 'companies/$companyCode/auditTrail/$branchId/$auditId';
    await _queue.enqueue(
      entityType: 'auditTrail', entityId: auditId, operation: op,
      firebasePath: path, payload: payload,
      companyId: companyCode, branchId: branchId,
      deviceId: ctx['deviceId']!,
      priority: SyncPriority.p4Transactional,
    );
    _fireAndForget(() => _uploadAuditTrailToFirebase(companyCode, branchId, auditId, payload));
  }

  static Future<void> _uploadAuditTrailToFirebase(
      String companyCode, String branchId, String auditId,
      Map<String, dynamic> payload) async {
    try {
      final cfg = await _cfgSvc.load();
      if (cfg == null) return;
      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      await db.ref('companies/$companyCode/auditTrail/$branchId/$auditId').set(payload);
      await _markQueueSynced('auditTrail', auditId);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Audit Trail upload failed: $e');
    }
  }
}
