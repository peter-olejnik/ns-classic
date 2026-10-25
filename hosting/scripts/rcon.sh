#!/usr/bin/env bash
# Run a server console command over RCON, from inside the hlds container:
#
#   ./rcon.sh status
#   ./rcon.sh sv_botreloadnav
#
# Uses RCON_PASSWORD and HLDS_PORT from the container's environment, so the
# password never leaves the container. Talks GoldSrc RCON over UDP with
# bash's /dev/udp: request a challenge, then send the command with it.
set -euo pipefail

[[ $# -gt 0 ]] || { echo "usage: rcon.sh <command> [args...]" >&2; exit 2; }
[[ -n "${RCON_PASSWORD:-}" ]] || { echo "error: RCON_PASSWORD is not set (hosting/.env)" >&2; exit 1; }

exec 3<>"/dev/udp/127.0.0.1/${HLDS_PORT:-27016}"

# Each reply is one datagram: 4 x 0xff, then the payload
recv() { timeout "$1" dd bs=4096 count=1 status=none <&3 | tail -c +5 | tr -d '\000'; }

printf '\xff\xff\xff\xffchallenge rcon\n' >&3
reply="$(recv 3)" || true
[[ "$reply" =~ ^challenge\ rcon\ ([0-9]+) ]] || { echo "error: no RCON challenge from the server" >&2; exit 1; }

printf '\xff\xff\xff\xffrcon %s "%s" %s\n' "${BASH_REMATCH[1]}" "$RCON_PASSWORD" "$*" >&3

# Output is "l<text>", possibly split over several datagrams
got=0
while out="$(recv 1)" && [[ -n "$out" ]]; do
  printf '%s' "${out#l}"
  got=1
done
(( got )) || { echo "error: no reply to the command" >&2; exit 1; }
echo
