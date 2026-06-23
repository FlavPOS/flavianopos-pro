import 'package:flutter/material.dart';
import '../models/z_report_model.dart';
import 'firebase_config_service.dart';
import 'firebase_realtime_service.dart';
import 'device_assignment_service.dart';

/// BIR-compliant Daily Lock — ROLE-AWARE
/// Blocks ONLY Cashier role from new transactions after Z Report.
/// Admin/Manager retain authority to encode Beginning Cash and ring sales.
class DailyLockService {
  /// True if Z Report already generated today.
  /// Lock applies only to Cashier role.
  static Future<bool> shouldBlock(String role) async {
    // Admin/Manager are never blocked (they have authority)
    if (role.toLowerCase() != 'cashier') return false;
    try {
      return await ZReportRecord.hasReportForToday();
    } catch (_) {
      return false;
    }
  }

  /// True if Z Report already generated today.
  /// Checks BOTH local SQLite AND Firebase (defense-in-depth).
  static Future<bool> isLocked() async {
    // 1. Check local SQLite
    try {
      if (await ZReportRecord.hasReportForToday()) return true;
    } catch (_) {}

    // 2. Check Firebase (in case local was wiped — Smart Reset, Clear Data, etc.)
    try {
      final cfg = await FirebaseConfigService().load();
      if (cfg == null) return false;
      final companyCode = cfg.companyCode;
      if (companyCode.isEmpty) return false;

      if (!FirebaseRealtimeService.instance.isInitialized) {
        await FirebaseRealtimeService.instance.initializeFromManualConfig(cfg);
      }
      final db = FirebaseRealtimeService.instance.db;
      if (db == null) return false;

      // Get current branchId from DeviceAssignmentService
      final assign = await DeviceAssignmentService().read();
      final branchId = assign['branchId'] ?? '';
      if (branchId.isEmpty) return false;

      // Today's date as ISO prefix
      final now = DateTime.now();
      final todayPrefix = '${now.year}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}';

      final snap = await db
          .ref('companies/$companyCode/zReports/$branchId')
          .get()
          .timeout(const Duration(seconds: 5));
      if (!snap.exists || snap.value is! Map) return false;

      final reports = (snap.value as Map);
      for (final entry in reports.entries) {
        if (entry.value is Map) {
          final m = entry.value as Map;
          final reportDate = (m['reportDate'] ?? '').toString();
          if (reportDate.startsWith(todayPrefix)) {
            return true; // Today's Z Report found in cloud
          }
        }
      }
    } catch (_) {}

    return false;
  }

  /// Legacy (backward-compatible). Use shouldBlock(role) for new code.

  static String unlockMessage() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final remaining = midnight.difference(now);
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) return 'Unlocks in ${hours}h ${minutes}m (midnight)';
    return 'Unlocks in ${minutes}m (midnight)';
  }

  /// Friendly dialog for Cashier — no Admin Override
  /// (To override, log out and use Admin credentials)
  static Future<void> showCashierLockedDialog(BuildContext context, {required String action}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.lock_outline, color: Colors.orange.shade700, size: 28),
          const SizedBox(width: 8),
          const Expanded(child: Text('End-of-Day Locked')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, size: 20, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  unlockMessage(),
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                )),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Cannot $action.', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            const Text(
              'Z Report for today has already been generated. New transactions will be allowed at midnight.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.admin_panel_settings, size: 18, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'If emergency, please log in as Admin or Manager.',
                  style: TextStyle(fontSize: 12, color: Colors.purple.shade700),
                )),
              ]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK, I understand'),
          ),
        ],
      ),
    );
  }
}
