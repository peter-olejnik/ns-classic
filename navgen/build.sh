#!/usr/bin/env bash
# Build the navgen image (headless bot navmesh generator) and, given maps,
# generate their navmeshes: <map>.bsp -> <out dir>/<map>.nav.
#
# Generated meshes are a plain "Build" in the editor: they have no hand-placed
# off-mesh connections (ladders, jumps, lifts), nav hints or convex volumes.
# Curated meshes belong in content/navmeshes/.
#
# The maps are streamed into a container with tar and the results streamed
# back, so it works with remote podman (no bind mounts). Maps are built in
# parallel, NAVGEN_JOBS at a time (default: the container's CPU count). Maps
# that fail are reported and skipped; the exit status is 1 if any failed.
# Uses podman if available, otherwise docker; override with CONTAINER_ENGINE.
#
# Usage: navgen/build.sh [-o out dir] [map.bsp ...]   (default out: dist/navmeshes)
#   e.g. navgen/build.sh dist/server/ns/maps/ns_siege005.bsp
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="$repo_root/dist/navmeshes"
if [[ "${1:-}" == "-o" ]]; then
  out_dir="$2"
  shift 2
fi

engine="${CONTAINER_ENGINE:-$(command -v podman >/dev/null && echo podman || echo docker)}"
image="localhost/ns-classic-navgen:latest"

"$engine" build -q -t "$image" "$repo_root/navgen" >/dev/null
[[ $# -gt 0 ]] || { echo "Built $image"; exit 0; }

export MSYS_NO_PATHCONV=1
container="$("$engine" create --entrypoint sleep "$image" infinity)"
trap '"$engine" rm -f "$container" >/dev/null' EXIT
"$engine" start "$container" >/dev/null
"$engine" exec "$container" mkdir -p /maps /out /failed

tar_args=()
for bsp in "$@"; do
  tar_args+=(-C "$(cd "$(dirname "$bsp")" && pwd)" "$(basename "$bsp")")
done
echo "Generating $# navmesh(es)"
tar -cf - "${tar_args[@]}" | "$engine" exec -i "$container" tar --no-same-owner -xf - -C /maps

# One navgen per map; a failed map leaves a marker in /failed with its errors
"$engine" exec -e "JOBS=${NAVGEN_JOBS:-}" "$container" bash -c '
  cd /maps
  find . -name "*.bsp" -print0 |
    xargs -0 -P "${JOBS:-$(nproc)}" -I{} bash -c '\''
      m="$(basename "$1" .bsp)"
      if timeout 900 navgen build "$1" "/out/$m.nav" 2>"/failed/$m"; then rm "/failed/$m"
      else s=$?; echo "navgen exited with status $s$([ $s = 124 ] && echo " (timed out)")" >>"/failed/$m"; rm -f "/out/$m.nav"; fi
    '\'' _ {}
  true' | sed 's|^/out/||'

failed="$("$engine" exec "$container" sh -c 'cd /failed && for f in *; do [ -e "$f" ] && echo "$f: $(paste -sd " " "$f")"; done; true')"

mkdir -p "$out_dir"
"$engine" exec "$container" tar -cf - -C /out . | tar --no-same-owner -xf - -C "$out_dir"
echo "Navmeshes: $out_dir"
if [[ -n "$failed" ]]; then
  echo "Failed:" >&2
  echo "$failed" | sed 's/^/  /' >&2
  exit 1
fi
