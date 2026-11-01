# config/

Every setting for the server lives here. The folder has the same layout as the
`ns/` mod directory in the server image, so `addons/amxmodx/configs/amxx.cfg`
here becomes `ns/addons/amxmodx/configs/amxx.cfg` there.

- **`X.example`** files are the committed defaults. Don't edit them.
- **To change one, copy it without `.example`** (for example
  `cp server.cfg.example server.cfg`) and edit your copy. Your copies are
  gitignored, so they stay local, and a copy always wins over its example.
- **Any other file you add** (no `.example`) is copied into `ns/` as it is,
  for example `mapcycle.txt`, `banned.cfg` or `dlls/ns_v33b9.so`.

`hosting/build.sh` (the image step of `./setup.sh`) installs this folder over
the mod directory, after the maps and plugins. Files under `addons/<name>/`
are only installed when the image has that plugin, for example
`PLUGINS=amxmodx`. When an example changes after you made your copy, the build
prints a note, so you can merge the change.

| File | What it is |
|---|---|
| `.env.default` → `.env` | Container settings: port, launch options (players, map, mapcycle), **passwords**, HLTV, log rotation. Compose reads both files, so a change only needs `compose up -d`. For a port change, run `hosting/build.sh env` first, or let `./setup.sh` do it. Never copied into the image. |
| `server.cfg.example` | Server cvars: hostname, bots, time limit and so on. `./setup.sh` sets the hostname and bots in your copy. |
| `motd.txt.example` | The message of the day that joining players see. |
| `addons/metamod/config.ini.example`, `plugins.ini.example` | Metamod-P: the game DLL it loads, and its plugins (AMX Mod X). |
| `addons/amxmodx/configs/plugins.ini.example` | Which AMX Mod X plugins load (a leading `;` disables one). Entries whose `.amxx` wasn't built are commented out in the image with `[not built]`. |
| `addons/amxmodx/configs/*.example` | AMX Mod X 1.10's own configs: `amxx.cfg` (cvars), `users.ini` (**admins**), `maps.ini`, `modules.ini`, `cmds.ini` and so on. |
| `addons/amxmodx/configs/extralevels3.cfg`, `el3_ban.cfg`, `toggle_random_nvault.cfg`, `hivelocs.ini`, `kickball.ini`, `pause4vip.ini`, `sprites.ini` | Settings of the custom plugins, from the old server. |
| `addons/amxmodx/configs/mvm_configs/` | Building positions per map for MvM/AvA (`mvm_allinone`). |
| `addons/amxmodx/configs/maps/plugins-<map>.ini.example` | Plugins turned off on single maps. |

Secrets (`.env`, `users.ini`) never belong in an `.example` file. Lists of
players' Steam IDs (`stacksplit.ini`, `constant_names.ini`,
`clan_night_attendants.ini`, `icons.conf`) are your own files too, not
examples.
