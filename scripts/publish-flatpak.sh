#!/usr/bin/env bash
# Adds each app's published Flatpak to the Mauvely remote's repo, signed.
#
#   REPO=<dir> WORK=<dir> GPG_KEY=<fingerprint> GNUPGHOME=<dir> \
#     scripts/publish-flatpak.sh [app-key ...]          default: compose sotto
#
# For each app key the script
#   1. reads the release feed and takes the newest `flatpak` item for linux-x86_64,
#   2. downloads it and checks its sha256 against the feed,
#   3. imports it into a scratch repo, which says what its ref is, and refuses
#      any app id but com.mauvely.<key> (ids moved from net.mauvely.*.app in
#      plan 20, and older bundles are still in the feed),
#   4. re-brands that ref to $BRANCH with `flatpak build-commit-from`, which
#      rewrites the ref binding inside the commit and signs it. Importing with
#      --ref=.../stable instead publishes, and then fails on install,
# and finally runs `flatpak build-update-repo`, which signs the summary,
# generates the summary index and the static deltas, and prunes.
#
# $REPO is the whole repo, as synced down from R2. It is created if it is empty
# (a first publish) and never recreated: a fresh repo would drop every older
# commit from the summary. Running it twice on the same feed changes nothing.
# Rings are branches: BRANCH=next would put the same bundle on `next`.
set -euo pipefail

feed="${FEED:-https://mauvely.com/api/releases}"
branch="${BRANCH:-stable}"
platform="${PLATFORM:-linux-x86_64}"
arch="${platform#linux-}"
repo="${REPO:?REPO: the repo directory}"
work="${WORK:?WORK: a scratch directory}"
key="${GPG_KEY:?GPG_KEY: the signing key fingerprint}"
gnupghome="${GNUPGHOME:?GNUPGHOME: the keyring holding that key}"
apps=("$@")
[ ${#apps[@]} -gt 0 ] || apps=(compose sotto)

for tool in curl python3 sha256sum flatpak ostree gpg; do
  command -v "$tool" >/dev/null || { echo "publish-flatpak: $tool is required" >&2; exit 1; }
done

mkdir -p "$work/dl" "$repo"
[ -f "$repo/config" ] || ostree init --repo="$repo" --mode=archive-z2
# R2 holds files, not directories, so a repo synced down from it is missing the
# empty ones (refs/remotes and the rest), and ostree refuses to open it.
mkdir -p "$repo"/{tmp,state,extensions,objects,deltas,refs/heads,refs/remotes,refs/mirrors}

for app in "${apps[@]}"; do
  [[ "$app" =~ ^[a-z0-9-]+$ ]] || { echo "publish-flatpak: bad app key '$app'" >&2; exit 1; }
  echo "== $app"

  # 1. The newest Flatpak for this platform. One line: url, sha256, version, filename.
  item="$(curl -fsS --proto '=https' "$feed?app=$app" | python3 -I -c '
import json, sys
platform = sys.argv[1]
items = [i for i in json.load(sys.stdin)["items"]
         if i["format"] == "flatpak" and i["platform"] == platform]
if not items:
    sys.exit(1)
i = max(items, key=lambda i: i["publishedAt"])
print(i["url"], i["sha256"], i["version"], i["filename"])
' "$platform")" || { echo "publish-flatpak: $app has no $platform Flatpak in the feed" >&2; exit 1; }
  read -r url sha version filename <<<"$item"
  [[ "$filename" =~ ^[A-Za-z0-9._-]+\.flatpak$ ]] || { echo "publish-flatpak: odd file name '$filename'" >&2; exit 1; }
  [[ "$sha" =~ ^[0-9a-f]{64}$ ]] || { echo "publish-flatpak: odd sha256 '$sha'" >&2; exit 1; }

  # 2. Download, and check against the feed.
  bundle="$work/dl/$filename"
  curl -fsSL --proto '=https' -o "$bundle" "$url"
  echo "$sha  $bundle" | sha256sum -c - || { rm -f "$bundle"; exit 1; }

  # 3. Import into a scratch repo; the bundle names its own ref.
  rm -rf "$work/import"
  ostree init --repo="$work/import" --mode=archive-z2
  out="$(flatpak build-import-bundle --no-update-summary "$work/import" "$bundle" 2>&1)"
  echo "$out"
  ref="$(sed -n 's|^Importing \(app/[^ ]*\) .*|\1|p' <<<"$out")"
  [ "$(wc -l <<<"$ref")" -eq 1 ] && [[ "$ref" =~ ^app/[A-Za-z0-9._-]+/$arch/[A-Za-z0-9._-]+$ ]] \
    || { echo "publish-flatpak: expected one app/…/$arch/… ref in $filename, got: '$ref'" >&2; exit 1; }
  id="${ref#app/}"; id="${id%%/*}"
  # The feed still holds bundles from before plan 20 (Compose 0.5.3 is
  # net.mauvely.compose.app), and one of those here is an app no device is
  # ever assigned, signed for good.
  [ "$id" = "com.mauvely.$app" ] \
    || { echo "publish-flatpak: $filename is $id, not com.mauvely.$app; release a newer $app first" >&2; exit 1; }

  # 4. Re-brand to $branch, into the real repo, signed. "no change" is not an error.
  flatpak build-commit-from --src-repo="$work/import" --src-ref="$ref" \
    --no-update-summary --gpg-sign="$key" --gpg-homedir="$gnupghome" \
    --subject="$id $version" --body="bundle-sha256: $sha" \
    "$repo" "app/$id/$arch/$branch"
done

# Refs from before plan 20. The first publish, on 2026-10-14, put Compose 0.5.3
# in as net.mauvely.compose.app before the check above existed, and nothing
# else ever removes a ref. publish-flatpak.yml deletes its file in R2 too.
for old in $(ostree --repo="$repo" refs | grep '^app/net\.mauvely\.' || true); do
  ostree --repo="$repo" refs --delete "$old"
  echo "removed $old, from before plan 20"
done

flatpak build-update-repo --gpg-sign="$key" --gpg-homedir="$gnupghome" \
  --default-branch="$branch" --generate-static-deltas --prune "$repo"

echo "== refs in $repo"
ostree --repo="$repo" refs
