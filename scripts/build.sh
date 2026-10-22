#!/usr/bin/env bash
# Builds the image with podman, rootless. CI runs this same script with the
# agent checked out at agent.ref and the installer at installer.ref.
#
#   scripts/build.sh                      -> localhost/mauvely-os:dev
#   TAG=localhost/mauvely-os:x scripts/build.sh
#   AGENT_DIR=/path/to/os-agent INSTALLER_DIR=/path/to/os-installer JOBS=24 scripts/build.sh
#
# The agent comes in as the named build context `agent`, and os-installer, for
# the sign-in window, as `installer`. The image is only reproducible when they
# are the commits pinned in agent.ref and installer.ref, so anything else is a
# warning, not an error: a local build against work in progress is the point
# of a local build.
set -euo pipefail
cd "$(dirname "$0")/.."

agent_dir="${AGENT_DIR:-../agent}"
installer_dir="${INSTALLER_DIR:-../installer}"
tag="${TAG:-localhost/mauvely-os:dev}"

# check <dir> <ref file> <repository> <variable>
check() {
  local dir="$1" ref="$2" repo="$3" var="$4" want have
  want="$(tr -d '[:space:]' < "$ref")"
  have="$(git -C "$dir" rev-parse HEAD 2>/dev/null)" || {
    echo "build.sh: $dir is not a git checkout of $repo; set $var." >&2
    exit 1
  }
  if [ "$have" != "$want" ]; then
    echo "build.sh: WARNING: $dir is at ${have:0:12}, but $ref pins ${want:0:12}." >&2
    echo "build.sh: WARNING: this image is not the one CI builds." >&2
  fi
  if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
    echo "build.sh: WARNING: $dir has uncommitted changes; they go into the image." >&2
  fi
}
check "$agent_dir" agent.ref os-agent AGENT_DIR
check "$installer_dir" installer.ref os-installer INSTALLER_DIR

exec podman build \
  --build-context "agent=$agent_dir" \
  --build-context "installer=$installer_dir" \
  --build-arg "CARGO_BUILD_JOBS=${JOBS:-8}" \
  --build-arg "CMAKE_BUILD_PARALLEL_LEVEL=${JOBS:-8}" \
  -t "$tag" \
  .
