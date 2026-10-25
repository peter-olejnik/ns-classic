#!/usr/bin/env bash
# Build the NS dedicated server image (localhost/ns-classic-server:latest),
# used by hosting/compose.yaml.
#
# The mod directory comes from dist/server/ns, assembled by mapmerge/merge.sh
# from builder/build.sh's dist/ns plus the custom maps. Override it with
# NS_DIR, e.g. NS_DIR=dist/ns for a server without custom maps.
#
# hosting/server.cfg and hosting/motd.txt replace the ones in the mod directory.
# They are gitignored; if missing, they are created from the committed
# server.cfg.example and motd.txt.example.
#
# Uses podman if available, otherwise docker; override with CONTAINER_ENGINE.
#
# Usage: hosting/build.sh [extra build args...]
#   e.g. hosting/build.sh --no-cache
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ns_dir="${NS_DIR:-$repo_root/dist/server/ns}"
image="localhost/ns-classic-server:latest"

if [[ ! -f "$ns_dir/dlls/ns.so" ]]; then
  echo "error: $ns_dir/dlls/ns.so not found; run builder/build.sh, then mapmerge/merge.sh" >&2
  exit 1
fi

# Your configs; created from the committed examples on the first run
for f in server.cfg motd.txt; do
  if [[ ! -f "$repo_root/hosting/$f" ]]; then
    cp "$repo_root/hosting/$f.example" "$repo_root/hosting/$f"
    echo "Created hosting/$f from hosting/$f.example; edit it to customize the server"
  fi
done

engine="${CONTAINER_ENGINE:-$(command -v podman >/dev/null && echo podman || echo docker)}"

"$engine" build -f "$repo_root/hosting/Dockerfile" -t "$image" \
  --build-context ns="$ns_dir" \
  "$@" "$repo_root/hosting"

echo "Built $image"
echo "Start it with: cd hosting && $engine compose up -d"
