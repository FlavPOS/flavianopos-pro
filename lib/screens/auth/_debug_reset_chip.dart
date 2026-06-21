import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/database_helper.dart';

class DebugResetChip extends StatelessWidget {
  const DebugResetChip({super.key});

  Future<void> _factoryReset(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Factory Reset?'),
        content: const Text(
          'This wipes ALL local users, branches, products, sales, and Firebase setup. Use only for testing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Wipe Everything'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final db = await DatabaseHelper().database;
      final tables = [
        'users','branches','products','batches','transactions',
        'transaction_items','customers','companies_cache','sync_queue',
        'employees','batch_logs','adjustment_records','stock_transfers',
        'transfer_items','transfer_ledger','delivery_records',
        'delivery_items','discount_records','discount_items','expenses',
        'expense_categories','expense_sub_categories','cashier_sessions',
        'denomination_records','incident_reports','z_reports','exchanges',
      ];
      for (final t in tables) {
        try { await db.delete(t); } catch (_) {}
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('Wiped. Refresh now or close & reopen the preview.'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: ActionChip(
        backgroundColor: Colors.red.shade900.withValues(alpha: 0.6),
        label: const Text(
          '🔧 Factory Reset',
          style: TextStyle(color: Colors.white, fontSize: 11),
        ),
        onPressed: () => _factoryReset(context),
      ),
    );
  }
}
