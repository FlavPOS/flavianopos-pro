// lib/screens/expenses/approval_screen.dart
// FlavianoPOS - PRO: Expense Approval (Mobile + Tablet + Web)
import 'package:flutter/material.dart';
import '../../models/settings_model.dart';
import 'package:flutter/services.dart';
import '../../models/expense_model.dart';
import '../../utils/expense_print_dialog.dart';
import '../../models/user_model.dart';
import '../../utils/responsive.dart';

class ExpenseApprovalScreen extends StatefulWidget {
  final String currentUser, branch;
  final VoidCallback onChanged;
  const ExpenseApprovalScreen({super.key, required this.currentUser, required this.branch, required this.onChanged});
  @override
  State<ExpenseApprovalScreen> createState() => _ExpenseApprovalScreenState();
}

class _ExpenseApprovalScreenState extends State<ExpenseApprovalScreen> {
  List<Expense> _all = [];
  List<Expense> _filtered = [];
  String _filter = 'For Approval';
  String _search = '';
  bool _loading = true;

  final _filters = const ['For Approval', 'Returned', 'Rejected', 'Approved', 'All'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await ExpenseStorage.getAll();
    final branchExpenses = all.where((e) => e.branch == widget.branch).toList();
    setState(() {
      _all = branchExpenses;
      _filtered = _applyFilter(branchExpenses);
      _loading = false;
    });
  }

  List<Expense> _applyFilter(List<Expense> source) {
    var list = source.where((e) {
      if (_filter == 'All') return !e.isDraft;
      return e.status == _filter;
    }).toList();
    if (_search.isNotEmpty) {
      final s = _search.toLowerCase();
      list = list.where((e) =>
        e.expenseNumber.toLowerCase().contains(s) ||
        e.categoryName.toLowerCase().contains(s) ||
        e.payeeSupplier.toLowerCase().contains(s)
      ).toList();
    }
    list.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
    return list;
  }

  void _setFilter(String f) {
    setState(() { _filter = f; _filtered = _applyFilter(_all); });
  }

  // ════════════ MANAGER PIN DIALOG (6-DIGIT) ════════════
  Future<bool> _verifyManagerPin(String actionTitle, double amount) async {
    final pinCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.lock, color: Color(0xFF7B1FA2)),
          const SizedBox(width: 8),
          Text(actionTitle, style: const TextStyle(fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.amber.shade800, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Amount: ${AppSettings.currencySymbol}${amount.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900))),
            ]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: pinCtrl,
            obscureText: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Manager PIN (6 digits)',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2),
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B1FA2), foregroundColor: Colors.white),
            onPressed: () {
              if (pinCtrl.text.length != 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('PIN must be exactly 6 digits')));
                return;
              }
              final mgr = AppUser.allUsers.where((u) =>
                (u.role == 'Admin' || u.role == 'Manager') && u.pin == pinCtrl.text.trim()
              ).firstOrNull;
              if (mgr != null) {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Invalid Manager PIN'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ════════════ APPROVE ════════════
  Future<void> _approve(Expense e) async {
    final remarksCtrl = TextEditingController();
    final confirmed = await _showActionSheet(
      context: context,
      title: 'Approve Expense',
      titleColor: Colors.green.shade700,
      icon: Icons.check_circle,
      expense: e,
      remarksLabel: 'Approval Remarks (Optional)',
      remarksCtrl: remarksCtrl,
      remarksRequired: false,
      confirmLabel: 'APPROVE',
      confirmColor: Colors.green.shade700,
    );
    if (!confirmed) return;
    final pinOk = await _verifyManagerPin('Approve: ${e.expenseNumber}', e.amount);
    if (!pinOk) return;

    final now = DateTime.now();
    final updated = e.copyWith(
      status: 'Approved',
      approvedBy: widget.currentUser,
      approvedDate: now.toIso8601String(),
      approvalRemarks: remarksCtrl.text.trim(),
      updatedBy: widget.currentUser,
      updatedDate: now.toIso8601String(),
    );
    await ExpenseStorage.updateExpense(e.id, updated);
    await ExpenseStorage.addAudit(ExpenseAudit(
      id: 'AUD-${now.millisecondsSinceEpoch}',
      expenseId: e.id, expenseNumber: e.expenseNumber,
      action: 'Approved', newValue: 'Approved by ${widget.currentUser}',
      performedBy: widget.currentUser, performedDate: now.toIso8601String(),
      branch: widget.branch,
    ));
    widget.onChanged();
    _load();
    _snack('✅ Expense approved!', Colors.green);
    if (mounted) await ExpensePrintDialog.show(context, updated);
  }

  // ════════════ REJECT ════════════
  Future<void> _reject(Expense e) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await _showActionSheet(
      context: context,
      title: 'Reject Expense',
      titleColor: Colors.red.shade700,
      icon: Icons.cancel,
      expense: e,
      remarksLabel: 'Rejection Reason *',
      remarksCtrl: reasonCtrl,
      remarksRequired: true,
      confirmLabel: 'REJECT',
      confirmColor: Colors.red.shade700,
    );
    if (!confirmed) return;
    final pinOk = await _verifyManagerPin('Reject: ${e.expenseNumber}', e.amount);
    if (!pinOk) return;

    final now = DateTime.now();
    final updated = e.copyWith(
      status: 'Rejected',
      rejectedBy: widget.currentUser,
      rejectedDate: now.toIso8601String(),
      rejectionReason: reasonCtrl.text.trim(),
      updatedBy: widget.currentUser,
      updatedDate: now.toIso8601String(),
    );
    await ExpenseStorage.updateExpense(e.id, updated);
    await ExpenseStorage.addAudit(ExpenseAudit(
      id: 'AUD-${now.millisecondsSinceEpoch}',
      expenseId: e.id, expenseNumber: e.expenseNumber,
      action: 'Rejected', newValue: reasonCtrl.text.trim(),
      performedBy: widget.currentUser, performedDate: now.toIso8601String(),
      branch: widget.branch,
    ));
    widget.onChanged();
    _load();
    _snack('❌ Expense rejected', Colors.red);
    if (mounted) await ExpensePrintDialog.show(context, updated);
  }

  // ════════════ RETURN ════════════
  Future<void> _returnExp(Expense e) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await _showActionSheet(
      context: context,
      title: 'Return for Revision',
      titleColor: Colors.orange.shade700,
      icon: Icons.replay,
      expense: e,
      remarksLabel: 'Return Reason *',
      remarksCtrl: reasonCtrl,
      remarksRequired: true,
      confirmLabel: 'RETURN',
      confirmColor: Colors.orange.shade700,
    );
    if (!confirmed) return;
    final pinOk = await _verifyManagerPin('Return: ${e.expenseNumber}', e.amount);
    if (!pinOk) return;

    final now = DateTime.now();
    final updated = e.copyWith(
      status: 'Returned',
      returnedBy: widget.currentUser,
      returnedDate: now.toIso8601String(),
      returnReason: reasonCtrl.text.trim(),
      updatedBy: widget.currentUser,
      updatedDate: now.toIso8601String(),
    );
    await ExpenseStorage.updateExpense(e.id, updated);
    await ExpenseStorage.addAudit(ExpenseAudit(
      id: 'AUD-${now.millisecondsSinceEpoch}',
      expenseId: e.id, expenseNumber: e.expenseNumber,
      action: 'Returned', newValue: reasonCtrl.text.trim(),
      performedBy: widget.currentUser, performedDate: now.toIso8601String(),
      branch: widget.branch,
    ));
    widget.onChanged();
    _load();
    _snack('🔄 Expense returned for revision', Colors.orange);
    if (mounted) await ExpensePrintDialog.show(context, updated);
  }

  // ════════════ ACTION SHEET (Bottom sheet on phone, dialog on tablet/web) ════════════
  Future<bool> _showActionSheet({
    required BuildContext context,
    required String title,
    required Color titleColor,
    required IconData icon,
    required Expense expense,
    required String remarksLabel,
    required TextEditingController remarksCtrl,
    required bool remarksRequired,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final isPhone = Responsive.isPhone(context);
    Widget content = StatefulBuilder(builder: (ctx, setSt) => Container(
      padding: EdgeInsets.all(Responsive.pad(ctx)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: titleColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: titleColor, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor))),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx, false)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.tag, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(expense.expenseNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            Text('${expense.categoryName}${expense.subCategoryName.isEmpty ? "" : " › ${expense.subCategoryName}"}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 6),
            if (expense.payeeSupplier.isNotEmpty)
              Text('Payee: ${expense.payeeSupplier}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 8),
            Text('${AppSettings.currencySymbol}${expense.amount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: titleColor)),
          ]),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: remarksCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: remarksLabel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: confirmColor, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Cancel'),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            onPressed: () {
              if (remarksRequired && remarksCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$remarksLabel is required'), backgroundColor: Colors.red));
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          )),
        ]),
      ]),
    ));

    if (isPhone) {
      return (await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: content,
        ),
      )) ?? false;
    } else {
      return (await showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: content),
        ),
      )) ?? false;
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ════════════ BUILD ════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        title: Text('Approvals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.titleSz(context))),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B1FA2)))
          : Responsive.centered(
              context: context,
              child: Column(children: [
                _buildSearchBar(context),
                _buildFilterChips(context),
                _buildSummaryStrip(context),
                Expanded(child: _filtered.isEmpty ? _buildEmptyState(context) : _buildList(context)),
              ]),
            ),
    );
  }

  Widget _buildSearchBar(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(Responsive.pad(context), 12, Responsive.pad(context), 8),
    child: TextField(
      onChanged: (v) => setState(() { _search = v; _filtered = _applyFilter(_all); }),
      decoration: InputDecoration(
        hintText: 'Search by #, category, payee...',
        prefixIcon: const Icon(Icons.search, color: Color(0xFF7B1FA2)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2)),
      ),
    ),
  );

  Widget _buildFilterChips(BuildContext context) => SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: Responsive.pad(context)),
      itemCount: _filters.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final f = _filters[i];
        final selected = _filter == f;
        final count = _all.where((e) => f == 'All' ? !e.isDraft : e.status == f).length;
        return FilterChip(
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(f, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Colors.white : const Color(0xFF7B1FA2), fontSize: 12)),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF7B1FA2).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
                child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : const Color(0xFF7B1FA2)))),
            ],
          ]),
          selected: selected,
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFF7B1FA2),
          checkmarkColor: Colors.white,
          showCheckmark: false,
          side: BorderSide(color: selected ? const Color(0xFF7B1FA2) : Colors.grey.shade300),
          onSelected: (_) => _setFilter(f),
        );
      },
    ),
  );

  Widget _buildSummaryStrip(BuildContext context) {
    final total = _filtered.fold<double>(0, (s, e) => s + e.amount);
    return Padding(
      padding: EdgeInsets.fromLTRB(Responsive.pad(context), 8, Responsive.pad(context), 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF7B1FA2).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.summarize, size: 16, color: Color(0xFF7B1FA2)),
          const SizedBox(width: 6),
          Text('${_filtered.length} expense${_filtered.length == 1 ? "" : "s"}',
            style: const TextStyle(color: Color(0xFF7B1FA2), fontWeight: FontWeight.bold, fontSize: 12)),
          const Spacer(),
          Text('Total: ${AppSettings.currencySymbol}${total.toStringAsFixed(2)}',
            style: const TextStyle(color: Color(0xFF7B1FA2), fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
          child: Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade400)),
        const SizedBox(height: 20),
        Text('All caught up!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        const SizedBox(height: 8),
        Text(_filter == 'For Approval' ? 'No expenses pending approval' : 'No $_filter expenses',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
      ]),
    ),
  );

  Widget _buildList(BuildContext context) {
    final cols = Responsive.isPhone(context) ? 1 : Responsive.isTablet(context) ? 2 : 3;
    return RefreshIndicator(
      color: const Color(0xFF7B1FA2),
      onRefresh: _load,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Responsive.pad(context)),
        child: cols == 1
            ? ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _buildCard(context, _filtered[i]),
              )
            : GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                ),
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _buildCard(context, _filtered[i]),
              ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Expense e) {
    final statusColor = _statusColor(e.status);
    final statusIcon = _statusIcon(e.status);
    final canAction = e.isForApproval || e.isReturned;
    final isUrgent = e.priority == 'High' || e.priority == 'Urgent';

    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(Responsive.cardR(context)),
      child: InkWell(
        borderRadius: BorderRadius.circular(Responsive.cardR(context)),
        onTap: () => _showDetail(e),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 5, decoration: BoxDecoration(color: statusColor,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)))),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(Responsive.pad(context)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(e.status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ])),
                    if (isUrgent) ...[
                      const SizedBox(width: 6),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.priority_high, size: 11, color: Colors.red.shade700),
                          const SizedBox(width: 2),
                          Text('URGENT', style: TextStyle(color: Colors.red.shade700, fontSize: 9, fontWeight: FontWeight.bold)),
                        ])),
                    ],
                    const Spacer(),
                    Text(e.expenseNumber, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 8),
                  Text(e.categoryName.isEmpty ? 'Uncategorized' : e.categoryName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (e.subCategoryName.isNotEmpty)
                    Text(e.subCategoryName, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text('${AppSettings.currencySymbol}${e.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF7B1FA2))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.person, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(child: Text('By ${e.preparedBy}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis)),
                    Icon(Icons.calendar_today, size: 11, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(_fmtDate(e.expenseDate), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ]),
                  if (canAction) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _miniBtn('Approve', Icons.check, Colors.green.shade700, () => _approve(e))),
                      const SizedBox(width: 6),
                      Expanded(child: _miniBtn('Return', Icons.replay, Colors.orange.shade700, () => _returnExp(e))),
                      const SizedBox(width: 6),
                      Expanded(child: _miniBtn('Reject', Icons.close, Colors.red.shade700, () => _reject(e))),
                    ]),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _miniBtn(String label, IconData icon, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
    ),
  );

  void _showDetail(Expense e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.95, expand: false,
        builder: (_, ctrl) => SingleChildScrollView(controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(e.expenseNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text(e.status, style: TextStyle(color: _statusColor(e.status), fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            _dRow('Category', e.categoryName),
            if (e.subCategoryName.isNotEmpty) _dRow('Sub-Category', e.subCategoryName),
            _dRow('Amount', '${AppSettings.currencySymbol}${e.amount.toStringAsFixed(2)}'),
            _dRow('Payment Method', e.paymentMethod),
            _dRow('Expense Date', _fmtDate(e.expenseDate)),
            _dRow('Branch', e.branch),
            _dRow('Prepared By', e.preparedBy),
            if (e.payeeSupplier.isNotEmpty) _dRow('Payee', e.payeeSupplier),
            if (e.referenceNumber.isNotEmpty) _dRow('Reference #', e.referenceNumber),
            if (e.remarks.isNotEmpty) _dRow('Remarks', e.remarks),
            if (e.approvedBy.isNotEmpty) ...[
              const SizedBox(height: 8),
              _dRow('Approved By', e.approvedBy),
              if (e.approvalRemarks.isNotEmpty) _dRow('Approval Remarks', e.approvalRemarks),
            ],
            if (e.rejectedBy.isNotEmpty) ...[
              const SizedBox(height: 8),
              _dRow('Rejected By', e.rejectedBy),
              _dRow('Rejection Reason', e.rejectionReason),
            ],
            if (e.returnedBy.isNotEmpty) ...[
              const SizedBox(height: 8),
              _dRow('Returned By', e.returnedBy),
              _dRow('Return Reason', e.returnReason),
            ],
            const Divider(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Print'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF6A1B9A), side: const BorderSide(color: Color(0xFF6A1B9A)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () { Navigator.pop(context); ExpensePrintDialog.show(context, e); })),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Save PDF'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () { Navigator.pop(context); ExpensePrintDialog.show(context, e); })),
            ]),
            const SizedBox(height: 20),
          ]))),
    );
  }

  Widget _dRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );

  Color _statusColor(String s) {
    switch (s) {
      case 'Approved': return Colors.green.shade600;
      case 'Rejected': return Colors.red.shade600;
      case 'For Approval': return Colors.amber.shade700;
      case 'Returned': return Colors.orange.shade600;
      case 'Draft': return Colors.blue.shade400;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Approved': return Icons.check_circle;
      case 'Rejected': return Icons.cancel;
      case 'For Approval': return Icons.hourglass_top;
      case 'Returned': return Icons.replay;
      case 'Draft': return Icons.edit_note;
      default: return Icons.help_outline;
    }
  }

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.month}/${d.day}/${d.year}';
  }
}
