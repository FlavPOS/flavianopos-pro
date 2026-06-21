import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'database_helper.dart';

/// Step 4 — Sync Schema Helper
/// Adds sync metadata columns to important tables and creates the
/// sync_queue + companies_cache tables.
///
/// Safe to run on every app start (idempotent).
/// Does NOT touch database_helper.dart.
class SyncSchemaHelper {
  SyncSchemaHelper._();

  /// List of (table, columnName, columnDef) for sync metadata.
  /// Adding to important tables only. Skips link/items tables that sync
  /// via their parent record (e.g. transaction_items, transfer_items).
  static const List<String> _syncTables = [
    'branches',
    'users',
    'products',
    'batches',
    'transactions',
    'customers',
    'stock_transfers',
    'adjustment_records',
    'expenses',
    'exchanges',
    'delivery_records',
    'discount_records',
    'employees',
  ];

  static const List<List<String>> _syncColumns = [
    // [columnName, columnDef]
    ['syncStatus', "TEXT DEFAULT 'pending'"],
    ['lastModifiedAt', "TEXT DEFAULT ''"],
    ['lastSyncedAt', "TEXT DEFAULT ''"],
    ['firebaseId', "TEXT DEFAULT ''"],
    ['firebasePath', "TEXT DEFAULT ''"],
    ['companyId', "TEXT DEFAULT ''"],
    ['branchId_sync', "TEXT DEFAULT ''"], // _sync suffix to avoid clashing with existing branchId columns
    ['deviceId', "TEXT DEFAULT ''"],
    ['createdBy_sync', "TEXT DEFAULT ''"],
    ['updatedBy_sync', "TEXT DEFAULT ''"],
    ['isDeleted', "INTEGER DEFAULT 0"],
  ];

  /// Call once after DatabaseHelper().database resolves on app start.
  static Future<void> ensureSyncSchema() async {
    final db = await DatabaseHelper().database;

    // 1) Add sync columns to important tables (defensive try/catch per ALTER).
    for (final tableName in _syncTables) {
      // Check table exists first (otherwise ALTER errors are noisy).
      if (!await _tableExists(db, tableName)) continue;

      for (final col in _syncColumns) {
        final colName = col[0];
        final colDef = col[1];
        if (await _columnExists(db, tableName, colName)) continue;
        try {
          await db.execute('ALTER TABLE $tableName ADD COLUMN $colName $colDef');
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ ALTER $tableName ADD $colName failed (ignored): $e');
          }
        }
      }
    }

    // 2) Mark Main Branch flag on branches table.
    if (await _tableExists(db, 'branches') &&
        !await _columnExists(db, 'branches', 'isMainBranch')) {
      try {
        await db.execute(
            'ALTER TABLE branches ADD COLUMN isMainBranch INTEGER DEFAULT 0');
      } catch (_) {}
    }

    // 3) sync_queue table.
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          queueId TEXT UNIQUE,
          entityType TEXT,
          entityId TEXT,
          operation TEXT,
          firebasePath TEXT,
          payloadJson TEXT,
          status TEXT DEFAULT 'pending',
          retryCount INTEGER DEFAULT 0,
          errorMessage TEXT,
          companyId TEXT DEFAULT '',
          branchId TEXT DEFAULT '',
          deviceId TEXT DEFAULT '',
          createdAt TEXT,
          updatedAt TEXT,
          lastAttemptAt TEXT,
          priority INTEGER DEFAULT 0
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_queue_priority ON sync_queue(priority, createdAt)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_queue_entity ON sync_queue(entityType, entityId)');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ sync_queue create failed: $e');
    }

    // 4) companies_cache table (local mirror of the Company record).
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS companies_cache (
          companyId TEXT PRIMARY KEY,
          companyCode TEXT,
          companyName TEXT DEFAULT '',
          ownerName TEXT DEFAULT '',
          setupMode TEXT DEFAULT '',
          isActive INTEGER DEFAULT 1,
          createdAt TEXT,
          updatedAt TEXT,
          createdByDeviceId TEXT DEFAULT '',
          syncStatus TEXT DEFAULT 'pending',
          lastModifiedAt TEXT DEFAULT '',
          lastSyncedAt TEXT DEFAULT '',
          firebaseId TEXT DEFAULT '',
          isDeleted INTEGER DEFAULT 0
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_companies_cache_code ON companies_cache(companyCode)');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ companies_cache create failed: $e');
    }

    if (kDebugMode) {
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND (name='sync_queue' OR name='companies_cache')");
      debugPrint('✅ Sync schema ensured. Found: ${tables.map((r) => r['name']).toList()}');
    }
  }

  static Future<bool> _tableExists(Database db, String name) async {
    final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?", [name]);
    return rows.isNotEmpty;
  }

  static Future<bool> _columnExists(
      Database db, String table, String column) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    for (final r in rows) {
      if ((r['name'] ?? '').toString() == column) return true;
    }
    return false;
  }
}
