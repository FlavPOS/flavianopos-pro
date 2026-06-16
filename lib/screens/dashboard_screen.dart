// lib/screens/dashboard_screen.dart
import 'expenses/expenses_screen.dart';
import 'receive_delivery/receive_delivery_screen.dart' as rd;
import 'item_ledger/item_ledger_screen.dart';
import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'cashiering/cashiering_screen.dart';
import 'inventory/inventory_screen.dart';
import 'reports/z_report_screen.dart';
import 'reports/sales_history_screen.dart';
import 'reports/discount_monitoring_screen.dart';
import 'stock_adjustment/stock_adjustment_screen.dart';
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
  int _selectedIndex = 0;
  bool _hasAccess(String module) => widget.permissions.contains(module);

  void _navigateToModule(String module) {
    switch (module) {
      case 'Cashiering':
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
            builder: (context) => InventoryScreen(branch: widget.branch),
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
            builder: (context) =>
                StockAdjustmentScreen(branch: widget.branch),
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
                rd.ReceiveDeliveryScreen(products: Product.allProducts),
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
          final isPhone = screenW < 700;
          final isTablet = screenW >= 700;
          final isWide = screenW >= 1000;
          final contentMaxW = screenW >= 1200 ? 1400.0 : (screenW >= 900 ? 1200.0 : double.infinity);
          final hPad = screenW < 400 ? 10.0 : (screenW < 600 ? 14.0 : (screenW < 900 ? 22.0 : (screenW < 1200 ? 30.0 : 40.0)));
          final gridCols = screenW < 320 ? 2 : (screenW < 500 ? 3 : (screenW < 750 ? 4 : (screenW < 1000 ? 5 : 6)));
          final cardH = screenW < 360 ? 100.0 : (screenW < 500 ? 112.0 : (screenW < 750 ? 122.0 : 135.0));

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

                // ── Responsive Grid ──
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridCols,
                    crossAxisSpacing: screenW < 400 ? 8.0 : (screenW < 600 ? 10.0 : 14.0),
                    mainAxisSpacing: screenW < 400 ? 8.0 : (screenW < 600 ? 10.0 : 14.0),
                    mainAxisExtent: cardH),
                  children: [
                    _buildModuleCard('Cashiering', Icons.point_of_sale, Colors.green, () => _navigateToModule('Cashiering')),
                    _buildModuleCard('Inventory', Icons.inventory_2, Colors.orange, () => _navigateToModule('Inventory')),
                    _buildModuleCard('Z Report', Icons.assessment, Colors.purple, () => _navigateToModule('Z Report')),
                    _buildModuleCard('Sales History', Icons.history, Colors.teal, () => _navigateToModule('Sales History')),
                    _buildModuleCard('Stock Adjustment', Icons.tune, Colors.blue, () => _navigateToModule('Stock Adjustment')),
                    _buildModuleCard('Item Ledger', Icons.account_balance_wallet, Colors.deepPurple, () => _navigateToModule('Item Ledger')),
                    _buildModuleCard('Receive Delivery', Icons.local_shipping, Colors.teal, () => _navigateToModule('Receive Delivery')),
                    _buildModuleCard('Batch', Icons.inventory_2, Colors.teal, () => _navigateToModule('Batch')),
                    _buildModuleCard('Stock Transfer', Icons.swap_horiz, Colors.blue, () => _navigateToModule('Stock Transfer')),
                    _buildModuleCard('Branches', Icons.store, Colors.indigo, () => _navigateToModule('Branches')),
                    _buildModuleCard('Customers', Icons.people, Colors.cyan, () => _navigateToModule('Customers')),
                    _buildModuleCard('Users', Icons.admin_panel_settings, Colors.red, () => _navigateToModule('Users')),
                    _buildModuleCard('Discount Monitor', Icons.discount, Colors.deepOrange, () => _navigateToModule('Discount Monitor')),
                    _buildModuleCard('Settings', Icons.settings, Colors.blueGrey, () => _navigateToModule('Settings')),
                    _buildModuleCard('Expenses', Icons.receipt_long, Colors.purple, () => _navigateToModule('Expenses')),
                  ]),
              ])),
          ));
        }),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) { _navigateToModule('Cashiering'); setState(() => _selectedIndex = 0); }
          else if (index == 2) { _navigateToModule('Inventory'); setState(() => _selectedIndex = 0); }
          else if (index == 3) { _navigateToModule('Sales History'); setState(() => _selectedIndex = 0); }
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

  Widget _buildModuleCard(String title, IconData icon, Color color, VoidCallback onTap) => Card(
    elevation: 2, clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 7),
          Flexible(child: Text(title, style: const TextStyle(fontSize: 11.5, height: 1.1, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center, maxLines: 2, softWrap: true, overflow: TextOverflow.ellipsis)),
        ]))));
}
