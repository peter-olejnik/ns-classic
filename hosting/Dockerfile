# NS dedicated server image: HLDS (installed with SteamCMD) plus the ns mod
# directory from dist/server/ns (builder/build.sh, then mapmerge/merge.sh).
#
# hosting/build.sh passes the mod directory as the named build context "ns":
#
#   podman build -f hosting/Dockerfile -t localhost/ns-classic-server \
#     --build-context ns=dist/server/ns --build-context plugins=<dir> hosting
#
# and the plugins (e.g. AMX Mod X, plugins/amxmodx/) as "plugins".
#
# The container's command picks its role: hlds (default), hltv or rotate.
# See scripts/entry.sh.

# Fully qualified so Podman on RHEL doesn't need short-name resolution.
# Ubuntu 22.04 or newer: the built ns.so needs glibc 2.33 and GLIBCXX 3.4.29.
ARG BASE_IMAGE=docker.io/library/ubuntu:22.04
ARG STEAMCMD_IMAGE=docker.io/steamcmd/steamcmd:ubuntu-22

# HLDS (app 90). Identical to the hlds stage in mapmerge/Dockerfile, so the
# ~1 GB layer is shared between the two builds.
# app_update is repeated: HLDS often doesn't fully install on the first pass
FROM ${STEAMCMD_IMAGE} AS hlds
RUN for i in 1 2 3; do \
      steamcmd +force_install_dir /hlds +login anonymous \
        +app_set_config 90 mod valve +app_update 90 validate +quit || true; \
    done && \
    test -f /hlds/valve/halflife.wad

# Keep only what the server runs: drop Counter-Strike, the 64-bit libraries
# and Steam's install state. Older HLDS builds shipped their own libstdc++ and
# libgcc_s, which are older than what ns.so needs; remove them should they
# come back, so the system's libraries are used.
FROM hlds AS hlds-files
RUN rm -rf /hlds/cstrike /hlds/linux64 /hlds/steamapps && \
    rm -f /hlds/libstdc++.so* /hlds/libgcc_s.so* && \
    test -x /hlds/hlds_linux && test -x /hlds/hltv

# LD_PRELOAD fix for HLTV, which aborts when it starts recording a demo (see
# hltvfix/hltv_demofix.c)
FROM ${BASE_IMAGE} AS hltvfix
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc gcc-multilib libc6-dev-i386 && \
    rm -rf /var/lib/apt/lists/*
COPY hltvfix/hltv_demofix.c /src/
RUN gcc -m32 -O2 -shared -fPIC -Wall -Werror -o /hltv_demofix.so /src/hltv_demofix.c -ldl

FROM ${BASE_IMAGE} AS server

# GoldSrc is 32-bit only: i386 runtime libraries, no compilers or SteamCMD.
# lz4 and zip compress logs and demos (rotate), tini reaps and forwards signals.
RUN export DEBIAN_FRONTEND=noninteractive && \
    dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      libc6:i386 libstdc++6:i386 libgcc-s1:i386 \
      ca-certificates lz4 zip procps tini && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 steam
USER steam
WORKDIR /home/steam/hlds

COPY --from=hlds-files --chown=steam:steam /hlds ./
# The engine looks for the Steam client library here. HLDS writes
# steam_appid.txt on its first start but fails Steam init ("Unable to
# initialize Steam") until it exists, so every fresh container would crash once.
RUN mkdir -p ~/.steam/sdk32 && \
    ln -s /home/steam/hlds/steamclient.so ~/.steam/sdk32/steamclient.so && \
    echo 70 > steam_appid.txt

# The mod directory (several GB with custom maps); everything after this is
# small, so config and script changes don't copy it again.
COPY --from=ns --chown=steam:steam . ns/
RUN test -f ns/dlls/ns.so && \
    mkdir -p ns/logs ns/demos cores && \
    if LD_LIBRARY_PATH=. ldd hlds_linux engine_i486.so ns/dlls/ns.so | grep 'not found'; then exit 1; fi

# Plugins (PLUGINS in build.sh, each from dist/plugins/<name>), copied over
# the mod directory; the "plugins" context is empty without any. With
# metamod, the engine has to load it instead of ns.so, and metamod loads
# dlls/ns.so (addons/metamod/config.ini). The HL25 engine takes the gamedll
# line and swaps .dll for .so (it ignores gamedll_linux), so both lines are
# pointed at metamod.
COPY --from=plugins --chown=steam:steam . ns/
RUN if [ -f ns/addons/metamod/dlls/metamod.so ]; then \
      sed -i -E \
        -e 's#^([[:space:]]*gamedll)[[:space:]].*#\1 "addons\\metamod\\dlls\\metamod.dll"#' \
        -e 's#^([[:space:]]*gamedll_linux)[[:space:]].*#\1 "addons/metamod/dlls/metamod.so"#' \
        ns/liblist.gam && \
      grep -q '^gamedll "addons.metamod.dlls.metamod.dll"' ns/liblist.gam; \
    fi && \
    # The AMXX plugin compiler; dist/ on a Windows drive loses exec bits
    if [ -f ns/addons/amxmodx/scripting/amxxpc ]; then \
      chmod 755 ns/addons/amxmodx/scripting/amxxpc ns/addons/amxmodx/scripting/*.sh; \
    fi && \
    for f in $(find ns/addons -name '*.so' 2>/dev/null); do \
      if LD_LIBRARY_PATH=. ldd "$f" | grep 'not found'; then echo "$f: missing libraries" >&2; exit 1; fi; \
    done

# Your own configs, copied over the mod directory: anything in overlay/, then
# server.cfg and motd.txt (build.sh creates them from the *.example files)
COPY --chown=steam:steam overlay/ ns/
COPY --chown=steam:steam server.cfg motd.txt ns/
COPY --chown=steam:steam --chmod=755 scripts/entry.sh scripts/rotate.sh scripts/rcon.sh ./
COPY --from=hltvfix /hltv_demofix.so ./

# Game and RCON (UDP), VAC, HLTV
EXPOSE 27016/udp 26900/udp 27020/udp

ENTRYPOINT ["/usr/bin/tini", "--", "/home/steam/hlds/entry.sh"]
CMD ["hlds"]
