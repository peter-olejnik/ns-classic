#!/usr/bin/env bash
# Analyze ns_maps/ against dist/ns/ in a container and export the report to
# <out dir> (default: dist/mapmerge): report.md and report.json.
#
# Requires dist/ns from builder/build.sh. Uses podman if available, otherwise
# docker; override with CONTAINER_ENGINE.
#
# Usage: mapmerge/analyze.sh [out dir] [extra build args...]
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
maps_dir="$repo_root/ns_maps"
ns_dir="$repo_root/dist/ns"
out_dir="${1:-$repo_root/dist/mapmerge}"
shift || true

[[ -d "$maps_dir" ]] || { echo "error: $maps_dir not found" >&2; exit 1; }
[[ -d "$ns_dir" ]] || { echo "error: $ns_dir not found; run builder/build.sh first" >&2; exit 1; }

engine="${CONTAINER_ENGINE:-$(command -v podman >/dev/null && echo podman || echo docker)}"
image="ns-classic-mapmerge:latest"

"$engine" build -f "$repo_root/mapmerge/Dockerfile" --target report -t "$image" \
  --build-context maps="$maps_dir" --build-context ns="$ns_dir" \
  "$@" "$repo_root/mapmerge"

# The export image is FROM scratch; the command is never run, create just needs one.
container="$("$engine" create "$image" /none)"
trap '"$engine" rm "$container" >/dev/null' EXIT

rm -rf "$out_dir"
mkdir -p "$out_dir"
"$engine" cp "$container:/report.md" "$out_dir/report.md"
"$engine" cp "$container:/report.json" "$out_dir/report.json"

echo "Report: $out_dir/report.md"
