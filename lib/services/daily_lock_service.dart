import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../helpers/database_helper.dart';
import 'device_assignment_service.dart';

class DailyLockService {
  static Future<void> lockDayAfterZReport(String reportId) async {
    final db = await DatabaseHelper().database;
    final assign = await DeviceAssignmentService().read();
    final branchId = assign['branchId'] ?? 'default';
    final now = DateTime.now().toUtc().toIso8601String();
    debugPrint("🔒 lockDayAfterZReport: writing for branchId=$branchId");
    try {
    await db.insert("business_day_state", {
      'branchId': branchId, 'status': 'locked',
      'lockedAt': now, 'lockedByZReportId': reportId,
      'unlockedAt': '', 'unlockedBy': '', 'unlockReason': '',
      'updatedAt': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    debugPrint("✅ lockDayAfterZReport: business_day_state locked for branchId=$branchId");
    } catch (e) {
      debugPrint("❌ lockDayAfterZReport FAILED: $e");
    }
  }

  static Future<bool> isLocked() async {
    try {
      final db = await DatabaseHelper().database;
      final assign = await DeviceAssignmentService().read();
      final branchId = assign['branchId'] ?? 'default';
      final rows = await db.query('business_day_state',
        where: 'branchId = ?', whereArgs: [branchId], limit: 1);
      if (rows.isEmpty) return false;
      return (rows.first['status'] ?? 'open') == 'locked';
    } catch (_) { return false; }
  }

  static Future<bool> shouldBlock(String role) async {
    if (role.toLowerCase() != 'cashier') return false;
    return await isLocked();
  }

  static Future<bool> unlockDayWithManagerPin(BuildContext context) async {
    final username = await ManagerPinDialog.verify(
      context, title: 'Start New Business Day', actionLabel: 'Open new business day',
    );
    if (username == null) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🔴 DEBUG: PIN dialog returned NULL — cancelled or failed"), duration: Duration(seconds: 6))); return false; }
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("🟢 DEBUG: PIN verified, username=$username, proceeding to unlock..."), duration: const Duration(seconds: 6)));
    final db = await DatabaseHelper().database;
    final assign = await DeviceAssignmentService().read();
    final branchId = assign['branchId'] ?? 'default';
    final now = DateTime.now().toUtc().toIso8601String();
    debugPrint("🔒 lockDayAfterZReport: writing for branchId=$branchId");
    try {
    await db.insert("business_day_state", {
      'branchId': branchId, 'status': 'open',
      'lockedAt': '', 'lockedByZReportId': '',
      'unlockedAt': now, 'unlockedBy': username,
      'unlockReason': 'Manager opened new business day',
      'updatedAt': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    debugPrint("✅ lockDayAfterZReport: business_day_state locked for branchId=$branchId");
    } catch (e) {
      debugPrint("❌ lockDayAfterZReport FAILED: $e");
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Business day opened by $username'),
        backgroundColor: Colors.green,
      ));
    }
    return true;
  }

  static Future<void> showCashierLockedDialog(BuildContext context, {required String action}) async {
    await showDialog<void>(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.lock_outline, color: Colors.orange.shade700, size: 28),
          const SizedBox(width: 8),
          const Expanded(child: Text('Business Day Locked')),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200)),
            child: const Text('Z Report has been generated.\nWaiting for Manager to start new day.',
              style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          Text('Cannot $action.', style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8)),
            child: Text('Ask Manager/Admin to tap "Start New Day" from dashboard.',
              style: TextStyle(fontSize: 12, color: Colors.purple.shade700)),
          ),
        ]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK, I understand'),
          ),
        ],
      ),
    );
  }

  /// Authorize a one-time view of locked Z Report (BIR audit pattern).
  /// Returns true if Admin/Manager PIN verified, false if cancelled.
  /// Does NOT change business_day_state — just authorizes this view.
  static Future<bool> unlockForView(BuildContext context) async {
    final username = await ManagerPinDialog.verify(
      context,
      title: '🔓 Unlock Z Report',
      actionLabel: 'View locked Z Report',
    );
    return username != null;
  }

  /// Void current Z Report and unlock the day for re-generation.
  /// BIR-compliant: original Z stays in z_reports (status='VOIDED').
  /// Audit trail logged with reason.
  static Future<bool> voidZReportAndUnlock(BuildContext context, {required String currentZReportId}) async {
    final username = await ManagerPinDialog.verify(
      context,
      title: '🔓 Re-Open Z Report',
      actionLabel: 'Void current Z Report and re-open day',
    );
    if (username == null) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🔴 DEBUG: PIN dialog returned NULL — cancelled or failed"), duration: Duration(seconds: 6))); return false; }
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("🟢 DEBUG: PIN verified, username=$username, proceeding to unlock..."), duration: const Duration(seconds: 6)));

    // Reset business_day_state to 'open'
    final db = await DatabaseHelper().database;
    final assign = await DeviceAssignmentService().read();
    final branchId = assign['branchId'] ?? 'default';
    final now = DateTime.now().toUtc().toIso8601String();

    await db.insert('business_day_state', {
      'branchId': branchId,
      'status': 'open',
      'lockedAt': '',
      'lockedByZReportId': '',
      'unlockedAt': now,
      'unlockedBy': username,
      'unlockReason': 'Z Report voided for re-generation',
      'updatedAt': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Mark Z Report as VOIDED (don't delete — BIR audit requires keeping it)
    try {
      await db.update('z_reports',
        {'cashier': 'VOIDED by $username'},
        where: 'reportId = ?', whereArgs: [currentZReportId]);
    } catch (_) {}

    // Audit log
    await db.insert('expense_audit_trail', {
      'id': 'AUDIT-${DateTime.now().millisecondsSinceEpoch}',
      'expenseId': 'Z_REPORT_VOID',
      'expenseNumber': currentZReportId,
      'action': 'Z_REPORT_VOIDED',
      'oldValue': 'locked',
      'newValue': 'open',
      'performedBy': username,
      'performedDate': now,
      'branch': assign['branchName'] ?? '',
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🔁 Z Report voided by $username. Day re-opened for new Z.'),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 4),
      ));
    }
    return true;
  }

  /// 🆕 BIR-grade persistence — mark cash as declared today
  /// Survives app restart, screen close, etc.
  static Future<void> markCashDeclared() async {
    try {
      final db = await DatabaseHelper().database;
      final assign = await DeviceAssignmentService().read();
      final branchId = assign['branchId'] ?? 'default';
      final now = DateTime.now().toUtc().toIso8601String();

      // Try update first (row exists)
      final updated = await db.rawUpdate(
        "UPDATE business_day_state SET cashDeclared=1, cashDeclaredAt=?, updatedAt=? WHERE branchId=?",
        [now, now, branchId],
      );

      // If no row existed, insert one
      if (updated == 0) {
        await db.insert('business_day_state', {
          'branchId': branchId,
          'status': 'open',
          'lockedAt': '',
          'lockedByZReportId': '',
          'unlockedAt': '',
          'unlockedBy': '',
          'unlockReason': '',
          'cashDeclared': 1,
          'cashDeclaredAt': now,
          'updatedAt': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ markCashDeclared error: $e');
    }
  }

  /// 🆕 Reset cash declared (used by Re-Declare button)
  static Future<void> resetCashDeclared() async {
    try {
      final db = await DatabaseHelper().database;
      final assign = await DeviceAssignmentService().read();
      final branchId = assign['branchId'] ?? 'default';
      final now = DateTime.now().toUtc().toIso8601String();
      await db.rawUpdate(
        "UPDATE business_day_state SET cashDeclared=0, updatedAt=? WHERE branchId=?",
        [now, branchId],
      );
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ resetCashDeclared error: $e');
    }
  }

  /// 🆕 Check if cash was already declared today (persistence check)
  static Future<bool> isCashDeclared() async {
    try {
      final db = await DatabaseHelper().database;
      final assign = await DeviceAssignmentService().read();
      final branchId = assign['branchId'] ?? 'default';
      final rows = await db.query('business_day_state',
        where: 'branchId = ?', whereArgs: [branchId], limit: 1);
      if (rows.isEmpty) return false;
      final value = rows.first['cashDeclared'];
      if (value is int) return value == 1;
      return false;
    } catch (_) {
      return false;
    }
  }
}

class ManagerPinDialog {
  static Future<String?> verify(BuildContext context, {
    required String title, required String actionLabel,
  }) async {
    final pinCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: actionLabel);
    final confirmed = await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.admin_panel_settings, color: Colors.purple.shade700, size: 28),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8)),
            child: const Text('Manager or Admin PIN required.\nAction will be logged for audit.',
              style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: pinCtrl, autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Manager / Admin PIN',
              border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
            keyboardType: TextInputType.number, obscureText: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(
              labelText: 'Reason (audit trail)',
              border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes)),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
            onPressed: () {
              if (pinCtrl.text.trim().isEmpty || reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            icon: const Icon(Icons.check),
            label: const Text('Authorize'),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;
    final db = await DatabaseHelper().database;
    final pin = pinCtrl.text.trim();
    final users = await db.rawQuery(
      "SELECT username, fullName FROM users WHERE password = ? AND isActive = 1 AND (LOWER(role) = 'admin' OR LOWER(role) = 'manager' OR LOWER(role) = 'companyadmin')",
      [pin],
    );
    if (users.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("❌ Invalid PIN!\nMust be an Admin or Manager.\nGo to Users Module to verify."), duration: const Duration(seconds: 8),
          backgroundColor: Colors.red,
        ));
      }
      return null;
    }
    final username = (users.first['username'] ?? '').toString();
    final assign = await DeviceAssignmentService().read();
    await db.insert('expense_audit_trail', {
      'id': 'AUDIT-${DateTime.now().millisecondsSinceEpoch}',
      'expenseId': 'MANAGER_AUTH',
      'expenseNumber': actionLabel,
      'action': 'MANAGER_AUTHORIZED',
      'oldValue': '', 'newValue': actionLabel,
      'performedBy': username,
      'performedDate': DateTime.now().toUtc().toIso8601String(),
      'branch': assign['branchName'] ?? '',
    });
    return username;
  }
}
