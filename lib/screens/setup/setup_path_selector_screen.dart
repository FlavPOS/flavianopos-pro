import 'package:flutter/material.dart';
import 'join_existing_branch_screen.dart';
import 'add_new_branch_screen.dart';

class SetupPathSelectorScreen extends StatelessWidget {
  final Map<String, dynamic> existingProfile;
  const SetupPathSelectorScreen({super.key, required this.existingProfile});

  static const Color _purple = Color(0xFF6A1B9A);
  static const Color _lightPurple = Color(0xFFEDE7F6);

  @override
  Widget build(BuildContext context) {
    final name = (existingProfile['companyName'] ?? '').toString().isEmpty
        ? '(no name)' : existingProfile['companyName'].toString();
    final code = (existingProfile['companyCode'] ?? '').toString();
    return Scaffold(
      backgroundColor: _lightPurple,
      appBar: AppBar(backgroundColor: _purple, foregroundColor: Colors.white,
          title: const Text('Company Already Exists')),
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(padding: const EdgeInsets.all(24), child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.cloud_done_outlined, size: 64, color: _purple),
                const SizedBox(height: 12),
                Text('🏢 $name', textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _purple)),
                const SizedBox(height: 4),
                Text('Code: $code', textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 4),
                const Text('How is this device being used?', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 24),
                _option(context, 'Join Existing Branch',
                    'Extra cashier/staff device for an existing branch.',
                    Icons.login, true,
                    () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const JoinExistingBranchScreen()))),
                const SizedBox(height: 12),
                _option(context, 'Add New Branch',
                    'Admin only. Open a new branch (e.g. Cebu).',
                    Icons.add_business_outlined, false,
                    () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const AddNewBranchScreen()))),
              ],
            )),
          ),
        ),
      ))),
    );
  }

  Widget _option(BuildContext ctx, String title, String subtitle,
      IconData icon, bool primary, VoidCallback onTap) =>
    InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14),
      child: Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: primary ? _purple.withValues(alpha: 0.06) : Colors.white,
          border: Border.all(color: primary ? _purple : Colors.black12, width: primary ? 2 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(icon, color: _purple, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ])),
          const Icon(Icons.chevron_right, color: _purple),
        ]),
      ),
    );
}
