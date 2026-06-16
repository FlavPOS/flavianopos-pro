f = 'lib/screens/reports/sales_analytics_screen.dart'
t = open(f).read()

def find_method(t, sig):
    s = t.index(sig)
    brace = 0
    started = False
    for i in range(s, len(t)):
        if t[i] == '{':
            brace += 1
            started = True
        elif t[i] == '}':
            brace -= 1
        if started and brace == 0:
            return s, i+1
    return s, len(t)

# Replace _dailySales
s1, e1 = find_method(t, 'List<_DaySales> get _dailySales {')
nd = """  List<_DaySales> get _dailySales {
    final now = DateTime.now();
    final map = <String, _DaySales>{};
    if (_dateFilter == 'All') {
      final jan1 = DateTime(now.year, 1, 1);
      var d = jan1;
      while (!d.isAfter(now)) {
        final key = '${d.year}-${d.month}-${d.day}';
        map[key] = _DaySales(date: d);
        d = d.add(const Duration(days: 1));
      }
    }
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
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }"""
t = t[:s1] + nd + t[e1:]

# Replace _monthlySales
s2, e2 = find_method(t, 'List<_DaySales> get _monthlySales {')
nm = """  List<_DaySales> get _monthlySales {
    final now = DateTime.now();
    final map = <int, _DaySales>{};
    if (_dateFilter == 'All') {
      for (int m = 1; m <= 12; m++) {
        map[m] = _DaySales(date: DateTime(now.year, m, 1));
      }
    }
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
  }"""
t = t[:s2] + nm + t[e2:]

# Replace _weeklySales
s3, e3 = find_method(t, 'List<_DaySales> get _weeklySales {')
nw = """  List<_DaySales> get _weeklySales {
    final now = DateTime.now();
    final jan1 = DateTime(now.year, 1, 1);
    final map = <int, _DaySales>{};
    if (_dateFilter == 'All') {
      for (int w = 1; w <= 52; w++) {
        final wkStart = jan1.add(Duration(days: (w - 1) * 7));
        map[w] = _DaySales(date: wkStart);
      }
    }
    for (final t in _filtered) {
      if (t.dateTime.year != now.year) continue;
      final diff = t.dateTime.difference(jan1).inDays;
      final wk = (diff ~/ 7) + 1;
      final key = wk.clamp(1, 52);
      if (!map.containsKey(key)) {
        final wkStart = jan1.add(Duration(days: (key - 1) * 7));
        map[key] = _DaySales(date: wkStart);
      }
      map[key] = _DaySales(date: map[key]!.date,
        txnCount: map[key]!.txnCount + 1, units: map[key]!.units + t.totalQty,
        sales: map[key]!.sales + t.total);
    }
    var list = map.entries.toList();
    list.sort((a, b) => a.key.compareTo(b.key));
    return list.map((e) => e.value).toList();
  }"""
t = t[:s3] + nw + t[e3:]

open(f, 'w').write(t)
print('Done! Date filters now work in Trends.')
