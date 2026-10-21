#!/usr/bin/env python3
"""Generate the Mauvely light/dark KDE colour schemes from the design-system tokens."""
import sys, os

OUT = sys.argv[1]

def rgb(h):
    h = h.lstrip('#')
    return ','.join(str(int(h[i:i+2], 16)) for i in (0, 2, 4))

# Design-system tokens (website-main/project/_ds/.../tokens/colors.css)
T = {
 'violet-100':'#f0eefe','violet-200':'#e7e5fe','violet-300':'#d2cefd','violet-400':'#b5abfc',
 'violet-500':'#968ae0','violet-600':'#796cbf','violet-700':'#5d5294','violet-800':'#423a6a',
 'violet-900':'#2b2741','violet-950':'#1a1728',
 'mauve-300':'#cbb0d1','mauve-400':'#ac89b6','mauve-500':'#886193',
 'teal-400':'#17c6bb','teal-600':'#0d938b','teal-700':'#0f736d',
 'slate-50':'#f8f9fd','slate-100':'#f3f5fe','slate-200':'#e4e7f5','slate-300':'#cfd3e5',
 'slate-400':'#b2b6ca','slate-500':'#9397ab','slate-600':'#75798c','slate-700':'#595d6c',
 'slate-800':'#3f424d','slate-900':'#292b31','slate-950':'#161826',
 'danger-500':'#d94f6f','danger-600':'#b93c59','warning-500':'#e8a33d','warning-600':'#c9852a',
 'indigo-950':'#12142e',
 # semantic
 'light-app-ground':'#e8e5f9','light-chrome-panel':'#f5f3ff','white':'#ffffff',
 'dark-app-ground':'#12142e','dark-chrome-panel':'#1b1a33','dark-app-panel':'#1b1d2b',
 'dark-app-panel-alt':'#1f2131','dark-surface-card':'#232532','dark-surface-raised':'#2b2d3c',
 'dark-text-strong':'#e9e9ed',
}

def group(bg, alt, fg):
    return dict(BackgroundNormal=bg, BackgroundAlternate=alt, **fg)

def schemes():
    L_fg = dict(ForegroundNormal='slate-900', ForegroundInactive='slate-600', ForegroundActive='violet-600',
                ForegroundLink='violet-600', ForegroundVisited='mauve-500', ForegroundNegative='danger-600',
                ForegroundNeutral='warning-600', ForegroundPositive='teal-700',
                DecorationFocus='violet-500', DecorationHover='violet-500')
    L_sel = dict(ForegroundNormal='white', ForegroundInactive='violet-200', ForegroundActive='white',
                 ForegroundLink='violet-100', ForegroundVisited='mauve-300', ForegroundNegative='white',
                 ForegroundNeutral='white', ForegroundPositive='white',
                 DecorationFocus='violet-500', DecorationHover='violet-500')
    D_fg = dict(ForegroundNormal='dark-text-strong', ForegroundInactive='slate-500', ForegroundActive='violet-400',
                ForegroundLink='violet-400', ForegroundVisited='mauve-400', ForegroundNegative='danger-500',
                ForegroundNeutral='warning-500', ForegroundPositive='teal-400',
                DecorationFocus='violet-500', DecorationHover='violet-500')
    D_sel = dict(ForegroundNormal='violet-950', ForegroundInactive='violet-900', ForegroundActive='violet-950',
                 ForegroundLink='violet-950', ForegroundVisited='violet-900', ForegroundNegative='violet-950',
                 ForegroundNeutral='violet-950', ForegroundPositive='violet-950',
                 DecorationFocus='violet-500', DecorationHover='violet-500')
    light = {
        'Colors:Window':            group('light-chrome-panel', 'light-app-ground', L_fg),
        'Colors:View':              group('white', 'slate-50', L_fg),
        'Colors:Button':            group('white', 'violet-200', L_fg),
        'Colors:Selection':         group('violet-600', 'violet-300', L_sel),
        'Colors:Tooltip':           group('white', 'slate-100', L_fg),
        'Colors:Header':            group('light-app-ground', 'light-chrome-panel', L_fg),
        'Colors:Header][Inactive':  group('light-chrome-panel', 'light-app-ground', L_fg),
        'Colors:Complementary':     group('dark-app-panel', 'dark-app-ground', D_fg),
    }
    light_wm = dict(activeBackground='light-app-ground', activeBlend='light-app-ground', activeForeground='slate-900',
                    inactiveBackground='light-chrome-panel', inactiveBlend='light-chrome-panel', inactiveForeground='slate-600')
    dark = {
        'Colors:Window':            group('dark-chrome-panel', 'dark-surface-card', D_fg),
        'Colors:View':              group('dark-app-panel', 'dark-app-panel-alt', D_fg),
        'Colors:Button':            group('dark-surface-card', 'violet-800', D_fg),
        'Colors:Selection':         group('violet-500', 'violet-700', D_sel),
        'Colors:Tooltip':           group('dark-surface-card', 'dark-app-panel', D_fg),
        'Colors:Header':            group('dark-app-ground', 'dark-chrome-panel', D_fg),
        'Colors:Header][Inactive':  group('dark-app-panel', 'dark-app-ground', D_fg),
        'Colors:Complementary':     group('dark-app-ground', 'dark-app-panel', D_fg),
    }
    dark_wm = dict(activeBackground='dark-app-ground', activeBlend='dark-app-ground', activeForeground='dark-text-strong',
                   inactiveBackground='dark-app-panel', inactiveBlend='dark-app-panel', inactiveForeground='slate-500')
    return [('MauvelyLight', 'Mauvely light', light, light_wm), ('MauvelyDark', 'Mauvely dark', dark, dark_wm)]

HEADER = """# Mauvely colour scheme, generated from the Mauvely design-system tokens
# (website-main/project/_ds/.../tokens/colors.css). Structure follows Breeze.
# SPDX-License-Identifier: LGPL-2.0-or-later
"""

for sid, name, groups, wm in schemes():
    out = [HEADER]
    out.append("""[ColorEffects:Disabled]
Color=56,56,56
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=112,111,110
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0
""")
    for g in sorted(groups):
        out.append(f"[{g}]")
        for k in sorted(groups[g]):
            out.append(f"{k}={rgb(T[groups[g][k]])}")
        out.append("")
    out.append(f"[General]\nColorScheme={sid}\nName={name}\nshadeSortColumn=true\n")
    out.append("[KDE]\ncontrast=4\n")
    out.append("[WM]")
    for k in sorted(wm):
        out.append(f"{k}={rgb(T[wm[k]])}")
    out.append("")
    with open(os.path.join(OUT, sid + '.colors'), 'w') as f:
        f.write('\n'.join(out))
    print('wrote', sid)
