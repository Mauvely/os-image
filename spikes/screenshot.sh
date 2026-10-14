#!/usr/bin/env bash
# screenshot.sh <out.png>   QMP screendump of the running VM, as a small PNG.
set -euo pipefail
. "$(dirname "$0")/env.sh"
ppm="$W/shot.ppm"
python3 "$(dirname "$0")/qmp.py" "$M/qmp.sock" screendump "{\"filename\":\"$ppm\"}" >/dev/null
magick "$ppm" -strip -define png:compression-level=9 "$1"
rm -f "$ppm"
