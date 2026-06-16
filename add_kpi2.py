f = 'lib/screens/reports/sales_analytics_screen.dart'
t = open(f).read()

old_s = '  Widget _buildTrends() {'
old_e = '  Widget _miniCard('
i1 = t.index(old_s)
i2 = t.index(old_e)

new_code = """  Widget _buildTrends() {
    final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    List<_DaySales> data;
    if (_trendView == 'Monthly') { data = _monthlySales; }
    else if (_trendView == 'Weekly') { data = _weeklySales; }
    else { data = _dailySales; }

    final totalNet = data.fold(0.0, (s, d) => s + d.sales);
    final totalTxn = data.fold(0, (s, d) => s + d.txnCount);
    final totalUnits = data.fold(0, (s, d) => s + d.units);
    final totalDisc = _discountSum;
    final totalGross = totalNet + totalDisc;
    final days = data.length > 0 ? data.length : 1;
    final cost = totalNet * 0.70;
    final profit = totalNet - cost;
    final margin = totalNet > 0 ? (profit / totalNet * 100) : 0;
    final ads = totalNet / days;
    final atc = totalTxn / days;

    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: ['Daily', 'Weekly', 'Monthly'].map((v) {
          final sel = _trendView == v;
          return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => setState(() => _trendView = v),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? Colors.teal[700] : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? Colors.teal[700]! : Colors.grey[300]!)),
                child: Center(child: Text(v,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : Colors.grey[600])))))));
        }).toList())),

      Expanded(child: SingleChildScrollView(child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          horizontalMargin: 12,
          headingRowHeight: 38,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 50,
          headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
          headingTextStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal[800]),
          dataTextStyle: const TextStyle(fontSize: 11),
          columns: [
            DataColumn(label: Text(_trendView == 'Monthly' ? 'Month' : _trendView == 'Weekly' ? 'Week' : 'Date')),
            const DataColumn(label: Text('TXN'), numeric: true),
            const DataColumn(label: Text('Units'), numeric: true),
            const DataColumn(label: Text('Net Sales'), numeric: true),
            const DataColumn(label: Text('Disc'), numeric: true),
            const DataColumn(label: Text('Gross'), numeric: true),
            const DataColumn(label: Text('ATV'), numeric: true),
            const DataColumn(label: Text('IPB'), numeric: true),
          ],
          rows: [
            ...data.map((d) {
              String label;
              if (_trendView == 'Monthly') {
                label = '\${months[d.date.month]} \${d.date.year}';
              } else if (_trendView == 'Weekly') {
                final end = d.date.add(const Duration(days: 6));
                label = '\${d.date.month}/\${d.date.day}-\${end.month}/\${end.day}';
              } else {
                final wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
                label = '\${d.date.month}/\${d.date.day} \${wd[d.date.weekday - 1]}';
              }
              final dNet = d.sales;
              final dDisc = 0.0;
              final dGross = dNet + dDisc;
              final dAtv = d.txnCount > 0 ? dNet / d.txnCount : 0.0;
              final dIpb = d.txnCount > 0 ? d.units / d.txnCount : 0.0;
              return DataRow(cells: [
                DataCell(Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
                DataCell(Text('\${d.txnCount}')),
                DataCell(Text('\${d.units}')),
                DataCell(Text('P\${dNet.toStringAsFixed(2)}', style: TextStyle(color: Colors.teal[700]))),
                DataCell(Text('P\${dDisc.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red))),
                DataCell(Text('P\${dGross.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w500))),
                DataCell(Text('P\${dAtv.toStringAsFixed(2)}')),
                DataCell(Text('\${dIpb.toStringAsFixed(1)}')),
              ]);
            }),
            DataRow(
              color: WidgetStateProperty.all(Colors.teal[50]),
              cells: [
                const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataCell(Text('\$totalTxn', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text('\$totalUnits', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text('P\${totalNet.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[700]))),
                DataCell(Text('P\${totalDisc.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                DataCell(Text('P\${totalGross.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(totalTxn > 0 ? 'P\${(totalNet / totalTxn).toStringAsFixed(2)}' : '-',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(totalTxn > 0 ? '\${(totalUnits / totalTxn).toStringAsFixed(1)}' : '-',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
              ]),
          ],
        )))),

      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.grey[100],
            border: Border(top: BorderSide(color: Colors.grey[300]!))),
        child: Row(children: [
          _sumChip('ADS', 'P\${ads.toStringAsFixed(2)}', Colors.indigo),
          const SizedBox(width: 6),
          _sumChip('ATC', '\${atc.toStringAsFixed(1)}', Colors.cyan),
          const SizedBox(width: 6),
          _sumChip('Profit', 'P\${profit.toStringAsFixed(2)}', Colors.blue),
          const SizedBox(width: 6),
          _sumChip('Margin', '\${margin.toStringAsFixed(1)}%', Colors.purple),
        ])),
    ]);
  }

  Widget _sumChip(String label, String value, Color color) =>
    Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(40))),
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color)),
        Text(label, style: TextStyle(fontSize: 8, color: Colors.grey[600])),
      ])));

"""

t = t[:i1] + new_code + t[i2:]
open(f, 'w').write(t)
print('Done! Table-style trends with KPIs.')
