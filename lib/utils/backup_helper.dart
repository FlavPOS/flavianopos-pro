// lib/utils/backup_helper.dart
// COMPLETE ENTERPRISE BACKUP SYSTEM - Covers ALL 29 SQLite tables

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../helpers/database_helper.dart';

class BackupHelper {
  static const String VERSION = '2.0';
  static const String APP_NAME = 'FlavianoPOS-PRO';

  // ALL 29 tables to backup
  static const List<String> ALL_TABLES = [
    // Core
    'products', 'batches', 'transactions', 'transaction_items',
    'customers', 'users', 'branches', 'employees',
    // Inventory
    'batch_logs', 'adjustment_records', 'adjustment_reasons',
    'stock_transfers', 'transfer_items', 'transfer_ledger',
    'delivery_records', 'delivery_items',
    // Sales
    'discount_records', 'discount_items', 'exchanges', 'z_reports',
    // Expenses
    'expenses', 'expense_categories', 'expense_sub_categories',
    'expense_audit_trail', 'expense_budgets', 'petty_cash_transactions',
    // Cashier Locking
    'cashier_sessions', 'denomination_records', 'incident_reports',
  ];

  /// Export ALL data from ALL tables to JSON string
  static Future<String> exportAllData() async {
    final db = await DatabaseHelper().database;
    final Map<String, dynamic> backup = {
      'metadata': {
        'app': APP_NAME,
        'version': VERSION,
        'exportedAt': DateTime.now().toIso8601String(),
        'tableCount': ALL_TABLES.length,
      },
      'data': <String, dynamic>{},
    };

    int totalRows = 0;
    for (final table in ALL_TABLES) {
      try {
        final rows = await db.query(table);
        backup['data'][table] = rows;
        totalRows += rows.length;
      } catch (e) {
        // Table may not exist in older versions - skip silently
        backup['data'][table] = [];
      }
    }

    backup['metadata']['totalRows'] = totalRows;
    return jsonEncode(backup);
  }

  /// Save backup to file and share
  static Future<String?> saveBackupToFile() async {
    try {
      final jsonString = await exportAllData();
      final now = DateTime.now();
      final filename = 'FlavianoPOS-Backup-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';

      if (kIsWeb) {
        // Web: trigger download via share
        final bytes = utf8.encode(jsonString);
        await Share.shareXFiles(
          [XFile.fromData(Uint8List.fromList(bytes), name: filename, mimeType: 'application/json')],
          subject: 'FlavianoPOS Backup',
        );
        return filename;
      } else {
        // Mobile/Desktop: save to documents
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsString(jsonString);

        // Share the file
        await Share.shareXFiles([XFile(file.path)], subject: 'FlavianoPOS Backup');
        return file.path;
      }
    } catch (e) {
      throw Exception('Backup failed: $e');
    }
  }

  /// Restore from JSON string
  static Future<Map<String, dynamic>> restoreFromJson(String jsonString) async {
    try {
      final backup = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate metadata
      final metadata = backup['metadata'] as Map<String, dynamic>?;
      if (metadata == null || metadata['app'] != APP_NAME) {
        throw Exception('Invalid backup file - not a FlavianoPOS backup');
      }

      final data = backup['data'] as Map<String, dynamic>?;
      if (data == null) throw Exception('Backup has no data section');

      final db = await DatabaseHelper().database;

      int restoredRows = 0;
      int failedTables = 0;
      final List<String> errors = [];

      // Restore each table
      for (final table in ALL_TABLES) {
        if (!data.containsKey(table)) continue;

        try {
          final rows = data[table] as List<dynamic>;
          
          // Clear existing data in this table first
          await db.delete(table);
          
          // Insert all rows
          for (final row in rows) {
            await db.insert(table, Map<String, dynamic>.from(row as Map));
            restoredRows++;
          }
        } catch (e) {
          failedTables++;
          errors.add('$table: $e');
        }
      }

      return {
        'success': true,
        'restoredRows': restoredRows,
        'failedTables': failedTables,
        'errors': errors,
        'metadata': metadata,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Pick and restore backup file
  static Future<Map<String, dynamic>?> pickAndRestoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return null;

      String jsonString;
      if (kIsWeb) {
        final bytes = result.files.first.bytes;
        if (bytes == null) throw Exception('Cannot read file');
        jsonString = utf8.decode(bytes);
      } else {
        final path = result.files.first.path;
        if (path == null) throw Exception('No file path');
        jsonString = await File(path).readAsString();
      }

      return await restoreFromJson(jsonString);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get backup preview (count rows per table)
  static Future<Map<String, int>> getBackupPreview() async {
    final db = await DatabaseHelper().database;
    final Map<String, int> counts = {};

    for (final table in ALL_TABLES) {
      try {
        final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM $table');
        counts[table] = (result.first['cnt'] as int?) ?? 0;
      } catch (_) {
        counts[table] = 0;
      }
    }

    return counts;
  }
}
