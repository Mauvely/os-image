#!/usr/bin/env bash
# ssh-vm.sh installer|target [command...]   ssh into one of the two VMs.
set -euo pipefail
. "$(dirname "$0")/env.sh"
role="$1"; shift
case "$role" in installer) port=$SSH_PORT; user=fedora;; target) port=$TARGET_SSH_PORT; user=root;; esac
exec ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
  -o ConnectTimeout=5 -i "$SSHDIR/id_ed25519" -p "$port" "$user@127.0.0.1" "$@"
