# ns-classic

Containerized build and hosting for **Natural Selection** (NS1), the classic Half-Life (GoldSrc) mod.

The goal is to build the NS mod binaries from source and run a dedicated server (HLDS, plus optional HLTV) entirely in Docker, so the toolchain and server need nothing installed on the host machine.

## Repository layout

| Path     | What it is |
|----------|------------|
| `src/` | A git checkout of the community-maintained [ENSL/NS](https://github.com/ENSL/NS) v3.3 project: C++ source, maps, models, sounds and configs. It isn't tracked in this repo. `builder/build.sh` clones it if it's missing. |
| `src/main/` | The `ns` mod directory: game content plus `source/`, the code for the server DLL (`ns.so` / `ns.dll`), the client DLL, particles and the HPB bot. |
| `src/main/source/linux/` | Linux makefiles (`Makefile`, `Makefile.nsdll`, `Makefile.hl_cdll`). They build 32-bit (i386) binaries. |
| `src/hd/` | Optional high-definition (AI-upscaled) models. |
| `builder/` | The container build for the NS server binary (`Dockerfile` and `build.sh`). Its output goes to `dist/ns/`. |
| `builder/patches/` | Source fixes, applied to `src/main/source` during the container build. |
| `ns_maps/` | A dumping ground for custom maps and anything they might need, in any layout: archives, loose files, mirrored download sites. Every `.bsp` is merged as a map, along with only the files those maps need. |
| `content/` | Committed content you make for the server, laid out like the mod directory, e.g. bot navmeshes in `content/navmeshes/<map>.nav`. `mapmerge/merge.sh` copies it into `dist/server/ns/` last, so it wins over the stock files and the merged maps. |
| `navgen/` | A headless bot navmesh generator (NavEditor's Build and Save steps), built in a container. Its output goes to `dist/navmeshes/`. `mapmerge/merge.sh --navgen` runs it for maps without a navmesh. See [Generating navmeshes](#generating-navmeshes-navgen). |
| `mapmerge/` | The container that analyzes `ns_maps/` against `dist/ns/` and merges it according to `rules.toml`. Scripts: `analyze.sh` and `merge.sh`. Its output goes to `dist/server/ns/`, `dist/maps/` and `dist/mapmerge/`. |
| `hosting/` | The dedicated server image (`Dockerfile`, `build.sh`) and stack (`compose.yaml`): HLDS installed with SteamCMD, plus `dist/server/ns/`. Runs HLDS, log/demo rotation and, optionally, HLTV. |
| `hosting/server.cfg`, `hosting/motd.txt` | Your server config and message of the day, created from the committed `.example` files and copied over `ns/` in the image. |
| `hosting/overlay/` | Any other files to copy over `ns/` in the image (`mapcycle.txt`, `banned.cfg`, ...). |

## Current status

This is a work in progress.

- **Building** is containerized in `builder/`. It compiles the 32-bit Linux server binary (`dlls/ns.so`) from `src/main/source` and exports a server-ready `dist/ns/` directory. Tested with Podman.
- **Custom maps** in `ns_maps/` are analyzed and merged by `mapmerge/`, following `rules.toml`. The result is `dist/server/ns/` (`dist/ns/` plus the maps), along with reports.
- **Hosting** is containerized in `hosting/`: Ubuntu 22.04, HLDS from SteamCMD, and the mod directory from `dist/server/ns/`. Tested with Podman: the server loads stock and custom maps, connects to Steam with VAC, and HLTV records demos.

### Roadmap

1. ~~Add a build container that compiles the server binary from `src/main/source`.~~ Done (`builder/`).
2. ~~Have the host image use the built mod directory instead of downloading the release zip.~~ Done (`hosting/`, from `dist/server/ns/`).
3. ~~Pull the NS source from git instead of vendoring it.~~ Done (`builder/build.sh` clones into `src/`). The default is pinned to the `v3.3b9` release tag.
4. ~~Move the base images off Ubuntu Xenial (end of life) to a supported release.~~ Done: `builder/` and `hosting/` use Ubuntu 22.04.
5. ~~Merge `ns_maps/` into the server's mod directory.~~ Done (`mapmerge/merge.sh` → `dist/server/ns/`).
6. ~~Keep secrets out of the repo.~~ Done: `hosting/` takes RCON and server passwords only from an untracked `.env`.
7. ~~Generate mapcycles from the merged maps.~~ Done (`mapcycle.*.txt`). Still to do: set up a fast-download (`sv_downloadurl`) host for the custom maps.

## Running a server

Requirements: Podman or Docker, with Compose (`podman compose` or `docker compose`). Everything runs in containers. The full pipeline is:

```sh
builder/build.sh          # compile ns.so          → dist/ns/
mapmerge/merge.sh         # add the custom maps    → dist/server/ns/
hosting/build.sh          # build the server image → localhost/ns-classic-server
cd hosting
podman compose up -d      # or docker compose; add --profile hltv for HLTV
```

`hosting/build.sh` bakes `dist/server/ns/` into the image. Set `NS_DIR=dist/ns` to build a server without the custom maps. Re-run it after a new build, a merge or a config change. The first build downloads HLDS (about 1 GB). That layer is shared with `mapmerge/` and cached.

### Settings

Settings live in `hosting/.env.default`. Don't edit that file. Instead, create `hosting/.env` (gitignored) with only the lines you want to change. It overrides the defaults:

```sh
RCON_PASSWORD=change-me
HLDS_OPTS=+maxplayers 24 +map ns_eclipse +log on -pingboost 3 +sys_ticrate 1000
```

| Variable | Default | Purpose |
|----------|---------|---------|
| `HLDS_PORT` | `27016` | Game port (UDP). Set it in `.env`, which compose also reads for the port mapping. |
| `HLDS_OPTS` | `+maxplayers 32 +map ns_veil ...` | `hlds_linux` options. `-game ns` and `-port` are added automatically. |
| `NS_GAMEDLL` | empty | Run another server binary from `ns/` in place of the built `dlls/ns.so`, for comparison, e.g. a release binary put in `hosting/overlay/dlls/` (the release zip's `ns/dlls/ns.so`, renamed). Don't use the repo's prebuilt `dlls/ns_i386.so`: it's an old beta build that rejects everyone but authorized testers. |
| `RCON_PASSWORD` | empty | RCON password, passed at start. Don't put it in `server.cfg`. |
| `SV_PASSWORD` | empty | Join password. HLTV also uses it to connect. |
| `HLTV_PORT` | `27020` | HLTV port (UDP). |
| `HLTV_OPTS` | `+record demos/ns` | `hltv` options. `+connect hlds:<port>` is added automatically. |
| `HLTV_DELAY` | `10` | Seconds HLTV waits for the server to start. |
| `ROTATE_INTERVAL`, `ROTATE_AGE` | `300`, `30` | How often the rotate service runs (seconds), and how many minutes a file must be idle before it's compressed. |

### Server config and MOTD

The two files you'll change most often live directly in `hosting/`:

| File | Committed template | What it is |
|------|--------------------|------------|
| `hosting/server.cfg` | `server.cfg.example` | Server settings (hostname, `sv_region`, gameplay cvars). The server runs it on every map change. |
| `hosting/motd.txt` | `motd.txt.example` | The message of the day shown to joining players. |

They replace `ns/server.cfg` and `ns/motd.txt` from `dist/server/ns/` in the image. `dist/server/ns/` itself isn't changed, because `merge.sh` rebuilds it anyway. Both files are gitignored, so your edits stay local, while the `.example` files are committed copies of the stock `dist/ns/` versions.

1. Run `hosting/build.sh` once. It creates `server.cfg` and `motd.txt` from the `.example` files if they don't exist. You can also copy them yourself.
2. Edit `hosting/server.cfg` and `hosting/motd.txt`.
3. Rebuild and restart: `hosting/build.sh && cd hosting && podman compose up -d`. Only the small config layer is rebuilt.

To start over from the stock files, delete your copy and run `build.sh` again. Keep passwords out of `server.cfg`: set `RCON_PASSWORD` and `SV_PASSWORD` in `hosting/.env`.

Any other file for the mod directory (`mapcycle.txt`, `banned.cfg`, a custom `skill.cfg`, ...) goes in `hosting/overlay/`, at its path under `ns/`. It's copied over `ns/` before `server.cfg` and `motd.txt`. Content you make and want to keep in git, like bot navmeshes, goes in `content/` instead (see [Server content](#server-content)). Don't add files to `dist/server/ns/` by hand: `mapmerge/merge.sh` recreates it on every run. The image holds a copy of all these files, so after any change run `hosting/build.sh` and then `podman compose up -d`; `up -d` alone keeps the old image.

### Server content

`content/` holds files you make for the server, committed to git, at their path under `ns/`. Bot navmeshes go in `content/navmeshes/<map>.nav`. `mapmerge/merge.sh` copies `content/` into `dist/server/ns/` as the last layer, after the stock files and the merged maps, so your files always win. The end of `dist/mapmerge/merge-report.md` lists each file and whether it was added or replaces a stock or merged file. After adding or changing files:

```sh
mapmerge/merge.sh && hosting/build.sh && (cd hosting && podman compose up -d)
```

The analysis is cached, so this only re-runs the quick assembly.

**Live update, without a rebuild or restart:** `hosting/push-content.sh` copies `content/` into the running `hlds` container and runs `sv_botreloadnav` over RCON, so the bots reload the current map's navmesh right away. It needs `RCON_PASSWORD` in `hosting/.env`. The copy only lives in the running container, so run the merge and build commands above when you're done, or the next container restart loses it. Bots must be enabled (`mp_botsenabled 1`). If the current map started without a navmesh, `sv_botreloadnav` does nothing, so the script switches the bots off and on instead, which loads the new navmesh (there are no bots on such a map anyway). Other maps pick up their new navmesh when they load.

For other console commands, use `podman exec ns-classic-hlds-1 ./rcon.sh <command>` (e.g. `status`, `changelevel ns_eclipse`). It runs inside the container with the container's own `RCON_PASSWORD`. Note that HLDS prints every RCON packet, password included, to its console.

`content/` vs `hosting/overlay/`: `content/` is shared project content (committed); `overlay/` is for one server's local files (gitignored).

NavEditor (`GoldsrcNavEditor.exe`) ships in `src/main/navmeshes/NavEditor/`. The build leaves it out of `dist/` (the server doesn't need it), so run it from there or from your own copy. Save the navmeshes you make into `content/navmeshes/`. The stock `mapcycle.txt` lists only the stock maps. Generated mapcycles for all maps are in `ns/` too (see [Mapcycles](#mapcycles)), and you can pick one with `+mapcyclefile mapcycle.ns.txt` in `HLDS_OPTS`.

### Generating navmeshes (navgen)

`navgen/` is a headless version of NavEditor's "Input Map", "Build" and "Save" steps. It's a small console program built in a container from the editor's source ([RGreenlees/goldsrcnaveditor](https://github.com/RGreenlees/goldsrcnaveditor), pinned commit) without the GUI, so nothing is installed on the host.

```sh
navgen/build.sh                                         # build the image only
navgen/build.sh dist/server/ns/maps/ns_agora.bsp ...    # → dist/navmeshes/<map>.nav
navgen/build.sh -o content/navmeshes maps/ns_x.bsp      # another output dir
mapmerge/merge.sh --navgen                              # every mapcycle map without a navmesh
mapmerge/merge.sh --navgen-all                          # every map without a navmesh
```

With `--navgen`, `merge.sh` generates a navmesh for each map in `mapcycle.ns.txt`, `mapcycle.co.txt` and `mapcycle.siege.txt` that has none from `dist/ns/`, `ns_maps/` or `content/`, and puts it in `dist/server/ns/navmeshes/`. A navmesh you made always wins, because maps that already have one are skipped. The results are cached in `dist/navmeshes/`, keyed by each `.bsp`'s checksum and by navgen's source. So later runs only build new or changed maps, plus all of them again after navgen itself changes. The first run covers about 800 maps and takes a while. `NAVGEN_JOBS` sets how many are built at once (default: the Podman machine's CPU count). `merge-report.md` ends with a "navgen" section listing the generated and failed maps. A failed map just has no navmesh, so bots don't play on it.

A generated navmesh is what a plain "Build" gives you, with no hand-placed off-mesh connections (ladders, jumps, lifts), nav hints (where the commander places structures) or convex volumes. Bots load it and play, but they won't use ladders or jumps that need a connection. To curate a navmesh, open the generated one in NavEditor, add those, and save it into `content/navmeshes/`.

NS's own copy of the editor was built from an unpublished version of that code, so the output isn't byte-identical to NavEditor's. On ns_siege005, compared with a plain build saved from NavEditor, the header, triangle count and tile layout match exactly, and 97% of the tile layers are identical. The rest differ by a few cells at ledge edges. On some maps the shipped editor also includes a few dozen triangles that navgen leaves out (cause unknown).

`navgen dump <file.nav>` prints a fingerprint of each tile layer for comparing two files, and `navgen tile <file.nav> <mesh> <tx> <ty> <layer>` prints one layer as text.


### Services

| Service  | Purpose | Ports |
|----------|---------|-------|
| `hlds`   | The NS dedicated server | 27016/udp (game and RCON), 26900/udp (VAC) |
| `hltv`   | Optional, off by default. Spectator and demo proxy. It connects to `hlds` and records demos. A small preload library fixes a Valve bug that crashed HLTV whenever it started a demo (`hosting/hltvfix/`). | 27020/udp |
| `rotate` | Compresses logs (LZ4) and demos (zip) once they've been idle for 30 minutes | – |

`hltv` is in the compose profile `hltv`: start it with `podman compose --profile hltv up -d`, and stop it with `podman compose --profile hltv rm -sf hltv`. It can't connect to a server whose mapcycle file is over about 8 KB, and it restarts in a loop if it can't (see [Mapcycles](#mapcycles)).

All three use the same image; the container command picks the role (`hosting/scripts/entry.sh`). Logs, demos and core dumps are stored in the named volumes `ns-classic_logs`, `ns-classic_demos` and `ns-classic_cores`, which avoids permission problems with rootless Podman.

```sh
podman compose logs -f hlds                 # server output
podman attach ns-classic-hlds-1             # server console (detach with Ctrl-P Ctrl-Q)
hosting/push-content.sh                     # live update: content/ into the running server, reload navmeshes
podman exec ns-classic-hlds-1 ./rcon.sh status  # run one console command over RCON
podman compose exec hlds bash               # shell inside the container
podman compose down                         # stop everything (volumes are kept)
podman volume inspect ns-classic_logs       # where the logs are on the host
podman run --rm -v ns-classic_demos:/d -v "$PWD:/out" docker.io/library/ubuntu:22.04 cp -r /d /out/demos
                                            # copy the demos out
```

**Connecting from the same Windows PC (Podman on WSL):** `connect 127.0.0.1:27016` doesn't work. WSL forwards only TCP from Windows `localhost` into the Podman machine, and GoldSrc is UDP-only. Connect to the machine's own address instead:

```sh
wsl -d podman-machine-default -- ip -4 -o addr show eth0   # e.g. inet 172.20.221.16/20
# in the game console: connect 172.20.221.16:27016
```

That address can change when WSL restarts. To make `127.0.0.1` work, switch WSL to mirrored networking: put `networkingMode=mirrored` under `[wsl2]` in `%UserProfile%.wslconfig`, then run `wsl --shutdown`. This changes networking for all WSL distros. On Linux and RHEL, `127.0.0.1` and the host's address work as usual.

**When the server crashes:** compose restarts it, and the console log usually just stops. The reason is in the kernel log of the host (on Windows, the Podman machine): `podman machine ssh 'sudo dmesg -T | grep -A3 hlds_linux'` shows a line like `segfault at 0 ip ... in ns.so[2d9614,...]`. The number after `ns.so[` is the offset in `dist/server/ns/dlls/ns.so`, which isn't stripped, so `addr2line -f -C -e ns.so 0x2d9614` gives the function. For a full backtrace you need a core dump. `hlds` and `hltv` (if enabled) mount the volume `ns-classic_cores` at `/home/steam/hlds/cores`, but the host decides where cores go (`kernel.core_pattern`). On the Podman machine the default pipes them to `systemd-coredump`, which fails under WSL. To write them to the volume instead:

```sh
podman machine ssh 'echo "kernel.core_pattern=/home/steam/hlds/cores/core.%e.%p.%t" | sudo tee /etc/sysctl.d/50-coredump-file.conf && sudo sysctl -p /etc/sysctl.d/50-coredump-file.conf'
```

The setting covers every process on the machine. Processes without a `/home/steam/hlds/cores` directory just don't write a core. On RHEL, `systemd-coredump` works, so leave the default and use `coredumpctl list hlds_linux` and `coredumpctl debug`. A core holds the server's memory, including its command line with the RCON and join passwords, so don't share one. Each core is around 100–300 MB, and old ones aren't deleted automatically. To debug one, run gdb in a container of the same server image, so the binaries match the core:

```sh
podman run --rm -it --user root -v ns-classic_cores:/cores:ro --entrypoint bash localhost/ns-classic-server:latest
apt-get update && apt-get install -y gdb
cd /home/steam/hlds && LD_LIBRARY_PATH=. gdb ./hlds_linux /cores/core.hlds_linux.<pid>.<time>   # then: bt
```

`ns.so` is built without debug info, so the backtrace has function names but no line numbers.

On RHEL, open the UDP ports in firewalld, for example `firewall-cmd --add-port=27016/udp --add-port=27020/udp --add-port=26900/udp --permanent`.

## Building from source

Requirements: Podman or Docker. Nothing else needs to be installed on the host. This works on Linux (including RHEL), and on Windows with Podman (WSL machine) or Docker Desktop.

```sh
builder/build.sh                              # → dist/ns/
builder/build.sh dist --build-arg CFG=debug   # debug build
CONTAINER_ENGINE=docker builder/build.sh      # force docker (default: podman if installed)
NS_GIT_REF=develop builder/build.sh           # clone another branch or tag (only when src/ is missing)
builder/build.sh clean                        # delete src/, re-clone, then build
NS_GIT_REF=develop builder/build.sh clean     # switch src/ to another ref (or: git -C src checkout <ref>)
```

On Windows, run it from Git Bash or WSL. The script also needs `git` if `src/` has to be cloned.

**Source:** the build reads `src/`. If `src/` doesn't exist, `build.sh` first runs a shallow clone of `NS_GIT_URL` (default `https://github.com/ENSL/NS.git`) at `NS_GIT_REF` (default: the `v3.3b9` release tag; `NS_GIT_REF=` with an empty value clones the default branch, `develop`).

**Why v3.3b9 and not `develop`:** players run the v3.3b9 release client. ENSL's `develop` branch adds 33 unreleased commits, all to the new AI bots. A server built from `develop` sends a message that v3.3b9 clients can't parse when a round ends with bots: the client disconnects with `Host_Error: CL_ParseServerMessage: Illegible server message - svc_bad`. Tested with the same client: ENSL's official v3.3b9 binary and our own build of the `v3.3b9` tag both work, while our build of `develop` fails. An existing `src/` is used exactly as it is and is never pulled or replaced. To update it, run `git -C src pull`, or check out another ref. To start fresh, run `builder/build.sh clean`, which deletes `src/` and clones it again. As a safeguard, `clean` refuses to delete `src/` if it has uncommitted changes or isn't a git checkout. You can also put any local copy or fork in `src/`.

`build.sh` builds `builder/Dockerfile` and then copies `/ns` out of the image. It uses `create` and `cp` because remote Podman (the Windows/macOS podman machine) does not support `build --output`. With a local engine you can also run `podman build -f builder/Dockerfile -o dist .` directly.

The output `dist/ns/` is the full `src/main` mod directory without `source/`, plus the freshly compiled `dlls/ns.so` that `liblist.gam` points to. Place it in an HLDS install as `<hlds>/ns`.

The build runs on Ubuntu 22.04. The source in `src/` is never modified. Inside the container the build does three things:

1. It converts the source tree from CRLF to LF.
2. It applies the fixes in `builder/patches/*.patch`, in name order. The patches use paths relative to the ENSL/NS repo root, so they also apply to a git checkout.
3. It works around problems with modern toolchains using `make` overrides:
   - The particles `ar clq` call is replaced, because binutils 2.36 and newer reject it.
   - The server compiles with `-std=c++11`, because GCC 11 defaults to C++17 and `std::byte` clashes with the engine's `byte` typedef.

Only the server binary is built. The client (`hl_cdll`) is not needed for hosting.

**Client libraries:** `dist/ns/` also gets `cl_dlls/client.dll`, `cl_dlls/client.so` and `dlls/ns.dll` from ENSL's v3.3b9 release zip (`ns_v33b9_patch.zip`, checked against a pinned sha256). They're not in git. With `mp_consistency 1`, the server compares its copies of these files with each player's, and kicks players whose copies differ or that the server doesn't have: `Bad file (cl_dlls/client.so) Your NS version differs from the server's`. A client built here wouldn't match the release byte for byte, so the files always come from the release that players install, whatever `NS_GIT_REF` the server is built from. For another release, pass `--build-arg NS_CLIENT_URL=... --build-arg NS_CLIENT_SHA256=...`. The server's own `dlls/ns.so` is built here and can't match the release copy, so `builder/patches/0002-consistency-skip-ns-so.patch` leaves it out of the check. Clients never load it, and the client libraries still enforce the release version.

**Bot fix:** `builder/patches/0003-bots-reset-navmesh-status-on-new-map.patch` fixes an upstream bug, still present on `develop`. Normally, after one map without a navmesh (most custom maps), bots never join again, on any map, until the server restarts or `mp_botsenabled` is switched off and on. The failed navmesh state carried over to every later map. With the patch, each map change tries that map's navmesh again.

**Navmesh crash fix:** `builder/patches/0004-detour-closest-point-null-edge.patch` fixes a segfault in Detour, the bots' navigation library. `closestPointOnDetailEdges()` read through a null pointer when it found no edge, for example with a NaN position. That crashed the server mid-round in `dtNavMesh::closestPointOnPoly`, with nothing on the console. With the patch, the point is left unchanged instead.

**Phase gate crash fix:** `builder/patches/0005-detour-unlink-offmesh-on-tile-rebuild.patch` fixes another bot navigation segfault, in `dtNavMeshQuery::findPath`. NS links phase gates as off-mesh connections between any two tiles of the navmesh. When a tile was rebuilt (a structure placed on it), only its eight neighbours dropped their links to it. So the tile at the other end of a phase gate kept a link to a polygon that no longer existed, and the next path search through it crashed. With the patch, every tile drops its links to a rebuilt tile, and the phase gate connections are linked to the new tile again.

## Custom maps (ns_maps)

`ns_maps/` is a dumping ground. You can put anything there, in any folder layout: map archives (zip, rar, 7z, including archives inside archives), loose `.bsp` files, map packs, whole mirrored download sites, or loose WADs, sprites, models and sounds. Folder names don't mean anything. Then, with `dist/ns/` already built:

```sh
mapmerge/analyze.sh            # analysis only → dist/mapmerge/report.md
mapmerge/merge.sh              # analysis + merge → dist/server/ns/ (ready for hosting)
mapmerge/merge.sh --navgen     # same, plus bot navmeshes for maps without one (see navgen)
```

What gets merged:

- **Every `.bsp` in `ns_maps/` is a map**, together with its own `.res`, `.txt`, minimap and navmesh. The merge rules below then decide which maps go in: by default, broken maps and maps missing critical files are skipped.
- **Every other file is only a source** for what those maps need. It's merged only if a merged map requires it, so the rest of the dump never reaches the server.
- **Files packaged in the same archive as a merged map** are merged too. Mappers sometimes ship assets that nothing references directly. The `files.include_archive_siblings` rule turns this off.

How a needed file is found: first at its path (e.g. `nsp/sprites/foo.spr` in an archive counts as `sprites/foo.spr`). Then `dist/ns/` and Half-Life's `valve/` are checked. Finally the file is looked up **by name anywhere in `ns_maps/`**, so a loose `foo.spr` in any folder fills `sprites/foo.spr`, and the file is copied to the path the map expects. If several different files share that name, the largest is used and the reports say so. Lookup by name only fills real game paths (WADs in the root, everything else under `maps/`, `sprites/`, `sound/` and so on). It ignores bare names from readmes and typo paths from `.res` files such as `sounds/...`. A map that is missing files becomes complete as soon as the files appear anywhere in `ns_maps/`. `ns_maps/misc/` is a handy place to drop them.

### Outputs

`merge.sh` applies the rules in `mapmerge/rules.toml` and writes:

| Output | What it is |
|---|---|
| `dist/server/ns/` | The final mod directory: `dist/ns/` plus the merged maps, the navmeshes generated with `--navgen`, and `content/`. |
| `dist/navmeshes/` | The navmesh cache for `--navgen` (`keys.txt` records what each was built from). Delete it to rebuild everything. |
| `dist/maps/` | Only the files merged from `ns_maps/`, as an overlay for `dist/ns/`. |
| `dist/mapmerge/merge-report.md` | Which maps were merged or skipped and why, how conflicts were resolved, and every file added or skipped. |
| `dist/mapmerge/maplist.txt` | Names of the merged maps. |
| `mapcycle.*.txt` | In `dist/server/ns/` (and `dist/maps/`): mapcycles for every map on the server. See [Mapcycles](#mapcycles). |
| `dist/mapmerge/report.md` | The analysis report, described below. |

`dist/ns/` itself is never modified, so you can re-run `merge.sh` any time. After you edit `rules.toml`, only the merge step re-runs (a few seconds), because the analysis is cached.

### Mapcycles

`merge.sh` also writes mapcycle files into `dist/server/ns/`, so they're baked into the server image. Choose one with `+mapcyclefile <file>` in `HLDS_OPTS` (`hosting/.env`). Every entry uses `minplayers 0` and `maxplayers 32` (`[mapcycle]` in `rules.toml`).

| File | Maps |
|---|---|
| `mapcycle.all.txt` | Every map on the server, all versions included. |
| `mapcycle.siege.txt` | Maps with `siege` in the name. Filtered. |
| `mapcycle.co.txt` | `co_` maps, excluding siege maps. Filtered. |
| `mapcycle.ns.txt` | `ns_` maps, excluding siege maps. Filtered. Maps with neither prefix (bhop, kz and so on) appear only in `mapcycle.all.txt`, because NS doesn't run a game mode on them. |
| `mapcycle.original.txt` | The stock `dist/ns/mapcycle.txt`, with the player limits rewritten. |

The filtered files keep one version of each map (logic in `mapmerge/mapcycle.py`):

- A name is split into a map and a version suffix: `_b3`, `b5`, `_beta2b`, `_alpha`, `_a2`, `_rc4`, `-rc8a`, `_t004` (test), `_r2`, `_v6f`, `_new2`, `_final`/`_fixed`, and combinations like `_v3_b1`. `-` and `_` are treated the same.
- When a map exists as `ns_foo`, a numbered re-release (`ns_foo_1.3`, `ns_foo_2009`) or a letter revision (`ns_foo004a`, revisions a–f only) counts as a version of it.
- A release beats any test, alpha, beta or release candidate. Among releases, `_final` and `_fixed` beat the plain name, which beats `_rN` and `_vN` (`co_as_oilrig` over `co_as_oilrig_v9`). If a map only exists as betas, the highest one is used (`b10a` > `b9`, `rc` > `b`). `v` numbers read as dotted versions, so `_v22` (2.2) ranks below `_v3`.
- `_v2` is often a new map rather than an update, so `ns_foo_v2` is kept next to `ns_foo`.
- Suffixes like `_mvm`, `_classic`, `_mp` or `2` (`ns_tanith2`) mark different maps, so those are all kept.

`merge-report.md` lists which versions were left out. To adjust the result, use `mapcycle.include`, which lists a version anyway, and `mapcycle.exclude`, which takes glob patterns for maps never to list.

**Size limit with HLTV:** the engine sends the whole mapcycle file to every client that connects. HLTV can't parse more than about 8.5 KB of it (about 180 maps). It logs `ParseBad: illegal server message`, disconnects with `ParseBaseline: needed delta encoder missing`, and exits. `merge.sh` prints a warning for every `mapcycle*.txt` over 8192 bytes, including ones from `content/`, and `merge-report.md` lists each file's size. Players' clients get the same string but handle a long one fine (tested with the 13.9 KB `mapcycle.ns.txt`), so the limit only matters with HLTV.

### Merge rules (`mapmerge/rules.toml`)

| Rule | Default | Effect |
|---|---|---|
| `maps.skip_broken` | `true` | Skip maps whose `.bsp` is truncated or corrupt. |
| `maps.skip_critical_missing` | `true` | Skip maps missing a model or sprite that HLDS has to precache. |
| `maps.skip_missing_textures` | `false` | Skip maps that use textures not found in any WAD. |
| `maps.exclude` / `maps.include` | `[]` | Map names to never merge, or to always merge regardless of the rules above. |
| `conflicts.strategy` | `"largest"` | When different files have the same destination, keep the `largest` or the `smallest`. |
| `conflicts.prefer` | | Per-path override, mapping a destination path to text in the source to use (e.g. `"ns_rust.wad" = "ns_rust_1.3.zip"`). |
| `dist.overwrite` | `false` | Replace `dist/ns/` files that have a different version in `ns_maps`. |
| `files.include_archive_siblings` | `true` | Also merge files shipped in the same archive as a merged map. |
| `files.exclude` | `[]` | Destination paths (glob patterns) to never merge. |
| `files.place` | | Force-merge a file that no map needs to a destination, e.g. `"ns_foo_str.cfg" = "maps/ns_foo_str.cfg"`. |
| `mapcycle.minplayers` / `mapcycle.maxplayers` | `0` / `32` | Player limits written for every map in every mapcycle file. |
| `mapcycle.exclude` | `[]` | Map names (glob patterns) never to list in a mapcycle, apart from the original. |
| `mapcycle.include` | `[]` | Maps to list in the filtered mapcycles even if a better version exists. |

When a map is skipped, its own files (`.bsp`, `.res`, `.txt`, minimap and navmesh) are skipped with it. So are any other files that only skipped maps use. If an included map also uses a file, such as a shared WAD, it's still merged. Unknown keys in `rules.toml` are reported as errors, so typos don't get ignored. Destination paths are checked before copying: anything absolute, with `..` or with a drive letter is refused, because these paths come from map data and archives.

### How the analysis works

Inside the container, the analyzer does the following:

1. **Collect:** extracts every archive, including nested ones, with `unar` (zip, rar and 7z). It then works out where each file belongs in the mod directory:
   - `.bsp` files always go to `maps/` and `.wad` files always to the mod root.
   - For anything else, the first game folder in the path (`maps/`, `gfx/`, `models/`, `sound/`, `sprites/` and so on) anchors it, so `nsp/sound/x.wav` becomes `sound/x.wav`.
   - Loose files are placed by type: `.res` and map `.txt` files go to `maps/`, `<map>.spr` to `sprites/minimaps/`, skybox images to `gfx/env/`. Anything else stays available for lookup by name.
   - Screenshots, documents and leftovers of interrupted downloads (`.ztmp`, `.part`) are ignored, and `ns_foo (1).bsp` is treated as `ns_foo.bsp`.
2. **Dedupe:** files are compared by SHA-1. Identical copies are collapsed. A needed file with several different versions is reported as a **conflict**.
3. **Compare with `dist/ns/`:** each needed file is classified as new, already present (identical), or **differs** from the file that ships with NS.
4. **Check requirements** for every map, gathered from:
   - the BSP's own entity data: WADs, skybox, models, sprites and sounds;
   - its `.res` file;
   - its `.txt` hints (low confidence).

   Each requirement is looked up by path in `ns_maps`, then in `dist/ns` and Half-Life's `valve/` directory, and finally by name anywhere in `ns_maps`. Paths are normalized first: `\` becomes `/`, and `./`, `../` and leading mod folders like `valve/` are dropped. The analyzer also reads the BSP's texture list and checks that every texture not embedded in the map exists in an available WAD.

Missing requirements get a severity:
- **critical:** a model or sprite used by an entity. HLDS can't load the map without it.
- **textures:** textures the map uses aren't in any available WAD.
- **minor:** sounds, skyboxes, or files only listed in the `.res`.

The report also flags broken BSPs (including Source-engine maps, which GoldSrc can't run), archives that fail to extract, case mismatches (Linux is case-sensitive), and maps without a minimap or bot navmesh.

Half-Life's `valve/` content comes from an anonymous SteamCMD install of HLDS (app 90) in a build stage. It's about 1 GB and is cached after the first run. `ns_maps/` and `dist/ns/` are passed in as named build contexts (`--build-context`), so they don't go through the repo's `.dockerignore`.

See `src/README.md` for upstream notes on playing, hosting and building on Windows (Visual Studio `Natural_Selection.sln`).

## Licensing and credits

- Natural Selection was created by Charlie Cleveland / Unknown Worlds Entertainment. The NS code is under the GPL (`COPYING.txt` in ENSL/NS). Some code is excluded from the GPL: the Half-Life SDK, FMOD, Lua and the particle library. See the upstream README.
- The v3.x updates come from the [ENSL](https://github.com/ENSL) community. The original HLDS container came from ENSL as well.
- Half-Life and HLDS are owned by Valve. HLDS is installed at build time through SteamCMD and is not redistributed here.
