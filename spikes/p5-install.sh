#!/usr/bin/env bash
# P5: the S1 install, the way the real installer will make it. It differs from
# s1-install.sh in two places:
#   - no --filesystem: the image's /usr/lib/bootc/install/50-mauvely.toml names xfs,
#   - afterwards it adds the recovery key to the target disk, as the installer
#     does (bootc wipes the passphrase slot, so a fresh install has none). The
#     key goes to $M/recovery-key.txt, never into the repo.
set -euo pipefail
. "$(dirname "$0")/env.sh"
img="${1:-localhost/mauvely-os:p5-ssh}"
vm() { "$(dirname "$0")/ssh-vm.sh" installer "$@"; }
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
  -i "$SSHDIR/id_ed25519" -P "$SSH_PORT" "$SSHDIR/id_ed25519.pub" fedora@127.0.0.1:/tmp/root-authorized_keys
vm "sudo podman run --rm --privileged --pid=host \
  -v /dev:/dev -v /var/lib/containers:/var/lib/containers \
  -v /tmp/root-authorized_keys:/root-authorized_keys:ro \
  --security-opt label=type:unconfined_t \
  $img bootc install to-disk \
    --wipe --block-setup tpm2-luks \
    --root-ssh-authorized-keys /root-authorized_keys \
    --target-imgref registry.invalid/mauvely/os:p5 --skip-fetch-check \
    /dev/vdb"
luks="$(vm "lsblk -rno PATH,FSTYPE /dev/vdb | awk '\$2==\"crypto_LUKS\"{print \$1}'")"
echo "LUKS partition: $luks"
vm "sudo systemd-cryptenroll --unlock-tpm2-device=auto --recovery-key $luks" > "$M/recovery-key.txt"
chmod 600 "$M/recovery-key.txt"
echo "recovery key enrolled (in $M/recovery-key.txt)"
