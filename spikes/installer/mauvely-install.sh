#!/bin/bash
# Stand-in for the Qt installer: pick the blank disk and run `bootc install
# to-disk` from the payload image that the ISO carries in containers-storage.
exec 2>&1
echo "MAUVELY-INSTALLER: start"
uname -r; findmnt / | tail -1
live=$(findmnt -n -o SOURCE /run/initramfs/live 2>/dev/null)
echo "live medium: $live"
# the target is the disk with the serial TARGET (spike); the real installer lets the user choose
disk=""
for d in /dev/vd? /dev/sd? /dev/nvme?n?; do
  [ -b "$d" ] || continue
  if udevadm info -q property -n "$d" | grep -q '^ID_SERIAL=TARGET'; then disk=$d; fi
done
echo "target disk: $disk"; lsblk
[ -n "$disk" ] || { echo "MAUVELY-INSTALLER: no target disk"; exit 1; }
podman images
payload=$(podman images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>' | head -1)
echo "payload: $payload"
set -x
bootc install to-disk --source-imgref "containers-storage:$payload" \
  --target-imgref registry.invalid/mauvely/os:spike --skip-fetch-check \
  --wipe --block-setup tpm2-luks --filesystem xfs \
  --root-ssh-authorized-keys /usr/share/mauvely-installer/root-authorized_keys "$disk" 2>&1 | tee /run/bootc-install.log
rc=${PIPESTATUS[0]}
set +x
# bootc 1.16.13, run outside a container, leaves /run/bootc/storage mounted from the
# new root, so its last step ("Closing root LUKS device") fails with the install
# already complete. Anything else is a real failure.
if [ $rc != 0 ] && grep -q 'Task Closing root LUKS device failed' /run/bootc-install.log; then
  echo "MAUVELY-INSTALLER: recovering the leaked mount"
  umount /run/bootc/storage && cryptsetup close root && rc=0
fi
echo "MAUVELY-INSTALLER: bootc exit=$rc"
if [ $rc != 0 ]; then
  dmsetup info -c; findmnt -A | grep -E 'mapper|dm-0'
  exit 1
fi
echo "MAUVELY-INSTALL-DONE"
sleep 3
systemctl poweroff
