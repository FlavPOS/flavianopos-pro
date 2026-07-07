import 'package:flutter/material.dart';
import '../../helpers/database_helper.dart';

/// Reason code model — direction auto-detected from name.
/// 
/// Rules:
/// - Name contains "(-)" → NEGATIVE (deducts stock)
/// - Name contains "(+)" → POSITIVE (adds stock)
/// - No sign → defaults to NEGATIVE
class AdjustmentReasonV3 {
  final String reasonCode;
  final String reasonName;
  final int direction;
  final String iconName;
  final bool isActive;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  const AdjustmentReasonV3({
    required this.reasonCode,
    required this.reasonName,
    required this.direction,
    this.iconName = 'warning_amber_rounded',
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isNegative => direction < 0;
  bool get isPositive => direction > 0;

  /// Auto-detect direction from name.
  /// Looks for (+) or (-) or (plus) or (minus).
  static int detectDirection(String name) {
    final lower = name.toLowerCase().replaceAll(' ', '');
    if (lower.contains('(+)') || lower.contains('(plus)')) {
      return 1;
    }
    if (lower.contains('(-)') || lower.contains('(minus)')) {
      return -1;
    }
    return -1; // Default: negative
  }

  Color get color => isNegative
      ? const Color(0xFFEF4444)
      : const Color(0xFF22C55E);

  IconData get icon {
    switch (iconName) {
      case 'warning_amber_rounded': return Icons.warning_amber_rounded;
      case 'broken_image_rounded':  return Icons.broken_image_rounded;
      case 'schedule_rounded':      return Icons.schedule_rounded;
      case 'error_rounded':         return Icons.error_rounded;
      case 'undo_rounded':          return Icons.undo_rounded;
      case 'delete_rounded':        return Icons.delete_rounded;
      case 'add_task_rounded':      return Icons.add_task_rounded;
      case 'search_rounded':        return Icons.search_rounded;
      case 'edit_rounded':          return Icons.edit_rounded;
      case 'warehouse_rounded':     return Icons.warehouse_rounded;
      case 'refresh_rounded':       return Icons.refresh_rounded;
      default:
        return isNegative
            ? Icons.warning_amber_rounded
            : Icons.add_task_rounded;
    }
  }

  Map<String, dynamic> toMap() => {
    'reason_code': reasonCode,
    'reason_name': reasonName,
    'direction': direction,
    'icon_name': iconName,
    'is_active': isActive ? 1 : 0,
    'sort_order': sortOrder,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory AdjustmentReasonV3.fromMap(Map<String, dynamic> m) =>
      AdjustmentReasonV3(
        reasonCode: (m['reason_code'] ?? '') as String,
        reasonName: (m['reason_name'] ?? '') as String,
        direction: (m['direction'] as num?)?.toInt() ?? -1,
        iconName: (m['icon_name'] ?? 'warning_amber_rounded') as String,
        isActive: ((m['is_active'] as num?)?.toInt() ?? 1) == 1,
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
        createdAt: (m['created_at'] ?? '') as String,
        updatedAt: (m['updated_at'] ?? '') as String,
      );
}

/// Data Access Object for AdjustmentReasonV3.
class AdjustmentReasonV3Dao {
  static const String _table = 'adjustment_reasons_v3';

  static Future<List<AdjustmentReasonV3>> getAll(
      {bool activeOnly = true}) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      _table,
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'sort_order ASC, reason_code ASC',
    );
    return rows.map(AdjustmentReasonV3.fromMap).toList();
  }

  static Future<void> insert(AdjustmentReasonV3 reason) async {
    final db = await DatabaseHelper().database;
    await db.insert(_table, reason.toMap());
  }

  static Future<void> update(AdjustmentReasonV3 reason) async {
    final db = await DatabaseHelper().database;
    await db.update(
      _table,
      reason.toMap(),
      where: 'reason_code = ?',
      whereArgs: [reason.reasonCode],
    );
  }

  static Future<void> delete(String reasonCode) async {
    final db = await DatabaseHelper().database;
    await db.delete(
      _table,
      where: 'reason_code = ?',
      whereArgs: [reasonCode],
    );
  }

  /// Seed default reason codes if table is empty.
  static Future<void> seedDefaults() async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM $_table');
    final count = (result.first['c'] as num?)?.toInt() ?? 0;
    // Auto-migrate: if any old single-digit codes exist, purge and reseed with 2-digit codes
    if (count > 0) {
      final hasOldCodes = await db.rawQuery(
        "SELECT COUNT(*) as c FROM $_table WHERE LENGTH(reason_code) < 2"
      );
      final oldCount = (hasOldCodes.first['c'] as num?)?.toInt() ?? 0;
      if (oldCount == 0) return;
      // Purge old codes and reseed
      await db.delete(_table);
    }

    final now = DateTime.now().toIso8601String();
    final defaults = [
      {'code': '01', 'name': 'Cycle Count (-)'},
      {'code': '02', 'name': 'Damaged Item (-)'},
      {'code': '03', 'name': 'Expired Item (-)'},
      {'code': '04', 'name': 'Theft or Loss (-)'},
      {'code': '05', 'name': 'Supplier Return (-)'},
      {'code': '06', 'name': 'Stock Write-Off (-)'},
      {'code': '07', 'name': 'Cycle Count (+)'},
      {'code': '08', 'name': 'Found Stock (+)'},
      {'code': '09', 'name': 'Inventory Correction (+)'},
    ];

    for (var i = 0; i < defaults.length; i++) {
      final d = defaults[i];
      final name = d['name'] as String;
      await db.insert(_table, {
        'reason_code': d['code'],
        'reason_name': name,
        'direction': AdjustmentReasonV3.detectDirection(name),
        'icon_name': '',
        'is_active': 1,
        'sort_order': i + 1,
        'created_at': now,
        'updated_at': now,
      });
    }
  }
}
