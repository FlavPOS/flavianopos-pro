f = 'lib/screens/reports/sales_analytics_screen.dart'
t = open(f).read()

# Fix: Jan 1 2026 is Thursday, so firstMon goes back to Dec 29 2025
# That makes week calc off by 1. Just use Jan 1 as base instead.
t = t.replace(
    "final firstMon = jan1.subtract(Duration(days: (jan1.weekday - 1) % 7));",
    "final firstMon = jan1;"
)

# Also fix in lbl function
t = t.replace(
    "final fmw = jan1w.subtract(Duration(days: (jan1w.weekday - 1) % 7));",
    "final fmw = jan1w;"
)

open(f, 'w').write(t)
print('Done! Week 1 starts from Jan 1.')
