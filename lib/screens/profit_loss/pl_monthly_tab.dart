// lib/screens/profit_loss/pl_monthly_tab.dart
// Monthly Table Tab — 12-month annual P&L view

import 'package:flutter/material.dart';
import '../../models/profit_loss_model.dart';

class PLMonthlyTab extends StatelessWidget {
  final AnnualPLReport? report;
  final bool isLoading;
  final int selectedYear;
  final String selectedBranch;
  final Function(int) onYearChange;
  final Function(String) onBranchChange;
  final Function(MonthlyPLData) onMonthTap;
  final String currencySymbol;

  const PLMonthlyTab({
    super.key,
    required this.report,
    required this.isLoading,
    required this.selectedYear,
    required this.selectedBranch,
    required this.onYearChange,
    required this.onBranchChange,
    required this.onMonthTap,
    required this.currencySymbol,
  });

  String _fmt(double v) {
    if (v == 0) return '${currencySymbol}0';
    if (v.abs() >= 1000000) return '$currencySymbol${(v / 1000000).toStringAsFixed(1)}M';
    if (v.abs() >= 1000) return '$currencySymbol${(v / 1000).toStringAsFixed(1)}k';
    return '$currencySymbol${v.toStringAsFixed(0)}';
  }

  String _fmtFull(double v) => '$currencySymbol${v.toStringAsFixed(2)}';
  String _pct(double v) => '${v.toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (report == null) return _emptyState(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _yearSelector(context),
        const SizedBox(height: 16),
        _monthlyTable(context),
        const SizedBox(height: 16),
        _visualChart(context),
        const SizedBox(height: 16),
        _annualMetrics(context),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _yearSelector(BuildContext context) {
    final currentYear = DateTime.now().year;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.calendar_today, color: Color(0xFF7B1FA2), size: 20),
          const SizedBox(width: 8),
          const Text('Year:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onYearChange(selectedYear - 1),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            padding: EdgeInsets.zero,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7B1FA2).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$selectedYear',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7B1FA2))),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: selectedYear < currentYear ? () => onYearChange(selectedYear + 1) : null,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            padding: EdgeInsets.zero,
          ),
          const Spacer(),
          if (selectedYear != currentYear)
            TextButton.icon(
              icon: const Icon(Icons.today, size: 16),
              label: const Text('This Year'),
              onPressed: () => onYearChange(currentYear),
            ),
        ]),
      ),
    );
  }

  Widget _monthlyTable(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.table_chart, color: Color(0xFF7B1FA2), size: 20),
            const SizedBox(width: 6),
            Text('Monthly P&L Table — ${report!.year}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Text('Tap row to view detail',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
          ]),
          const Divider(height: 16),
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(children: const [
              Expanded(flex: 2, child: Text('Month', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 3, child: Text('Revenue', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 3, child: Text('COGS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 3, child: Text('Shrinkage', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 3, child: Text('Expenses', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 3, child: Text('Net Profit', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              SizedBox(width: 24),
            ]),
          ),
          // Month rows
          ...report!.months.map((m) => _monthRow(context, m)),
          const Divider(height: 16),
          // Totals row
          _totalsRow(context),
          // Averages row
          _averagesRow(context),
        ]),
      ),
    );
  }

  Widget _monthRow(BuildContext context, MonthlyPLData m) {
    final isBest = report!.bestMonth?.month == m.month && m.netProfit > 0;
    final color = m.isProfit ? Colors.green : Colors.red;
    final hasData = m.revenue > 0 || m.expenses > 0;
    return InkWell(
      onTap: hasData ? () => onMonthTap(m) : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isBest ? Colors.green.withValues(alpha: 0.08) : null,
          border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        ),
        child: Row(children: [
          Expanded(flex: 2, child: Row(children: [
            if (isBest) const Text('🏆 ', style: TextStyle(fontSize: 12)),
            Text(m.monthName,
              style: TextStyle(fontSize: 12, fontWeight: isBest ? FontWeight.bold : FontWeight.w500)),
          ])),
          Expanded(flex: 3, child: Text(_fmt(m.revenue),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, color: Colors.green))),
          Expanded(flex: 3, child: Text(_fmt(m.cogs), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.orange.shade700))),
          Expanded(flex: 3, child: Text(_fmt(m.shrinkage), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.red.shade700))),
          Expanded(flex: 3, child: Text(_fmt(m.expenses),
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, color: Colors.purple.shade700))),
          Expanded(flex: 3, child: Text(_fmt(m.netProfit),
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))),
          SizedBox(
            width: 24,
            child: hasData
              ? Icon(m.isProfit ? Icons.check_circle : Icons.cancel, size: 14, color: color)
              : Icon(Icons.remove, size: 14, color: Colors.grey.shade400),
          ),
        ]),
      ),
    );
  }

  Widget _totalsRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF7B1FA2).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        const Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        Expanded(flex: 3, child: Text(_fmt(report!.totalRevenue),
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green))),
        Expanded(flex: 3, child: Text(_fmt(report!.totalCogs),
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade700))),
        Expanded(flex: 3, child: Text(_fmt(report!.totalShrinkage),
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade700))),
        Expanded(flex: 3, child: Text(_fmt(report!.totalExpenses),
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade700))),
        Expanded(flex: 3, child: Text(_fmt(report!.totalNetProfit),
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
            color: report!.totalNetProfit >= 0 ? Colors.green : Colors.red))),
        const SizedBox(width: 24),
      ]),
    );
  }

  Widget _averagesRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Row(children: [
        Expanded(flex: 2, child: Text('AVG/Month',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade700, fontStyle: FontStyle.italic))),
        Expanded(flex: 3, child: Text(_fmt(report!.avgRevenue),
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic))),
        Expanded(flex: 3, child: Text(_fmt(report!.totalCogs / 12),
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic))),
        Expanded(flex: 3, child: Text(_fmt(report!.totalShrinkage / 12),
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic))),
        Expanded(flex: 3, child: Text(_fmt(report!.totalExpenses / 12),
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic))),
        Expanded(flex: 3, child: Text(_fmt(report!.avgNetProfit),
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic))),
        const SizedBox(width: 24),
      ]),
    );
  }

  Widget _visualChart(BuildContext context) {
    final maxProfit = report!.months
        .map((m) => m.netProfit.abs())
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (maxProfit == 0) return const SizedBox.shrink();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.show_chart, color: Color(0xFF7B1FA2), size: 20),
            SizedBox(width: 6),
            Text('Visual Trend — Net Profit',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          ...report!.months.map((m) {
            final pct = maxProfit > 0 ? (m.netProfit.abs() / maxProfit) : 0.0;
            final color = m.isProfit ? Colors.green : Colors.red;
            final isBest = report!.bestMonth?.month == m.month && m.netProfit > 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(
                  width: 36,
                  child: Text(m.monthName,
                    style: TextStyle(fontSize: 11, fontWeight: isBest ? FontWeight.bold : FontWeight.normal)),
                ),
                Expanded(
                  child: Stack(children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: pct.clamp(0.0, 1.0),
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [color.shade400, color.shade700]),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: Text(_fmt(m.netProfit),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, fontWeight: isBest ? FontWeight.bold : FontWeight.w500, color: color)),
                ),
                if (isBest) const Text(' 🏆', style: TextStyle(fontSize: 12)),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _annualMetrics(BuildContext context) {
    final best = report!.bestMonth;
    final worst = report!.worstMonth;
    final isProfit = report!.totalNetProfit >= 0;
    final color = isProfit ? Colors.green : Colors.red;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.insights, color: Color(0xFF7B1FA2), size: 20),
            const SizedBox(width: 6),
            Text('${report!.year} Annual Summary',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const Divider(height: 16),
          _annualRow('Total Revenue', _fmtFull(report!.totalRevenue), Colors.green),
          _annualRow('Total COGS', _fmtFull(report!.totalCogs), Colors.orange.shade700),
          _annualRow('Total Shrinkage', _fmtFull(report!.totalShrinkage), Colors.red),
          _annualRow('Total Operating Exp', _fmtFull(report!.totalExpenses), Colors.purple),
          const Divider(),
          _annualRow('Total Net Profit', _fmtFull(report!.totalNetProfit), color, bold: true),
          _annualRow('Net Margin', _pct(report!.netMargin), color, bold: true),
          const SizedBox(height: 12),
          if (best != null && best.netProfit > 0) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Text('🏆 ', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Best Month', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('${best.monthName} ${report!.year}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ]),
                ),
                Text(_fmtFull(best.netProfit),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
              ]),
            ),
            const SizedBox(height: 6),
          ],
          if (worst != null && worst.netProfit < (best?.netProfit ?? 0)) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Text('📉 ', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Slowest Month', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('${worst.monthName} ${report!.year}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ]),
                ),
                Text(_fmtFull(worst.netProfit),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _annualRow(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label,
          style: TextStyle(fontSize: bold ? 13 : 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
        Text(value,
          style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: color)),
      ]),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.calendar_view_month, size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        const Text('Loading annual data...', style: TextStyle(fontSize: 16)),
      ]),
    );
  }
}
