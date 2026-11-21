import os, glob
root = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(root, 'src')
js = '\n'.join(open(f, encoding='utf-8').read() for f in sorted(glob.glob(os.path.join(src, '[0-9]*.js'))))
js = '(function(){\n"use strict";\n' + js + '\n})();'
css = open(os.path.join(src, 'style.css'), encoding='utf-8').read()
tpl = open(os.path.join(src, 'index.template.html'), encoding='utf-8').read()
js = js.replace('</script', '<\\/script')
out = tpl.replace('/*__CSS__*/', css).replace('/*__JS__*/', js)
os.makedirs(os.path.join(root, '.'), exist_ok=True)
p = os.path.join(root, '.', 'index.html')
open(p, 'w', encoding='utf-8').write(out)
print(p, len(out))
