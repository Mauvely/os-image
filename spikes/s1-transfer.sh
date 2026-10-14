#!/usr/bin/env bash
# Moves the built image into the installer VM's root container storage.
# (A real installer ISO carries the image itself; this is the stand-in.)
set -euo pipefail
. "$(dirname "$0")/env.sh"
img="${1:-localhost/mauvely-os:spike-ssh}"
podman save "$img" | "$(dirname "$0")/ssh-vm.sh" installer 'sudo podman load'
