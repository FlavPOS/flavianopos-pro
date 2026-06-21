import 'package:sqflite/sqflite.dart' hide Transaction;
import 'database_helper.dart';
import '../models/company_model.dart';
import '../models/sync_queue_model.dart';

class FirebaseToSqliteMirror {
  Future<void> mirrorCompany({
    required Map<String, dynamic> profile,
    required String companyCode,
    required String deviceId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final c = Company(
      companyId: (profile['companyId'] ?? '').toString(),
      companyCode: companyCode,
      companyName: (profile['companyName'] ?? '').toString(),
      ownerName: (profile['ownerName'] ?? '').toString(),
      setupMode: 'multiple',
      isActive: true,
      createdAt: (profile['createdAt'] ?? now).toString(),
      updatedAt: (profile['updatedAt'] ?? now).toString(),
      createdByDeviceId: (profile['createdByDeviceId'] ?? '').toString(),
      syncStatus: SyncStatus.synced,
      lastSyncedAt: now,
      firebaseId: (profile['companyId'] ?? '').toString(),
    );
    await Company.insert(c);
  }

  Future<void> mirrorBranches({
    required List<Map<String, dynamic>> branches,
    required String companyCode,
    required String deviceId,
  }) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toUtc().toIso8601String();
    for (final b in branches) {
      final id = (b['branchId'] ?? '').toString();
      if (id.isEmpty) continue;
      await db.insert('branches', {
        'id': id,
        'name': (b['branchName'] ?? '').toString(),
        'address': (b['address'] ?? '').toString(),
        'phone': (b['phone'] ?? '').toString(),
        'isActive': 1,
        'email': (b['email'] ?? '').toString(),
        'manager': (b['manager'] ?? '').toString(),
        'createdDate': (b['createdAt'] ?? now).toString(),
        'imagePath': null,
        'syncStatus': SyncStatus.synced,
        'lastModifiedAt': (b['updatedAt'] ?? now).toString(),
        'lastSyncedAt': now,
        'firebaseId': id,
        'firebasePath': 'companies/$companyCode/branches/$id',
        'companyId': companyCode,
        'branchId_sync': id,
        'deviceId': deviceId,
        'createdBy_sync': 'mirror',
        'updatedBy_sync': 'mirror',
        'isDeleted': 0,
        'isMainBranch': (b['isMainBranch'] == true) ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> mirrorUsers({
    required List<Map<String, dynamic>> users,
    required String companyCode,
    required String deviceId,
  }) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toUtc().toIso8601String();
    for (final u in users) {
      final id = (u['userId'] ?? '').toString();
      if (id.isEmpty) continue;
      final username = (u['username'] ?? '').toString();
      if (username.isEmpty) continue;
      final exists = await db.query('users',
          where: 'id = ? OR username = ?',
          whereArgs: [id, username], limit: 1);
      if (exists.isNotEmpty) continue;
      await db.insert('users', {
        'id': id,
        'username': username,
        'password': '__pending_setup__',
        'fullName': (u['fullName'] ?? '').toString(),
        'role': (u['role'] ?? 'cashier').toString(),
        'branch': (u['branchName'] ?? '').toString(),
        'pin': '',
        'isActive': 1,
        'dateCreated': (u['createdAt'] ?? now).toString(),
        'email': (u['email'] ?? '').toString(),
        'phone': (u['phone'] ?? '').toString(),
        'lastLogin': null,
        'permissions': (u['permissions'] ?? '').toString(),
        'biometricEnabled': 0, 'biometricEnrolled': 0,
        'preferredBiometricType': 'face', 'lastBiometricVerifiedAt': null,
        'syncStatus': SyncStatus.synced,
        'lastModifiedAt': (u['updatedAt'] ?? now).toString(),
        'lastSyncedAt': now,
        'firebaseId': id,
        'firebasePath': 'companies/$companyCode/users/$id',
        'companyId': companyCode,
        'branchId_sync': (u['branchId'] ?? '').toString(),
        'deviceId': deviceId,
        'createdBy_sync': 'mirror',
        'updatedBy_sync': 'mirror',
        'isDeleted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}
