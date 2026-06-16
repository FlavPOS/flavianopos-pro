import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/app_logo.dart';
import '../../helpers/database_helper.dart';
import 'login_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _currentStep = 0;
  final _branchNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _branchNameController.dispose(); _addressController.dispose();
    _phoneController.dispose(); _emailController.dispose();
    _fullNameController.dispose(); _usernameController.dispose();
    _pinController.dispose(); _confirmPinController.dispose();
    super.dispose();
  }

  void _goToAdminStep() {
    if (_branchNameController.text.trim().isEmpty) { _showSnackBar('Please enter Branch Name'); return; }
    setState(() => _currentStep = 1);
  }

  void _goBackToBranch() { setState(() => _currentStep = 0); }

  Future<void> _handleSetupComplete() async {
    if (_fullNameController.text.trim().isEmpty) { _showSnackBar('Please enter Full Name'); return; }
    if (_usernameController.text.trim().isEmpty) { _showSnackBar('Please enter Username'); return; }
    if (_pinController.text.length < 4) { _showSnackBar('PIN must be 4-6 digits'); return; }
    if (_pinController.text != _confirmPinController.text) { _showSnackBar('PINs do not match'); return; }

    setState(() => _isLoading = true);

    try {
      final db = DatabaseHelper();

      // Save branch
      await db.saveBranch({
        'name': _branchNameController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
      });

      // Save admin user
      await db.insertUser({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'fullName': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'password': _pinController.text,
        'pin': _pinController.text,
        'role': 'admin',
        'branch': _branchNameController.text.trim(),
        'isActive': 1,
        'dateCreated': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setup complete! Please login.'), backgroundColor: Colors.green),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isT = sw > 600;
    final maxW = isT ? 500.0 : double.infinity;
    final hPad = isT ? 48.0 : 24.0;

    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6A1B9A), Color(0xFF7B1FA2), Color(0xFF8E24AA)])),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Column(children: [
                  SizedBox(height: isT ? 50 : 30),
                  const AppLogo(),
                  const SizedBox(height: 12),
                  Text(_currentStep == 0 ? "Let's set up your store" : 'Create your admin account', style: TextStyle(color: Colors.white, fontSize: isT ? 18 : 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 20),
                  _buildStepIndicator(isT),
                  const SizedBox(height: 24),
                  _currentStep == 0 ? _buildBranchCard(isT) : _buildAdminCard(isT),
                  const SizedBox(height: 24),
                  Text('\u00a9 2026 FlavianoPOS - PRO v1.0', style: TextStyle(color: Colors.white70, fontSize: isT ? 14 : 12)),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(bool isT) {
    final cs = isT ? 52.0 : 44.0;
    final ic = isT ? 26.0 : 22.0;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _stepCircle(icon: _currentStep > 0 ? Icons.check : Icons.store, label: 'Branch', active: _currentStep == 0, done: _currentStep > 0, cs: cs, ic: ic, isT: isT),
      Container(width: isT ? 60 : 40, height: 2, color: _currentStep > 0 ? Colors.white : Colors.white38),
      _stepCircle(icon: Icons.person, label: 'Admin', active: _currentStep == 1, done: false, cs: cs, ic: ic, isT: isT),
    ]);
  }

  Widget _stepCircle({required IconData icon, required String label, required bool active, required bool done, required double cs, required double ic, required bool isT}) {
    return Column(children: [
      Container(width: cs, height: cs, decoration: BoxDecoration(color: active || done ? Colors.white : Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: active || done ? Colors.white : Colors.white38, width: 2)),
        child: Icon(icon, color: active || done ? const Color(0xFF7B1FA2) : Colors.white54, size: ic)),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(color: active || done ? Colors.white : Colors.white54, fontSize: isT ? 14 : 12, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
    ]);
  }

  Widget _buildBranchCard(bool isT) {
    final cp = isT ? 32.0 : 24.0;
    return Container(
      width: double.infinity, padding: EdgeInsets.all(cp),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Column(children: [
        Container(padding: EdgeInsets.all(isT ? 14 : 10), decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.store, color: const Color(0xFF7B1FA2), size: isT ? 34 : 28)),
        const SizedBox(height: 10),
        Text('Branch Setup', style: TextStyle(fontSize: isT ? 24 : 20, fontWeight: FontWeight.bold, color: const Color(0xFF7B1FA2))),
        const SizedBox(height: 4),
        Text('Configure your store', style: TextStyle(color: Colors.grey[500], fontSize: isT ? 15 : 13)),
        SizedBox(height: isT ? 28 : 20),
        _field(c: _branchNameController, h: 'Branch Name *', i: Icons.storefront, isT: isT),
        SizedBox(height: isT ? 18 : 14),
        _field(c: _addressController, h: 'Address', i: Icons.location_on_outlined, isT: isT),
        SizedBox(height: isT ? 18 : 14),
        _field(c: _phoneController, h: 'Phone', i: Icons.phone_outlined, kt: TextInputType.phone, isT: isT),
        SizedBox(height: isT ? 18 : 14),
        _field(c: _emailController, h: 'Email', i: Icons.email_outlined, kt: TextInputType.emailAddress, isT: isT),
        SizedBox(height: isT ? 28 : 24),
        _gradBtn(label: 'Continue', icon: Icons.arrow_forward, onPressed: _goToAdminStep, isT: isT),
      ]),
    );
  }

  Widget _buildAdminCard(bool isT) {
    final cp = isT ? 32.0 : 24.0;
    return Container(
      width: double.infinity, padding: EdgeInsets.all(cp),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Column(children: [
        Container(padding: EdgeInsets.all(isT ? 14 : 10), decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.admin_panel_settings, color: const Color(0xFF7B1FA2), size: isT ? 34 : 28)),
        const SizedBox(height: 10),
        Text('Admin Account', style: TextStyle(fontSize: isT ? 24 : 20, fontWeight: FontWeight.bold, color: const Color(0xFF7B1FA2))),
        const SizedBox(height: 4),
        Text('Create your admin login', style: TextStyle(color: Colors.grey[500], fontSize: isT ? 15 : 13)),
        SizedBox(height: isT ? 28 : 20),
        _field(c: _fullNameController, h: 'Full Name *', i: Icons.person_outline, isT: isT),
        SizedBox(height: isT ? 18 : 14),
        _field(c: _usernameController, h: 'Username *', i: Icons.account_circle_outlined, isT: isT),
        SizedBox(height: isT ? 18 : 14),
        _field(c: _pinController, h: 'PIN (4-6 digits) *', i: Icons.lock_outline, obs: _obscurePin, kt: TextInputType.number, fmt: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)], suf: IconButton(icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF7B1FA2)), onPressed: () => setState(() => _obscurePin = !_obscurePin)), isT: isT),
        SizedBox(height: isT ? 18 : 14),
        _field(c: _confirmPinController, h: 'Confirm PIN *', i: Icons.lock_outline, obs: _obscureConfirmPin, kt: TextInputType.number, fmt: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)], suf: IconButton(icon: Icon(_obscureConfirmPin ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF7B1FA2)), onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin)), isT: isT),
        SizedBox(height: isT ? 28 : 24),
        Row(children: [
          Expanded(child: SizedBox(height: isT ? 56 : 52, child: OutlinedButton.icon(onPressed: _goBackToBranch, icon: const Icon(Icons.arrow_back, size: 18), label: Text('Back', style: TextStyle(fontSize: isT ? 16 : 13)), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF7B1FA2), side: const BorderSide(color: Color(0xFF7B1FA2), width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))))),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _gradBtn(label: 'Complete Setup', icon: Icons.check_circle_outline, onPressed: _isLoading ? null : _handleSetupComplete, isLoading: _isLoading, isT: isT)),
        ]),
      ]),
    );
  }

  Widget _field({required TextEditingController c, required String h, required IconData i, bool obs = false, TextInputType? kt, List<TextInputFormatter>? fmt, Widget? suf, bool isT = false}) {
    return TextField(
      controller: c, obscureText: obs, keyboardType: kt, inputFormatters: fmt,
      style: TextStyle(fontSize: isT ? 17 : 15),
      decoration: InputDecoration(
        prefixIcon: Icon(i, color: const Color(0xFF7B1FA2), size: isT ? 26 : 22), hintText: h, hintStyle: TextStyle(color: Colors.grey[400], fontSize: isT ? 17 : 15), suffixIcon: suf,
        filled: true, fillColor: const Color(0xFFF9F9F9), contentPadding: EdgeInsets.symmetric(vertical: isT ? 18 : 14, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2)),
      ),
    );
  }

  Widget _gradBtn({required String label, required IconData icon, VoidCallback? onPressed, bool isLoading = false, bool isT = false}) {
    return SizedBox(
      width: double.infinity, height: isT ? 56 : 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 4),
        child: Ink(
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFCE93D8)]), borderRadius: BorderRadius.circular(14)),
          child: Container(alignment: Alignment.center, child: isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: isT ? 24 : 20), const SizedBox(width: 8), Text(label, style: TextStyle(color: Colors.white, fontSize: isT ? 19 : 17, fontWeight: FontWeight.bold))])),
        ),
      ),
    );
  }
}
