#!/usr/bin/env bash
# The Plasma preset's colour scheme: Breeze Light with the Mauvely accent (violet-500,
# #968ae0), exactly as Plasma tints it when a person picks that accent. Plasma's own
# plasma-apply-colorscheme does the tinting, in the base image, with a scratch HOME;
# its [Colors:*] groups then replace Breeze Light's.
#
#   design/plasma/src/gen_plasma_colors.sh [base image] > rootfs/usr/share/color-schemes/MauvelyPlasma.colors
set -euo pipefail
cd "$(dirname "$0")/../../.."
base="${1:-$(sed -n 's|^FROM \(quay.io/fedora-ostree-desktops/kinoite:[^ ]*\) AS kinoite$|\1|p' Containerfile)}"
podman run --rm -e HOME=/tmp/h -e XDG_CONFIG_HOME=/tmp/h/.config -e QT_QPA_PLATFORM=offscreen "$base" bash -c '
  mkdir -p "$XDG_CONFIG_HOME"
  plasma-apply-colorscheme --accent-color "#968ae0" BreezeLight >/dev/null 2>&1
  cat /usr/share/color-schemes/BreezeLight.colors
  echo "@@kdeglobals@@"
  cat "$XDG_CONFIG_HOME/kdeglobals"' | python3 -I -c '
import sys
scheme, tinted = sys.stdin.read().split("@@kdeglobals@@\n")
def groups(text):
    out, name = {}, None
    for line in text.splitlines():
        if line.startswith("["):
            name = line
            out[name] = []
        elif name is not None:
            out[name].append(line)
    return out
tinted = groups(tinted)
order, base = [], groups(scheme)
assert all(g in tinted for g in base if g.startswith("[Colors:")), "tinting left a group out"
print("# Breeze Light with the Mauvely accent (violet-500, #968ae0), tinted by Plasma 6 itself:")
print("# design/plasma/src/gen_plasma_colors.sh in os-image.")
print("# SPDX-License-Identifier: LGPL-2.0-or-later")
for name, lines in base.items():
    if name.startswith("[Colors:"):
        lines = [l for l in tinted[name] if l] + [""]
    elif name == "[General]":
        lines = ["ColorScheme=MauvelyPlasma", "Name=Plasma", "shadeSortColumn=true", ""]
    print(name)
    print("\n".join(lines))
'
