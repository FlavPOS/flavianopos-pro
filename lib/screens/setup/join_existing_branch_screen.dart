import 'package:flutter/material.dart';
import '../../helpers/database_helper.dart';
import '../../helpers/firebase_to_sqlite_mirror.dart';
import '../../helpers/cache_reload_helper.dart';
import '../../models/user_model.dart';
import '../../services/company_lookup_service.dart';
import '../../services/device_assignment_service.dart';
import '../../services/device_id_service.dart';
import '../../services/firebase_config_service.dart';
import '../../services/firebase_realtime_service.dart';
import '../auth/login_screen.dart';

class JoinExistingBranchScreen extends StatefulWidget {
  const JoinExistingBranchScreen({super.key});
  @override
  State<JoinExistingBranchScreen> createState() => _JoinExistingBranchScreenState();
}

class _JoinExistingBranchScreenState extends State<JoinExistingBranchScreen> {
  static const Color _purple = Color(0xFF6A1B9A);
  static const Color _lightPurple = Color(0xFFEDE7F6);

  final _lookup = CompanyLookupService();
  final _cfgSvc = FirebaseConfigService();
  final _deviceIdSvc = DeviceIdService();
  final _assignSvc = DeviceAssignmentService();
  final _mirror = FirebaseToSqliteMirror();

  final _username = TextEditingController();
  final _pin = TextEditingController();
  bool _showPw = false;
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final cfg = await _cfgSvc.load();
      if (cfg == null) throw Exception('Firebase config missing.');
      final list = await _lookup.fetchBranches(cfg.companyCode);
      if (!mounted) return;
      setState(() {
        _branches = list;
        _loading = false;
        if (_branches.isNotEmpty) {
          _selectedBranchId = _branches.first['branchId']?.toString();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  /// Find user locally (case-insensitive)
  Future<Map<String, dynamic>?> _findUserLocally(String username, String pin) async {
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.rawQuery(
        'SELECT * FROM users WHERE LOWER(username) = LOWER(?) AND password = ? AND isActive = 1 LIMIT 1',
        [username, pin],
      );
      if (rows.isEmpty) return null;
      final u = rows.first;
      return {
        'userId': u['id'],
        'username': u['username'],
        'fullName': u['fullName'],
        'role': u['role'],
        'companyId': u['companyId'] ?? '',
        'branchId': u['branchId_sync'] ?? '',
        'branchName': u['branch'] ?? '',
        'email': u['email'] ?? '',
        'phone': u['phone'] ?? '',
        'isCompanyAdmin': u['role'] == 'Admin',
        'permissions': u['permissions'] ?? '',
      };
    } catch (_) { return null; }
  }

  /// 🎯 KEY FIX: Write the Firebase user into local SQLite using AppUser.addUser()
  /// This is what was missing — without it, the user exists in Firebase but
  /// Login.authenticateUser() can't find them locally.
  Future<void> _writeUserToLocalDb({
    required Map<String, dynamic> fbUser,
    required String typedPin,
  }) async {
    final db = await DatabaseHelper().database;
    final username = (fbUser['username'] ?? '').toString();
    final role = (fbUser['role'] ?? 'cashier').toString();
    // Normalize old data: "companyAdmin" → "Admin"
    final normalizedRole = role.toLowerCase() == 'companyadmin' ? 'Admin' : role;

    // Get permissions list (handle both array and string formats)
    final permsRaw = fbUser['permissions'];
    final List<String> perms;
    if (permsRaw is List) {
      perms = permsRaw.map((e) => e.toString()).toList();
    } else if (permsRaw is String && permsRaw == 'all') {
      perms = AppUser.rolePresets['Admin'] ?? <String>[];
    } else {
      perms = AppUser.rolePresets[normalizedRole] ??
              AppUser.rolePresets['Admin'] ?? <String>[];
    }

    // Remove any existing row with same username (case-insensitive)
    await db.rawDelete('DELETE FROM users WHERE LOWER(username) = LOWER(?)', [username]);
    AppUser.allUsers.removeWhere((u) => u.username.toLowerCase() == username.toLowerCase());

    // Build the AppUser and use the canonical addUser() pattern
    final newUser = AppUser(
      id: (fbUser['userId'] ?? 'USR-${DateTime.now().millisecondsSinceEpoch}').toString(),
      name: (fbUser['fullName'] ?? '').toString(),
      username: username,
      pin: typedPin,                  // ← typed PIN becomes the local PIN/password
      email: (fbUser['email'] ?? '').toString(),
      phone: (fbUser['phone'] ?? '').toString(),
      role: normalizedRole,
      branch: (fbUser['branchName'] ?? '').toString(),
      joinDate: DateTime.now(),
      lastLogin: null,
      isActive: true,
      permissions: perms,
    );

    AppUser.addUser(newUser);
    // Give a moment for async insertUser to flush
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _selfHealUploadUser({
    required Map<String, dynamic> user,
    required String companyCode,
    required String branchId,
  }) async {
    try {
      final fbDb = FirebaseRealtimeService.instance.db;
      if (fbDb == null) return;
      final userId = (user['userId'] ?? '').toString();
      if (userId.isEmpty) return;
      final payload = {
        'userId': userId,
        'companyCode': companyCode,
        'username': user['username'],
        'fullName': user['fullName'],
        'role': user['role'],
        'branchId': branchId,
        'branchName': user['branchName'],
        'email': user['email'],
        'phone': user['phone'],
        'permissions': user['permissions'],
        'isMainBranchUser': true,
        'isCompanyAdmin': true,
        'isActive': true,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'isDeleted': false,
      };
      await fbDb.ref('companies/$companyCode/users/$userId').update(payload);
      await fbDb.ref('companies/$companyCode/usersByBranch/$branchId/$userId').update(payload);
    } catch (_) {}
  }

  Future<void> _onJoin() async {
    if (_selectedBranchId == null) { _snack('Select a branch.'); return; }
    if (_username.text.trim().isEmpty || _pin.text.isEmpty) {
      _snack('Enter username and PIN.'); return;
    }
    setState(() => _saving = true);
    try {
      final cfg = await _cfgSvc.load();
      if (cfg == null) throw Exception('Firebase config missing.');
      final companyCode = cfg.companyCode;
      final usernameTyped = _username.text.trim();
      final pin = _pin.text.trim();
      final deviceId = await _deviceIdSvc.getOrCreate();
      final myBranchId = _selectedBranchId!;

      // 1) Try Firebase (case-insensitive)
      Map<String, dynamic>? me;
      try {
        final allUsers = await _lookup.fetchAllUsers(companyCode);
        final candidates = allUsers.where((u) =>
          ((u['username'] ?? '').toString().toLowerCase()) ==
          usernameTyped.toLowerCase()).toList();
        if (candidates.isNotEmpty) me = candidates.first;
      } catch (_) {}

      // 2) Fallback to local SQLite
      me ??= await _findUserLocally(usernameTyped, pin);

      if (me == null) {
        throw Exception(
            'Username "$usernameTyped" not found.\nTip: ask admin to confirm your account, or run wizard fresh.');
      }

      // 3) Check permission to join selected branch (admins can join any)
      final hisBranchId = (me['branchId'] ?? '').toString();
      final isAdmin = (me['isCompanyAdmin'] == true) ||
          (me['isMainBranchUser'] == true) ||
          ((me['role'] ?? '').toString().toLowerCase() == 'admin') ||
          ((me['role'] ?? '').toString().toLowerCase() == 'companyadmin');
      if (!isAdmin && hisBranchId.isNotEmpty && hisBranchId != myBranchId) {
        throw Exception('You can only join your assigned branch.');
      }

      // 4) 🎯 KEY: Write user to local SQLite with the typed PIN
      await _writeUserToLocalDb(fbUser: me, typedPin: pin);

      // 5) Mirror company + branches
      try {
        final profile = await _lookup.fetchCompanyProfile(companyCode) ?? {};
        await _mirror.mirrorCompany(profile: profile, companyCode: companyCode, deviceId: deviceId);
        await _mirror.mirrorBranches(branches: _branches, companyCode: companyCode, deviceId: deviceId);
      } catch (_) {}

      // 6) Self-heal: refresh Firebase user record with normalized role
      await _selfHealUploadUser(user: me, companyCode: companyCode, branchId: myBranchId);

      // 7) Save device assignment
      final selBranch = _branches.firstWhere(
          (b) => (b['branchId'] ?? '') == myBranchId,
          orElse: () => {'branchName': 'Branch'});
      await _assignSvc.assign(
        companyId: (me['companyId'] ?? '').toString(),
        companyCode: companyCode,
        branchId: myBranchId,
        branchName: (selBranch['branchName'] ?? '').toString(),
        role: (me['role'] ?? 'cashier').toString(),
      );

      // 8) Register device
      try {
        await _lookup.registerDevice(
          companyCode: companyCode, deviceId: deviceId,
          branchId: myBranchId,
          branchName: (selBranch['branchName'] ?? '').toString(),
          role: (me['role'] ?? 'cashier').toString(),
          userId: (me['userId'] ?? '').toString(),
          username: usernameTyped,
        );
      } catch (_) {}

      await _cfgSvc.lock();
      await CacheReloadHelper.reloadAll();

      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Joined successfully 🎉'),
        content: Text(
          'This device is now assigned to "${selBranch['branchName']}".\n\n'
          'Login with:\nUsername: $usernameTyped\nPIN: (the one you just typed)',
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _lightPurple,
    appBar: AppBar(backgroundColor: _purple, foregroundColor: Colors.white,
        title: const Text('Join Existing Branch')),
    body: SafeArea(child: _loading
      ? const Center(child: CircularProgressIndicator(color: _purple))
      : _error != null ? _errorView() : _form()),
  );

  Widget _errorView() => Padding(padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: Colors.red, size: 56),
      const SizedBox(height: 12),
      Text(_error!, textAlign: TextAlign.center),
    ]));

  Widget _form() => Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
      child: Card(elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.storefront, size: 56, color: _purple),
            const SizedBox(height: 8),
            const Text('Select your branch', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _purple)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedBranchId,
              items: _branches.map((b) {
                final id = (b['branchId'] ?? '').toString();
                final n = (b['branchName'] ?? '').toString();
                final main = (b['isMainBranch'] == true) ? ' ⭐' : '';
                return DropdownMenuItem(value: id, child: Text('$n$main'));
              }).toList(),
              onChanged: (v) => setState(() => _selectedBranchId = v),
              decoration: const InputDecoration(
                labelText: 'Branch *',
                prefixIcon: Icon(Icons.store_outlined, color: _purple),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(controller: _username, decoration: const InputDecoration(
              labelText: 'Username *',
              prefixIcon: Icon(Icons.alternate_email, color: _purple),
              border: OutlineInputBorder(),
            )),
            const SizedBox(height: 10),
            TextField(controller: _pin, obscureText: !_showPw,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'PIN *',
                prefixIcon: const Icon(Icons.lock_outline, color: _purple),
                suffixIcon: IconButton(
                  icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPw = !_showPw),
                ),
                border: const OutlineInputBorder(),
              )),
            const SizedBox(height: 20),
            SizedBox(height: 52, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _saving ? null : _onJoin,
              icon: _saving
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Icon(Icons.login),
              label: Text(_saving ? 'Joining...' : 'Join Branch'),
            )),
            const SizedBox(height: 10),
            const Text('Your PIN is stored locally on this device for offline login.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.black54)),
          ]),
        ),
      ),
    ),
  ));
}
