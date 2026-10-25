# Builds the Natural Selection Linux server binary from src/main/source and
# exports a server-ready `ns` mod directory to the host.
#
# Run from the repo root:
#
#   builder/build.sh                              (podman or docker, incl. remote podman)
#   podman build -f builder/Dockerfile -o dist .  (local engines only; remote
#                                                  podman doesn't support --output)
#
# Result: dist/ns/ (mod content + freshly compiled dlls/ns.so), ready to be
# placed next to an HLDS install as <hlds>/ns.

# Fully qualified so Podman on RHEL doesn't need short-name resolution
ARG BASE_IMAGE=docker.io/library/ubuntu:22.04

FROM ${BASE_IMAGE} AS toolchain

ARG DEBIAN_FRONTEND=noninteractive

# 32-bit toolchain (GoldSrc/HLDS are i386 only), per src/README.md "Compiling"
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gcc-multilib \
    g++-multilib \
    libc6-dev-i386 \
    mesa-common-dev \
    dos2unix \
    patch && \
    rm -rf /var/lib/apt/lists/*

FROM toolchain AS build

# release | debug
ARG CFG=release

# /src mirrors the root of the ENSL/NS repo (src/ in this repo), so patches
# use repo-relative paths (a/main/source/...) and apply equally to a git clone.
WORKDIR /src
COPY src/main/source ./main/source
COPY builder/patches /patches

# Normalize line endings to LF (a Windows checkout has CRLF; make passes a
# trailing \r into recipe commands, and patches are written against LF).
# dos2unix skips binary files. Then apply local fixes in order.
RUN find main/source -type f -print0 | xargs -0 dos2unix -q && \
    for p in /patches/*.patch; do \
      [ -e "$p" ] || continue; \
      echo "Applying ${p##*/}"; \
      patch -p1 --batch --forward --fuzz=0 < "$p" || exit 1; \
    done

# `particles` produces libparticleMP.a, which the `ns` target links against.
# The client library (hl_cdll) is not needed for hosting and is not built.
# SLIBB override: upstream uses `ar clq`, but binutils >= 2.36 treats `l` as
# the libdeps option and fails.
# CC override: pin C++11 (as upstream already does for the client). GCC >= 11
# defaults to C++17, whose std::byte clashes with the engine's `byte` typedef.
WORKDIR /src/main/source/linux
RUN make CFG=${CFG} particles SLIBB='ar cqs $@ $(POBJS)' && \
    make CFG=${CFG} ns CC='"gcc -m32 -std=c++11"' && \
    test -f ${CFG}/ns.so

# Client libraries from the release that players install. The server precaches
# cl_dlls/client.{dll,so} and dlls/ns.dll for its consistency check
# (mp_consistency 1) and kicks players whose copies differ from the server's
# ("Your NS version differs from the server's"). They're not in git, and a
# client built here wouldn't match the release byte for byte, so they come
# from the release zip, pinned by checksum. Keep this on the release clients
# run, whatever NS_GIT_REF the server is built from.
FROM ${BASE_IMAGE} AS client
ARG NS_CLIENT_URL=https://github.com/ENSL/NS/releases/download/v3.3b9/ns_v33b9_patch.zip
ARG NS_CLIENT_SHA256=285c8d4f6191d0080810687d6dc11dc96de59c6caa2339d7e047390544d56410
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl unzip && \
    rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /release.zip "$NS_CLIENT_URL" && \
    echo "$NS_CLIENT_SHA256  /release.zip" | sha256sum -c - && \
    unzip -q /release.zip 'ns/cl_dlls/*' 'ns/dlls/ns.dll' -d /client && \
    test -f /client/ns/cl_dlls/client.dll && test -f /client/ns/cl_dlls/client.so

FROM toolchain AS package

ARG CFG=release

COPY src/main /out/ns
# Not for the server: the source, and the Windows navmesh editor (run it from
# src/main/navmeshes/NavEditor; a copy here would be deleted by every merge)
RUN rm -rf /out/ns/source /out/ns/navmeshes/NavEditor
COPY --from=client /client/ns/ /out/ns/
COPY --from=build /src/main/source/linux/${CFG}/ns.so /out/ns/dlls/ns.so

FROM scratch AS export
COPY --from=package /out/ /
