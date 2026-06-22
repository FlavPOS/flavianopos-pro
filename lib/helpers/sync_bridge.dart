import 'package:flutter/foundation.dart';
import '../helpers/database_helper.dart';
import '../helpers/sync_queue_dao.dart';
import '../models/sync_queue_model.dart';
import '../models/user_model.dart';
import '../models/branch_model.dart';
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
}
