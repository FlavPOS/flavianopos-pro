import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/database_helper.dart';

class DebugResetChip extends StatelessWidget {
  const DebugResetChip({super.key});

  // Keys we PRESERVE — Firebase config only.
  // Device assignment is CLEARED so user re-picks branch.
  static const _preserveKeys = {
    'setupMode',
    'setupModeSelectedAt',
    'firebaseConfigJson',
    'firebaseConfigLocked',
    'deviceId',
  };

  Future<void> _factoryReset(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('🧹 Smart Reset?'),
        content: const Text(
          'This wipes:\n'
          '  • Local users, branches, sales, products, etc.\n'
          '  • Device assignment to current branch\n\n'
          'Keeps:\n'
          '  • Firebase config (no need to retype)\n'
          '  • Device ID\n\n'
          'After reset → app routes back to Branch Selector\n'
          'so you can re-pick which branch this device serves.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Wipe + Re-pick Branch'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      // 1) Wipe ALL local tables (including users + branches)
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

      // 2) Wipe SharedPreferences EXCEPT Firebase config keys
      // This INCLUDES wiping the DeviceAssignmentService keys,
      // which forces the app to route back to Branch Selector on next boot.
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (!_preserveKeys.contains(key)) {
          await prefs.remove(key);
        }
      }

      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('🧹 Wiped. Refresh → goes to Branch Selector.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ));
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _nuclearReset(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('💥 NUCLEAR Reset?'),
        content: const Text(
          'This wipes EVERYTHING:\n'
          '  • All local data\n'
          '  • Firebase config\n'
          '  • Device ID\n'
          '  • setupMode (back to Solo/Multiple choice)\n\n'
          'Use only to re-do the wizard from scratch.\n'
          'Cloud data in Firebase is NOT touched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('NUKE IT'),
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
        content: Text('💥 Nuked. Refresh to restart from Select Store Setup.'),
        backgroundColor: Colors.red,
      ));
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      icon: const Icon(Icons.build, color: Colors.red, size: 18),
      tooltip: 'Debug Tools',
      onSelected: (v) {
        if (v == 'smart') _factoryReset(context);
        if (v == 'nuke') _nuclearReset(context);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'smart',
          child: ListTile(
            leading: Icon(Icons.cleaning_services, color: Colors.orange),
            title: Text('🧹 Smart Reset', style: TextStyle(fontSize: 13)),
            subtitle: Text('Wipe local, re-pick branch', style: TextStyle(fontSize: 10)),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'nuke',
          child: ListTile(
            leading: Icon(Icons.warning, color: Colors.red),
            title: Text('💥 Nuclear Reset', style: TextStyle(fontSize: 13)),
            subtitle: Text('Wipe EVERYTHING incl. Firebase config', style: TextStyle(fontSize: 10)),
            dense: true,
          ),
        ),
      ],
    );
  }
}
