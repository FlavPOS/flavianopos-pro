import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:uuid/uuid.dart';
import '../helpers/database_helper.dart';

class Company {
  final String companyId;
  final String companyCode;
  final String companyName;
  final String ownerName;
  final String setupMode;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final String createdByDeviceId;
  final String syncStatus;
  final String lastModifiedAt;
  final String lastSyncedAt;
  final String firebaseId;
  final bool isDeleted;

  const Company({
    required this.companyId,
    required this.companyCode,
    required this.companyName,
    this.ownerName = '',
    this.setupMode = 'multiple',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdByDeviceId = '',
    this.syncStatus = 'pending',
    this.lastModifiedAt = '',
    this.lastSyncedAt = '',
    this.firebaseId = '',
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'companyCode': companyCode,
        'companyName': companyName,
        'ownerName': ownerName,
        'setupMode': setupMode,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'createdByDeviceId': createdByDeviceId,
        'syncStatus': syncStatus,
        'lastModifiedAt': lastModifiedAt,
        'lastSyncedAt': lastSyncedAt,
        'firebaseId': firebaseId,
        'isDeleted': isDeleted ? 1 : 0,
      };

  Map<String, dynamic> toFirebase() => {
        'companyId': companyId,
        'companyCode': companyCode,
        'companyName': companyName,
        'ownerName': ownerName,
        'setupMode': setupMode,
        'isActive': isActive,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'createdByDeviceId': createdByDeviceId,
        'isDeleted': isDeleted,
      };

  factory Company.fromMap(Map<String, dynamic> m) => Company(
        companyId: (m['companyId'] ?? '').toString(),
        companyCode: (m['companyCode'] ?? '').toString(),
        companyName: (m['companyName'] ?? '').toString(),
        ownerName: (m['ownerName'] ?? '').toString(),
        setupMode: (m['setupMode'] ?? 'multiple').toString(),
        isActive: ((m['isActive'] as int?) ?? 1) == 1,
        createdAt: (m['createdAt'] ?? '').toString(),
        updatedAt: (m['updatedAt'] ?? '').toString(),
        createdByDeviceId: (m['createdByDeviceId'] ?? '').toString(),
        syncStatus: (m['syncStatus'] ?? 'pending').toString(),
        lastModifiedAt: (m['lastModifiedAt'] ?? '').toString(),
        lastSyncedAt: (m['lastSyncedAt'] ?? '').toString(),
        firebaseId: (m['firebaseId'] ?? '').toString(),
        isDeleted: ((m['isDeleted'] as int?) ?? 0) == 1,
      );

  static Future<void> insert(Company c) async {
    final db = await DatabaseHelper().database;
    await db.insert('companies_cache', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Company?> getFirst() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query('companies_cache',
        where: 'isDeleted = 0', limit: 1);
    if (rows.isEmpty) return null;
    return Company.fromMap(rows.first);
  }

  static String newId() => const Uuid().v4();
}
