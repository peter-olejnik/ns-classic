#!/usr/bin/env python3
"""Apply rules.toml to the analysis of ns_maps and produce the files to merge.

Reads the full analysis state written by analyze.py (--state), decides per
map and per file what gets merged, and copies the chosen files to
<out>/maps/<destination path>, an overlay for the ns mod directory. Also
writes merge-report.md, merge.json and maplist.txt (merged map names), and
the mapcycle.*.txt files (see mapcycle.py) into the overlay.
"""
import argparse
import datetime
import fnmatch
import json
import shutil
import tomllib
from collections import defaultdict
from pathlib import Path, PurePosixPath

import mapcycle

DEFAULT_RULES = {
    "maps": {"skip_broken": True, "skip_critical_missing": True, "skip_missing_textures": False,
             "exclude": [], "include": []},
    "conflicts": {"strategy": "largest", "prefer": {}},
    "dist": {"overwrite": False},
    "files": {"include_archive_siblings": True, "exclude": [], "place": {}},
    "mapcycle": {"minplayers": 0, "maxplayers": 32, "exclude": [], "include": []},
}


def load_rules(path):
    rules = json.loads(json.dumps(DEFAULT_RULES))
    with open(path, "rb") as f:
        user = tomllib.load(f)
    for section, values in user.items():
        if section not in rules:
            raise SystemExit(f"rules: unknown section [{section}]")
        for k, v in values.items():
            if k not in rules[section]:
                raise SystemExit(f"rules: unknown key {section}.{k}")
            rules[section][k] = v
    if rules["conflicts"]["strategy"] not in ("largest", "smallest"):
        raise SystemExit("rules: conflicts.strategy must be \"largest\" or \"smallest\"")
    return rules


def map_skip_reason(m, rules):
    r = rules["maps"]
    if m["map"].lower() in {x.lower() for x in r["exclude"]}:
        return "excluded in rules"
    if r["skip_broken"] and m.get("bsp_error"):
        return f"broken BSP: {m['bsp_error']}"
    critical = [q["path"] for q in m["requirements"] if q.get("severity") == "critical"]
    if r["skip_critical_missing"] and critical:
        return "missing critical files: " + ", ".join(f"`{p}`" for p in critical)
    t = m["textures"]
    if r["skip_missing_textures"] and t["unresolved"] and not t["may_be_in_valve_wads"]:
        return f"{len(t['unresolved'])} textures not found in any WAD"
    return None


def pick_variant(f, rules):
    """-> (chosen source, how). Sources of the same content are one variant."""
    variants = {}
    for s in f["sources"]:
        variants.setdefault(s["sha1"], s)
    if len(variants) == 1:
        return next(iter(variants.values())), None
    prefer = {k.lower(): v for k, v in rules["conflicts"]["prefer"].items()}.get(f["target"].lower())
    if prefer:
        hits = [s for s in variants.values() if prefer.lower() in f"{s['origin']}/{s['member']}".lower()]
        if len(hits) == 1:
            return hits[0], f"preferred `{prefer}`"
        if not hits:
            raise SystemExit(f"rules: conflicts.prefer for {f['target']!r}: no source contains {prefer!r}")
        raise SystemExit(f"rules: conflicts.prefer for {f['target']!r}: {prefer!r} matches several sources")
    largest = rules["conflicts"]["strategy"] == "largest"
    chosen = sorted(variants.values(), key=lambda s: s["size"], reverse=largest)[0]
    return chosen, f"{rules['conflicts']['strategy']} ({chosen['size']} B)"


def merge(state, rules, ns_root, out):
    """ns_maps is a loose dump: merge the maps that pass the rules, and only
    the files they need (own files, requirements, optionally archive siblings)."""
    maps = state["maps"]
    files = state["files"]
    force = {x.lower() for x in rules["maps"]["include"]}
    overwrite = rules["dist"]["overwrite"]

    skipped = {}
    for m in maps:
        if m["map"].lower() in force:
            continue
        reason = map_skip_reason(m, rules)
        if reason:
            skipped[m["map"].lower()] = reason
    active = {m["map"].lower() for m in maps} - skipped.keys()
    # Maps whose .bsp is actually added; only these pull in archive siblings,
    # so an archive holding a copy of an official map doesn't drag in its junk.
    adding = {m["map"].lower() for m in maps if m["map"].lower() in active
              and (m["file"] in ("new", "conflict") or (m["file"] == "differs_from_dist" and overwrite))}

    exclude_globs = [g.lower() for g in rules["files"]["exclude"]]
    added, skipped_files, conflicts = [], [], []
    not_needed = 0
    maps_dir = out / "maps"
    maps_dir.mkdir(parents=True, exist_ok=True)

    def copy(src_path, target):
        """Copy to the overlay. -> False (and the file is skipped) for an unsafe
        destination: they come from map data and archive contents, so only plain
        relative paths inside the output directory are allowed."""
        parts = PurePosixPath(target).parts
        if not parts or target.startswith("/") or any(not p.strip(".") or ":" in p for p in parts):
            skipped_files.append({"target": target, "reason": "unsafe destination path"})
            return False
        dest = maps_dir / target
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_path, dest)
        return True

    for f in sorted(files, key=lambda f: f["target"].lower()):
        target, key = f["target"], f["target"].lower()

        def skip(reason):
            skipped_files.append({"target": target, "reason": reason})

        own = (f.get("own_of") or "").lower()
        used_by = {n.lower() for n in f["used_by"]}
        if own:
            if own in skipped:
                skip(f"belongs to skipped map: {f['own_of']}")
                continue
            role = "map"
        elif used_by:
            if not used_by & active:
                skip("only used by skipped map(s): " + ", ".join(f["used_by"]))
                continue
            role = "required"
        elif rules["files"]["include_archive_siblings"] and {n.lower() for n in f["sibling_of"]} & adding:
            role = "sibling"
        else:
            not_needed += 1
            continue
        if any(fnmatch.fnmatch(key, g) for g in exclude_globs):
            skip("excluded in rules")
            continue
        chosen, how = pick_variant(f, rules)
        if f.get("dist_path"):
            if chosen["sha1"] == f["dist_sha1"]:
                skip("already in dist/ns")
                continue
            if not overwrite:
                skip(f"differs from dist/ns `{f['dist_path']}` (kept)")
                continue
        if how:
            conflicts.append({"target": target, "chosen": f"{chosen['origin']} → {chosen['member']}",
                              "how": how, "variants": len({s["sha1"] for s in f["sources"]})})
        if not copy(chosen["path"], target):
            continue
        added.append({"target": target, "from": chosen["origin"], "member": chosen["member"], "role": role,
                      "overwrites_dist": bool(f.get("dist_path"))})

    # Needed files found by name in another folder: copy to where the map expects them
    taken = {a["target"].lower() for a in added}
    for u in state["name_uses"]:
        dest = u["dest"]

        def skip(reason):
            skipped_files.append({"target": dest, "reason": reason})

        if not {n.lower() for n in u["maps"]} & active:
            skip("only used by skipped map(s): " + ", ".join(u["maps"]))
            continue
        if any(fnmatch.fnmatch(dest.lower(), g) for g in exclude_globs):
            skip("excluded in rules")
            continue
        if dest.lower() in taken:
            continue
        c = u["chosen"]
        if not copy(c["path"], dest):
            continue
        taken.add(dest.lower())
        added.append({"target": dest, "from": c["origin"], "member": c["member"], "role": "by name",
                      "variants": u["variants"], "overwrites_dist": False})

    # Unplaced files with a destination in rules
    placed_rules = {k.lower(): v for k, v in rules["files"]["place"].items()}
    dist_lower = {p.relative_to(ns_root).as_posix().lower() for p in ns_root.rglob("*") if p.is_file()}
    used_place = set()
    for u in state["unplaced"]:
        name = PurePosixPath(u["member"]).name.lower()
        target = placed_rules.get(name)
        if not target or name in used_place:
            continue
        used_place.add(name)
        if target.lower() in taken:
            skipped_files.append({"target": target, "reason": f"files.place: `{u['member']}` collides with "
                                  "another merged file"})
            continue
        if target.lower() in dist_lower and not overwrite:
            skipped_files.append({"target": target, "reason": "files.place: exists in dist/ns (kept)"})
            continue
        if not copy(u["path"], target):
            continue
        taken.add(target.lower())
        added.append({"target": target, "from": u["origin"], "member": u["member"], "role": "files.place",
                      "overwrites_dist": target.lower() in dist_lower})
    unused_place = sorted(set(placed_rules) - used_place)
    # Files with no known destination that weren't needed by name or placed by a rule
    by_name = {(u["chosen"]["origin"], u["chosen"]["member"]) for u in state["name_uses"]}
    not_needed += sum(1 for u in state["unplaced"] if (u["origin"], u["member"]) not in by_name
                      and PurePosixPath(u["member"]).name.lower() not in used_place)

    merged_maps = sorted({PurePosixPath(a["target"]).stem for a in added
                          if a["target"].lower().startswith("maps/") and a["target"].lower().endswith(".bsp")},
                         key=str.lower)
    return {
        "generated": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
        "rules": rules,
        "merged_maps": merged_maps,
        "skipped_maps": [{"map": m["map"], "reason": skipped[m["map"].lower()]}
                         for m in maps if m["map"].lower() in skipped],
        "added": added,
        "skipped_files": skipped_files,
        "not_needed": not_needed,
        "conflicts": conflicts,
        "unused_place_rules": unused_place,
    }


def md_report(r):
    out = []
    w = out.append
    w("# ns_maps merge report\n")
    w(f"Generated {r['generated']}. Rules: `mapmerge/rules.toml`. The files below were added on top of "
      "`dist/ns/` to produce `dist/server/ns/`; `dist/ns/` itself is unchanged.\n")
    reasons = defaultdict(int)
    for s in r["skipped_files"]:
        reasons[s["reason"].split(":")[0].split(" `")[0]] += 1
    w("## Summary\n")
    w("| | Count |\n|---|---:|")
    w(f"| Maps merged | {len(r['merged_maps'])} |")
    w(f"| Maps skipped | {len(r['skipped_maps'])} |")
    roles = defaultdict(int)
    for a in r["added"]:
        roles[a["role"]] += 1
    labels = {"map": "maps' own files (bsp, res, txt, minimap, navmesh)",
              "required": "required by a map, found at its path",
              "by name": "required by a map, found by name in another folder",
              "sibling": "shipped in the same archive as a merged map",
              "files.place": "placed by `files.place`"}
    w(f"| Files added | {len(r['added'])} |")
    for role, label in labels.items():
        if roles[role]:
            w(f"| … {label} | {roles[role]} |")
    w(f"| … replacing a dist/ns file | {sum(1 for a in r['added'] if a['overwrites_dist'])} |")
    w(f"| Conflicts resolved | {len(r['conflicts'])} |")
    w(f"| Needed files skipped | {len(r['skipped_files'])} |")
    for k, v in sorted(reasons.items(), key=lambda x: -x[1]):
        w(f"| … {k} | {v} |")
    w(f"| Other ns_maps files (not needed by any merged map) | {r['not_needed']} |")
    w("")
    if r["unused_place_rules"]:
        w("**Warning:** `files.place` entries that matched no unplaced file: "
          + ", ".join(f"`{x}`" for x in r["unused_place_rules"]) + "\n")
    w("## Skipped maps\n")
    if r["skipped_maps"]:
        w("| Map | Reason |\n|---|---|")
        for s in r["skipped_maps"]:
            w(f"| {s['map']} | {s['reason']} |")
    else:
        w("None.")
    w("")
    w("## Conflicts resolved\n")
    if r["conflicts"]:
        for c in r["conflicts"]:
            w(f"- `{c['target']}`: {c['how']} of {c['variants']} versions → `{c['chosen']}`")
    else:
        w("None.")
    w("")
    w("## Merged maps\n")
    w(", ".join(r["merged_maps"]) or "None.")
    w("")
    w("## Mapcycles\n")
    w("Written to the mod directory; select one with `+mapcyclefile <file>`. The filtered files keep one "
      "version per map: the release if there is one, otherwise the newest beta. Tune with `[mapcycle]` "
      "in `rules.toml`.\n")
    limit = mapcycle.HLTV_MAX_BYTES
    w("| File | Maps | Bytes |\n|---|---:|---:|")
    for name, (title, maps) in r["mapcycles"].items():
        size = r["mapcycle_sizes"][name]
        w(f"| `{name}` | {len(maps)} | {size}{' ⚠' if size > limit else ''} |")
    w("")
    if any(s > limit for s in r["mapcycle_sizes"].values()):
        w(f"⚠ Over {limit} bytes: the engine sends the whole mapcycle file to every connecting client, and "
          "HLTV can't parse one that long. It disconnects (\"ParseBaseline: needed delta encoder missing\") "
          "and exits. Don't use these files with HLTV, or trim them with `[mapcycle]` exclude.\n")
    w("<details><summary>Versions left out of the filtered mapcycles (%d maps, %d families)</summary>\n"
      % (sum(len(v["dropped"]) for v in r["map_versions"]), len(r["map_versions"])))
    for v in r["map_versions"]:
        dropped = ", ".join(v["dropped"]) or "none"
        w(f"- **{', '.join(v['kept'])}**, left out: {dropped}")
    w("\n</details>\n")
    w("<details><summary>Files added (%d)</summary>\n" % len(r["added"]))
    for a in r["added"]:
        flag = " (replaces dist/ns file)" if a["overwrites_dist"] else ""
        flag += f" ({a['role']})" if a["role"] in ("by name", "sibling", "files.place") else ""
        flag += f" (largest of {a['variants']} different files)" if a.get("variants", 1) > 1 else ""
        w(f"- `{a['target']}` from `{a['from']}` → `{a['member']}`{flag}")
    w("\n</details>\n")
    w("<details><summary>Needed files skipped (%d)</summary>\n" % len(r["skipped_files"]))
    for s in r["skipped_files"]:
        w(f"- `{s['target']}`: {s['reason']}")
    w("\n</details>\n")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--state", type=Path, required=True, help="analysis state from analyze.py --state")
    ap.add_argument("--rules", type=Path, required=True, help="rules.toml")
    ap.add_argument("--ns", type=Path, required=True, help="built ns mod directory (dist/ns)")
    ap.add_argument("--out", type=Path, required=True, help="output directory")
    a = ap.parse_args()

    rules = load_rules(a.rules)
    state = json.loads(a.state.read_text())
    a.out.mkdir(parents=True, exist_ok=True)
    result = merge(state, rules, a.ns, a.out)
    for x in result["added"]:
        x.pop("path", None)

    # Mapcycles for every map on the server: dist/ns maps plus the merged ones
    stock = [p.stem for p in (a.ns / "maps").iterdir() if p.suffix.lower() == ".bsp"]
    server_maps = {m.lower(): m for m in stock + result["merged_maps"]}
    original = a.ns / "mapcycle.txt"
    original = mapcycle.read_mapcycle(original.read_text(errors="replace")) if original.is_file() else []
    cycles, versions = mapcycle.build(sorted(server_maps.values(), key=str.lower), original, rules)
    sizes = {}
    for name, (title, maps) in cycles.items():
        sizes[name] = mapcycle.write_mapcycle(a.out / "maps" / name, title, maps,
                                              rules["mapcycle"]["minplayers"], rules["mapcycle"]["maxplayers"])
    result["mapcycles"] = cycles
    result["mapcycle_sizes"] = sizes
    result["map_versions"] = versions

    (a.out / "merge.json").write_text(json.dumps(result, indent=2))
    (a.out / "merge-report.md").write_text(md_report(result))
    (a.out / "maplist.txt").write_text("".join(f"{m}\n" for m in result["merged_maps"]))
    print(f"merged maps: {len(result['merged_maps'])}, skipped maps: {len(result['skipped_maps'])}, "
          f"files added: {len(result['added'])}, skipped: {len(result['skipped_files'])}")


if __name__ == "__main__":
    main()
