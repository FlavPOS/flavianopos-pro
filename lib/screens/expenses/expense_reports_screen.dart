// lib/screens/expenses/expense_reports_screen.dart
// FlavianoPOS - PRO: Expense Reports (Mobile + Tablet + Web)
import 'package:flutter/material.dart';
import '../../models/settings_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart' as xl;
import '../../models/expense_model.dart';
import '../../utils/responsive.dart';
import '../../utils/download_helper.dart';

class ExpenseReportsScreen extends StatefulWidget {
  final String branch;
  const ExpenseReportsScreen({super.key, required this.branch});
  @override
  State<ExpenseReportsScreen> createState() => _ExpenseReportsScreenState();
}

class _ExpenseReportsScreenState extends State<ExpenseReportsScreen> {
  List<Expense> _allExpenses = [];
  List<Expense> _filtered = [];
  bool _loading = true;
  String _reportType = 'Category';
  String _dateRange = 'This Month';
  DateTime? _customFrom, _customTo;

  static const _reportTypes = ['Category', 'Sub Category', 'Payment Method', 'Branch', 'Prepared By'];
  static const _dateRanges = ['Today', 'This Week', 'This Month', 'Last Month', 'This Year', 'All Time', 'Custom'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await ExpenseStorage.getAll();
    setState(() {
      _allExpenses = all.where((e) => e.branch == widget.branch && e.isApproved).toList();
      _loading = false;
    });
    _applyDateFilter();
  }

  void _applyDateFilter() {
    final now = DateTime.now();
    DateTime? from, to;
    switch (_dateRange) {
      case 'Today':
        from = DateTime(now.year, now.month, now.day);
        to = from.add(const Duration(days: 1)); break;
      case 'This Week':
        from = now.subtract(Duration(days: now.weekday - 1));
        from = DateTime(from.year, from.month, from.day);
        to = from.add(const Duration(days: 7)); break;
      case 'This Month':
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 1); break;
      case 'Last Month':
        from = DateTime(now.year, now.month - 1, 1);
        to = DateTime(now.year, now.month, 1); break;
      case 'This Year':
        from = DateTime(now.year, 1, 1);
        to = DateTime(now.year + 1, 1, 1); break;
      case 'Custom':
        from = _customFrom; to = _customTo; break;
      default: from = null; to = null;
    }
    setState(() {
      _filtered = _allExpenses.where((e) {
        final d = DateTime.tryParse(e.expenseDate);
        if (d == null) return false;
        if (from != null && d.isBefore(from)) return false;
        if (to != null && d.isAfter(to)) return false;
        return true;
      }).toList();
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF7B1FA2)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dateRange = 'Custom';
        _customFrom = picked.start;
        _customTo = picked.end.add(const Duration(days: 1));
      });
      _applyDateFilter();
    }
  }

  Map<String, double> _groupBy(String Function(Expense) keyFn) {
    final map = <String, double>{};
    for (final e in _filtered) {
      final k = keyFn(e).isEmpty ? 'Uncategorized' : keyFn(e);
      map[k] = (map[k] ?? 0) + e.amount;
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  Map<String, double> _grouped() {
    switch (_reportType) {
      case 'Sub Category': return _groupBy((e) => '${e.categoryName} › ${e.subCategoryName}');
      case 'Payment Method': return _groupBy((e) => e.paymentMethod);
      case 'Branch': return _groupBy((e) => e.branch);
      case 'Prepared By': return _groupBy((e) => e.preparedBy);
      default: return _groupBy((e) => e.categoryName);
    }
  }

  Future<void> _exportExcel() async {
    if (_filtered.isEmpty) { _snack('No data to export', Colors.orange); return; }
    final excel = xl.Excel.createExcel();
    final sheet = excel['Report - $_reportType'];
    excel.delete('Sheet1');
    final hs = xl.CellStyle(
      bold: true,
      fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: xl.ExcelColor.fromHexString('#7B1FA2'));

    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = xl.TextCellValue('Report Type:')
      ..cellStyle = hs;
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
      .value = xl.TextCellValue(_reportType);
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      ..value = xl.TextCellValue('Date Range:')
      ..cellStyle = hs;
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1))
      .value = xl.TextCellValue(_dateRange);
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
      ..value = xl.TextCellValue('Branch:')
      ..cellStyle = hs;
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2))
      .value = xl.TextCellValue(widget.branch);

    final headers = [_reportType, 'Amount (PHP)', 'Percentage', 'Count'];
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 4));
      cell.value = xl.TextCellValue(headers[c]);
      cell.cellStyle = hs;
    }
    final grouped = _grouped();
    final total = grouped.values.fold<double>(0, (s, v) => s + v);
    var row = 5;
    for (final entry in grouped.entries) {
      final pct = total > 0 ? (entry.value / total * 100) : 0.0;
      final count = _filtered.where((e) {
        switch (_reportType) {
          case 'Sub Category': return '${e.categoryName} › ${e.subCategoryName}' == entry.key;
          case 'Payment Method': return e.paymentMethod == entry.key;
          case 'Branch': return e.branch == entry.key;
          case 'Prepared By': return e.preparedBy == entry.key;
          default: return e.categoryName == entry.key;
        }
      }).length;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue(entry.key);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.TextCellValue(entry.value.toStringAsFixed(2));
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.TextCellValue('${pct.toStringAsFixed(1)}%');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.IntCellValue(count);
      row++;
    }
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row + 1))
      ..value = xl.TextCellValue('TOTAL')
      ..cellStyle = hs;
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row + 1))
      ..value = xl.TextCellValue(total.toStringAsFixed(2))
      ..cellStyle = hs;

    final bytes = excel.save();
    if (bytes != null) {
      await saveFileBytes('expense_report_${DateTime.now().millisecondsSinceEpoch}.xlsx', bytes);
      _snack('✅ Excel exported!', Colors.green);
    }
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(m, style: const TextStyle(fontWeight: FontWeight.w600)),
    backgroundColor: c, behavior: SnackBarBehavior.floating,
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
        title: Text('Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.titleSz(context))),
        actions: [
          IconButton(icon: const Icon(Icons.file_download), tooltip: 'Export Excel', onPressed: _exportExcel),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B1FA2)))
          : Responsive.centered(
              context: context,
              child: RefreshIndicator(
                color: const Color(0xFF7B1FA2),
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(Responsive.pad(context)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildSummaryCard(context),
                    SizedBox(height: Responsive.pad(context)),
                    _buildDateChips(context),
                    const SizedBox(height: 12),
                    _buildReportTypeChips(context),
                    SizedBox(height: Responsive.pad(context)),
                    _buildChartCard(context),
                    SizedBox(height: Responsive.pad(context)),
                    _buildBreakdownCard(context),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ),
    );
  }

  // ════════════ SUMMARY CARD ════════════
  Widget _buildSummaryCard(BuildContext context) {
    final total = _filtered.fold<double>(0, (s, e) => s + e.amount);
    final count = _filtered.length;
    final avg = count > 0 ? total / count : 0.0;
    return Container(
      padding: EdgeInsets.all(Responsive.isPhone(context) ? 18 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0), Color(0xFFAB47BC)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Responsive.cardR(context) + 4),
        boxShadow: [BoxShadow(color: const Color(0xFF7B1FA2).withValues(alpha: 0.3),
          blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.analytics, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(_dateRange.toUpperCase(),
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 14),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text('${AppSettings.currencySymbol}${total.toStringAsFixed(2)}',
            style: TextStyle(color: Colors.white,
              fontSize: Responsive.isPhone(context) ? 28 : 36,
              fontWeight: FontWeight.bold))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _summaryStat('Transactions', '$count', Icons.receipt_long)),
          Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.3)),
          Expanded(child: _summaryStat('Average', '${AppSettings.currencySymbol}${avg.toStringAsFixed(2)}', Icons.trending_up)),
        ]),
      ]),
    );
  }

  Widget _summaryStat(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 14),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
      ]),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
    ]),
  );

  // ════════════ DATE CHIPS ════════════
  Widget _buildDateChips(BuildContext context) => SizedBox(
    height: 40,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _dateRanges.length,
      separatorBuilder: (_, __) => const SizedBox(width: 6),
      itemBuilder: (_, i) {
        final d = _dateRanges[i];
        final selected = _dateRange == d;
        return FilterChip(
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            if (d == 'Custom') Icon(Icons.date_range, size: 14, color: selected ? Colors.white : Colors.teal.shade700),
            if (d == 'Custom') const SizedBox(width: 4),
            Text(d, style: TextStyle(fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Colors.white : Colors.teal.shade700)),
          ]),
          selected: selected,
          backgroundColor: Colors.white,
          selectedColor: Colors.teal.shade600,
          showCheckmark: false,
          side: BorderSide(color: selected ? Colors.teal.shade600 : Colors.grey.shade300),
          onSelected: (_) {
            if (d == 'Custom') { _pickCustomRange(); }
            else { setState(() => _dateRange = d); _applyDateFilter(); }
          },
        );
      },
    ),
  );

  // ════════════ REPORT TYPE CHIPS ════════════
  Widget _buildReportTypeChips(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Icon(Icons.tune, color: Color(0xFF7B1FA2), size: 16),
      const SizedBox(width: 6),
      Text('Group By', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
    ]),
    const SizedBox(height: 6),
    SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _reportTypes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final r = _reportTypes[i];
          final selected = _reportType == r;
          return FilterChip(
            label: Text(r, style: TextStyle(fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Colors.white : const Color(0xFF7B1FA2))),
            selected: selected,
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFF7B1FA2),
            showCheckmark: false,
            side: BorderSide(color: selected ? const Color(0xFF7B1FA2) : Colors.grey.shade300),
            onSelected: (_) => setState(() => _reportType = r),
          );
        },
      ),
    ),
  ]);

  // ════════════ CHART CARD (Pie) ════════════
  Widget _buildChartCard(BuildContext context) {
    final grouped = _grouped();
    if (grouped.isEmpty) return const SizedBox.shrink();

    final colors = [
      const Color(0xFF7B1FA2), Colors.blue.shade500, Colors.teal.shade500,
      Colors.orange.shade500, Colors.pink.shade400, Colors.green.shade500,
      Colors.indigo.shade400, Colors.amber.shade600, Colors.cyan.shade500,
      Colors.deepPurple.shade400,
    ];

    final total = grouped.values.fold<double>(0, (s, v) => s + v);
    final top = grouped.entries.take(10).toList();

    return Container(
      padding: EdgeInsets.all(Responsive.pad(context)),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Responsive.cardR(context)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.pie_chart, color: Color(0xFF7B1FA2), size: 18),
          const SizedBox(width: 6),
          Text('Distribution', style: TextStyle(fontSize: Responsive.titleSz(context) - 2,
            fontWeight: FontWeight.bold, color: const Color(0xFF424242))),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: Responsive.isPhone(context) ? 200 : 260,
          child: Row(children: [
            Expanded(flex: 2, child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: Responsive.isPhone(context) ? 50 : 70,
                sections: top.asMap().entries.map((e) {
                  final idx = e.key; final entry = e.value;
                  final pct = total > 0 ? (entry.value / total * 100) : 0.0;
                  return PieChartSectionData(
                    value: entry.value,
                    color: colors[idx % colors.length],
                    title: pct > 5 ? '${pct.toStringAsFixed(0)}%' : '',
                    radius: 50,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  );
                }).toList(),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: top.asMap().entries.take(5).map((e) {
                final idx = e.key; final entry = e.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Container(width: 10, height: 10,
                      decoration: BoxDecoration(color: colors[idx % colors.length],
                        borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Expanded(child: Text(entry.key,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis)),
                  ]),
                );
              }).toList(),
            )),
          ]),
        ),
      ]),
    );
  }

  // ════════════ BREAKDOWN CARD ════════════
  Widget _buildBreakdownCard(BuildContext context) {
    final grouped = _grouped();
    if (grouped.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Responsive.cardR(context))),
        child: Column(children: [
          Icon(Icons.bar_chart, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No approved expenses in this period',
            style: TextStyle(color: Colors.grey.shade500)),
        ]),
      );
    }
    final total = grouped.values.fold<double>(0, (s, v) => s + v);
    final colors = [
      const Color(0xFF7B1FA2), Colors.blue.shade500, Colors.teal.shade500,
      Colors.orange.shade500, Colors.pink.shade400, Colors.green.shade500,
      Colors.indigo.shade400, Colors.amber.shade600,
    ];

    return Container(
      padding: EdgeInsets.all(Responsive.pad(context)),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Responsive.cardR(context)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.list_alt, color: Color(0xFF7B1FA2), size: 18),
          const SizedBox(width: 6),
          Text('Detailed Breakdown', style: TextStyle(fontSize: Responsive.titleSz(context) - 2,
            fontWeight: FontWeight.bold, color: const Color(0xFF424242))),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF7B1FA2).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
            child: Text('${grouped.length}',
              style: const TextStyle(color: Color(0xFF7B1FA2), fontSize: 11, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 12),
        ...grouped.entries.toList().asMap().entries.map((e) {
          final idx = e.key;
          final entry = e.value.key;
          final amount = e.value.value;
          final pct = total > 0 ? (amount / total * 100) : 0.0;
          final color = colors[idx % colors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 28, height: 28,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text('${idx + 1}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(entry, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('${pct.toStringAsFixed(1)}% of total',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                ])),
                Text('${AppSettings.currencySymbol}${amount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct / 100, minHeight: 6,
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}
