#!/usr/bin/env bash
# P5: what to look at on the installed machine, over ssh. Prints plain text; the
# runs are saved under proof/p5/. Run it before the first reboot and again after.
#   p5-evidence.sh <label>
# The recovery key stays on the host: it is piped to `cryptsetup --test-passphrase`
# on stdin and never printed.
set -uo pipefail
. "$(dirname "$0")/env.sh"
label="${1:?label}"
vm() { "$(dirname "$0")/ssh-vm.sh" target "$@"; }
sect() { printf '\n== %s\n' "$*"; }

sect "$label"; vm 'date -u; uname -r; cat /proc/cmdline | tr " " "\n" | grep -E "^luks|^root"'
sect "os-release"; vm 'cat /usr/lib/os-release; echo; ls -la /etc/os-release; ls /usr/lib/mauvely-release 2>&1'
sect "About page"; vm 'cat /etc/xdg/kcm-about-distrorc; ls -la /usr/share/pixmaps/mauvely-logo.png'
sect "secure boot, disk"; vm 'mokutil --sb-state; lsblk -f /dev/vda; findmnt -no FSTYPE /sysroot'
sect "mauvelyd: present and enabled, inactive without /etc/mauvely/server"
vm 'ls -la /usr/bin/mauvelyd; mauvelyd --version; systemctl is-enabled mauvelyd; systemctl is-active mauvelyd; ls /etc/mauvely 2>&1; systemctl status mauvelyd --no-pager | sed -n "1,5p"'
sect "mauvely-seal"; vm 'systemctl is-enabled mauvely-seal; systemctl show -p ActiveState,Result,ExecMainStatus mauvely-seal; journalctl -b -u mauvely-seal --no-pager -o cat'
sect "LUKS tokens and slots"
vm 'dev=$(cryptsetup status /dev/mapper/root 2>/dev/null | awk "/device:/{print \$2}"); [ -n "$dev" ] || dev=/dev/vda4; echo "device: $dev"
    cryptsetup luksDump --dump-json-metadata $dev | jq -c "{tokens: [.tokens[] | {type, keyslots, pcrs: .[\"tpm2-pcrs\"], bank: .[\"tpm2-pcr-bank\"]}], keyslots: (.keyslots | keys)}"
    systemd-cryptenroll $dev'
sect "the recovery slot still opens the volume"
tr -d '\n' < "$M/recovery-key.txt" | vm 'cryptsetup open --test-passphrase --key-file=- /dev/vda4 && echo "recovery key: opens the volume"'
sect "staged deployment (a kargs-only one is expected before the first reboot)"
vm 'bootc status --json | jq -c "{booted: .status.booted.image.image.image, staged: .status.staged.image.image.image}"; rpm-ostree status | head -20'
sect "no Fedora Flatpak remotes"
vm 'flatpak remotes --system --show-disabled --columns=name,url; echo "remotes: $(flatpak remotes --system --show-disabled --columns=name | grep -c .)"; ls /etc/flatpak/remotes.d /usr/share/flatpak/remotes.d; ls /var/lib/flatpak/.fedora-initialized 2>&1; systemctl is-enabled flatpak-add-fedora-repos'
sect "no update timers"
vm 'systemctl is-enabled bootc-fetch-apply-updates.timer rpm-ostreed-automatic.timer bootc-fetch-apply-updates.service rpm-ostreed-automatic.service; systemctl list-timers --all --no-pager | grep -E "bootc|rpm-ostree" || echo "no bootc or rpm-ostree timer is listed"'
sect "Firefox is gone"
vm 'rpm -q firefox firefox-langpacks; command -v firefox || echo "no firefox on PATH"; ls /usr/share/applications | grep -i firefox || echo "no firefox.desktop"'
sect "Plasma Setup stays"
vm 'ls /etc/plasma-setup-done 2>&1; systemctl is-enabled plasma-setup'
sect "dnf, flatpak, bootc see Fedora"
vm '. /etc/os-release; echo "ID=$ID VERSION_ID=$VERSION_ID"; flatpak --version; bootc --version; rpm -E %fedora'
