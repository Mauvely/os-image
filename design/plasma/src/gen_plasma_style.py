#!/usr/bin/env python3
"""Make the Mauvely Plasma style's translucent SVGs from Breeze's: same shapes,
a lighter fill so KWin's blur shows through (acrylic). usage: gen_plasma_style.py <breeze-default-dir> <out-dir> <opacity>"""
import gzip, sys, os, re
src, out, op = sys.argv[1], sys.argv[2], sys.argv[3]
for rel in ('translucent/dialogs/background.svgz', 'translucent/widgets/panel-background.svgz', 'translucent/widgets/tooltip.svgz'):
    data = gzip.open(os.path.join(src, rel)).read().decode()
    new, n = re.subn(r'opacity:0\.85', f'opacity:{op}', data)
    os.makedirs(os.path.dirname(os.path.join(out, rel)), exist_ok=True)
    with gzip.open(os.path.join(out, rel), 'wb') as f:
        f.write(new.encode())
    print(rel, n, 'fills ->', op)
