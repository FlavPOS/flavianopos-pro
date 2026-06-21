import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:uuid/uuid.dart';
import '../../helpers/database_helper.dart';
import '../../helpers/firebase_to_sqlite_mirror.dart';
import '../../helpers/sync_queue_dao.dart';
import '../../helpers/cache_reload_helper.dart';
import '../../models/sync_queue_model.dart';
import '../../services/company_lookup_service.dart';
import '../../services/device_assignment_service.dart';
import '../../services/device_id_service.dart';
import '../../services/firebase_config_service.dart';
import '../auth/login_screen.dart';

class AddNewBranchScreen extends StatefulWidget {
  const AddNewBranchScreen({super.key});
  @override
  State<AddNewBranchScreen> createState() => _AddNewBranchScreenState();
}

class _AddNewBranchScreenState extends State<AddNewBranchScreen> {
  static const Color _purple = Color(0xFF6A1B9A);
  static const Color _lightPurple = Color(0xFFEDE7F6);

  final _adminUsername = TextEditingController();
  final _adminPin = TextEditingController();
  final _branchName = TextEditingController();
  final _branchAddress = TextEditingController();
  final _branchPhone = TextEditingController();
  bool _saving = false;
  bool _showPw = false;

  Future<Map<String, dynamic>?> _findAdminLocally(String username, String pin) async {
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'users',
        where: 'username = ? AND password = ? AND isActive = 1',
        whereArgs: [username, pin],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final u = rows.first;
        final role = (u['role'] ?? '').toString();
        final perms = (u['permissions'] ?? '').toString();
        // Treat 'Admin' OR 'companyAdmin' OR users with 'all' permission as admins
        if (role == 'Admin' || role == 'companyAdmin' || perms.contains('admin') || perms.contains('all')) {
          return {
            'userId': u['id'],
            'username': u['username'],
            'fullName': u['fullName'],
            'role': u['role'],
            'companyId': u['companyId'] ?? '',
            'email': u['email'] ?? '',
            'phone': u['phone'] ?? '',
            'isCompanyAdmin': true,
          };
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _onCreate() async {
    if (_adminUsername.text.trim().isEmpty || _adminPin.text.isEmpty) {
      _snack('Enter admin username and PIN.'); return;
    }
    if (_branchName.text.trim().isEmpty) {
      _snack('Enter the new branch name.'); return;
    }
    setState(() => _saving = true);
    try {
      final cfgSvc = FirebaseConfigService();
      final cfg = await cfgSvc.load();
      if (cfg == null) throw Exception('Firebase config missing.');
      final companyCode = cfg.companyCode;

      final lookup = CompanyLookupService();
      final username = _adminUsername.text.trim();
      final pin = _adminPin.text.trim();

      // 1) Try Firebase lookup first
      Map<String, dynamic>? admin;
      try {
        final allUsers = await lookup.fetchAllUsers(companyCode);
        final firebaseAdmins = allUsers.where((u) =>
            (u['username'] ?? '') == username &&
            ((u['isCompanyAdmin'] == true) ||
                (u['isMainBranchUser'] == true) ||
                ((u['role'] ?? '').toString() == 'companyAdmin') ||
                ((u['role'] ?? '').toString() == 'Admin'))).toList();
        if (firebaseAdmins.isNotEmpty) admin = firebaseAdmins.first;
      } catch (_) {
        // Firebase unreachable — fall back to local
      }

      // 2) Fall back to local SQLite if Firebase didn't have it
      admin ??= await _findAdminLocally(username, pin);

      if (admin == null) {
        debugPrint('🔍 Path C lookup result: admin=$admin, username=$username'); throw Exception('Admin "$username" not found or lacks permission.\nTip: use the username from the original wizard.');
      }

      // 3) Verify PIN locally (Firebase doesn't store the PIN for security)
      final db = await DatabaseHelper().database;
      final pinCheck = await db.query(
        'users',
        where: 'username = ? AND password = ? AND isActive = 1',
        whereArgs: [username, pin],
        limit: 1,
      );
      if (pinCheck.isEmpty) {
        throw Exception('Wrong PIN for "$username".');
      }

      // 4) Proceed to create the branch
      final deviceId = await DeviceIdService().getOrCreate();
      final mirror = FirebaseToSqliteMirror();
      try {
        final profile = await lookup.fetchCompanyProfile(companyCode) ?? {};
        await mirror.mirrorCompany(profile: profile, companyCode: companyCode, deviceId: deviceId);
        final existing = await lookup.fetchBranches(companyCode);
        await mirror.mirrorBranches(branches: existing, companyCode: companyCode, deviceId: deviceId);
      } catch (_) {}

      final newId = const Uuid().v4();
      final now = DateTime.now().toUtc().toIso8601String();
      final payload = {
        'branchId': newId,
        'companyId': (admin['companyId'] ?? '').toString(),
        'companyCode': companyCode,
        'branchCode': _branchName.text.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '-'),
        'branchName': _branchName.text.trim(),
        'address': _branchAddress.text.trim(),
        'phone': _branchPhone.text.trim(),
        'isMainBranch': false,
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
        'createdByDeviceId': deviceId,
        'createdByUserId': (admin['userId'] ?? '').toString(),
        'createdByUsername': username,
        'isDeleted': false,
      };

      await db.insert('branches', {
        'id': newId, 'name': _branchName.text.trim(),
        'address': _branchAddress.text.trim(), 'phone': _branchPhone.text.trim(),
        'isActive': 1, 'email': '', 'manager': '',
        'createdDate': now, 'imagePath': null,
        'syncStatus': SyncStatus.pending,
        'lastModifiedAt': now, 'lastSyncedAt': '',
        'firebaseId': newId,
        'firebasePath': 'companies/$companyCode/branches/$newId',
        'companyId': companyCode, 'branchId_sync': newId,
        'deviceId': deviceId,
        'createdBy_sync': username, 'updatedBy_sync': username,
        'isDeleted': 0, 'isMainBranch': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await SyncQueueDao().enqueue(
        entityType: 'branch', entityId: newId, operation: SyncOp.create,
        firebasePath: 'companies/$companyCode/branches/$newId',
        payload: payload, companyId: companyCode, branchId: newId,
        deviceId: deviceId, priority: SyncPriority.p1Critical,
      );

      try {
        await lookup.writeBranch(companyCode: companyCode, branchId: newId, payload: payload);
        await db.update('branches',
            {'syncStatus': SyncStatus.synced, 'lastSyncedAt': DateTime.now().toUtc().toIso8601String()},
            where: 'id = ?', whereArgs: [newId]);
        await db.update('sync_queue',
            {'status': SyncStatus.synced, 'updatedAt': DateTime.now().toUtc().toIso8601String()},
            where: 'entityType = ? AND entityId = ?', whereArgs: ['branch', newId]);
      } catch (_) {
        // Will retry via SyncManager in Step 6
      }

      await DeviceAssignmentService().assign(
        companyId: (admin['companyId'] ?? '').toString(),
        companyCode: companyCode, branchId: newId,
        branchName: _branchName.text.trim(), role: 'Admin',
      );

      await cfgSvc.lock();
      await CacheReloadHelper.reloadAll();

      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('New Branch Created 🎉'),
        content: Text('Branch "${_branchName.text.trim()}" is live. This device is assigned to it.'),
        actions: [ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx), child: const Text('Go to Login'),
        )],
      ));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _snack('$e');
      setState(() => _saving = false);
    }
  }

  void _snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightPurple,
      appBar: AppBar(backgroundColor: _purple, foregroundColor: Colors.white,
          title: const Text('Add New Branch')),
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(padding: const EdgeInsets.all(20), child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.add_business_outlined, size: 56, color: _purple),
                const SizedBox(height: 8),
                const Text('Admin Authorization Required', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _purple)),
                const SizedBox(height: 4),
                const Text('Only a Company Admin can create a new branch.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 16),
                TextField(controller: _adminUsername, decoration: const InputDecoration(
                  labelText: 'Admin Username *',
                  prefixIcon: Icon(Icons.admin_panel_settings, color: _purple),
                  border: OutlineInputBorder(),
                )),
                const SizedBox(height: 10),
                TextField(controller: _adminPin, obscureText: !_showPw,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Admin PIN *',
                    prefixIcon: const Icon(Icons.lock_outline, color: _purple),
                    suffixIcon: IconButton(
                      icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showPw = !_showPw),
                    ),
                    border: const OutlineInputBorder(),
                  )),
                const Divider(height: 32),
                TextField(controller: _branchName, decoration: const InputDecoration(
                  labelText: 'New Branch Name * (e.g. Cebu Branch)',
                  prefixIcon: Icon(Icons.store_outlined, color: _purple),
                  border: OutlineInputBorder(),
                )),
                const SizedBox(height: 10),
                TextField(controller: _branchAddress, decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on_outlined, color: _purple),
                  border: OutlineInputBorder(),
                )),
                const SizedBox(height: 10),
                TextField(controller: _branchPhone, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined, color: _purple),
                    border: OutlineInputBorder(),
                  )),
                const SizedBox(height: 20),
                SizedBox(height: 52, child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _saving ? null : _onCreate,
                  icon: _saving
                      ? const SizedBox(height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Creating...' : 'Create Branch'),
                )),
              ]),
            ),
          ),
        ),
      ))),
    );
  }
}
