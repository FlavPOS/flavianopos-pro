import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../helpers/database_helper.dart';
import '../models/sync_queue_model.dart';

/// Step 4 — Sync Queue DAO
/// All CRUD for the sync_queue table.
/// SOLO STORE MODE: never enqueues. Multiple Store: enqueues every write.
class SyncQueueDao {
  static const String table = 'sync_queue';
  static const Uuid _uuid = Uuid();

  /// Add a new pending sync item.
  Future<String> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required String firebasePath,
    Map<String, dynamic> payload = const {},
    String companyId = '',
    String branchId = '',
    String deviceId = '',
    int priority = SyncPriority.p4Transactional,
  }) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toUtc().toIso8601String();
    final queueId = _uuid.v4();

    await db.insert(table, {
      'queueId': queueId,
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation,
      'firebasePath': firebasePath,
      'payloadJson': jsonEncode(payload),
      'status': SyncStatus.pending,
      'retryCount': 0,
      'errorMessage': null,
      'companyId': companyId,
      'branchId': branchId,
      'deviceId': deviceId,
      'createdAt': now,
      'updatedAt': now,
      'lastAttemptAt': null,
      'priority': priority,
    });

    return queueId;
  }

  /// Fetch pending items ordered by priority then by createdAt (FIFO).
  Future<List<SyncQueueItem>> getPending({int limit = 100}) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      table,
      where: 'status IN (?, ?)',
      whereArgs: [SyncStatus.pending, SyncStatus.failed],
      orderBy: 'priority ASC, createdAt ASC',
      limit: limit,
    );
    return rows.map(SyncQueueItem.fromMap).toList();
  }

  /// Get all items (admin/debug view).
  Future<List<SyncQueueItem>> getAll({int limit = 500}) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      table,
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.map(SyncQueueItem.fromMap).toList();
  }

  /// Counts for status dashboard pill.
  Future<Map<String, int>> counts() async {
    final db = await DatabaseHelper().database;
    final rows = await db.rawQuery(
        'SELECT status, COUNT(*) as c FROM $table GROUP BY status');
    final out = <String, int>{};
    for (final r in rows) {
      out[(r['status'] ?? '').toString()] = (r['c'] as int?) ?? 0;
    }
    return out;
  }

  /// Mark an item as currently being processed (so other syncs skip it).
  Future<void> markProcessing(String queueId) async {
    final db = await DatabaseHelper().database;
    await db.update(
      table,
      {
        'status': SyncStatus.processing,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'lastAttemptAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'queueId = ?',
      whereArgs: [queueId],
    );
  }

  /// Mark an item as successfully synced.
  Future<void> markSynced(String queueId) async {
    final db = await DatabaseHelper().database;
    await db.update(
      table,
      {
        'status': SyncStatus.synced,
        'errorMessage': null,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'queueId = ?',
      whereArgs: [queueId],
    );
  }

  /// Mark an item as failed; will be retried later.
  Future<void> markFailed(String queueId, String error) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawUpdate(
      'UPDATE $table SET status = ?, errorMessage = ?, retryCount = retryCount + 1, updatedAt = ?, lastAttemptAt = ? WHERE queueId = ?',
      [SyncStatus.failed, error, now, now, queueId],
    );
  }

  /// Reset "processing" items that got stuck (e.g. app crashed mid-sync).
  Future<int> resetStuckProcessing(
      {Duration olderThan = const Duration(minutes: 5)}) async {
    final db = await DatabaseHelper().database;
    final threshold =
        DateTime.now().toUtc().subtract(olderThan).toIso8601String();
    return db.rawUpdate(
      "UPDATE $table SET status = ?, updatedAt = ? WHERE status = ? AND (lastAttemptAt IS NULL OR lastAttemptAt < ?)",
      [
        SyncStatus.pending,
        DateTime.now().toUtc().toIso8601String(),
        SyncStatus.processing,
        threshold
      ],
    );
  }

  /// Purge old synced items (keep table small).
  Future<int> purgeOldSynced(
      {Duration olderThan = const Duration(days: 30)}) async {
    final db = await DatabaseHelper().database;
    final threshold =
        DateTime.now().toUtc().subtract(olderThan).toIso8601String();
    return db.delete(
      table,
      where: 'status = ? AND updatedAt < ?',
      whereArgs: [SyncStatus.synced, threshold],
    );
  }

  Future<void> deleteByQueueId(String queueId) async {
    final db = await DatabaseHelper().database;
    await db
        .delete(table, where: 'queueId = ?', whereArgs: [queueId]);
  }
}
