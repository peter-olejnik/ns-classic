# Analyzes custom maps in ns_maps/ against the built mod directory dist/ns/
# and merges them according to rules.toml.
#
# Targets:
#   report  report.md + report.json (analysis only)       mapmerge/analyze.sh
#   merged  the analysis report, plus maps/ (the files to   mapmerge/merge.sh
#           add to dist/ns), merge-report.md, merge.json
#           and maplist.txt; maps/ includes the mapcycle.*.txt files
#
# The scripts pass the inputs as named build contexts:
#
#   podman build -f mapmerge/Dockerfile --target merged \
#     --build-context maps=ns_maps --build-context ns=dist/ns mapmerge

# Fully qualified so Podman on RHEL doesn't need short-name resolution
ARG BASE_IMAGE=docker.io/library/python:3.12-slim-bookworm
ARG STEAMCMD_IMAGE=docker.io/steamcmd/steamcmd:ubuntu-22

# Half-Life base content (valve/), which every HLDS install and client has.
# Keep this stage identical to the one in hosting/Dockerfile so the layer is shared.
# Maps commonly reference it, so requirements are resolved against it too.
# ~1 GB download; the layer is cached after the first run.
FROM ${STEAMCMD_IMAGE} AS hlds
# app_update is repeated: HLDS often doesn't fully install on the first pass
RUN for i in 1 2 3; do \
      steamcmd +force_install_dir /hlds +login anonymous \
        +app_set_config 90 mod valve +app_update 90 validate +quit || true; \
    done && \
    test -f /hlds/valve/halflife.wad

FROM ${BASE_IMAGE} AS tools

# unar extracts zip, rar (incl. RAR5) and 7z with one tool
RUN apt-get update && \
    apt-get install -y --no-install-recommends unar && \
    rm -rf /var/lib/apt/lists/*

FROM tools AS analyze

COPY --from=maps . /in/maps
COPY --from=ns . /in/ns
COPY --from=hlds /hlds/valve /in/valve
COPY analyze.py /app/analyze.py
# Extracted files stay in /work/extract for the merge stage
RUN python3 /app/analyze.py --maps /in/maps --ns /in/ns --valve /in/valve \
      --work /work/extract --state /work/analysis.json --out /out

# Separate from analyze so editing rules.toml or merge.py only re-runs this
FROM analyze AS merge
COPY merge.py mapcycle.py rules.toml /app/
RUN python3 /app/merge.py --state /work/analysis.json --rules /app/rules.toml --ns /in/ns --out /out

FROM scratch AS report
COPY --from=analyze /out/ /

FROM scratch AS merged
COPY --from=merge /out/ /
