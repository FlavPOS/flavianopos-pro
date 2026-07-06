import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:uuid/uuid.dart';
import '../helpers/database_helper.dart';
import '../helpers/sync_queue_dao.dart';
import '../models/company_model.dart';
import '../models/sync_queue_model.dart';
import '../models/user_model.dart';
import 'firebase_config_service.dart';
import 'firebase_realtime_service.dart';
import 'device_id_service.dart';

class MultiStoreSetupService {
  final _firebaseConfig = FirebaseConfigService();
  final _deviceIdService = DeviceIdService();
  final _queueDao = SyncQueueDao();
  static const Uuid _uuid = Uuid();

  Future<MultiStoreSetupResult> performSetup({
    required String companyName,
    required String ownerName,
    required String mainBranchName,
    String mainBranchAddress = '',
    String mainBranchPhone = '',
    String mainBranchCode = 'HO001',           // NEW: system key
    String mainBranchType = 'HEAD_OFFICE',      // NEW: business type
    required String adminUsername,
    required String adminFullName,
    required String adminPassword,
    required String adminPin,
    String adminEmail = '',
    String adminPhone = '',
  }) async {
    final cfg = await _firebaseConfig.load();
    if (cfg == null || !cfg.hasRequiredFields) {
      return MultiStoreSetupResult.failure('Firebase config is missing.');
    }
    final companyCode = cfg.companyCode.trim();
    if (companyCode.isEmpty) {
      return MultiStoreSetupResult.failure('Company Code is empty.');
    }

    final deviceId = await _deviceIdService.getOrCreate();
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toUtc().toIso8601String();

    // ----- COMPANY -----
    final companyId = Company.newId();
    final company = Company(
      companyId: companyId,
      companyCode: companyCode,
      companyName: companyName.trim(),
      ownerName: ownerName.trim(),
      setupMode: 'multiple',
      isActive: true,
      createdAt: now,
      updatedAt: now,
      createdByDeviceId: deviceId,
      syncStatus: SyncStatus.pending,
      lastModifiedAt: now,
    );
    await Company.insert(company);

    await _queueDao.enqueue(
      entityType: 'company',
      entityId: companyId,
      operation: SyncOp.create,
      firebasePath: 'companies/$companyCode/profile',
      payload: company.toFirebase(),
      companyId: companyCode,
      deviceId: deviceId,
      priority: SyncPriority.p1Critical,
    );

    // ----- MAIN BRANCH -----
    // Use branchCode as system key (BR001, HO001) instead of UUID
    final mainBranchId = mainBranchCode.trim().toUpperCase();
    await db.insert('branches', {
      'id': mainBranchId,
      'name': mainBranchName.trim(),
      'branchType': mainBranchType,
      'address': mainBranchAddress.trim(),
      'phone': mainBranchPhone.trim(),
      'isActive': 1,
      'email': '',
      'manager': '',
      'createdDate': now,
      'imagePath': null,
      'syncStatus': SyncStatus.pending,
      'lastModifiedAt': now,
      'lastSyncedAt': '',
      'firebaseId': mainBranchId,
      'firebasePath': 'companies/$companyCode/branches/$mainBranchId',
      'companyId': companyCode,
      'branchId_sync': mainBranchId,
      'deviceId': deviceId,
      'createdBy_sync': 'setup',
      'updatedBy_sync': 'setup',
      'isDeleted': 0,
      'isMainBranch': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    final isHeadOffice = mainBranchType == 'HEAD_OFFICE';
    final mainBranchPayload = {
      'branchId': mainBranchId,
      'companyId': companyId,
      'companyCode': companyCode,
      'branchCode': mainBranchId,
      'branchName': mainBranchName.trim(),
      'branchType': mainBranchType,
      'address': mainBranchAddress.trim(),
      'phone': mainBranchPhone.trim(),
      'isMainBranch': isHeadOffice,
      'isActive': true,
      'createdAt': now,
      'updatedAt': now,
      'createdByDeviceId': deviceId,
      'isDeleted': false,
    };

    await _queueDao.enqueue(
      entityType: 'branch',
      entityId: mainBranchId,
      operation: SyncOp.create,
      firebasePath: 'companies/$companyCode/branches/$mainBranchId',
      payload: mainBranchPayload,
      companyId: companyCode,
      branchId: mainBranchId,
      deviceId: deviceId,
      priority: SyncPriority.p1Critical,
    );

    // ----- FIRST ADMIN USER — uses the CANONICAL AppUser.addUser() pattern -----
    final adminUserId = 'USR-${_uuid.v4().substring(0, 8).toUpperCase()}';
    final rawPin = adminPin.trim();
    final adminPerms = AppUser.rolePresets['Admin'] ?? <String>[];

    // Clean up any pre-existing rows with same username (for re-runs).
    try {
      await db.delete('users', where: 'username = ?', whereArgs: [adminUsername.trim()]);
      // Also remove from in-memory cache if present
      AppUser.allUsers.removeWhere((u) => u.username == adminUsername.trim());
    } catch (_) {}

    final adminUser = AppUser(
      id: adminUserId,
      name: adminFullName.trim(),
      username: adminUsername.trim(),
      pin: rawPin,
      email: adminEmail.trim(),
      phone: adminPhone.trim(),
      role: 'Admin',
      branch: mainBranchName.trim(),
      joinDate: DateTime.now(),
      lastLogin: null,
      isActive: true,
      permissions: adminPerms,
    );

    // 🎯 CANONICAL CALL — same path your User Module uses
    AppUser.addUser(adminUser);
    // Give async insert a brief moment to flush before continuing
    await Future.delayed(const Duration(milliseconds: 50));

    // Now patch sync metadata columns onto the row that addUser() just inserted
    await db.update('users', {
      'syncStatus': SyncStatus.pending,
      'lastModifiedAt': now,
      'lastSyncedAt': '',
      'firebaseId': adminUserId,
      'firebasePath': 'companies/$companyCode/users/$adminUserId',
      'companyId': companyCode,
      'branchId_sync': mainBranchId,
      'deviceId': deviceId,
      'createdBy_sync': 'setup',
      'updatedBy_sync': 'setup',
      'isDeleted': 0,
    }, where: 'id = ?', whereArgs: [adminUserId]);

    final adminFirebasePayload = {
      'userId': adminUserId,
      'companyId': companyId,
      'companyCode': companyCode,
      'username': adminUsername.trim(),
      'fullName': adminFullName.trim(),
      'role': 'Admin',
      'roleName': 'Company Admin',
      'branchId': mainBranchId,
      'branchName': mainBranchName.trim(),
      'createdByBranchId': mainBranchId,
      'createdByUserId': adminUserId,
      'email': adminEmail.trim(),
      'phone': adminPhone.trim(),
      'permissions': adminPerms,
      'isMainBranchUser': true,
      'isCompanyAdmin': true,
      'isBranchAdmin': true,
      'isActive': true,
      'createdAt': now,
      'updatedAt': now,
      'lastModifiedAt': now,
      'isDeleted': false,
    };

    await _queueDao.enqueue(
      entityType: 'user',
      entityId: adminUserId,
      operation: SyncOp.create,
      firebasePath: 'companies/$companyCode/users/$adminUserId',
      payload: adminFirebasePayload,
      companyId: companyCode,
      branchId: mainBranchId,
      deviceId: deviceId,
      priority: SyncPriority.p1Critical,
    );
    await _queueDao.enqueue(
      entityType: 'userByBranch',
      entityId: adminUserId,
      operation: SyncOp.create,
      firebasePath: 'companies/$companyCode/usersByBranch/$mainBranchId/$adminUserId',
      payload: adminFirebasePayload,
      companyId: companyCode,
      branchId: mainBranchId,
      deviceId: deviceId,
      priority: SyncPriority.p1Critical,
    );

    // ----- FIREBASE UPLOAD -----
    String? firebaseError;
    try {
      await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      final fbDb = FirebaseRealtimeService.instance.db;
      if (fbDb == null) throw Exception('Firebase DB not initialized');

      await fbDb.ref('companies/$companyCode/profile').set(company.toFirebase());
      await _markQueueSyncedByEntity('company', companyId);
      await _markRowSynced(db, 'companies_cache', 'companyId', companyId, now);

      await fbDb.ref('companies/$companyCode/branches/$mainBranchId').set(mainBranchPayload);
      await _markQueueSyncedByEntity('branch', mainBranchId);
      await _markRowSynced(db, 'branches', 'id', mainBranchId, now);

      await fbDb.ref('companies/$companyCode/users/$adminUserId').set(adminFirebasePayload);
      await fbDb.ref('companies/$companyCode/usersByBranch/$mainBranchId/$adminUserId').set(adminFirebasePayload);
      await _markQueueSyncedByEntity('user', adminUserId);
      await _markQueueSyncedByEntity('userByBranch', adminUserId);
      await _markRowSynced(db, 'users', 'id', adminUserId, now);

      await fbDb.ref('companies/$companyCode/devices/$deviceId').update({
        'deviceId': deviceId,
        'branchId': mainBranchId,
        'branchName': mainBranchName.trim(),
        'role': 'Admin',
        'registeredAt': now,
        'lastSeenAt': now,
        'registeredByUserId': adminUserId,
        'registeredByUsername': adminUsername.trim(),
        'platform': 'flutter',
        'app': 'FlavianoPOS-Pro',
      });
    } catch (e) {
      firebaseError = e.toString();
    }

    await _firebaseConfig.lock();

    return MultiStoreSetupResult.success(
      companyId: companyId,
      companyCode: companyCode,
      mainBranchId: mainBranchId,
      adminUserId: adminUserId,
      firebaseError: firebaseError,
    );
  }

  Future<void> _markQueueSyncedByEntity(String entityType, String entityId) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update('sync_queue',
        {'status': SyncStatus.synced, 'updatedAt': now, 'errorMessage': null},
        where: 'entityType = ? AND entityId = ?',
        whereArgs: [entityType, entityId]);
  }

  Future<void> _markRowSynced(
      Database db, String table, String pkCol, String pkVal, String now) async {
    try {
      await db.update(table,
          {'syncStatus': SyncStatus.synced, 'lastSyncedAt': now},
          where: '$pkCol = ?', whereArgs: [pkVal]);
    } catch (_) {}
  }
}

class MultiStoreSetupResult {
  final bool success;
  final String? error;
  final String? companyId;
  final String? companyCode;
  final String? mainBranchId;
  final String? adminUserId;
  final String? firebaseError;

  const MultiStoreSetupResult._(
      {required this.success, this.error, this.companyId, this.companyCode,
       this.mainBranchId, this.adminUserId, this.firebaseError});

  factory MultiStoreSetupResult.success({
    required String companyId, required String companyCode,
    required String mainBranchId, required String adminUserId,
    String? firebaseError,
  }) => MultiStoreSetupResult._(
    success: true, companyId: companyId, companyCode: companyCode,
    mainBranchId: mainBranchId, adminUserId: adminUserId,
    firebaseError: firebaseError,
  );

  factory MultiStoreSetupResult.failure(String error) =>
      MultiStoreSetupResult._(success: false, error: error);
}
