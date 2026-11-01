#!/bin/sh
# Build time (Dockerfile), after config/ is copied over the mod directory:
#
#   plugin-lists.sh <amxmodx dir>
#
# In AMXX's plugin lists (configs/plugins.ini, configs/plugins-*.ini and the
# per-map configs/maps/plugins-<map>.ini), an entry whose .amxx isn't in
# plugins/ (a script that didn't compile, a plugin that was removed) is
# commented out with "[not built]", so AMXX doesn't log a load failure for it
# every map. Does nothing without AMXX.
set -eu
amxx=$1
[ -d "$amxx/configs" ] || exit 0

for ini in "$amxx"/configs/plugins.ini "$amxx"/configs/plugins-*.ini "$amxx"/configs/maps/plugins-*.ini; do
  [ -f "$ini" ] || continue
  awk -v dir="$amxx/plugins" '
    {
      line = $0; sub(/\r$/, "", line)
      if (match(line, /^[ \t]*[^; \t]+\.amxx/)) {
        file = substr(line, RSTART, RLENGTH); gsub(/^[ \t]+/, "", file)
        if (system("test -f \"" dir "/" file "\"") != 0) {
          print ";" line "\t; [not built]"
          n++
          next
        }
      }
      print line
    }
    END { if (n) printf "%s: %d entries not built\n", FILENAME, n > "/dev/stderr" }' "$ini" > "$ini.tmp"
  mv "$ini.tmp" "$ini"
done
