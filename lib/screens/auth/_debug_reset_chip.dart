import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/database_helper.dart';

class DebugResetChip extends StatelessWidget {
  const DebugResetChip({super.key});

  // Keys we PRESERVE so the device stays "registered" to its company/branch
  static const _preserveKeys = {
    'setupMode',
    'setupModeSelectedAt',
    'firebaseConfigJson',
    'firebaseConfigLocked',
    'deviceId',
    'assignedCompanyId',
    'assignedCompanyCode',
    'assignedBranchId',
    'assignedBranchName',
    'assignedDeviceRole',
    'assignedAt',
  };

  Future<void> _factoryReset(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Factory Reset (smart)?'),
        content: const Text(
          'This wipes LOCAL data only:\n'
          '  • Users, branches, products, sales, batches, etc.\n\n'
          'KEEPS:\n'
          '  • Firebase config (so you stay connected)\n'
          '  • Device assignment (so SyncManager keeps working)\n\n'
          'Use this to clear local state and re-pull fresh data from Firebase.',
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
            child: const Text('Wipe Local Data'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      // 1) Wipe SQLite tables
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

      // 2) Wipe SharedPreferences EXCEPT preserved keys
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (!_preserveKeys.contains(key)) {
          await prefs.remove(key);
        }
      }

      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('🧹 Local data wiped. Firebase context preserved. Refresh to re-pull from cloud.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ));
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// 🔴 Full nuke — wipes EVERYTHING including Firebase config + setupMode.
  /// Use only if you want to re-do the wizard from scratch.
  Future<void> _nuclearReset(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('🔴 NUCLEAR Reset?'),
        content: const Text(
          'This wipes EVERYTHING:\n'
          '  • All local data\n'
          '  • Firebase config\n'
          '  • Device assignment\n'
          '  • setupMode (back to Solo/Multiple choice)\n\n'
          'Use this only to re-do the wizard from scratch.\n'
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
            subtitle: Text('Wipe local, keep Firebase', style: TextStyle(fontSize: 10)),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'nuke',
          child: ListTile(
            leading: Icon(Icons.warning, color: Colors.red),
            title: Text('💥 Nuclear Reset', style: TextStyle(fontSize: 13)),
            subtitle: Text('Wipe EVERYTHING', style: TextStyle(fontSize: 10)),
            dense: true,
          ),
        ),
      ],
    );
  }
}
