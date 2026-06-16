f = 'lib/screens/reports/sales_analytics_screen.dart'
t = open(f).read()

cs = t.index('  Widget _buildByCategory() {')
brace = 0
started = False
for i in range(cs, len(t)):
    if t[i] == '{':
        brace += 1
        started = True
    elif t[i] == '}':
        brace -= 1
        if started and brace == 0:
            ce = i + 1
            break

new_code = open('new_cat_method.dart').read()
t = t[:cs] + new_code + t[ce:]
open(f, 'w').write(t)
print('Done! By Category with column toggles.')
