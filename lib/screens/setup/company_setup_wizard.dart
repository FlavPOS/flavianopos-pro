// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../services/multi_store_setup_service.dart';
import '../../services/device_assignment_service.dart';
import '../auth/login_screen.dart';
import '../../helpers/cache_reload_helper.dart';

class CompanySetupWizard extends StatefulWidget {
  const CompanySetupWizard({super.key});
  @override
  State<CompanySetupWizard> createState() => _CompanySetupWizardState();
}

class _CompanySetupWizardState extends State<CompanySetupWizard> {
  static const Color _purple = Color(0xFF6A1B9A);
  static const Color _lightPurple = Color(0xFFEDE7F6);

  int _step = 0;
  bool _saving = false;

  final _companyName = TextEditingController();
  final _ownerName = TextEditingController();
  final _f1 = GlobalKey<FormState>();

  final _branchName = TextEditingController(text: 'Head Office');
  final _branchAddress = TextEditingController();
  final _branchPhone = TextEditingController();
  final _f2 = GlobalKey<FormState>();

  final _adminUsername = TextEditingController();
  final _adminFullName = TextEditingController();
  final _adminPin = TextEditingController();
  final _adminConfirmPin = TextEditingController();
  bool _showPw = false;
  final _f3 = GlobalKey<FormState>();

  @override
  void dispose() {
    _companyName.dispose(); _ownerName.dispose();
    _branchName.dispose(); _branchAddress.dispose(); _branchPhone.dispose();
    _adminUsername.dispose(); _adminFullName.dispose();
    _adminPin.dispose(); _adminConfirmPin.dispose();
    super.dispose();
  }

  String? _req(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  bool _validateCurrent() {
    final k = [_f1, _f2, _f3][_step];
    return k.currentState?.validate() ?? false;
  }

  Future<void> _onFinish() async {
    if (!_validateCurrent()) return;
    if (_adminPin.text != _adminConfirmPin.text) {
      _snack('PINs do not match.'); return;
    }
    setState(() => _saving = true);
    try {
      final res = await MultiStoreSetupService().performSetup(
        companyName: _companyName.text.trim(),
        ownerName: _ownerName.text.trim(),
        mainBranchName: _branchName.text.trim(),
        mainBranchAddress: _branchAddress.text.trim(),
        mainBranchPhone: _branchPhone.text.trim(),
        adminUsername: _adminUsername.text.trim(),
        adminFullName: _adminFullName.text.trim(),
        adminPassword: _adminPin.text,
        adminPin: _adminPin.text,
      );

      if (!mounted) return;
      if (!res.success) {
        _snack(res.error ?? 'Setup failed');
        setState(() => _saving = false);
        return;
      }

      // Assign founding device locally as well.
      await DeviceAssignmentService().assign(
        companyId: res.companyId!,
        companyCode: res.companyCode!,
        branchId: res.mainBranchId!,
        branchName: _branchName.text.trim(),
        role: 'companyAdmin',
      );

      await showDialog<void>(
        context: context, barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Setup Complete 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Company Code: ${res.companyCode}'),
              const SizedBox(height: 4),
              Text('Main Branch ID: ${res.mainBranchId}'),
              const SizedBox(height: 4),
              Text('Admin User: ${_adminUsername.text}'),
              const SizedBox(height: 10),
              if (res.firebaseError != null)
                Text('⚠️ Saved locally. Firebase will retry:\n${res.firebaseError}',
                    style: const TextStyle(color: Colors.orange, fontSize: 12))
              else
                const Text('✅ Synced to Firebase.',
                    style: TextStyle(color: Colors.green, fontSize: 12)),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _purple, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      await CacheReloadHelper.reloadAll();
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

  void _snack(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final maxW = isTablet ? 640.0 : 460.0;
    return Scaffold(
      backgroundColor: _lightPurple,
      appBar: AppBar(
        backgroundColor: _purple, foregroundColor: Colors.white,
        title: Text('Company Setup (${_step + 1} of 3)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 0) {
              Navigator.of(context).maybePop();
            } else {
              setState(() => _step--);
            }
          },
        ),
      ),
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Card(
            elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(padding: EdgeInsets.all(isTablet ? 28 : 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _progress(),
                const SizedBox(height: 16),
                if (_step == 0) _step1(),
                if (_step == 1) _step2(),
                if (_step == 2) _step3(),
                const SizedBox(height: 24),
                _nav(),
              ]),
            ),
          ),
        ),
      ))),
    );
  }

  Widget _progress() => Row(children: List.generate(3, (i) {
    final on = i <= _step;
    return Expanded(child: Container(
      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
      height: 6,
      decoration: BoxDecoration(
        color: on ? _purple : Colors.black12,
        borderRadius: BorderRadius.circular(4),
      ),
    ));
  }));

  Widget _step1() => Form(key: _f1, child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.business, size: 56, color: _purple),
      const SizedBox(height: 8),
      const Text('Company Profile', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _purple)),
      const SizedBox(height: 4),
      const Text('Tell us your business name and owner.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
      const SizedBox(height: 18),
      _field(_companyName, 'Company Name *', Icons.business_outlined,
          validator: (v) => _req(v, 'Company Name')),
      _field(_ownerName, 'Owner Name', Icons.person_outline),
    ],
  ));

  Widget _step2() => Form(key: _f2, child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.storefront, size: 56, color: _purple),
      const SizedBox(height: 8),
      const Text('Main Branch / Head Office', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _purple)),
      const SizedBox(height: 4),
      const Text('Controls master data (products, reasons, users).',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
      const SizedBox(height: 18),
      _field(_branchName, 'Branch Name *', Icons.store_outlined,
          validator: (v) => _req(v, 'Branch Name')),
      _field(_branchAddress, 'Address', Icons.location_on_outlined),
      _field(_branchPhone, 'Phone', Icons.phone_outlined, keyboardType: TextInputType.phone),
    ],
  ));

  Widget _step3() => Form(key: _f3, child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.admin_panel_settings, size: 56, color: _purple),
      const SizedBox(height: 8),
      const Text('First Admin User', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _purple)),
      const SizedBox(height: 4),
      const Text('Full access. You can create more users later.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
      const SizedBox(height: 18),
      _field(_adminUsername, 'Username *', Icons.alternate_email,
          validator: (v) => _req(v, 'Username')),
      _field(_adminFullName, 'Full Name *', Icons.badge_outlined,
          validator: (v) => _req(v, 'Full Name')),
      _field(_adminPin, "PIN (6 digits) *", Icons.lock_outline,
          keyboardType: TextInputType.number,
          obscure: !_showPw,
          suffix: IconButton(
            icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showPw = !_showPw),
          ),
          validator: (v) {
            final r = _req(v, 'Password');
            if (r != null) return r;
            if (v!.length != 6) return "PIN must be exactly 6 digits";
            return null;
          }),
      _field(_adminConfirmPin, "Confirm PIN *", Icons.lock_reset,
          keyboardType: TextInputType.number,
          obscure: !_showPw, validator: (v) => _req(v, 'Confirm Password')),
    ],
  ));

  Widget _nav() {
    final isLast = _step == 2;
    return Row(children: [
      if (_step > 0) Expanded(child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _purple,
          side: const BorderSide(color: _purple, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: _saving ? null : () => setState(() => _step--),
        icon: const Icon(Icons.arrow_back), label: const Text('Back'),
      )),
      if (_step > 0) const SizedBox(width: 10),
      Expanded(flex: 2, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isLast ? Colors.green.shade700 : _purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: _saving ? null : () {
          if (!_validateCurrent()) return;
          if (isLast) { _onFinish(); } else { setState(() => _step++); }
        },
        icon: _saving
            ? const SizedBox(height: 18, width: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Icon(isLast ? Icons.check : Icons.arrow_forward),
        label: Text(_saving ? 'Saving...' : (isLast ? 'Finish Setup' : 'Next')),
      )),
    ]);
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool obscure = false, Widget? suffix, TextInputType? keyboardType,
       String? Function(String?)? validator}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl, obscureText: obscure,
      keyboardType: keyboardType, validator: validator,
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
