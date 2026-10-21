#!/usr/bin/env python3
"""Mauvely wallpaper: flat bands of the violet ramp rising from the centred taskbar.
No gradients, no new hues (design system: flat colour fields, one ramp)."""
import sys
out = sys.argv[1]
W, H = 3840, 2160
variants = {
  # ground, then rings from outermost to innermost
  'light': ('#f5f3ff', ['#f0eefe', '#e7e5fe', '#d2cefd', '#b5abfc', '#968ae0']),
  'dark':  ('#12142e', ['#1a1728', '#2b2741', '#423a6a', '#5d5294', '#796cbf']),
}
for name, (ground, rings) in variants.items():
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
             f'<rect width="{W}" height="{H}" fill="{ground}"/>']
    n = len(rings)
    for i, c in enumerate(rings):
        t = i / (n - 1)
        r = 2600 - t * 1900          # outer 2600px .. inner 700px
        cx = W * 0.5 + (1 - t) * 1100 # centres drift right as the rings grow: a crescent swell, not a target
        cy = H + 420 - t * 260
        parts.append(f'<circle cx="{cx:.0f}" cy="{cy:.0f}" r="{r:.0f}" fill="{c}"/>')
    parts.append('</svg>')
    with open(f'{out}/mauvely-{name}.svg', 'w') as f:
        f.write('\n'.join(parts))
    print('wrote', name)
