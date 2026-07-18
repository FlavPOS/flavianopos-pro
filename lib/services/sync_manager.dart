import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../helpers/database_helper.dart';
import 'device_id_service.dart';
import '../helpers/sync_queue_dao.dart';
import '../helpers/cache_reload_helper.dart';
import '../models/sync_queue_model.dart';
import 'setup_mode_service.dart';
import 'firebase_config_service.dart';
import 'firebase_realtime_service.dart';
import 'device_assignment_service.dart';
import 'connectivity_watcher.dart';

/// SyncManager — central engine for offline-first cloud sync.
/// Solo Store mode: never starts (zero overhead).
/// Multiple Store mode: keeps SQLite ↔ Firebase in sync continuously.
class SyncManager {
  SyncManager._();
  static final SyncManager instance = SyncManager._();

  final _queueDao = SyncQueueDao();
  final _modeSvc = SetupModeService();
  final _cfgSvc = FirebaseConfigService();
  final _assignSvc = DeviceAssignmentService();
  final _connectivity = ConnectivityWatcher.instance;

  Timer? _periodicTimer;
  StreamSubscription<bool>? _connSub;
  final List<StreamSubscription<DatabaseEvent>> _rtListeners = [];

  // Status (used by UI pill)
  final ValueNotifier<SyncStatusInfo> status =
      ValueNotifier(SyncStatusInfo.idle());

  bool _started = false;
  bool _draining = false;

  /// Call once on app start.
  Future<void> start() async {
    if (_started) return;

    final mode = await _modeSvc.getSetupMode();
    if (mode != SetupModeService.modeMultiple) {
      if (kDebugMode) debugPrint('🔕 SyncManager idle (Solo Store mode)');
      return;
    }

    // Init Firebase if not already
    final cfg = await _cfgSvc.load();
    if (cfg == null || !cfg.hasRequiredFields) {
      if (kDebugMode) debugPrint('⚠️ SyncManager: no Firebase config');
      return;
    }
    if (!FirebaseRealtimeService.instance.isInitialized) {
      try {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ SyncManager init failed: $e');
        return;
      }
    }

    // Reset stuck "processing" items from previous crash
    final reset = await _queueDao.resetStuckProcessing();
    if (kDebugMode && reset > 0) {
      debugPrint('♻️  SyncManager reset $reset stuck items');
    }

    // Connectivity watcher
    await _connectivity.start();
    _connSub = _connectivity.onChange.listen((online) {
      _updateStatus(online: online);
      if (online) drainOnce(reason: 'connection-returned');
    });
    _updateStatus(online: _connectivity.isOnline);

    // Real-time Firebase listeners (own branch only — Q2=A)
    await _attachRealtimeListeners(cfg.companyCode);

    // Periodic drainer every 30s
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      drainOnce(reason: 'periodic');
    });

    // First drain
    drainOnce(reason: 'startup');

    _started = true;
    if (kDebugMode) debugPrint('✅ SyncManager started');
  }

  Future<void> stop() async {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    await _connSub?.cancel();
    _connSub = null;
    for (final s in _rtListeners) {
      await s.cancel();
    }
    _rtListeners.clear();
    _started = false;
  }

  /// Manual "Sync Now" button.
  Future<void> syncNow() => drainOnce(reason: 'manual');

  /// Drain all pending queue items once.
  Future<void> drainOnce({String reason = ''}) async {
    if (_draining) return;
    if (!_connectivity.isOnline) {
      _updateStatus(online: false);
      return;
    }
    _draining = true;
    try {
      final pending = await _queueDao.getPending(limit: 50);
      _updateStatus(pendingCount: pending.length, syncing: true);
      int success = 0;
      for (final item in pending) {
        final ok = await _processOne(item);
        if (ok) {
          success++;
        } else {
        }
      }
      if (success > 0) {
        _showSnackBar?.call('☁️ Synced $success record${success == 1 ? '' : 's'}');
      }
      final counts = await _queueDao.counts();
      _updateStatus(
        pendingCount: counts[SyncStatus.pending] ?? 0,
        failedCount: counts[SyncStatus.failed] ?? 0,
        syncing: false,
        lastSyncAt: DateTime.now(),
      );
    } finally {
      _draining = false;
    }
  }

  Future<bool> _processOne(SyncQueueItem item) async {
    // 🛡️ Ensure Firebase is initialized for this session
    if (!FirebaseRealtimeService.instance.isInitialized) {
      try {
        final cfg = await _cfgSvc.load();
        if (cfg != null) {
          await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
        }
      } catch (e) {
        if (kDebugMode) debugPrint("⚠️ Firebase init failed: $e");
        return false;
      }
    }
    final db = FirebaseRealtimeService.instance.db;
    if (db == null) return false;

    try {
      await _queueDao.markProcessing(item.queueId);
      final payload = item.payloadDecoded();
      final ref = db.ref(item.firebasePath);

      switch (item.operation) {
        case SyncOp.delete:
          await ref.remove().timeout(const Duration(seconds: 12));
          break;
        case SyncOp.update:
        case SyncOp.create:
        default:
          await ref.set(payload).timeout(const Duration(seconds: 12));
          break;
      }

      await _queueDao.markSynced(item.queueId);
      await _markRowSynced(item.entityType, item.entityId);
      return true;
    } catch (e) {
      await _queueDao.markFailed(item.queueId, e.toString());
      if (kDebugMode) debugPrint('⚠️ sync failed [${item.entityType}]: $e');
      return false;
    }
  }

  Future<void> _markRowSynced(String entityType, String entityId) async {
    final table = _tableFor(entityType);
    if (table == null) return;
    try {
      final db = await DatabaseHelper().database;
      await db.update(
        table,
        {
          'syncStatus': SyncStatus.synced,
          'lastSyncedAt': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [entityId],
      );
    } catch (_) {}
  }

  String? _tableFor(String entityType) {
    switch (entityType) {
      case 'user':
      case 'userByBranch':
        return 'users';
      case 'branch':
        return 'branches';
      case 'company':
        return 'companies_cache';
      case 'product':
        return 'products';
      case 'sale':
        return 'transactions';
      case 'expense':
        return 'expenses';
      default:
        return null;
    }
  }

  // ═══════════════════ Real-time listeners (Q2=A: own branch only) ═══════════════════
  Future<void> _attachRealtimeListeners(String companyCode) async {
    final fbDb = FirebaseRealtimeService.instance.db;
    if (fbDb == null) return;
    final assign = await _assignSvc.read();
    var branchId = assign['branchId'] ?? '';
    // v1.0.58+114 — HO users may have empty branchId; default to HO001
    if (branchId.isEmpty) {
      final role = (assign['role'] ?? '').toString().toLowerCase().trim();
      if (role == 'admin' || role == 'companyadmin') {
        branchId = 'HO001';
        if (kDebugMode) debugPrint('[SYNC-INV] HO user detected, defaulting branchId=HO001');
      }
    }

    await _backfillProducts(companyCode);  // 🆕 pull existing products first
    // 📦 Listen for product master (Head Office controls, all branches see)
    _rtListeners.add(fbDb.ref("companies/$companyCode/products")
        .onChildAdded.listen((event) => _onProductUpdate(event, companyCode)));
    _rtListeners.add(fbDb.ref("companies/$companyCode/products")
        .onChildChanged.listen((event) => _onProductUpdate(event, companyCode)));
    _rtListeners.add(fbDb.ref("companies/$companyCode/products")
        .onChildRemoved.listen((event) => _onProductDelete(event)));

    // Listen for branch list changes (so new branches added elsewhere appear)
    _rtListeners.add(fbDb.ref('companies/$companyCode/branches')
        .onChildAdded.listen((event) => _onBranchUpdate(event, companyCode)));
    _rtListeners.add(fbDb.ref('companies/$companyCode/branches')
        .onChildChanged.listen((event) => _onBranchUpdate(event, companyCode)));

    // Listen for users IN MY BRANCH
    if (branchId.isNotEmpty) {
      // 💰 SALES TRANSACTIONS
      final viewerRole = (assign["role"] ?? "").toString().toLowerCase().trim();
      if (viewerRole == "admin" || viewerRole == "companyadmin") {
        // 🏢 HEAD OFFICE: listen to ALL branches
        await _backfillAllSales(companyCode);  // 🆕 pull existing first
        _rtListeners.add(fbDb.ref("companies/$companyCode/sales")
            .onChildAdded.listen((event) => _onSaleBranchUpdate(event, companyCode)));
        _rtListeners.add(fbDb.ref("companies/$companyCode/sales")
            .onChildChanged.listen((event) => _onSaleBranchUpdate(event, companyCode)));
      } else {
        // 🏪 BRANCH: listen to OWN branch only
        await _backfillBranchSales(companyCode, branchId);  // 🆕 pull existing first
        _rtListeners.add(fbDb.ref("companies/$companyCode/sales/$branchId")
            .onChildAdded.listen((event) => _onSaleUpdate(event, companyCode, branchId)));
        _rtListeners.add(fbDb.ref("companies/$companyCode/sales/$branchId")
            .onChildChanged.listen((event) => _onSaleUpdate(event, companyCode, branchId)));
        _rtListeners.add(fbDb.ref("companies/$companyCode/sales/$branchId")
            .onChildRemoved.listen((event) => _onSaleDelete(event)));
      }
      // 📊 Z REPORTS (same branch-routing pattern as sales)
      if (viewerRole == "admin" || viewerRole == "companyadmin") {
        await _backfillAllZReports(companyCode);
        _rtListeners.add(fbDb.ref("companies/$companyCode/zReports")
            .onChildAdded.listen((event) => _onZReportBranchUpdate(event, companyCode)));
        _rtListeners.add(fbDb.ref("companies/$companyCode/zReports")
            .onChildChanged.listen((event) => _onZReportBranchUpdate(event, companyCode)));
      } else {
        await _backfillBranchZReports(companyCode, branchId);
        _rtListeners.add(fbDb.ref("companies/$companyCode/zReports/$branchId")
            .onChildAdded.listen((event) => _onZReportUpdate(event, companyCode, branchId)));
        _rtListeners.add(fbDb.ref("companies/$companyCode/zReports/$branchId")
            .onChildChanged.listen((event) => _onZReportUpdate(event, companyCode, branchId)));
      }

      // v156: HOLD TRANSACTIONS - Real-time multi-device sync (today-only filter)
      await _backfillHeldTransactions(companyCode);
      _rtListeners.add(fbDb.ref("companies/$companyCode/holdTransactions")
          .onChildAdded.listen((event) => _onHeldTransactionUpdate(event, companyCode)));
      _rtListeners.add(fbDb.ref("companies/$companyCode/holdTransactions")
          .onChildChanged.listen((event) => _onHeldTransactionUpdate(event, companyCode)));


      _rtListeners.add(fbDb.ref('companies/$companyCode/usersByBranch/$branchId')
          .onChildAdded.listen((event) => _onUserUpdate(event, branchId)));
      _rtListeners.add(fbDb.ref('companies/$companyCode/usersByBranch/$branchId')
          .onChildChanged.listen((event) => _onUserUpdate(event, branchId)));

      // 📦 BRANCH INVENTORY (multi-device same-branch real-time sync)
      // Listens for stock changes made by other devices in the same branch.
      // Uses deviceId comparison to prevent sync loops (ignore own writes).
      _rtListeners.add(fbDb.ref('companies/$companyCode/branchInventory/$branchId')
          .onChildAdded.listen((event) => _onInventoryUpdate(event, companyCode, branchId)));
      _rtListeners.add(fbDb.ref('companies/$companyCode/branchInventory/$branchId')
          .onChildChanged.listen((event) => _onInventoryUpdate(event, companyCode, branchId)));
      // v1.0.58+114 — Debug: confirm listener registered
      if (kDebugMode) debugPrint('[SYNC-INV] Registered listener for branchInventory/$branchId');

      // ═══ INTER-STORE TRANSFERS + BRANCH ADJUSTMENTS ═══
      _rtListeners.add(fbDb.ref('companies/$companyCode/interStoreTransfers')
          .onChildAdded.listen((event) => _onTransferUpdate(event, companyCode)));
      _rtListeners.add(fbDb.ref('companies/$companyCode/interStoreTransfers')
          .onChildChanged.listen((event) => _onTransferUpdate(event, companyCode)));
      _rtListeners.add(fbDb.ref('companies/$companyCode/branchAdjustments')
          .onChildAdded.listen((event) => _onAdjustmentBranchUpdate(event, companyCode)));
      _rtListeners.add(fbDb.ref('companies/$companyCode/branchAdjustments')
          .onChildChanged.listen((event) => _onAdjustmentBranchUpdate(event, companyCode)));

      // ═══ RECEIVED DELIVERY (all 3 statuses) ═══
      _rtListeners.add(fbDb.ref('companies/$companyCode/branchReceivedDelivery')
          .onChildAdded.listen((event) => _onDeliveryUpdate(event, companyCode, 'Approved')));
      _rtListeners.add(fbDb.ref('companies/$companyCode/branchReceivedDelivery')
          .onChildChanged.listen((event) => _onDeliveryUpdate(event, companyCode, 'Approved')));
      _rtListeners.add(fbDb.ref('companies/$companyCode/branchSubmittedDelivery')
          .onChildAdded.listen((event) => _onDeliveryUpdate(event, companyCode, 'Submitted')));
      _rtListeners.add(fbDb.ref('companies/$companyCode/branchSubmittedDelivery')
          .onChildChanged.listen((event) => _onDeliveryUpdate(event, companyCode, 'Submitted')));
      _rtListeners.add(fbDb.ref('companies/$companyCode/branchRejectedDelivery')
          .onChildAdded.listen((event) => _onDeliveryUpdate(event, companyCode, 'Rejected')));
      _rtListeners.add(fbDb.ref('companies/$companyCode/branchRejectedDelivery')
          .onChildChanged.listen((event) => _onDeliveryUpdate(event, companyCode, 'Rejected')));

      // ═══ BATCHES ═══
      // Nested: companies/{code}/batches/{branchId}/{batchId}
      _rtListeners.add(fbDb.ref('companies/$companyCode/batches')
          .onChildAdded.listen((event) => _onBatchBranchUpdate(event, companyCode)));
      _rtListeners.add(fbDb.ref('companies/$companyCode/batches')
          .onChildChanged.listen((event) => _onBatchBranchUpdate(event, companyCode)));
      // Handle deletes/removals for cross-device sync
      // Listen at BRANCH level so onChildRemoved fires per individual batch
      final batchAssign = await DeviceAssignmentService().read();
      final batchMyBranchId = (batchAssign['branchId'] ?? '').toString();
      if (batchMyBranchId.isNotEmpty) {
        _rtListeners.add(fbDb.ref('companies/$companyCode/batches/$batchMyBranchId')
            .onChildRemoved.listen((event) => _onBatchRemoved(event, companyCode, batchMyBranchId)));
        debugPrint('[SYNC-BATCH] Listening for deletes at branches/$batchMyBranchId');
      }
    }
  }

  Future<void> _onBranchUpdate(DatabaseEvent event, String companyCode) async {
    try {
      final val = event.snapshot.value;
      if (val is! Map) return;
      final m = val.map((k, v) => MapEntry(k.toString(), v));
      final id = (m['branchId'] ?? event.snapshot.key ?? '').toString();
      if (id.isEmpty) return;
      final db = await DatabaseHelper().database;
      // PRESERVE LOCAL PHOTO (branch-local imagePath, not synced from Firebase)
      final localPhotoRow = await db.query(
        "products", columns: ["imagePath"],
        where: "id = ?", whereArgs: [id], limit: 1,
      );
      final localImagePath = localPhotoRow.isNotEmpty
          ? localPhotoRow.first["imagePath"]
          : null;
      await db.insert(
        'branches',
        {
          'id': id,
          'name': (m['branchName'] ?? '').toString(),
          'address': (m['address'] ?? '').toString(),
          'phone': (m['phone'] ?? '').toString(),
          'isActive': (m['isActive'] == true) ? 1 : 1,
          'email': (m['email'] ?? '').toString(),
          'manager': (m['manager'] ?? '').toString(),
          'createdDate': (m['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
          "imagePath": localImagePath,
          'syncStatus': SyncStatus.synced,
          'lastSyncedAt': DateTime.now().toUtc().toIso8601String(),
          'firebaseId': id,
          'firebasePath': 'companies/$companyCode/branches/$id',
          'companyId': companyCode,
          'branchId_sync': id,
          'isDeleted': 0,
          'isMainBranch': (m['isMainBranch'] == true) ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await CacheReloadHelper.reloadAll();
      _showSnackBar?.call('🔄 Branch "${m['branchName']}" updated from cloud');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ branch realtime: $e');
    }
  }

  /// Handles real-time branchInventory updates from Firebase.
  /// Prevents sync loops by ignoring changes from THIS device.
  Future<void> _onInventoryUpdate(DatabaseEvent event, String companyCode, String branchId) async {
    try {
      final val = event.snapshot.value;
      if (val is! Map) return;
      final m = val.map((k, v) => MapEntry(k.toString(), v));
      final sku = (event.snapshot.key ?? '').toString();
      if (sku.isEmpty) return;

      // ═══ SYNC LOOP PREVENTION ═══
      // Skip updates that originated from THIS device
      final incomingDeviceId = (m['deviceId'] ?? '').toString();
      final myDeviceId = await DeviceIdService().getOrCreate();
      if (incomingDeviceId.isNotEmpty && incomingDeviceId == myDeviceId) {
        // Own change - already applied locally, no need to re-apply
        return;
      }

      // Update local SQLite from Firebase (from OTHER device)
      final db = await DatabaseHelper().database;
      await db.insert('branch_inventory', {
        'branchId': branchId,
        'productId': sku,
        'stockQty': (m['stockQty'] as num?)?.toInt() ?? 0,
        'reservedQty': (m['reservedQty'] as num?)?.toInt() ?? 0,
        'inTransitInQty': (m['inTransitInQty'] as num?)?.toInt() ?? 0,
        'inTransitOutQty': (m['inTransitOutQty'] as num?)?.toInt() ?? 0,
        'reorderLevel': (m['reorderLevel'] as num?)?.toInt() ?? 5,
        'lastUpdated': (m['lastUpdated'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'deviceId': incomingDeviceId,  // Preserve which device made the change
        'isDeleted': (m['isDeleted'] == true) ? 1 : 0,
        'isMigrated': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      if (kDebugMode) {
        debugPrint('[SYNC-INV] Updated $sku from device $incomingDeviceId (stock: ${m['stockQty']}) in branch $branchId');
      }

      // Show notification (throttled to avoid spam)
      _showSnackBar?.call('📦 Inventory synced from another device');
    } catch (e) {
      if (kDebugMode) debugPrint('[SYNC-INV] Error: $e');
    }
  }

  Future<void> _onUserUpdate(DatabaseEvent event, String branchId) async {
    try {
    // SKIP USER INSERT FROM LISTENER - prevents placeholder password overwrite
    // Real users are populated by:
    //   1. Join Existing Branch (saves real PIN)
    //   2. User Module Phase 3B cloud merge (preserves PIN)
    // This listener used to insert placeholder credentials that broke login
    return;
      final val = event.snapshot.value;
      if (val is! Map) return;
      final m = val.map((k, v) => MapEntry(k.toString(), v));
      final id = (m['userId'] ?? event.snapshot.key ?? '').toString();
      final username = (m['username'] ?? '').toString();
      if (id.isEmpty || username.isEmpty) return;
      final db = await DatabaseHelper().database;
      // Insert ONLY if missing locally; never overwrite local PIN
      final exists = await db.rawQuery(
          'SELECT id FROM users WHERE id = ? OR LOWER(username) = LOWER(?) LIMIT 1',
          [id, username]);
      if (exists.isNotEmpty) return;
      await db.insert('users', {
        'id': id,
        'username': username,
        'password': '__pending_setup__',
        'pin': '',
        'fullName': (m['fullName'] ?? '').toString(),
        'role': (m['role'] ?? 'Cashier').toString(),
        'branch': (m['branchName'] ?? '').toString(),
        'isActive': (m['isActive'] == true) ? 1 : 1,
        'dateCreated': (m['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
        'email': (m['email'] ?? '').toString(),
        'phone': (m['phone'] ?? '').toString(),
        'permissions': m['permissions'] is List
            ? jsonEncode(m['permissions'])
            : (m['permissions'] ?? '').toString(),
        'biometricEnabled': 0, 'biometricEnrolled': 0,
        'preferredBiometricType': 'face', 'lastBiometricVerifiedAt': null,
        'syncStatus': SyncStatus.synced,
        'lastSyncedAt': DateTime.now().toUtc().toIso8601String(),
        'firebaseId': id,
        'branchId_sync': branchId,
        'isDeleted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await CacheReloadHelper.reloadAll();
      _showSnackBar?.call('👤 User "$username" mirrored from cloud');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ user realtime: $e');
    }
  }

  // ═══════════════════ UI hook for snackbars ═══════════════════
  void Function(String msg)? _showSnackBar;
  void registerSnackBar(void Function(String) cb) {
    _showSnackBar = cb;
  }

  // ═══════════════════ Status helpers ═══════════════════
  void _updateStatus({
    bool? online,
    int? pendingCount,
    int? failedCount,
    bool? syncing,
    DateTime? lastSyncAt,
  }) {
    final cur = status.value;
    status.value = SyncStatusInfo(
      online: online ?? cur.online,
      pendingCount: pendingCount ?? cur.pendingCount,
      failedCount: failedCount ?? cur.failedCount,
      syncing: syncing ?? cur.syncing,
      lastSyncAt: lastSyncAt ?? cur.lastSyncAt,
    );
  }

  // ═══════════════════ PRODUCT real-time listeners ═══════════════════
  Future<void> _onProductUpdate(DatabaseEvent event, String companyCode) async {
    try {
      final val = event.snapshot.value;
      if (val is! Map) return;
      final m = val.map((k, v) => MapEntry(k.toString(), v));
      final id = (m['productId'] ?? event.snapshot.key ?? '').toString();
      if (id.isEmpty) return;
      final db = await DatabaseHelper().database;
      // 🛡️ PRESERVE LOCAL PHOTO (branch-local imagePath, never synced from Firebase)
      final preservePhoto = await db.query(
        "products", columns: ["imagePath"],
        where: "id = ?", whereArgs: [id], limit: 1,
      );
      final preservedImagePath = preservePhoto.isNotEmpty
          ? preservePhoto.first["imagePath"]
          : null;
      await db.insert(
        'products',
        {
          'id': id,
          'sku': (m['sku'] ?? '').toString(),
          'name': (m['name'] ?? '').toString(),
          'category': (m['category'] ?? '').toString(),
          'unit': (m['unit'] ?? 'pcs').toString(),
          'costPrice': (m['costPrice'] is num) ? (m['costPrice'] as num).toDouble() : 0.0,
          'sellingPrice': (m['sellingPrice'] is num) ? (m['sellingPrice'] as num).toDouble() : 0.0,
          'stockQty': (m['stockQty'] is num) ? (m['stockQty'] as num).toInt() : 0,
          'reorderLevel': (m['reorderLevel'] is num) ? (m['reorderLevel'] as num).toInt() : 5,
          'barcode': (m['barcode'] ?? '').toString(),
          'imagePath': preservedImagePath,
          'imageUrl': (m['imageUrl'] ?? '').toString(),
          'syncStatus': SyncStatus.synced,
          'lastSyncedAt': DateTime.now().toUtc().toIso8601String(),
          'firebaseId': id,
          'firebasePath': 'companies/$companyCode/products/$id',
          'companyId': companyCode,
          'isDeleted': (m['isDeleted'] == true) ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await CacheReloadHelper.reloadAll();
      _showSnackBar?.call('📦 Product "${m['name']}" updated from cloud');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ product realtime: $e');
    }
  }

  Future<void> _onProductDelete(DatabaseEvent event) async {
    try {
      final id = event.snapshot.key;
      if (id == null) return;
      final db = await DatabaseHelper().database;
      await db.delete('products', where: 'id = ?', whereArgs: [id]);
      await CacheReloadHelper.reloadAll();
      _showSnackBar?.call('🗑️ Product removed from cloud');
    } catch (_) {}
  }

  // ═══════════════════ SALES real-time listeners ═══════════════════
  Future<void> _onSaleUpdate(DatabaseEvent event, String companyCode, String branchId) async {
    try {
      final val = event.snapshot.value;
      if (val is! Map) return;
      final m = val.map((k, v) => MapEntry(k.toString(), v));
      final id = (m['txnId'] ?? event.snapshot.key ?? '').toString();
      if (id.isEmpty) return;

      // ═══ SYNC LOOP PREVENTION ═══
      // Skip transactions created by THIS device (already saved locally)
      // Same pattern as inventory sync
      final incomingDeviceId = (m['deviceId'] ?? '').toString();
      final myDeviceId = await DeviceIdService().getOrCreate();
      if (incomingDeviceId.isNotEmpty && incomingDeviceId == myDeviceId) {
        if (kDebugMode) debugPrint('[SYNC-SALE] Skip own transaction: $id');
        return;
      }

      // Also check if transaction already exists locally (double safety)
      final dbCheck = await DatabaseHelper().database;
      final existing = await dbCheck.query('transactions',
          where: 'id = ?', whereArgs: [id], limit: 1);
      if (existing.isNotEmpty) {
        // Already have this transaction (maybe from own device write)
        if (kDebugMode) debugPrint('[SYNC-SALE] Skip existing transaction: $id');
        return;
      }

      final db = await DatabaseHelper().database;

      // Insert transaction header
      await db.insert('transactions', {
        'id': id,
        'subtotal': (m['subtotal'] is num) ? (m['subtotal'] as num).toDouble() : 0.0,
        'totalDiscount': (m['totalDiscount'] is num) ? (m['totalDiscount'] as num).toDouble() : 0.0,
        'total': (m['total'] is num) ? (m['total'] as num).toDouble() : 0.0,
        'paymentMethod': (m['paymentMethod'] ?? 'Cash').toString(),
        'amountPaid': (m['amountPaid'] is num) ? (m['amountPaid'] as num).toDouble() : 0.0,
        'changeAmount': (m['change'] is num) ? (m['change'] as num).toDouble() : 0.0,
        'status': (m['status'] ?? 'completed').toString(),
        'cashier': (m['cashier'] ?? '').toString(),
        'branch': (m['branch'] ?? '').toString(),
        'voidReason': m['voidReason']?.toString(),
        'voidedBy': m['voidedBy']?.toString(),
        'voidedAt': m['voidedAt']?.toString(),
        'refundAmount': (m['refundAmount'] is num) ? (m['refundAmount'] as num).toDouble() : null,
        'dateTime': (m['dateTime'] ?? DateTime.now().toIso8601String()).toString(),
        'syncStatus': SyncStatus.synced,
        'lastSyncedAt': DateTime.now().toUtc().toIso8601String(),
        'firebaseId': id,
        'firebasePath': 'companies/$companyCode/sales/$branchId/$id',
        'companyId': companyCode,
        'branchId_sync': branchId,
        'isDeleted': (m['isDeleted'] == true) ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Insert items if present
      final itemsRaw = m['items'];
      if (itemsRaw is List) {
        // Clear old items for this txn first
        await db.delete('transaction_items', where: 'transactionId = ?', whereArgs: [id]);
        for (final item in itemsRaw) {
          if (item is Map) {
            final im = item.map((k, v) => MapEntry(k.toString(), v));
            await db.insert('transaction_items', {
              'transactionId': id,
              'name': (im['name'] ?? '').toString(),
              'sku': (im['sku'] ?? '').toString(),
              'qty': (im['qty'] is num) ? (im['qty'] as num).toInt() : 0,
              'price': (im['price'] is num) ? (im['price'] as num).toDouble() : 0.0,
              'discount': (im['discount'] is num) ? (im['discount'] as num).toDouble() : 0.0,
              'discountType': (im['discountType'] ?? 'fixed').toString(),
              'discountAmount': (im['discountAmount'] is num) ? (im['discountAmount'] as num).toDouble() : 0.0,
            });
          }
        }
      }

      await CacheReloadHelper.reloadAll();
      _showSnackBar?.call('💰 New sale from "${m['branch']}" — ₱${m['total']}');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ sale realtime: $e');
    }
  }

  Future<void> _onSaleDelete(DatabaseEvent event) async {
    try {
      final id = event.snapshot.key;
      if (id == null) return;
      final db = await DatabaseHelper().database;
      await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
      await db.delete('transaction_items', where: 'transactionId = ?', whereArgs: [id]);
      await CacheReloadHelper.reloadAll();
    } catch (_) {}
  }

  /// Head Office handler: branchId comes from the parent key in the tree
  Future<void> _onSaleBranchUpdate(DatabaseEvent event, String companyCode) async {
    try {
      // event.snapshot here is one branch's subtree (under sales/{branchId})
      final branchId = event.snapshot.key ?? '';
      if (branchId.isEmpty) return;
      final val = event.snapshot.value;
      if (val is! Map) return;
      final salesMap = val.map((k, v) => MapEntry(k.toString(), v));
      for (final entry in salesMap.entries) {
        if (entry.value is Map) {
          // Fake a DatabaseEvent-like update for each child
          final childSnap = await FirebaseRealtimeService.instance.db
              ?.ref('companies/$companyCode/sales/$branchId/${entry.key}').get();
          if (childSnap != null && childSnap.exists) {
            await _onSaleUpdate(
              _SyntheticEvent(childSnap),
              companyCode,
              branchId,
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ HO sale branch sync: $e');
    }
  }

  // ═══════════════════ BACKFILL (one-shot fetch on attach) ═══════════════════
  Future<void> _backfillAllSales(String companyCode) async {
    try {
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      final snap = await db.ref('companies/$companyCode/sales').get()
          .timeout(const Duration(seconds: 20));
      if (!snap.exists) return;
      final raw = snap.value;
      if (raw is! Map) return;
      final branches = raw.map((k, v) => MapEntry(k.toString(), v));
      int count = 0;
      for (final branchEntry in branches.entries) {
        final branchId = branchEntry.key;
        final salesMap = branchEntry.value;
        if (salesMap is! Map) continue;
        for (final saleEntry in salesMap.entries) {
          if (saleEntry.value is Map) {
            await _mirrorOneSale(saleEntry.value as Map, branchId, companyCode);
            count++;
          }
        }
      }
      if (kDebugMode) debugPrint('📥 HO backfill: $count sales pulled from cloud');
      await CacheReloadHelper.reloadAll();
      if (count > 0) {
        _showSnackBar?.call('📥 Pulled $count sale${count == 1 ? "" : "s"} from cloud');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ HO backfill error: $e');
    }
  }

  Future<void> _backfillBranchSales(String companyCode, String branchId) async {
    try {
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      final snap = await db.ref('companies/$companyCode/sales/$branchId').get()
          .timeout(const Duration(seconds: 20));
      if (!snap.exists) return;
      final raw = snap.value;
      if (raw is! Map) return;
      final salesMap = raw.map((k, v) => MapEntry(k.toString(), v));
      int count = 0;
      for (final entry in salesMap.entries) {
        if (entry.value is Map) {
          await _mirrorOneSale(entry.value as Map, branchId, companyCode);
          count++;
        }
      }
      if (kDebugMode) debugPrint('📥 Branch backfill: $count sales pulled');
      await CacheReloadHelper.reloadAll();
      if (count > 0) {
        _showSnackBar?.call('📥 Pulled $count sale${count == 1 ? "" : "s"} from cloud');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ branch backfill error: $e');
    }
  }


  // ═══════════════════ v156: HOLD TRANSACTIONS (real-time multi-device sync) ═══════════════════
  Future<void> _backfillHeldTransactions(String companyCode) async {
    try {
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      
      // v156: Today-only filter - fetch only records with heldAt >= today midnight
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayStartIso = todayStart.toIso8601String();
      
      final snap = await db.ref('companies/$companyCode/holdTransactions')
          .orderByChild('heldAt')
          .startAt(todayStartIso)
          .get()
          .timeout(const Duration(seconds: 20));
      
      if (!snap.exists) return;
      final raw = snap.value;
      if (raw is! Map) return;
      final holdsMap = raw.map((k, v) => MapEntry(k.toString(), v));
      
      int count = 0;
      int skipped = 0;
      for (final entry in holdsMap.entries) {
        if (entry.value is! Map) continue;
        final data = (entry.value as Map).map((k, v) => MapEntry(k.toString(), v));
        
        // Double-check filters (belt + suspenders)
        final status = (data['status'] ?? '').toString();
        if (status != 'HOLD') { skipped++; continue; }
        
        final heldAtStr = (data['heldAt'] ?? '').toString();
        final heldAt = DateTime.tryParse(heldAtStr);
        if (heldAt == null || heldAt.isBefore(todayStart)) { skipped++; continue; }
        
        await _upsertHeldTransaction(entry.key, data);
        count++;
      }
      if (kDebugMode) debugPrint('[v156] Backfill: $count synced, $skipped skipped (today-only filter)');
      if (count > 0) {
        _showSnackBar?.call('📥 Pulled $count active hold${count == 1 ? "" : "s"} from cloud');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[v156] Backfill error: $e');
    }
  }

  Future<void> _onHeldTransactionUpdate(DatabaseEvent event, String companyCode) async {
    try {
      final data = event.snapshot.value;
      if (data == null) return;
      if (data is! Map) return;
      
      final map = (data).map((k, v) => MapEntry(k.toString(), v));
      final holdId = event.snapshot.key ?? '';
      if (holdId.isEmpty) return;
      
      final status = (map['status'] ?? '').toString();
      
      // Status changed to COMPLETED/CANCELLED/EXPIRED - just update local
      if (status != 'HOLD') {
        await _updateHeldStatus(holdId, status, map);
        return;
      }
      
      // Today-only filter for new HOLDs
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final heldAt = DateTime.tryParse((map['heldAt'] ?? '').toString());
      if (heldAt == null || heldAt.isBefore(todayStart)) {
        if (kDebugMode) debugPrint('[v156] Ignoring old hold: $holdId');
        return;
      }
      
      await _upsertHeldTransaction(holdId, map);
      if (kDebugMode) debugPrint('[v156] Synced hold: $holdId');
    } catch (e) {
      if (kDebugMode) debugPrint('[v156] Update error: $e');
    }
  }

  Future<void> _upsertHeldTransaction(String id, Map<String, dynamic> data) async {
    try {
      final db = await DatabaseHelper().database;
      await db.insert('held_transactions', {
        'id': id,
        'heldNumber': (data['heldNumber'] ?? '').toString(),
        'branch': (data['branch'] ?? '').toString(),
        'cashierId': (data['cashierId'] ?? '').toString(),
        'cashierName': (data['cashierName'] ?? '').toString(),
        'customerName': (data['customerName'] ?? '').toString(),
        'note': (data['note'] ?? '').toString(),
        'itemsJson': (data['itemsJson'] ?? '[]').toString(),
        'subtotal': (data['subtotal'] as num?)?.toDouble() ?? 0,
        'totalDiscount': (data['totalDiscount'] as num?)?.toDouble() ?? 0,
        'total': (data['total'] as num?)?.toDouble() ?? 0,
        'heldAt': (data['heldAt'] ?? '').toString(),
        'status': 'HOLD',
        'shiftId': (data['shiftId'] ?? '').toString(),
        'completedAt': (data['completedAt'] ?? '').toString(),
        'completedBy': (data['completedBy'] ?? '').toString(),
        'cancelledAt': (data['cancelledAt'] ?? '').toString(),
        'cancelledBy': (data['cancelledBy'] ?? '').toString(),
        'cancelReason': (data['cancelReason'] ?? '').toString(),
        'expiredAt': (data['expiredAt'] ?? '').toString(),
        'salesTransactionId': (data['salesTransactionId'] ?? '').toString(),
        'deviceId': (data['deviceId'] ?? '').toString(),
        'modifiedAt': (data['modifiedAt'] ?? '').toString(),
        'modifiedBy': (data['modifiedBy'] ?? '').toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      if (kDebugMode) debugPrint('[v156] Upsert failed: $e');
    }
  }

  Future<void> _updateHeldStatus(String id, String newStatus, Map<String, dynamic> data) async {
    try {
      final db = await DatabaseHelper().database;
      await db.update('held_transactions', {
        'status': newStatus,
        'completedAt': (data['completedAt'] ?? '').toString(),
        'completedBy': (data['completedBy'] ?? '').toString(),
        'cancelledAt': (data['cancelledAt'] ?? '').toString(),
        'cancelledBy': (data['cancelledBy'] ?? '').toString(),
        'cancelReason': (data['cancelReason'] ?? '').toString(),
        'expiredAt': (data['expiredAt'] ?? '').toString(),
        'salesTransactionId': (data['salesTransactionId'] ?? '').toString(),
        'modifiedAt': DateTime.now().toIso8601String(),
      }, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      if (kDebugMode) debugPrint('[v156] Status update failed: $e');
    }
  }

  Future<void> _mirrorOneSale(Map raw, String branchId, String companyCode) async {
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final id = (m['txnId'] ?? '').toString();
    if (id.isEmpty) return;
    final db = await DatabaseHelper().database;
    await db.insert('transactions', {
      'id': id,
      'subtotal': (m['subtotal'] is num) ? (m['subtotal'] as num).toDouble() : 0.0,
      'totalDiscount': (m['totalDiscount'] is num) ? (m['totalDiscount'] as num).toDouble() : 0.0,
      'total': (m['total'] is num) ? (m['total'] as num).toDouble() : 0.0,
      'paymentMethod': (m['paymentMethod'] ?? 'Cash').toString(),
      'amountPaid': (m['amountPaid'] is num) ? (m['amountPaid'] as num).toDouble() : 0.0,
      'changeAmount': (m['change'] is num) ? (m['change'] as num).toDouble() : 0.0,
      'status': (m['status'] ?? 'completed').toString(),
      'cashier': (m['cashier'] ?? '').toString(),
      'branch': (m['branch'] ?? '').toString(),
      'voidReason': m['voidReason']?.toString(),
      'voidedBy': m['voidedBy']?.toString(),
      'voidedAt': m['voidedAt']?.toString(),
      'refundAmount': (m['refundAmount'] is num) ? (m['refundAmount'] as num).toDouble() : null,
      'dateTime': (m['dateTime'] ?? DateTime.now().toIso8601String()).toString(),
      'syncStatus': SyncStatus.synced,
      'lastSyncedAt': DateTime.now().toUtc().toIso8601String(),
      'firebaseId': id,
      'firebasePath': 'companies/$companyCode/sales/$branchId/$id',
      'companyId': companyCode,
      'branchId_sync': branchId,
      'isDeleted': (m['isDeleted'] == true) ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final itemsRaw = m['items'];
    if (itemsRaw is List) {
      await db.delete('transaction_items', where: 'transactionId = ?', whereArgs: [id]);
      for (final item in itemsRaw) {
        if (item is Map) {
          final im = item.map((k, v) => MapEntry(k.toString(), v));
          await db.insert('transaction_items', {
            'transactionId': id,
            'name': (im['name'] ?? '').toString(),
            'sku': (im['sku'] ?? '').toString(),
            'qty': (im['qty'] is num) ? (im['qty'] as num).toInt() : 0,
            'price': (im['price'] is num) ? (im['price'] as num).toDouble() : 0.0,
            'discount': (im['discount'] is num) ? (im['discount'] as num).toDouble() : 0.0,
            'discountType': (im['discountType'] ?? 'fixed').toString(),
            'discountAmount': (im['discountAmount'] is num) ? (im['discountAmount'] as num).toDouble() : 0.0,
          });
        }
      }
    }
  }

  // ═══════════════════ PRODUCTS BACKFILL (one-shot on attach) ═══════════════════
  Future<void> _backfillProducts(String companyCode) async {
    try {
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      final snap = await db.ref('companies/$companyCode/products').get()
          .timeout(const Duration(seconds: 20));
      if (!snap.exists) return;
      final raw = snap.value;
      if (raw is! Map) return;
      final products = raw.map((k, v) => MapEntry(k.toString(), v));
      int count = 0;
      final sqliteDb = await DatabaseHelper().database;
      for (final entry in products.entries) {
        if (entry.value is! Map) continue;
        final m = (entry.value as Map).map((k, v) => MapEntry(k.toString(), v));
        final id = (m['productId'] ?? entry.key ?? '').toString();
        if (id.isEmpty) continue;
        // 🛡️ PRESERVE LOCAL PHOTO (branch-local imagePath)
        final existingPhoto = await sqliteDb.query(
          "products", columns: ["imagePath"],
          where: "id = ?", whereArgs: [id], limit: 1,
        );
        final localPhoto = existingPhoto.isNotEmpty
            ? existingPhoto.first["imagePath"]
            : null;
        await sqliteDb.insert(
          'products',
          {
            'id': id,
            'sku': (m['sku'] ?? '').toString(),
            'name': (m['name'] ?? '').toString(),
            'category': (m['category'] ?? '').toString(),
            'unit': (m['unit'] ?? 'pcs').toString(),
            'costPrice': (m['costPrice'] is num) ? (m['costPrice'] as num).toDouble() : 0.0,
            'sellingPrice': (m['sellingPrice'] is num) ? (m['sellingPrice'] as num).toDouble() : 0.0,
            'stockQty': (m['stockQty'] is num) ? (m['stockQty'] as num).toInt() : 0,
            'reorderLevel': (m['reorderLevel'] is num) ? (m['reorderLevel'] as num).toInt() : 5,
            'barcode': (m['barcode'] ?? '').toString(),
            'imagePath': localPhoto,
            'imageUrl': (m['imageUrl'] ?? '').toString(),
            'syncStatus': SyncStatus.synced,
            'lastSyncedAt': DateTime.now().toUtc().toIso8601String(),
            'firebaseId': id,
            'firebasePath': 'companies/$companyCode/products/$id',
            'companyId': companyCode,
            'isDeleted': (m['isDeleted'] == true) ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }
      if (kDebugMode) debugPrint('📥 Product backfill: $count products pulled from cloud');
      await CacheReloadHelper.reloadAll();
      if (count > 0) {
        _showSnackBar?.call('📥 Pulled $count product${count == 1 ? "" : "s"} from cloud');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ product backfill error: $e');
    }
  }

  // ═══════════════════ Z REPORT real-time listeners ═══════════════════
  Future<void> _onZReportUpdate(DatabaseEvent event, String companyCode, String branchId) async {
    try {
      final val = event.snapshot.value;
      if (val is! Map) return;
      final m = val.map((k, v) => MapEntry(k.toString(), v));
      await _mirrorOneZReport(m, branchId, companyCode);
      _showSnackBar?.call('📊 New Z Report from "${m['branch']}" — ₱${m['netSales']}');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Z Report realtime: $e');
    }
  }

  Future<void> _onZReportBranchUpdate(DatabaseEvent event, String companyCode) async {
    try {
      final branchId = event.snapshot.key ?? '';
      if (branchId.isEmpty) return;
      final val = event.snapshot.value;
      if (val is! Map) return;
      final reportsMap = val.map((k, v) => MapEntry(k.toString(), v));
      for (final entry in reportsMap.entries) {
        if (entry.value is Map) {
          final m = (entry.value as Map).map((k, v) => MapEntry(k.toString(), v));
          await _mirrorOneZReport(m, branchId, companyCode);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ HO Z Report sync: $e');
    }
  }

  Future<void> _mirrorOneZReport(Map<String, dynamic> m, String branchId, String companyCode) async {
    final id = (m['reportId'] ?? '').toString();
    if (id.isEmpty) return;
    final db = await DatabaseHelper().database;
    await db.insert('z_reports', {
      'reportId': id,
      'reportDate': (m['reportDate'] ?? DateTime.now().toIso8601String()).toString(),
      'generatedAt': (m['generatedAt'] ?? DateTime.now().toIso8601String()).toString(),
      'branch': (m['branch'] ?? '').toString(),
      'cashier': (m['cashier'] ?? '').toString(),
      'grossSales': (m['grossSales'] is num) ? (m['grossSales'] as num).toDouble() : 0.0,
      'totalDiscount': (m['totalDiscount'] is num) ? (m['totalDiscount'] as num).toDouble() : 0.0,
      'netSales': (m['netSales'] is num) ? (m['netSales'] as num).toDouble() : 0.0,
      'totalTransactions': (m['totalTransactions'] is num) ? (m['totalTransactions'] as num).toInt() : 0,
      'averageTransaction': (m['averageTransaction'] is num) ? (m['averageTransaction'] as num).toDouble() : 0.0,
      'paymentBreakdownJson': (m['paymentBreakdownJson'] ?? '').toString(),
      'voidedCount': (m['voidedCount'] is num) ? (m['voidedCount'] as num).toInt() : 0,
      'voidedAmount': (m['voidedAmount'] is num) ? (m['voidedAmount'] as num).toDouble() : 0.0,
      'voidedTransactionsJson': (m['voidedTransactionsJson'] ?? '').toString(),
      'beginningCash': (m['beginningCash'] is num) ? (m['beginningCash'] as num).toDouble() : 0.0,
      'endingCash': (m['endingCash'] is num) ? (m['endingCash'] as num).toDouble() : 0.0,
      'expectedCash': (m['expectedCash'] is num) ? (m['expectedCash'] as num).toDouble() : 0.0,
      'overShort': (m['overShort'] is num) ? (m['overShort'] as num).toDouble() : 0.0,
      'refundedCount': (m['refundedCount'] is num) ? (m['refundedCount'] as num).toInt() : 0,
      'refundedAmount': (m['refundedAmount'] is num) ? (m['refundedAmount'] as num).toDouble() : 0.0,
      'allTransactionsJson': (m['allTransactionsJson'] ?? '').toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _backfillAllZReports(String companyCode) async {
    try {
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      final snap = await db.ref('companies/$companyCode/zReports').get()
          .timeout(const Duration(seconds: 20));
      if (!snap.exists) return;
      final raw = snap.value;
      if (raw is! Map) return;
      final branches = raw.map((k, v) => MapEntry(k.toString(), v));
      int count = 0;
      for (final branchEntry in branches.entries) {
        final branchId = branchEntry.key;
        final reportsMap = branchEntry.value;
        if (reportsMap is! Map) continue;
        for (final reportEntry in reportsMap.entries) {
          if (reportEntry.value is Map) {
            final m = (reportEntry.value as Map).map((k, v) => MapEntry(k.toString(), v));
            await _mirrorOneZReport(m, branchId, companyCode);
            count++;
          }
        }
      }
      if (count > 0) _showSnackBar?.call('📥 Pulled $count Z Report${count == 1 ? "" : "s"} from cloud');
      if (kDebugMode) debugPrint('📥 HO Z Report backfill: $count pulled');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Z Report backfill error: $e');
    }
  }

  Future<void> _backfillBranchZReports(String companyCode, String branchId) async {
    try {
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return;
      final snap = await db.ref('companies/$companyCode/zReports/$branchId').get()
          .timeout(const Duration(seconds: 20));
      if (!snap.exists) return;
      final raw = snap.value;
      if (raw is! Map) return;
      final reportsMap = raw.map((k, v) => MapEntry(k.toString(), v));
      int count = 0;
      for (final entry in reportsMap.entries) {
        if (entry.value is Map) {
          final m = (entry.value as Map).map((k, v) => MapEntry(k.toString(), v));
          await _mirrorOneZReport(m, branchId, companyCode);
          count++;
        }
      }
      if (count > 0) _showSnackBar?.call('📥 Pulled $count Z Report${count == 1 ? "" : "s"} from cloud');
      if (kDebugMode) debugPrint('📥 Branch Z Report backfill: $count pulled');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Branch Z Report backfill error: $e');
    }
  }

  // ═══ TRANSFER SYNC HANDLER ═══
  Future<void> _onTransferUpdate(DatabaseEvent event, String companyCode) async {
    try {
      final val = event.snapshot.value;
      if (val is! Map) return;
      final m = val.map((k, v) => MapEntry(k.toString(), v));
      final transferId = (event.snapshot.key ?? '').toString();
      if (transferId.isEmpty) return;

      final incomingDeviceId = (m['deviceId'] ?? '').toString();
      final myDeviceId = await DeviceIdService().getOrCreate();
      if (incomingDeviceId.isNotEmpty && incomingDeviceId == myDeviceId) return;

      final db = await DatabaseHelper().database;
      await db.insert('interstore_transfers_v3', {
        'transfer_id': transferId,
        'doc_number': (m['docNumber'] ?? '').toString(),
        'status': (m['status'] ?? 'DRAFT').toString(),
        'issuing_branch_id': (m['issuingBranchId'] ?? '').toString(),
        'issuing_branch_name': (m['issuingBranchName'] ?? '').toString(),
        'receiving_branch_id': (m['receivingBranchId'] ?? '').toString(),
        'receiving_branch_name': (m['receivingBranchName'] ?? '').toString(),
        'prepared_by': (m['preparedBy'] ?? '').toString(),
        'prepared_by_id': (m['preparedById'] ?? '').toString(),
        'prepared_date': (m['preparedDate'] ?? '').toString(),
        'submitted_by': (m['submittedBy'] ?? '').toString(),
        'submitted_date': (m['submittedDate'] ?? '').toString(),
        'approved_by': (m['approvedBy'] ?? '').toString(),
        'approved_by_pin': (m['approvedByPin'] ?? '').toString(),
        'approved_by_role': (m['approvedByRole'] ?? '').toString(),
        'approved_date': (m['approvedDate'] ?? '').toString(),
        'dispatched_by': (m['dispatchedBy'] ?? '').toString(),
        'dispatched_date': (m['dispatchedDate'] ?? '').toString(),
        'received_by': (m['receivedBy'] ?? '').toString(),
        'received_by_pin': (m['receivedByPin'] ?? '').toString(),
        'received_date': (m['receivedDate'] ?? '').toString(),
        'total_items': (m['totalItems'] as num?)?.toInt() ?? 0,
        'total_issued_qty': (m['totalIssuedQty'] as num?)?.toInt() ?? 0,
        'total_received_qty': (m['totalReceivedQty'] as num?)?.toInt() ?? 0,
        'total_floating_qty': (m['totalFloatingQty'] as num?)?.toInt() ?? 0,
        'total_short_qty': (m['totalShortQty'] as num?)?.toInt() ?? 0,
        'total_cost': (m['totalCost'] as num?)?.toDouble() ?? 0,
        'notes': (m['notes'] ?? '').toString(),
        'sync_status': 'SYNCED',
        'created_at': (m['createdAt'] ?? m['preparedDate'] ?? '').toString(),
        'updated_at': (m['updatedAt'] ?? '').toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // v1.0.57+107 — Handle items array-as-Map from Firebase
      final rawItems = m['items'];
      final items = rawItems is List
          ? rawItems
          : rawItems is Map
              ? (rawItems).values.toList()
              : <dynamic>[];
      if (items.isNotEmpty) {
        await db.delete('interstore_transfer_items_v3',
            where: 'transfer_id = ?', whereArgs: [transferId]);
        for (final item in items) {
          if (item is Map) {
            final im = item.map((k, v) => MapEntry(k.toString(), v));
            await db.insert('interstore_transfer_items_v3', {
              'transfer_id': transferId,
              'product_id': (im['productId'] ?? '').toString(),
              'sku': (im['sku'] ?? '').toString(),
              'product_name': (im['productName'] ?? '').toString(),
              'category': (im['category'] ?? '').toString(),
              'issued_qty': (im['issuedQty'] as num?)?.toInt() ?? 0,
              'received_qty': (im['receivedQty'] as num?)?.toInt() ?? 0,
              'short_qty': (im['shortQty'] as num?)?.toInt() ?? 0,
              'unit_cost': (im['unitCost'] as num?)?.toDouble() ?? 0,
              'created_at': (im['createdAt'] ?? '').toString(),
            });
          }
        }
      }

      // v1.0.53/57 — Sync batches from Firebase (handles both List and Map form)
      try {
        final rawBatches = m['batches'];
        // v1.0.57+107 — Firebase sometimes returns arrays as Map with numeric keys
        final batches = rawBatches is List
            ? rawBatches
            : rawBatches is Map
                ? (rawBatches).values.toList()
                : <dynamic>[];
        if (batches.isNotEmpty) {
          await db.execute("CREATE TABLE IF NOT EXISTS transfer_item_batches (id INTEGER PRIMARY KEY AUTOINCREMENT, transferId TEXT NOT NULL, productId TEXT NOT NULL, batchId TEXT NOT NULL, batchNumber TEXT DEFAULT '', lotNumber TEXT DEFAULT '', mfgDate TEXT DEFAULT '', expiryDate TEXT DEFAULT '', transferQty INTEGER DEFAULT 0, unitCost REAL DEFAULT 0, receivedQty INTEGER DEFAULT 0, postbackQty INTEGER DEFAULT 0, shortReason TEXT DEFAULT '', varianceNotes TEXT DEFAULT '')");
          // v1.0.56/57 — safe migrations for existing DBs
          try { await db.execute("ALTER TABLE transfer_item_batches ADD COLUMN receivedQty INTEGER DEFAULT 0"); } catch (_) {}
          try { await db.execute("ALTER TABLE transfer_item_batches ADD COLUMN postbackQty INTEGER DEFAULT 0"); } catch (_) {}
          try { await db.execute("ALTER TABLE transfer_item_batches ADD COLUMN shortReason TEXT DEFAULT ''"); } catch (_) {}
          try { await db.execute("ALTER TABLE transfer_item_batches ADD COLUMN varianceNotes TEXT DEFAULT ''"); } catch (_) {}
          await db.delete('transfer_item_batches',
              where: 'transferId = ?', whereArgs: [transferId]);
          for (final b in batches) {
            if (b is Map) {
              final bm = b.map((k, v) => MapEntry(k.toString(), v));
              await db.insert('transfer_item_batches', {
                'transferId': transferId,
                'productId': (bm['productId'] ?? '').toString(),
                'batchId': (bm['batchId'] ?? '').toString(),
                'batchNumber': (bm['batchNumber'] ?? '').toString(),
                'lotNumber': (bm['lotNumber'] ?? '').toString(),
                'mfgDate': (bm['mfgDate'] ?? '').toString(),
                'expiryDate': (bm['expiryDate'] ?? '').toString(),
                'transferQty': (bm['transferQty'] as num?)?.toInt() ?? 0,
                'unitCost': (bm['unitCost'] as num?)?.toDouble() ?? 0,
                'receivedQty': (bm['receivedQty'] as num?)?.toInt() ?? 0,
                'postbackQty': (bm['postbackQty'] as num?)?.toInt() ?? 0,
                'shortReason': (bm['shortReason'] ?? '').toString(),
                'varianceNotes': (bm['varianceNotes'] ?? '').toString(),
              });
            }
          }
          if (kDebugMode) debugPrint('[SYNC-BATCHES] Synced ${batches.length} batches for $transferId (form: ${rawBatches.runtimeType})');
        } else {
          if (kDebugMode) debugPrint('[SYNC-BATCHES] No batches for $transferId (raw type: ${rawBatches?.runtimeType})');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[SYNC-BATCHES] Error: $e');
      }

      if (kDebugMode) debugPrint('[SYNC-TRANSFER] $transferId synced');
      _showSnackBar?.call('🔄 Transfer synced from another device');
    } catch (e) {
      if (kDebugMode) debugPrint('[SYNC-TRANSFER] Error: $e');
    }
  }

  // ═══ ADJUSTMENT SYNC HANDLER ═══
  Future<void> _onAdjustmentBranchUpdate(DatabaseEvent event, String companyCode) async {
    try {
      final val = event.snapshot.value;
      if (val is! Map) return;
      final branchId = (event.snapshot.key ?? '').toString();
      if (branchId.isEmpty) return;

      for (final entry in val.entries) {
        final adjustmentId = entry.key.toString();
        final adjData = entry.value;
        if (adjData is! Map) continue;
        final m = adjData.map((k, v) => MapEntry(k.toString(), v));

        final incomingDeviceId = (m['deviceId'] ?? '').toString();
        final myDeviceId = await DeviceIdService().getOrCreate();
        if (incomingDeviceId.isNotEmpty && incomingDeviceId == myDeviceId) continue;

        final db = await DatabaseHelper().database;
        await db.insert('adjustments_v3', {
          'adjustment_id': adjustmentId,
          'doc_number': (m['docNumber'] ?? '').toString(),
          'status': (m['status'] ?? 'APPROVED').toString(),
          'branch_code': branchId,
          'branch_name': (m['branchName'] ?? '').toString(),
          'created_by_name': (m['preparedBy'] ?? '').toString(),
          'submitted_by': (m['submittedBy'] ?? '').toString(),
          'submitted_at': (m['submittedDate'] ?? '').toString(),
          'approved_by': (m['approvedBy'] ?? '').toString(),
          'approved_by_pin': (m['approvedByPin'] ?? '').toString(),
          'approved_by_role': (m['approvedByRole'] ?? '').toString(),
          'approved_at': (m['approvedDate'] ?? '').toString(),
          'total_items': (m['totalItems'] as num?)?.toInt() ?? 0,
          'notes': (m['notes'] ?? '').toString(),
          'sync_status': 'SYNCED',
          'created_at': (m['preparedDate'] ?? '').toString(),
          'updated_at': (m['lastEditedDate'] ?? '').toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        if (kDebugMode) debugPrint('[SYNC-ADJ] $adjustmentId synced');
      }

      _showSnackBar?.call('🔄 Adjustment synced from another device');
    } catch (e) {
      if (kDebugMode) debugPrint('[SYNC-ADJ] Error: $e');
    }
  }


  // ═══ DELIVERY SYNC HANDLER ═══
  Future<void> _onDeliveryUpdate(
    DatabaseEvent event,
    String companyCode,
    String status,
  ) async {
    try {
      final val = event.snapshot.value;
      if (kDebugMode) {
        debugPrint('[SYNC-DELIV] Event fired: status=$status, key=${event.snapshot.key}, valueType=${val.runtimeType}');
      }
      if (val is! Map) return;
      final branchId = (event.snapshot.key ?? '').toString();
      if (branchId.isEmpty) return;

      for (final entry in val.entries) {
        final deliveryId = entry.key.toString();
        final delivData = entry.value;
        if (delivData is! Map) continue;
        final m = delivData.map((k, v) => MapEntry(k.toString(), v));

        // Sync loop prevention
        final incomingDeviceId = (m['deviceId'] ?? '').toString();
        final myDeviceId = await DeviceIdService().getOrCreate();
        if (incomingDeviceId.isNotEmpty && incomingDeviceId == myDeviceId) {
          continue;
        }

        final db = await DatabaseHelper().database;

        try {
          if (kDebugMode) {
            debugPrint('[SYNC-DELIV] Upserting $deliveryId (branch=$branchId, status=$status)');
          }
          await db.insert('delivery_records', {
            'id': deliveryId,
            'refNumber': (m['refNumber'] ?? '').toString(),
            'supplier': (m['supplier'] ?? '').toString(),
            'driverName': (m['driverName'] ?? '').toString(),
            'plateNumber': (m['plateNumber'] ?? '').toString(),
            'receivedBy': (m['receivedBy'] ?? '').toString(),
            'notes': (m['notes'] ?? '').toString(),
            'totalItems': (m['totalItems'] as num?)?.toInt() ?? 0,
            'totalQuantity': (m['totalQuantity'] as num?)?.toInt() ?? 0,
            'totalCost': (m['totalCost'] as num?)?.toDouble() ?? 0.0,
            'totalRetail': (m['totalRetail'] as num?)?.toDouble() ?? 0.0,
            'dateTime': (m['dateTime'] ?? m['dateReceived'] ?? m['date'] ?? DateTime.now().toIso8601String()).toString(),
            'branchId': branchId,
            'branchName': (m['branchName'] ?? '').toString(),
            'status': (m['status'] ?? status).toString(),
            'submittedDate': (m['submittedDate'] ?? '').toString(),
            'submittedBy': (m['submittedBy'] ?? '').toString(),
            'approvedDate': (m['approvedDate'] ?? '').toString(),
            'approvedBy': (m['approvedBy'] ?? '').toString(),
            'rejectedDate': (m['rejectedDate'] ?? '').toString(),
            'rejectedBy': (m['rejectedBy'] ?? '').toString(),
            'rejectionReason': (m['rejectionReason'] ?? '').toString(),
            'lastEditedDate': (m['lastEditedDate'] ?? '').toString(),
            'syncStatus': 'Synced',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (e) {
          if (kDebugMode) debugPrint('[SYNC-DELIV] Insert error: $e');
        }

        // Sync line items
        final items = m['items'];
        if (items is List) {
          try {
            await db.delete('delivery_items',
                where: 'deliveryId = ?', whereArgs: [deliveryId]);
            for (final item in items) {
              if (item is Map) {
                final im = item.map((k, v) => MapEntry(k.toString(), v));
                await db.insert('delivery_items', {
                  'deliveryId': deliveryId,
                  'productId': (im['productId'] ?? '').toString(),
                  'sku': (im['sku'] ?? '').toString(),
                  'itemName': (im['itemName'] ?? im['productName'] ?? '').toString(),
                  'quantity': (im['quantity'] as num?)?.toInt() ?? 0,
                  'oldStock': (im['oldStock'] as num?)?.toInt() ?? 0,
                  'newStock': (im['newStock'] as num?)?.toInt() ?? 0,
                  'cost': (im['cost'] ?? im['unitCost'] as num?)?.toDouble() ?? 0.0,
                  'retail': (im['retail'] ?? im['unitRetail'] as num?)?.toDouble() ?? 0.0,
                  'batchNumber': (im['batchNumber'] ?? '').toString(),
                  'lotNumber': (im['lotNumber'] ?? '').toString(),
                  'mfgDate': (im['mfgDate'] ?? '').toString(),
                  'expDate': (im['expDate'] ?? '').toString(),
                });
              }
            }
          } catch (e) {
            if (kDebugMode) debugPrint('[SYNC-DELIV] Items error: $e');
          }
        }

        if (kDebugMode) {
          debugPrint('[SYNC-DELIV] $deliveryId synced ($status)');
        }
      }

      _showSnackBar?.call('📦 Delivery synced from another device');
    } catch (e) {
      if (kDebugMode) debugPrint('[SYNC-DELIV] Error: $e');
    }
  }

  // ═══ BATCHES SYNC HANDLER (Nested: branchId/batchId) ═══
  Future<void> _onBatchBranchUpdate(DatabaseEvent event, String companyCode) async {
    try {
      final val = event.snapshot.value;
      if (val is! Map) return;
      final branchId = (event.snapshot.key ?? '').toString();
      if (branchId.isEmpty) return;

      // Get current device branchId to filter
      final assign = await DeviceAssignmentService().read();
      final myBranchId = (assign['branchId'] ?? '').toString();
      
      // Skip batches from other branches (per-branch scoping)
      if (myBranchId.isNotEmpty && myBranchId != branchId) {
        return;
      }

      for (final entry in val.entries) {
        final batchId = entry.key.toString();
        final batchData = entry.value;
        if (batchData is! Map) continue;
        final m = batchData.map((k, v) => MapEntry(k.toString(), v));

        // Sync loop prevention
        final incomingDeviceId = (m['deviceId'] ?? '').toString();
        final myDeviceId = await DeviceIdService().getOrCreate();
        if (incomingDeviceId.isNotEmpty && incomingDeviceId == myDeviceId) continue;

        final db = await DatabaseHelper().database;
        final now = DateTime.now().toIso8601String();

        try {
          await db.insert('batches', {
            'id': batchId,
            'productId': (m['productId'] ?? '').toString(),
            'productName': (m['productName'] ?? '').toString(),
            'productSku': (m['productSku'] ?? '').toString(),
            'batchNumber': (m['batchNumber'] ?? '').toString(),
            'lotNumber': (m['lotNumber'] ?? '').toString(),
            'manufacturedDate': (m['manufacturedDate'] ?? '').toString(),
            'expiryDate': (m['expiryDate'] ?? '').toString(),
            'quantity': (m['quantity'] as num?)?.toInt() ?? 0,
            'originalQty': (m['originalQty'] as num?)?.toInt() ?? 0,
            'costPrice': (m['costPrice'] as num?)?.toDouble() ?? 0.0,
            'supplier': (m['supplier'] ?? '').toString(),
            'notes': (m['notes'] ?? '').toString(),
            'branchId': branchId,
            'branchName': (m['branchName'] ?? '').toString(),
            'source': (m['source'] ?? 'MANUAL').toString(),
            'sourceDocId': (m['sourceDocId'] ?? '').toString(),
            'status': (m['status'] ?? 'ACTIVE').toString(),
            'deviceId': incomingDeviceId,
            'dateAdded': (m['dateAdded'] ?? now).toString(),
            'updatedAt': (m['updatedAt'] ?? now).toString(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          
          debugPrint('[SYNC-BATCH] $batchId synced (branch=$branchId)');
        } catch (e) {
          debugPrint('[SYNC-BATCH] Insert error: $e');
        }
      }

      _showSnackBar?.call('📦 Batch synced from another device');
    } catch (e) {
      if (kDebugMode) debugPrint('[SYNC-BATCH] Error: $e');
    }
  }

  // ═══ BATCH REMOVE HANDLER (Individual Batch Delete) ═══
  // Fires when a specific batch is removed from Firebase
  Future<void> _onBatchRemoved(DatabaseEvent event, String companyCode, String branchId) async {
    try {
      final batchId = (event.snapshot.key ?? '').toString();
      if (batchId.isEmpty) return;

      debugPrint('[SYNC-BATCH-DEL] Individual batch removed: $batchId (branch=$branchId)');

      final db = await DatabaseHelper().database;
      try {
        await db.delete('batches', where: 'id = ?', whereArgs: [batchId]);
        debugPrint('[SYNC-BATCH-DEL] ✅ Removed $batchId from local SQLite');
        
        // Also remove from in-memory cache
        // (Force refresh on next load)
      } catch (e) {
        debugPrint('[SYNC-BATCH-DEL] Delete error: $e');
      }

      _showSnackBar?.call('🗑️ Batch removed from another device');
    } catch (e) {
      if (kDebugMode) debugPrint('[SYNC-BATCH-DEL] Error: $e');
    }
  }
}
class SyncStatusInfo {
  final bool online;
  final int pendingCount;
  final int failedCount;
  final bool syncing;
  final DateTime? lastSyncAt;
  const SyncStatusInfo({
    required this.online,
    required this.pendingCount,
    required this.failedCount,
    required this.syncing,
    this.lastSyncAt,
  });
  factory SyncStatusInfo.idle() => const SyncStatusInfo(
      online: true, pendingCount: 0, failedCount: 0, syncing: false);

  String get label {
    if (!online) {
      final p = pendingCount;
      return p == 0 ? 'Offline' : 'Offline · $p pending';
    }
    if (syncing) return 'Syncing...';
    if (failedCount > 0) return 'Sync issues ($failedCount)';
    if (pendingCount > 0) return '$pendingCount pending';
    return 'All synced';
  }
}

/// Adapter that lets us reuse _onSaleUpdate with a fetched snapshot.
class _SyntheticEvent implements DatabaseEvent {
  @override
  final DataSnapshot snapshot;
  _SyntheticEvent(this.snapshot);
  @override
  String? get previousChildKey => null;
  @override
  DatabaseEventType get type => DatabaseEventType.childAdded;
}
