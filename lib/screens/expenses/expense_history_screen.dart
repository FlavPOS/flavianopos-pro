// lib/screens/expenses/expense_history_screen.dart
// FlavianoPOS - PRO: Expense History (Mobile + Tablet + Web)
import 'package:flutter/material.dart';
import '../../models/settings_model.dart';
import 'package:excel/excel.dart' as xl;
import '../../utils/download_helper.dart';
import '../../utils/responsive.dart';
import '../../models/expense_model.dart';
import '../../utils/expense_print_dialog.dart';
import 'encode_expense_screen.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  final String currentUser, branch;
  const ExpenseHistoryScreen({super.key, required this.currentUser, required this.branch});
  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  List<Expense> _all = [];
  List<Expense> _filtered = [];
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'All';
  String _dateFilter = 'All';
  DateTime? _dateFrom, _dateTo;
  bool _loading = true;
  String _sortBy = 'newest';

  static const _statuses = ['All', 'Draft', 'For Approval', 'Approved', 'Rejected', 'Returned', 'Cancelled'];
  static const _dates = ['All', 'Today', 'Yesterday', 'This Week', 'This Month', 'Last Month'];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await ExpenseStorage.getAll();
    final branchExp = all.where((e) => e.branch == widget.branch).toList();
    setState(() { _all = branchExp; _loading = false; });
    _applyFilters();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _applyFilters() {
    var list = List<Expense>.from(_all);
    if (_statusFilter != 'All') list = list.where((e) => e.status == _statusFilter).toList();
    if (_dateFrom != null) list = list.where((e) => e.expenseDate.compareTo(_fmtDate(_dateFrom!)) >= 0).toList();
    if (_dateTo != null) list = list.where((e) => e.expenseDate.compareTo(_fmtDate(_dateTo!)) <= 0).toList();
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) =>
        e.expenseNumber.toLowerCase().contains(q) ||
        e.categoryName.toLowerCase().contains(q) ||
        e.subCategoryName.toLowerCase().contains(q) ||
        e.remarks.toLowerCase().contains(q) ||
        e.preparedBy.toLowerCase().contains(q) ||
        e.payeeSupplier.toLowerCase().contains(q) ||
        e.referenceNumber.toLowerCase().contains(q)
      ).toList();
    }
    switch (_sortBy) {
      case 'oldest': list.sort((a, b) => a.expenseDate.compareTo(b.expenseDate)); break;
      case 'highest': list.sort((a, b) => b.amount.compareTo(a.amount)); break;
      case 'lowest': list.sort((a, b) => a.amount.compareTo(b.amount)); break;
      default: list.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    }
    setState(() => _filtered = list);
  }

  void _setQuickDate(String label) {
    final now = DateTime.now();
    switch (label) {
      case 'Today': _dateFrom = _dateTo = now; break;
      case 'Yesterday': final y = now.subtract(const Duration(days: 1)); _dateFrom = _dateTo = y; break;
      case 'This Week':
        _dateFrom = now.subtract(Duration(days: now.weekday - 1));
        _dateTo = _dateFrom!.add(const Duration(days: 6)); break;
      case 'This Month':
        _dateFrom = DateTime(now.year, now.month, 1);
        _dateTo = DateTime(now.year, now.month + 1, 0); break;
      case 'Last Month':
        _dateFrom = DateTime(now.year, now.month - 1, 1);
        _dateTo = DateTime(now.year, now.month, 0); break;
      default: _dateFrom = null; _dateTo = null;
    }
    _dateFilter = label;
    _applyFilters();
  }

  void _editExpense(Expense e) async {
    if (!e.canEdit) { _snack('Cannot edit ${e.status} expense', Colors.orange); return; }
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => EncodeExpenseScreen(currentUser: widget.currentUser, branch: widget.branch, expense: e)));
    if (result == true) _load();
  }

  Future<void> _cancelExpense(Expense e) async {
    if (!e.canCancel) { _snack('Cannot cancel ${e.status} expense', Colors.orange); return; }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.cancel, color: Colors.red.shade700),
          const SizedBox(width: 8),
          const Text('Cancel Expense?'),
        ]),
        content: Text('Cancel ${e.expenseNumber}?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final now = DateTime.now();
      await ExpenseStorage.updateExpense(e.id, e.copyWith(
        status: 'Cancelled', updatedBy: widget.currentUser, updatedDate: now.toIso8601String()));
      await ExpenseStorage.addAudit(ExpenseAudit(
        id: 'AUD-${now.millisecondsSinceEpoch}',
        expenseId: e.id, expenseNumber: e.expenseNumber,
        action: 'Cancelled', performedBy: widget.currentUser,
        performedDate: now.toIso8601String(), branch: widget.branch));
      _load();
      _snack('Expense cancelled', Colors.red);
    }
  }

  Future<void> _exportExcel() async {
    if (_filtered.isEmpty) { _snack('No data to export', Colors.orange); return; }
    final excel = xl.Excel.createExcel();
    final sheet = excel['Expenses'];
    excel.delete('Sheet1');
    final hs = xl.CellStyle(
      bold: true,
      fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: xl.ExcelColor.fromHexString('#7B1FA2'));
    final headers = ['Expense #', 'Date', 'Branch', 'Category', 'Sub Category', 'Amount',
      'Payment', 'Type', 'Priority', 'Payee', 'Ref #', 'Remarks', 'Prepared By', 'Status',
      'Approved By', 'Approved Date', 'Rejected By', 'Rejection Reason'];
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = xl.TextCellValue(headers[c]);
      cell.cellStyle = hs;
    }
    for (var i = 0; i < _filtered.length; i++) {
      final e = _filtered[i];
      final r = i + 1;
      final vals = [e.expenseNumber, e.expenseDate, e.branch, e.categoryName, e.subCategoryName,
        e.amount.toStringAsFixed(2), e.paymentMethod, e.expenseType, e.priority, e.payeeSupplier,
        e.referenceNumber, e.remarks, e.preparedBy, e.status, e.approvedBy, e.approvedDate,
        e.rejectedBy, e.rejectionReason];
      for (var c = 0; c < vals.length; c++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
          .value = xl.TextCellValue(vals[c]);
      }
    }
    final bytes = excel.save();
    if (bytes != null) {
      await saveFileBytes('expenses_${DateTime.now().millisecondsSinceEpoch}.xlsx', bytes);
      _snack('✅ Excel exported!', Colors.green);
    }
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(m, style: const TextStyle(fontWeight: FontWeight.w600)),
    backgroundColor: c,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));

  // ════════════ BUILD ════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        title: Text('History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.titleSz(context))),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (v) { setState(() => _sortBy = v); _applyFilters(); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'newest', child: Text('🆕 Newest first')),
              PopupMenuItem(value: 'oldest', child: Text('📅 Oldest first')),
              PopupMenuItem(value: 'highest', child: Text('💰 Highest amount')),
              PopupMenuItem(value: 'lowest', child: Text('💵 Lowest amount')),
            ],
          ),
          IconButton(icon: const Icon(Icons.file_download), tooltip: 'Export Excel', onPressed: _exportExcel),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B1FA2)))
          : Responsive.centered(
              context: context,
              child: Column(children: [
                _buildSearchBar(context),
                _buildStatusChips(context),
                _buildDateChips(context),
                _buildSummaryStrip(context),
                Expanded(child: _filtered.isEmpty ? _buildEmptyState(context) : _buildList(context)),
              ]),
            ),
    );
  }

  Widget _buildSearchBar(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(Responsive.pad(context), 12, Responsive.pad(context), 8),
    child: TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Search expense#, category, payee, remarks...',
        prefixIcon: const Icon(Icons.search, color: Color(0xFF7B1FA2)),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _applyFilters(); })
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2)),
      ),
    ),
  );

  Widget _buildStatusChips(BuildContext context) => SizedBox(
    height: 40,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: Responsive.pad(context)),
      itemCount: _statuses.length,
      separatorBuilder: (_, __) => const SizedBox(width: 6),
      itemBuilder: (_, i) {
        final s = _statuses[i];
        final selected = _statusFilter == s;
        final color = _sc(s);
        final count = _all.where((e) => s == 'All' ? true : e.status == s).length;
        return FilterChip(
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(s, style: TextStyle(fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Colors.white : color)),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text('($count)', style: TextStyle(fontSize: 10,
                color: selected ? Colors.white.withValues(alpha: 0.85) : color.withValues(alpha: 0.7))),
            ],
          ]),
          selected: selected,
          backgroundColor: Colors.white,
          selectedColor: color,
          showCheckmark: false,
          side: BorderSide(color: selected ? color : Colors.grey.shade300),
          onSelected: (_) { setState(() => _statusFilter = s); _applyFilters(); },
        );
      },
    ),
  );

  Widget _buildDateChips(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: Responsive.pad(context)),
        itemCount: _dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final d = _dates[i];
          final selected = _dateFilter == d;
          return FilterChip(
            label: Text(d, style: TextStyle(fontSize: 10,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Colors.white : Colors.teal.shade700)),
            selected: selected,
            backgroundColor: Colors.white,
            selectedColor: Colors.teal.shade600,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: selected ? Colors.teal.shade600 : Colors.grey.shade300),
            onSelected: (_) => _setQuickDate(d),
          );
        },
      ),
    ),
  );

  Widget _buildSummaryStrip(BuildContext context) {
    final total = _filtered.fold<double>(0, (s, e) => s + e.amount);
    final approved = _filtered.where((e) => e.isApproved).fold<double>(0, (s, e) => s + e.amount);
    final pending = _filtered.where((e) => e.isForApproval).fold<double>(0, (s, e) => s + e.amount);
    return Padding(
      padding: EdgeInsets.fromLTRB(Responsive.pad(context), 10, Responsive.pad(context), 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF7B1FA2).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_filtered.length} expense${_filtered.length == 1 ? "" : "s"}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
            const SizedBox(height: 2),
            Text('${AppSettings.currencySymbol}${total.toStringAsFixed(2)}',
              style: const TextStyle(color: Color(0xFF7B1FA2), fontWeight: FontWeight.bold, fontSize: 14)),
          ])),
          Container(width: 1, height: 32, color: Colors.grey.shade300),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Approved', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
            const SizedBox(height: 2),
            Text('${AppSettings.currencySymbol}${approved.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
          ])),
          Container(width: 1, height: 32, color: Colors.grey.shade300),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pending', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
            const SizedBox(height: 2),
            Text('${AppSettings.currencySymbol}${pending.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
          ])),
        ]),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
          child: Icon(Icons.receipt_long, size: 56, color: Colors.grey.shade400)),
        const SizedBox(height: 16),
        Text('No expenses found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        Text(_searchCtrl.text.isNotEmpty
            ? 'Try adjusting your search or filters'
            : 'Your expense history will appear here',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
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
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _buildCard(context, _filtered[i]),
              )
            : GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _buildCard(context, _filtered[i]),
              ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Expense e) {
    final sc = _sc(e.status);
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(Responsive.cardR(context)),
      child: InkWell(
        borderRadius: BorderRadius.circular(Responsive.cardR(context)),
        onTap: () => _showDetail(e),
        onLongPress: () => ExpensePrintDialog.show(context, e),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 5, decoration: BoxDecoration(color: sc,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)))),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(Responsive.pad(context)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: sc.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_statusIcon(e.status), size: 12, color: sc),
                        const SizedBox(width: 4),
                        Text(e.status, style: TextStyle(color: sc, fontSize: 10, fontWeight: FontWeight.bold)),
                      ])),
                    const Spacer(),
                    Text(e.expenseNumber,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                    if (e.canEdit || e.canCancel)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
                        padding: EdgeInsets.zero,
                        onSelected: (v) {
                          if (v == 'edit') _editExpense(e);
                          if (v == 'cancel') _cancelExpense(e);
                        },
                        itemBuilder: (_) => [
                          if (e.canEdit) const PopupMenuItem(value: 'edit',
                            child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit')])),
                          if (e.canCancel) PopupMenuItem(value: 'cancel',
                            child: Row(children: [Icon(Icons.cancel, size: 16, color: Colors.red.shade700),
                              const SizedBox(width: 8), const Text('Cancel')])),
                        ],
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Text(e.categoryName.isEmpty ? 'Uncategorized' : e.categoryName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (e.subCategoryName.isNotEmpty)
                    Text(e.subCategoryName,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(child: Text('${AppSettings.currencySymbol}${e.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF7B1FA2)))),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (e.payeeSupplier.isNotEmpty)
                        Text(e.payeeSupplier,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                      Text(e.expenseDate,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ]),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

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
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(e.expenseNumber,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _sc(e.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(e.status,
                  style: TextStyle(color: _sc(e.status), fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
            const Divider(height: 24),
            _dRow('Category', e.categoryName),
            if (e.subCategoryName.isNotEmpty) _dRow('Sub-Category', e.subCategoryName),
            _dRow('Amount', '${AppSettings.currencySymbol}${e.amount.toStringAsFixed(2)}'),
            _dRow('Payment Method', e.paymentMethod),
            _dRow('Expense Type', e.expenseType),
            _dRow('Priority', e.priority),
            _dRow('Expense Date', e.expenseDate),
            _dRow('Branch', e.branch),
            _dRow('Prepared By', e.preparedBy),
            if (e.payeeSupplier.isNotEmpty) _dRow('Payee', e.payeeSupplier),
            if (e.referenceNumber.isNotEmpty) _dRow('Reference #', e.referenceNumber),
            if (e.remarks.isNotEmpty) _dRow('Remarks', e.remarks),
            if (e.approvedBy.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              _dRow('Approved By', e.approvedBy),
              _dRow('Approved Date', e.approvedDate),
              if (e.approvalRemarks.isNotEmpty) _dRow('Approval Remarks', e.approvalRemarks),
            ],
            if (e.rejectedBy.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              _dRow('Rejected By', e.rejectedBy),
              _dRow('Rejection Reason', e.rejectionReason),
            ],
            if (e.returnedBy.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
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
            const SizedBox(height: 12),
            const SizedBox(height: 20),
            if (e.canEdit || e.canCancel)
              Row(children: [
                if (e.canEdit)
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () { Navigator.pop(context); _editExpense(e); },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: const Color(0xFF7B1FA2),
                      side: const BorderSide(color: Color(0xFF7B1FA2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
                if (e.canEdit && e.canCancel) const SizedBox(width: 10),
                if (e.canCancel)
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () { Navigator.pop(context); _cancelExpense(e); },
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
              ]),
            const SizedBox(height: 12),
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

  Color _sc(String s) {
    switch (s) {
      case 'For Approval': return Colors.amber.shade700;
      case 'Approved': return Colors.green.shade600;
      case 'Rejected': return Colors.red.shade600;
      case 'Returned': return Colors.orange.shade600;
      case 'Draft': return Colors.blue.shade400;
      case 'Cancelled': return Colors.grey.shade600;
      default: return const Color(0xFF7B1FA2);
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Approved': return Icons.check_circle;
      case 'Rejected': return Icons.cancel;
      case 'For Approval': return Icons.hourglass_top;
      case 'Returned': return Icons.replay;
      case 'Draft': return Icons.edit_note;
      case 'Cancelled': return Icons.block;
      default: return Icons.receipt_long;
    }
  }
}
