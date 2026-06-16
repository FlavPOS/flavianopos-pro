f = 'lib/screens/reports/sales_analytics_screen.dart'
t = open(f).read()

old_daily = '''  List<_DaySales> get _dailySales {
    final map = <String, _DaySales>{};
    for (final t in _filtered) {
      final key = '${t.dateTime.year}-${t.dateTime.month}-${t.dateTime.day}';
      if (!map.containsKey(key)) {
        map[key] = _DaySales(date: DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day));
      }
      map[key] = _DaySales(date: map[key]!.date,
        txnCount: map[key]!.txnCount + 1, units: map[key]!.units + t.totalQty,
        sales: map[key]!.sales + t.total);
    }
    var list = map.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }'''

new_daily = '''  List<_DaySales> get _dailySales {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final map = <String, _DaySales>{};
    for (int d = 1; d <= daysInMonth; d++) {
      final dt = DateTime(now.year, now.month, d);
      if (dt.isAfter(now)) break;
      final key = '${now.year}-${now.month}-$d';
      map[key] = _DaySales(date: dt);
    }
    for (final t in _filtered) {
      if (t.dateTime.month != now.month || t.dateTime.year != now.year) continue;
      final key = '${t.dateTime.year}-${t.dateTime.month}-${t.dateTime.day}';
      if (map.containsKey(key)) {
        map[key] = _DaySales(date: map[key]!.date,
          txnCount: map[key]!.txnCount + 1, units: map[key]!.units + t.totalQty,
          sales: map[key]!.sales + t.total);
      }
    }
    var list = map.values.toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }'''

old_monthly = '''  List<_DaySales> get _monthlySales {
    final map = <int, _DaySales>{};
    for (final t in _filtered) {
      final key = t.dateTime.month;
      if (!map.containsKey(key)) {
        map[key] = _DaySales(date: DateTime(t.dateTime.year, key, 1));
      }
      map[key] = _DaySales(date: map[key]!.date,
        txnCount: map[key]!.txnCount + 1, units: map[key]!.units + t.totalQty,
        sales: map[key]!.sales + t.total);
    }
    var list = map.values.toList();
    list.sort((a, b) => a.date.month.compareTo(b.date.month));
    return list;
  }'''

new_monthly = '''  List<_DaySales> get _monthlySales {
    final now = DateTime.now();
    final map = <int, _DaySales>{};
    for (int m = 1; m <= 12; m++) {
      map[m] = _DaySales(date: DateTime(now.year, m, 1));
    }
    for (final t in _filtered) {
      if (t.dateTime.year != now.year) continue;
      final key = t.dateTime.month;
      map[key] = _DaySales(date: map[key]!.date,
        txnCount: map[key]!.txnCount + 1, units: map[key]!.units + t.totalQty,
        sales: map[key]!.sales + t.total);
    }
    var list = map.values.toList();
    list.sort((a, b) => a.date.month.compareTo(b.date.month));
    return list;
  }'''

old_weekly = '''  List<_DaySales> get _weeklySales {
    final map = <String, _DaySales>{};
    for (final t in _filtered) {
      final weekStart = t.dateTime.subtract(Duration(days: t.dateTime.weekday - 1));
      final key = '${weekStart.year}-${weekStart.month}-${weekStart.day}';
      if (!map.containsKey(key)) {
        map[key] = _DaySales(date: DateTime(weekStart.year, weekStart.month, weekStart.day));
      }
      map[key] = _DaySales(date: map[key]!.date,
        txnCount: map[key]!.txnCount + 1, units: map[key]!.units + t.totalQty,
        sales: map[key]!.sales + t.total);
    }
    var list = map.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }'''

new_weekly = '''  List<_DaySales> get _weeklySales {
    final now = DateTime.now();
    final jan1 = DateTime(now.year, 1, 1);
    final map = <int, _DaySales>{};
    for (int w = 1; w <= 52; w++) {
      map[w] = _DaySales(date: DateTime(now.year, 1, w));
    }
    for (final t in _filtered) {
      if (t.dateTime.year != now.year) continue;
      final diff = t.dateTime.difference(jan1).inDays;
      final wk = (diff ~/ 7) + 1;
      final key = wk.clamp(1, 52);
      map[key] = _DaySales(date: map[key]!.date,
        txnCount: map[key]!.txnCount + 1, units: map[key]!.units + t.totalQty,
        sales: map[key]!.sales + t.total);
    }
    var list = map.values.toList();
    list.sort((a, b) => a.date.day.compareTo(b.date.day));
    return list;
  }'''

t = t.replace(old_daily, new_daily)
t = t.replace(old_monthly, new_monthly)
t = t.replace(old_weekly, new_weekly)

# Update weekly label
t = t.replace(
    "if (_trendView == 'Weekly') {\n        final e = d.date.add(const Duration(days: 6));\n        return '${d.date.month}/${d.date.day}-${e.month}/${e.day}';",
    "if (_trendView == 'Weekly') {\n        return 'Wk ${d.date.day}';"
)

open(f, 'w').write(t)
print('Done! All periods shown.')
