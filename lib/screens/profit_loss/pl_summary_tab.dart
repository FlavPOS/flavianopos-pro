// lib/screens/profit_loss/pl_summary_tab.dart
// Summary Tab — Detailed period-based P&L breakdown

import 'package:flutter/material.dart';
import '../../models/profit_loss_model.dart';

class PLSummaryTab extends StatelessWidget {
  final PLReport? report;
  final bool isLoading;
  final String periodLabel;
  final String selectedBranch;
  final Function(String) onPeriodSelect;
  final VoidCallback onCustomRange;
  final Function(String) onBranchChange;
  final String currencySymbol;

  const PLSummaryTab({
    super.key,
    required this.report,
    required this.isLoading,
    required this.periodLabel,
    required this.selectedBranch,
    required this.onPeriodSelect,
    required this.onCustomRange,
    required this.onBranchChange,
    required this.currencySymbol,
  });

  String _fmt(double v) => '$currencySymbol${v.toStringAsFixed(2)}';
  String _pct(double v) => '${v.toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (report == null || !report!.hasData) return _emptyState(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _periodFilter(context),
        const SizedBox(height: 16),
        _salesCard(context),
        const SizedBox(height: 12),
        _cogsCard(context),
        const SizedBox(height: 12),
        _grossProfitCard(context),
        const SizedBox(height: 12),
        if (report!.shrinkageByReason.isNotEmpty) ...[
          _shrinkageCard(context),
          const SizedBox(height: 12),
        ],
        if (report!.expensesByCategory.isNotEmpty) ...[
          _expensesCard(context),
          const SizedBox(height: 12),
        ],
        _netProfitCard(context),
        const SizedBox(height: 12),
        _metricsCard(context),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _periodFilter(BuildContext context) {
    final periods = ['Today', 'This Week', 'This Month', 'Last Month', 'This Year'];
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.date_range, size: 18, color: Color(0xFF7B1FA2)),
            const SizedBox(width: 6),
            Text('Period: $periodLabel',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.calendar_month, size: 16),
              label: const Text('Custom'),
              onPressed: onCustomRange,
            ),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: periods.map((p) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(p, style: const TextStyle(fontSize: 12)),
                selected: periodLabel == p,
                selectedColor: const Color(0xFF7B1FA2).withValues(alpha: 0.2),
                onSelected: (_) => onPeriodSelect(p),
              ),
            )).toList()),
          ),
        ]),
      ),
    );
  }

  Widget _salesCard(BuildContext context) {
    return _sectionCard(
      title: '💰 SALES SUMMARY',
      color: Colors.green,
      child: Column(children: [
        _row('Gross Sales', _fmt(report!.grossSales), bold: true),
        _row('Less: Discounts', '(${_fmt(report!.totalDiscounts)})', textColor: Colors.orange.shade700),
        _row('Less: Refunds', '(${_fmt(report!.totalRefunds)})', textColor: Colors.red.shade700),
        _row('Less: Voided', '(${_fmt(report!.totalVoided)})', textColor: Colors.grey.shade700),
        const Divider(),
        _row('Net Sales (Revenue)', _fmt(report!.netSales), bold: true, fontSize: 16, textColor: Colors.green.shade700),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _miniStat('Transactions', '${report!.transactionCount}')),
          const SizedBox(width: 8),
          Expanded(child: _miniStat('Avg Sale', _fmt(report!.averageSale))),
        ]),
      ]),
    );
  }

  Widget _cogsCard(BuildContext context) {
    final cogsPct = report!.netSales > 0 ? (report!.cogs / report!.netSales) * 100 : 0;
    return _sectionCard(
      title: '�� COST OF GOODS SOLD',
      color: Colors.orange,
      child: Column(children: [
        _row('COGS', _fmt(report!.cogs), bold: true),
        _row('COGS % of Sales', _pct(cogsPct.toDouble())),
      ]),
    );
  }

  Widget _grossProfitCard(BuildContext context) {
    final color = report!.grossMargin >= 40 ? Colors.green : Colors.orange;
    return _sectionCard(
      title: '🎯 GROSS PROFIT',
      color: Colors.blue,
      child: Column(children: [
        _row('Net Sales', _fmt(report!.netSales)),
        _row('- COGS', _fmt(report!.cogs)),
        const Divider(),
        _row('Gross Profit', _fmt(report!.grossProfit), bold: true, fontSize: 16, textColor: color),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Margin: ${_pct(report!.grossMargin)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _shrinkageCard(BuildContext context) {
    final sorted = report!.shrinkageByReason.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _sectionCard(
      title: '⚠️ SHRINKAGE BREAKDOWN by REASON',
      color: Colors.red,
      subtitle: '${_fmt(report!.totalShrinkage)} (${_pct(report!.shrinkageRate)} of Revenue)',
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: const [
            Expanded(flex: 4, child: Text('Reason', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            Expanded(flex: 3, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: Text('% Shrink', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: Text('% Rev', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          ]),
        ),
        ...sorted.map((e) {
          final pctShrink = report!.totalShrinkage > 0 ? (e.value / report!.totalShrinkage) * 100 : 0;
          final pctRev = report!.netSales > 0 ? (e.value / report!.netSales) * 100 : 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Row(children: [
              Expanded(flex: 4, child: Text('${_iconForReason(e.key)} ${e.key}', style: const TextStyle(fontSize: 12))),
              Expanded(flex: 3, child: Text(_fmt(e.value), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
              Expanded(flex: 2, child: Text(_pct(pctShrink.toDouble()), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
              Expanded(flex: 2, child: Text(_pct(pctRev.toDouble()), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.red.shade600))),
            ]),
          );
        }),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(children: [
            const Expanded(flex: 4, child: Text('TOTAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            Expanded(flex: 3, child: Text(_fmt(report!.totalShrinkage), textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade700))),
            const Expanded(flex: 2, child: Text('100.0%', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: Text(_pct(report!.shrinkageRate), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700))),
          ]),
        ),
      ]),
    );
  }

  Widget _expensesCard(BuildContext context) {
    return _sectionCard(
      title: '💸 OPERATING EXPENSES by CATEGORY',
      color: Colors.purple,
      subtitle: '${_fmt(report!.totalOperatingExpenses)} (${_pct(report!.operatingExpenseRate)} of Revenue)',
      child: Column(children: [
        ...report!.expensesByCategory.entries.map((catEntry) {
          final catTotal = catEntry.value.values.fold<double>(0, (a, b) => a + b);
          final catPctExp = report!.totalOperatingExpenses > 0 ? (catTotal / report!.totalOperatingExpenses) * 100 : 0;
          final catPctRev = report!.netSales > 0 ? (catTotal / report!.netSales) * 100 : 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B1FA2).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  Expanded(flex: 4, child: Text('▼ ${catEntry.key}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  Expanded(flex: 3, child: Text(_fmt(catTotal), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text(_pct(catPctExp.toDouble()), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text(_pct(catPctRev.toDouble()), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.purple.shade700, fontWeight: FontWeight.bold))),
                ]),
              ),
              ...catEntry.value.entries.map((subEntry) {
                final subPctExp = report!.totalOperatingExpenses > 0 ? (subEntry.value / report!.totalOperatingExpenses) * 100 : 0;
                final subPctRev = report!.netSales > 0 ? (subEntry.value / report!.netSales) * 100 : 0;
                return Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                  child: Row(children: [
                    Expanded(flex: 4, child: Text('└─ ${subEntry.key}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700))),
                    Expanded(flex: 3, child: Text(_fmt(subEntry.value), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
                    Expanded(flex: 2, child: Text(_pct(subPctExp.toDouble()), textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: Colors.grey.shade600))),
                    Expanded(flex: 2, child: Text(_pct(subPctRev.toDouble()), textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: Colors.grey.shade600))),
                  ]),
                );
              }),
            ]),
          );
        }),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(children: [
            const Expanded(flex: 4, child: Text('TOTAL EXPENSES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            Expanded(flex: 3, child: Text(_fmt(report!.totalOperatingExpenses), textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple.shade700))),
            const Expanded(flex: 2, child: Text('100.0%', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: Text(_pct(report!.operatingExpenseRate), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade700))),
          ]),
        ),
      ]),
    );
  }

  Widget _netProfitCard(BuildContext context) {
    final color = report!.isProfit ? Colors.green : Colors.red;
    final icon = report!.isProfit ? '💎' : '🔴';
    final status = report!.isProfit ? 'Profitable' : 'Loss';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.shade700, color.shade400]),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 8),
          const Expanded(child: Text('NET PROFIT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2))),
        ]),
        const SizedBox(height: 8),
        Text(_fmt(report!.netProfit),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Margin: ${_pct(report!.netMargin)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Text(status,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 8),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.3)),
        const SizedBox(height: 8),
        _profitFormula('Gross Profit', _fmt(report!.grossProfit)),
        _profitFormula('- Shrinkage', '(${_fmt(report!.totalShrinkage)})'),
        _profitFormula('- Operating Exp', '(${_fmt(report!.totalOperatingExpenses)})'),
      ]),
    );
  }

  Widget _metricsCard(BuildContext context) {
    final metrics = [
      _MetricRow('Gross Margin', report!.grossMargin, 40, 50, true),
      _MetricRow('Net Margin', report!.netMargin, 5, 15, true),
      _MetricRow('Shrinkage Rate', report!.shrinkageRate, 1.5, 2.5, false),
      _MetricRow('OpEx Ratio', report!.operatingExpenseRate, 15, 25, false),
    ];
    return _sectionCard(
      title: '📊 KEY METRICS vs INDUSTRY',
      color: Colors.indigo,
      child: Column(children: metrics.map((m) {
        final isGood = m.higherIsBetter ? m.value >= m.lowBenchmark : m.value <= m.highBenchmark;
        final color = isGood ? Colors.green : (m.value < m.lowBenchmark || m.value > m.highBenchmark * 1.5 ? Colors.red : Colors.orange);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(flex: 3, child: Text(m.label, style: const TextStyle(fontSize: 12))),
            Expanded(flex: 2, child: Text(_pct(m.value), textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color))),
            Expanded(flex: 3, child: Text('Industry: ${m.lowBenchmark.toStringAsFixed(1)}-${m.highBenchmark.toStringAsFixed(1)}%',
              textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: Colors.grey.shade600))),
            const SizedBox(width: 4),
            Icon(isGood ? Icons.check_circle : Icons.warning, size: 16, color: color),
          ]),
        );
      }).toList()),
    );
  }

  Widget _sectionCard({required String title, required Color color, String? subtitle, required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color, letterSpacing: 0.5)),
          if (subtitle != null) Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ),
          const Divider(height: 16),
          child,
        ]),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, double fontSize = 13, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: textColor))),
        Text(value, style: TextStyle(fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: textColor)),
      ]),
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _profitFormula(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white))),
        Text(value, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.bar_chart, size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        const Text('No data for this period', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('Try a different date range', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: _periodFilter(context)),
      ]),
    );
  }

  String _iconForReason(String reason) {
    final r = reason.toLowerCase();
    if (r.contains('theft') || r.contains('stolen')) return '🚨';
    if (r.contains('expire')) return '⏰';
    if (r.contains('damage') || r.contains('broken')) return '💥';
    if (r.contains('spoil')) return '📉';
    if (r.contains('lost') || r.contains('missing')) return '❓';
    if (r.contains('variance')) return '📊';
    return '⚠️';
  }
}

class _MetricRow {
  final String label;
  final double value;
  final double lowBenchmark;
  final double highBenchmark;
  final bool higherIsBetter;
  _MetricRow(this.label, this.value, this.lowBenchmark, this.highBenchmark, this.higherIsBetter);
}
