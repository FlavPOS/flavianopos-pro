import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../helpers/database_helper.dart';
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
    final branchId = assign['branchId'] ?? '';

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
        _rtListeners.add(fbDb.ref("companies/$companyCode/sales")
            .onChildAdded.listen((event) => _onSaleBranchUpdate(event, companyCode)));
        _rtListeners.add(fbDb.ref("companies/$companyCode/sales")
            .onChildChanged.listen((event) => _onSaleBranchUpdate(event, companyCode)));
      } else {
        // 🏪 BRANCH: listen to OWN branch only
        _rtListeners.add(fbDb.ref("companies/$companyCode/sales/$branchId")
            .onChildAdded.listen((event) => _onSaleUpdate(event, companyCode, branchId)));
        _rtListeners.add(fbDb.ref("companies/$companyCode/sales/$branchId")
            .onChildChanged.listen((event) => _onSaleUpdate(event, companyCode, branchId)));
        _rtListeners.add(fbDb.ref("companies/$companyCode/sales/$branchId")
            .onChildRemoved.listen((event) => _onSaleDelete(event)));
      }

      _rtListeners.add(fbDb.ref('companies/$companyCode/usersByBranch/$branchId')
          .onChildAdded.listen((event) => _onUserUpdate(event, branchId)));
      _rtListeners.add(fbDb.ref('companies/$companyCode/usersByBranch/$branchId')
          .onChildChanged.listen((event) => _onUserUpdate(event, branchId)));
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
          'imagePath': null,
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

  Future<void> _onUserUpdate(DatabaseEvent event, String branchId) async {
    try {
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
          'imagePath': null,
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
