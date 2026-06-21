// lib/models/profit_loss_model.dart
// P&L data classes for Profit & Loss reporting

class PLReport {
  // Sales
  final double grossSales;
  final double totalDiscounts;
  final double totalRefunds;
  final double totalVoided;
  final double netSales;
  final int transactionCount;
  final double averageSale;

  // COGS & Profit
  final double cogs;
  final double grossProfit;
  final double grossMargin;

  // Shrinkage
  final Map<String, double> shrinkageByReason;
  final double totalShrinkage;
  final double shrinkageRate;

  // Expenses (Category -> SubCategory -> Amount)
  final Map<String, Map<String, double>> expensesByCategory;
  final double totalOperatingExpenses;
  final double operatingExpenseRate;

  // Net Profit
  final double netProfit;
  final double netMargin;

  // Period info
  final DateTime periodStart;
  final DateTime periodEnd;
  final String branchFilter;

  const PLReport({
    required this.grossSales,
    required this.totalDiscounts,
    required this.totalRefunds,
    required this.totalVoided,
    required this.netSales,
    required this.transactionCount,
    required this.averageSale,
    required this.cogs,
    required this.grossProfit,
    required this.grossMargin,
    required this.shrinkageByReason,
    required this.totalShrinkage,
    required this.shrinkageRate,
    required this.expensesByCategory,
    required this.totalOperatingExpenses,
    required this.operatingExpenseRate,
    required this.netProfit,
    required this.netMargin,
    required this.periodStart,
    required this.periodEnd,
    required this.branchFilter,
  });

  factory PLReport.empty(DateTime start, DateTime end, String branch) {
    return PLReport(
      grossSales: 0, totalDiscounts: 0, totalRefunds: 0, totalVoided: 0, netSales: 0,
      transactionCount: 0, averageSale: 0,
      cogs: 0, grossProfit: 0, grossMargin: 0,
      shrinkageByReason: {}, totalShrinkage: 0, shrinkageRate: 0,
      expensesByCategory: {}, totalOperatingExpenses: 0, operatingExpenseRate: 0,
      netProfit: 0, netMargin: 0,
      periodStart: start, periodEnd: end, branchFilter: branch,
    );
  }

  bool get isProfit => netProfit >= 0;
  bool get hasData => grossSales > 0 || totalOperatingExpenses > 0 || totalShrinkage > 0;
}

class MonthlyPLData {
  final int month;
  final String monthName;
  final double revenue;
  final double cogs;
  final double shrinkage;
  final double expenses;
  final double netProfit;

  const MonthlyPLData({
    required this.month,
    required this.monthName,
    required this.revenue,
    required this.cogs,
    required this.shrinkage,
    required this.expenses,
    required this.netProfit,
  });

  double get grossProfit => revenue - cogs;
  double get netMargin => revenue > 0 ? (netProfit / revenue) * 100 : 0;
  bool get isProfit => netProfit >= 0;
}

class AnnualPLReport {
  final int year;
  final List<MonthlyPLData> months;
  final double totalRevenue;
  final double totalCogs;
  final double totalShrinkage;
  final double totalExpenses;
  final double totalNetProfit;

  const AnnualPLReport({
    required this.year,
    required this.months,
    required this.totalRevenue,
    required this.totalCogs,
    required this.totalShrinkage,
    required this.totalExpenses,
    required this.totalNetProfit,
  });

  double get avgRevenue => months.isEmpty ? 0 : totalRevenue / months.length;
  double get avgNetProfit => months.isEmpty ? 0 : totalNetProfit / months.length;
  double get netMargin => totalRevenue > 0 ? (totalNetProfit / totalRevenue) * 100 : 0;

  MonthlyPLData? get bestMonth {
    if (months.isEmpty) return null;
    return months.reduce((a, b) => a.netProfit > b.netProfit ? a : b);
  }

  MonthlyPLData? get worstMonth {
    if (months.isEmpty) return null;
    return months.reduce((a, b) => a.netProfit < b.netProfit ? a : b);
  }

  double get growthRate {
    if (months.length < 2) return 0;
    final first = months.first.netProfit;
    final last = months.last.netProfit;
    if (first == 0) return 0;
    return ((last - first) / first.abs()) * 100;
  }
}
