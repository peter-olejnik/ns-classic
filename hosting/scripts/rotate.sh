#!/usr/bin/env bash
# Every ROTATE_INTERVAL seconds (default 300), compress server logs (lz4) and
# HLTV demos (zip) that haven't been written to for ROTATE_AGE minutes
# (default 30), and delete the originals.
set -uo pipefail

ns=/home/steam/hlds/ns
interval="${ROTATE_INTERVAL:-300}"
age="${ROTATE_AGE:-30}"

# rotate <dir> <pattern> <extension> <command...>; the command gets <src> <dest>
rotate() {
  local dir="$1" pattern="$2" ext="$3" f
  shift 3
  find "$dir" -maxdepth 1 -type f -iname "$pattern" -mmin +"$age" -print0 |
    while IFS= read -r -d '' f; do
      if [[ -e "$f.$ext" ]]; then
        echo "skipped: $f ($f.$ext already exists)"
      elif "$@" "$f" "$f.$ext"; then
        rm -f "$f" && echo "rotated: $f"
      fi
    done
}

zip_one() { zip -9 -q -j "$2" "$1"; }

echo "Rotating $ns/logs and $ns/demos every ${interval}s (files older than ${age} min)"
while true; do
  rotate "$ns/logs" '*.log' lz4 lz4 -9 -q
  rotate "$ns/demos" '*.dem' zip zip_one
  sleep "$interval"
done
