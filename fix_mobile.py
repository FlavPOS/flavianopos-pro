f = 'lib/screens/reports/sales_analytics_screen.dart'
t = open(f).read()

if '_visibleCols' not in t:
    t = t.replace(
        "String _trendView = 'Daily';",
        "String _trendView = 'Daily';\n  final Set<String> _visibleCols = {'TXN','Units','Net','Gross','ATV','IPB'};"
    )

s = '  Widget _buildTrends() {'
e = '  Widget _miniCard('
if e not in t:
    e = '  Widget _sumChip('
i1 = t.index(s)
i2 = t.index(e)

new_code = """  Widget _buildTrends() {
    final mo = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    List<_DaySales> data;
    if (_trendView == 'Monthly') { data = _monthlySales; }
    else if (_trendView == 'Weekly') { data = _weeklySales; }
    else { data = _dailySales; }

    final tNet = data.fold(0.0, (s, d) => s + d.sales);
    final tTxn = data.fold(0, (s, d) => s + d.txnCount);
    final tUnits = data.fold(0, (s, d) => s + d.units);
    final tDisc = _discountSum;
    final tGross = tNet + tDisc;
    final days = data.isNotEmpty ? data.length : 1;
    final profit = tNet * 0.30;
    final margin = tNet > 0 ? 30.0 : 0.0;
    final ads = tNet / days;
    final atc = tTxn / days;
    final allCols = ['TXN','Units','Net','Disc','Gross','ATV','IPB','ADS','ATC','Profit','Margin'];

    String lbl(_DaySales d) {
      if (_trendView == 'Monthly') return '\${mo[d.date.month]} \${d.date.year}';
      if (_trendView == 'Weekly') {
        final e = d.date.add(const Duration(days: 6));
        return '\${d.date.month}/\${d.date.day}-\${e.month}/\${e.day}';
      }
      final wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return '\${d.date.month}/\${d.date.day} \${wd[d.date.weekday-1]}';
    }

    List<String> vals(_DaySales d) {
      final n = d.sales;
      final di = 0.0;
      final g = n + di;
      final a = d.txnCount > 0 ? n / d.txnCount : 0.0;
      final ip = d.txnCount > 0 ? d.units / d.txnCount : 0.0;
      final pr = n * 0.30;
      final mr = n > 0 ? 30.0 : 0.0;
      return [
        '\${d.txnCount}','\${d.units}','P\${n.toStringAsFixed(2)}',
        'P\${di.toStringAsFixed(2)}','P\${g.toStringAsFixed(2)}',
        'P\${a.toStringAsFixed(2)}','\${ip.toStringAsFixed(1)}',
        'P\${n.toStringAsFixed(2)}','\${d.txnCount.toDouble().toStringAsFixed(1)}',
        'P\${pr.toStringAsFixed(2)}','\${mr.toStringAsFixed(1)}%',
      ];
    }

    List<String> totVals() {
      final a2 = tTxn > 0 ? tNet / tTxn : 0.0;
      final ip2 = tTxn > 0 ? tUnits / tTxn : 0.0;
      return [
        '\$tTxn','\$tUnits','P\${tNet.toStringAsFixed(2)}',
        'P\${tDisc.toStringAsFixed(2)}','P\${tGross.toStringAsFixed(2)}',
        'P\${a2.toStringAsFixed(2)}','\${ip2.toStringAsFixed(1)}',
        'P\${ads.toStringAsFixed(2)}','\${atc.toStringAsFixed(1)}',
        'P\${profit.toStringAsFixed(2)}','\${margin.toStringAsFixed(1)}%',
      ];
    }

    final visCols = allCols.where((c) => _visibleCols.contains(c)).toList();

    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: ['Daily','Weekly','Monthly'].map((v) {
          final sel = _trendView == v;
          return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(onTap: () => setState(() => _trendView = v),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(color: sel ? Colors.teal[700] : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? Colors.teal[700]! : Colors.grey[300]!)),
                child: Center(child: Text(v, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : Colors.grey[600])))))));
        }).toList())),

      Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Wrap(spacing: 4, runSpacing: 2, children: allCols.map((c) {
          final on = _visibleCols.contains(c);
          return GestureDetector(
            onTap: () => setState(() { if (on) _visibleCols.remove(c); else _visibleCols.add(c); }),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: on ? Colors.teal[700] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(6)),
              child: Text(c, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                  color: on ? Colors.white : Colors.grey[600]))));
        }).toList())),
      const SizedBox(height: 6),

      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 85, child: Column(children: [
          Container(height: 36, color: Colors.teal[50], alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 8),
            child: Text(_trendView == 'Monthly' ? 'Month' : _trendView == 'Weekly' ? 'Week' : 'Date',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal[800]))),
          Expanded(child: ListView.builder(itemCount: data.length + 1, itemBuilder: (ctx, i) {
            if (i == data.length) return Container(height: 40, color: Colors.teal[50],
              alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 8),
              child: const Text('TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)));
            return Container(height: 40, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
              child: Text(lbl(data[i]), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)));
          })),
        ])),
        Container(width: 1, color: Colors.grey[300]),
        Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: SizedBox(width: visCols.length * 72.0, child: Column(children: [
            Container(height: 36, color: Colors.teal[50],
              child: Row(children: visCols.map((c) => SizedBox(width: 72,
                child: Center(child: Text(c, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                    color: Colors.teal[800]))))).toList())),
            Expanded(child: ListView.builder(itemCount: data.length + 1, itemBuilder: (ctx, i) {
              final v = i == data.length ? totVals() : vals(data[i]);
              final isTot = i == data.length;
              return Container(height: 40, color: isTot ? Colors.teal[50] : null,
                decoration: isTot ? null : BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
                child: Row(children: visCols.map((c) {
                  final ci = allCols.indexOf(c);
                  Color? tc;
                  if (c == 'Net') tc = Colors.teal[700];
                  if (c == 'Disc') tc = Colors.red;
                  if (c == 'Profit') tc = Colors.blue;
                  if (c == 'Margin') tc = Colors.purple;
                  return SizedBox(width: 72, child: Center(child: Text(v[ci],
                      style: TextStyle(fontSize: 10, fontWeight: isTot ? FontWeight.bold : FontWeight.normal,
                          color: tc))));
                }).toList()));
            })),
          ])))),
      ])),

      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.grey[100],
            border: Border(top: BorderSide(color: Colors.grey[300]!))),
        child: Row(children: [
          _sumChip('ADS', 'P\${ads.toStringAsFixed(0)}', Colors.indigo),
          const SizedBox(width: 4),
          _sumChip('ATC', '\${atc.toStringAsFixed(1)}', Colors.cyan),
          const SizedBox(width: 4),
          _sumChip('Profit', 'P\${profit.toStringAsFixed(0)}', Colors.blue),
          const SizedBox(width: 4),
          _sumChip('Margin', '\${margin.toStringAsFixed(1)}%', Colors.purple),
        ])),
    ]);
  }

  Widget _sumChip(String label, String value, Color color) =>
    Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(40))),
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: color)),
        Text(label, style: TextStyle(fontSize: 7, color: Colors.grey[600])),
      ])));

"""

t = t[:i1] + new_code + t[i2:]
open(f, 'w').write(t)
print('Done! Mobile-friendly frozen-column table.')
