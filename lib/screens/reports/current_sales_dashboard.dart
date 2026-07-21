// lib/screens/reports/current_sales_dashboard.dart
// v164b Phase 1 - Current Sales Dashboard with LY Same Day comparison
// Retail calendar comparison (MMS/SAP style)

import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/transaction_model.dart' as txn_model;

/// v164b: Retail Calendar utility (MMS-style)
class RetailCalendar {
  /// Last Year Same Weekday - weekday-aligned (Watsons/SM standard)
  /// Example: Today Monday Jul 21, 2026 -> Returns Monday Jul 22, 2025
  static DateTime lySameDay(DateTime today) {
    var candidate = today.subtract(const Duration(days: 364));
    while (candidate.weekday != today.weekday) {
      candidate = candidate.subtract(const Duration(days: 1));
    }
    return candidate;
  }

  /// Yesterday
  static DateTime yesterday(DateTime today) {
    return today.subtract(const Duration(days: 1));
  }

  /// Get start of day
  static DateTime startOfDay(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Get end of day
  static DateTime endOfDay(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day, 23, 59, 59);
  }

  /// Format date short (e.g. "Jul 22, 2025")
  static String formatShort(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '\${months[dt.month - 1]} \${dt.day}, \${dt.year}';
  }

  /// Format weekday name
  static String weekdayName(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }
}

/// v164b Phase 1: Current Sales Dashboard
class CurrentSalesDashboard extends StatefulWidget {
  final String branch;
  const CurrentSalesDashboard({super.key, required this.branch});

  @override
  State<CurrentSalesDashboard> createState() => _CurrentSalesDashboardState();
}

class _CurrentSalesDashboardState extends State<CurrentSalesDashboard> {
  // Today's KPIs
  double _netSales = 0.0;
  double _grossSales = 0.0;
  int _transactions = 0;
  int _unitsSold = 0;
  double _atv = 0.0;
  double _ipb = 0.0;
  double _grossMargin = 0.0;
  double _grossMarginPct = 0.0;
  double _discountAmount = 0.0;
  double _discountPct = 0.0;

  // LY Same Day KPIs (for comparison)
  double _lyNetSales = 0.0;
  double _lyGrossSales = 0.0;
  int _lyTransactions = 0;
  int _lyUnitsSold = 0;
  double _lyAtv = 0.0;
  double _lyIpb = 0.0;
  double _lyGrossMargin = 0.0;
  double _lyDiscountAmount = 0.0;

  DateTime _lyCompareDate = DateTime.now().subtract(const Duration(days: 364));

  bool _loading = true;
  bool _refreshing = false;
  DateTime _lastUpdated = DateTime.now();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadStats();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final txns = await txn_model.Transaction.branchScopedTransactions;
      final now = DateTime.now();
      final today = RetailCalendar.startOfDay(now);
      final todayEnd = RetailCalendar.endOfDay(now);

      // LY Same Day (weekday-aligned)
      final lyDay = RetailCalendar.lySameDay(now);
      final lyStart = RetailCalendar.startOfDay(lyDay);
      final lyEnd = RetailCalendar.endOfDay(lyDay);

      // Today's Transactions (completed only)
      final todayTxns = txns.where((t) =>
        t.dateTime.isAfter(today) &&
        t.dateTime.isBefore(todayEnd) &&
        t.status == 'completed'
      ).toList();

      // LY Same Day Transactions
      final lyTxns = txns.where((t) =>
        t.dateTime.isAfter(lyStart) &&
        t.dateTime.isBefore(lyEnd) &&
        t.status == 'completed'
      ).toList();

      // Calculate Today's KPIs
      final grossSales = todayTxns.fold<double>(0.0, (sum, t) => sum + t.subtotal);
      final discountAmount = todayTxns.fold<double>(0.0, (sum, t) => sum + t.totalDiscount);
      final netSales = todayTxns.fold<double>(0.0, (sum, t) => sum + t.total);
      final transactions = todayTxns.length;
      final unitsSold = todayTxns.fold<int>(0, (sum, t) => sum + t.items.fold<int>(0, (s, i) => s + i.qty));
      final atv = transactions > 0 ? netSales / transactions : 0.0;
      final ipb = transactions > 0 ? unitsSold / transactions : 0.0;
      // Simplified margin (assuming 30% for now - would need product cost data)
      final grossMargin = netSales * 0.32;
      final grossMarginPct = netSales > 0 ? (grossMargin / netSales) * 100 : 0.0;
      final discountPct = grossSales > 0 ? (discountAmount / grossSales) * 100 : 0.0;

      // Calculate LY KPIs
      final lyGross = lyTxns.fold<double>(0.0, (sum, t) => sum + t.subtotal);
      final lyDisc = lyTxns.fold<double>(0.0, (sum, t) => sum + t.totalDiscount);
      final lyNet = lyTxns.fold<double>(0.0, (sum, t) => sum + t.total);
      final lyTrans = lyTxns.length;
      final lyUnits = lyTxns.fold<int>(0, (sum, t) => sum + t.items.fold<int>(0, (s, i) => s + i.qty));
      final lyAtv = lyTrans > 0 ? lyNet / lyTrans : 0.0;
      final lyIpb = lyTrans > 0 ? lyUnits / lyTrans : 0.0;
      final lyMargin = lyNet * 0.32;

      if (!mounted) return;
      setState(() {
        _netSales = netSales;
        _grossSales = grossSales;
        _transactions = transactions;
        _unitsSold = unitsSold;
        _atv = atv;
        _ipb = ipb.toDouble();
        _grossMargin = grossMargin;
        _grossMarginPct = grossMarginPct;
        _discountAmount = discountAmount;
        _discountPct = discountPct;

        _lyNetSales = lyNet;
        _lyGrossSales = lyGross;
        _lyTransactions = lyTrans;
        _lyUnitsSold = lyUnits;
        _lyAtv = lyAtv;
        _lyIpb = lyIpb.toDouble();
        _lyGrossMargin = lyMargin;
        _lyDiscountAmount = lyDisc;

        _lyCompareDate = lyDay;
        _lastUpdated = DateTime.now();
        _loading = false;
      });
    } catch (e) {
      debugPrint('[v164b] Load stats error: \$e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _refreshing = true);
    await _loadStats();
    if (mounted) setState(() => _refreshing = false);
  }

  double _growthPct(double current, double previous) {
    if (previous == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100;
  }

  String _fmtCurrency(double v) {
    if (v == 0) return '0.00';
    final str = v.toStringAsFixed(2);
    final parts = str.split('.');
    var whole = parts[0];
    final decimal = parts.length > 1 ? '.\${parts[1]}' : '';
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return '\${buffer.toString()}\$decimal';
  }

  String _fmtCount(int n) {
    if (n == 0) return '0';
    final str = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String _fmtTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '\$hour:\$min \$ampm';
  }

  String _fmtFullDate(DateTime dt) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '\${days[dt.weekday - 1]}, \${months[dt.month - 1]} \${dt.day}, \${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Sales',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Today, \${_fmtFullDate(now)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            tooltip: 'Change Date',
            onPressed: () {},
          ),
          IconButton(
            icon: AnimatedRotation(
              turns: _refreshing ? 1 : 0,
              duration: const Duration(milliseconds: 600),
              child: const Icon(Icons.refresh_rounded),
            ),
            tooltip: 'Refresh',
            onPressed: _handleRefresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: const Color(0xFF00796B),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00796B)))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Row 1: 4 KPI Cards
                    Row(
                      children: [
                        Expanded(child: _buildKpiCard(
                          icon: Icons.currency_exchange_rounded,
                          iconBg: const Color(0xFF22C55E),
                          label: 'NET SALES',
                          value: _fmtCurrency(_netSales),
                          growth: _growthPct(_netSales, _lyNetSales),
                          comparison: 'vs LY \${RetailCalendar.weekdayName(_lyCompareDate)}',
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _buildKpiCard(
                          icon: Icons.shopping_bag_rounded,
                          iconBg: const Color(0xFF3B82F6),
                          label: 'GROSS SALES',
                          value: _fmtCurrency(_grossSales),
                          growth: _growthPct(_grossSales, _lyGrossSales),
                          comparison: 'vs LY \${RetailCalendar.weekdayName(_lyCompareDate)}',
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _buildKpiCard(
                          icon: Icons.receipt_long_rounded,
                          iconBg: const Color(0xFF8B5CF6),
                          label: 'TRANSACTIONS',
                          value: _fmtCount(_transactions),
                          growth: _growthPct(_transactions.toDouble(), _lyTransactions.toDouble()),
                          comparison: 'vs LY \${RetailCalendar.weekdayName(_lyCompareDate)}',
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _buildKpiCard(
                          icon: Icons.inventory_2_rounded,
                          iconBg: const Color(0xFFF97316),
                          label: 'UNITS SOLD',
                          value: _fmtCount(_unitsSold),
                          growth: _growthPct(_unitsSold.toDouble(), _lyUnitsSold.toDouble()),
                          comparison: 'vs LY \${RetailCalendar.weekdayName(_lyCompareDate)}',
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Row 2: 4 KPI Cards
                    Row(
                      children: [
                        Expanded(child: _buildKpiCard(
                          icon: Icons.trending_up_rounded,
                          iconBg: const Color(0xFF14B8A6),
                          label: 'ATV',
                          value: _fmtCurrency(_atv),
                          growth: _growthPct(_atv, _lyAtv),
                          comparison: 'vs LY \${RetailCalendar.weekdayName(_lyCompareDate)}',
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _buildKpiCard(
                          icon: Icons.shopping_cart_rounded,
                          iconBg: const Color(0xFFEC4899),
                          label: 'IPB',
                          value: _ipb.toStringAsFixed(2),
                          growth: _growthPct(_ipb, _lyIpb),
                          comparison: 'vs LY \${RetailCalendar.weekdayName(_lyCompareDate)}',
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _buildKpiCard(
                          icon: Icons.pie_chart_rounded,
                          iconBg: const Color(0xFFF59E0B),
                          label: 'GROSS MARGIN',
                          value: _fmtCurrency(_grossMargin),
                          growth: _growthPct(_grossMargin, _lyGrossMargin),
                          comparison: 'Margin \${_grossMarginPct.toStringAsFixed(2)}%',
                          isSubtitle: true,
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _buildKpiCard(
                          icon: Icons.percent_rounded,
                          iconBg: const Color(0xFF6366F1),
                          label: 'DISCOUNT',
                          value: _fmtCurrency(_discountAmount),
                          growth: _discountPct,
                          comparison: 'of Gross Sales',
                          isSubtitle: true,
                          showAsPercent: true,
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00796B).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF00796B), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'LY Same Day Comparison',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                                ),
                                Text(
                                  'Today (\${RetailCalendar.weekdayName(now)}) vs LY \${RetailCalendar.weekdayName(_lyCompareDate)} (\${RetailCalendar.formatShort(_lyCompareDate)})',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF00695C)),
                                ),
                                Text(
                                  'Last updated: \${_fmtTime(_lastUpdated)}',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Coming Soon Placeholder
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.hourglass_top_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'More Sections Coming in Phase 2',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Performance Comparison • Financial Summary • Payment Summary • Transaction Summary • Sales by Hour • Top Selling Items • Recent Transactions',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required Color iconBg,
    required String label,
    required String value,
    required double growth,
    required String comparison,
    bool isSubtitle = false,
    bool showAsPercent = false,
  }) {
    final isPositive = growth >= 0;
    final growthColor = isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          if (isSubtitle)
            Column(
              children: [
                Text(
                  showAsPercent ? '\${growth.toStringAsFixed(2)}%' : '\${growth.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: growthColor,
                  ),
                ),
                Text(
                  comparison,
                  style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          else
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 10,
                      color: growthColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '\${growth.abs().toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: growthColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  comparison,
                  style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
