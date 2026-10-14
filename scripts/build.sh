#!/usr/bin/env bash
# Builds the image with podman, rootless. CI runs this same script with the
# agent checked out at agent.ref.
#
#   scripts/build.sh                      -> localhost/mauvely-os:dev
#   TAG=localhost/mauvely-os:x scripts/build.sh
#   AGENT_DIR=/path/to/os-agent JOBS=24 scripts/build.sh
#
# The agent source comes in as the named build context `agent`. The image is
# only reproducible when that is the commit pinned in agent.ref, so anything
# else is a warning, not an error: a local build against work in progress is
# the point of a local build.
set -euo pipefail
cd "$(dirname "$0")/.."

agent_dir="${AGENT_DIR:-../agent}"
tag="${TAG:-localhost/mauvely-os:dev}"
want="$(tr -d '[:space:]' < agent.ref)"

have="$(git -C "$agent_dir" rev-parse HEAD 2>/dev/null)" || {
  echo "build.sh: $agent_dir is not a git checkout of os-agent; set AGENT_DIR." >&2
  exit 1
}
if [ "$have" != "$want" ]; then
  echo "build.sh: WARNING: $agent_dir is at ${have:0:12}, but agent.ref pins ${want:0:12}." >&2
  echo "build.sh: WARNING: this image is not the one CI builds." >&2
fi
if [ -n "$(git -C "$agent_dir" status --porcelain 2>/dev/null)" ]; then
  echo "build.sh: WARNING: $agent_dir has uncommitted changes; they go into the image." >&2
fi

exec podman build \
  --build-context "agent=$agent_dir" \
  --build-arg "CARGO_BUILD_JOBS=${JOBS:-8}" \
  -t "$tag" \
  .
