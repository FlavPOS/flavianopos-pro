f = 'lib/screens/reports/sales_analytics_screen.dart'
t = open(f).read()

# Add ADS, ATC, Profit, Margin columns to DataTable
# 1. Add 4 new column headers after IPB
t = t.replace(
    "const DataColumn(label: Text('IPB'), numeric: true),",
    """const DataColumn(label: Text('IPB'), numeric: true),
            const DataColumn(label: Text('ADS'), numeric: true),
            const DataColumn(label: Text('ATC'), numeric: true),
            const DataColumn(label: Text('Profit'), numeric: true),
            const DataColumn(label: Text('Margin'), numeric: true),"""
)

# 2. Add 4 new cells in each data row after IPB cell
t = t.replace(
    "DataCell(Text('${dIpb.toStringAsFixed(1)}')),\n              ]);",
    """DataCell(Text('${dIpb.toStringAsFixed(1)}')),
                DataCell(Text('P${dNet.toStringAsFixed(2)}')),
                DataCell(Text(d.txnCount > 0 ? '${(d.txnCount / 1).toStringAsFixed(1)}' : '-')),
                DataCell(Text('P${(dNet * 0.30).toStringAsFixed(2)}', style: const TextStyle(color: Colors.blue))),
                DataCell(Text('30.0%', style: const TextStyle(color: Colors.purple))),
              ]);"""
)

# 3. Fix the data row ADS and ATC to be per-row values
# ADS per row = net sales for that row (same as net since it's 1 day/week/month)
# ATC per row = txn count for that row
# Actually ADS = sales/1 day = sales, ATC = txn/1 = txn for daily
# For the row level these are just the row values

# 4. Add 4 new cells in TOTAL row after IPB
old_total_ipb = """DataCell(Text(totalTxn > 0 ? '${(totalUnits / totalTxn).toStringAsFixed(1)}' : '-',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
              ]),"""

new_total_ipb = """DataCell(Text(totalTxn > 0 ? '${(totalUnits / totalTxn).toStringAsFixed(1)}' : '-',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text('P${ads.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text('${atc.toStringAsFixed(1)}',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text('P${profit.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                DataCell(Text('${margin.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))),
              ]),"""

t = t.replace(old_total_ipb, new_total_ipb)

open(f, 'w').write(t)
print('Done! Added ADS, ATC, Profit, Margin to table.')
