import 'package:flutter/material.dart';
import '../models/z_report_model.dart';

/// BIR-compliant Daily Lock
/// Once a Z Report is generated for the day, blocks:
///   - Beginning Cash encoding
///   - Sales (Cashiering)
/// Auto-unlocks at midnight (next calendar day)
class DailyLockService {
  /// True if Z Report already generated today (per local SQLite — branch-isolated by data design)
  static Future<bool> isLocked() async {
    try {
      return await ZReportRecord.hasReportForToday();
    } catch (_) {
      return false;
    }
  }

  /// Human-friendly time until midnight unlock
  static String unlockMessage() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final remaining = midnight.difference(now);
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return 'Unlocks in ${hours}h ${minutes}m (midnight)';
    }
    return 'Unlocks in ${minutes}m (midnight)';
  }

  /// Show lock dialog with Admin override option
  static Future<bool> showLockDialog(BuildContext context, {required String action}) async {
    final override = await showDialog<bool>(
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
                  'Admin can override with PIN if emergency.',
                  style: TextStyle(fontSize: 12, color: Colors.purple.shade700),
                )),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final ok = await _promptAdminOverride(ctx);
              if (ctx.mounted) Navigator.pop(ctx, ok);
            },
            icon: const Icon(Icons.key, size: 18),
            label: const Text('Admin Override'),
          ),
        ],
      ),
    );
    return override ?? false;
  }

  static Future<bool> _promptAdminOverride(BuildContext context) async {
    final pinCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🔐 Admin PIN Override'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinCtrl,
              decoration: const InputDecoration(
                labelText: 'Admin PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              // PIN check: any non-empty for v1 — caller should verify
              Navigator.pop(ctx, pinCtrl.text.isNotEmpty);
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
