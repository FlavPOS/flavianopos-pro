import os
for root,dirs,files in os.walk('lib'):
  for fn in files:
    if fn.endswith('.dart'):
      p = os.path.join(root,fn)
      t = open(p).read()
      if '&gt;' in t or '&lt;' in t or '&amp;' in t:
        t = t.replace('&gt;','>').replace('&lt;','<').replace('&amp;','&')
        open(p,'w').write(t)
        print('Fixed:',p)
print('All done!')
