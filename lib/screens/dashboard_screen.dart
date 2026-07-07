// lib/screens/dashboard_screen.dart
import 'expenses/expenses_screen.dart';
import 'profit_loss/profit_loss_screen.dart';
import '../services/cashier_session_service.dart';
import '../helpers/database_helper.dart';
import '../models/cashier_session_model.dart';
import 'cashier_lock/cash_declaration_screen.dart';
import 'cashier_lock/incident_report_screen.dart';
import 'cashier_lock/cashier_report_screen.dart';
import 'receive_delivery/receive_delivery_dashboard.dart' as rd;
import 'item_ledger/item_ledger_screen.dart';
import 'package:flutter/material.dart';
import '../services/daily_lock_service.dart';
import "../widgets/sync_status_pill.dart";
import 'auth/login_screen.dart';
import 'cashiering/cashiering_screen.dart';
import 'inventory/inventory_screen.dart';
import 'reports/z_report_screen.dart';
import 'reports/sales_history_screen.dart';
import 'reports/discount_monitoring_screen.dart';
import 'stock_adjustment/stock_adjustment_screen.dart';
import 'stock_adjustment/stock_adjustment_screen_v2.dart';
import 'stock_transfer/stock_transfer_screen.dart';
import '../models/product_model.dart';
import '../models/transaction_model.dart';
import 'customers/customers_screen.dart';
import 'settings/settings_screen.dart';
import 'users/users_screen.dart';
import 'branches/branches_screen.dart';
import 'batch/batch_screen.dart';
import '../models/batch_model.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String role;
  final String branch;
  final List<String> permissions;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.role,
    required this.branch,
    required this.permissions,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Feature flag: toggle true/false to switch v1/v2 UI
  static const bool _useAdjustmentV2 = true;

  int _selectedIndex = 0;
  bool _hasAccess(String module) => widget.permissions.contains('all') || widget.permissions.contains(module);

  // 🔓 Manager PIN unlock — start new business day after Z Report



  void _openCashierReport() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CashierReportScreen(currentUser: widget.userName, branch: widget.branch),
    ));
  }

  Future<void> _endShift() async {
    // Get active session
    final session = await CashierSessionService.getActiveSession(widget.userName);
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active shift found'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Get latest session data (with all updates)
    final sessionRow = await DatabaseHelper().getSessionById(session.id);
    if (sessionRow == null) return;
    final freshSession = CashierSession.fromMap(sessionRow);

    // System Expected Cash = Beginning + Cash Sales - Refunds
    final systemExpected = freshSession.beginningCash + freshSession.cashSales - freshSession.totalRefunds;

    if (!mounted) return;
    final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(
      builder: (_) => CashDeclarationScreen(
        session: freshSession,
        systemExpectedCash: systemExpected,
        cashSales: freshSession.cashSales,
        gcashSales: freshSession.gcashSales,
        mayaSales: freshSession.mayaSales,
        cardSales: freshSession.cardSales,
        totalRefunds: freshSession.totalRefunds,
        totalVoids: freshSession.totalVoids,
        totalDiscounts: freshSession.totalDiscounts,
        totalExchanges: freshSession.totalExchanges,
        transactionCount: freshSession.transactionCount,
      ),
    ));

    if (result == null) return;

    if (result['requireIR'] == true) {
      // Navigate to IR Screen
      // Variance > ₱50 → Open IR Screen
      final irResult = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(
        builder: (_) => IncidentReportScreen(
          session: freshSession,
          totalCounted: result['totalCounted'] as double,
          systemExpected: systemExpected,
          variance: result['variance'] as double,
          denominations: (result['denominations'] as Map<double, int>),
        ),
      ));

      if (irResult != null && irResult['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('IR filed. Shift ended with variance ₱${(irResult['variance'] as double).toStringAsFixed(2)}'),
              backgroundColor: Colors.orange, duration: const Duration(seconds: 3)),
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
          }
        }
      }
      return;
    }

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shift ended! Ending cash: ₱${(result['totalCounted'] as double).toStringAsFixed(2)}'),
          backgroundColor: Colors.green, duration: const Duration(seconds: 3)),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
      }
    }
  }

  void _navigateToModule(String module) {
    switch (module) {
      case 'Cashiering':
        // 🔒 Daily Lock check
        DailyLockService.shouldBlock(widget.role).then((locked) async {
          if (locked) {
            await DailyLockService.showCashierLockedDialog(context, action: "ring up sales");
            return;
          }
          if (!context.mounted) return;
          Navigator.push(context, MaterialPageRoute(builder: (context) => CashieringScreen(
            userName: widget.userName, branch: widget.branch,
          )));
        });
        return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CashieringScreen(
              userName: widget.userName,
              branch: widget.branch,
            ),
          ),
        ).then((_) => setState(() {}));
        break;

      case 'Inventory':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InventoryScreen(branch: widget.branch, role: widget.role, permissions: widget.permissions),
          ),
        ).then((_) => setState(() {}));
        break;

      case 'Z Report':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ZReportScreen(
              branch: widget.branch,
              cashier: widget.userName,
            ),
          ),
        ).then((_) => setState(() {}));
        break;

      case 'Sales History':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SalesHistoryScreen(branch: widget.branch),
          ),
        ).then((_) => setState(() {}));
        break;

      case 'Stock Adjustment':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _useAdjustmentV2
                ? StockAdjustmentScreenV2(branch: widget.branch, userName: widget.userName)
                : StockAdjustmentScreen(branch: widget.branch, userName: widget.userName),
          ),
        ).then((_) => setState(() {}));
        break;

      case 'Stock Transfer':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StockTransferScreen(
              currentUser: widget.userName,
              currentBranch: widget.branch,
            ),
          ),
        ).then((_) => setState(() {}));
        break;

      case 'Item Ledger':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ItemLedgerScreen(products: Product.allProducts),
          ),
        ).then((_) => setState(() {}));
        break;

      case 'Receive Delivery':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                rd.ReceiveDeliveryDashboard(products: Product.allProducts),
          ),
        ).then((_) => setState(() {}));
        break;

      case 'Customers':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CustomersScreen()),
        ).then((_) => setState(() {}));
        break;

      case 'Settings':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SettingsScreen(branch: widget.branch),
          ),
        ).then((_) => setState(() {}));
        break;

      case 'Users':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UsersScreen()),
        ).then((_) => setState(() {}));
        break;

      case 'Discount Monitor':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DiscountMonitoringScreen(branch: widget.branch),
          ),
        ).then((_) => setState(() {}));
        break;

      case 'Batch':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BatchScreen()),
        ).then((_) => setState(() {}));
        break;
      case 'Expenses':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ExpensesScreen(currentUser: widget.userName, branch: widget.branch))).then((_) => setState(() {}));
        break;
      case 'Profit & Loss':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfitLossScreen(currentUser: widget.userName, branch: widget.branch))).then((_) => setState(() {}));
        break;

      case 'Branches':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BranchesScreen()),
        ).then((_) => setState(() {}));
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$module module coming soon!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  double get _todaySales {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Transaction.allTransactions
        .where((t) => t.dateTime.isAfter(today) && t.status == 'completed')
        .fold(0.0, (s, t) => s + t.total);
  }

  int get _todayTxnCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Transaction.allTransactions
        .where((t) => t.dateTime.isAfter(today) && t.status == 'completed')
        .length;
  }

  int get _lowStockCount =>
      Product.allProducts.where((p) => p.stockQty <= p.reorderLevel).length;

  List<ProductBatch> get _expiryAlerts {
    return ProductBatch.allBatches
        .where(
          (b) =>
              !b.isExpired && b.daysUntilExpiry <= 30 && b.quantity > 0,
        )
        .toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
  }

  List<ProductBatch> get _expiredItems {
    return ProductBatch.allBatches
        .where((b) => b.isExpired && b.quantity > 0)
        .toList();
  }

  int get _totalAlerts => _expiryAlerts.length + _expiredItems.length;

  Widget _buildNotifBell() {
    final ct = _totalAlerts;

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => _showNotifPanel(),
        ),
        if (ct > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                ct.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _showNotifPanel() {
    final exp = _expiredItems;
    final near = _expiryAlerts;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx2, scroll) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications,
                    color: Colors.orange[700],
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${exp.length + near.length} alerts',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (exp.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error,
                            size: 16,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'EXPIRED (${exp.length})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...exp.map((bt) => _notifCard(bt, true)),
                  ],
                  if (near.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'NEAR EXPIRY (${near.length})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...near.map((bt) => _notifCard(bt, false)),
                  ],
                  if (exp.isEmpty && near.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 48,
                            color: Colors.green[300],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'All good!',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'No expiry alerts',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BatchScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.inventory_2),
                      label: const Text('View All Batches'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifCard(ProductBatch bt, bool isExp) {
    final color = isExp ? Colors.red : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isExp ? Icons.error : Icons.warning,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bt.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Batch: ${bt.batchNumber}  |  Qty: ${bt.quantity}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    bt.expiryText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isExp ? 'EXPIRED' : '${bt.daysUntilExpiry}d',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override

  // ── Purple Theme ──
  static const _bgPurple = Color(0xFF6A1B9A);
  static const _purple2 = Color(0xFF7B1FA2);
  static const _btnPurple = Color(0xFF8E24AA);

  // ── Dynamic sizing helpers ──
  int _gridCols(double w) {
    if (w >= 1200) return 6;
    if (w >= 1000) return 5;
    if (w >= 750) return 4;
    if (w >= 500) return 3;
    if (w >= 320) return 3;
    return 2;
  }

  double _cardHeight(double w) {
    if (w >= 1200) return 140;
    if (w >= 1000) return 135;
    if (w >= 750) return 128;
    if (w >= 500) return 118;
    if (w >= 360) return 108;
    return 96;
  }

  double _iconSize(double w) {
    if (w >= 1200) return 36;
    if (w >= 900) return 32;
    if (w >= 600) return 30;
    if (w >= 400) return 28;
    return 22;
  }

  double _iconPadding(double w) {
    if (w >= 1200) return 14;
    if (w >= 900) return 13;
    if (w >= 600) return 12;
    if (w >= 400) return 11;
    return 8;
  }

  double _labelSize(double w) {
    if (w >= 1200) return 14;
    if (w >= 900) return 13;
    if (w >= 600) return 12;
    if (w >= 400) return 11.5;
    return 10;
  }

  double _gridSpacing(double w) {
    if (w >= 1200) return 16;
    if (w >= 900) return 14;
    if (w >= 600) return 12;
    if (w >= 400) return 10;
    return 8;
  }

  double _cardBorderRadius(double w) {
    if (w >= 900) return 20;
    if (w >= 600) return 18;
    return 16;
  }

  double _cardInnerHPad(double w) {
    if (w >= 900) return 10;
    if (w >= 600) return 8;
    return 6;
  }

  double _cardInnerVPad(double w) {
    if (w >= 900) return 14;
    if (w >= 600) return 12;
    return 10;
  }

  @override

  void _showPermissionDenied(String moduleName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.orange[700], size: 28),
            const SizedBox(width: 10),
            const Text('Permission Required', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You don\'t have permission to access $moduleName.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                border: Border.all(color: Colors.amber[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[800], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Contact your administrator to request access.',
                      style: TextStyle(fontSize: 11, color: Colors.amber[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('OK'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _bgPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.3)),
        actions: [
          _buildNotifBell(),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            constraints: const BoxConstraints(maxWidth: 120),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(widget.branch, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ),
          const SyncStatusPill(),
          IconButton(icon: const Icon(Icons.logout), onPressed: () {
            showDialog(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Logout'), content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(onPressed: () { Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false); },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Logout')),
              ]));
          }),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, outer) {
          final screenW = outer.maxWidth;
          final isCompact = screenW < 360;

          // ✅ FIX 1: No max width cap — fills entire screen
          final contentMaxW = double.infinity;

          // ✅ FIX 2: Reduced padding on wide screens
          final hPad = screenW < 400 ? 10.0 : (screenW < 600 ? 14.0 : (screenW < 900 ? 16.0 : 20.0));

          // ── Dynamic grid values ──
          final gridCols = _gridCols(screenW);
          final cardH = _cardHeight(screenW);
          final spacing = _gridSpacing(screenW);
          final iconSz = _iconSize(screenW);
          final iconPad = _iconPadding(screenW);
          final labelSz = _labelSize(screenW);
          final borderR = _cardBorderRadius(screenW);
          final innerH = _cardInnerHPad(screenW);
          final innerV = _cardInnerVPad(screenW);

          return Center(child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxW),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: hPad * 0.7),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Welcome Card ──
                Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(width: double.infinity, padding: EdgeInsets.all(screenW < 360 ? 12.0 : (screenW < 600 ? 16.0 : (screenW < 900 ? 22.0 : 28.0))),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(colors: [_bgPurple, _purple2])),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Welcome, ${widget.userName}!',
                        style: TextStyle(color: Colors.white, fontSize: screenW < 360 ? 16.0 : (screenW < 600 ? 20.0 : (screenW < 900 ? 24.0 : 28.0)), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${widget.role} - ${widget.branch}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: screenW < 360 ? 11.0 : (screenW < 600 ? 13.0 : 15.0))),
                      SizedBox(height: screenW < 600 ? 12.0 : 18.0),
                      // Stats row — wraps on compact
                      isCompact
                        ? Wrap(spacing: 16, runSpacing: 12, children: [
                            _buildQuickStat('Today Sales', _todaySales.toStringAsFixed(2), Icons.trending_up),
                            _buildQuickStat('Transactions', '$_todayTxnCount', Icons.receipt_long),
                            _buildQuickStat('Low Stock', '$_lowStockCount', Icons.warning_amber),
                          ])
                        : Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _buildQuickStat('Today Sales', _todaySales.toStringAsFixed(2), Icons.trending_up),
                            _buildQuickStat('Transactions', '$_todayTxnCount', Icons.receipt_long),
                            _buildQuickStat('Low Stock', '$_lowStockCount', Icons.warning_amber),
                          ]),
                    ]))),

                SizedBox(height: screenW < 600 ? 16.0 : 24.0),
                Text('Quick Actions', style: TextStyle(fontSize: screenW < 360 ? 16.0 : (screenW < 600 ? 18.0 : 20.0), fontWeight: FontWeight.bold)),
                SizedBox(height: screenW < 600 ? 8.0 : 14.0),

                // ── Responsive Dynamic Grid ──
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridCols,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    mainAxisExtent: cardH,
                  ),
                  children: [
if (_hasAccess('Cashiering'))                     _buildModuleCard('Cashiering', Icons.point_of_sale, Colors.green, () => _navigateToModule('Cashiering'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
if (_hasAccess('Inventory'))                     _buildModuleCard('Inventory', Icons.inventory_2, Colors.orange, () => _navigateToModule('Inventory'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
if (_hasAccess('Z Report'))                     _buildModuleCard('Z Report', Icons.assessment, Colors.purple, () => _navigateToModule('Z Report'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
if (_hasAccess('Sales History'))                     _buildModuleCard('Sales History', Icons.history, Colors.teal, () => _navigateToModule('Sales History'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
if (_hasAccess('Stock Adjustment'))                     _buildModuleCard('Stock Adjustment', Icons.tune, Colors.blue, () => _navigateToModule('Stock Adjustment'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
if (_hasAccess('Item Ledger'))                     _buildModuleCard('Item Ledger', Icons.account_balance_wallet, Colors.deepPurple, () => _navigateToModule('Item Ledger'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
if (_hasAccess('Receive Delivery'))                     _buildModuleCard('Receive Delivery', Icons.local_shipping, Colors.teal, () => _navigateToModule('Receive Delivery'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
if (_hasAccess('Batch Management'))                     _buildModuleCard('Batch', Icons.inventory_2, Colors.teal, () => _navigateToModule('Batch'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
if (_hasAccess('Stock Transfer'))                     _buildModuleCard('Stock Transfer', Icons.swap_horiz, Colors.blue, () => _navigateToModule('Stock Transfer'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
if (_hasAccess('Branches'))                     _buildModuleCard('Branches', Icons.store, Colors.indigo, () => _navigateToModule('Branches'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
if (_hasAccess('Customers'))                     _buildModuleCard('Customers', Icons.people, Colors.cyan, () => _navigateToModule('Customers'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
if (_hasAccess('Users'))                     _buildModuleCard('Users', Icons.admin_panel_settings, Colors.red, () => _navigateToModule('Users'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
if (_hasAccess('Discount Monitoring'))                     _buildModuleCard('Discount Monitor', Icons.discount, Colors.deepOrange, () => _navigateToModule('Discount Monitor'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
if (_hasAccess('Settings'))                     _buildModuleCard('Settings', Icons.settings, Colors.blueGrey, () => _navigateToModule('Settings'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
if (_hasAccess('Expenses'))                     _buildModuleCard('Expenses', Icons.receipt_long, Colors.purple, () => _navigateToModule('Expenses'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
if (_hasAccess('Profit & Loss'))                _buildModuleCard('Profit & Loss', Icons.trending_up, Colors.teal, () => _navigateToModule('Profit & Loss'), iconSz, iconPad, labelSz, borderR, innerH, innerV),
                if (_hasAccess("End Shift")) _buildModuleCard("End Shift", Icons.lock_clock, Colors.red.shade700, () => _endShift(), iconSz, iconPad, labelSz, borderR, innerH, innerV),
                if (_hasAccess("Cashier Report")) _buildModuleCard("Cashier Report", Icons.assignment_ind, Colors.indigo.shade700, () => _openCashierReport(), iconSz, iconPad, labelSz, borderR, innerH, innerV),
                  ],
                ),
                const SizedBox(height: 80),
              ])),
          ));
        }),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0) return; // Dashboard - always accessible

          // Tab 1: Cashier
          if (index == 1) {
            if (_hasAccess('Cashiering')) {
              _navigateToModule('Cashiering');
            } else {
              _showPermissionDenied('Cashier');
            }
            setState(() => _selectedIndex = 0);
          }
          // Tab 2: Inventory
          else if (index == 2) {
            if (_hasAccess('Inventory')) {
              _navigateToModule('Inventory');
            } else {
              _showPermissionDenied('Inventory');
            }
            setState(() => _selectedIndex = 0);
          }
          // Tab 3: Reports
          else if (index == 3) {
            if (_hasAccess("Tab: Reports")) {
              _navigateToModule('Sales History');
            } else {
              _showPermissionDenied('Reports');
            }
            setState(() => _selectedIndex = 0);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'Cashier'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Reports'),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) => Column(children: [
    Icon(icon, color: Colors.white, size: 26),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
  ]);

  Widget _buildModuleCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
    double iconSz,
    double iconPad,
    double labelSz,
    double borderR,
    double innerH,
    double innerV,
  ) =>
      Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderR)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderR),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: innerH, vertical: innerV),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(iconPad),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: iconSz),
                ),
                SizedBox(height: iconSz * 0.25),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: labelSz,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
