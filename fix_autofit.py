f = 'lib/screens/reports/sales_analytics_screen.dart'
t = open(f).read()

# Replace fixed width SizedBox with flexible layout
# Change the scrollable columns section to use Expanded instead of fixed width

# Fix: When columns fit screen, expand to fill. When too many, scroll.
t = t.replace(
    "child: SizedBox(width: visCols.length * 72.0, child: Column(children: [",
    "child: ConstrainedBox(constraints: BoxConstraints(minWidth: visCols.length * 72.0), child: IntrinsicWidth(child: Column(children: ["
)

t = t.replace(
    "child: Row(children: visCols.map((c) => SizedBox(width: 72,",
    "child: Row(children: visCols.map((c) => Expanded("
)

# Fix header cell - remove width, use Center
t = t.replace(
    "child: Center(child: Text(c, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,\n                    color: Colors.teal[800]))))).toList())),",
    "child: Center(child: Text(c, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,\n                    color: Colors.teal[800]))))).toList())),"
)

# Fix data cells - use Expanded instead of SizedBox
t = t.replace(
    "return SizedBox(width: 72, child: Center(child: Text(v[ci],",
    "return Expanded(child: Center(child: Text(v[ci],"
)

# Close the extra bracket from ConstrainedBox+IntrinsicWidth
t = t.replace(
    "            ])))),",
    "            ]))))),",
    1  # only first occurrence in the scrollable section
)

open(f, 'w').write(t)
print('Done! Table now auto-fits screen.')
