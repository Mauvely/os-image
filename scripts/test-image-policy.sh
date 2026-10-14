#!/usr/bin/env bash
# Tries a built image's signature policy the way a device meets it, against a
# throwaway registry and throwaway cosign keys. A signed image must be accepted,
# an unsigned one or one signed with another key refused, and an image from any
# other repository left alone.
#
#   COSIGN=/path/to/cosign scripts/test-image-policy.sh [image]
#
# The image defaults to localhost/mauvely-os:dev, what scripts/build.sh makes.
# Needs podman and cosign v2 (see publish-image.yml for why not v3). Nothing
# leaves this machine: the registry is a container on 127.0.0.1, the keys are
# made here and deleted at the end, and nothing is sent to Rekor. The image's
# own key is covered by the throwaway one, so a build with the real key tests
# the same way.
set -euo pipefail

image="${1:-localhost/mauvely-os:dev}"
cosign="${COSIGN:-cosign}"
port="${PORT:-5055}"
reg="127.0.0.1:$port"
work="$(mktemp -d)"
registry=mauvely-policy-registry

cleanup() {
  podman rm -f "$registry" >/dev/null 2>&1 || true
  podman rmi -f localhost/mauvely-policy-test:{signed,unsigned,foreign,other} >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

"$cosign" version 2>&1 | grep -q 'GitVersion: *v2\.' || {
  echo "test-image-policy: needs cosign v2; set COSIGN." >&2
  exit 1
}

echo "== keys and registry"
(cd "$work" && for k in good foreign; do
  COSIGN_PASSWORD='' "$cosign" generate-key-pair --output-key-prefix "$k" >/dev/null 2>&1
done)
podman run -d --rm --name "$registry" --network host quay.io/fedora/fedora:44 \
  sh -c "dnf -yq install docker-distribution >/dev/null && REGISTRY_HTTP_ADDR=$reg exec registry serve /etc/docker-distribution/registry/config.yml" \
  >/dev/null
for _ in $(seq 120); do
  curl -sf "http://$reg/v2/" >/dev/null && break
  sleep 1
done
curl -sf "http://$reg/v2/" >/dev/null || { echo "test-image-policy: the registry did not start" >&2; exit 1; }

# Four images with four digests: a signature is attached by digest, so two tags
# of one image would share it.
mkdir "$work/ctx"
declare -A digest
for case in signed unsigned foreign other; do
  printf 'FROM quay.io/fedora/fedora:44\nLABEL net.mauvely.policy-test=%s\n' "$case" \
    | podman build -q -t "localhost/mauvely-policy-test:$case" -f - "$work/ctx" >/dev/null
  repo=mauvely/os; [ "$case" = other ] && repo=other/thing
  podman push -q --tls-verify=false --digestfile "$work/$case.digest" \
    "localhost/mauvely-policy-test:$case" "docker://$reg/$repo:$case"
  digest[$case]="$(cat "$work/$case.digest")"
done
sign() {
  COSIGN_PASSWORD='' "$cosign" sign --yes --tlog-upload=false --allow-insecure-registry \
    --key "$work/$1.key" "$reg/mauvely/os@$2" >/dev/null 2>&1
}
sign good "${digest[signed]}"
sign foreign "${digest[foreign]}"

echo "== the policy in $image"
# The image's policy and registries.d, with only the repository's name moved to
# the test registry.
podman run --rm --network host \
  -v "$work/good.pub:/etc/pki/containers/mauvely-os.pub:ro,Z" \
  "$image" bash -c "
    set -u
    sed -i 's|ghcr.io/mauvely/os|$reg/mauvely/os|' /etc/containers/policy.json /etc/containers/registries.d/mauvely-os.yaml
    fails=0
    check() {
      if out=\$(skopeo copy -q --src-tls-verify=false docker://$reg/\$1 dir:/tmp/\${1//[\/:]/_} 2>&1); then got=accepted
      elif [[ \$out == *ignature* ]]; then got=refused
      else got=error
      fi
      if [ \"\$got\" = \"\$2\" ]; then echo \"ok    \$1: \$got\"; else echo \"FAIL  \$1: \$got, expected \$2\"; echo \"      \$out\"; fails=1; fi
    }
    check mauvely/os:signed accepted
    check mauvely/os:unsigned refused
    check mauvely/os:foreign refused
    check other/thing:other accepted
    exit \$fails
  "
echo "== passed"
