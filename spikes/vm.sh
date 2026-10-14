#!/usr/bin/env bash
# Starts swtpm and qemu for one of the two roles, headless, daemonised.
#   vm.sh installer   Fedora Cloud + the blank target disk as /dev/vdb (S1)
#   vm.sh target      the target disk alone, same OVMF vars, same swtpm (S2)
#   vm.sh stop        quits qemu (ACPI), leaves swtpm state on disk
# The same OVMF vars file and swtpm state back both roles: they are the machine,
# and the LUKS key is sealed to that TPM and that Secure Boot state.
set -euo pipefail
. "$(dirname "$0")/env.sh"
role="${1:?installer|target|stop}"

stop() {
  [ -S "$M/qmp.sock" ] && python3 "$(dirname "$0")/qmp.py" "$M/qmp.sock" system_powerdown >/dev/null 2>&1 || true
  for _ in $(seq 60); do [ -f "$M/qemu.pid" ] && kill -0 "$(cat "$M/qemu.pid")" 2>/dev/null || break; sleep 1; done
  [ -f "$M/qemu.pid" ] && kill -0 "$(cat "$M/qemu.pid")" 2>/dev/null && kill "$(cat "$M/qemu.pid")" || true
  [ -f "$M/swtpm.pid" ] && kill "$(cat "$M/swtpm.pid")" 2>/dev/null || true
}
[ "$role" = stop ] && { stop; exit 0; }

# swtpm: a TPM 2.0 whose state persists in $M/tpm
swtpm socket --tpm2 --tpmstate "dir=$M/tpm" \
  --ctrl "type=unixio,path=$M/swtpm.sock" --pid "file=$M/swtpm.pid" \
  --log "file=$M/swtpm.log,level=5" --daemon

common=(
  -name "mauvely-os-$role" -machine q35,smm=on,accel=kvm -cpu host -smp 4 -m 8G
  -global driver=cfi.pflash01,property=secure,value=on
  -drive "if=pflash,format=raw,unit=0,file=/usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd,readonly=on"
  -drive "if=pflash,format=raw,unit=1,file=$M/OVMF_VARS.secboot.fd"
  -chardev "socket,id=chrtpm,path=$M/swtpm.sock" -tpmdev emulator,id=tpm0,chardev=chrtpm
  -device tpm-crb,tpmdev=tpm0
  -device VGA -display none -serial "file:$M/serial-$role.log"
  -qmp "unix:$M/qmp.sock,server,nowait"
  -device virtio-rng-pci
  -pidfile "$M/qemu.pid" -daemonize
)

case "$role" in
  installer)
    exec qemu-system-x86_64 "${common[@]}" \
      -drive "if=none,id=sys,format=qcow2,file=$M/installer.qcow2" -device virtio-blk-pci,drive=sys,bootindex=1 \
      -drive "if=none,id=tgt,format=qcow2,file=$M/target.qcow2" -device virtio-blk-pci,drive=tgt,serial=TARGET \
      -netdev "user,id=n0,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22" -device virtio-net-pci,netdev=n0 \
      -smbios "type=1,serial=ds=nocloud;s=http://10.0.2.2:$SEED_PORT/"
    ;;
  target)
    exec qemu-system-x86_64 "${common[@]}" \
      -drive "if=none,id=tgt,format=qcow2,file=$M/target.qcow2" -device virtio-blk-pci,drive=tgt,bootindex=1,serial=TARGET \
      -netdev "user,id=n0,hostfwd=tcp:127.0.0.1:$TARGET_SSH_PORT-:22" -device virtio-net-pci,netdev=n0
    ;;
esac
