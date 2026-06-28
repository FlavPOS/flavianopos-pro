// lib/services/profit_loss_service.dart
// All P&L calculation logic — pure SQL aggregations

import '../helpers/database_helper.dart';
import '../models/profit_loss_model.dart';

class ProfitLossService {
  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /// Calculate P&L for a date range (optionally filtered by branch)
  static Future<PLReport> calculate({
    required DateTime start,
    required DateTime end,
    String? branch,
  }) async {
    final db = await DatabaseHelper().database;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();
    final branchFilter = (branch != null && branch != 'All Branches') ? branch : '';

    // === SALES ===
    final salesQuery = '''
      SELECT 
        COALESCE(SUM(CASE WHEN (voidedAt IS NULL OR voidedAt = '') THEN subtotal ELSE 0 END), 0) as grossSales,
        COALESCE(SUM(CASE WHEN (voidedAt IS NULL OR voidedAt = '') THEN totalDiscount ELSE 0 END), 0) as totalDiscounts,
        COALESCE(SUM(CASE WHEN refundedAt IS NOT NULL AND refundedAt != '' THEN COALESCE(refundAmount, total) WHEN status = 'refunded' THEN total ELSE 0 END), 0) as totalRefunds,
        COALESCE(SUM(CASE WHEN voidedAt IS NOT NULL AND voidedAt != '' THEN total WHEN status = 'voided' THEN total ELSE 0 END), 0) as totalVoided,
        COALESCE(SUM(CASE WHEN (voidedAt IS NULL OR voidedAt = '') THEN total ELSE 0 END), 0) as netRevenue,
        COUNT(CASE WHEN (voidedAt IS NULL OR voidedAt = '') THEN 1 END) as txnCount
      FROM transactions
      WHERE dateTime BETWEEN ? AND ?
        ${branchFilter.isNotEmpty ? "AND branch = ?" : ""}
    ''';
    final salesArgs = branchFilter.isNotEmpty
        ? [startStr, endStr, branchFilter]
        : [startStr, endStr];
    final salesResult = await db.rawQuery(salesQuery, salesArgs);
    final s = salesResult.first;

    final double grossSales = (s['grossSales'] as num?)?.toDouble() ?? 0;
    final double totalDiscounts = (s['totalDiscounts'] as num?)?.toDouble() ?? 0;
    final double totalRefunds = (s['totalRefunds'] as num?)?.toDouble() ?? 0;
    final double totalVoided = (s['totalVoided'] as num?)?.toDouble() ?? 0;
    final double netRevenue = (s['netRevenue'] as num?)?.toDouble() ?? 0;
    final int txnCount = (s['txnCount'] as num?)?.toInt() ?? 0;
    final double netSales = netRevenue - totalRefunds;
    final double avgSale = txnCount > 0 ? netSales / txnCount : 0;

    // === COGS ===
    final cogsQuery = '''
      SELECT COALESCE(SUM(ti.qty * COALESCE(p.costPrice, 0)), 0) as cogs
      FROM transaction_items ti
      INNER JOIN transactions t ON ti.transactionId = t.id
      LEFT JOIN products p ON ti.sku = p.sku
      WHERE t.dateTime BETWEEN ? AND ?
        AND (t.status = 'completed' OR t.status IS NULL)
        AND (t.voidedAt IS NULL OR t.voidedAt = '')
        ${branchFilter.isNotEmpty ? "AND t.branch = ?" : ""}
    ''';
    final cogsResult = await db.rawQuery(cogsQuery, salesArgs);
    final double cogs = (cogsResult.first['cogs'] as num?)?.toDouble() ?? 0;

    final double grossProfit = netSales - cogs;
    final double grossMargin = netSales > 0 ? (grossProfit / netSales) * 100 : 0;

    // === SHRINKAGE by REASON (Smart NET with Reversal) ===
    // Gross losses (DEDUCTs) MINUS reversals (Wrong Adjustment / Reversal ADDs)
    Map<String, double> shrinkageByReason = {};
    Map<String, double> reversalsByReason = {};
    try {
      final excludeKeywords = ['transfer out', 'correction'];

      // 1. Get all DEDUCT adjustments (gross shrinkage)
      final deductQuery = '''
        SELECT reason, COALESCE(SUM(quantity * cost), 0) as amount
        FROM adjustment_records
        WHERE dateTime BETWEEN ? AND ?
          AND adjustmentType IN ('Deduct', 'deduct', 'OUT', 'out')
        GROUP BY reason
      ''';
      final deductResults = await db.rawQuery(deductQuery, [startStr, endStr]);
      for (final row in deductResults) {
        var reason = (row['reason'] as String?)?.trim() ?? '';
        reason = reason.replaceFirst(RegExp(r'^[-\u2013\u2014]\s*'), '').trim();
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        if (reason.isEmpty || amount <= 0) continue;
        final lower = reason.toLowerCase();
        if (excludeKeywords.any((ex) => lower.contains(ex))) continue;
        shrinkageByReason[reason] = (shrinkageByReason[reason] ?? 0) + amount;
      }

      // 2. Get REVERSAL ADJUSTMENTS (cancels wrong shrinkage)
      final reversalQuery = '''
        SELECT reason, COALESCE(SUM(quantity * cost), 0) as amount
        FROM adjustment_records
        WHERE dateTime BETWEEN ? AND ?
          AND adjustmentType IN ('Add', 'add', 'IN', 'in')
          AND (LOWER(reason) LIKE '%wrong%' OR LOWER(reason) LIKE '%reversal%')
        GROUP BY reason
      ''';
      final reversalResults = await db.rawQuery(reversalQuery, [startStr, endStr]);
      for (final row in reversalResults) {
        var reason = (row['reason'] as String?)?.trim() ?? '';
        reason = reason.replaceFirst(RegExp(r'^[-\u2013\u2014]\s*'), '').trim();
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        if (reason.isEmpty || amount <= 0) continue;
        reversalsByReason[reason] = (reversalsByReason[reason] ?? 0) + amount;
      }

      // 3. Display reversals as negative entries
      for (final entry in reversalsByReason.entries) {
        shrinkageByReason['Reversal: ${entry.key}'] = -entry.value;
      }
    } catch (_) {}

    final double totalShrinkage = shrinkageByReason.values.fold(0, (a, b) => a + b);
    final double shrinkageRate = netSales > 0 ? (totalShrinkage / netSales) * 100 : 0;

    // === EXPENSES by CATEGORY > SUB-CATEGORY ===
    Map<String, Map<String, double>> expensesByCategory = {};
    try {
      final expQuery = '''
        SELECT categoryName, subCategoryName, COALESCE(SUM(amount), 0) as total
        FROM expenses
        WHERE expenseDate BETWEEN ? AND ?
          AND status = 'Approved'
          ${branchFilter.isNotEmpty ? "AND branch = ?" : ""}
        GROUP BY categoryName, subCategoryName
        ORDER BY categoryName, total DESC
      ''';
      final expArgs = branchFilter.isNotEmpty
          ? [start.toIso8601String().split('T').first, end.toIso8601String().split('T').first, branchFilter]
          : [start.toIso8601String().split('T').first, end.toIso8601String().split('T').first];
      final expResults = await db.rawQuery(expQuery, expArgs);
      for (final row in expResults) {
        final cat = (row['categoryName'] as String?)?.trim() ?? 'Uncategorized';
        final subCat = (row['subCategoryName'] as String?)?.trim() ?? 'General';
        final amount = (row['total'] as num?)?.toDouble() ?? 0;
        if (amount <= 0) continue;
        expensesByCategory.putIfAbsent(cat, () => {});
        expensesByCategory[cat]![subCat] = (expensesByCategory[cat]![subCat] ?? 0) + amount;
      }
    } catch (_) {}

    final double totalOpEx = expensesByCategory.values
        .expand((sub) => sub.values)
        .fold(0, (a, b) => a + b);
    final double opExRate = netSales > 0 ? (totalOpEx / netSales) * 100 : 0;

    // === NET PROFIT ===
    final double netProfit = grossProfit - totalShrinkage - totalOpEx;
    final double netMargin = netSales > 0 ? (netProfit / netSales) * 100 : 0;

    return PLReport(
      grossSales: grossSales,
      totalDiscounts: totalDiscounts,
      totalRefunds: totalRefunds,
      totalVoided: totalVoided,
      netSales: netSales,
      transactionCount: txnCount,
      averageSale: avgSale,
      cogs: cogs,
      grossProfit: grossProfit,
      grossMargin: grossMargin,
      shrinkageByReason: shrinkageByReason,
      totalShrinkage: totalShrinkage,
      shrinkageRate: shrinkageRate,
      expensesByCategory: expensesByCategory,
      totalOperatingExpenses: totalOpEx,
      operatingExpenseRate: opExRate,
      netProfit: netProfit,
      netMargin: netMargin,
      periodStart: start,
      periodEnd: end,
      branchFilter: branch ?? 'All Branches',
    );
  }

  /// Calculate 12-month annual P&L
  static Future<AnnualPLReport> calculateAnnual({
    required int year,
    String? branch,
  }) async {
    final List<MonthlyPLData> months = [];
    double totalRevenue = 0, totalCogs = 0, totalShrinkage = 0, totalExpenses = 0, totalNetProfit = 0;

    for (int m = 1; m <= 12; m++) {
      final start = DateTime(year, m, 1);
      final end = DateTime(year, m + 1, 0, 23, 59, 59);
      final report = await calculate(start: start, end: end, branch: branch);

      final monthData = MonthlyPLData(
        month: m,
        monthName: _monthNames[m - 1],
        revenue: report.netSales,
        cogs: report.cogs,
        shrinkage: report.totalShrinkage,
        expenses: report.totalOperatingExpenses,
        netProfit: report.netProfit,
      );
      months.add(monthData);

      totalRevenue += monthData.revenue;
      totalCogs += monthData.cogs;
      totalShrinkage += monthData.shrinkage;
      totalExpenses += monthData.expenses;
      totalNetProfit += monthData.netProfit;
    }

    return AnnualPLReport(
      year: year,
      months: months,
      totalRevenue: totalRevenue,
      totalCogs: totalCogs,
      totalShrinkage: totalShrinkage,
      totalExpenses: totalExpenses,
      totalNetProfit: totalNetProfit,
    );
  }
}
