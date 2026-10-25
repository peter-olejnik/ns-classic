#!/usr/bin/env bash
# Container entrypoint. The first argument picks the role:
#
#   hlds    the NS dedicated server (default)
#   hltv    the HLTV proxy, connected to the hlds service
#   rotate  compress old logs and demos (see rotate.sh)
#
# Anything else is run as a command, e.g. `bash`. Extra arguments after hlds
# or hltv are appended to the command line. Settings come from the
# environment (hosting/.env.default, overridden by hosting/.env).
set -euo pipefail

cd /home/steam/hlds
export LD_LIBRARY_PATH=".${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

role="${1:-hlds}"
(( $# )) && shift

case "$role" in
  hlds)
    # Run another server binary than the built dlls/ns.so for comparison, e.g.
    # a release ns.so added as overlay/dlls/ns_v33b9.so. The engine derives the
    # library from liblist.gam's gamedll (dlls\ns.dll -> dlls/ns.so) and ignores
    # gamedll_linux, so the chosen binary is put in place as dlls/ns.so. This
    # only changes the container; the built one is kept as dlls/ns.so.built.
    if [[ -n "${NS_GAMEDLL:-}" ]]; then
      [[ -f "ns/$NS_GAMEDLL" ]] || { echo "error: NS_GAMEDLL: ns/$NS_GAMEDLL not found" >&2; exit 1; }
      [[ -f ns/dlls/ns.so.built ]] || cp ns/dlls/ns.so ns/dlls/ns.so.built
      cp -f "ns/$NS_GAMEDLL" ns/dlls/ns.so
      echo "Using server binary $NS_GAMEDLL"
    elif [[ -f ns/dlls/ns.so.built ]]; then
      cp -f ns/dlls/ns.so.built ns/dlls/ns.so
    fi
    args=(-game ns -port "${HLDS_PORT:-27016}")
    # Secrets come from the environment, not from configs baked into the image
    [[ -n "${RCON_PASSWORD:-}" ]] && args+=(+rcon_password "$RCON_PASSWORD")
    [[ -n "${SV_PASSWORD:-}" ]] && args+=(+sv_password "$SV_PASSWORD")
    # HLDS_OPTS is split into words on purpose
    # shellcheck disable=SC2206
    args+=(${HLDS_OPTS:-} "$@")
    echo "Starting HLDS on port ${HLDS_PORT:-27016}: ${HLDS_OPTS:-} $*"
    exec ./hlds_linux "${args[@]}"
    ;;
  hltv)
    # Give the server time to load its map
    sleep "${HLTV_DELAY:-10}"
    args=(-port "${HLTV_PORT:-27020}")
    [[ -n "${SV_PASSWORD:-}" ]] && args+=(+serverpassword "$SV_PASSWORD")
    # shellcheck disable=SC2206
    args+=(${HLTV_OPTS:-} +connect "${HLTV_CONNECT:-hlds:${HLDS_PORT:-27016}}" "$@")
    echo "Starting HLTV"
    # Fixes the crash when HLTV starts recording a demo (hltvfix/hltv_demofix.c)
    LD_PRELOAD="/home/steam/hlds/hltv_demofix.so${LD_PRELOAD:+:$LD_PRELOAD}" exec ./hltv "${args[@]}"
    ;;
  rotate)
    exec ./rotate.sh
    ;;
  *)
    exec "$role" "$@"
    ;;
esac
