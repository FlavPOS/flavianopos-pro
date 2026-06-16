f = 'lib/screens/reports/sales_analytics_screen.dart'
t = open(f).read()

s = '  Widget _buildTrends() {'
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
    final visCols = allCols.where((c) => _visibleCols.contains(c)).toList();

    String lbl(_DaySales d) {
      if (_trendView == 'Monthly') return '\${mo[d.date.month]} \${d.date.year}';
      if (_trendView == 'Weekly') {
        final e = d.date.add(const Duration(days: 6));
        return '\${d.date.month}/\${d.date.day}-\${e.month}/\${e.day}';
      }
      final wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return '\${d.date.month}/\${d.date.day} \${wd[d.date.weekday-1]}';
    }

    List<String> rowVals(_DaySales d) {
      final n = d.sales;
      final a = d.txnCount > 0 ? n / d.txnCount : 0.0;
      final ip = d.txnCount > 0 ? d.units / d.txnCount : 0.0;
      return ['\${d.txnCount}','\${d.units}','P\${n.toStringAsFixed(2)}',
        'P0.00','P\${n.toStringAsFixed(2)}','P\${a.toStringAsFixed(2)}',
        '\${ip.toStringAsFixed(1)}','P\${n.toStringAsFixed(2)}',
        '\${d.txnCount.toDouble().toStringAsFixed(1)}',
        'P\${(n*0.3).toStringAsFixed(2)}','\${n>0?"30.0":"0.0"}%'];
    }

    List<String> totVals() {
      final a2 = tTxn > 0 ? tNet / tTxn : 0.0;
      final ip2 = tTxn > 0 ? tUnits / tTxn : 0.0;
      return ['\$tTxn','\$tUnits','P\${tNet.toStringAsFixed(2)}',
        'P\${tDisc.toStringAsFixed(2)}','P\${tGross.toStringAsFixed(2)}',
        'P\${a2.toStringAsFixed(2)}','\${ip2.toStringAsFixed(1)}',
        'P\${ads.toStringAsFixed(2)}','\${atc.toStringAsFixed(1)}',
        'P\${profit.toStringAsFixed(2)}','\${margin.toStringAsFixed(1)}%'];
    }

    Color? colColor(String c) {
      if (c == 'Net') return Colors.teal[700];
      if (c == 'Disc') return Colors.red;
      if (c == 'Profit') return Colors.blue;
      if (c == 'Margin') return Colors.purple;
      return null;
    }

    Widget buildRow(List<String> vals, String label, {bool isHeader = false, bool isTotal = false}) {
      final style = TextStyle(fontSize: isHeader ? 10 : 11,
        fontWeight: (isHeader || isTotal) ? FontWeight.bold : FontWeight.normal,
        color: isHeader ? Colors.teal[800] : null);
      return Container(
        height: 40,
        color: (isHeader || isTotal) ? Colors.teal[50] : null,
        decoration: (!isHeader && !isTotal) ? BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[200]!))) : null,
        child: Row(children: [
          Expanded(flex: 2, child: Padding(padding: const EdgeInsets.only(left: 8),
            child: Text(label, style: style.copyWith(fontWeight: FontWeight.w600)))),
          ...visCols.map((c) {
            final ci = allCols.indexOf(c);
            return Expanded(flex: 2, child: Center(child: Text(
              isHeader ? c : vals[ci],
              style: style.copyWith(color: isHeader ? Colors.teal[800] : colColor(c)),
            )));
          }),
        ]),
      );
    }

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
            onTap: () => setState(() { if (on) { _visibleCols.remove(c); } else { _visibleCols.add(c); } }),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: on ? Colors.teal[700] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(6)),
              child: Text(c, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                  color: on ? Colors.white : Colors.grey[600]))));
        }).toList())),
      const SizedBox(height: 6),

      buildRow([], _trendView == 'Monthly' ? 'Month' : _trendView == 'Weekly' ? 'Week' : 'Date', isHeader: true),

      Expanded(child: ListView.builder(
        itemCount: data.length + 1,
        itemBuilder: (ctx, i) {
          if (i == data.length) return buildRow(totVals(), 'TOTAL', isTotal: true);
          return buildRow(rowVals(data[i]), lbl(data[i]));
        },
      )),

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

"""

t = t[:i1] + new_code + t[i2:]
open(f, 'w').write(t)
print('Done! Full-width table.')
