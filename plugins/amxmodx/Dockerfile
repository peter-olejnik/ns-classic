# AMX Mod X with Metamod-P, built from source, exported as an overlay for the
# ns mod directory: /ns/addons/{metamod,amxmodx}.
#
# plugins/amxmodx/build.sh resolves each repo's ref (default: the latest
# commit of the default branch) to a commit and passes it as a build arg, so
# the clone layers are rebuilt exactly when upstream changes:
#
#   metamod-p     Bots-United/metamod-p, the metamod the server runs (it has
#                 the HL25 engine API additions and knows NS's dlls/ns.so)
#   amxmodx       alliedmodders/amxmodx (AMBuild), base + ns packages
#   metamod-hl1   alliedmodders/metamod-hl1: only headers for the AMXX build
#   hlsdk         alliedmodders/hlsdk: headers for the AMXX build
#   ambuild       alliedmodders/ambuild: AMXX's build tool
#
# The engine loads metamod instead of dlls/ns.so; hosting/Dockerfile points
# liblist.gam at it when the overlay has addons/metamod/dlls/metamod.so.

ARG BASE_IMAGE=docker.io/library/ubuntu:22.04

FROM ${BASE_IMAGE} AS toolchain
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential gcc-multilib g++-multilib nasm make \
      git ca-certificates python3 python3-pip python3-setuptools && \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=755 fetch.sh /usr/local/bin/fetch

FROM toolchain AS metamod
ARG METAMOD_GIT_URL=https://github.com/Bots-United/metamod-p.git
ARG METAMOD_COMMIT
RUN test -n "$METAMOD_COMMIT" && fetch "$METAMOD_GIT_URL" "$METAMOD_COMMIT" /src/metamod-p
WORKDIR /src/metamod-p
# CC explicitly: the Makefile's "CC ?= gcc -m32" loses to make's built-in CC
RUN make -j"$(nproc)" -C metamod OPT=opt CC="gcc -m32" && \
    test -f metamod/opt.linux_i386/metamod.so

FROM toolchain AS amxmodx
ARG AMBUILD_GIT_URL=https://github.com/alliedmodders/ambuild.git
ARG AMBUILD_COMMIT
ARG HLSDK_GIT_URL=https://github.com/alliedmodders/hlsdk.git
ARG HLSDK_COMMIT
ARG METAMOD_HL1_GIT_URL=https://github.com/alliedmodders/metamod-hl1.git
ARG METAMOD_HL1_COMMIT
RUN test -n "$AMBUILD_COMMIT" && test -n "$HLSDK_COMMIT" && test -n "$METAMOD_HL1_COMMIT" && \
    fetch "$AMBUILD_GIT_URL" "$AMBUILD_COMMIT" /src/ambuild && \
    pip3 install --no-cache-dir /src/ambuild && \
    fetch "$HLSDK_GIT_URL" "$HLSDK_COMMIT" /src/hlsdk && \
    fetch "$METAMOD_HL1_GIT_URL" "$METAMOD_HL1_COMMIT" /src/metamod-am
# Full commit history (but no old file contents): the version number is the
# commit count (support/generate_headers.py)
ARG AMXMODX_GIT_URL=https://github.com/alliedmodders/amxmodx.git
ARG AMXMODX_COMMIT
RUN test -n "$AMXMODX_COMMIT" && \
    git clone -q --filter=blob:none --no-checkout "$AMXMODX_GIT_URL" /src/amxmodx && \
    git -C /src/amxmodx checkout -q "$AMXMODX_COMMIT" && \
    git -C /src/amxmodx submodule update -q --init --recursive
# Local fixes, in name order (git diffs against the LF-normalized upstream
# tree). 0001: the ns module takes its field offsets from dlls/ns.so.offsets
# (written by builder/) and its functions from ns.so's symbols, instead of
# NS 3.2 constants that misread or crash our NS 3.3 ns.so.
COPY patches/ /patches/
RUN for p in /patches/*.patch; do \
      [ -e "$p" ] || continue; \
      echo "Applying ${p##*/}"; \
      git -C /src/amxmodx apply --whitespace=nowarn "$p" || exit 1; \
    done
# MySQL is left out: its 32-bit client libraries are a separate ~200 MB
# download (support/checkout-deps.sh). SQLite works without it.
# Upstream builds with GCC 8 and -Werror. GCC 11 flags a false positive in
# the bundled SQLite (sqlite3SelectNew's "standin"), so that warning is off
# for C files. It goes in CC: AMBuild runs CC's words for every C compile,
# while CFLAGS from the environment only reaches its compiler detection.
WORKDIR /src/amxmodx/build
RUN CC="gcc -Wno-return-local-addr" CXX=g++ python3 ../configure.py --enable-optimize --no-mysql \
      --metamod=/src/metamod-am --hlsdk=/src/hlsdk && \
    ambuild && \
    test -f packages/base/addons/amxmodx/dlls/amxmodx_mm_i386.so && \
    test -f packages/ns/addons/amxmodx/modules/ns_amxx_i386.so

# The overlay: AMXX's base package, then its ns package (NS configs, plugins
# and module) over it, metamod and its configs
FROM toolchain AS package
COPY --from=amxmodx /src/amxmodx/build/packages/base/ /ns/
COPY --from=amxmodx /src/amxmodx/build/packages/ns/ /ns/
COPY --from=metamod /src/metamod-p/metamod/opt.linux_i386/metamod.so /ns/addons/metamod/dlls/
COPY files/ /ns/
ARG METAMOD_GIT_URL=https://github.com/Bots-United/metamod-p.git
ARG METAMOD_COMMIT
ARG AMXMODX_GIT_URL=https://github.com/alliedmodders/amxmodx.git
ARG AMXMODX_COMMIT
ARG AMBUILD_COMMIT
ARG HLSDK_COMMIT
ARG METAMOD_HL1_COMMIT
RUN printf '%s %s\n' \
      metamod-p "$METAMOD_GIT_URL $METAMOD_COMMIT" \
      amxmodx "$AMXMODX_GIT_URL $AMXMODX_COMMIT" \
      ambuild "$AMBUILD_COMMIT" hlsdk "$HLSDK_COMMIT" metamod-hl1 "$METAMOD_HL1_COMMIT" \
      > /ns/addons/amxmodx/ns-classic-sources.txt && \
    for f in $(find /ns -name '*.so'); do \
      if ldd "$f" | grep 'not found'; then echo "$f: missing libraries" >&2; exit 1; fi; \
    done

# Custom plugins: every scripting/*.sma, compiled with the compiler and
# includes built above (plus scripting/include), and prebuilt/*.amxx (old
# plugins without source) as they are. Then plugins.ini, which
# enables or disables each plugin, as configs/plugins.ini. A script that
# doesn't compile is left out and listed in scripting/ns-classic-compile.txt.
FROM package AS scripts
COPY --chmod=755 compile.sh /usr/local/bin/compile-plugins
COPY scripting/ /src/scripting/
COPY prebuilt/ /src/prebuilt/
COPY plugins.ini /src/plugins.ini
RUN compile-plugins /src/scripting /src/prebuilt /src/plugins.ini /ns/addons/amxmodx

FROM scratch AS export
COPY --from=scripts /ns /ns
