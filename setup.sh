#!/usr/bin/env bash
# Interactive setup: choose what to build and run, save the choices as a plan,
# then run it. It only calls the existing scripts, so they all keep working on
# their own.
#
#   ./setup.sh          ask (the saved answers are the defaults), save, run
#   ./setup.sh edit     ask and save, don't run
#   ./setup.sh run      run the saved plan without asking (scripts, servers)
#   ./setup.sh show     print the saved plan and the steps it would run
#
# The plan is plan.env (gitignored): KEY=value lines, choices only, never
# secrets. Server settings go where the server reads them: port, players,
# map, mapcycle and passwords in hosting/.env, hostname and bots in
# hosting/server.cfg.
#
# Steps, in order (each one can be skipped by the plan):
#   build   builder/build.sh     -> dist/ns
#   maps    mapmerge/merge.sh    -> dist/server/ns (custom maps, navgen, content/)
#   amxmodx plugins/amxmodx/build.sh -> dist/plugins/amxmodx (AMX Mod X + Metamod-P)
#   image   hosting/build.sh     -> localhost/ns-classic-server
#   start   compose up -d        (hosting/compose.yaml)
#
# To add an option: give its key a default in PLAN and its allowed values in
# CHOICES, ask it in wizard(), and use it in a plan_<step> function. A new
# step is a plan_<name> function (sets TITLE, DIR, ENVS and CMD, returns 1
# with WHY to skip) listed in STEPS.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plan_file="$repo/plan.env"
hosting="$repo/hosting"
image="localhost/ns-classic-server:latest"

STEPS=(build maps amxmodx image start)

declare -A PLAN=(
  [ENGINE]=auto
  [BUILD]=auto
  [BUILD_CFG]=release
  [NS_GIT_REF]=v3.3b9
  [MAPS]=merge
  [NAVGEN]=off
  [IMAGE]=yes
  [START]=yes
  [HLTV]=no
  [AMXMODX]=off
)
PLAN_KEYS=(ENGINE BUILD BUILD_CFG NS_GIT_REF MAPS NAVGEN AMXMODX IMAGE START HLTV)
declare -A CHOICES=(
  [ENGINE]="auto podman docker"
  [BUILD]="auto always skip"
  [BUILD_CFG]="release debug"
  [MAPS]="merge stock"
  [NAVGEN]="off mapcycle all"
  [IMAGE]="yes no"
  [START]="yes no"
  [HLTV]="yes no"
  [AMXMODX]="off auto always"
)

if [[ -t 1 ]]; then B=$'\e[1m' D=$'\e[2m' R=$'\e[0m'; else B="" D="" R=""; fi
die() { echo "error: $*" >&2; exit 1; }
warn() { echo "warning: $*" >&2; }

# --- plan file ---------------------------------------------------------------

load_plan() {
  [[ -d "$repo/ns_maps" ]] || PLAN[MAPS]=stock
  [[ -f "$plan_file" ]] || return 0
  local line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
    key="${line%%=*}" val="${line#*=}"
    if [[ -z "${PLAN[$key]+x}" ]]; then warn "plan.env: unknown key $key (ignored)"; continue; fi
    PLAN[$key]="$val"
  done < "$plan_file"
}

check_plan() {
  local key
  for key in "${!CHOICES[@]}"; do
    [[ " ${CHOICES[$key]} " == *" ${PLAN[$key]} "* ]] ||
      die "plan.env: $key=${PLAN[$key]} (expected one of: ${CHOICES[$key]})"
  done
}

save_plan() {
  local key
  {
    echo "# ns-classic plan, written by ./setup.sh. Run it with: ./setup.sh run"
    echo "# Choices only; passwords live in hosting/.env."
    for key in "${PLAN_KEYS[@]}"; do echo "$key=${PLAN[$key]}"; done
  } > "$plan_file"
  echo "Saved plan.env"
}

# --- prompts ------------------------------------------------------------------

# pick CURRENT "Question" value "description" [value "description" ...]
# Sets REPLY to the chosen value; Enter keeps CURRENT.
pick() {
  local cur="$1" question="$2"; shift 2
  local -a vals=() descs=()
  while (( $# )); do vals+=("$1"); descs+=("$2"); shift 2; done
  local i def=1 mark ans w=0
  for i in "${vals[@]}"; do (( ${#i} > w )) && w=${#i}; done
  echo
  echo "${B}$question${R}"
  for i in "${!vals[@]}"; do
    mark=" "
    if [[ "${vals[i]}" == "$cur" ]]; then def=$((i + 1)) mark="*"; fi
    printf '  %s%d) %-*s  %s%s%s\n' "$mark" $((i + 1)) "$w" "${vals[i]}" "$D" "${descs[i]}" "$R"
  done
  while :; do
    read -r -p "  Choice [$def]: " ans
    ans="${ans:-$def}"
    if [[ "$ans" =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= ${#vals[@]} )); then
      REPLY="${vals[ans - 1]}"; return
    fi
    for i in "${vals[@]}"; do [[ "$ans" == "$i" ]] && { REPLY="$i"; return; }; done
    echo "  Enter a number from 1 to ${#vals[@]}."
  done
}

# choose KEY "Question" value "description" ...: pick() into PLAN[KEY]
choose() {
  local key="$1"; shift
  pick "${PLAN[$key]}" "$@"
  PLAN[$key]="$REPLY"
}

# ask "Prompt" DEFAULT [REGEX "hint"]: sets REPLY; Enter keeps DEFAULT
ask() {
  local prompt="$1" def="$2" re="${3:-}" hint="${4:-}" ans
  while :; do
    read -r -p "  $prompt [$def]: " ans
    ans="${ans:-$def}"
    if [[ -z "$re" || "$ans" =~ $re ]]; then REPLY="$ans"; return; fi
    echo "  $hint"
  done
}

# confirm "Question" y|n: true for yes
confirm() {
  local ans hint="[y/N]"
  [[ "$2" == y ]] && hint="[Y/n]"
  read -r -p "$1 $hint " ans
  ans="${ans:-$2}"
  [[ "$ans" == [yY]* ]]
}

# --- server settings (hosting/.env, hosting/server.cfg) ----------------------

# env_get KEY: the value compose will use (.env over .env.default)
env_get() {
  local f line val=""
  for f in "$hosting/.env.default" "$hosting/.env"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%$'\r'}"
      [[ "$line" == "$1="* ]] && val="${line#*=}"
    done < "$f"
  done
  printf '%s' "$val"
}

# env_set KEY VALUE: replace KEY's line in hosting/.env, or append it.
# Nothing is written if compose would already see that value.
env_set() {
  [[ "$(env_get "$1")" == "$2" ]] && return 0
  local f="$hosting/.env" tmp
  touch "$f"
  tmp="$(mktemp "$f.XXXXXX")"
  K="$1" V="$2" awk '
    BEGIN { k = ENVIRON["K"] "="; done = 0 }
    { sub(/\r$/, "") }
    index($0, k) == 1 { if (!done) print k ENVIRON["V"]; done = 1; next }
    { print }
    END { if (!done) print k ENVIRON["V"] }' "$f" > "$tmp"
  mv "$tmp" "$f"
  CHANGED+=("hosting/.env: $1")
}

cfg_file() {
  local f="$hosting/server.cfg"
  [[ -f "$f" ]] || cp "$hosting/server.cfg.example" "$f"
  printf '%s' "$f"
}

# cfg_get NAME: a cvar's value in hosting/server.cfg, without quotes
cfg_get() {
  awk -v k="$1" '{ sub(/\r$/, "") } $1 == k { $1 = ""; v = $0 } END { sub(/^ +/, "", v); gsub(/"/, "", v); print v }' "$(cfg_file)"
}

# cfg_set NAME VALUE: replace the cvar's line in hosting/server.cfg, or append it
cfg_set() {
  [[ "$(cfg_get "$1")" == "${2//\"/}" ]] && return 0
  local f tmp
  f="$(cfg_file)"
  tmp="$(mktemp "$f.XXXXXX")"
  K="$1" V="$2" awk '
    BEGIN { k = ENVIRON["K"]; done = 0 }
    { sub(/\r$/, "") }
    $1 == k { if (!done) print k " " ENVIRON["V"]; done = 1; next }
    { print }
    END { if (!done) print k " " ENVIRON["V"] }' "$f" > "$tmp"
  mv "$tmp" "$f"
  CHANGED+=("hosting/server.cfg: $1")
}

# opt_get NAME OPTS: the value of +NAME in an HLDS_OPTS string
opt_get() {
  local re="(^|[[:space:]])\\+$1[[:space:]]+([^[:space:]]+)"
  if [[ "$2" =~ $re ]]; then printf '%s' "${BASH_REMATCH[2]}"; fi
}

# opt_set NAME VALUE OPTS: OPTS with +NAME set in place (removed if VALUE is
# empty); a new +map goes last, anything else first.
opt_set() {
  local name="$1" val="$2" opts="$3" re="^(.*[[:space:]])?\\+$1[[:space:]]+[^[:space:]]+(.*)$"
  local -a words
  if [[ "$opts" =~ $re ]]; then
    opts="${BASH_REMATCH[1]}${val:++$name $val}${BASH_REMATCH[2]}"
  elif [[ -n "$val" && "$name" == map ]]; then
    opts="$opts +$name $val"
  elif [[ -n "$val" ]]; then
    opts="+$name $val $opts"
  fi
  read -r -a words <<< "$opts"
  printf '%s' "${words[*]}"
}

# password NAME "what": prompt without echo; Enter keeps, "-" clears
password() {
  local cur ans state=empty
  cur="$(env_get "$1")"
  [[ -n "$cur" ]] && state=set
  while :; do
    read -r -s -p "  $2 (currently $state; Enter keeps it, - clears it): " ans
    echo
    case "$ans" in
      "") return ;;
      -) env_set "$1" ""; return ;;
      *[[:space:]\"\'#]*) echo "  No spaces, quotes or #, please (hosting/.env can't hold them)." ;;
      *) env_set "$1" "$ans"; return ;;
    esac
  done
}

settings_wizard() {
  local opts cycle size note f
  local -a args
  echo
  echo "${B}Server settings${R} ${D}(written to hosting/.env and hosting/server.cfg)${R}"

  ask "Server name" "$(cfg_get hostname)" '^[^"]+$' "No double quotes, please."
  cfg_set hostname "\"$REPLY\""
  ask "Game port (UDP)" "$(env_get HLDS_PORT)" '^[0-9]{2,5}$' "Enter a port number."
  env_set HLDS_PORT "$REPLY"

  opts="$(env_get HLDS_OPTS)"
  ask "Max players" "$(opt_get maxplayers "$opts")" '^([1-9]|[12][0-9]|3[0-2])$' "Enter 1 to 32."
  opts="$(opt_set maxplayers "$REPLY" "$opts")"
  ask "Start map" "$(opt_get map "$opts")" '^[A-Za-z0-9_.-]+$' "Enter a map name, e.g. ns_veil."
  [[ -f "$repo/dist/server/ns/maps/$REPLY.bsp" || -f "$repo/dist/ns/maps/$REPLY.bsp" ]] ||
    echo "  ${D}(no maps/$REPLY.bsp in dist/ yet; make sure it exists)${R}"
  opts="$(opt_set map "$REPLY" "$opts")"

  if [[ "${PLAN[MAPS]}" == merge ]]; then
    cycle="$(opt_get mapcyclefile "$opts")"
    args=()
    for f in mapcycle.txt:"stock maps only" mapcycle.ns.txt:"ns_ maps, one version each" \
             mapcycle.co.txt:"co_ maps, one version each" mapcycle.siege.txt:"siege maps, one version each" \
             mapcycle.all.txt:"every map, all versions" mapcycle.original.txt:"stock list, player limits rewritten"; do
      note="${f#*:}"
      size="$(wc -c 2>/dev/null < "$repo/dist/server/ns/${f%%:*}" || true)"
      if [[ -n "$size" ]] && (( size > 8192 )); then note="$note (over 8 KB: HLTV can't connect)"; fi
      args+=("${f%%:*}" "$note")
    done
    pick "${cycle:-mapcycle.txt}" "Mapcycle" "${args[@]}"
    [[ "$REPLY" == mapcycle.txt ]] && REPLY=""
    opts="$(opt_set mapcyclefile "$REPLY" "$opts")"
  fi
  env_set HLDS_OPTS "$opts"

  pick "$([[ "$(cfg_get mp_botsenabled)" == 1 ]] && echo on || echo off)" "Bots" \
    on "they play on maps with a navmesh (see navgen)" off ""
  cfg_set mp_botsenabled "$([[ "$REPLY" == on ]] && echo 1 || echo 0)"

  echo
  echo "${B}Passwords${R} ${D}(hosting/.env only, never plan.env)${R}"
  password RCON_PASSWORD "RCON password"
  password SV_PASSWORD "Join password"
  [[ -n "$(env_get RCON_PASSWORD)" ]] ||
    echo "  ${D}No RCON password: remote admin and hosting/push-content.sh won't work.${R}"
}

wizard() {
  [[ -t 0 ]] || die "the wizard needs a terminal; use ./setup.sh run for the saved plan"
  CHANGED=()
  echo "${B}ns-classic setup${R}  ${D}Enter keeps the current choice (*).${R}"

  choose ENGINE "Container engine" \
    auto "podman if installed, otherwise docker" podman "" docker ""

  choose BUILD "Build the server binary (builder/ -> dist/ns)" \
    auto "only if dist/ns is missing" \
    always "every run (cached layers make an unchanged build quick)" \
    skip "never; use the existing dist/ns"
  if [[ "${PLAN[BUILD]}" != skip ]]; then
    choose BUILD_CFG "Build type" release "" debug "with debug info"
    if [[ ! -d "$repo/src" ]]; then
      echo; echo "src/ is missing, so the build clones ENSL/NS first."
      ask "Branch or tag to clone (keep v3.3b9: clients run that release)" "${PLAN[NS_GIT_REF]}"
      PLAN[NS_GIT_REF]="$REPLY"
    fi
  fi

  choose MAPS "Maps" \
    merge "stock + custom maps from ns_maps/, plus content/ (mapmerge/)" \
    stock "stock maps only (dist/ns; no ns_maps/, no content/)"
  if [[ "${PLAN[MAPS]}" == merge ]]; then
    [[ -d "$repo/ns_maps" ]] || echo "  ${D}ns_maps/ doesn't exist yet: create it and put map archives in it.${R}"
    choose NAVGEN "Generate bot navmeshes for maps without one (navgen/; cached)" \
      off "" mapcycle "maps in mapcycle.ns/co/siege.txt" all "every map (the first run takes long)"
  fi

  choose AMXMODX "AMX Mod X (admin commands, votes, plugins; with Metamod-P, built from source)" \
    off "" \
    auto "build once from the latest upstream source, then reuse it" \
    always "rebuild from the latest upstream source every run (cached if unchanged)"

  choose IMAGE "Build the server image (hosting/)" \
    yes "needed after any build, merge or settings change" no ""
  choose START "Start or update the server (compose up -d)" yes "" no ""
  if [[ "${PLAN[START]}" == yes ]]; then
    choose HLTV "HLTV (spectator proxy, records demos)" yes "" no "stopped if it's running"
  fi

  echo
  local def=n
  [[ -f "$hosting/.env" ]] || def=y
  if confirm "${B}Change server settings${R} (name, port, players, map, mapcycle, bots, passwords)?" "$def"; then
    settings_wizard
  fi
  if (( ${#CHANGED[@]} )); then
    echo
    printf 'Updated %s\n' "${CHANGED[@]}"
    if [[ "${PLAN[IMAGE]}" == no ]]; then
      echo "  ${D}server.cfg is baked into the image: rebuild it (image step) to apply changes there.${R}"
    fi
  fi
  echo
  save_plan
}

# --- steps ---------------------------------------------------------------------
# plan_<step> sets TITLE, DIR (run from), ENVS (VAR=value) and CMD, and
# returns 1 with WHY set when the step doesn't run.

engine() {
  if [[ "${PLAN[ENGINE]}" != auto ]]; then echo "${PLAN[ENGINE]}"
  elif command -v podman >/dev/null; then echo podman
  else echo docker; fi
}

ns_dir() {
  if [[ "${PLAN[MAPS]}" == merge ]]; then echo dist/server/ns; else echo dist/ns; fi
}

plan_build() {
  TITLE="Build the server binary -> dist/ns" DIR="$repo"
  ENVS=("NS_GIT_REF=${PLAN[NS_GIT_REF]}")
  CMD=(builder/build.sh dist --build-arg "CFG=${PLAN[BUILD_CFG]}")
  case "${PLAN[BUILD]}" in
    skip) WHY="BUILD=skip"; return 1 ;;
    auto) if [[ -f "$repo/dist/ns/dlls/ns.so" ]]; then WHY="dist/ns exists (BUILD=auto)"; return 1; fi ;;
  esac
}

plan_maps() {
  TITLE="Merge custom maps -> dist/server/ns" DIR="$repo" ENVS=()
  CMD=(mapmerge/merge.sh)
  case "${PLAN[NAVGEN]}" in
    mapcycle) CMD+=(--navgen); TITLE+=" + navmeshes for mapcycle maps" ;;
    all) CMD+=(--navgen-all); TITLE+=" + navmeshes for all maps" ;;
  esac
  if [[ "${PLAN[MAPS]}" == stock ]]; then WHY="MAPS=stock"; return 1; fi
}

plan_amxmodx() {
  TITLE="Build AMX Mod X + Metamod-P -> dist/plugins/amxmodx" DIR="$repo" ENVS=()
  CMD=(plugins/amxmodx/build.sh)
  case "${PLAN[AMXMODX]}" in
    off) WHY="AMXMODX=off"; return 1 ;;
    auto) if [[ -d "$repo/dist/plugins/amxmodx" ]]; then WHY="dist/plugins/amxmodx exists (AMXMODX=auto)"; return 1; fi ;;
  esac
}

# The plugins the image gets (hosting/build.sh PLUGINS), in order
plugins() {
  local -a p=()
  [[ "${PLAN[AMXMODX]}" == off ]] || p+=(amxmodx)
  echo "${p[*]}"
}

plan_image() {
  TITLE="Build the server image from $(ns_dir)" DIR="$repo"
  ENVS=("NS_DIR=$repo/$(ns_dir)")
  if [[ -n "$(plugins)" ]]; then ENVS+=("PLUGINS=$(plugins)"); TITLE+=" + $(plugins)"; fi
  CMD=(hosting/build.sh)
  if [[ "${PLAN[IMAGE]}" == no ]]; then WHY="IMAGE=no"; return 1; fi
}

plan_start() {
  TITLE="Start or update the server" DIR="$hosting" ENVS=()
  CMD=("$(engine)" compose)
  if [[ "${PLAN[HLTV]}" == yes ]]; then CMD+=(--profile hltv); TITLE+=" with HLTV"; fi
  CMD+=(up -d)
  if [[ "${PLAN[START]}" == no ]]; then WHY="START=no"; return 1; fi
}

show_steps() {
  local step n=0
  for step in "${STEPS[@]}"; do
    if "plan_$step"; then
      n=$((n + 1))
      printf '  %d. %s\n     %s%s%s\n' "$n" "$TITLE" "$D" "${ENVS[*]:+${ENVS[*]//"$repo/"/} }${CMD[*]}" "$R"
    else
      printf '  -  %s%s (skipped: %s)%s\n' "$D" "$TITLE" "$WHY" "$R"
    fi
  done
  (( n )) || echo "  Nothing to run."
}

show() {
  echo "${B}Plan${R} ${D}(plan.env)${R}"
  local key
  for key in "${PLAN_KEYS[@]}"; do printf '  %-11s %s\n' "$key" "${PLAN[$key]}"; done
  echo
  echo "${B}Steps${R}"
  show_steps
}

# Fail early on what would only break a later step
preflight() {
  local e
  e="$(engine)"
  command -v "$e" >/dev/null || die "$e not found (set ENGINE in ./setup.sh edit)"
  "$e" info >/dev/null 2>&1 ||
    die "$e isn't responding. On Windows or macOS, start the machine: podman machine start"
  if plan_maps; then
    [[ -d "$repo/ns_maps" ]] || die "ns_maps/ not found: create it (it can be empty) or choose MAPS=stock"
  fi
  if ! plan_build && [[ "${PLAN[BUILD]}" == skip ]]; then
    if plan_maps || plan_image; then
      [[ -f "$repo/dist/ns/dlls/ns.so" ]] || die "dist/ns is missing and BUILD=skip"
    fi
  fi
  if ! plan_maps && plan_image && [[ "${PLAN[MAPS]}" == merge && ! -d "$repo/dist/server/ns" ]]; then
    die "dist/server/ns is missing"
  fi
  if plan_amxmodx; then
    command -v git >/dev/null || die "git not found (plugins/amxmodx/build.sh looks up the latest commits)"
  elif [[ "${PLAN[AMXMODX]}" != off ]] && plan_image && [[ ! -d "$repo/dist/plugins/amxmodx" ]]; then
    die "dist/plugins/amxmodx is missing"
  fi
  if ! plan_image && plan_start; then
    "$e" image inspect "$image" >/dev/null 2>&1 || die "no $image yet: set IMAGE=yes"
  fi
}

run_plan() {
  check_plan
  preflight
  export CONTAINER_ENGINE
  CONTAINER_ENGINE="$(engine)"
  local step n=0 start
  for step in "${STEPS[@]}"; do
    "plan_$step" || continue
    n=$((n + 1))
    echo
    echo "${B}==> $n. $TITLE${R}"
    echo "${D}    ${CMD[*]}${R}"
    start=$SECONDS
    if ! (cd "$DIR" && env "${ENVS[@]}" "${CMD[@]}"); then
      die "step '$step' failed (fix it, then re-run: ./setup.sh run)"
    fi
    echo "${D}    done in $((SECONDS - start)) s${R}"
  done

  # HLTV off in the plan: stop it if an earlier run started it
  if plan_start && [[ "${PLAN[HLTV]}" == no ]] &&
     "$CONTAINER_ENGINE" ps -a --format '{{.Names}}' 2>/dev/null | grep -qx ns-classic-hltv-1; then
    echo "Stopping HLTV (HLTV=no)"
    (cd "$hosting" && "$CONTAINER_ENGINE" compose --profile hltv rm -sf hltv)
  fi

  echo
  echo "${B}Done.${R}"
  if plan_start; then
    echo "  Server: UDP port $(env_get HLDS_PORT)$([[ "${PLAN[HLTV]}" == yes ]] && echo ", HLTV on $(env_get HLTV_PORT)")"
    echo "  Console: $CONTAINER_ENGINE attach ns-classic-hlds-1   (detach: Ctrl-P Ctrl-Q)"
    echo "  Logs:    cd hosting && $CONTAINER_ENGINE compose logs -f hlds"
  fi
}

load_plan
case "${1:-}" in
  "")
    wizard
    echo
    show_steps
    echo
    if confirm "Run this plan now?" y; then run_plan; else echo "Run it later with: ./setup.sh run"; fi
    ;;
  edit) wizard ;;
  run)
    [[ -f "$plan_file" ]] || die "no plan.env yet: run ./setup.sh first"
    run_plan
    ;;
  show) check_plan; show ;;
  -h|--help|help) sed -n '2,/^set -euo/{/^set -euo/d;s/^# \{0,1\}//;p}' "${BASH_SOURCE[0]}" ;;
  *) die "unknown command '$1' (try ./setup.sh help)" ;;
esac
