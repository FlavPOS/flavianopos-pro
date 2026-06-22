import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:uuid/uuid.dart';
import '../../helpers/database_helper.dart';
import '../../helpers/firebase_to_sqlite_mirror.dart';
import '../../helpers/sync_queue_dao.dart';
import '../../helpers/cache_reload_helper.dart';
import '../../models/sync_queue_model.dart';
import '../../models/user_model.dart';
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

  final _branchName = TextEditingController();
  final _branchAddress = TextEditingController();
  final _branchPhone = TextEditingController();
  final _newAdminUsername = TextEditingController();
  final _newAdminFullName = TextEditingController();
  final _newAdminPin = TextEditingController();
  final _newAdminConfirmPin = TextEditingController();
  bool _saving = false;
  bool _showPw = false;

  Future<void> _onCreate() async {
    // ---- Validation ----
    if (_branchName.text.trim().isEmpty) {
      _snack('Enter the branch name.'); return;
    }
    if (_newAdminUsername.text.trim().isEmpty) {
      _snack('Enter the new branch admin username.'); return;
    }
    if (_newAdminFullName.text.trim().isEmpty) {
      _snack('Enter the admin full name.'); return;
    }
    if (_newAdminPin.text.length != 6) {
      _snack('PIN must be exactly 6 digits.'); return;
    }
    if (_newAdminPin.text != _newAdminConfirmPin.text) {
      _snack('PINs do not match.'); return;
    }

    setState(() => _saving = true);
    try {
      final cfgSvc = FirebaseConfigService();
      final cfg = await cfgSvc.load();
      if (cfg == null) throw Exception('Firebase config missing.');
      final companyCode = cfg.companyCode;
      final lookup = CompanyLookupService();
      final deviceId = await DeviceIdService().getOrCreate();

      // Also check locally
      final db = await DatabaseHelper().database;
      final localTaken = await db.rawQuery(
        'SELECT id FROM users WHERE LOWER(username) = LOWER(?) LIMIT 1',
        [_newAdminUsername.text.trim()],
      );
      if (localTaken.isNotEmpty) {
        throw Exception('Username "${_newAdminUsername.text.trim()}" is already used on THIS device. (Each branch can have its own admin — this error only fires if you try to create the same username twice on the same device.)');
      }

      // ---- Mirror existing company + branches ----
      final mirror = FirebaseToSqliteMirror();
      try {
        final profile = await lookup.fetchCompanyProfile(companyCode) ?? {};
        await mirror.mirrorCompany(profile: profile, companyCode: companyCode, deviceId: deviceId);
        final existing = await lookup.fetchBranches(companyCode);
        await mirror.mirrorBranches(branches: existing, companyCode: companyCode, deviceId: deviceId);
      } catch (_) {}

      // ---- 1) CREATE THE BRANCH ----
      final newBranchId = const Uuid().v4();
      final now = DateTime.now().toUtc().toIso8601String();
      final branchPayload = {
        'branchId': newBranchId,
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
        'isDeleted': false,
      };

      await db.insert('branches', {
        'id': newBranchId,
        'name': _branchName.text.trim(),
        'address': _branchAddress.text.trim(),
        'phone': _branchPhone.text.trim(),
        'isActive': 1,
        'email': '',
        'manager': _newAdminFullName.text.trim(),
        'createdDate': now,
        'imagePath': null,
        'syncStatus': SyncStatus.pending,
        'lastModifiedAt': now,
        'lastSyncedAt': '',
        'firebaseId': newBranchId,
        'firebasePath': 'companies/$companyCode/branches/$newBranchId',
        'companyId': companyCode,
        'branchId_sync': newBranchId,
        'deviceId': deviceId,
        'createdBy_sync': _newAdminUsername.text.trim(),
        'updatedBy_sync': _newAdminUsername.text.trim(),
        'isDeleted': 0,
        'isMainBranch': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await SyncQueueDao().enqueue(
        entityType: 'branch', entityId: newBranchId, operation: SyncOp.create,
        firebasePath: 'companies/$companyCode/branches/$newBranchId',
        payload: branchPayload, companyId: companyCode, branchId: newBranchId,
        deviceId: deviceId, priority: SyncPriority.p1Critical,
      );

      try {
        await lookup.writeBranch(companyCode: companyCode, branchId: newBranchId, payload: branchPayload);
        await db.update('branches',
            {'syncStatus': SyncStatus.synced, 'lastSyncedAt': DateTime.now().toUtc().toIso8601String()},
            where: 'id = ?', whereArgs: [newBranchId]);
        await db.update('sync_queue',
            {'status': SyncStatus.synced, 'updatedAt': DateTime.now().toUtc().toIso8601String()},
            where: 'entityType = ? AND entityId = ?', whereArgs: ['branch', newBranchId]);
      } catch (_) {}

      // ---- 2) CREATE THE NEW BRANCH ADMIN USER ----
      final newAdminUserId = 'USR-${const Uuid().v4().substring(0, 8).toUpperCase()}';
      final perms = AppUser.rolePresets['Manager'] ?? <String>[];
      final newAdmin = AppUser(
        id: newAdminUserId,
        name: _newAdminFullName.text.trim(),
        username: _newAdminUsername.text.trim(),
        pin: _newAdminPin.text,
        email: '',
        phone: '',
        role: 'Manager',
        branch: _branchName.text.trim(),
        joinDate: DateTime.now(),
        lastLogin: null,
        isActive: true,
        permissions: perms,
      );
      AppUser.addUser(newAdmin);   // 🎯 canonical — SyncBridge auto-syncs to Firebase
      await Future.delayed(const Duration(milliseconds: 80));

      // Patch sync metadata on the just-inserted row
      await db.update('users', {
        'syncStatus': SyncStatus.pending,
        'lastModifiedAt': now,
        'firebaseId': newAdminUserId,
        'firebasePath': 'companies/$companyCode/users/$newAdminUserId',
        'companyId': companyCode,
        'branchId_sync': newBranchId,
        'deviceId': deviceId,
        'createdBy_sync': 'setup',
        'updatedBy_sync': 'setup',
        'isDeleted': 0,
      }, where: 'id = ?', whereArgs: [newAdminUserId]);

      // ---- 3) ASSIGN THIS DEVICE TO THE NEW BRANCH ----
      await DeviceAssignmentService().assign(
        companyId: companyCode,
        companyCode: companyCode,
        branchId: newBranchId,
        branchName: _branchName.text.trim(),
        role: 'Manager',
      );

      // ---- 4) REGISTER DEVICE ----
      try {
        await lookup.registerDevice(
          companyCode: companyCode, deviceId: deviceId,
          branchId: newBranchId, branchName: _branchName.text.trim(),
          role: 'Manager',
          userId: newAdminUserId,
          username: _newAdminUsername.text.trim(),
        );
      } catch (_) {}

      await cfgSvc.lock();
      await CacheReloadHelper.reloadAll();

      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('🎉 New Branch Ready!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Branch "${_branchName.text.trim()}" is live.', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('This device is now assigned to it.'),
            const SizedBox(height: 12),
            const Text('Login as the new branch admin:', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 4),
            Text('• Username: ${_newAdminUsername.text.trim()}'),
            const Text('• PIN: (the one you just typed)'),
          ],
        ),
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
      appBar: AppBar(
        backgroundColor: _purple, foregroundColor: Colors.white,
        title: const Text('Add New Branch'),
      ),
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(padding: const EdgeInsets.all(22), child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.add_business_outlined, size: 56, color: _purple),
                const SizedBox(height: 8),
                const Text('Set Up a New Branch', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _purple)),
                const SizedBox(height: 4),
                const Text(
                  'Create the branch and its first admin in one step. This device will be assigned to the new branch.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 18),

                // ── Branch section ──
                _section('Branch Details'),
                _field(_branchName, 'Branch Name * (e.g. Lapu-Lapu Branch)', Icons.store_outlined),
                _field(_branchAddress, 'Address', Icons.location_on_outlined),
                _field(_branchPhone, 'Phone', Icons.phone_outlined,
                    keyboardType: TextInputType.phone),

                const SizedBox(height: 14),
                _section('New Branch Admin'),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('A fresh admin account that controls this branch.',
                      style: TextStyle(fontSize: 11, color: Colors.black54)),
                ),
                _field(_newAdminFullName, 'Full Name *', Icons.badge_outlined),
                _field(_newAdminUsername, 'Username *', Icons.alternate_email),
                _field(_newAdminPin, 'PIN (6 digits) *', Icons.lock_outline,
                    obscure: !_showPw, keyboardType: TextInputType.number,
                    suffix: IconButton(
                      icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showPw = !_showPw),
                    )),
                _field(_newAdminConfirmPin, 'Confirm PIN *', Icons.lock_reset,
                    obscure: !_showPw, keyboardType: TextInputType.number),

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
                  label: Text(_saving ? 'Creating...' : 'Create Branch & Admin'),
                )),
              ]),
            ),
          ),
        ),
      ))),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11, color: _purple,
          fontWeight: FontWeight.bold, letterSpacing: 1.1,
        )),
  );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool obscure = false, Widget? suffix, TextInputType? keyboardType}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _purple),
        suffixIcon: suffix,
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _purple, width: 1.5)),
      ),
    ),
  );
}
