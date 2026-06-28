// lib/services/branch_inventory_service.dart
// BRANCH INVENTORY V2 - SINGLE source of truth
// AGGRESSIVE LOGGING + Direct Firebase upload

import '../helpers/database_helper.dart';
import '../models/branch_inventory_model.dart';
import '../services/firebase_config_service.dart';
import '../services/firebase_realtime_service.dart';
import '../services/device_assignment_service.dart';
import '../services/device_id_service.dart';

class BranchInventoryService {

  // ===== READ =====

  static Future<int> getStock(String branchId, String productId) async {
    if (branchId.isEmpty || productId.isEmpty) return 0;
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'branch_inventory',
      where: 'branchId = ? AND productId = ? AND isDeleted = 0',
      whereArgs: [branchId, productId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['stockQty'] as num?)?.toInt() ?? 0;
  }

  static Future<BranchInventory?> getInventory(String branchId, String productId) async {
    if (branchId.isEmpty || productId.isEmpty) return null;
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'branch_inventory',
      where: 'branchId = ? AND productId = ? AND isDeleted = 0',
      whereArgs: [branchId, productId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return BranchInventory.fromMap(rows.first);
  }

  // ===== WRITE =====

  static Future<bool> setStock(String branchId, String productId, int qty) async {
    if (qty < 0) qty = 0;
    print('[BINV] setStock: $branchId/$productId qty=$qty');
    return await _upsert(branchId, productId, {'stockQty': qty, 'isMigrated': 1});
  }

  static Future<bool> decrementStock(String branchId, String productId, int qty) async {
    if (qty <= 0) return false;
    print('[BINV] decrementStock START: $branchId/$productId qty=$qty');
    final current = await getStock(branchId, productId);
    print('[BINV] current=$current');
    if (current < qty) {
      print('[BINV] INSUFFICIENT');
      return false;
    }
    return await _upsert(branchId, productId, {'stockQty': current - qty, 'isMigrated': 1});
  }

  static Future<bool> incrementStock(String branchId, String productId, int qty) async {
    if (qty <= 0) return false;
    print('[BINV] incrementStock: $branchId/$productId +$qty');
    final current = await getStock(branchId, productId);
    return await _upsert(branchId, productId, {'stockQty': current + qty, 'isMigrated': 1});
  }

  // ===== UPSERT =====

  static Future<bool> _upsert(String branchId, String productId, Map<String, dynamic> updates) async {
    if (branchId.isEmpty || productId.isEmpty) return false;
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toUtc().toIso8601String();

    final existing = await db.query(
      'branch_inventory',
      where: 'branchId = ? AND productId = ?',
      whereArgs: [branchId, productId],
      limit: 1,
    );

    if (existing.isEmpty) {
      final row = <String, dynamic>{
        'branchId': branchId,
        'productId': productId,
        'stockQty': updates['stockQty'] ?? 0,
        'reservedQty': updates['reservedQty'] ?? 0,
        'inTransitInQty': updates['inTransitInQty'] ?? 0,
        'inTransitOutQty': updates['inTransitOutQty'] ?? 0,
        'reorderLevel': updates['reorderLevel'] ?? 5,
        'lastUpdated': now,
        'updatedAt': now,
        'deviceId': '',
        'isDeleted': 0,
        'isMigrated': updates['isMigrated'] ?? 0,
      };
      try {
        await db.insert('branch_inventory', row);
        print('[BINV] INSERT OK: $branchId/$productId');
        await _syncToFirebase(branchId, productId);
        return true;
      } catch (e) {
        print('[BINV] INSERT FAIL: $e');
        return false;
      }
    } else {
      final upd = Map<String, dynamic>.from(updates);
      upd['lastUpdated'] = now;
      upd['updatedAt'] = now;
      try {
        await db.update(
          'branch_inventory',
          upd,
          where: 'branchId = ? AND productId = ?',
          whereArgs: [branchId, productId],
        );
        print('[BINV] UPDATE OK: $branchId/$productId');
        await _syncToFirebase(branchId, productId);
        return true;
      } catch (e) {
        print('[BINV] UPDATE FAIL: $e');
        return false;
      }
    }
  }

  // ===== FIREBASE SYNC (DIRECT, NO QUEUE) =====

  // ═══ DEBUG: Last sync status ═══
  static String lastSyncStatus = "never";
  static String lastSyncDetail = "";
  static DateTime? lastSyncTime;

  static Future<void> _syncToFirebase(String branchId, String productId) async {
    print('[BINV-SYNC] START: $branchId/$productId');
    try {
      final cfg = await FirebaseConfigService().load();
      if (cfg == null) {
        print('[BINV-SYNC] FAIL: config NULL');
        return;
      }

      final assign = await DeviceAssignmentService().read();
      final companyCode = (assign['companyCode'] ?? '').toString();
      if (companyCode.isEmpty) {
        print('[BINV-SYNC] FAIL: companyCode empty');
        return;
      }
      print('[BINV-SYNC] companyCode=$companyCode');

      if (!FirebaseRealtimeService.instance.isInitialized) {
        print('[BINV-SYNC] Initializing Firebase...');
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }

      final db = FirebaseRealtimeService.instance.db;
      if (db == null) {
        print('[BINV-SYNC] FAIL: db NULL');
        return;
      }

      final inv = await getInventory(branchId, productId);
      if (inv == null) {
        print('[BINV-SYNC] FAIL: inv NULL');
        return;
      }

      final deviceId = await DeviceIdService().getOrCreate();
      final payload = {
        'branchId': inv.branchId,
        'productId': inv.productId,
        'stockQty': inv.stockQty,
        'reservedQty': inv.reservedQty,
        'inTransitInQty': inv.inTransitInQty,
        'inTransitOutQty': inv.inTransitOutQty,
        'reorderLevel': inv.reorderLevel,
        'lastUpdated': inv.lastUpdated.toIso8601String(),
        'updatedAt': inv.updatedAt.toIso8601String(),
        'deviceId': deviceId,
        'isDeleted': inv.isDeleted,
        'isMigrated': inv.isMigrated,
      };

      final path = 'companies/$companyCode/branchInventory/$branchId/$productId';
      print('[BINV-SYNC] Writing: $path');

      await db.ref(path).set(payload);

      print('[BINV-SYNC] SUCCESS: $path');
      lastSyncStatus = "SUCCESS";
      lastSyncDetail = path;
      lastSyncTime = DateTime.now();
    } catch (e) {
      print('[BINV-SYNC] EXCEPTION: $e');
      lastSyncStatus = "EXCEPTION";
      lastSyncDetail = e.toString();
      lastSyncTime = DateTime.now();
    }
  }

  // ===== MIGRATION =====

  static Future<int> getStockOrMigrate(String branchId, String productId, int productStockQty) async {
    final inv = await getInventory(branchId, productId);
    if (inv != null && inv.isMigrated) {
      return inv.stockQty;
    }
    print('[BINV-MIGRATE] $branchId/$productId from=$productStockQty');
    await setStock(branchId, productId, productStockQty);
    return productStockQty;
  }

  // ===== STOCK MAPS (for UI display) =====

  /// Returns Map<productId, stockQty> for a single branch.
  /// Used by Branch users in Inventory Screen.
  static Future<Map<String, int>> getStockMapForBranch(String branchId) async {
    final result = <String, int>{};
    if (branchId.isEmpty) return result;
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'branch_inventory',
      columns: ['productId', 'stockQty'],
      where: 'branchId = ? AND isDeleted = 0',
      whereArgs: [branchId],
    );
    for (final r in rows) {
      final pid = r['productId']?.toString() ?? '';
      final qty = (r['stockQty'] as num?)?.toInt() ?? 0;
      if (pid.isNotEmpty) result[pid] = qty;
    }
    print('[BINV] getStockMapForBranch($branchId) -> ${result.length} products');
    return result;
  }

  /// Returns Map<productId, totalStockQty> SUMMED across ALL branches.
  /// Used by Head Office / CompanyAdmin in Inventory Screen.
  static Future<Map<String, int>> getStockMapAllBranches() async {
    final result = <String, int>{};
    final db = await DatabaseHelper().database;
    final rows = await db.rawQuery(
      'SELECT productId, SUM(stockQty) AS totalQty FROM branch_inventory WHERE isDeleted = 0 GROUP BY productId'
    );
    for (final r in rows) {
      final pid = r['productId']?.toString() ?? '';
      final qty = (r['totalQty'] as num?)?.toInt() ?? 0;
      if (pid.isNotEmpty) result[pid] = qty;
    }
    print('[BINV] getStockMapAllBranches() -> ${result.length} products (consolidated)');
    return result;
  }

  /// Returns Map<branchId, Map<productId, stockQty>> for HO drill-down.
  static Future<Map<String, Map<String, int>>> getStockMapByBranch() async {
    final result = <String, Map<String, int>>{};
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'branch_inventory',
      columns: ['branchId', 'productId', 'stockQty'],
      where: 'isDeleted = 0',
    );
    for (final r in rows) {
      final bid = r['branchId']?.toString() ?? '';
      final pid = r['productId']?.toString() ?? '';
      final qty = (r['stockQty'] as num?)?.toInt() ?? 0;
      if (bid.isEmpty || pid.isEmpty) continue;
      result.putIfAbsent(bid, () => <String, int>{});
      result[bid]![pid] = qty;
    }
    print('[BINV] getStockMapByBranch() -> ${result.length} branches');
    return result;
  }
}
