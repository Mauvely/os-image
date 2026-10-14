#!/usr/bin/env bash
# iso-boot.sh <iso|-> <dir>   Boots an installer ISO headless under Secure Boot
# (fresh OVMF vars with Microsoft keys, fresh swtpm, blank 60 GB raw disk with
# serial TARGET) in its own directory, so it never touches "the machine".
# Console: <dir>/serial.log. Screenshot: QMP socket <dir>/qmp.sock.
set -euo pipefail
. "$(dirname "$0")/env.sh"
iso="$1"; D="$2"; mkdir -p "$D/tpm"
[ -f "$D/vars.fd" ] || "$VENV/bin/virt-fw-vars" -i /usr/share/edk2/x64/OVMF_VARS.4m.fd -o "$D/vars.fd" --enroll-redhat --secure-boot >/dev/null 2>&1
[ -f "$D/target.raw" ] || truncate -s 60G "$D/target.raw"
swtpm socket --tpm2 --tpmstate "dir=$D/tpm" --ctrl "type=unixio,path=$D/swtpm.sock" \
  --pid "file=$D/swtpm.pid" --daemon
cd=(-drive "if=none,id=cd,format=raw,media=cdrom,readonly=on,file=$iso" -device ide-cd,drive=cd,bootindex=1)
[ "$iso" = - ] && cd=()    # "-" boots the target disk alone
exec qemu-system-x86_64 -name "iso-test" -machine q35,smm=on,accel=kvm -cpu host -smp 4 -m 8G \
  -global driver=cfi.pflash01,property=secure,value=on \
  -drive "if=pflash,format=raw,unit=0,file=/usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd,readonly=on" \
  -drive "if=pflash,format=raw,unit=1,file=$D/vars.fd" \
  -chardev "socket,id=chrtpm,path=$D/swtpm.sock" -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-crb,tpmdev=tpm0 \
  -device VGA -display none -serial "file:$D/serial.log" -qmp "unix:$D/qmp.sock,server,nowait" \
  "${cd[@]}" \
  -drive "if=none,id=tgt,format=raw,file=$D/target.raw" -device virtio-blk-pci,drive=tgt,serial=TARGET,bootindex=2 \
  -netdev "user,id=n0,hostfwd=tcp:127.0.0.1:${SSH_FWD:-2224}-:22" -device virtio-net-pci,netdev=n0 -device virtio-rng-pci \
  -pidfile "$D/qemu.pid" -daemonize
