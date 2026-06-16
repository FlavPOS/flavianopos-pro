import 'package:flutter/material.dart';
import '../../models/expense_model.dart';
import 'encode_expense_screen.dart';
import 'approval_screen.dart';
import 'expense_history_screen.dart';
import 'expense_settings_screen.dart';
import 'expense_reports_screen.dart';
import 'expense_audit_screen.dart';

class ExpensesScreen extends StatefulWidget {
  final String currentUser, branch;
  const ExpensesScreen({super.key, required this.currentUser, required this.branch});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Map<String, dynamic> _summary = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 6, vsync: this); _loadSummary(); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadSummary() async {
    try { final s = await ExpenseStorage.getSummary(branch: widget.branch); setState(() { _summary = s; _loading = false; }); }
    catch (_) { setState(() => _loading = false); }
  }

  void _encode() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EncodeExpenseScreen(currentUser: widget.currentUser, branch: widget.branch)));
    if (result == true) _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final forApproval = (_summary['forApproval'] ?? 0) as int;
    final draft = (_summary['draft'] ?? 0) as int;
    final returned = (_summary['returned'] ?? 0) as int;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(elevation: 0, backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white,
        title: const Text('\u{1F4B0} Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [IconButton(icon: const Icon(Icons.add_circle_outline, size: 26), tooltip: 'New Expense', onPressed: _encode)],
        bottom: TabBar(controller: _tabCtrl, isScrollable: true, indicatorColor: Colors.amber, indicatorWeight: 3, labelColor: Colors.white, unselectedLabelColor: Colors.white60, labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: [
            const Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Dashboard'),
            Tab(icon: Badge(isLabelVisible: forApproval > 0, label: Text('$forApproval', style: const TextStyle(fontSize: 9)), child: const Icon(Icons.approval_rounded, size: 18)), text: 'Approval'),
            const Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'History'),
            const Tab(icon: Icon(Icons.settings_rounded, size: 18), text: 'Settings'),
            const Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'Reports'),
            const Tab(icon: Icon(Icons.policy_rounded, size: 18), text: 'Audit'),
          ])),
      body: TabBarView(controller: _tabCtrl, children: [
        _DashboardTab(summary: _summary, loading: _loading, onEncode: _encode, onRefresh: _loadSummary),
        ExpenseApprovalScreen(currentUser: widget.currentUser, branch: widget.branch, onChanged: _loadSummary),
        ExpenseHistoryScreen(currentUser: widget.currentUser, branch: widget.branch),
        ExpenseSettingsScreen(branch: widget.branch),
        ExpenseReportsScreen(branch: widget.branch),
        ExpenseAuditScreen(branch: widget.branch),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _encode, icon: const Icon(Icons.add), label: const Text('New Expense', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final Map<String, dynamic> summary; final bool loading; final VoidCallback onEncode, onRefresh;
  const _DashboardTab({required this.summary, required this.loading, required this.onEncode, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final totalApproved = (summary['totalApproved'] as num?)?.toDouble() ?? 0;
    final countApproved = (summary['countApproved'] as num?)?.toInt() ?? 0;
    final forApproval = (summary['forApproval'] as num?)?.toInt() ?? 0;
    final draft = (summary['draft'] as num?)?.toInt() ?? 0;
    final rejected = (summary['rejected'] as num?)?.toInt() ?? 0;
    final returned = (summary['returned'] as num?)?.toInt() ?? 0;
    return RefreshIndicator(onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)]), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total Approved Expenses', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(totalApproved.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('$countApproved approved expense(s)', style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ])),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _card('For Approval', '$forApproval', Icons.pending_actions, Colors.orange)),
            const SizedBox(width: 10),
            Expanded(child: _card('Draft', '$draft', Icons.edit_note, Colors.grey)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _card('Rejected', '$rejected', Icons.cancel_outlined, Colors.red)),
            const SizedBox(width: 10),
            Expanded(child: _card('Returned', '$returned', Icons.undo, Colors.blue)),
          ]),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(onPressed: onEncode, icon: const Icon(Icons.add_circle_outline),
            label: const Text('Encode New Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
        ])));
  }

  Widget _card(String title, String value, IconData icon, Color color) => Container(padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 18, color: color), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)))]),
      const SizedBox(height: 8), Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
    ]));
}
