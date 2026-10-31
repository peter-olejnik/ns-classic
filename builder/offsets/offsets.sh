#!/bin/sh
# Writes ns.so.offsets for the ns.so just built: its GNU build ID, then the
# field offsets ns_offsets.cpp prints. Run in main/source/linux after the
# ns build, with that build's CFG and CC:
#
#   offsets.sh <CFG> <CC> <ns_offsets.cpp> <out file>
#
# The dumper is compiled with ns.so's exact compile line, taken from a make
# dry run for one of its sources, so the class layout is the same.
set -eu
cfg=$1 cc=$2 src=$3 out=$4

# The top-level make only prints the sub-make; dry-run that one too
sub=$(make -Bn CFG="$cfg" ns CC="\"$cc\"" | grep '^make .*-f Makefile.nsdll ' | sed 's/^make /make -Bn /')
[ -n "$sub" ] || { echo "offsets.sh: no Makefile.nsdll sub-make in the dry run" >&2; exit 1; }
line=$(eval "$sub" | grep -e ' -c \.\./mod/AvHGamerules\.cpp$')
[ -n "$line" ] || { echo "offsets.sh: no compile line for mod/AvHGamerules.cpp" >&2; exit 1; }

# Same directory as AvHGamerules.cpp, so its includes resolve the same way
cp "$src" ../mod/ns_offsets.cpp
eval "$(printf '%s\n' "$line" | sed 's# -o [^ ]* -c \.\./mod/AvHGamerules\.cpp$# -o /tmp/ns_offsets ../mod/ns_offsets.cpp -lstdc++#')"
rm ../mod/ns_offsets.cpp

id=$(readelf -n "$cfg/ns.so" | sed -n 's/^ *Build ID: *//p')
[ -n "$id" ] || { echo "offsets.sh: $cfg/ns.so has no GNU build ID" >&2; exit 1; }
{
  echo "build_id $id"
  /tmp/ns_offsets
} > "$out"
cat "$out"
