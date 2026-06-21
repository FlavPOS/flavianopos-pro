// lib/screens/expenses/expense_audit_screen.dart
// FlavianoPOS - PRO: Expense Audit Trail (Mobile + Tablet + Web)
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xl;
import '../../models/expense_model.dart';
import '../../utils/responsive.dart';
import '../../utils/download_helper.dart';

class ExpenseAuditScreen extends StatefulWidget {
  final String branch;
  const ExpenseAuditScreen({super.key, required this.branch});
  @override
  State<ExpenseAuditScreen> createState() => _ExpenseAuditScreenState();
}

class _ExpenseAuditScreenState extends State<ExpenseAuditScreen> {
  List<ExpenseAudit> _all = [];
  List<ExpenseAudit> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _actionFilter = 'All';
  String _userFilter = 'All';

  static const _actionFilters = ['All', 'Approved', 'Rejected', 'Returned', 'Edited', 'Submitted for Approval', 'Saved as Draft', 'Cancelled'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final a = await ExpenseStorage.getAuditTrail();
    final branchAudits = a.where((e) => e.branch.isEmpty || e.branch == widget.branch).toList();
    branchAudits.sort((x, y) => y.performedDate.compareTo(x.performedDate));
    setState(() { _all = branchAudits; _loading = false; });
    _applyFilters();
  }

  void _applyFilters() {
    var list = List<ExpenseAudit>.from(_all);
    if (_actionFilter != 'All') list = list.where((a) => a.action == _actionFilter).toList();
    if (_userFilter != 'All') list = list.where((a) => a.performedBy == _userFilter).toList();
    if (_search.isNotEmpty) {
      final s = _search.toLowerCase();
      list = list.where((a) =>
        a.expenseNumber.toLowerCase().contains(s) ||
        a.performedBy.toLowerCase().contains(s) ||
        a.action.toLowerCase().contains(s) ||
        a.newValue.toLowerCase().contains(s)
      ).toList();
    }
    setState(() => _filtered = list);
  }

  List<String> get _availableUsers {
    final users = _all.map((a) => a.performedBy).toSet().toList()..sort();
    return ['All', ...users];
  }

  Color _actionColor(String a) {
    switch (a) {
      case 'Approved': return Colors.green.shade600;
      case 'Rejected': return Colors.red.shade600;
      case 'Returned': return Colors.orange.shade600;
      case 'Cancelled': return Colors.grey.shade600;
      case 'Submitted for Approval': return Colors.amber.shade700;
      case 'Saved as Draft': return Colors.blue.shade400;
      case 'Edited': return Colors.teal.shade600;
      default: return const Color(0xFF7B1FA2);
    }
  }

  IconData _actionIcon(String a) {
    switch (a) {
      case 'Approved': return Icons.check_circle;
      case 'Rejected': return Icons.cancel;
      case 'Returned': return Icons.replay;
      case 'Cancelled': return Icons.block;
      case 'Submitted for Approval': return Icons.send;
      case 'Saved as Draft': return Icons.save;
      case 'Edited': return Icons.edit;
      default: return Icons.info;
    }
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(m, style: const TextStyle(fontWeight: FontWeight.w600)),
    backgroundColor: c, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  Future<void> _exportExcel() async {
    if (_filtered.isEmpty) { _snack('No data to export', Colors.orange); return; }
    final excel = xl.Excel.createExcel();
    final sheet = excel['Audit Trail'];
    excel.delete('Sheet1');
    final hs = xl.CellStyle(bold: true,
      fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: xl.ExcelColor.fromHexString('#7B1FA2'));
    final headers = ['Date', 'Time', 'Expense #', 'Action', 'Performed By', 'Details', 'Branch'];
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = xl.TextCellValue(headers[c]);
      cell.cellStyle = hs;
    }
    for (var i = 0; i < _filtered.length; i++) {
      final a = _filtered[i];
      final dt = DateTime.tryParse(a.performedDate);
      final dateStr = dt != null ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}' : a.performedDate;
      final timeStr = dt != null ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' : '';
      final r = i + 1;
      final vals = [dateStr, timeStr, a.expenseNumber, a.action, a.performedBy, a.newValue, a.branch];
      for (var c = 0; c < vals.length; c++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).value = xl.TextCellValue(vals[c]);
      }
    }
    final bytes = excel.save();
    if (bytes != null) {
      await saveFileBytes('audit_trail_${DateTime.now().millisecondsSinceEpoch}.xlsx', bytes);
      _snack('Audit trail exported!', Colors.green);
    }
  }

  String _dateHeader(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dDay = DateTime(d.year, d.month, d.day);
    if (dDay == today) return 'Today';
    if (dDay == yesterday) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _timeStr(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F8),
      appBar: AppBar(elevation: 0, backgroundColor: const Color(0xFF7B1FA2), foregroundColor: Colors.white,
        title: Text('Audit Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.titleSz(context))),
        actions: [
          IconButton(icon: const Icon(Icons.file_download), tooltip: 'Export Excel', onPressed: _exportExcel),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _load),
        ]),
      body: _loading ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B1FA2)))
        : Responsive.centered(context: context, child: Column(children: [
            _buildSearchBar(context),
            _buildActionChips(context),
            _buildUserDropdown(context),
            _buildSummaryStrip(context),
            Expanded(child: _filtered.isEmpty ? _buildEmptyState(context) : _buildTimeline(context)),
          ])));
  }

  Widget _buildSearchBar(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(Responsive.pad(context), 12, Responsive.pad(context), 8),
    child: TextField(onChanged: (v) { setState(() => _search = v); _applyFilters(); },
      decoration: InputDecoration(hintText: 'Search expense#, user, action...',
        prefixIcon: const Icon(Icons.search, color: Color(0xFF7B1FA2)),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2)))));

  Widget _buildActionChips(BuildContext context) => SizedBox(
    height: 40,
    child: ListView.separated(scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: Responsive.pad(context)),
      itemCount: _actionFilters.length,
      separatorBuilder: (_, __) => const SizedBox(width: 6),
      itemBuilder: (_, i) {
        final f = _actionFilters[i];
        final selected = _actionFilter == f;
        final color = f == 'All' ? const Color(0xFF7B1FA2) : _actionColor(f);
        return FilterChip(
          label: Text(f, style: TextStyle(fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : color)),
          selected: selected,
          backgroundColor: Colors.white,
          selectedColor: color,
          showCheckmark: false,
          side: BorderSide(color: selected ? color : Colors.grey.shade300),
          onSelected: (_) { setState(() => _actionFilter = f); _applyFilters(); });
      }));

  Widget _buildUserDropdown(BuildContext context) {
    final users = _availableUsers;
    if (users.length <= 1) return const SizedBox.shrink();
    return Padding(padding: EdgeInsets.fromLTRB(Responsive.pad(context), 8, Responsive.pad(context), 0),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
        child: Row(children: [
          Icon(Icons.person, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('User:', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(child: DropdownButton<String>(
            value: _userFilter, isExpanded: true, underline: const SizedBox(),
            style: const TextStyle(fontSize: 12, color: Color(0xFF424242), fontWeight: FontWeight.w500),
            items: users.map((u) => DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) { setState(() => _userFilter = v!); _applyFilters(); })),
        ])));
  }

  Widget _buildSummaryStrip(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(Responsive.pad(context), 8, Responsive.pad(context), 4),
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF7B1FA2).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.history, size: 16, color: Color(0xFF7B1FA2)),
        const SizedBox(width: 6),
        Text('${_filtered.length} record${_filtered.length == 1 ? "" : "s"}',
          style: const TextStyle(color: Color(0xFF7B1FA2), fontWeight: FontWeight.bold, fontSize: 12)),
        const Spacer(),
        if (_filtered.isNotEmpty) Text('Latest: ${_filtered.first.performedDate.length > 10 ? _filtered.first.performedDate.substring(0, 10) : _filtered.first.performedDate}',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
      ])));

  Widget _buildEmptyState(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
          child: Icon(Icons.policy, size: 56, color: Colors.grey.shade400)),
        const SizedBox(height: 16),
        Text(_search.isEmpty && _actionFilter == 'All' && _userFilter == 'All'
            ? 'No audit trail yet'
            : 'No matches found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        Text(_search.isEmpty && _actionFilter == 'All' && _userFilter == 'All'
            ? 'All expense activity will appear here'
            : 'Try different filters',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      ])));

  Widget _buildTimeline(BuildContext context) {
    final Map<String, List<ExpenseAudit>> grouped = {};
    for (final a in _filtered) {
      final dt = DateTime.tryParse(a.performedDate);
      if (dt == null) continue;
      final key = _dateHeader(dt);
      grouped.putIfAbsent(key, () => []).add(a);
    }
    return RefreshIndicator(color: const Color(0xFF7B1FA2), onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(Responsive.pad(context), 8, Responsive.pad(context), 16),
        itemCount: grouped.length,
        itemBuilder: (_, idx) {
          final dateKey = grouped.keys.elementAt(idx);
          final items = grouped[dateKey]!;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF7B1FA2),
                    borderRadius: BorderRadius.circular(12)),
                  child: Text(dateKey,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
              ])),
            ...items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return _buildTimelineItem(context, e.value, isLast);
            }),
          ]);
        }));
  }

  Widget _buildTimelineItem(BuildContext context, ExpenseAudit a, bool isLast) {
    final color = _actionColor(a.action);
    final icon = _actionIcon(a.action);
    final dt = DateTime.tryParse(a.performedDate);
    final timeStr = dt != null ? _timeStr(dt) : a.performedDate;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
              border: Border.all(color: color, width: 2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16)),
          if (!isLast) Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Padding(padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: Material(color: Colors.white,
            borderRadius: BorderRadius.circular(Responsive.cardR(context)),
            elevation: 1,
            child: Padding(padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6)),
                    child: Text(a.action, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
                  const Spacer(),
                  Icon(Icons.access_time, size: 11, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text(timeStr, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 8),
                Text(a.expenseNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                if (a.newValue.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(a.newValue, style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  Container(padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                    child: Icon(Icons.person, size: 11, color: Colors.grey.shade700)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(a.performedBy,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis)),
                  if (a.branch.isNotEmpty) ...[
                    Icon(Icons.store, size: 11, color: Colors.grey.shade500),
                    const SizedBox(width: 3),
                    Text(a.branch, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ]),
              ])))))
      ]));
  }
}
