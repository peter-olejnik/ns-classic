#!/usr/bin/env bash
# Build the NS server binary in a container and export the server-ready mod
# directory to <out dir>/ns (default: dist/ns).
#
# Source comes from src/ (a checkout of the ENSL/NS repo). If src/ does not
# exist it is cloned first:
#   NS_GIT_URL  repo to clone          (default: https://github.com/ENSL/NS.git)
#   NS_GIT_REF  branch or tag to clone (default: v3.3b9, the release that
#               current clients run; develop has unreleased bot changes that
#               break clients at round end with "svc_bad")
# An existing src/ is used as-is, never updated or replaced, unless `clean`
# is given: then src/ is deleted and re-cloned. `clean` refuses to delete a
# checkout with uncommitted changes or one that is not a git repo.
#
# The client libraries (cl_dlls/, dlls/ns.dll) come from the release zip that
# players install, not from src/; see the client stage in the Dockerfile
# (--build-arg NS_CLIENT_URL=... NS_CLIENT_SHA256=... for another release).
#
# Uses podman if available, otherwise docker; override with CONTAINER_ENGINE.
# Works with remote podman (Windows/macOS podman machine), which does not
# support `build --output`, by copying out of a created container instead.
#
# Usage: builder/build.sh [clean] [out dir] [extra build args...]
#   e.g. builder/build.sh dist --build-arg CFG=debug
#        builder/build.sh clean
#        NS_GIT_REF=develop builder/build.sh clean
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_dir="$repo_root/src"

clean=0
if [[ "${1:-}" == "clean" || "${1:-}" == "--clean" ]]; then
  clean=1
  shift
fi

out_dir="${1:-$repo_root/dist}"
shift || true

git_url="${NS_GIT_URL:-https://github.com/ENSL/NS.git}"
git_ref="${NS_GIT_REF-v3.3b9}"

if [[ "$clean" == 1 && -e "$src_dir" ]]; then
  if ! git -C "$src_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "error: $src_dir is not a git checkout; not deleting it. Remove it manually to re-clone." >&2
    exit 1
  fi
  if [[ -n "$(git -C "$src_dir" status --porcelain)" ]]; then
    echo "error: $src_dir has uncommitted changes; not deleting it:" >&2
    git -C "$src_dir" status --short >&2
    exit 1
  fi
  echo "clean: removing $src_dir"
  rm -rf "$src_dir"
fi

if [[ ! -d "$src_dir" ]]; then
  echo "No source at $src_dir; cloning $git_url${git_ref:+ ($git_ref)}"
  git clone --depth 1 ${git_ref:+--branch "$git_ref"} "$git_url" "$src_dir"
fi
if [[ ! -d "$src_dir/main/source/linux" ]]; then
  echo "error: $src_dir does not look like an ENSL/NS checkout (missing main/source/linux)" >&2
  exit 1
fi

engine="${CONTAINER_ENGINE:-$(command -v podman >/dev/null && echo podman || echo docker)}"
image="ns-classic-build:latest"

"$engine" build -f "$repo_root/builder/Dockerfile" --target export -t "$image" "$@" "$repo_root"

# The export image is FROM scratch; the command is never run, create just needs one.
container="$("$engine" create "$image" /none)"
trap '"$engine" rm "$container" >/dev/null' EXIT

rm -rf "$out_dir/ns"
mkdir -p "$out_dir"
"$engine" cp "$container:/ns" "$out_dir/ns"

echo "Exported: $out_dir/ns"
