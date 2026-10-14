#!/usr/bin/env bash
# Creates everything the installer VM and the installed machine need:
# an SSH key, the cloud-init seed, the Secure Boot varstore (Microsoft keys
# enrolled), and the two disks. Idempotent: it never overwrites "the machine".
set -euo pipefail
. "$(dirname "$0")/env.sh"
mkdir -p "$M" "$SSHDIR" "$SEEDDIR" "$M/tpm"

[ -f "$SSHDIR/id_ed25519" ] || ssh-keygen -q -t ed25519 -N '' -C mauvely-os-spike -f "$SSHDIR/id_ed25519"

# cloud-init NoCloud, served over HTTP (no ISO tooling needed).
cat > "$SEEDDIR/meta-data" <<META
instance-id: mauvely-os-installer-1
local-hostname: installer
META
cat > "$SEEDDIR/user-data" <<USERDATA
#cloud-config
users:
  - name: fedora
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat "$SSHDIR/id_ed25519.pub")
ssh_pwauth: false
growpart:
  mode: auto
  devices: ['/']
resize_rootfs: true
USERDATA

# Secure Boot varstore: Red Hat PK/KEK plus the Microsoft KEK and db keys
# (UEFI CA 2011 and 2023, which is what signs shim), Secure Boot switched on.
if [ ! -f "$M/OVMF_VARS.secboot.fd" ]; then
  "$VENV/bin/virt-fw-vars" -i /usr/share/edk2/x64/OVMF_VARS.4m.fd \
    -o "$M/OVMF_VARS.secboot.fd" --enroll-redhat --secure-boot
fi

# Installer VM: a copy-on-write overlay on the Fedora Cloud base, grown to 40 GB.
if [ ! -f "$M/installer.qcow2" ]; then
  "$(dirname "$0")/qemu-img.sh" create -q -f qcow2 -b "$CLOUD_QCOW2" -F qcow2 "$M/installer.qcow2" 40G
fi
# Target disk: blank, sparse.
[ -f "$M/target.qcow2" ] || "$(dirname "$0")/qemu-img.sh" create -q -f qcow2 "$M/target.qcow2" 60G
echo "prepared in $M"
