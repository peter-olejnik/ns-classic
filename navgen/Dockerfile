# Headless bot navmesh generator (navgen.cpp), built from the sources of
# RGreenlees/goldsrcnaveditor without its GUI (no SDL/OpenGL). Everything is
# compiled here; nothing is installed on the host.
#
#   navgen/build.sh     (or: podman build -t localhost/ns-classic-navgen navgen)

ARG BASE_IMAGE=docker.io/library/ubuntu:22.04

FROM ${BASE_IMAGE} AS build
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates git g++ && \
    rm -rf /var/lib/apt/lists/*

# Pinned: navgen.cpp mirrors this commit's build code
ARG NAVEDITOR_URL=https://github.com/RGreenlees/goldsrcnaveditor.git
ARG NAVEDITOR_REF=d105401c4c76020d548e93c8e2f838c726602545
RUN git clone -q "$NAVEDITOR_URL" /gne && cd /gne && git checkout -q "$NAVEDITOR_REF"

COPY navgen.cpp /src/

# Recast (generation), the tile cache layer builder and Detour's helpers, the
# editor's BSP loader and chunky mesh, and fastlz
RUN cd /gne && \
    g++ -O2 -std=c++17 -o /navgen \
      -IRecast/Include -IDetour/Include -IDetourTileCache/Include \
      -IRecastDemo/Include -IRecastDemo/Contrib/fastlz \
      /src/navgen.cpp \
      Recast/Source/*.cpp \
      DetourTileCache/Source/DetourTileCacheBuilder.cpp \
      Detour/Source/DetourAlloc.cpp Detour/Source/DetourAssert.cpp Detour/Source/DetourCommon.cpp \
      RecastDemo/Source/MeshLoaderObj.cpp RecastDemo/Source/ChunkyTriMesh.cpp \
      -x c RecastDemo/Contrib/fastlz/fastlz.c && \
    /navgen 2>&1 | grep -q usage

FROM ${BASE_IMAGE} AS navgen
COPY --from=build /navgen /usr/local/bin/navgen
ENTRYPOINT ["/usr/local/bin/navgen"]
