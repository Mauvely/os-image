#!/usr/bin/env bash
# S2 step 4, path B: build a `bootc-generic-iso` from the minimal installer
# container (spikes/installer/), carrying our OS image as the payload, inside the
# installer VM. Both images must already be loaded there.
set -euo pipefail
. "$(dirname "$0")/env.sh"
"$(dirname "$0")/ssh-vm.sh" installer "sudo bash -s" <<'REMOTE'
mkdir -p /var/bib/out-generic /var/bib/cache-generic
podman run --rm --privileged --security-opt label=type:unconfined_t \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v /var/bib/out-generic:/output -v /var/bib/cache-generic:/root/.cache \
  ghcr.io/osbuild/image-builder-cli:latest build \
  --bootc-ref localhost/mauvely-installer:spike \
  --bootc-installer-payload-ref localhost/mauvely-os:spike-ssh \
  --bootc-default-fs xfs bootc-generic-iso > /var/bib/generic.log 2>&1
echo "exit=$?" >> /var/bib/generic.log
REMOTE
