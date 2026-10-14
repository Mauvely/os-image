#!/usr/bin/env bash
# Runs `bootc install to-disk` for the spike image inside the installer VM, onto
# the blank 60 GB disk (/dev/vdb), with the LUKS key sealed to the VM's TPM.
# This is the same call the real installer makes.
set -euo pipefail
. "$(dirname "$0")/env.sh"
img="${1:-localhost/mauvely-os:spike-ssh}"
vm() { "$(dirname "$0")/ssh-vm.sh" installer "$@"; }
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
  -i "$SSHDIR/id_ed25519" -P "$SSH_PORT" "$SSHDIR/id_ed25519.pub" fedora@127.0.0.1:/tmp/root-authorized_keys
vm "sudo podman run --rm --privileged --pid=host \
  -v /dev:/dev -v /var/lib/containers:/var/lib/containers \
  -v /tmp/root-authorized_keys:/root-authorized_keys:ro \
  --security-opt label=type:unconfined_t \
  $img bootc install to-disk \
    --wipe --block-setup tpm2-luks --filesystem xfs \
    --root-ssh-authorized-keys /root-authorized_keys \
    --target-imgref registry.invalid/mauvely/os:spike --skip-fetch-check \
    /dev/vdb"
