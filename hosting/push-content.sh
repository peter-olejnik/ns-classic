#!/usr/bin/env bash
# Copy content/ into the running hlds container and reload the bot navmeshes,
# without rebuilding the image or restarting the server:
#
#   hosting/push-content.sh
#
# The files land in the container only; the next image build (merge.sh, then
# build.sh) bakes them in for good. sv_botreloadnav reloads the navmesh of the
# current map; if the map started without one, the bots are switched off and
# on instead, which loads it. Bots must be enabled (mp_botsenabled 1). Other
# maps pick up their new navmesh when they load.
#
# Needs RCON_PASSWORD in hosting/.env. Uses podman if available, otherwise
# docker; override with CONTAINER_ENGINE, and the container with
# HLDS_CONTAINER (default: ns-classic-hlds-1, from compose.yaml).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
content_dir="$repo_root/content"
engine="${CONTAINER_ENGINE:-$(command -v podman >/dev/null && echo podman || echo docker)}"
container="${HLDS_CONTAINER:-ns-classic-hlds-1}"
mod_dir=/home/steam/hlds/ns

# Git Bash on Windows would rewrite the container paths below
export MSYS_NO_PATHCONV=1

[[ -d "$content_dir" ]] || { echo "error: $content_dir not found" >&2; exit 1; }
[[ "$("$engine" inspect -f '{{.State.Running}}' "$container" 2>/dev/null)" == "true" ]] ||
  { echo "error: container $container is not running (cd hosting && podman compose up -d)" >&2; exit 1; }

# ... so convert the host path by hand (remote podman needs a Windows path)
src="$content_dir"
command -v cygpath >/dev/null && src="$(cygpath -m "$src")"
"$engine" cp "$src/." "$container:$mod_dir/"
echo "Copied $(find "$content_dir" -type f | wc -l) files from content/ to $container"

# sv_botreloadnav says nothing when the current map has no navmesh loaded
# (there was none when the map started). Then there are no bots either, so
# switching bots off and on is harmless, and it loads the navmesh.
if out="$("$engine" exec "$container" ./rcon.sh sv_botreloadnav 2>&1)" && [[ "$out" == *"loaded successfully"* ]]; then
  echo "$out"
else
  echo "No navmesh was loaded for the current map; restarting the bots to load it"
  "$engine" exec "$container" ./rcon.sh mp_botsenabled 0 >/dev/null 2>&1 || true
  sleep 2
  "$engine" exec "$container" ./rcon.sh mp_botsenabled 1 >/dev/null 2>&1 || true
  echo "Done. If the bots still don't join, check: podman logs ns-classic-hlds-1 | grep -i nav"
fi
