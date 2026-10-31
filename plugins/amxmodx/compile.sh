#!/bin/sh
# Compiles the custom plugins and installs the plugin list (Dockerfile,
# "scripts" stage):
#
#   compile.sh <scripting dir> <prebuilt dir> <plugins.ini> <amxmodx dir>
#
# Every <scripting dir>/*.sma is compiled with the AMXX compiler and includes
# in <amxmodx dir>/scripting, plus <scripting dir>/include, into
# <amxmodx dir>/plugins. A script that doesn't compile is left out and listed,
# but doesn't fail the build. The sources go to scripting/ as well, so they
# can be recompiled in the container.
#
# <prebuilt dir>/*.amxx are plugins with no source, installed as they are
# (first, so a compiled .sma of the same name replaces one).
#
# <plugins.ini> becomes configs/plugins.ini. An enabled entry whose .amxx
# wasn't built is commented out with "[not built]", so AMXX doesn't log a
# load failure for it every map.
#
# The report, with each failed script's compiler output, is
# <amxmodx dir>/scripting/ns-classic-compile.txt.
set -eu
src=$1 prebuilt=$2 ini=$3 amxx=$4
sc="$amxx/scripting"
report="$sc/ns-classic-compile.txt"
logs=$(mktemp -d)

for f in "$prebuilt"/*.amxx; do
  [ -e "$f" ] && cp "$f" "$amxx/plugins/"
done

mkdir -p "$sc/include"
cp "$src"/*.sma "$sc/"
[ -d "$src/include" ] && cp "$src"/include/*.inc "$sc/include/"

built=0 failed=""
cd "$sc"
for f in "$src"/*.sma; do
  name=$(basename "$f" .sma)
  # amxxpc's exit status isn't reliable on errors; the output file is
  rm -f "$amxx/plugins/$name.amxx"
  ./amxxpc "$f" -i"$sc/include" -o"$amxx/plugins/$name.amxx" > "$logs/$name.log" 2>&1 || true
  if [ -s "$amxx/plugins/$name.amxx" ]; then
    built=$((built + 1))
  else
    rm -f "$amxx/plugins/$name.amxx"
    failed="$failed $name"
  fi
done

{
  echo "Built $built custom plugins."
  if [ -n "$failed" ]; then
    echo "Not built:$failed"
    for name in $failed; do
      echo
      echo "== $name.sma"
      grep -E 'error|fatal' "$logs/$name.log" | head -20
    done
  fi
} > "$report"

# The plugin list; enabled entries without a built .amxx are commented out
awk -v dir="$amxx/plugins" '
  {
    line = $0; sub(/\r$/, "", line)
    if (match(line, /^[ \t]*[^; \t]+\.amxx/)) {
      file = substr(line, RSTART, RLENGTH); gsub(/^[ \t]+/, "", file)
      if (system("test -f \"" dir "/" file "\"") != 0) {
        print ";" line "\t; [not built]"
        next
      }
    }
    print line
  }' "$ini" > "$amxx/configs/plugins.ini"

rm -rf "$logs"
cat "$report"
