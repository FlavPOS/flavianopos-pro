import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/app_logo.dart';
import '../../helpers/database_helper.dart';
import '../dashboard_screen.dart';

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
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardScreen(
              userName: user['fullName'] as String,
              role: user['role'] as String? ?? 'admin',
              branch: branch?['name'] as String? ?? 'Main Branch',
              permissions: const ['all'],
            )));
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
                  SizedBox(height: isT ? 50 : 40),
                  const AppLogo(),
                  const SizedBox(height: 12),
                  Text('Secure Login', style: TextStyle(color: Colors.white, fontSize: isT ? 19 : 16, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                  const SizedBox(height: 30),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: isT ? 32 : 24, vertical: isT ? 40 : 32),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))]),
                    child: Column(children: [
                      Container(padding: EdgeInsets.all(isT ? 16 : 12), decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.lock, color: const Color(0xFF7B1FA2), size: isT ? 38 : 32)),
                      SizedBox(height: isT ? 28 : 24),
                      TextField(
                        controller: _usernameController, textInputAction: TextInputAction.next,
                        style: TextStyle(fontSize: isT ? 17 : 15),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.person_outline, color: const Color(0xFF7B1FA2), size: isT ? 26 : 22),
                          hintText: 'Username', hintStyle: TextStyle(color: Colors.grey[400], fontSize: isT ? 17 : 15),
                          filled: true, fillColor: const Color(0xFFF9F9F9), contentPadding: EdgeInsets.symmetric(vertical: isT ? 18 : 14, horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[300]!)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[300]!)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2)),
                        ),
                      ),
                      SizedBox(height: isT ? 20 : 16),
                      TextField(
                        controller: _pinController, obscureText: _obscurePin, keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                        textInputAction: TextInputAction.done, onSubmitted: (_) => _handleLogin(),
                        style: TextStyle(fontSize: isT ? 17 : 15),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock_outline, color: const Color(0xFF7B1FA2), size: isT ? 26 : 22),
                          hintText: 'PIN', hintStyle: TextStyle(color: Colors.grey[400], fontSize: isT ? 17 : 15),
                          filled: true, fillColor: const Color(0xFFF9F9F9), contentPadding: EdgeInsets.symmetric(vertical: isT ? 18 : 14, horizontal: 16),
                          suffixIcon: IconButton(icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF7B1FA2)), onPressed: () => setState(() => _obscurePin = !_obscurePin)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[300]!)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[300]!)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2)),
                        ),
                      ),
                      SizedBox(height: isT ? 28 : 24),
                      SizedBox(
                        width: double.infinity, height: isT ? 56 : 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 4),
                          child: Ink(
                            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFCE93D8)]), borderRadius: BorderRadius.circular(14)),
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
    );
  }
}
