# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project goal

Fully containerized **build** and **hosting** for Natural Selection (NS1), the GoldSrc/Half-Life mod. The end state:

1. A build container compiles the NS binaries from `src/main/source`.
2. The host container runs HLDS (and HLTV) using those binaries and the `src/main` content (exported as `dist/ns/`, plus custom maps merged into `dist/server/ns/`).

`README.md` describes the current status and roadmap. Both steps work: `builder/` → `dist/ns/`, `mapmerge/` → `dist/server/ns/`, `hosting/` → server image. Builder and hosting stay as separate Dockerfiles for now, at the user's request.

**Podman is the primary engine** (Podman on Windows through a WSL machine for development, RHEL for production hosting). Everything must also keep working with Docker. In practice:
- Use fully qualified image names (`docker.io/library/ubuntu:22.04`), because RHEL enforces short-name resolution.
- Don't rely on `build --output`, because remote Podman doesn't support it. Export with `create` and `cp` instead, as `builder/build.sh` does.
- Ignore files belong in the build context's root (`/.dockerignore` for `builder/`, `hosting/.dockerignore`), not in `<Dockerfile>.dockerignore`. For large inputs that only one build needs, use named build contexts (`--build-context name=path`, then `COPY --from=name`) instead, as `mapmerge/` and `hosting/` do. This works with remote Podman.
- Keep RHEL in mind for the host: rootless containers, and SELinux volume labels (`:Z`) on bind mounts. `hosting/` uses named volumes, which need neither `:Z` nor uid mapping.

## Layout

- `src/`: a git clone of upstream [ENSL/NS](https://github.com/ENSL/NS) (source and game assets, about 1.3 GB). It's gitignored here, and `builder/build.sh` clones it when it's missing (`NS_GIT_URL`, `NS_GIT_REF`; default tag `v3.3b9`). Keep the default on the release that clients run: `develop` (bot work after b9) makes b9 clients drop with `svc_bad` at round end with bots. That was verified by A/B testing against ENSL's release binary and our build of the tag. Move the default only to a new release tag, and test a full round with bots before you do. The user may also place a local copy or fork there. On Windows the checkout has CRLF, because upstream's `.gitattributes` uses `text=auto`.
  - `src/main/source/linux/Makefile`: the Linux build entry point. Targets: `particles`, `ns` (server DLL, via `Makefile.nsdll`) and `hl_cdll` (client, via `Makefile.hl_cdll`). `CFG=release|debug`.
  - `src/main/liblist.gam`: the mod manifest. The server loads `gamedll_linux "dlls/ns.so"`.
  - `src/main/dlls/`: committed upstream prebuilt binaries (`ns_i386.so`, `ns.dll`, and so on).
  - **Never edit files under `src/` directly.** Source fixes go in `builder/patches/` (see below).
- `builder/`: the container build. Ubuntu 22.04, multi-stage `toolchain` → `build` → `package` → `export` (FROM scratch, holds `/ns`). A separate `client` stage downloads ENSL's release zip (`NS_CLIENT_URL`, pinned by `NS_CLIENT_SHA256`; default v3.3b9 patch zip) and adds its `cl_dlls/client.{dll,so}` and `dlls/ns.dll` to the package. They're not in git. The server precaches them for the consistency check (`mp_consistency 1`), and without byte-identical copies every player is kicked with "Bad file (cl_dlls/client.so) Your NS version differs from the server's". Keep them on the release clients run, independent of `NS_GIT_REF`. `dlls/ns.so` stays our build, which can't match the release `ns.so` that clients have, so `patches/0002-consistency-skip-ns-so.patch` stops precaching it for the check (clients never load it). Without the patch, players are kicked with "Bad file (dlls/ns.so)". `patches/0003-bots-reset-navmesh-status-on-new-map.patch`: upstream `AIMGR_NewMap()` returned early on `AIMGR_IsBotEnabled()`, which is false while the navmesh status is FAILED. So after a map without a navmesh, the status never reset to pending and bots stayed off on every later map. The patch checks the `avh_botsenabled` cvar instead and always calls `UnloadNavigationData()`, which resets the status. Unpatched workaround: `mp_botsenabled 0` then `1` (`AIMGR_OnBotEnabled()` loads directly). The build context is the repo root, filtered by `/.dockerignore`. It works around old makefiles with `make` command-line overrides instead of editing them: `SLIBB='ar cqs ...'` and `CC='"gcc -m32 -std=c++11"'`. Note that the embedded quotes in `CC` are required, because the upstream Makefile passes `CC=$(CC)` unquoted to the sub-make.
  - `builder/patches/NNNN-*.patch`: unified diffs applied in name order with `patch -p1 --fuzz=0`. Paths are relative to the ENSL/NS repo root (`a/main/source/...`). They are written against **LF** source, because the container converts the whole tree with dos2unix before patching. They're marked `-text` in `.gitattributes` so git keeps them byte-exact. To create one, diff an LF copy of the pristine file against the fixed copy, outside `src/`. Don't use `sed -i` on `src/` from Git Bash: it strips CRLF. With a git clone, `git -C src diff` is also a reasonable starting point. Then revert with `git -C src checkout -- <file>`.
  - `builder/build.sh`: clones `src/` if it's missing, picks the engine (podman, then docker, or `CONTAINER_ENGINE`), builds, and exports to `dist/ns/`. It never pulls or modifies an existing `src/`. The exception is `build.sh clean` (first argument), which deletes `src/` and re-clones it. It refuses if `src/` has uncommitted changes or isn't a git repo.
  - The built `ns.so` needs glibc 2.33 or newer and GLIBCXX 3.4.29 or newer (Ubuntu 22.04 or later at runtime). The old prebuilt `ns_i386.so` only needs glibc 2.3.
- `content/`: committed, user-made server content at its path under `ns/` (bot navmeshes in `content/navmeshes/`). `*.nav` is `binary` in `.gitattributes`. It's excluded from the builder context (`/.dockerignore`). `mapmerge/merge.sh` copies it on the host as the last layer of `dist/server/ns` (after `dist/ns` and `dist/maps`), and appends a "## content/" section to `merge-report.md` listing each file as added, replacing a dist/ns file, or replacing a merged file. Being host-side, a content change doesn't invalidate the cached analysis. Files in `content/` aren't seen by the analysis or the mapcycles, so a `.bsp` placed there isn't in any mapcycle; maps belong in `ns_maps/`. `hosting/overlay/` stays for local, gitignored per-server files. NavEditor ships in `src/main/navmeshes/NavEditor/`. The builder's package stage deletes it from `dist/ns`, because the user kept running it from `dist/server/ns`, and Windows then locks the folder so `merge.sh` fails at `rm -rf` (it reports that with a hint).
- `ns_maps/`: the user's **dumping ground** (archives, loose files, mirrored download sites; any layout, and folder names carry no meaning). Every `.bsp` in it is a map. Every other file is only a source for what the merged maps need. It's input data; don't modify it.
- `mapmerge/`: analyzes `ns_maps/` against `dist/ns/` and merges it according to `rules.toml`. The result is `dist/server/ns/` (`dist/ns` + `dist/maps` overlay) plus reports in `dist/mapmerge/`. `dist/ns` is never modified, so a re-run is always from a clean base.
  - `Dockerfile`: stages `hlds` (steamcmd/steamcmd image, installs HLDS app 90 to get `valve/`) → `tools` (python slim + `unar`) → `analyze` (runs `analyze.py`, keeps extracted files in `/work/extract` and the full state with paths in `/work/analysis.json`) → `merge` (FROM analyze, runs `merge.py`, writes `/out/maps/...`). Export targets: `report` (`analyze.sh`) and `merged` (`merge.sh`). Inputs come from named build contexts `maps` and `ns`. The main context is `mapmerge/` itself. Editing `rules.toml` or `merge.py` re-runs only the merge stage.
  - `merge.py`: stdlib only (`tomllib`). It validates `rules.toml` keys against `DEFAULT_RULES`, so unknown keys are errors. It merges only:
    - a map's own files (`own_of`), unless the map is skipped;
    - requirements resolved by path (`used_by`), if any non-skipped map uses them;
    - by-name finds (`name_uses`), copied to the destination the map expects;
    - archive siblings (`sibling_of`), only for maps whose `.bsp` is actually added, and only when `files.include_archive_siblings` is on;
    - `files.place` entries.

    Everything else in the dump is only counted, never listed or copied. `copy()` refuses unsafe destinations (absolute paths, dot-only parts, `:`). `merge.sh` assembles `dist/server/ns` on the host with `cp -a`.
  - `mapcycle.py`: imported by `merge.py` (the Dockerfile copies it next to `merge.py`). It writes `mapcycle.{all,siege,co,ns,original}.txt` into `/out/maps`, the mod overlay, for every map on the server (dist/ns `maps/*.bsp` plus the merged maps). `family_and_version()` splits a name into a family and a version key: separator tokens from the end (stages in `STAGES`; `t`/`a`/`v`/`new` need a number; `v` digits are dotted, so `v22` is 2.2), with a glued `b`/`beta`/`rc`/`v` suffix as a fallback (`ns_shivab4`). `pick()` adds numbered re-releases and a–f letter revisions of existing maps, treats a map whose full name is another family as that family's release, and then keeps per family the best non-beta (`is_beta`: rank ≤ rc), otherwise the best beta. Base names beat `_vN`/`_rN`. `_v2` is kept next to the base (`SEPARATE_FROM_BASE`). Tune it by checking the "Versions left out" list in `merge-report.md`. The `[mapcycle]` rules are minplayers, maxplayers, exclude and include.
  - `analyze.py`: stdlib only. It parses BSP v30 (entity lump and texture lump; a miptex with offset 0 means the texture comes from a WAD) and the WAD3 directory. Placement rules live in `place()`. Severity: critical means a `.mdl` or `.spr` used by a non-worldspawn entity (HLDS precache failure). A missing WAD counts only when external textures are unresolved.
  - References are normalized with `norm_ref()` before they're resolved: backslashes become `/`, empty and dot-only parts (`./`, `../`, `.../`) are dropped, and anything before the first game dir is stripped (`../valve/models/x` → `models/x`). `.res` and `.txt` files are read with `read_text()`, because some are UTF-16. Garbage entries in worldspawn `wad` lists are dropped. A `VBSP` header is reported as a Source-engine map.
  - `place()`: `.bsp` always goes to `maps/` and `.wad` always to the root, whatever folder they're in. Other files are anchored at the first game dir in the path or placed by type; anything else is "unplaced" and only reachable by name. `.ztmp` and `.part` files are junk.
  - `resolve()` order: candidates by path → dist → valve → by name (`name_lookup()` over the `by_name` index of every collected file) → missing. Lookup by name only fills a destination that is a WAD in the root or a path under a `GAME_DIRS` folder. Bare names (readme hints) and non-game top folders (`.res` typos like `sounds/`) stay missing, flagged `invalid_folder`. A by-name hit has status `name`, with `found` = the destination; `name_uses` records the chosen file (largest if names collide) and the maps that use it. Minimap and navmesh gaps are filled the same way as `ns:minimap` / `ns:bot navmesh` requirements.
  - Each `files[]` entry carries `own_of`, `used_by`, `sibling_of` and `needed`. The report covers conflicts and dist differences only for needed files, because the dump is full of irrelevant duplicates.
- `navgen/`: a headless bot navmesh generator. `navgen.cpp` reproduces NavEditor's Input Map → Build → Save, compiled in a container (`Dockerfile`) from RGreenlees/goldsrcnaveditor at a pinned commit: Recast, `DetourTileCacheBuilder`, the editor's `MeshLoaderObj` (BSP loader) and `ChunkyTriMesh`, and fastlz. There's no GUI and no patches. `build.sh [-o dir] [bsp...]` builds `localhost/ns-classic-navgen`, streams the maps into a `sleep` container with tar (`--no-same-owner`, absolute `-C` per file), runs `xargs -P ${NAVGEN_JOBS:-nproc}` navgen builds (900 s timeout each), and streams `/out` back, by default to `dist/navmeshes/`. No bind mounts, so it works with remote podman. Failures leave `/failed/<map>` with their stderr; they are listed and the exit status is 1, but the successful maps are still copied. navgen checks for BSP v30 first, because the editor loader segfaults on junk. `mapmerge/merge.sh --navgen` (maps in `mapcycle.{ns,co,siege}.txt`) or `--navgen-all` (all maps) runs it after the overlay and before `content/`. It covers maps with no `navmeshes/<map>.nav` in `dist/server/ns` or `content/`. The cache is `dist/navmeshes/<map>.nav` plus `keys.txt` (`map<TAB>cksum of bsp:cksum of navgen.cpp+Dockerfile`), so only new or changed maps or a changed navgen trigger a rebuild. It appends a "## navgen" section (generated and failed) to `merge-report.md`; a failure doesn't fail the merge.
  - NS `.nav` format (`TileCacheBuildHeader` in `AvHAINavigation.cpp`, 316 bytes, `static_assert`ed):
    - magic `TSET`, version 2, tile counts for the regular, onos and building meshes;
    - three NS `dtNavMeshParams` + `dtTileCacheParams` pairs. NS's `dtTileCacheParams` has `walkableSlope` and no `crouchHeight`, unlike the editor's current one;
    - surftype, off-mesh, convex volume and hint count/offset pairs;
    - then per mesh `{tileRef, dataSize}` + fastlz-compressed tile cache layers. `tileRef` = `(1 << cacheTileBits) | index`;
    - then one int surftype per triangle. navgen writes no off-mesh connections, volumes or hints.
  - The file holds only heightfield layers; bots build the polygons at load.
  - The settings in `kMeshes`/`Options` were decoded from the headers of editor-saved files: cs/ch 3, tile 48, and per mesh height/radius/climb/slope of regular 72/17/18/50, onos 108/32/18/50 and building 100/32/18/45. Also crouch 36/72/100, and the ledge filter on the building mesh only.
  - Area codes are remapped from the editor's profile codes (1 walk, 2 crouch) to NS's (63 walk, 1 crouch).
  - NS's shipped editor came from unpublished code, so parity is 97% of tile layers on a plain-build reference (ns_siege005). The remaining differences are erosion at ledges and layer splits. Other erosion versions from the editor's history, entity-class solidity and water/sky handling were all tried; none did better. Stock `.nav` files are hand-edited, so they aren't byte references. Verified in-game: a generated ns_agora mesh loads ("Navigation data for ns_agora loaded successfully") and in ~3.5 minutes, bots-only, both teams built 4 resource towers each across the map and got kills.
- `hosting/`: the server image and stack. It was derived from the ENSL HLDS container, without the ENSL plugin stage.
  - `Dockerfile` stages:
    - `hlds`: the same RUN as `mapmerge/Dockerfile`'s `hlds` stage, kept byte-identical so the ~1 GB layer is shared. If you change one, change both.
    - `hlds-files`: drops `cstrike/`, `linux64/`, `steamapps/` and any Steam `libstdc++`/`libgcc_s`.
    - `hltvfix`: compiles `hltvfix/hltv_demofix.c` (gcc -m32) into an `LD_PRELOAD` library. Valve's `proxy.so` copies `"HLDEMO"` (7 bytes) into the 6-byte `szFileStamp` (`DemoFile::StartRecording`, `DemoFile.cpp:313`). It's built with `_FORTIFY_SOURCE`, so every demo recording aborted with "buffer overflow detected", which made `hltv` crash-loop (and "Proxy slots are full" until the dead slot timed out). The shim lets only that exact copy through (src `HLDEMO`, len 7, destlen 6), via `__memcpy_chk`/`__strcpy_chk`; everything else goes to glibc. `entry.sh` preloads it for `hltv` only. Verified with gdb, and demos get a valid `HLDEMO` header. Don't remove it unless Valve fixes HLTV.
    - `server`: Ubuntu 22.04 with i386 runtime libs only, user `steam` (uid 1000), `~/.steam/sdk32/steamclient.so` symlinked to HLDS's own copy. The mod directory comes from the `ns` named context (`dist/server/ns`, or `NS_DIR`), then `overlay/` and the scripts. It has an `ldd` check (with `LD_LIBRARY_PATH=.`) for missing libraries. tini is PID 1.
  - **`steam_appid.txt` (`70`) is pre-created on purpose.** Without it, every fresh container fails its first start with "Unable to initialize Steam" (HLDS writes the file during that failed start, so only restarts work). Don't remove it.
  - The old ENSL container's `files/*.acf` manifest workaround isn't needed with current HLDS and was dropped.
  - `build.sh` builds `localhost/ns-classic-server:latest` with context `hosting/` and `--build-context ns=...`. `compose.yaml` (project `ns-classic`) only uses that image (`pull_policy: never`), because compose builds can't pass named contexts portably.
  - `compose.yaml` services, one per role:
    - `hlds`, which needs `tty` and `stdin_open` for `attach`;
    - `hltv`;
    - `rotate`.

    Named volumes `logs` and `demos`. UDP ports only; GoldSrc doesn't use TCP. `env_file` is `.env.default` plus an optional `.env` (`required: false`). Compose interpolation reads `.env` too, so `HLDS_PORT`/`HLTV_PORT` set there change both the server and the port mapping. Container port = host port on purpose, since GoldSrc advertises its own port.
  - `scripts/entry.sh`: the first argument is the role (`hlds`/`hltv`/`rotate`/any command). It `exec`s `hlds_linux` directly (not `hlds_run`, whose bash loop swallows signals). Restarts come from compose `restart: unless-stopped`. Passwords come from `RCON_PASSWORD`/`SV_PASSWORD` as command-line args. Never bake them into the image; `.dockerignore` excludes `.env*`.
  - `NS_GAMEDLL` (entry.sh): copies the chosen binary over `ns/dlls/ns.so` in the container, keeping the built one as `ns.so.built` and restoring it when the variable is unset. The HL25 engine ignores `gamedll_linux` and `-dll`: it loads the `gamedll` name with `.so` (`dlls/ns.so`), so editing liblist.gam doesn't work. Upstream's committed `main/dlls/ns_i386.so` is NOT a release server: it's an `AVH_SECURE_PRERELEASE_BUILD` that rejects players with "Only authorized players can join beta NS servers". Release binaries come from the GitHub release zips (`ns/dlls/ns.so`).
  - `scripts/rcon.sh` (in the image as `./rcon.sh`): GoldSrc RCON over bash `/dev/udp` to 127.0.0.1, using the container's `RCON_PASSWORD`/`HLDS_PORT`, so the password never leaves the container. Each reply is one datagram, so it's read with `dd bs=4096 count=1` (`head -c N` blocks on short datagrams). HLDS echoes RCON packets, password included, to its console; that's engine behavior.
  - `push-content.sh` (host): `podman cp content/. <hlds>:/home/steam/hlds/ns/`, then `./rcon.sh sv_botreloadnav` (NS command; needs `mp_botsenabled 1`; `ReloadNavMeshes` only acts if a navmesh is loaded and prints nothing otherwise). If the reply lacks "loaded successfully", it switches `mp_botsenabled` to 0 and back to 1 instead, which loads the navmesh. Git Bash: `MSYS_NO_PATHCONV=1` for the container paths, and `cygpath -m` for the host path, because remote podman needs a Windows path. Ownership stays `steam`. It only changes the running container; a rebuild is still needed to make it permanent.
  - `scripts/rotate.sh`: compresses `ns/logs/*.log` (lz4) and `ns/demos/*.dem` (zip) after `ROTATE_AGE` idle minutes.
  - `server.cfg` and `motd.txt`: the user's copies, gitignored. They're created from the committed `server.cfg.example` / `motd.txt.example` (stock `dist/ns` files; the server.cfg one has an instruction header) by `build.sh` if missing, and copied over `ns/` after `overlay/`, so they win. The Dockerfile COPYs them unconditionally, so `build.sh` must keep creating them. Don't put a header in `motd.txt.example`, because players would see it. If upstream's `server.cfg`/`motd.txt` change, refresh the examples from `dist/ns` (LF).
  - `overlay/`: any other files copied over `ns/`, gitignored except `.placeholder`.

## Key technical constraints

- **Everything is 32-bit.** GoldSrc and HLDS are i386 only. Builds need `gcc -m32` / `g++ -m32`, multilib, and i386 versions of libcurl and libpng. Runtime images need `dpkg --add-architecture i386`.
- **libstdc++ conflict:** older HLDS builds shipped a `libstdc++.so.6` (and `libgcc_s.so.1`) older than what `ns.so` needs. Current HLDS doesn't, but `hosting/` still deletes them in case they come back, so the system ones are used. Keep this behavior.
- `steamclient.so` must be symlinked into `~/.steam/sdk32/`, and `steam_appid.txt` must exist in the HLDS directory (see `hosting/`).
- HLDS is installed with SteamCMD as an anonymous user (app 90, mod `valve`). Never commit HLDS or Valve binaries.
- Ports (all UDP): game 27016 (upstream default is 27015), VAC 26900, HLTV 27020.
- The container runs as the `steam` user (uid 1000). `ns/logs` and `ns/demos` are created in the image owned by that user, so named volumes inherit the ownership.

## Working conventions

- Secrets: don't commit any. In `hosting/`, passwords live only in the untracked `hosting/.env`.
- Base images: `ubuntu:xenial` is end of life. When you change images, pin specific versions and keep the i386 package names correct for the release (for example `lib32gcc1` → `lib32gcc-s1`, `libcurl3` → `libcurl4` on newer Ubuntu).
- Keep all tooling outside `src/`. It is upstream's checkout and isn't tracked here.
- Shell scripts run inside Linux containers. Keep LF line endings even though development happens on Windows.

## Useful commands

```sh
# Build the server binary → dist/ns/
builder/build.sh                             # [out dir] [extra build args], e.g. --build-arg CFG=debug
NS_GIT_REF=develop builder/build.sh          # ref used only when cloning a missing src/ (default v3.3b9)
builder/build.sh clean                       # delete + re-clone src/, then build

# Analyze custom maps → dist/mapmerge/report.md (needs dist/ns)
mapmerge/analyze.sh

# Analyze + merge per mapmerge/rules.toml → dist/server/ns (ready for hosting)
mapmerge/merge.sh

# Generate bot navmeshes (no off-mesh connections/hints) → dist/navmeshes/<map>.nav
navgen/build.sh dist/server/ns/maps/ns_agora.bsp
mapmerge/merge.sh --navgen                   # merge + navmeshes for mapcycle maps lacking one (cached)

# Build the server image from dist/server/ns, then run the stack
hosting/build.sh                             # NS_DIR=dist/ns hosting/build.sh: no custom maps
cd hosting && podman compose up -d           # or docker compose
podman attach ns-classic-hlds-1              # console; detach with Ctrl-P Ctrl-Q
hosting/push-content.sh                      # content/ into the running server + sv_botreloadnav
podman exec ns-classic-hlds-1 ./rcon.sh status   # one console command over RCON
```
