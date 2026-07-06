import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:uuid/uuid.dart';
import '../../helpers/database_helper.dart';
import '../../helpers/firebase_to_sqlite_mirror.dart';
import '../../helpers/sync_queue_dao.dart';
import '../../helpers/cache_reload_helper.dart';
import '../../models/sync_queue_model.dart';
import '../../models/user_model.dart';
import '../../models/branch_model.dart';
import '../../services/company_lookup_service.dart';
import '../../services/device_assignment_service.dart';
import '../../services/device_id_service.dart';
import '../../services/firebase_config_service.dart';
import '../../utils/uppercase_text_formatter.dart';
import '../auth/login_screen.dart';

class AddNewBranchScreen extends StatefulWidget {
  const AddNewBranchScreen({super.key});
  @override
  State<AddNewBranchScreen> createState() => _AddNewBranchScreenState();
}

class _AddNewBranchScreenState extends State<AddNewBranchScreen> {
  static const Color _purple = Color(0xFF6A1B9A);
  static const Color _lightPurple = Color(0xFFEDE7F6);

  final _branchCode = TextEditingController();
  final _branchName = TextEditingController();
  final _branchAddress = TextEditingController();
  final _branchPhone = TextEditingController();
  final _newAdminUsername = TextEditingController();
  final _newAdminFullName = TextEditingController();
  final _newAdminPin = TextEditingController();
  final _newAdminConfirmPin = TextEditingController();
  String _branchType = Branch.typeHeadOffice; // Default: first branch = Head Office
  bool _saving = false;
  bool _showPw = false;

  @override
  void initState() {
    super.initState();
    _autoGenerateCode();
  }

  void _autoGenerateCode() {
    switch (_branchType) {
      case 'HEAD_OFFICE': _branchCode.text = 'HO001'; break;
      case 'WAREHOUSE': _branchCode.text = 'WH001'; break;
      default: _branchCode.text = 'BR001'; break;
    }
  }

  @override
  void dispose() {
    _branchCode.dispose();
    _branchName.dispose();
    _branchAddress.dispose();
    _branchPhone.dispose();
    _newAdminUsername.dispose();
    _newAdminFullName.dispose();
    _newAdminPin.dispose();
    _newAdminConfirmPin.dispose();
    super.dispose();
  }

  Future<void> _onCreate() async {
    final code = _branchCode.text.trim().toUpperCase();

    // ⭐ Branch Code Validation
    final codeError = Branch.validateBranchCode(code);
    if (codeError != null) { _snack(codeError); return; }

    if (_branchName.text.trim().isEmpty) { _snack('Enter the branch name.'); return; }
    if (_newAdminUsername.text.trim().isEmpty) { _snack('Enter the new branch admin username.'); return; }
    if (_newAdminFullName.text.trim().isEmpty) { _snack('Enter the admin full name.'); return; }
    if (_newAdminPin.text.length != 6) { _snack('PIN must be exactly 6 digits.'); return; }
    if (_newAdminPin.text != _newAdminConfirmPin.text) { _snack('PINs do not match.'); return; }

    setState(() => _saving = true);
    try {
      final cfgSvc = FirebaseConfigService();
      final cfg = await cfgSvc.load();
      if (cfg == null) throw Exception('Firebase config missing.');
      final companyCode = cfg.companyCode;
      final lookup = CompanyLookupService();
      final deviceId = await DeviceIdService().getOrCreate();

      // ⭐ Check Branch Code uniqueness in Firebase
      try {
        final existing = await lookup.fetchBranches(companyCode);
        final exists = existing.any((b) =>
            ((b['branchCode'] ?? '').toString().toUpperCase() == code) ||
            ((b['branchId'] ?? '').toString().toUpperCase() == code));
        if (exists) throw Exception('Branch Code "$code" already exists in this company!');
      } catch (e) {
        if (e.toString().contains('already exists')) rethrow;
        // Ignore other errors (device may be offline)
      }

      final db = await DatabaseHelper().database;
      final localTaken = await db.rawQuery(
        'SELECT id FROM users WHERE LOWER(username) = LOWER(?) LIMIT 1',
        [_newAdminUsername.text.trim()],
      );
      if (localTaken.isNotEmpty) {
        throw Exception('Username "${_newAdminUsername.text.trim()}" already used on this device.');
      }

      final mirror = FirebaseToSqliteMirror();
      try {
        final profile = await lookup.fetchCompanyProfile(companyCode) ?? {};
        await mirror.mirrorCompany(profile: profile, companyCode: companyCode, deviceId: deviceId);
        final existing = await lookup.fetchBranches(companyCode);
        await mirror.mirrorBranches(branches: existing, companyCode: companyCode, deviceId: deviceId);
      } catch (_) {}

      // ⭐ USE BRANCH CODE AS ID (not UUID!)
      final newBranchId = code;
      final now = DateTime.now().toUtc().toIso8601String();
      final isHeadOffice = _branchType == Branch.typeHeadOffice;

      final branchPayload = {
        'branchId': newBranchId,
        'companyCode': companyCode,
        'branchCode': code,
        'branchName': _branchName.text.trim(),
        'branchType': _branchType,
        'address': _branchAddress.text.trim(),
        'phone': _branchPhone.text.trim(),
        'isMainBranch': isHeadOffice,
        'isActive': true,
        'createdAt': now,
        'updatedAt': now,
        'createdByDeviceId': deviceId,
        'isDeleted': false,
      };

      await db.insert('branches', {
        'id': newBranchId,               // ⭐ CODE, NOT UUID!
        'name': _branchName.text.trim(),
        'branchType': _branchType,        // ⭐ NEW
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
        'isMainBranch': isHeadOffice ? 1 : 0,
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

      final adminRole = isHeadOffice ? 'Admin' : 'Manager';
      final newAdminUserId = 'USR-${const Uuid().v4().substring(0, 8).toUpperCase()}';
      final perms = AppUser.rolePresets[adminRole] ?? <String>[];
      final newAdmin = AppUser(
        id: newAdminUserId,
        name: _newAdminFullName.text.trim(),
        username: _newAdminUsername.text.trim(),
        pin: _newAdminPin.text,
        email: '',
        phone: '',
        role: adminRole,
        branch: _branchName.text.trim(),
        joinDate: DateTime.now(),
        lastLogin: null,
        isActive: true,
        permissions: perms,
      );
      AppUser.addUser(newAdmin);
      await Future.delayed(const Duration(milliseconds: 80));

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

      await DeviceAssignmentService().assign(
        companyId: companyCode,
        companyCode: companyCode,
        branchId: newBranchId,           // ⭐ Now HO001 or BR001!
        branchName: _branchName.text.trim(),
        role: adminRole,
      );

      try {
        await lookup.registerDevice(
          companyCode: companyCode, deviceId: deviceId,
          branchId: newBranchId, branchName: _branchName.text.trim(),
          role: adminRole,
          userId: newAdminUserId,
          username: _newAdminUsername.text.trim(),
        );
      } catch (_) {}

      await cfgSvc.lock();
      await CacheReloadHelper.reloadAll();

      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text('🎉 ${isHeadOffice ? "Head Office" : "Branch"} Ready!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$code - ${_branchName.text.trim()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('This device is now assigned to it.'),
            const SizedBox(height: 12),
            const Text('Login credentials:', style: TextStyle(color: Colors.black54)),
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
        title: const Text('Set Up Branch'),
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
                const Text('Set Up Your Location', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _purple)),
                const SizedBox(height: 4),
                const Text(
                  'Create the location (Head Office / Warehouse / Branch) and its admin. This device will be assigned to it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 18),

                // ⭐ Branch Identity Section
                _section('Location Identity'),

                // Branch Type dropdown
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _branchType,
                    decoration: InputDecoration(
                      labelText: 'Location Type *',
                      prefixIcon: const Icon(Icons.category, color: _purple),
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _purple, width: 1.5)),
                      helperText: 'First location is usually Head Office',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'HEAD_OFFICE', child: Text('🏢 Head Office / Main Warehouse')),
                      DropdownMenuItem(value: 'WAREHOUSE', child: Text('🏭 Warehouse')),
                      DropdownMenuItem(value: 'BRANCH', child: Text('🏪 Branch / Store')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _branchType = v;
                        _autoGenerateCode();
                      });
                    },
                  ),
                ),

                // Branch Code field
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _branchCode,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
                      LengthLimitingTextInputFormatter(20),
                      UpperCaseTextFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Location Code *',
                      hintText: 'HO001',
                      helperText: 'Example: HO001 (Head Office), BR001 (Branch), WH001 (Warehouse)',
                      prefixIcon: const Icon(Icons.qr_code_2, color: _purple),
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _purple, width: 1.5)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh, color: _purple),
                        tooltip: 'Auto-generate code',
                        onPressed: _autoGenerateCode,
                      ),
                    ),
                  ),
                ),

                _section('Location Details'),
                _field(_branchName, 'Location Name * (e.g. Head Office)', Icons.store_outlined),
                _field(_branchAddress, 'Address', Icons.location_on_outlined),
                _field(_branchPhone, 'Phone', Icons.phone_outlined,
                    keyboardType: TextInputType.phone),

                const SizedBox(height: 14),
                _section('Admin Account'),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('This admin will control this location and can add cashiers later.',
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
                  label: Text(_saving ? 'Creating...' : 'Create Location & Admin'),
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
