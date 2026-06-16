import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xl;
import '../../utils/download_helper.dart';
import '../../models/expense_model.dart';
import 'encode_expense_screen.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  final String currentUser, branch;
  const ExpenseHistoryScreen({super.key, required this.currentUser, required this.branch});
  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  List<Expense> _all = [], _filtered = [];
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'All';
  String _dateFilter = 'All';
  DateTime? _dateFrom, _dateTo;
  bool _loading = true;
  String _sortBy = 'newest';

  static const _statuses = ['All', 'Draft', 'For Approval', 'Approved', 'Rejected', 'Returned', 'Cancelled'];

  @override
  void initState() { super.initState(); _load(); _searchCtrl.addListener(_applyFilters); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async { final all = await ExpenseStorage.getAll(); setState(() { _all = all; _loading = false; }); _applyFilters(); }

  void _applyFilters() {
    var list = List<Expense>.from(_all);
    if (_statusFilter != 'All') list = list.where((e) => e.status == _statusFilter).toList();
    if (_dateFrom != null) list = list.where((e) => e.expenseDate.compareTo(_fmtDate(_dateFrom!)) >= 0).toList();
    if (_dateTo != null) list = list.where((e) => e.expenseDate.compareTo(_fmtDate(_dateTo!)) <= 0).toList();
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) list = list.where((e) => e.expenseNumber.toLowerCase().contains(q) || e.categoryName.toLowerCase().contains(q) || e.subCategoryName.toLowerCase().contains(q) || e.remarks.toLowerCase().contains(q) || e.preparedBy.toLowerCase().contains(q) || e.payeeSupplier.toLowerCase().contains(q) || e.referenceNumber.toLowerCase().contains(q)).toList();
    switch (_sortBy) { case 'oldest': list.sort((a, b) => a.expenseDate.compareTo(b.expenseDate)); case 'highest': list.sort((a, b) => b.amount.compareTo(a.amount)); case 'lowest': list.sort((a, b) => a.amount.compareTo(b.amount)); default: list.sort((a, b) => b.expenseDate.compareTo(a.expenseDate)); }
    setState(() => _filtered = list);
  }

  void _setQuickDate(String label) {
    final now = DateTime.now();
    switch (label) {
      case 'Today': _dateFrom = _dateTo = now;
      case 'Yesterday': _dateFrom = _dateTo = now.subtract(const Duration(days: 1));
      case 'This Week': _dateFrom = now.subtract(Duration(days: now.weekday - 1)); _dateTo = now;
      case 'This Month': _dateFrom = DateTime(now.year, now.month, 1); _dateTo = now;
      case 'Last Month': _dateFrom = DateTime(now.year, now.month - 1, 1); _dateTo = DateTime(now.year, now.month, 0);
      default: _dateFrom = null; _dateTo = null;
    }
    _dateFilter = label; _applyFilters();
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  Color _sc(String s) => switch (s) { 'For Approval' => Colors.orange, 'Approved' => Colors.green, 'Rejected' => Colors.red, 'Returned' => Colors.blue, 'Draft' => Colors.grey, 'Cancelled' => Colors.grey, _ => Colors.grey };

  void _editExpense(Expense e) async {
    if (!e.canEdit) { _snack('Cannot edit ${e.status} expense'); return; }
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EncodeExpenseScreen(currentUser: widget.currentUser, branch: widget.branch, expense: e)));
    if (result == true) _load();
  }

  void _cancelExpense(Expense e) async {
    if (!e.canCancel) { _snack('Cannot cancel ${e.status} expense'); return; }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Cancel Expense?'), content: Text('Cancel ${e.expenseNumber}?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Cancel', style: TextStyle(color: Colors.white)))]));
    if (ok == true) {
      final now = DateTime.now();
      await ExpenseStorage.updateExpense(e.id, e.copyWith(status: 'Cancelled', updatedBy: widget.currentUser, updatedDate: now.toIso8601String()));
      await ExpenseStorage.addAudit(ExpenseAudit(id: 'AUD-${now.millisecondsSinceEpoch}', expenseId: e.id, expenseNumber: e.expenseNumber, action: 'Cancelled', performedBy: widget.currentUser, performedDate: now.toIso8601String(), branch: widget.branch));
      _load(); _snack('Expense cancelled');
    }
  }

  Future<void> _exportExcel() async {
    if (_filtered.isEmpty) { _snack('No data'); return; }
    final excel = xl.Excel.createExcel(); final sheet = excel['Expenses']; excel.delete('Sheet1');
    final hs = xl.CellStyle(bold: true, fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'), backgroundColorHex: xl.ExcelColor.fromHexString('#6A1B9A'));
    final headers = ['Expense #', 'Date', 'Branch', 'Category', 'Sub Category', 'Amount', 'Payment', 'Type', 'Priority', 'Payee', 'Ref #', 'Remarks', 'Prepared By', 'Status', 'Approved By', 'Approved Date', 'Rejected By', 'Rejection Reason'];
    for (var c = 0; c < headers.length; c++) { final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)); cell.value = xl.TextCellValue(headers[c]); cell.cellStyle = hs; }
    for (var i = 0; i < _filtered.length; i++) { final e = _filtered[i]; final r = i + 1;
      final vals = [e.expenseNumber, e.expenseDate, e.branch, e.categoryName, e.subCategoryName, e.amount.toStringAsFixed(2), e.paymentMethod, e.expenseType, e.priority, e.payeeSupplier, e.referenceNumber, e.remarks, e.preparedBy, e.status, e.approvedBy, e.approvedDate, e.rejectedBy, e.rejectionReason];
      for (var c = 0; c < vals.length; c++) { sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).value = xl.TextCellValue(vals[c]); } }
    final bytes = excel.save(); if (bytes != null) { await saveFileBytes('expenses_${DateTime.now().millisecondsSinceEpoch}.xlsx', bytes); _snack('Excel exported!'); }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final total = _filtered.fold(0.0, (s, e) => s + e.amount);
    return Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.all(10), child: Column(children: [
        TextField(controller: _searchCtrl, style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(hintText: 'Search expense#, category, payee...', prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); _applyFilters(); }) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10))),
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (final s in _statuses) Padding(padding: const EdgeInsets.only(right: 4), child: ChoiceChip(label: Text(s, style: TextStyle(fontSize: 10, color: _statusFilter == s ? Colors.white : Colors.grey[700])),
            selected: _statusFilter == s, selectedColor: const Color(0xFF6A1B9A), onSelected: (_) { _statusFilter = s; _applyFilters(); }))])),
        const SizedBox(height: 6),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (final d in ['All', 'Today', 'Yesterday', 'This Week', 'This Month', 'Last Month']) Padding(padding: const EdgeInsets.only(right: 4), child: ChoiceChip(label: Text(d, style: TextStyle(fontSize: 10, color: _dateFilter == d ? Colors.white : Colors.grey[700])),
            selected: _dateFilter == d, selectedColor: Colors.teal, onSelected: (_) => _setQuickDate(d)))])),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), color: Colors.purple[50],
        child: Row(children: [Text('${_filtered.length} expense(s)', style: TextStyle(fontSize: 12, color: Colors.grey[600])), const Spacer(),
          Text('Total: ${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple[800])),
          const SizedBox(width: 8), PopupMenuButton<String>(icon: const Icon(Icons.sort, size: 18), tooltip: 'Sort',
            onSelected: (v) { _sortBy = v; _applyFilters(); },
            itemBuilder: (_) => [for (final s in ['newest', 'oldest', 'highest', 'lowest']) PopupMenuItem(value: s, child: Text(s))]),
          IconButton(icon: const Icon(Icons.file_download, size: 18, color: Colors.green), tooltip: 'Excel', onPressed: _exportExcel)])),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
        : _filtered.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.receipt_long, size: 48, color: Colors.grey[300]), const SizedBox(height: 8), Text('No expenses found', style: TextStyle(color: Colors.grey[500]))]))
        : RefreshIndicator(onRefresh: _load, child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _filtered.length,
            itemBuilder: (_, i) { final e = _filtered[i]; final sc = _sc(e.status);
              return Card(margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  title: Row(children: [Expanded(child: Text(e.expenseNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(e.status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: sc)))]),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${e.categoryName} > ${e.subCategoryName}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    Row(children: [Text(e.amount.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple[800])), const Spacer(), Text(e.expenseDate, style: TextStyle(fontSize: 10, color: Colors.grey[500]))])]),
                  trailing: PopupMenuButton<String>(icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (v) { if (v == 'edit') _editExpense(e); if (v == 'cancel') _cancelExpense(e); },
                    itemBuilder: (_) => [if (e.canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')), if (e.canCancel) const PopupMenuItem(value: 'cancel', child: Text('Cancel'))]),
                )); }))),
    ]);
  }
}
