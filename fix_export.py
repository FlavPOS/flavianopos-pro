f = 'lib/screens/reports/sales_analytics_screen.dart'
t = open(f).read()

# 1. Add imports
imp = "import 'package:flutter/material.dart';"
new_imp = imp + "\nimport 'dart:io';\nimport 'package:path_provider/path_provider.dart';\nimport 'package:share_plus/share_plus.dart';"
if 'dart:io' not in t:
    t = t.replace(imp, new_imp)

# 2. Add _exportCSV method
export_method = """  Future<void> _exportCSV() async {
    final buf = StringBuffer();
    final tab = _tabCtrl.index;
    if (tab == 0) {
      buf.writeln('Name,SKU,Category,Units,Sales,Transactions');
      for (final item in _itemSales) {
        buf.writeln('\${item.name},\${item.sku},\${item.category},\${item.totalUnits},\${item.totalSales.toStringAsFixed(2)},\${item.txnCount}');
      }
    } else if (tab == 1) {
      buf.writeln('Category,Items,Units,Sales,Transactions');
      for (final cat in _categorySales) {
        buf.writeln('\${cat.name},\${cat.itemCount},\${cat.totalUnits},\${cat.totalSales.toStringAsFixed(2)},\${cat.txnCount}');
      }
    } else {
      final mo = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      List<_DaySales> data;
      if (_trendView == 'Monthly') { data = _monthlySales; }
      else if (_trendView == 'Weekly') { data = _weeklySales; }
      else { data = _dailySales; }
      buf.writeln('Period,TXN,Units,Net Sales,Discount,Gross,ATV,IPB,Profit,Margin');
      for (final d in data) {
        String label;
        if (_trendView == 'Monthly') {
          label = '\${mo[d.date.month]} \${d.date.year}';
        } else if (_trendView == 'Weekly') {
          final jan1w = DateTime(d.date.year, 1, 1);
          final wk = (d.date.difference(jan1w).inDays ~/ 7) + 1;
          label = 'Wk \$wk';
        } else {
          label = '\${d.date.month}/\${d.date.day}/\${d.date.year}';
        }
        final n = d.sales;
        final atv = d.txnCount > 0 ? n / d.txnCount : 0.0;
        final ipb = d.txnCount > 0 ? d.units / d.txnCount : 0.0;
        buf.writeln('\$label,\${d.txnCount},\${d.units},\${n.toStringAsFixed(2)},0.00,\${n.toStringAsFixed(2)},\${atv.toStringAsFixed(2)},\${ipb.toStringAsFixed(1)},\${(n*0.3).toStringAsFixed(2)},\${n>0?"30.0":"0.0"}%');
      }
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final tabNames = ['by_item', 'by_category', 'trends'];
      final fileName = 'sales_\${tabNames[tab]}_\${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('\${dir.path}/\$fileName');
      await file.writeAsString(buf.toString());
      await Share.shareXFiles([XFile(file.path)], subject: 'Sales Report CSV');
    } catch (e) {
      if (mounted) _snack('Error: \$e');
    }
  }

"""

if '_exportCSV' not in t:
    t = t.replace('  void _snack(', export_method + '  void _snack(')

# 3. Replace bottom bar - single CSV button
sa_start = t.index('child: SafeArea(child:')
depth = 0
sa_end = sa_start
for i in range(sa_start, len(t)):
    if t[i] == '(':
        depth += 1
    elif t[i] == ')':
        depth -= 1
        if depth == 0:
            sa_end = i + 1
            break

if sa_end < len(t) and t[sa_end] == ',':
    sa_end += 1

new_bottom = """        child: SafeArea(child: SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _exportCSV,
            icon: const Icon(Icons.table_chart, size: 18),
            label: const Text('Export CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),"""

t = t[:sa_start] + new_bottom + t[sa_end:]

open(f, 'w').write(t)
print('Done! Export CSV button ready.')
