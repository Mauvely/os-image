# Shared by the P1 spike scripts (brief 19). Source it, do not run it.
# Everything big lives under ~/.cache/mauvely-os, never /tmp.
export W="${MAUVELY_OS_CACHE:-$HOME/.cache/mauvely-os}"
export M="$W/machine"              # "the machine": OVMF vars + swtpm state + disks
export SSHDIR="$W/ssh"
export SEEDDIR="$W/seed"
export SEED_PORT="${SEED_PORT:-8099}"
export SSH_PORT="${SSH_PORT:-2222}"               # host side of the installer VM's sshd
export TARGET_SSH_PORT="${TARGET_SSH_PORT:-2223}"        # host side of the installed machine's sshd
export CLOUD_QCOW2="$W/dl/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2"
export VENV="$W/venv"
export IMAGE_TAG="localhost/mauvely-os:spike"
