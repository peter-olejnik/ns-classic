#!/usr/bin/env bash
# Analyze ns_maps/, apply mapmerge/rules.toml, and assemble the server's mod
# directory:
#
#   dist/maps/          the files merged from ns_maps (overlay for dist/ns)
#   dist/server/ns/     dist/ns + dist/maps (+ --navgen navmeshes) + content/:
#                       ready for hosting
#   dist/mapmerge/      report.md, merge-report.md, maplist.txt (+ .json)
#   mapcycle.*.txt      in dist/maps and dist/server/ns (see mapmerge/mapcycle.py)
#
# content/ (committed, user-made files such as bot navmeshes) is copied last,
# so it wins over dist/ns and the merged maps. The files it adds or replaces
# are listed at the end of merge-report.md. It's applied here on the host, so
# a change to content/ never invalidates the cached analysis.
#
# dist/ns itself is never modified, so this can be re-run at any time (e.g.
# after editing rules.toml; only the merge step re-runs, the analysis is
# cached). Requires dist/ns from builder/build.sh. Uses podman if available,
# otherwise docker; override with CONTAINER_ENGINE.
#
# --navgen generates a bot navmesh (navgen/) for every map in the filtered
# mapcycles (mapcycle.ns/co/siege.txt) that has none in dist/ns, ns_maps or
# content/; --navgen-all does it for every map. Results are cached in
# dist/navmeshes/, so only new or changed maps are built; the first run takes
# a while (NAVGEN_JOBS maps in parallel). They're listed in merge-report.md.
#
# Usage: mapmerge/merge.sh [--navgen | --navgen-all] [extra build args...]
set -euo pipefail

navgen=""
case "${1:-}" in
  --navgen) navgen=cycles; shift ;;
  --navgen-all) navgen=all; shift ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
maps_dir="$repo_root/ns_maps"
ns_dir="$repo_root/dist/ns"
report_dir="$repo_root/dist/mapmerge"
overlay_dir="$repo_root/dist/maps"
server_dir="$repo_root/dist/server/ns"
content_dir="$repo_root/content"

[[ -d "$maps_dir" ]] || { echo "error: $maps_dir not found" >&2; exit 1; }
[[ -d "$ns_dir" ]] || { echo "error: $ns_dir not found; run builder/build.sh first" >&2; exit 1; }

engine="${CONTAINER_ENGINE:-$(command -v podman >/dev/null && echo podman || echo docker)}"
image="ns-classic-mapmerge-merged:latest"

"$engine" build -f "$repo_root/mapmerge/Dockerfile" --target merged -t "$image" \
  --build-context maps="$maps_dir" --build-context ns="$ns_dir" \
  "$@" "$repo_root/mapmerge"

# The export image is FROM scratch; the command is never run, create just needs one.
container="$("$engine" create "$image" /none)"
trap '"$engine" rm "$container" >/dev/null' EXIT

rm -rf "$report_dir" "$overlay_dir"
mkdir -p "$report_dir"
for f in report.md report.json merge-report.md merge.json maplist.txt; do
  "$engine" cp "$container:/$f" "$report_dir/$f"
done
"$engine" cp "$container:/maps" "$overlay_dir"

echo "Assembling $server_dir"
rm -rf "$server_dir" || {
  echo "error: can't delete $server_dir; close any program running from it (e.g. NavEditor), then re-run" >&2
  exit 1
}
mkdir -p "$(dirname "$server_dir")"
cp -a "$ns_dir" "$server_dir"
cp -a "$overlay_dir/." "$server_dir/"

# --navgen: generate bot navmeshes for maps that have none (see navgen/).
# Cached in dist/navmeshes/ and keyed by the .bsp's checksum and navgen's
# source, so only new or changed maps (or a changed navgen) are rebuilt.
if [[ -n "$navgen" ]]; then
  nav_cache="$repo_root/dist/navmeshes"
  keys_file="$nav_cache/keys.txt"
  mkdir -p "$nav_cache"
  touch "$keys_file"
  navgen_key="$(cat "$repo_root/navgen/navgen.cpp" "$repo_root/navgen/Dockerfile" | cksum | cut -d' ' -f1)"

  if [[ "$navgen" == all ]]; then
    names="$(find "$server_dir/maps" -maxdepth 1 -name '*.bsp' -printf '%f\n' | sed 's/\.bsp$//')"
  else
    names="$(cat "$server_dir"/mapcycle.{ns,co,siege}.txt | sed -E '/^\/\/|^\s*$/d; s/ +".*$//')"
  fi

  declare -A old_key=()
  while IFS=$'\t' read -r m k; do
    if [[ -n "$m" ]]; then old_key["$m"]="$k"; fi
  done < "$keys_file"
  declare -A new_key=()
  wanted=() todo=()
  while IFS= read -r m; do
    bsp="$server_dir/maps/$m.bsp"
    [[ -n "$m" && -f "$bsp" ]] || continue
    [[ -e "$server_dir/navmeshes/$m.nav" || -e "$content_dir/navmeshes/$m.nav" ]] && continue
    wanted+=("$m")
    new_key["$m"]="$(cksum < "$bsp" | tr ' ' :):$navgen_key"
    if [[ ! -f "$nav_cache/$m.nav" || "${old_key[$m]:-}" != "${new_key[$m]}" ]]; then
      rm -f "$nav_cache/$m.nav"
      todo+=("$bsp")
    fi
  done < <(sort -u <<< "$names")

  echo "navgen: ${#wanted[@]} maps without a navmesh, ${#todo[@]} to generate"
  if (( ${#todo[@]} )); then
    "$repo_root/navgen/build.sh" -o "$nav_cache" "${todo[@]}" || true
  fi

  generated=() failed=()
  mkdir -p "$server_dir/navmeshes"
  for m in "${wanted[@]}"; do
    if [[ -f "$nav_cache/$m.nav" ]]; then
      cp "$nav_cache/$m.nav" "$server_dir/navmeshes/"
      old_key["$m"]="${new_key[$m]}"
      generated+=("$m")
    else
      failed+=("$m")
    fi
  done
  for m in "${!old_key[@]}"; do printf '%s\t%s\n' "$m" "${old_key[$m]}"; done | sort > "$keys_file"

  {
    printf '\n## navgen\n\n'
    printf 'Generated bot navmeshes (no off-mesh connections, hints or volumes) for %d maps without one' "${#generated[@]}"
    [[ "$navgen" == all ]] && printf ' (all maps).\n\n' || printf ' (maps in mapcycle.ns/co/siege).\n\n'
    for m in "${generated[@]}"; do printf -- '- `%s`\n' "$m"; done
    if (( ${#failed[@]} )); then
      printf '\nFailed:\n\n'
      for m in "${failed[@]}"; do printf -- '- `%s`\n' "$m"; done
    fi
  } >> "$report_dir/merge-report.md"
  echo "navgen: ${#generated[@]} navmeshes added, ${#failed[@]} failed"
fi

# content/ last: list what it adds or replaces, then copy it over
if [[ -d "$content_dir" ]]; then
  n=0
  {
    printf '\n## content/\n\n'
    printf 'Copied last from `content/`, over dist/ns and the merged maps.\n\n'
    while IFS= read -r -d '' f; do
      rel="${f#"$content_dir"/}"
      if [[ -e "$overlay_dir/$rel" ]]; then what="replaces a merged file"
      elif [[ -e "$ns_dir/$rel" ]]; then what="replaces a dist/ns file"
      else what="added"; fi
      printf -- '- `%s`: %s\n' "$rel" "$what"
      n=$((n + 1))
    done < <(find "$content_dir" -type f -print0 | sort -z)
    (( n )) || printf 'No files.\n'
  } >> "$report_dir/merge-report.md"
  cp -a "$content_dir/." "$server_dir/"
  echo "Applied content/ ($(find "$content_dir" -type f | wc -l) files)"
fi

echo "Merge report: $report_dir/merge-report.md"
echo "Server mod directory: $server_dir"
