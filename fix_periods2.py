f = 'lib/screens/reports/sales_analytics_screen.dart'
t = open(f).read()

ds = t.index('List<_DaySales> get _dailySales {')
brace = 0
started = False
for i in range(ds, len(t)):
    if t[i] == '{':
        brace += 1
        started = True
    elif t[i] == '}':
        brace -= 1
        if started and brace == 0:
            de = i + 1
            break

nd = """  List<_DaySales> get _dailySales {
    final now = DateTime.now();
    final jan1 = DateTime(now.year, 1, 1);
    final map = <String, _DaySales>{};
    var d = jan1;
    while (!d.isAfter(now)) {
      final key = '${d.year}-${d.month}-${d.day}';
      map[key] = _DaySales(date: d);
      d = d.add(const Duration(days: 1));
    }
    for (final t in _filtered) {
      if (t.dateTime.year != now.year) continue;
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
  }"""

t = t[:ds] + nd + t[de:]

ws = t.index('List<_DaySales> get _weeklySales {')
brace = 0
started = False
for i in range(ws, len(t)):
    if t[i] == '{':
        brace += 1
        started = True
    elif t[i] == '}':
        brace -= 1
        if started and brace == 0:
            we = i + 1
            break

nw = """  List<_DaySales> get _weeklySales {
    final now = DateTime.now();
    final jan1 = DateTime(now.year, 1, 1);
    final firstMon = jan1.subtract(Duration(days: (jan1.weekday - 1) % 7));
    final map = <int, _DaySales>{};
    for (int w = 1; w <= 52; w++) {
      final wkStart = firstMon.add(Duration(days: (w - 1) * 7));
      map[w] = _DaySales(date: wkStart);
    }
    for (final t in _filtered) {
      if (t.dateTime.year != now.year) continue;
      final diff = t.dateTime.difference(firstMon).inDays;
      final wk = (diff ~/ 7) + 1;
      final key = wk.clamp(1, 52);
      if (map.containsKey(key)) {
        map[key] = _DaySales(date: map[key]!.date,
          txnCount: map[key]!.txnCount + 1, units: map[key]!.units + t.totalQty,
          sales: map[key]!.sales + t.total);
      }
    }
    var list = map.entries.toList();
    list.sort((a, b) => a.key.compareTo(b.key));
    return list.map((e) => e.value).toList();
  }"""

t = t[:ws] + nw + t[we:]

old_lbl = "if (_trendView == 'Weekly') {\n        return 'Wk ${d.date.day}';"
new_lbl = "if (_trendView == 'Weekly') {\n        final jan1w = DateTime(d.date.year, 1, 1);\n        final fmw = jan1w.subtract(Duration(days: (jan1w.weekday - 1) % 7));\n        final wk = (d.date.difference(fmw).inDays ~/ 7) + 1;\n        return 'Wk $wk';"
t = t.replace(old_lbl, new_lbl)

open(f, 'w').write(t)
print('Done! Daily=Jan1-today, Weekly=Wk1-52 unique.')
