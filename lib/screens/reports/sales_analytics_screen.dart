// lib/screens/reports/sales_analytics_screen.dart
import '../../models/settings_model.dart';
import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import '../../utils/export_helper.dart';

class SalesAnalyticsScreen extends StatefulWidget {
  final String branch;
  const SalesAnalyticsScreen({super.key, required this.branch});
  @override
  State<SalesAnalyticsScreen> createState() => _SalesAnalyticsScreenState();
}

// ─────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────

class _ItemSales {
  final String name;
  final String sku;
  double totalSales = 0;
  int totalUnits = 0;
  int txnCount = 0;
  String category;
  _ItemSales({required this.name, required this.sku, this.category = ''});
}

class _CategorySales {
  final String name;
  final IconData icon;
  final Color color;
  double totalSales = 0;
  int totalUnits = 0;
  int txnCount = 0;
  int itemCount = 0;
  List<_ItemSales> items = [];
  bool expanded = false;
  _CategorySales({
    required this.name,
    required this.icon,
    required this.color,
    List<_ItemSales>? items,
  }) : items = items ?? [];
}

class _DaySales {
  final DateTime date;
  final int txnCount;
  final int units;
  final double sales;
  _DaySales({
    required this.date,
    this.txnCount = 0,
    this.units = 0,
    this.sales = 0,
  });
}

/// Pre-computed trend row - all values ready at build time.
class _TrendRow {
  final String label;
  final int days;        // active days with sales only
  final int txnCount;
  final int units;
  final double sales;
  final double atv;
  final double ipb;
  final double ads;      // Gross Sales / active days
  final double atc;      // TXN / active days
  final double profit;
  final double margin;

  _TrendRow({
    required this.label,
    required this.days,
    required this.txnCount,
    required this.units,
    required this.sales,
    required this.atv,
    required this.ipb,
    required this.ads,
    required this.atc,
    required this.profit,
    required this.margin,
  });

  /// Maps to the 12-column layout:
  /// Days | TXN | ADS | Gross | Net | Disc | Margin | Profit | Units | ATC | ATV | IPB
  List<String> toStringList() => [
        '$days',
        '$txnCount',
        ads.toStringAsFixed(2),
        sales.toStringAsFixed(2),
        sales.toStringAsFixed(2),
        '0.00',
        '${margin.toStringAsFixed(1)}%',
        profit.toStringAsFixed(2),
        '$units',
        atc.toStringAsFixed(1),
        atv.toStringAsFixed(2),
        ipb.toStringAsFixed(1),
      ];
}

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────

class _SalesAnalyticsScreenState extends State<SalesAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  // v1.0.59+131 — Branch-scoped for data isolation
  List<Transaction> _transactions = [];

  Future<void> _loadBranchScoped() async {
    final txns = await Transaction.branchScopedTransactions;
    if (mounted) setState(() => _transactions = txns);
  }

  String _dateFilter = AppSettings.defaultReportPeriod;
  String _trendView = 'Daily';
  final Set<String> _visibleCols = {'Days', 'TXN', 'ADS', 'Gross', 'Net', 'Disc', 'Margin', 'Profit', 'Units', 'ATC', 'ATV', 'IPB'};
  DateTimeRange? _customRange;
  String _sortBy = 'Sales';
  String _query = '';
  final _searchCtrl = TextEditingController();

  final _dateFilters = [
    'Today',
    'Yesterday',
    'This Week',
    'This Month',
    'All',
    'Custom',
  ];

  // ── All column keys in display order (single source of truth) ──
  static const List<String> _allColKeys = [
    'Days', 'TXN', 'ADS', 'Gross', 'Net', 'Disc', 'Margin', 'Profit', 'Units', 'ATC', 'ATV', 'IPB',
  ];

  // ── SKU prefix → category mapping ──────────────────────────
  static const Map<String, String> _skuCategories = {
    'BEV': 'Beverages',
    'SNK': 'Snacks',
    'GRC': 'Groceries',
    'GRO': 'Groceries',
    'PRC': 'Personal Care',
    'HOM': 'Home Care',
    'NUD': 'Noodles',
    'CAN': 'Canned Goods',
    'DAI': 'Dairy',
    'BAK': 'Bakery',
  };

  static const Map<String, IconData> _catIcons = {
    'Beverages': Icons.local_drink,
    'Snacks': Icons.cookie,
    'Groceries': Icons.shopping_basket,
    'Personal Care': Icons.face,
    'Home Care': Icons.cleaning_services,
    'Noodles': Icons.ramen_dining,
    'Canned Goods': Icons.inventory_2,
    'Dairy': Icons.egg,
    'Bakery': Icons.bakery_dining,
    'Other': Icons.category,
  };

  static const Map<String, Color> _catColors = {
    'Beverages': Colors.blue,
    'Snacks': Colors.orange,
    'Groceries': Colors.green,
    'Personal Care': Colors.pink,
    'Home Care': Colors.purple,
    'Noodles': Colors.amber,
    'Canned Goods': Colors.teal,
    'Dairy': Colors.cyan,
    'Bakery': Colors.brown,
    'Other': Colors.grey,
  };

  // ── Lifecycle ───────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadBranchScoped(); // v1.0.59+131 — branch isolation
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  /// Total calendar days in the selected filter window.
  int _getTotalCalendarDays() {
    final now = DateTime.now();
    switch (_dateFilter) {
      case 'Today':
        return 1;
      case 'Yesterday':
        return 1;
      case 'This Week':
        return 7;
      case 'This Month':
        return now.day;
      case 'Custom':
        if (_customRange != null) {
          return _customRange!.end.difference(_customRange!.start).inDays + 1;
        }
        return 1;
      default:
        return now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    }
  }

  /// Returns only the selected/green column keys in display order.
  List<String> get _activeColKeys =>
      _allColKeys.where((c) => _visibleCols.contains(c)).toList();

  // ── Filtered transactions ───────────────────────────────────

  List<Transaction> get _filtered {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _transactions.where((t) {
      if (t.status == 'voided' || t.status == 'refunded') return false;
      switch (_dateFilter) {
        case 'Today':
          return t.dateTime.isAfter(today);
        case 'Yesterday':
          final y = today.subtract(const Duration(days: 1));
          return t.dateTime.isAfter(y) && t.dateTime.isBefore(today);
        case 'This Week':
          return t.dateTime.isAfter(today.subtract(const Duration(days: 7)));
        case 'This Month':
          return t.dateTime.month == now.month &&
              t.dateTime.year == now.year;
        case 'Custom':
          if (_customRange != null) {
            return t.dateTime.isAfter(_customRange!.start) &&
                t.dateTime.isBefore(
                    _customRange!.end.add(const Duration(days: 1)));
          }
          return true;
        default:
          return true;
      }
    }).toList();
  }

  // ── Aggregations ────────────────────────────────────────────

  List<_ItemSales> get _itemSales {
    final map = <String, _ItemSales>{};
    for (final t in _filtered) {
      for (final item in t.items) {
        final prefix =
            item.sku.length >= 3 ? item.sku.substring(0, 3) : '';
        final cat = _skuCategories[prefix] ?? 'Other';
        map.putIfAbsent(
            item.name,
            () => _ItemSales(
                  name: item.name,
                  sku: item.sku,
                  category: cat,
                ));
        map[item.name]!.totalSales += item.subtotal;
        map[item.name]!.totalUnits += item.qty;
        map[item.name]!.txnCount++;
      }
    }
    var list = map.values.toList();
    if (_query.isNotEmpty) {
      list = list
          .where((i) =>
              i.name.toLowerCase().contains(_query.toLowerCase()))
          .toList();
    }
    switch (_sortBy) {
      case 'Sales':
        list.sort((a, b) => b.totalSales.compareTo(a.totalSales));
        break;
      case 'Units':
        list.sort((a, b) => b.totalUnits.compareTo(a.totalUnits));
        break;
      case 'Name':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return list;
  }

  List<_CategorySales> get _categorySales {
    final map = <String, _CategorySales>{};
    for (final item in _itemSales) {
      final cat = item.category;
      map.putIfAbsent(
          cat,
          () => _CategorySales(
                name: cat,
                icon: _catIcons[cat] ?? Icons.category,
                color: _catColors[cat] ?? Colors.grey,
              ));
      map[cat]!.totalSales += item.totalSales;
      map[cat]!.totalUnits += item.totalUnits;
      map[cat]!.txnCount += item.txnCount;
      map[cat]!.itemCount++;
      map[cat]!.items.add(item);
    }
    final list = map.values.toList()
      ..sort((a, b) => b.totalSales.compareTo(a.totalSales));
    return list;
  }

  List<_DaySales> get _dailySales {
    final map = <String, _DaySales>{};
    for (final t in _filtered) {
      if (t.total <= 0) continue;
      final key =
          '${t.dateTime.year}-${t.dateTime.month}-${t.dateTime.day}';
      if (!map.containsKey(key)) {
        map[key] = _DaySales(
            date: DateTime(
                t.dateTime.year, t.dateTime.month, t.dateTime.day));
      }
      map[key] = _DaySales(
        date: map[key]!.date,
        txnCount: map[key]!.txnCount + 1,
        units: map[key]!.units + t.totalQty,
        sales: map[key]!.sales + t.total,
      );
    }
    return map.values.where((d) => d.sales > 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<_DaySales> get _monthlySales {
    final map = <int, _DaySales>{};
    for (final t in _filtered) {
      if (t.total <= 0) continue;
      final key = t.dateTime.month;
      if (!map.containsKey(key)) {
        map[key] = _DaySales(date: DateTime(t.dateTime.year, key, 1));
      }
      map[key] = _DaySales(
        date: map[key]!.date,
        txnCount: map[key]!.txnCount + 1,
        units: map[key]!.units + t.totalQty,
        sales: map[key]!.sales + t.total,
      );
    }
    return map.values.where((d) => d.sales > 0).toList()
      ..sort((a, b) => a.date.month.compareTo(b.date.month));
  }

  List<_DaySales> get _weeklySales {
    final now = DateTime.now();
    final jan1 = DateTime(now.year, 1, 1);
    final map = <int, _DaySales>{};
    for (final t in _filtered) {
      if (t.total <= 0) continue;
      if (t.dateTime.year != now.year) continue;
      final wk =
          (t.dateTime.difference(jan1).inDays ~/ 7 + 1).clamp(1, 52);
      if (!map.containsKey(wk)) {
        map[wk] =
            _DaySales(date: jan1.add(Duration(days: (wk - 1) * 7)));
      }
      map[wk] = _DaySales(
        date: map[wk]!.date,
        txnCount: map[wk]!.txnCount + 1,
        units: map[wk]!.units + t.totalQty,
        sales: map[wk]!.sales + t.total,
      );
    }
    return (map.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => e.value)
        .where((d) => d.sales > 0)
        .toList();
  }

  double get _discountSum =>
      _filtered.fold(0.0, (s, t) => s + t.totalDiscount);

  // ─────────────────────────────────────────────────────────────
  // Core: build trend rows using ACTIVE DAYS only
  //
  // ADS = Gross Sales  ÷  days that had ≥1 transaction
  // ATC = Transactions ÷  days that had ≥1 transaction
  // ─────────────────────────────────────────────────────────────
  List<_TrendRow> _buildTrendRows() {
    final now = DateTime.now();
    final mo = [
      '',
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    final jan1 = DateTime(now.year, 1, 1);

    final Map<String, Set<String>> activeDatesPerMonth = {};
    final Map<int, Set<String>> activeDatesPerWeek = {};

    for (final t in _filtered) {
      if (t.total <= 0) continue;
      final dateKey =
          '${t.dateTime.year}-${t.dateTime.month}-${t.dateTime.day}';

      final monthKey = '${t.dateTime.year}-${t.dateTime.month}';
      activeDatesPerMonth.putIfAbsent(monthKey, () => {}).add(dateKey);

      if (t.dateTime.year == now.year) {
        final wk =
            (t.dateTime.difference(jan1).inDays ~/ 7 + 1).clamp(1, 52);
        activeDatesPerWeek.putIfAbsent(wk, () => {}).add(dateKey);
      }
    }

    List<_DaySales> data;
    if (_trendView == 'Monthly') {
      data = _monthlySales;
    } else if (_trendView == 'Weekly') {
      data = _weeklySales;
    } else {
      data = _dailySales;
    }

    final List<_TrendRow> rows = [];

    for (final d in data) {
      if (d.txnCount == 0 && d.sales == 0) continue;

      String label;
      int days;

      if (_trendView == 'Monthly') {
        label = '${mo[d.date.month]} ${d.date.year}';
        final monthKey = '${d.date.year}-${d.date.month}';
        days = activeDatesPerMonth[monthKey]?.length ?? 0;

      } else if (_trendView == 'Weekly') {
        final periodWk =
            (d.date.difference(jan1).inDays ~/ 7) + 1;
        label = 'Wk $periodWk';
        days = activeDatesPerWeek[periodWk]?.length ?? 0;

      } else {
        final wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
        label =
            '${d.date.month}/${d.date.day} ${wd[d.date.weekday - 1]}';
        days = d.sales > 0 ? 1 : 0;
      }

      final safeDays = days < 1 ? 1 : days;

      final double n   = d.sales;
      final double atv = d.txnCount > 0 ? n / d.txnCount : 0.0;
      final double ipb =
          d.txnCount > 0 ? d.units / d.txnCount : 0.0;
      final double ads = n / safeDays;
      final double atc = d.txnCount / safeDays;

      rows.add(_TrendRow(
        label:    label,
        days:     days,
        txnCount: d.txnCount,
        units:    d.units,
        sales:    n,
        atv:      atv,
        ipb:      ipb,
        ads:      ads,
        atc:      atc,
        profit:   n * 0.30,
        margin:   n > 0 ? 30.0 : 0.0,
      ));
    }

    return rows;
  }

  // ─────────────────────────────────────────────────────────────
  // Date picker
  // ─────────────────────────────────────────────────────────────

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
            colorScheme:
                ColorScheme.light(primary: Colors.teal[700]!)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _dateFilter = 'Custom';
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Snackbar helper
  // ─────────────────────────────────────────────────────────────

  void _snack(String msg, {Color? color}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  // ─────────────────────────────────────────────────────────────
  // ★ Column-value mappers for Category & Trends export
  //   Returns the value string for a given column key.
  // ─────────────────────────────────────────────────────────────

  /// Map a column key to the Category row value.
  String _catColValue(String colKey, _CategorySales c, int calDays) {
    final n = c.totalSales;
    final atv = c.txnCount > 0 ? n / c.txnCount : 0.0;
    final ipb = c.txnCount > 0 ? c.totalUnits / c.txnCount : 0.0;
    switch (colKey) {
      case 'Days':   return '$calDays';
      case 'TXN':    return '${c.txnCount}';
      case 'ADS':    return (n / calDays).toStringAsFixed(2);
      case 'Gross':  return n.toStringAsFixed(2);
      case 'Net':    return n.toStringAsFixed(2);
      case 'Disc':   return '0.00';
      case 'Margin': return '${n > 0 ? "30.0" : "0.0"}%';
      case 'Profit': return (n * 0.3).toStringAsFixed(2);
      case 'Units':  return '${c.totalUnits}';
      case 'ATC':    return (c.txnCount / calDays).toStringAsFixed(1);
      case 'ATV':    return atv.toStringAsFixed(2);
      case 'IPB':    return ipb.toStringAsFixed(1);
      default:       return '';
    }
  }

  /// Map a column key to the Trend row value.
  String _trendColValue(String colKey, _TrendRow r) {
    switch (colKey) {
      case 'Days':   return '${r.days}';
      case 'TXN':    return '${r.txnCount}';
      case 'ADS':    return r.ads.toStringAsFixed(2);
      case 'Gross':  return r.sales.toStringAsFixed(2);
      case 'Net':    return r.sales.toStringAsFixed(2);
      case 'Disc':   return '0.00';
      case 'Margin': return '${r.margin.toStringAsFixed(1)}%';
      case 'Profit': return r.profit.toStringAsFixed(2);
      case 'Units':  return '${r.units}';
      case 'ATC':    return r.atc.toStringAsFixed(1);
      case 'ATV':    return r.atv.toStringAsFixed(2);
      case 'IPB':    return r.ipb.toStringAsFixed(1);
      default:       return '';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Shared widgets
  // ─────────────────────────────────────────────────────────────

  Widget _buildColToggles(List<String> allCols) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: allCols.map((c) {
            final on = _visibleCols.contains(c);
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () => setState(() {
                  if (on) {
                    _visibleCols.remove(c);
                  } else {
                    _visibleCols.add(c);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: on ? Colors.teal[700] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: on ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _miniCard(String label, String value, Color color) => Expanded(
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withAlpha(40)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color)),
            Text(label,
                style:
                    TextStyle(fontSize: 9, color: Colors.grey[600])),
          ]),
        ),
      );

  Widget _sumChipFixed(String label, String value, Color color) =>
      Container(
        width: 80,
        padding:
            const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: color)),
          Text(label,
              style:
                  TextStyle(fontSize: 7, color: Colors.grey[600])),
        ]),
      );

  Color? _colColor(String c) {
    if (c == 'Net') return Colors.teal[700];
    if (c == 'Disc') return Colors.red;
    if (c == 'Profit') return Colors.blue;
    if (c == 'Margin') return Colors.purple;
    if (c == 'ADS') return Colors.indigo;
    if (c == 'ATC') return Colors.cyan[800];
    if (c == 'Days') return Colors.brown;
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  // ★ EXPORT TO EXCEL - only selected/green columns
  // ═══════════════════════════════════════════════════════════════
  void _exportExcel() {
    final tab = _tabCtrl.index;

    if (tab == 0) {
      // ── Tab 0: By Item - all fields (no column toggles) ──
      final data = _itemSales;
      if (data.isEmpty) {
        _snack('No selected data to export.', color: Colors.orange[800]);
        return;
      }
      ExportHelper.exportExcel(
        headers: ['SKU', 'Item Name', 'Units Sold', 'Total Sales', 'Txn Count', 'Category'],
        rows: data.map((s) => [
          s.sku, s.name, s.totalUnits.toString(),
          s.totalSales.toStringAsFixed(2), s.txnCount.toString(),
          s.category,
        ]).toList(),
        sheetName: 'Sales_By_Item',
        fileName: 'SalesAnalytics_ByItem_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      _snack('✅ Excel exported (By Item)!', color: Colors.green);

    } else if (tab == 1) {
      // ── Tab 1: By Category - only selected/green columns ──
      final activeCols = _activeColKeys;
      if (activeCols.isEmpty) {
        _snack('No selected data to export.', color: Colors.orange[800]);
        return;
      }
      final data = _categorySales;
      if (data.isEmpty) {
        _snack('No selected data to export.', color: Colors.orange[800]);
        return;
      }
      final calDays = _getTotalCalendarDays();
      final headers = ['Category', ...activeCols];
      final rows = data.map((c) => [
        c.name,
        ...activeCols.map((col) => _catColValue(col, c, calDays)),
      ]).toList();
      ExportHelper.exportExcel(
        headers: headers,
        rows: rows,
        sheetName: 'Sales_By_Category',
        fileName: 'SalesAnalytics_ByCategory_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      _snack('✅ Excel exported (By Category - ${activeCols.length} columns)!', color: Colors.green);

    } else {
      // ── Tab 2: Trends - only selected/green columns ──
      final activeCols = _activeColKeys;
      if (activeCols.isEmpty) {
        _snack('No selected data to export.', color: Colors.orange[800]);
        return;
      }
      final trendRows = _buildTrendRows();
      if (trendRows.isEmpty) {
        _snack('No selected data to export.', color: Colors.orange[800]);
        return;
      }
      final headers = ['Period', ...activeCols];
      final rows = trendRows.map((r) => [
        r.label,
        ...activeCols.map((col) => _trendColValue(col, r)),
      ]).toList();
      ExportHelper.exportExcel(
        headers: headers,
        rows: rows,
        sheetName: 'Sales_Trends_$_trendView',
        fileName: 'SalesAnalytics_Trends_${_trendView}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      _snack('✅ Excel exported (Trends $_trendView - ${activeCols.length} columns)!', color: Colors.green);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ★ EXPORT TO PDF - only selected/green columns
  // ═══════════════════════════════════════════════════════════════
  void _exportPdf() {
    final tab = _tabCtrl.index;

    if (tab == 0) {
      // ── Tab 0: By Item - all fields ──
      final data = _itemSales;
      if (data.isEmpty) {
        _snack('No selected data to export.', color: Colors.orange[800]);
        return;
      }
      ExportHelper.exportPdf(
        title: 'Sales Analytics - By Item',
        subtitle: '${data.length} items  |  Filter: $_dateFilter',
        headers: ['SKU', 'Item Name', 'Units Sold', 'Total Sales', 'Txn Count', 'Category'],
        rows: data.map((s) => [
          s.sku, s.name, s.totalUnits.toString(),
          s.totalSales.toStringAsFixed(2), s.txnCount.toString(),
          s.category,
        ]).toList(),
        fileName: 'SalesAnalytics_ByItem_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      _snack('✅ PDF exported (By Item)!', color: Colors.green);

    } else if (tab == 1) {
      // ── Tab 1: By Category - only selected/green columns ──
      final activeCols = _activeColKeys;
      if (activeCols.isEmpty) {
        _snack('No selected data to export.', color: Colors.orange[800]);
        return;
      }
      final data = _categorySales;
      if (data.isEmpty) {
        _snack('No selected data to export.', color: Colors.orange[800]);
        return;
      }
      final calDays = _getTotalCalendarDays();
      final headers = ['Category', ...activeCols];
      final rows = data.map((c) => [
        c.name,
        ...activeCols.map((col) => _catColValue(col, c, calDays)),
      ]).toList();
      ExportHelper.exportPdf(
        title: 'Sales Analytics - By Category',
        subtitle: '${data.length} categories  |  Filter: $_dateFilter  |  Columns: ${activeCols.join(", ")}',
        headers: headers,
        rows: rows,
        fileName: 'SalesAnalytics_ByCategory_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      _snack('✅ PDF exported (By Category - ${activeCols.length} columns)!', color: Colors.green);

    } else {
      // ── Tab 2: Trends - only selected/green columns ──
      final activeCols = _activeColKeys;
      if (activeCols.isEmpty) {
        _snack('No selected data to export.', color: Colors.orange[800]);
        return;
      }
      final trendRows = _buildTrendRows();
      if (trendRows.isEmpty) {
        _snack('No selected data to export.', color: Colors.orange[800]);
        return;
      }
      final headers = ['Period', ...activeCols];
      final rows = trendRows.map((r) => [
        r.label,
        ...activeCols.map((col) => _trendColValue(col, r)),
      ]).toList();
      ExportHelper.exportPdf(
        title: 'Sales Analytics - Trends ($_trendView)',
        subtitle: '${trendRows.length} periods  |  Filter: $_dateFilter  |  Columns: ${activeCols.join(", ")}',
        headers: headers,
        rows: rows,
        fileName: 'SalesAnalytics_Trends_${_trendView}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      _snack('✅ PDF exported (Trends $_trendView - ${activeCols.length} columns)!', color: Colors.green);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Scaffold
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart, color: Colors.green),
            tooltip: 'Export Excel',
            onPressed: _exportExcel,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
          ),
        ],
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'By Item'),
            Tab(
                icon: Icon(Icons.category, size: 18),
                text: 'By Category'),
            Tab(
                icon: Icon(Icons.trending_up, size: 18),
                text: 'Trends'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Date filter bar ──────────────────────────────────
          Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            child: Row(children: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  setState(() => _dateFilter = v);
                  if (v == 'Custom') _pickDateRange();
                },
                itemBuilder: (context) => _dateFilters.map((f) {
                  final sel = _dateFilter == f;
                  return PopupMenuItem<String>(
                    value: f,
                    child: Row(children: [
                      if (sel)
                        Icon(Icons.check,
                            size: 16, color: Colors.teal[700]),
                      if (sel) const SizedBox(width: 8),
                      Text(f,
                          style: TextStyle(
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: sel
                                  ? Colors.teal[700]
                                  : Colors.black87)),
                    ]),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.teal[300]!),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.teal[700]),
                    const SizedBox(width: 6),
                    Text(_dateFilter,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal[700])),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down,
                        size: 18, color: Colors.teal[700]),
                  ]),
                ),
              ),
            ]),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildByItem(),
                _buildByCategory(),
                _buildTrends(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1 - By Item
  // ─────────────────────────────────────────────────────────────

  Widget _buildByItem() {
    final items = _itemSales;
    final totalSales =
        items.fold(0.0, (s, i) => s + i.totalSales);
    final totalUnits =
        items.fold(0, (s, i) => s + i.totalUnits);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(children: [
          _miniCard('Items', '${items.length}', Colors.teal),
          const SizedBox(width: 6),
          _miniCard('Units', '$totalUnits', Colors.blue),
          const SizedBox(width: 6),
          _miniCard(
              'Sales', totalSales.toStringAsFixed(0), Colors.green),
        ]),
      ),
      Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search item...',
                  prefixIcon:
                      const Icon(Icons.search, size: 18),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          })
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                isDense: true,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black87),
                items: ['Sales', 'Units', 'Name']
                    .map((s) => DropdownMenuItem(
                        value: s, child: Text('Sort: $s')))
                    .toList(),
                onChanged: (v) => setState(() => _sortBy = v!),
              ),
            ),
          ),
        ]),
      ),
      Expanded(
        child: items.isEmpty
            ? const Center(
                child: Text('No data',
                    style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final rank = i + 1;
                  final rankColor = rank == 1
                      ? Colors.amber[700]!
                      : rank == 2
                          ? Colors.grey[500]!
                          : rank == 3
                              ? Colors.brown[400]!
                              : Colors.teal;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: rankColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text('$rank',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: rankColor)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(item.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              Text(
                                  '${item.sku}  |  ${item.category}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500])),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                item.totalSales.toStringAsFixed(2),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.teal[700])),
                            Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inventory_2,
                                      size: 10,
                                      color: Colors.grey[500]),
                                  Text(' ${item.totalUnits}',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600])),
                                  const SizedBox(width: 8),
                                  Icon(Icons.receipt,
                                      size: 10,
                                      color: Colors.grey[500]),
                                  Text(' ${item.txnCount}',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600])),
                                ]),
                          ],
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2 - By Category
  // ─────────────────────────────────────────────────────────────

  Widget _buildByCategory() {
    final cats = _categorySales;
    final totalSales =
        cats.fold(0.0, (s, c) => s + c.totalSales);
    final totalUnits =
        cats.fold(0, (s, c) => s + c.totalUnits);
    final totalTxn =
        cats.fold(0, (s, c) => s + c.txnCount);
    final totalItems =
        cats.fold(0, (s, c) => s + c.itemCount);
    final calDays = _getTotalCalendarDays();

    const allCols = [
      'Days','TXN','ADS','Gross','Net','Disc','Margin','Profit','Units','ATC','ATV','IPB',
    ];
    final visCols =
        allCols.where((c) => _visibleCols.contains(c)).toList();
    const double labelW = 120.0, colW = 72.0;

    List<String> catVals(_CategorySales c) {
      final n = c.totalSales;
      final atv = c.txnCount > 0 ? n / c.txnCount : 0.0;
      final ipb =
          c.txnCount > 0 ? c.totalUnits / c.txnCount : 0.0;
      return [
        '$calDays',
        '${c.txnCount}',
        (n / calDays).toStringAsFixed(2),
        n.toStringAsFixed(2),
        n.toStringAsFixed(2),
        '0.00',
        '${n > 0 ? "30.0" : "0.0"}%',
        (n * 0.3).toStringAsFixed(2),
        '${c.totalUnits}',
        (c.txnCount / calDays).toStringAsFixed(1),
        atv.toStringAsFixed(2),
        ipb.toStringAsFixed(1),
      ];
    }

    List<String> totVals() {
      final atv =
          totalTxn > 0 ? totalSales / totalTxn : 0.0;
      final ipb =
          totalTxn > 0 ? totalUnits / totalTxn : 0.0;
      return [
        '$calDays',
        '$totalTxn',
        (totalSales / calDays).toStringAsFixed(2),
        totalSales.toStringAsFixed(2),
        totalSales.toStringAsFixed(2),
        '0.00',
        '${totalSales > 0 ? "30.0" : "0.0"}%',
        (totalSales * 0.3).toStringAsFixed(2),
        '$totalUnits',
        (totalTxn / calDays).toStringAsFixed(1),
        atv.toStringAsFixed(2),
        ipb.toStringAsFixed(1),
      ];
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(children: [
          _miniCard(
              'Categories', '${cats.length}', Colors.purple),
          const SizedBox(width: 6),
          _miniCard('Items', '$totalItems', Colors.blue),
          const SizedBox(width: 6),
          _miniCard('Total',
              totalSales.toStringAsFixed(0), Colors.green),
        ]),
      ),
      _buildColToggles(allCols.toList()),
      Flexible(
        child: LayoutBuilder(builder: (context, constraints) {
          final contentW =
              (labelW + visCols.length * colW)
                  .clamp(constraints.maxWidth, double.infinity);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentW,
              height: constraints.maxHeight,
              child: Column(children: [
                // header
                Container(
                  height: 36,
                  color: Colors.teal[50],
                  child: Row(children: [
                    SizedBox(
                      width: labelW,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text('Category',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal[800])),
                      ),
                    ),
                    ...visCols.map((c) => SizedBox(
                          width: colW,
                          child: Center(
                              child: Text(c,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal[800]))),
                        )),
                  ]),
                ),
                // rows
                Expanded(
                  child: ListView.builder(
                    itemCount: cats.length + 1,
                    itemBuilder: (ctx, i) {
                      // total footer
                      if (i == cats.length) {
                        final tv = totVals();
                        return Container(
                          height: 40,
                          color: Colors.teal[50],
                          child: Row(children: [
                            SizedBox(
                              width: labelW,
                              child: const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Text('TOTAL',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight:
                                            FontWeight.bold)),
                              ),
                            ),
                            ...visCols.map((c) {
                              final ci =
                                  allCols.indexOf(c);
                              return SizedBox(
                                width: colW,
                                child: Center(
                                    child: Text(tv[ci],
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight.bold,
                                            color:
                                                _colColor(c)))),
                              );
                            }),
                          ]),
                        );
                      }

                      final cat = cats[i];
                      final cv = catVals(cat);
                      final pct = totalSales > 0
                          ? (cat.totalSales / totalSales * 100)
                          : 0.0;

                      return Column(children: [
                        InkWell(
                          onTap: () => setState(
                              () => cat.expanded = !cat.expanded),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color:
                                            Colors.grey[200]!))),
                            child: Row(children: [
                              SizedBox(
                                width: labelW,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(left: 4),
                                  child: Row(children: [
                                    Icon(cat.icon,
                                        size: 14,
                                        color: cat.color),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(cat.name,
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight
                                                          .w600),
                                              overflow: TextOverflow
                                                  .ellipsis),
                                          Text(
                                              '${pct.toStringAsFixed(1)}% | ${cat.itemCount} items',
                                              style: TextStyle(
                                                  fontSize: 8,
                                                  color: Colors
                                                      .grey[500])),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                        cat.expanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        size: 16,
                                        color: Colors.grey),
                                  ]),
                                ),
                              ),
                              ...visCols.map((c) {
                                final ci = allCols.indexOf(c);
                                return SizedBox(
                                  width: colW,
                                  child: Center(
                                      child: Text(cv[ci],
                                          style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  _colColor(c)))),
                                );
                              }),
                            ]),
                          ),
                        ),
                        if (cat.expanded)
                          ...cat.items.map((item) {
                            final n = item.totalSales;
                            final atv = item.txnCount > 0
                                ? n / item.txnCount
                                : 0.0;
                            final ipb = item.txnCount > 0
                                ? item.totalUnits / item.txnCount
                                : 0.0;
                            final iv = [
                              '$calDays',
                              item.txnCount,
                              (n / calDays).toStringAsFixed(2),
                              n.toStringAsFixed(2),
                              n.toStringAsFixed(2),
                              '0.00',
                              '${n > 0 ? "30.0" : "0.0"}%',
                              (n * 0.3).toStringAsFixed(2),
                              item.totalUnits,
                              (item.txnCount / calDays)
                                  .toStringAsFixed(1),
                              atv.toStringAsFixed(2),
                              ipb.toStringAsFixed(1),
                            ];
                            return Container(
                              height: 36,
                              color: Colors.grey[50],
                              decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color:
                                              Colors.grey[100]!))),
                              child: Row(children: [
                                SizedBox(
                                  width: labelW,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        left: 24),
                                    child: Text(item.name,
                                        style: const TextStyle(
                                            fontSize: 9),
                                        overflow:
                                            TextOverflow.ellipsis),
                                  ),
                                ),
                                ...visCols.map((c) {
                                  final ci = allCols.indexOf(c);
                                  return SizedBox(
                                    width: colW,
                                    child: Center(
                                        child: Text('${iv[ci]}',
                                            style: TextStyle(
                                                fontSize: 9,
                                                color:
                                                    _colColor(c)))),
                                  );
                                }),
                              ]),
                            );
                          }),
                      ]);
                    },
                  ),
                ),
              ]),
            ),
          );
        }),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 3 - Trends
  //
  // ADS = Gross Sales  ÷  active days (days with ≥1 transaction)
  // ATC = Transactions ÷  active days
  // ─────────────────────────────────────────────────────────────

  Widget _buildTrends() {
    final List<_TrendRow> rows = _buildTrendRows();

    final tNet   = rows.fold(0.0, (s, r) => s + r.sales);
    final tTxn   = rows.fold(0,   (s, r) => s + r.txnCount);
    final tUnits = rows.fold(0,   (s, r) => s + r.units);
    final tDisc  = _discountSum;
    final tGross = tNet + tDisc;
    final profit = tNet * 0.30;
    final margin = tNet > 0 ? 30.0 : 0.0;

    final int totalActiveDays =
        rows.fold(0, (s, r) => s + r.days).clamp(1, 999999);

    final totalAds = tNet / totalActiveDays;
    final totalAtc = tTxn / totalActiveDays;
    final totAtv   = tTxn > 0 ? tNet / tTxn : 0.0;
    final totIpb   = tTxn > 0 ? tUnits / tTxn : 0.0;

    const allCols = [
      'Days','TXN','ADS','Gross','Net','Disc','Margin','Profit','Units','ATC','ATV','IPB',
    ];
    final visCols =
        allCols.where((c) => _visibleCols.contains(c)).toList();
    const double labelW = 100.0, colW = 72.0;

    final totalRowStr = [
      '$totalActiveDays',
      '$tTxn',
      totalAds.toStringAsFixed(2),
      tGross.toStringAsFixed(2),
      tNet.toStringAsFixed(2),
      tDisc.toStringAsFixed(2),
      '${margin.toStringAsFixed(1)}%',
      profit.toStringAsFixed(2),
      '$tUnits',
      totalAtc.toStringAsFixed(1),
      totAtv.toStringAsFixed(2),
      totIpb.toStringAsFixed(1),
    ];

    Widget buildRow(
      List<String> vals,
      String label, {
      bool isHeader = false,
      bool isTotal = false,
    }) {
      final style = TextStyle(
        fontSize: isHeader ? 10 : 11,
        fontWeight:
            (isHeader || isTotal) ? FontWeight.bold : FontWeight.normal,
        color: isHeader ? Colors.teal[800] : null,
      );
      return Container(
        height: 40,
        color: (isHeader || isTotal) ? Colors.teal[50] : null,
        decoration: (!isHeader && !isTotal)
            ? BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!)))
            : null,
        child: Row(children: [
          SizedBox(
            width: labelW,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(label,
                  style: style.copyWith(
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ),
          ...visCols.map((c) {
            final ci = allCols.indexOf(c);
            return SizedBox(
              width: colW,
              child: Center(
                child: Text(
                  isHeader ? c : vals[ci],
                  style: style.copyWith(
                      color: isHeader ? Colors.teal[800] : _colColor(c)),
                ),
              ),
            );
          }),
        ]),
      );
    }

    return Column(children: [
      // ── Daily / Weekly / Monthly toggle ───────────────────
      Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: ['Daily', 'Weekly', 'Monthly'].map((v) {
            final sel = _trendView == v;
            return Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => setState(() => _trendView = v),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? Colors.teal[700]
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: sel
                              ? Colors.teal[700]!
                              : Colors.grey[300]!),
                    ),
                    child: Center(
                      child: Text(v,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: sel
                                  ? Colors.white
                                  : Colors.grey[600])),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      _buildColToggles(allCols.toList()),
      const SizedBox(height: 6),
      Flexible(
        child: LayoutBuilder(builder: (context, constraints) {
          final contentW =
              (labelW + visCols.length * colW)
                  .clamp(constraints.maxWidth, double.infinity);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentW,
              height: constraints.maxHeight,
              child: Column(children: [
                // header
                buildRow(
                  [],
                  _trendView == 'Monthly'
                      ? 'Month'
                      : _trendView == 'Weekly'
                          ? 'Week'
                          : 'Date',
                  isHeader: true,
                ),
                // data rows + total footer
                Expanded(
                  child: ListView.builder(
                    itemCount: rows.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == rows.length) {
                        return buildRow(totalRowStr, 'TOTAL',
                            isTotal: true);
                      }
                      return buildRow(
                          rows[i].toStringList(), rows[i].label);
                    },
                  ),
                ),
              ]),
            ),
          );
        }),
      ),
      // ── Summary chips ──────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border:
              Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _sumChipFixed(
                'ADS', totalAds.toStringAsFixed(0), Colors.indigo),
            const SizedBox(width: 4),
            _sumChipFixed(
                'ATC', totalAtc.toStringAsFixed(1), Colors.cyan),
            const SizedBox(width: 4),
            _sumChipFixed(
                'Days', '$totalActiveDays', Colors.teal),
            const SizedBox(width: 4),
            _sumChipFixed(
                'Profit', profit.toStringAsFixed(0), Colors.blue),
            const SizedBox(width: 4),
            _sumChipFixed(
                'Margin', '${margin.toStringAsFixed(1)}%', Colors.purple),
          ]),
        ),
      ),
    ]);
  }
}
