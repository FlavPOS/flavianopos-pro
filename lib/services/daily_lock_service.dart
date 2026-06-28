import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// 🆕 BIR-grade persistence — uses SharedPreferences (works on Web + Android)
  static Future<void> markCashDeclared() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final assign = await DeviceAssignmentService().read();
      final branchId = assign['branchId'] ?? 'default';
      final today = DateTime.now().toIso8601String().substring(0, 10);  // YYYY-MM-DD
      await prefs.setBool('cashDeclared_${branchId}_$today', true);
      await prefs.setString('cashDeclaredAt_${branchId}_$today',
        DateTime.now().toUtc().toIso8601String());
      if (kDebugMode) debugPrint('✅ markCashDeclared: $branchId $today');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ markCashDeclared error: $e');
    }
  }


  /// 🆕 BIR-grade persistence — save declared denominations as JSON
  static Future<void> saveCashDeclaredDenominations(Map<double, int> denoms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final assign = await DeviceAssignmentService().read();
      final branchId = assign['branchId'] ?? 'default';
      final today = DateTime.now().toIso8601String().substring(0, 10);
      // Encode as "1000:2,500:1,100:3"
      final encoded = denoms.entries
          .where((e) => e.value > 0)
          .map((e) => '${e.key}:${e.value}')
          .join(',');
      await prefs.setString('cashDeclaredDenoms_${branchId}_$today', encoded);
      if (kDebugMode) debugPrint('✅ saveCashDeclaredDenominations: $encoded');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ saveCashDeclaredDenominations error: $e');
    }
  }

  /// 🆕 Load declared denominations back (for blind audit re-display)
  static Future<Map<double, int>> getCashDeclaredDenominations() async {
    final result = <double, int>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final assign = await DeviceAssignmentService().read();
      final branchId = assign['branchId'] ?? 'default';
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final encoded = prefs.getString('cashDeclaredDenoms_${branchId}_$today') ?? '';
      if (encoded.isEmpty) return result;
      for (final pair in encoded.split(',')) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          final denom = double.tryParse(parts[0]) ?? 0;
          final qty = int.tryParse(parts[1]) ?? 0;
          if (denom > 0 && qty > 0) result[denom] = qty;
        }
      }
      if (kDebugMode) debugPrint('✅ getCashDeclaredDenominations: $result');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ getCashDeclaredDenominations error: $e');
    }
    return result;
  }

  /// 🆕 Clear declared denominations when day is reset/reopened
  static Future<void> clearCashDeclaredDenominations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final assign = await DeviceAssignmentService().read();
      final branchId = assign['branchId'] ?? 'default';
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await prefs.remove('cashDeclaredDenoms_${branchId}_$today');
      if (kDebugMode) debugPrint('🔄 clearCashDeclaredDenominations: $branchId $today');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ clearCashDeclaredDenominations error: $e');
    }
  }
  static Future<void> resetCashDeclared() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final assign = await DeviceAssignmentService().read();
      final branchId = assign['branchId'] ?? 'default';
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await prefs.setBool('cashDeclared_${branchId}_$today', false);
      if (kDebugMode) debugPrint('🔄 resetCashDeclared: $branchId $today');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ resetCashDeclared error: $e');
    }
  }

  static Future<bool> isCashDeclared() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final assign = await DeviceAssignmentService().read();
      final branchId = assign['branchId'] ?? 'default';
      final today = DateTime.now().toIso8601String().substring(0, 10);
      return prefs.getBool('cashDeclared_${branchId}_$today') ?? false;
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
          content: Text("❌ Invalid PIN!\nMust be an Admin or Manager.\nGo to Users Module to verify."), duration: Duration(seconds: 8),
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
