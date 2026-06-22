import 'package:flutter/material.dart';
import '_debug_reset_chip.dart';
import 'package:flutter/services.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/pos_background.dart';
import '../../helpers/database_helper.dart';
import '../../models/user_model.dart';
import '../dashboard_screen.dart';
import '../../services/cashier_session_service.dart';
import '../cashier_lock/beginning_cash_screen.dart';
import '../../models/cashier_session_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _obscurePin = true;
  bool _isLoading = false;

  @override
  void dispose() { _usernameController.dispose(); _pinController.dispose(); super.dispose(); }

  Future<void> _handleLogin() async {
    if (_usernameController.text.isEmpty || _pinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Username and PIN'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = DatabaseHelper();
      final branch = await db.getBranch();
      final user = await db.authenticateUser(
        _usernameController.text.trim(),
        _pinController.text,
      );

      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome, ${user['fullName']}!'), backgroundColor: Colors.green),
        );
        
        // Parse permissions from DB - robust parser (handles JSON, CSV, and corrupted formats)
        List<String> userPerms = [];
        try {
          final p = user["permissions"];
          if (p != null && p is String && p.isNotEmpty) {
            // Strip JSON brackets/quotes, then split CSV-style
            final cleaned = p.replaceAll(RegExp(r'[\[\]]'), '').replaceAll('"', '').replaceAll("'", '');
            userPerms = cleaned.split(",").map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();
          }
        } catch (_) {}
        final role = user["role"] as String? ?? "Admin";
        if (userPerms.isEmpty) {
          userPerms = AppUser.rolePresets[role] ?? AppUser.rolePresets["Admin"] ?? [];
        }
        // Safety net: Admin/Manager always get Users
        if ((role == "Admin" || role == "Manager") && !userPerms.contains("Users")) {
          userPerms.add("Users");
        }
        // Safety net: Admin/Manager always get Branches
        if ((role == "Admin" || role == "Manager") && !userPerms.contains("Branches")) {
          userPerms.add("Branches");
        }
        // Safety net: Admin/Manager always get Expenses
        if ((role == "Admin" || role == "Manager") && !userPerms.contains("Expenses")) {
          userPerms.add("Expenses");
        }

        await _checkSessionAndNavigate(user, role, branch, userPerms);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid Username or PIN'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override

  Future<void> _checkSessionAndNavigate(Map<String, dynamic> user, String role, Map<String, dynamic>? branch, List<String> userPerms) async {
    final userName = user['fullName'] as String;
    final branchName = branch?['name'] as String? ?? 'Main Branch';

    CashierSession? session;
    try {
      session = await CashierSessionService.getActiveSession(userName);
    } catch (_) {}

    if (!mounted) return;

    // ⚠️ ROLE CHECK: Only Cashier needs Beginning Cash!
    // Admin, Manager, Inventory Clerk, etc. → Skip to Dashboard
    if (role != 'Cashier') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardScreen(
        userName: userName,
        role: role,
        branch: branchName,
        permissions: userPerms,
      )));
      return;
    }

    if (session != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardScreen(
        userName: userName,
        role: role,
        branch: branchName,
        permissions: userPerms,
      )));
    } else {
      final newSession = await Navigator.push<CashierSession>(context, MaterialPageRoute(
        builder: (_) => BeginningCashScreen(
          cashierId: userName,
          cashierName: userName,
          branch: branchName,
        ),
      ));

      if (newSession != null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardScreen(
          userName: userName,
          role: role,
          branch: branchName,
          permissions: userPerms,
        )));
      }
    }
  }

  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isT = sw > 600;
    final maxW = isT ? 500.0 : double.infinity;
    final hPad = isT ? 48.0 : 24.0;

    return Scaffold(floatingActionButton: const DebugResetChip(),
      body: Stack(children: [const Positioned.fill(child: POSBackground(child: SizedBox.expand())), Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(color: Colors.transparent),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Column(children: [
                  SizedBox(height: isT ? 50 : 40),
                  const SizedBox(height: 12),
                  Text('Secure Login', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: isT ? 19 : 16, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                  const SizedBox(height: 30),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: isT ? 32 : 24, vertical: isT ? 40 : 32),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 12)), BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.2), blurRadius: 60, offset: const Offset(0, 0))]),
                    child: Column(children: [
                      Container(padding: EdgeInsets.all(isT ? 16 : 12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 4))]), child: Icon(Icons.lock, color: Colors.white, size: isT ? 38 : 32)),
                      SizedBox(height: isT ? 28 : 24),
                      TextField(
                        controller: _usernameController, textInputAction: TextInputAction.next,
                        style: TextStyle(fontSize: isT ? 17 : 15, color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.person_outline, color: const Color(0xFF8B5CF6), size: isT ? 26 : 22),
                          hintText: 'Username', hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: isT ? 17 : 15),
                          filled: true, fillColor: Colors.white.withValues(alpha: 0.08), contentPadding: EdgeInsets.symmetric(vertical: isT ? 18 : 14, horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2)),
                        ),
                      ),
                      SizedBox(height: isT ? 20 : 16),
                      TextField(
                        controller: _pinController, obscureText: _obscurePin, keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                        textInputAction: TextInputAction.done, onSubmitted: (_) => _handleLogin(),
                        style: TextStyle(fontSize: isT ? 17 : 15, color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock_outline, color: const Color(0xFF8B5CF6), size: isT ? 26 : 22),
                          hintText: 'PIN', hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: isT ? 17 : 15),
                          filled: true, fillColor: Colors.white.withValues(alpha: 0.08), contentPadding: EdgeInsets.symmetric(vertical: isT ? 18 : 14, horizontal: 16),
                          suffixIcon: IconButton(icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF8B5CF6)), onPressed: () => setState(() => _obscurePin = !_obscurePin)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2)),
                        ),
                      ),
                      SizedBox(height: isT ? 28 : 24),
                      SizedBox(
                        width: double.infinity, height: isT ? 56 : 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 4),
                          child: Ink(
                            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)]), borderRadius: BorderRadius.circular(14)),
                            child: Container(alignment: Alignment.center, child: _isLoading
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.login, color: Colors.white, size: isT ? 26 : 22), const SizedBox(width: 8), Text('Login', style: TextStyle(color: Colors.white, fontSize: isT ? 20 : 18, fontWeight: FontWeight.bold))])),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  Text('\u00a9 2026 FlavianoPOS - PRO v1.0', style: TextStyle(color: Colors.white70, fontSize: isT ? 14 : 12)),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ),
        ),
      ),
      ]),
    );
  }
}
