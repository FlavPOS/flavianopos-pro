// lib/screens/expenses/expenses_screen.dart
// FlavianoPOS - PRO: Expenses Dashboard (Mobile + Tablet + Web)
import 'package:flutter/material.dart';
import '../../models/settings_model.dart';
import '../../models/expense_model.dart';
import '../../utils/responsive.dart';
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

class _ExpensesScreenState extends State<ExpensesScreen> {
  Map<String, dynamic> _summary = {};
  List<Expense> _allExpenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final s = await ExpenseStorage.getSummary(branch: widget.branch);
      final all = await ExpenseStorage.getFiltered(branch: widget.branch);
      if (mounted) {
        setState(() {
          _summary = s;
          _allExpenses = all;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEncode() async {
    final r = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => EncodeExpenseScreen(currentUser: widget.currentUser, branch: widget.branch)));
    if (r == true) _loadData();
  }

  void _openScreen(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadData();
  }

  double _thisMonthTotal() {
    final now = DateTime.now();
    return _allExpenses.where((e) {
      final d = DateTime.tryParse(e.expenseDate);
      return d != null && d.year == now.year && d.month == now.month && e.isApproved;
    }).fold(0.0, (sum, e) => sum + e.amount);
  }

  int _thisMonthCount() {
    final now = DateTime.now();
    return _allExpenses.where((e) {
      final d = DateTime.tryParse(e.expenseDate);
      return d != null && d.year == now.year && d.month == now.month && e.isApproved;
    }).length;
  }

  double _lastMonthTotal() {
    final now = DateTime.now();
    final lm = DateTime(now.year, now.month - 1);
    return _allExpenses.where((e) {
      final d = DateTime.tryParse(e.expenseDate);
      return d != null && d.year == lm.year && d.month == lm.month && e.isApproved;
    }).fold(0.0, (sum, e) => sum + e.amount);
  }

  List<MapEntry<String, double>> _topCategories({int top = 5}) {
    final now = DateTime.now();
    final Map<String, double> totals = {};
    for (final e in _allExpenses) {
      final d = DateTime.tryParse(e.expenseDate);
      if (d != null && d.year == now.year && d.month == now.month && e.isApproved) {
        final cat = e.categoryName.isEmpty ? 'Uncategorized' : e.categoryName;
        totals[cat] = (totals[cat] ?? 0) + e.amount;
      }
    }
    final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(top).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        title: Text('💰 Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.titleSz(context))),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _loadData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B1FA2)))
          : RefreshIndicator(
              color: const Color(0xFF7B1FA2),
              onRefresh: _loadData,
              child: Responsive.centered(
                context: context,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(Responsive.pad(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(context),
                      SizedBox(height: Responsive.pad(context)),
                      _buildQuickActionsTitle(context),
                      const SizedBox(height: 12),
                      _buildQuickActionsGrid(context),
                      SizedBox(height: Responsive.pad(context) + 4),
                      _buildTopCategoriesSection(context),
                      SizedBox(height: Responsive.pad(context) + 4),
                      _buildAlertsSection(context),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEncode,
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Expense', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final total = _thisMonthTotal();
    final count = _thisMonthCount();
    final lastMonth = _lastMonthTotal();
    final pctChange = lastMonth > 0 ? ((total - lastMonth) / lastMonth * 100) : 0.0;
    final isPositive = pctChange >= 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.isPhone(context) ? 18 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0), Color(0xFFAB47BC)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Responsive.cardR(context) + 4),
        boxShadow: [BoxShadow(color: const Color(0xFF7B1FA2).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22)),
          const SizedBox(width: 10),
          const Expanded(child: Text('THIS MONTH',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
        ]),
        const SizedBox(height: 14),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text('${AppSettings.currencySymbol}${_fmtCurrency(total)}',
            style: TextStyle(color: Colors.white,
              fontSize: Responsive.isPhone(context) ? 30 : 38,
              fontWeight: FontWeight.bold, letterSpacing: -0.5))),
        const SizedBox(height: 6),
        Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _miniInfo(Icons.receipt_long, '$count transactions'),
          if (lastMonth > 0)
            _pctChip(isPositive ? '↑ ${pctChange.abs().toStringAsFixed(1)}%' : '↓ ${pctChange.abs().toStringAsFixed(1)}%',
              isPositive ? Colors.greenAccent : Colors.redAccent),
          if (lastMonth > 0)
            Text('vs last month', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _miniInfo(IconData i, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(i, color: Colors.white.withValues(alpha: 0.85), size: 14),
    const SizedBox(width: 4),
    Text(s, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w500)),
  ]);

  Widget _pctChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
  );

  Widget _buildQuickActionsTitle(BuildContext context) => Row(children: [
    const Icon(Icons.flash_on, color: Color(0xFF7B1FA2), size: 18),
    const SizedBox(width: 6),
    Text('Quick Actions', style: TextStyle(fontSize: Responsive.titleSz(context) - 2, fontWeight: FontWeight.bold, color: const Color(0xFF424242))),
  ]);

  Widget _buildQuickActionsGrid(BuildContext context) {
    final forApproval = (_summary['forApproval'] ?? 0) as int;
    final actions = [
      _QA(icon: Icons.edit_note, label: 'Encode', color: const Color(0xFF7B1FA2), onTap: _openEncode),
      _QA(icon: Icons.task_alt, label: 'Approval', color: Colors.orange.shade700,
        badge: forApproval > 0 ? '$forApproval' : null,
        onTap: () => _openScreen(ExpenseApprovalScreen(currentUser: widget.currentUser, branch: widget.branch, onChanged: _loadData))),
      _QA(icon: Icons.history, label: 'History', color: Colors.blue.shade700,
        onTap: () => _openScreen(ExpenseHistoryScreen(currentUser: widget.currentUser, branch: widget.branch))),
      _QA(icon: Icons.bar_chart, label: 'Reports', color: Colors.teal.shade700,
        onTap: () => _openScreen(ExpenseReportsScreen(branch: widget.branch))),
      _QA(icon: Icons.policy, label: 'Audit', color: Colors.deepOrange.shade700,
        onTap: () => _openScreen(ExpenseAuditScreen(branch: widget.branch))),
      _QA(icon: Icons.settings, label: 'Settings', color: Colors.blueGrey.shade700,
        onTap: () => _openScreen(ExpenseSettingsScreen(branch: widget.branch))),
    ];

    final cols = Responsive.gridCols(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10,
        childAspectRatio: Responsive.isPhone(context) ? 1.1 : 1.2,
      ),
      itemBuilder: (_, i) => _buildActionCard(context, actions[i]),
    );
  }

  Widget _buildActionCard(BuildContext context, _QA a) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(Responsive.cardR(context)),
      elevation: 1.5, shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(Responsive.cardR(context)),
        onTap: a.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                padding: EdgeInsets.all(Responsive.isPhone(context) ? 12 : 14),
                decoration: BoxDecoration(color: a.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(a.icon, color: a.color, size: Responsive.bigIconSz(context) - 4),
              ),
              if (a.badge != null)
                Positioned(right: -4, top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5)),
                    child: Text(a.badge!, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
            ]),
            const SizedBox(height: 10),
            Text(a.label, style: TextStyle(fontSize: Responsive.bodySz(context), fontWeight: FontWeight.w600, color: const Color(0xFF424242))),
          ]),
        ),
      ),
    );
  }

  Widget _buildTopCategoriesSection(BuildContext context) {
    final top = _topCategories();
    if (top.isEmpty) return const SizedBox.shrink();
    final maxAmount = top.first.value;
    final colors = [const Color(0xFF7B1FA2), Colors.blue.shade600, Colors.teal.shade600, Colors.orange.shade600, Colors.pink.shade600];

    return Container(
      padding: EdgeInsets.all(Responsive.pad(context)),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Responsive.cardR(context)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.emoji_events, color: Color(0xFFFFA000), size: 18),
          const SizedBox(width: 6),
          Text('Top Categories This Month',
            style: TextStyle(fontSize: Responsive.titleSz(context) - 2, fontWeight: FontWeight.bold, color: const Color(0xFF424242))),
        ]),
        const SizedBox(height: 14),
        ...top.asMap().entries.map((e) {
          final idx = e.key; final entry = e.value;
          final pct = maxAmount > 0 ? entry.value / maxAmount : 0.0;
          final color = colors[idx % colors.length];
          return Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(entry.key,
                  style: TextStyle(fontSize: Responsive.bodySz(context), fontWeight: FontWeight.w500, color: const Color(0xFF424242)))),
                Text('${AppSettings.currencySymbol}${_fmtCurrency(entry.value)}',
                  style: TextStyle(fontSize: Responsive.bodySz(context), fontWeight: FontWeight.bold, color: color)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: pct, minHeight: 6,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(color))),
            ]));
        }),
      ]),
    );
  }

  Widget _buildAlertsSection(BuildContext context) {
    final forApproval = (_summary['forApproval'] ?? 0) as int;
    final returned = (_summary['returned'] ?? 0) as int;
    final draft = (_summary['draft'] ?? 0) as int;
    final alerts = <_Alert>[];

    if (forApproval > 0) {
      alerts.add(_Alert(icon: Icons.pending_actions, color: Colors.red.shade600,
        title: '$forApproval expense${forApproval > 1 ? "s" : ""} awaiting approval',
        subtitle: 'Tap to review and process',
        onTap: () => _openScreen(ExpenseApprovalScreen(currentUser: widget.currentUser, branch: widget.branch, onChanged: _loadData))));
    }
    if (returned > 0) {
      alerts.add(_Alert(icon: Icons.replay, color: Colors.orange.shade700,
        title: '$returned expense${returned > 1 ? "s" : ""} returned for revision',
        subtitle: 'Needs your attention',
        onTap: () => _openScreen(ExpenseHistoryScreen(currentUser: widget.currentUser, branch: widget.branch))));
    }
    if (draft > 0) {
      alerts.add(_Alert(icon: Icons.edit_note, color: Colors.blue.shade600,
        title: '$draft draft expense${draft > 1 ? "s" : ""}',
        subtitle: 'Complete and submit',
        onTap: () => _openScreen(ExpenseHistoryScreen(currentUser: widget.currentUser, branch: widget.branch))));
    }

    if (alerts.isEmpty) {
      return Container(
        padding: EdgeInsets.all(Responsive.pad(context)),
        decoration: BoxDecoration(color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(Responsive.cardR(context)),
          border: Border.all(color: Colors.green.shade200)),
        child: Row(children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text('All caught up! No pending alerts.',
            style: TextStyle(fontSize: Responsive.bodySz(context), color: Colors.green.shade900, fontWeight: FontWeight.w500))),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.notifications_active, color: Color(0xFFD32F2F), size: 18),
        const SizedBox(width: 6),
        Text('Alerts', style: TextStyle(fontSize: Responsive.titleSz(context) - 2, fontWeight: FontWeight.bold, color: const Color(0xFF424242))),
      ]),
      const SizedBox(height: 10),
      ...alerts.map((a) => Padding(padding: const EdgeInsets.only(bottom: 8),
        child: Material(color: Colors.white, borderRadius: BorderRadius.circular(Responsive.cardR(context)), elevation: 1,
          child: InkWell(borderRadius: BorderRadius.circular(Responsive.cardR(context)), onTap: a.onTap,
            child: Padding(padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: a.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(a.icon, color: a.color, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.title, style: TextStyle(fontSize: Responsive.bodySz(context), fontWeight: FontWeight.bold, color: const Color(0xFF424242))),
                  const SizedBox(height: 2),
                  Text(a.subtitle, style: TextStyle(fontSize: Responsive.captionSz(context), color: Colors.grey.shade600)),
                ])),
                Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
              ]))))))
    ]);
  }

  String _fmtCurrency(double n) {
    final parts = n.toStringAsFixed(2).split('.');
    final intP = parts[0]; final dec = parts[1];
    final buf = StringBuffer();
    for (int i = 0; i < intP.length; i++) {
      if (i > 0 && (intP.length - i) % 3 == 0) buf.write(',');
      buf.write(intP[i]);
    }
    return '$buf.$dec';
  }
}

class _QA {
  final IconData icon; final String label; final Color color; final String? badge; final VoidCallback onTap;
  _QA({required this.icon, required this.label, required this.color, this.badge, required this.onTap});
}

class _Alert {
  final IconData icon; final Color color; final String title, subtitle; final VoidCallback onTap;
  _Alert({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
}
