f = 'lib/screens/reports/sales_analytics_screen.dart'
t = open(f).read()

new_getters = """
  double get _discountSum => _filtered.fold(0.0, (s, t) => s + t.totalDiscount);
  double get _costEstimate => _filtered.fold(0.0, (s, t) => s + t.total) * 0.70;
"""

if '_discountSum' not in t:
    t = t.replace('  void _snack(', new_getters + '  void _snack(')

old_s = '  Widget _buildTrends() {'
old_e = '  Widget _miniCard('
i1 = t.index(old_s)
i2 = t.index(old_e)

new_method = """  Widget _buildTrends() {
    final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    List<_DaySales> data;
    if (_trendView == 'Monthly') { data = _monthlySales; }
    else if (_trendView == 'Weekly') { data = _weeklySales; }
    else { data = _dailySales; }

    final totalSales = data.fold(0.0, (s, d) => s + d.sales);
    final totalTxn = data.fold(0, (s, d) => s + d.txnCount);
    final totalUnits = data.fold(0, (s, d) => s + d.units);
    final days = data.length > 0 ? data.length : 1;
    final discount = _discountSum;
    final netSales = totalSales - discount;
    final cost = _costEstimate;
    final profit = totalSales - cost;
    final margin = totalSales > 0 ? (profit / totalSales * 100) : 0;
    final atv = totalTxn > 0 ? totalSales / totalTxn : 0;
    final ads = totalSales / days;
    final atc = totalTxn / days;
    final ipb = totalTxn > 0 ? totalUnits / totalTxn : 0;

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

      Expanded(child: SingleChildScrollView(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Column(children: [
          Row(children: [
            _kpi('Gross Sales', 'P\${totalSales.toStringAsFixed(2)}', Icons.point_of_sale, Colors.teal),
            const SizedBox(width: 8),
            _kpi('Net Sales', 'P\${netSales.toStringAsFixed(2)}', Icons.monetization_on, Colors.green),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _kpi('Discount', 'P\${discount.toStringAsFixed(2)}', Icons.discount, Colors.red),
            const SizedBox(width: 8),
            _kpi('Profit', 'P\${profit.toStringAsFixed(2)}', Icons.trending_up, Colors.blue),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _kpi('Margin', '\${margin.toStringAsFixed(1)}%', Icons.pie_chart, Colors.purple),
            const SizedBox(width: 8),
            _kpi('ATV', 'P\${atv.toStringAsFixed(2)}', Icons.shopping_cart, Colors.orange),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _kpi('ADS', 'P\${ads.toStringAsFixed(2)}', Icons.calendar_today, Colors.indigo),
            const SizedBox(width: 8),
            _kpi('ATC', '\${atc.toStringAsFixed(1)}', Icons.receipt_long, Colors.cyan),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _kpi('IPB', '\${ipb.toStringAsFixed(1)}', Icons.inventory_2, Colors.brown),
            const SizedBox(width: 8),
            _kpi('Transactions', '\$totalTxn', Icons.swap_horiz, Colors.pink),
          ]),
        ])),
        const SizedBox(height: 12),

        Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Expanded(flex: 3, child: Text(
                  _trendView == 'Monthly' ? 'Month' : _trendView == 'Weekly' ? 'Week' : 'Date',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal[800]))),
              Expanded(flex: 2, child: Text('TXN', style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.bold, color: Colors.teal[800]), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('Units', style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.bold, color: Colors.teal[800]), textAlign: TextAlign.center)),
              Expanded(flex: 3, child: Text('Sales', style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.bold, color: Colors.teal[800]), textAlign: TextAlign.right)),
            ]))),

        ...List.generate(data.length + 1, (i) {
          if (i == data.length) {
            return Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Expanded(flex: 3, child: Text('TOTAL',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('\$totalTxn',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('\$totalUnits',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 3, child: Text('P\${totalSales.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal[700]),
                      textAlign: TextAlign.right)),
                ])));
          }
          final d = data[i];
          String label;
          String sublabel;
          if (_trendView == 'Monthly') {
            label = months[d.date.month];
            sublabel = '\${d.date.year}';
          } else if (_trendView == 'Weekly') {
            final end = d.date.add(const Duration(days: 6));
            label = '\${d.date.month}/\${d.date.day} - \${end.month}/\${end.day}';
            sublabel = 'Week';
          } else {
            final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            label = '\${d.date.month}/\${d.date.day}';
            sublabel = weekdays[d.date.weekday - 1];
          }
          return Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
              child: Row(children: [
                Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  Text(sublabel, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ])),
                Expanded(flex: 2, child: Text('\${d.txnCount}',
                    style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('\${d.units}',
                    style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                Expanded(flex: 3, child: Text('P\${d.sales.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal[700]),
                    textAlign: TextAlign.right)),
              ])));
        }),
        const SizedBox(height: 16),
      ]))),
    ]);
  }

  Widget _kpi(String label, String value, IconData icon, Color color) =>
    Expanded(child: Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(40))),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        ])),
      ])));

"""

t = t[:i1] + new_method + t[i2:]
open(f, 'w').write(t)
print('Done! KPIs added to Trends tab.')
