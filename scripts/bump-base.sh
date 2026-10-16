#!/usr/bin/env bash
# Moves the Containerfile's Kinoite pin to the newest dated build of the same
# Fedora release, and prints the new tag. Prints nothing and changes nothing
# when the pin is already the newest. A new Fedora release is never taken here:
# that stays a deliberate commit.
#
#   scripts/bump-base.sh
#
# publish-image.yml runs it weekly and commits the result (brief 22, U1).
set -euo pipefail
cd "$(dirname "$0")/.."

repo=quay.io/fedora-ostree-desktops/kinoite
pin="$(sed -n "s|^FROM $repo:\([0-9]*\.[0-9]\{8\}\.[0-9]*\)\$|\1|p" Containerfile)"
[ "$(wc -l <<<"$pin")" -eq 1 ] && [ -n "$pin" ] \
  || { echo "bump-base: expected one 'FROM $repo:<release>.<date>.<n>' line in the Containerfile" >&2; exit 1; }
release="${pin%%.*}"

# Quay's API lists the newest tags first; a dated build carries the multi-arch
# tag and one per architecture, and only the multi-arch one is wanted.
newest="$(curl -fsS --proto '=https' \
  "https://quay.io/api/v1/repository/${repo#quay.io/}/tag/?limit=100&onlyActiveTags=true&filter_tag_name=like:$release." \
  | python3 -I -c '
import json, re, sys
release = sys.argv[1]
tags = [t["name"] for t in json.load(sys.stdin)["tags"]
        if re.fullmatch(re.escape(release) + r"\.\d{8}\.\d+", t["name"])]
if not tags:
    sys.exit(1)
print(max(tags, key=lambda t: [int(p) for p in t.split(".")]))
' "$release")" || { echo "bump-base: no $release.<date>.<n> tag found on $repo" >&2; exit 1; }

key() { tr . ' ' <<<"$1" | awk '{ printf "%s%08d%04d", $1, $2, $3 }'; }
[[ "$(key "$newest")" > "$(key "$pin")" ]] || exit 0

sed -i "s|^FROM $repo:$pin\$|FROM $repo:$newest|" Containerfile
grep -qx "FROM $repo:$newest" Containerfile
echo "$newest"
