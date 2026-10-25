#!/usr/bin/env python3
"""Analyze custom NS maps against a built ns mod directory.

--maps is a loose dump: every .bsp in it (loose or in archives, including
nested ones) is a map; every other file is only a source for what those maps
need. Works out where each file belongs in the mod directory, what each map
needs (from the BSP itself, its .res file and .txt hints) and resolves those
requirements against the collected files (by path, then by file name), --ns
and --valve. Writes report.md and report.json to --out.

Nothing is merged; this is the analysis step only.
"""
import argparse
import datetime
import hashlib
import json
import re
import shutil
import struct
import subprocess
from collections import defaultdict
from pathlib import Path, PurePosixPath

ARCHIVE_EXTS = {".zip", ".rar", ".7z", ".tar", ".gz", ".tgz", ".bz2", ".xz"}
MAX_ARCHIVE_DEPTH = 3
# Top-level directories of a mod; the first one found in an archive path anchors it
# (so nsp/maps/x.bsp, Half-Life/ns/maps/x.bsp and maps/x.bsp all become maps/x.bsp).
GAME_DIRS = {"maps", "gfx", "models", "sound", "sprites", "overviews", "media", "music", "resource", "navmeshes"}
DIR_ALIASES = {"sounds": "sound"}  # common packaging mistakes
# Screenshots, sources and documents: never needed by the game
DOC_EXTS = {".jpg", ".jpeg", ".png", ".gif", ".pcx", ".psd", ".doc", ".docx", ".pdf", ".rtf", ".htm",
            ".html", ".url", ".rmf", ".map", ".jmf"}
JUNK_NAMES = {"thumbs.db", "desktop.ini", ".ds_store"}
# Leftovers of interrupted downloads/extractions
JUNK_EXTS = {".ztmp", ".part", ".crdownload", ".tmp", ".partial"}
REF_EXTS = (".wad", ".mdl", ".spr", ".wav", ".mp3", ".tga", ".bmp")
SKY_SIDES = ("up", "dn", "lf", "rt", "ft", "bk")
# WADs shipped with Half-Life itself (valve/), available on every HLDS install.
VALVE_WADS = {"halflife.wad", "liquids.wad", "xeno.wad", "decals.wad", "cached.wad", "gfx.wad",
              "fonts.wad", "spraypaint.wad", "tempdecal.wad", "pldecal.wad"}
# Browser/Windows copy suffix: "ns_foo (1).bsp" -> "ns_foo.bsp"
COPY_SUFFIX = re.compile(r" \(\d+\)(?=\.[^.]+$)")
TXT_REF = re.compile(r"[\w\-./\\]+\.(?:wad|mdl|spr|wav|mp3|tga|bmp)\b", re.IGNORECASE)
ENT_BLOCK = re.compile(r"\{([^{}]*)\}", re.S)
ENT_KV = re.compile(r'"([^"]*)"\s*"([^"]*)"')


def sha1(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def norm_ref(path):
    """Normalize a referenced path: forward slashes, no empty or dot-only parts
    (./, ../, .../), and no leading mod directory (../valve/models/x.mdl ->
    models/x.mdl)."""
    parts = [p for p in path.strip().replace("\\", "/").split("/") if p.strip(".")]
    for i, p in enumerate(parts[:-1]):
        if p.lower() in GAME_DIRS:
            parts = parts[i:]
            break
    return "/".join(parts)


def ext_of(name):
    return PurePosixPath(name).suffix.lower()


def stem_of(name):
    return PurePosixPath(name).stem


# --------------------------------------------------------------------------
# Collection and extraction
# --------------------------------------------------------------------------

class Collector:
    def __init__(self, maps_root, work):
        self.maps_root = maps_root
        self.work = work
        self.raw = []          # {"origin", "member", "path"}
        self.archives = []     # {"archive", "files", "ok", "error"}
        self._n = 0

    def run(self):
        for path in sorted(p for p in self.maps_root.rglob("*") if p.is_file()):
            rel = path.relative_to(self.maps_root).as_posix()
            if ext_of(path.name) in ARCHIVE_EXTS:
                self._extract(path, rel, 0)
            else:
                parent = str(PurePosixPath(rel).parent)
                self.raw.append({"origin": parent if parent != "." else "(root)",
                                 "member": path.name, "path": path, "archive": False})

    def _extract(self, archive, label, depth):
        self._n += 1
        dest = self.work / f"{self._n:04d}"
        dest.mkdir(parents=True)
        r = subprocess.run(["unar", "-q", "-f", "-D", "-o", str(dest), str(archive)],
                           stdin=subprocess.DEVNULL, capture_output=True, text=True)
        files = sorted(p for p in dest.rglob("*") if p.is_file())
        self.archives.append({"archive": label, "files": len(files), "ok": r.returncode == 0,
                              "error": (r.stderr or r.stdout).strip()[-500:] if r.returncode else ""})
        for p in files:
            member = p.relative_to(dest).as_posix()
            if ext_of(p.name) in ARCHIVE_EXTS and depth < MAX_ARCHIVE_DEPTH:
                self._extract(p, f"{label}!{member}", depth + 1)
            else:
                self.raw.append({"origin": label, "member": member, "path": p, "archive": True})


def place(member, origin_map_stems):
    """Return (kind, target) for an archive/folder member.

    kind: placed | doc | unplaced | junk
    """
    parts = [p for p in member.replace("\\", "/").split("/") if p not in ("", ".")]
    if not parts or any(p == "__MACOSX" for p in parts) or parts[-1].lower() in JUNK_NAMES:
        return "junk", None
    name = parts[-1]
    ext, stem = ext_of(name), stem_of(name).lower()
    if ext in JUNK_EXTS:
        return "junk", None
    if ext in DOC_EXTS:
        return "doc", None
    # These only work in one place, whatever folder they were dumped in
    if ext == ".bsp":
        return "placed", f"maps/{name}"
    if ext == ".wad":
        return "placed", name
    for i, p in enumerate(parts[:-1]):
        d = DIR_ALIASES.get(p.lower(), p.lower())
        if d in GAME_DIRS:
            return "placed", "/".join([d] + parts[i + 1:])
    if ext == ".res":
        return "placed", f"maps/{name}"
    if ext == ".nav":
        return "placed", f"navmeshes/{name}"
    if ext == ".txt":
        # maps/<map>.txt (map info) or maps/<map>_detail.txt (detail textures)
        if stem in origin_map_stems or stem.removesuffix("_detail") in origin_map_stems:
            return "placed", f"maps/{name}"
        return "doc", None
    if ext in (".tga", ".bmp") and stem[-2:] in SKY_SIDES:
        return "placed", f"gfx/env/{name}"
    if ext == ".spr" and stem in origin_map_stems:  # <map>.spr is the map's minimap
        return "placed", f"sprites/minimaps/{name}"
    return "unplaced", None


# --------------------------------------------------------------------------
# File formats
# --------------------------------------------------------------------------

def parse_entities(text):
    ents = []
    for block in ENT_BLOCK.findall(text):
        ents.append({k: v for k, v in ENT_KV.findall(block)})
    return ents


def parse_bsp(path):
    data = path.read_bytes()
    if len(data) < 4 + 15 * 8:
        return {"error": "file too small"}
    version = struct.unpack_from("<i", data, 0)[0]
    if data[:4] == b"VBSP":
        return {"error": "Source engine (HL2) map, not GoldSrc"}
    if version != 30:
        return {"error": f"unsupported BSP version {version} (GoldSrc is 30)"}
    lumps = [struct.unpack_from("<ii", data, 4 + i * 8) for i in range(15)]

    def lump_text(i):
        off, size = lumps[i]
        return data[off:off + size].split(b"\0", 1)[0].decode("latin-1")

    text = lump_text(0)
    if not text.lstrip().startswith("{"):
        text = lump_text(1)  # Blue Shift layout swaps lumps 0 and 1
    ents = parse_entities(text)

    external = []
    off, size = lumps[2]
    try:
        if size >= 4:
            count = struct.unpack_from("<i", data, off)[0]
            for mo in struct.unpack_from(f"<{count}i", data, off + 4):
                if mo < 0:
                    continue
                base = off + mo
                name = data[base:base + 16].split(b"\0", 1)[0].decode("latin-1")
                first_mip = struct.unpack_from("<I", data, base + 24)[0]
                if first_mip == 0:  # pixel data not embedded -> comes from a WAD
                    external.append(name.lower())
    except struct.error:
        return {"entities": ents, "external_textures": sorted(set(external)),
                "error": f"texture lump extends past end of file ({len(data)} bytes): truncated or corrupt"}
    return {"entities": ents, "external_textures": sorted(set(external))}


_wad_cache = {}


def wad_textures(path):
    if path not in _wad_cache:
        names = None
        try:
            with open(path, "rb") as f:
                hdr = f.read(12)
                if hdr[:4] in (b"WAD3", b"WAD2"):
                    n, diroff = struct.unpack("<ii", hdr[4:])
                    f.seek(diroff)
                    d = f.read(32 * n)
                    names = {d[i * 32 + 16:i * 32 + 32].split(b"\0", 1)[0].decode("latin-1").lower()
                             for i in range(n)}
        except OSError:
            pass
        _wad_cache[path] = names
    return _wad_cache[path]


def read_text(path):
    """Read a .res/.txt written by any Windows tool: UTF-16 (with BOM), UTF-8 or latin-1."""
    data = path.read_bytes()
    if data.startswith((b"\xff\xfe", b"\xfe\xff")):
        return data.decode("utf-16", "replace")
    if data.startswith(b"\xef\xbb\xbf"):
        return data[3:].decode("utf-8", "replace")
    return data.decode("latin-1")


def parse_res(path):
    refs = []
    for line in read_text(path).splitlines():
        line = line.split("//", 1)[0].strip().strip('"').strip()
        if line:
            refs.append(norm_ref(line))
    return refs


def bsp_refs(ents):
    """[(path, how)] referenced by the map's entities."""
    refs = []
    world = ents[0] if ents else {}
    for w in world.get("wad", "").split(";"):
        w = w.strip().replace("\\", "/")
        # Some compilers leave garbage bytes in the list; keep only real .wad names
        if w.lower().endswith(".wad") and w.isprintable():
            refs.append((w.rsplit("/", 1)[-1], "bsp:worldspawn.wad"))
    sky = world.get("skyname", "").strip()
    if sky:
        refs += [(f"gfx/env/{sky}{s}.tga", "bsp:worldspawn.skyname") for s in SKY_SIDES]
    for e in ents:
        cls = e.get("classname", "?")
        for k, v in e.items():
            v = norm_ref(v)
            if k == "wad" or v.startswith(("*", "!")) or not v.lower().endswith(REF_EXTS):
                continue
            if ext_of(v) == ".wav" and not v.lower().startswith("sound/"):
                v = f"sound/{v}"
            refs.append((v, f"bsp:{cls}.{k}"))
    return refs


# --------------------------------------------------------------------------
# Analysis
# --------------------------------------------------------------------------

class Index:
    """Case-insensitive path index: lower path -> actual path."""

    def __init__(self, paths=()):
        self.by_lower = {}
        for p in paths:
            self.by_lower.setdefault(p.lower(), p)

    def get(self, path):
        return self.by_lower.get(path.lower())


def analyze(maps_root, ns_root, valve_root, work):
    """ns_maps is a loose dump: every .bsp in it is a map; every other file is
    only a source for what those maps need (matched by path, then by name)."""
    col = Collector(maps_root, work)
    col.run()

    # Map stems per origin, so loose map .txt files can be told apart from readmes
    stems_by_origin = defaultdict(set)
    for r in col.raw:
        if ext_of(r["member"]) == ".bsp":
            stems_by_origin[r["origin"]].add(COPY_SUFFIX.sub("", stem_of(r["member"])).lower())
            stems_by_origin[r["origin"]].add(stem_of(r["member"]).lower())

    candidates = {}   # lower target -> {"target", "variants": {sha1: [source...]}}
    by_name = defaultdict(list)   # lower file name -> [source...], placed or not
    docs, unplaced, junk = [], [], 0
    renamed = []
    for r in col.raw:
        member = r["member"]
        clean = COPY_SUFFIX.sub("", member)
        kind, target = place(clean, stems_by_origin[r["origin"]])
        src = {"origin": r["origin"], "member": member, "path": str(r["path"])}
        if kind == "junk":
            junk += 1
            continue
        if kind == "doc":
            docs.append(src)
            continue
        src["sha1"] = sha1(r["path"])
        src["size"] = r["path"].stat().st_size
        by_name[PurePosixPath(clean).name.lower()].append(src)
        if kind == "unplaced":
            unplaced.append(src)
            continue
        if clean != member:
            renamed.append({**src, "target": target})
        c = candidates.setdefault(target.lower(), {"target": target, "variants": {}})
        c["variants"].setdefault(src["sha1"], []).append(src)

    dist_files = sorted(p.relative_to(ns_root).as_posix() for p in ns_root.rglob("*") if p.is_file())
    dist = Index(dist_files)
    cand = Index(c["target"] for c in candidates.values())
    valve_files = (sorted(p.relative_to(valve_root).as_posix() for p in valve_root.rglob("*") if p.is_file())
                   if valve_root else [])
    valve = Index(valve_files)

    def first_variant_path(lower_target):
        c = candidates[lower_target]
        return Path(next(iter(c["variants"].values()))[0]["path"])

    # Status of each candidate file vs dist/ns
    files = []
    for key, c in sorted(candidates.items()):
        entry = {"target": c["target"], "variants": len(c["variants"]),
                 "sources": [s for v in c["variants"].values() for s in v]}
        in_dist = dist.get(c["target"])
        if in_dist is not None:
            entry["dist_path"] = in_dist
            entry["dist_sha1"] = sha1(ns_root / in_dist)
        if len(c["variants"]) > 1:
            entry["status"] = "conflict"
        elif in_dist is None:
            entry["status"] = "new"
        else:
            same = entry["dist_sha1"] == next(iter(c["variants"]))
            entry["status"] = "in_dist_identical" if same else "differs_from_dist"
        files.append(entry)
    file_status = {f["target"].lower(): f for f in files}

    # Files found only by name (anywhere in ns_maps, in any folder), copied to
    # the path the map expects: lower destination -> {"dest", "chosen", "variants", "maps"}
    name_uses = {}

    def name_lookup(dest):
        """Find a file named like dest anywhere in ns_maps. -> destination or None"""
        entries = by_name.get(PurePosixPath(dest).name.lower())
        if not entries:
            return None
        if dest.lower() not in name_uses:
            variants = {e["sha1"]: e for e in entries}
            chosen = max(variants.values(), key=lambda e: e["size"])
            name_uses[dest.lower()] = {"dest": dest, "chosen": chosen, "variants": len(variants),
                                       "sources": len(entries), "maps": set()}
        return name_uses[dest.lower()]["dest"]

    def resolve(ref):
        """-> (status, actual path or None). status: maps | dist | valve | name | missing"""
        is_wad = ext_of(ref) == ".wad"
        tries = [ref.rsplit("/", 1)[-1]] if is_wad else [ref.lstrip("/")]
        if ext_of(ref) == ".mp3" and not ref.lower().startswith("sound/"):
            tries.append(f"sound/{ref}")
        for t in tries:
            if (hit := cand.get(t)):
                return "maps", hit
            if (hit := dist.get(t)):
                return "dist", hit
            if (hit := valve.get(t)):
                return "valve", hit
        if not valve_root and is_wad and tries[0].lower() in VALVE_WADS:
            return "valve", None
        # Fill by name only where the engine would look: WADs in the root, other
        # files under a game folder. Bare names (readme hints like "archer.mdl")
        # and paths outside the game folders (.res typos like sounds/... or
        # mbience/...) have no usable destination.
        dest = tries[0] if is_wad else next(
            (t for t in tries if "/" in t and t.split("/", 1)[0].lower() in GAME_DIRS), None)
        if dest and (dest := name_lookup(dest)):
            return "name", dest
        return "missing", None

    def actual_file(status, hit):
        if status == "maps":
            return first_variant_path(hit.lower())
        if status == "dist":
            return ns_root / hit
        if status == "valve" and hit:
            return valve_root / hit
        if status == "name":
            return Path(name_uses[hit.lower()]["chosen"]["path"])
        return None

    # Per-map requirements
    maps = []
    origins_of = defaultdict(set)
    for key, c in candidates.items():
        for v in c["variants"].values():
            for s in v:
                origins_of[key].add(s["origin"])
    docs_by_origin = defaultdict(list)
    for d in docs:
        docs_by_origin[d["origin"]].append(d)

    for key, c in sorted(candidates.items()):
        if not (key.startswith("maps/") and key.endswith(".bsp")):
            continue
        name = stem_of(c["target"])
        m = {"map": name, "file": file_status[key]["status"],
             "origins": sorted(origins_of[key]), "requirements": [], "notes": []}
        refs = defaultdict(set)   # path -> sources

        bsp = parse_bsp(first_variant_path(key))
        if "error" in bsp:
            m["bsp_error"] = bsp["error"]
            m["notes"].append(f"**BSP problem: {bsp['error']}**")
            bsp.setdefault("entities", [])
            bsp.setdefault("external_textures", [])
        for path, how in bsp_refs(bsp["entities"]):
            refs[path].add(how)

        res_key = f"maps/{name}.res".lower()
        if res_key in candidates:
            for path in parse_res(first_variant_path(res_key)):
                refs[path].add("res")
        elif (d := dist.get(f"maps/{name}.res")):
            for path in parse_res(ns_root / d):
                refs[path].add("res (dist)")

        txt_paths = []
        for k in (f"maps/{name}.txt".lower(), f"maps/{name}_detail.txt".lower()):
            if k in candidates:
                txt_paths.append(first_variant_path(k))
        for origin in origins_of[key]:
            if "/" in origin or origin.endswith(tuple(ARCHIVE_EXTS)) or "!" in origin:
                txt_paths += [Path(d["path"]) for d in docs_by_origin[origin] if ext_of(d["member"]) == ".txt"]
        for tp in txt_paths:
            for hit in TXT_REF.findall(read_text(tp)):
                refs[norm_ref(hit)].add(f"txt:{tp.name}")

        # Merge refs that differ only by case; keep the first spelling
        merged = {}
        for path, how in refs.items():
            merged.setdefault(path.lower(), [path, set()])[1].update(how)

        listed_wads = []
        for lower, (path, how) in sorted(merged.items()):
            status, hit = resolve(path)
            req = {"path": path, "from": sorted(how), "status": status}
            if status == "name":
                name_uses[hit.lower()]["maps"].add(name)
            if "/" in path and path.split("/", 1)[0].lower() not in GAME_DIRS and status == "missing":
                req["invalid_folder"] = True
            if hit:
                req["found"] = hit
                if status in ("maps", "dist", "valve") and ext_of(path) != ".wad" and hit != path.lstrip("/"):
                    req["case_mismatch"] = True
            only_txt = all(h.startswith("txt:") for h in how)
            if status == "missing" and only_txt:
                req["status"] = "missing_txt_hint"
            m["requirements"].append(req)
            if ext_of(path) == ".wad" and any(h.startswith("bsp:") or h.startswith("res") for h in how):
                listed_wads.append((path, status, hit))

        # Which external textures can't be found in the map's available WADs?
        ext_tex = set(bsp["external_textures"])
        if ext_tex:
            available = set()
            unreadable = []
            for path, status, hit in listed_wads:
                f = actual_file(status, hit)
                if f is not None:
                    names = wad_textures(f)
                    if names is None:
                        unreadable.append(path)
                    else:
                        available |= names
            missing_tex = sorted(ext_tex - available)
            # Without a valve/ directory, valve WADs can't be read; textures may be in them
            valve_unread = [p for p, s, hit in listed_wads if s == "valve" and not hit]
            m["textures"] = {"external": len(ext_tex), "unresolved": missing_tex,
                             "may_be_in_valve_wads": bool(valve_unread and missing_tex),
                             "unreadable_wads": unreadable}
        else:
            m["textures"] = {"external": 0, "unresolved": [], "may_be_in_valve_wads": False,
                             "unreadable_wads": []}

        # Severity of what's missing:
        #  critical: models/sprites used by entities are precached; HLDS fails to load the map
        #  textures: a missing WAD matters only if some external textures are unresolved
        #  minor:    sounds, skies, .res-only files (clients just miss them)
        tex_ok = not m["textures"]["unresolved"] and not m["textures"]["unreadable_wads"]
        for q in m["requirements"]:
            if q["status"] != "missing":
                continue
            e = ext_of(q["path"])
            from_bsp = any(h.startswith("bsp:") and not h.startswith("bsp:worldspawn") for h in q["from"])
            if e == ".wad":
                q["severity"] = "unneeded" if tex_ok else "textures"
            elif e in (".mdl", ".spr") and from_bsp:
                q["severity"] = "critical"
            else:
                q["severity"] = "minor"

        # Minimap and bot navmesh aren't needed to load the map; find them by
        # name elsewhere in ns_maps when available, otherwise note their absence.
        for what, extra in (("minimap", f"sprites/minimaps/{name}.spr"), ("bot navmesh", f"navmeshes/{name}.nav")):
            if cand.get(extra) or dist.get(extra) or extra.lower() in merged:
                continue
            if (dest := name_lookup(extra)):
                name_uses[dest.lower()]["maps"].add(name)
                m["requirements"].append({"path": extra, "from": [f"ns:{what}"], "status": "name", "found": dest})
            else:
                m["notes"].append(f"no {what} ({extra})")
        if not name.lower().startswith(("ns_", "co_")):
            m["notes"].append("name has no ns_/co_ prefix (game mode is chosen by prefix)")
        maps.append(m)

    # Why each collected file might be merged:
    #   own_of:     the map's own files (bsp, res, txt, minimap, navmesh)
    #   used_by:    maps whose requirements resolved to it by path
    #   sibling_of: maps in the same archive (mappers ship assets there that
    #               nothing references directly)
    archive_maps = defaultdict(set)
    for m in maps:
        for o in m["origins"]:
            if "!" in o or o.lower().endswith(tuple(ARCHIVE_EXTS)):
                archive_maps[o].add(m["map"])
    own = {}
    used = defaultdict(set)
    for m in maps:
        n = m["map"]
        for p in (f"maps/{n}.bsp", f"maps/{n}.res", f"maps/{n}.txt", f"maps/{n}_detail.txt",
                  f"sprites/minimaps/{n}.spr", f"navmeshes/{n}.nav"):
            own[p.lower()] = n
        for q in m["requirements"]:
            if q["status"] == "maps":
                used[q["found"].lower()].add(n)
    for f in files:
        key = f["target"].lower()
        if key in own:
            f["own_of"] = own[key]
        f["used_by"] = sorted(used.get(key, ()), key=str.lower)
        f["sibling_of"] = sorted({n for s in f["sources"] for n in archive_maps.get(s["origin"], ())} - {own.get(key)},
                                 key=str.lower)
        f["needed"] = bool(f.get("own_of") or f["used_by"])

    # .res files without a map
    orphan_res = [c["target"] for k, c in candidates.items()
                  if k.startswith("maps/") and k.endswith(".res")
                  and f"{k[:-4]}.bsp" not in candidates and not dist.get(f"{c['target'][:-4]}.bsp")]

    return {
        "generated": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
        "inputs": {"ns_maps_files": sum(1 for p in maps_root.rglob("*") if p.is_file()),
                   "archives": len(col.archives), "collected_files": len(col.raw),
                   "dist_files": len(dist_files), "valve_files": len(valve_files)},
        "archives": col.archives,
        "files": files,
        "maps": maps,
        "name_uses": [{**u, "maps": sorted(u["maps"], key=str.lower)}
                      for _, u in sorted(name_uses.items()) if u["maps"]],
        "unplaced": unplaced,
        "docs": docs,
        "renamed": renamed,
        "orphan_res": sorted(orphan_res),
        "junk": junk,
    }


# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------

def md_report(r):
    files, maps = r["files"], r["maps"]
    # Only files some map needs matter for conflicts and dist/ns differences;
    # the rest of the dump is never merged.
    needed = [f for f in files if f["needed"]]
    by_status = defaultdict(list)
    for f in needed:
        by_status[f["status"]].append(f)
    siblings = [f for f in files if not f["needed"] and f["sibling_of"]]
    dupes = [f for f in needed if len(f["sources"]) > 1 and f["variants"] == 1]
    failed = [a for a in r["archives"] if not a["ok"]]
    by_name_chosen = {(u["chosen"]["origin"], u["chosen"]["member"]) for u in r["name_uses"]}
    other = (len(files) - len(needed) - len(siblings)
             + sum(1 for u in r["unplaced"] if (u["origin"], u["member"]) not in by_name_chosen))

    def needs(m, *severities):
        return [q for q in m["requirements"] if q.get("severity") in severities]

    def tex_problem(m):
        return bool(m["textures"]["unresolved"]) and not m["textures"]["may_be_in_valve_wads"]

    missing_maps = [m for m in maps if needs(m, "critical", "textures", "minor") or tex_problem(m)]
    critical_maps = [m for m in maps if needs(m, "critical")]
    texture_maps = [m for m in maps if tex_problem(m)]
    map_status = defaultdict(int)
    for m in maps:
        map_status[m["file"]] += 1

    out = []
    w = out.append
    w("# ns_maps analysis report\n")
    w(f"Generated {r['generated']}. Inputs: `ns_maps/` ({r['inputs']['ns_maps_files']} files, "
      f"{r['inputs']['archives']} archives extracted, {r['inputs']['collected_files']} files collected) "
      f"compared against `dist/ns/` ({r['inputs']['dist_files']} files)"
      + (f" and Half-Life `valve/` from HLDS ({r['inputs']['valve_files']} files)" if r['inputs']['valve_files']
         else "; no Half-Life `valve/` directory was given, so base-game references are unchecked")
      + ".\n")
    w("`ns_maps/` is treated as a loose dump: every `.bsp` in it is a map, and every other file is only a "
      "source for what those maps need. This is the analysis step only: nothing has been merged.\n")

    w("## Summary\n")
    w("| | Count |\n|---|---:|")
    rows = [
        ("Maps found", len(maps)),
        ("… new (not in dist/ns)", map_status["new"]),
        ("… already in dist/ns (identical)", map_status["in_dist_identical"]),
        ("… **differ from the dist/ns version**", map_status["differs_from_dist"]),
        ("… **several different versions in ns_maps**", map_status["conflict"]),
        ("Maps with missing requirements (any)", len(missing_maps)),
        ("… **won't load** (missing precached model/sprite)", len(critical_maps)),
        ("… **missing textures**", len(texture_maps)),
        ("**Broken map files**", sum(1 for m in maps if m.get("bsp_error"))),
        ("Files the maps need, found by path (own files + requirements)", len(needed)),
        ("… new to dist/ns", len(by_status["new"])),
        ("… identical copy already in dist/ns", len(by_status["in_dist_identical"])),
        ("… **differ from dist/ns**", len(by_status["differs_from_dist"])),
        ("… **conflicts** (several different versions)", len(by_status["conflict"])),
        ("Files the maps need, found by name in another folder", len(r["name_uses"])),
        ("… **several different files with that name**", sum(1 for u in r["name_uses"] if u["variants"] > 1)),
        ("Archive siblings (shipped with a map, not referenced)", len(siblings)),
        ("Other files (not needed by any map; not merged)", other),
        ("Duplicate copies of needed files (identical, collapsed)", sum(len(f["sources"]) - 1 for f in dupes)),
        ("**Archive errors**", len(failed)),
        ("Docs, readmes, screenshots (not merged; .txt read for hints)", len(r["docs"])),
    ]
    for k, v in rows:
        w(f"| {k} | {v} |")
    w("")

    w("## Action needed\n")
    bad_bsp = [m for m in maps if m.get("bsp_error")]
    if bad_bsp:
        w("### Broken map files\n")
        for m in bad_bsp:
            w(f"- {m['map']}: {m['bsp_error']} (from {', '.join(f'`{o}`' for o in m['origins'])})")
        w("")
    if failed:
        w("### Archive errors\n")
        w("Truncated or corrupt archives; re-download them. Files that did extract are still analyzed.\n")
        for a in failed:
            lines = [l.strip() for l in a["error"].splitlines() if "Failed!" in l]
            detail = "; ".join(f"`{l.split('  ', 1)[0]}`" for l in lines) or a["error"] or "failed"
            w(f"- `{a['archive']}`: failed to extract {detail}")
        w("")
    if by_status["conflict"]:
        w("### Conflicts\n")
        w("A needed file exists in several different versions in ns_maps. The merge keeps the largest "
          "unless `conflicts.prefer` in rules.toml says otherwise.\n")
        for f in by_status["conflict"]:
            w(f"- `{f['target']}`")
            for s in f["sources"]:
                w(f"  - `{s['sha1'][:10]}` {s['size']:>9} B  `{s['origin']}` → `{s['member']}`")
        w("")
    if by_status["differs_from_dist"]:
        w("### Differs from dist/ns\n")
        w("A needed file has a different version in dist/ns. The merge keeps the dist/ns version unless "
          "`dist.overwrite` is set.\n")
        for f in by_status["differs_from_dist"]:
            s = f["sources"][0]
            w(f"- `{f['target']}` (from `{s['origin']}`)")
        w("")
    if missing_maps:
        w("### Missing requirements\n")
        w("Referenced by the map (BSP entities, .res) but not found anywhere: not in ns_maps (by path or "
          "by name), dist/ns or Half-Life's valve/. Drop the missing files anywhere in `ns_maps/` (e.g. "
          "`ns_maps/misc/`) and re-run. Severity:\n")
        w("- **critical**: a model/sprite used by an entity. HLDS precaches these and fails to load "
          "the map without them.")
        w("- **textures**: the map uses textures that aren't in any available WAD; the listed missing "
          "WADs probably hold them.")
        w("- **minor**: sounds, skyboxes, files only listed in the .res. The map loads; clients miss "
          "the asset.\n")
        order = {"critical": 0, "textures": 1, "minor": 2}
        for m in sorted(missing_maps, key=lambda m: (not needs(m, "critical"), not tex_problem(m), m["map"])):
            w(f"#### {m['map']}\n")
            for q in sorted(needs(m, "critical", "textures", "minor"), key=lambda q: (order[q["severity"]], q["path"])):
                bad = " — not a game folder (typo in the map's files)" if q.get("invalid_folder") else ""
                w(f"- **{q['severity']}** missing `{q['path']}` ({', '.join(q['from'])}){bad}")
            t = m["textures"]
            if tex_problem(m):
                w(f"- **textures** {len(t['unresolved'])} of {t['external']} external textures not in any "
                  "available WAD: " + ", ".join(f"`{x}`" for x in t["unresolved"][:12])
                  + (" …" if len(t["unresolved"]) > 12 else ""))
            w("")
    if not (bad_bsp or failed or by_status["conflict"] or by_status["differs_from_dist"] or missing_maps):
        w("Nothing. Everything resolved cleanly.\n")

    w("## Maps\n")
    w("Status: **new**, **in dist** (identical copy already there), **differs** (differs from the "
      "dist/ns version), **conflict** (several versions in ns_maps). Requirements are counted after "
      "de-duplicating paths.\n")
    w("| Map | Status | Requirements | Missing | Textures (external / unresolved) | Notes | Source |")
    w("|---|---|---:|---:|---|---|---|")
    labels = {"new": "new", "in_dist_identical": "in dist", "differs_from_dist": "**differs**",
              "conflict": "**conflict**"}
    for m in maps:
        crit, oth = len(needs(m, "critical")), len(needs(m, "textures", "minor"))
        miss = (f"**{crit} critical**" + (f" + {oth}" if oth else "")) if crit else (oth or "")
        t = m["textures"]
        tex = f"{t['external']} / {len(t['unresolved'])}"
        if t["unresolved"] and t["may_be_in_valve_wads"]:
            tex += " (valve wads?)"
        w(f"| {m['map']} | {labels[m['file']]} | {len(m['requirements'])} | {miss} | {tex} | "
          f"{'; '.join(m['notes'])} | {', '.join(f'`{o}`' for o in m['origins'])} |")
    w("")

    w("## Found by name\n")
    w("Needed files that weren't at the expected path but were found by file name somewhere in "
      "ns_maps. The merge copies them to the path the map expects.\n")
    if r["name_uses"]:
        for u in r["name_uses"]:
            c = u["chosen"]
            extra = (f" (**{u['variants']} different files with this name; largest used**)"
                     if u["variants"] > 1 else "")
            w(f"- `{u['dest']}` ← `{c['origin']}` → `{c['member']}`{extra}; used by {', '.join(u['maps'])}")
    else:
        w("None.")
    w("")

    w("## Warnings\n")
    case = [(m["map"], q) for m in maps for q in m["requirements"] if q.get("case_mismatch")]
    hints = [(m["map"], q) for m in maps for q in m["requirements"] if q["status"] == "missing_txt_hint"]
    valve_tex = [m for m in maps if m["textures"]["unresolved"] and m["textures"]["may_be_in_valve_wads"]]
    if case:
        w("### Case mismatches\n")
        w("Linux file names are case-sensitive; the reference and the file differ in case.\n")
        w("<details><summary>%d references</summary>\n" % len(case))
        for name, q in case:
            w(f"- {name}: `{q['path']}` → `{q['found']}`")
        w("\n</details>\n")
    if valve_tex:
        w("### Textures possibly in Half-Life base WADs\n")
        w("These maps use textures that aren't in any WAD available here, but they list Half-Life's own "
          "WADs (e.g. `halflife.wad`), which HLDS provides. Probably fine; verify against an HLDS "
          "`valve/` directory.\n")
        for m in valve_tex:
            w(f"- {m['map']}: {len(m['textures']['unresolved'])} of {m['textures']['external']}")
        w("")
    if hints:
        w("### Mentioned only in .txt files, not found\n")
        w("Low confidence: readmes often mention files that aren't needed (or that are embedded).\n")
        w("<details><summary>%d mentions</summary>\n" % len(hints))
        for name, q in hints:
            w(f"- {name}: `{q['path']}` ({', '.join(q['from'])})")
        w("\n</details>\n")
    unneeded = [(m["map"], q) for m in maps for q in needs(m, "unneeded")]
    if unneeded:
        w("### Listed WADs not found, but not needed\n")
        w("The map lists these WADs, but every texture it uses is embedded or found in other WADs.\n")
        w("<details><summary>%d WADs</summary>\n" % len(unneeded))
        for name, q in unneeded:
            w(f"- {name}: `{q['path']}` ({', '.join(q['from'])})")
        w("\n</details>\n")
    if r["orphan_res"]:
        w("### .res files without a map\n")
        for p in r["orphan_res"]:
            w(f"- `{p}`")
        w("")

    w("## Details\n")
    if r["renamed"]:
        w("<details><summary>Copy-suffix renames (%d)</summary>\n" % len(r["renamed"]))
        for s in r["renamed"]:
            w(f"- `{s['origin']}` → `{s['member']}` treated as `{s['target']}`")
        w("\n</details>\n")
    if dupes:
        w("<details><summary>Duplicates of needed files collapsed (%d paths)</summary>\n" % len(dupes))
        for f in dupes:
            w(f"- `{f['target']}` × {len(f['sources'])}: " + ", ".join(f"`{s['origin']}`" for s in f["sources"]))
        w("\n</details>\n")
    w("<details><summary>Needed files new to dist/ns (%d)</summary>\n" % len(by_status["new"]))
    for f in by_status["new"]:
        w(f"- `{f['target']}` (from `{f['sources'][0]['origin']}`)")
    w("\n</details>\n")
    w("<details><summary>Archive siblings (%d)</summary>\n" % len(siblings))
    for f in siblings:
        w(f"- `{f['target']}` (with {', '.join(f['sibling_of'])})")
    w("\n</details>\n")
    w("<details><summary>Archives (%d)</summary>\n" % len(r["archives"]))
    for a in r["archives"]:
        w(f"- `{a['archive']}`: {a['files']} files{'' if a['ok'] else ' — **error**'}")
    w("\n</details>\n")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--maps", type=Path, required=True, help="ns_maps directory")
    ap.add_argument("--ns", type=Path, required=True, help="built ns mod directory (dist/ns)")
    ap.add_argument("--valve", type=Path, help="Half-Life valve/ directory from HLDS (optional)")
    ap.add_argument("--out", type=Path, required=True, help="output directory for the report")
    ap.add_argument("--work", type=Path, default=Path("/tmp/mapmerge"), help="scratch dir for extraction")
    ap.add_argument("--state", type=Path,
                    help="also write the full result, with paths to the extracted files, here (for merge.py)")
    a = ap.parse_args()

    shutil.rmtree(a.work, ignore_errors=True)
    a.work.mkdir(parents=True)
    a.out.mkdir(parents=True, exist_ok=True)

    result = analyze(a.maps, a.ns, a.valve, a.work)
    if a.state:
        a.state.parent.mkdir(parents=True, exist_ok=True)
        a.state.write_text(json.dumps(result, indent=2))
    # name_uses[].chosen are the same objects as files[].sources / unplaced entries
    for s in result["unplaced"] + result["docs"]:
        s.pop("path", None)
    for f in result["files"]:
        for s in f["sources"]:
            s.pop("path", None)
    for s in result["renamed"]:
        s.pop("path", None)

    (a.out / "report.json").write_text(json.dumps(result, indent=2))
    (a.out / "report.md").write_text(md_report(result))
    print(f"maps: {len(result['maps'])}, files: {len(result['files'])}, "
          f"unplaced: {len(result['unplaced'])}, archive errors: "
          f"{sum(1 for x in result['archives'] if not x['ok'])}")


if __name__ == "__main__":
    main()
