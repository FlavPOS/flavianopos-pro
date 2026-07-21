// lib/screens/reports/sales_history_hub_screen.dart
// v164a - ERP-style Sales History Hub (14 modules)
// Matches inventory_adjustment_hub.dart design pattern

import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/transaction_model.dart' as txn_model;
import '../../helpers/database_helper.dart';
import 'sales_history_screen.dart';
import 'current_sales_dashboard.dart';

/// v164a: Main Hub for Sales History module.
/// Shows 14 sales analytics and transaction cards.
class SalesHistoryHubScreen extends StatefulWidget {
  final String branch;
  const SalesHistoryHubScreen({super.key, required this.branch});

  @override
  State<SalesHistoryHubScreen> createState() => _SalesHistoryHubScreenState();
}

class _SalesHistoryHubScreenState extends State<SalesHistoryHubScreen> {
  // Dynamic badge values
  double _currentSales = 0.0;
  double _ytdSales = 0.0;
  int _dailyCount = 0;
  int _weeklyCount = 0;
  int _monthlyCount = 0;
  int _totalTxns = 0;
  int _pluCount = 0;
  int _refundCount = 0;
  int _voidCount = 0;
  int _exchangeCount = 0;
  int _cashierCount = 0;
  double _paymentTotal = 0.0;
  int _peakHour = 0;
  double _growthPct = 0.0;

  bool _loading = true;
  bool _refreshing = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadStats();
    // v164a: Auto-refresh every 30s for real-time updates
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
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfYear = DateTime(now.year, 1, 1);
      final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      // Current Sales (Today - Completed only)
      final todayTxns = txns.where((t) =>
        t.dateTime.isAfter(startOfToday) &&
        t.status == 'completed'
      ).toList();
      final currentSales = todayTxns.fold<double>(0.0, (sum, t) => sum + t.total);

      // YTD Sales (Year-to-Date - Completed only)
      final ytdTxns = txns.where((t) =>
        t.dateTime.isAfter(startOfYear) &&
        t.status == 'completed'
      ).toList();
      final ytdSales = ytdTxns.fold<double>(0.0, (sum, t) => sum + t.total);

      // Daily/Weekly/Monthly counts
      final dailyCount = ytdTxns
          .map((t) => DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day))
          .toSet()
          .length;
      final weeklyCount = ((now.difference(startOfYear).inDays) / 7).ceil().clamp(1, 52);
      final monthlyCount = now.month;

      // Total transactions
      final totalTxns = txns.length;

      // PLU count - distinct products sold
      final pluSet = <String>{};
      for (final t in txns) {
        for (final item in t.items) {
          pluSet.add(item.sku);
        }
      }
      final pluCount = pluSet.length;

      // Refund count (status = refunded)
      final refundCount = txns.where((t) => t.status == 'refunded').length;

      // Void count (from void_records table - v161!)
      int voidCount = 0;
      try {
        final rows = await DatabaseHelper().rawQuery(
          "SELECT COUNT(*) as cnt FROM void_records WHERE branchId = ? OR branch = ?",
          [widget.branch, widget.branch],
        );
        voidCount = (rows.first['cnt'] as int?) ?? 0;
      } catch (_) {}

      // Exchange count (v162 - status = exchanged)
      final exchangeCount = txns.where((t) => t.status == 'exchanged').length;

      // Cashier count (distinct)
      final cashierCount = txns.map((t) => t.cashier).where((c) => c.isNotEmpty).toSet().length;

      // Payment total (today)
      final paymentTotal = currentSales;

      // Peak hour (today)
      int peakHour = 0;
      if (todayTxns.isNotEmpty) {
        final hourMap = <int, int>{};
        for (final t in todayTxns) {
          hourMap[t.dateTime.hour] = (hourMap[t.dateTime.hour] ?? 0) + 1;
        }
        peakHour = hourMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }

      // Growth % (this month vs last month - simplified)
      final monthTxns = txns.where((t) =>
        t.dateTime.isAfter(startOfMonth) &&
        t.status == 'completed'
      ).toList();
      final monthSales = monthTxns.fold<double>(0.0, (sum, t) => sum + t.total);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthTxns = txns.where((t) =>
        t.dateTime.isAfter(lastMonthStart) &&
        t.dateTime.isBefore(startOfMonth) &&
        t.status == 'completed'
      ).toList();
      final lastMonthSales = lastMonthTxns.fold<double>(0.0, (sum, t) => sum + t.total);
      final growthPct = lastMonthSales > 0 ? ((monthSales - lastMonthSales) / lastMonthSales * 100) : 0.0;

      if (!mounted) return;
      setState(() {
        _currentSales = currentSales;
        _ytdSales = ytdSales;
        _dailyCount = dailyCount;
        _weeklyCount = weeklyCount;
        _monthlyCount = monthlyCount;
        _totalTxns = totalTxns;
        _pluCount = pluCount;
        _refundCount = refundCount;
        _voidCount = voidCount;
        _exchangeCount = exchangeCount;
        _cashierCount = cashierCount;
        _paymentTotal = paymentTotal;
        _peakHour = peakHour;
        _growthPct = growthPct;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[v164a] Load stats error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _refreshing = true);
    await _loadStats();
    if (mounted) setState(() => _refreshing = false);
  }

  String _fmtCurrency(double v) {
    if (v >= 1000000) return '₱${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '₱${(v / 1000).toStringAsFixed(0)}K';
    return '₱${v.toStringAsFixed(2)}';
  }

  String _fmtCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  void _open(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) => _loadStats());
  }

  void _openComingSoon(String moduleName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$moduleName - Coming in v164b'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF00897B),
      ),
    );
  }

  void _showFilterSheet() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Filters - Coming in v164b'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.bar_chart_rounded, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'SALES HISTORY',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            tooltip: 'Filters',
            onPressed: _showFilterSheet,
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
        color: const Color(0xFF00897B),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Filter Summary
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'Branch: ${widget.branch}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'Today',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),

                    // 1. Current Sales
                    _buildCard(
                      icon: Icons.trending_up_rounded,
                      iconColor: const Color(0xFF22C55E),
                      iconBg: const Color(0xFFDCFCE7),
                      title: 'Current Sales',
                      subtitle: "View today's current sales performance and transaction summary.",
                      badge: _fmtCurrency(_currentSales),
                      badgeColor: const Color(0xFF22C55E),
                      onTap: () => _open(CurrentSalesDashboard(branch: widget.branch)),
                    ),
                    const SizedBox(height: 12),

                    // 2. YTD Sales
                    _buildCard(
                      icon: Icons.calendar_month_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      iconBg: const Color(0xFFDBEAFE),
                      title: 'YTD Sales',
                      subtitle: 'Review Year-to-Date sales, monthly trend and performance.',
                      badge: _fmtCurrency(_ytdSales),
                      badgeColor: const Color(0xFF3B82F6),
                      onTap: () => _openComingSoon('YTD Sales'),
                    ),
                    const SizedBox(height: 12),

                    // 3. Daily Sales
                    _buildCard(
                      icon: Icons.today_rounded,
                      iconColor: const Color(0xFFF97316),
                      iconBg: const Color(0xFFFFEDD5),
                      title: 'Daily Sales',
                      subtitle: 'Browse daily sales history with detailed transactions.',
                      badge: _fmtCount(_dailyCount),
                      badgeColor: const Color(0xFFF97316),
                      onTap: () => _openComingSoon('Daily Sales'),
                    ),
                    const SizedBox(height: 12),

                    // 4. Weekly Sales
                    _buildCard(
                      icon: Icons.bar_chart_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      iconBg: const Color(0xFFEDE9FE),
                      title: 'Weekly Sales',
                      subtitle: 'Analyze weekly sales totals and growth.',
                      badge: _fmtCount(_weeklyCount),
                      badgeColor: const Color(0xFF8B5CF6),
                      onTap: () => _openComingSoon('Weekly Sales'),
                    ),
                    const SizedBox(height: 12),

                    // 5. Monthly Sales
                    _buildCard(
                      icon: Icons.date_range_rounded,
                      iconColor: const Color(0xFF6366F1),
                      iconBg: const Color(0xFFE0E7FF),
                      title: 'Monthly Sales',
                      subtitle: 'Review monthly sales performance and comparisons.',
                      badge: _fmtCount(_monthlyCount),
                      badgeColor: const Color(0xFF6366F1),
                      onTap: () => _openComingSoon('Monthly Sales'),
                    ),
                    const SizedBox(height: 12),

                    // 6. Sales Transactions - NAVIGATES TO EXISTING SCREEN!
                    _buildCard(
                      icon: Icons.receipt_long_rounded,
                      iconColor: const Color(0xFF00897B),
                      iconBg: const Color(0xFFCCFBF1),
                      title: 'Sales Transactions',
                      subtitle: 'Search all sales transactions, receipts, refunds and voids.',
                      badge: _fmtCount(_totalTxns),
                      badgeColor: const Color(0xFF00897B),
                      onTap: () => _open(SalesHistoryScreen(branch: widget.branch)),
                    ),
                    const SizedBox(height: 12),

                    // 7. PLU Sales
                    _buildCard(
                      icon: Icons.sell_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      iconBg: const Color(0xFFFEF3C7),
                      title: 'PLU Sales',
                      subtitle: 'Analyze product sales by SKU, barcode, PLU and quantity sold.',
                      badge: _fmtCount(_pluCount),
                      badgeColor: const Color(0xFFF59E0B),
                      onTap: () => _openComingSoon('PLU Sales'),
                    ),
                    const SizedBox(height: 12),

                    // 8. Refund History
                    _buildCard(
                      icon: Icons.keyboard_return_rounded,
                      iconColor: const Color(0xFFEF4444),
                      iconBg: const Color(0xFFFEE2E2),
                      title: 'Refund History',
                      subtitle: 'View refunded transactions and refund details.',
                      badge: _fmtCount(_refundCount),
                      badgeColor: const Color(0xFFEF4444),
                      onTap: () => _openComingSoon('Refund History'),
                    ),
                    const SizedBox(height: 12),

                    // 9. Void History
                    _buildCard(
                      icon: Icons.block_rounded,
                      iconColor: const Color(0xFF6B7280),
                      iconBg: const Color(0xFFE5E7EB),
                      title: 'Void History',
                      subtitle: 'Review all voided sales transactions.',
                      badge: _fmtCount(_voidCount),
                      badgeColor: const Color(0xFF6B7280),
                      onTap: () => _openComingSoon('Void History'),
                    ),
                    const SizedBox(height: 12),

                    // 10. Exchange History
                    _buildCard(
                      icon: Icons.swap_horiz_rounded,
                      iconColor: const Color(0xFF06B6D4),
                      iconBg: const Color(0xFFCFFAFE),
                      title: 'Exchange History',
                      subtitle: 'View exchanged items and transaction history.',
                      badge: _fmtCount(_exchangeCount),
                      badgeColor: const Color(0xFF06B6D4),
                      onTap: () => _openComingSoon('Exchange History'),
                    ),
                    const SizedBox(height: 12),

                    // 11. Cashier Performance
                    _buildCard(
                      icon: Icons.person_outline_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      iconBg: const Color(0xFFDBEAFE),
                      title: 'Cashier Performance',
                      subtitle: 'Compare sales by cashier and transaction count.',
                      badge: _fmtCount(_cashierCount),
                      badgeColor: const Color(0xFF3B82F6),
                      onTap: () => _openComingSoon('Cashier Performance'),
                    ),
                    const SizedBox(height: 12),

                    // 12. Payment Summary
                    _buildCard(
                      icon: Icons.payments_outlined,
                      iconColor: const Color(0xFF22C55E),
                      iconBg: const Color(0xFFDCFCE7),
                      title: 'Payment Summary',
                      subtitle: 'Cash, GCash, Card, Credit and other payment totals.',
                      badge: _fmtCurrency(_paymentTotal),
                      badgeColor: const Color(0xFF22C55E),
                      onTap: () => _openComingSoon('Payment Summary'),
                    ),
                    const SizedBox(height: 12),

                    // 13. Hourly Sales
                    _buildCard(
                      icon: Icons.schedule_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      iconBg: const Color(0xFFEDE9FE),
                      title: 'Hourly Sales',
                      subtitle: 'Analyze sales by hour to identify peak selling periods.',
                      badge: _peakHour > 0 ? '${_peakHour}:00' : '--',
                      badgeColor: const Color(0xFF8B5CF6),
                      onTap: () => _openComingSoon('Hourly Sales'),
                    ),
                    const SizedBox(height: 12),

                    // 14. Sales Analytics
                    _buildCard(
                      icon: Icons.insights_rounded,
                      iconColor: const Color(0xFFEA580C),
                      iconBg: const Color(0xFFFFEDD5),
                      title: 'Sales Analytics',
                      subtitle: 'View sales trends, charts, KPIs and business insights.',
                      badge: '${_growthPct >= 0 ? '+' : ''}${_growthPct.toStringAsFixed(1)}%',
                      badgeColor: _growthPct >= 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                      onTap: () => _openComingSoon('Sales Analytics'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
