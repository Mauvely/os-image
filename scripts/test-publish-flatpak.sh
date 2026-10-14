#!/usr/bin/env bash
# Tries scripts/publish-flatpak.sh end to end on this machine, with a throwaway
# key, then reads the repo back the way a device would: a Flatpak client with its
# own user directory, so the machine's own Flatpak setup is never touched.
# Nothing here reaches R2, and nothing is installed (that would pull 2 GB of
# runtimes).
#
#   scripts/test-publish-flatpak.sh [app-key ...]       default: compose sotto
#
# Everything lives under $TEST_DIR (default ~/.cache/mauvely-os/publish-test).
set -euo pipefail
cd "$(dirname "$0")/.."

dir="${TEST_DIR:-$HOME/.cache/mauvely-os/publish-test}"
apps=("$@"); [ ${#apps[@]} -gt 0 ] || apps=(compose sotto)
rm -rf "$dir"; mkdir -p "$dir/gnupg"; chmod 700 "$dir/gnupg"

export GNUPGHOME="$dir/gnupg"
gpg --batch --quiet --pinentry-mode loopback --passphrase '' \
  --quick-gen-key 'Mauvely OS throwaway <throwaway@mauvely.invalid>' ed25519 sign never
key="$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr:/{print $10; exit}')"
gpg --export "$key" > "$dir/throwaway-public.gpg"
echo "throwaway key: $key"

echo "== publish, twice (the second run must change nothing)"
REPO="$dir/repo" WORK="$dir/work" GPG_KEY="$key" scripts/publish-flatpak.sh "${apps[@]}"
REPO="$dir/repo" WORK="$dir/work" GPG_KEY="$key" scripts/publish-flatpak.sh "${apps[@]}" | grep -c 'no change' \
  | xargs -I{} echo "second run: {} refs reported 'no change'"

echo "== a ref from before plan 20 is removed, as Compose 0.5.3's was from the live remote"
old="app/net.mauvely.${apps[0]}.app/x86_64/stable"
ostree --repo="$dir/repo" refs --create="$old" \
  "$(ostree --repo="$dir/repo" rev-parse "app/com.mauvely.${apps[0]}/x86_64/stable")"
REPO="$dir/repo" WORK="$dir/work" GPG_KEY="$key" scripts/publish-flatpak.sh "${apps[@]}" | grep "^removed $old"
! ostree --repo="$dir/repo" refs | grep -q '^app/net\.' || { echo "FAIL: $old is still in the repo" >&2; exit 1; }

echo "== publish once more onto a copy holding only files, which is what a repo synced down from R2 is"
mkdir -p "$dir/r2repo"
(cd "$dir/repo" && find . -type f -not -path './tmp/*' -not -path './state/*' -not -name .lock -print0 \
  | tar --null -T - -cf -) | tar -C "$dir/r2repo" -xf -
REPO="$dir/r2repo" WORK="$dir/work" GPG_KEY="$key" scripts/publish-flatpak.sh "${apps[@]}" | tail -6

echo "== read it back as a client"
export FLATPAK_USER_DIR="$dir/fp" XDG_DATA_HOME="$dir/xdg-data" XDG_CACHE_HOME="$dir/xdg-cache" XDG_CONFIG_HOME="$dir/xdg-config"
mkdir -p "$FLATPAK_USER_DIR" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
flatpak --user remote-add --gpg-import="$dir/throwaway-public.gpg" test "file://$dir/repo"
flatpak --user remote-ls test --columns=application,branch
for ref in $(ostree --repo="$dir/repo" refs | grep '^app/'); do
  IFS=/ read -r _ id _ branch <<<"$ref"
  flatpak --user remote-info test "$id//$branch" | sed -n '1,4p;/Commit:/,/Subject:/p'
done

echo "== a client holding the committed public key must refuse it (it is the wrong key)"
if flatpak --user remote-add wrong --gpg-import=keys/mauvely-flatpak.gpg "file://$dir/repo" 2>"$dir/wrong.err" \
   && flatpak --user remote-ls wrong >/dev/null 2>>"$dir/wrong.err"; then
  echo "FAIL: the committed key accepted a repo signed by a throwaway key" >&2; exit 1
fi
echo "refused, as it should: $(grep -m1 "Can't check signature" "$dir/wrong.err")"
