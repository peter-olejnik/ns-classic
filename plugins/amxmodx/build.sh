#!/usr/bin/env bash
# Build AMX Mod X and Metamod-P from source in a container and export them as
# an overlay for the ns mod directory: dist/plugins/amxmodx/addons/...
# hosting/build.sh adds it to the server image with PLUGINS=amxmodx, and then
# points liblist.gam at metamod.
#
# Every repo is built at the latest commit of its ref, resolved here with
# git ls-remote, so a rebuild picks up upstream changes and an unchanged
# upstream reuses the cached layers. Override a ref (branch, tag or commit)
# or a URL, e.g. for a fork:
#   AMXMODX_GIT_REF     (default: master)   AMXMODX_GIT_URL
#   METAMOD_GIT_REF     (default: master)   METAMOD_GIT_URL   (Bots-United/metamod-p)
#   AMBUILD_GIT_REF, HLSDK_GIT_REF, METAMOD_HL1_GIT_REF       (default: master)
# The commits used are in addons/amxmodx/ns-classic-sources.txt.
#
# It also compiles the custom plugins in plugins/amxmodx/scripting/*.sma
# (plus prebuilt/*.amxx as they are), and installs plugins/amxmodx/plugins.ini,
# which enables or disables each plugin, as configs/plugins.ini.
#
# Uses podman if available, otherwise docker; override with CONTAINER_ENGINE.
#
# Usage: plugins/amxmodx/build.sh [extra build args...]
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out_dir="$repo_root/dist/plugins/amxmodx"
engine="${CONTAINER_ENGINE:-$(command -v podman >/dev/null && echo podman || echo docker)}"
image="localhost/ns-classic-amxmodx:latest"

# resolve <url> <ref>: the commit a branch or tag points to (a commit as-is)
resolve() {
  if [[ "$2" =~ ^[0-9a-f]{40}$ ]]; then echo "$2"; return; fi
  local refs
  refs="$(git ls-remote "$1" "refs/heads/$2" "refs/tags/$2" "refs/tags/$2^{}")" ||
    { echo "error: can't reach $1" >&2; return 1; }
  # An annotated tag's own commit is the ^{} line
  refs="$(sort -k2 <<< "$refs" | tail -n 1 | cut -f1)"
  [[ -n "$refs" ]] || { echo "error: no branch or tag '$2' in $1" >&2; return 1; }
  echo "$refs"
}

build_args=()
add() { # add <NAME> <default url>: resolve NAME_GIT_REF, pass NAME_COMMIT (and the URL)
  local url_var="$1_GIT_URL" ref_var="$1_GIT_REF" url ref commit
  url="${!url_var:-$2}" ref="${!ref_var:-master}"
  commit="$(resolve "$url" "$ref")"
  printf '  %-12s %s %s (%s)\n' "${1,,}" "$url" "$ref" "${commit:0:12}"
  build_args+=(--build-arg "$1_GIT_URL=$url" --build-arg "$1_COMMIT=$commit")
}
echo "Sources:"
add AMXMODX https://github.com/alliedmodders/amxmodx.git
add METAMOD https://github.com/Bots-United/metamod-p.git
add AMBUILD https://github.com/alliedmodders/ambuild.git
add HLSDK https://github.com/alliedmodders/hlsdk.git
add METAMOD_HL1 https://github.com/alliedmodders/metamod-hl1.git

"$engine" build -f "$repo_root/plugins/amxmodx/Dockerfile" --target export -t "$image" \
  "${build_args[@]}" "$@" "$repo_root/plugins/amxmodx"

# The export image is FROM scratch; the command is never run, create just needs one.
container="$("$engine" create "$image" /none)"
trap '"$engine" rm "$container" >/dev/null' EXIT

rm -rf "$out_dir"
mkdir -p "$(dirname "$out_dir")"
"$engine" cp "$container:/ns" "$out_dir"

echo "Exported: $out_dir"
# The custom plugins (scripting/*.sma): how many compiled, and which didn't
head -n 2 "$out_dir/addons/amxmodx/scripting/ns-classic-compile.txt"
echo "Compiler errors: $out_dir/addons/amxmodx/scripting/ns-classic-compile.txt"
echo "Add it to the server image with: PLUGINS=amxmodx hosting/build.sh"
