#!/usr/bin/env bash
# S3: builds a signed OSTree (Flatpak) repo from the published Compose bundle and
# serves it on 127.0.0.1:8098. A throwaway ed25519 key signs it; the real key
# (fingerprint in CLAUDE.md) exists only in the Actions secret.
set -euo pipefail
. "$(dirname "$0")/env.sh"
export GNUPGHOME="$W/spike-gpg"; mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME"
DL="$W/flatpak-dl"; REPO="${REPO:-$W/flatpak-repo}"; mkdir -p "$DL"
APP="${1:-compose}"; VER="${2:-0.5.3}"
FILE="Mauvely$(tr '[:lower:]' '[:upper:]' <<<"${APP:0:1}")${APP:1}-$VER-linux-x86_64.flatpak"

# 1. the bundle and its checksum, both from the release feed
meta="$(curl -fsS "https://mauvely.com/api/releases?app=$APP" | python3 -c "
import json,sys
for i in json.load(sys.stdin)['items']:
    if i['format']=='flatpak' and i['version']=='$VER': print(i['url'], i['sha256'])")"
read -r url sha <<<"$meta"
[ -f "$DL/$FILE" ] || curl -fsSL -o "$DL/$FILE" "$url"
echo "$sha  $DL/$FILE" | sha256sum -c -

# 2. a throwaway signing key
if ! gpg --list-secret-keys spike@mauvely.invalid >/dev/null 2>&1; then
  gpg --batch --pinentry-mode loopback --passphrase '' --quick-gen-key 'Mauvely OS spike <spike@mauvely.invalid>' ed25519 sign never
fi
KEY="$(gpg --list-secret-keys --with-colons spike@mauvely.invalid | awk -F: '/^fpr/{print $10; exit}')"
gpg --export "$KEY" > "$W/spike-gpg/spike-public.gpg"        # binary, what --gpg-import takes
echo "key: $KEY"

# 3. the repo: archive mode, as Flatpak remotes need
rm -rf "$REPO"
ostree init --repo="$REPO" --mode=archive-z2
# BRANCH overrides the branch the bundle was built on (Compose 0.5.3 ships master).
if [ -n "${BRANCH:-}" ]; then
  id="$(flatpak build-import-bundle --no-update-summary "$REPO" "$DL/$FILE" 2>&1 | sed -n 's|^Importing app/\([^/]*\)/.*|\1|p')"
  rm -rf "$REPO"; ostree init --repo="$REPO" --mode=archive-z2
  flatpak build-import-bundle --no-update-summary --ref="app/$id/x86_64/$BRANCH" "$REPO" "$DL/$FILE"
else
  flatpak build-import-bundle --no-update-summary "$REPO" "$DL/$FILE"
fi
ostree --repo="$REPO" refs
for ref in $(ostree --repo="$REPO" refs | grep '^app/'); do
  IFS=/ read -r _ id arch branch <<<"$ref"
  flatpak build-sign --gpg-sign="$KEY" --gpg-homedir="$GNUPGHOME" "$REPO" "$id" "$branch"
done
flatpak build-update-repo --gpg-sign="$KEY" --gpg-homedir="$GNUPGHOME" \
  --generate-static-deltas --prune "$REPO"
ls -la "$REPO"
