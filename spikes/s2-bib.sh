#!/usr/bin/env bash
# S2 step 4: ask the legacy bootc-image-builder container for an installer ISO of
# our image, inside the installer VM. Usage: s2-bib.sh <type> (anaconda-iso | iso)
# Output goes under /var/bib: /tmp in the VM is a 4 GB tmpfs and an ISO does not fit.
set -euo pipefail
. "$(dirname "$0")/env.sh"
type="${1:-anaconda-iso}"
"$(dirname "$0")/ssh-vm.sh" installer "sudo bash -s" <<REMOTE
mkdir -p /var/bib/store /var/bib/out-$type
podman run --rm --privileged --security-opt label=type:unconfined_t \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v /var/bib/store:/store -v /var/bib/out-$type:/output \
  quay.io/centos-bootc/bootc-image-builder:latest build --type $type --rootfs xfs \
  localhost/mauvely-os:spike-ssh > /var/bib/bib-$type.log 2>&1
echo "exit=\$?" >> /var/bib/bib-$type.log
REMOTE
