"""Build the server's mapcycle files from the maps on the server.

Map packs ship many versions of one map (ns_foo_b3, ns_foo_b6, ns_foo_rc1,
ns_foo). The filtered mapcycles keep one map per family: the released map if
there is one, otherwise the highest version. Map names are split into a family
and a version suffix by family_and_version().

Written by merge.py into the mod directory overlay:

  mapcycle.all.txt       every map, including all versions
  mapcycle.siege.txt     filtered, "siege" in the name
  mapcycle.co.txt        filtered, co_ maps (no siege maps)
  mapcycle.ns.txt        filtered, ns_ maps (no siege maps)
  mapcycle.original.txt  the stock mapcycle.txt of dist/ns
"""
import fnmatch
import re

# Version stages, lowest first. A map without a version suffix is a release
# and ranks above alphas, betas, release candidates and revisions, but below
# an explicit final/fixed build.
STAGES = [
    ("test", 0), ("t", 0),
    ("alpha", 1), ("a", 1),
    ("beta", 2), ("b", 2),
    ("rc", 3),
    ("r", 4), ("v", 4), ("new", 4),
    ("final", 6), ("fnl", 6), ("fixed", 6), ("fixd", 6), ("fix", 6),
]
RELEASE = 5
STAGE_RANK = dict(STAGES)
_STAGE = "|".join(sorted((s for s, _ in STAGES), key=len, reverse=True))
# One part of a version token: stage, number, and a letter after the number
# unless it starts the next part (b10a, b2b, v2b1). t, a, v and new need a number.
_PART = re.compile(r"(" + _STAGE + r")(\d*)(?:(?<=\d)([a-z])(?![a-z]*\d))?")
_NEEDS_NUMBER = {"t", "a", "v", "new"}
# A version glued to the name: ns_shivab4, ns_unknownbeta5, ns_supersiege001b3
_ATTACHED = re.compile(r"^(.{3,}?[a-z0-9])(beta\d*[a-z]?\d*|b\d+[a-z]?\d*|rc\d+[a-z]?|v\d+[a-z]?)$")
# Re-releases of an existing map: ns_rust_1.3 and ns_rust_1_3 (ns_rust exists),
# ns_supersiege004a (ns_supersiege004 exists). Only letters a-f: co_de_dust2m
# (marine) is a different map.
_NUMBER_SUFFIX = re.compile(r"\d+(?:[._]\d+)*")
_LETTERED = re.compile(r"(.+\d)([a-f])")
# Suffixes that mark a new map rather than a version of the base map: kept next
# to the base map (ns_foo and ns_foo_v2). Without a base map they compete with
# the other versions as usual.
SEPARATE_FROM_BASE = ("v2",)


def _parse_token(tok):
    """'b10a' -> [(2, 10, 1)], 'v2b1' -> [(4, 2), (2, 1)], None if not a version."""
    parts, pos = [], 0
    while pos < len(tok):
        m = _PART.match(tok, pos)
        if not m:
            return None
        stage, num, letter = m.groups()
        if stage in _NEEDS_NUMBER and not num:
            return None
        # v numbers are dotted versions: v22 is 2.2 (below v3), v038 is 0.3.8
        nums = tuple(int(c) for c in num) if stage == "v" else ((int(num),) if num else ())
        parts.append((STAGE_RANK[stage],) + nums + ((ord(letter) - 96,) if letter else ()))
        pos = m.end()
    return parts or None


def family_and_version(name):
    """-> (family, version key, suffix). Higher keys are newer/better.

    ns_foo_b3 -> ("ns_foo", ..., "b3"); ns_foo -> ("ns_foo", ((RELEASE,),), "").
    Separators _ and - are equivalent. Plain numbers only count right after a
    version token (ns_foo_b6_2), so ns_rust_1_3 and co_gr1_1216 are names.
    """
    tokens = re.split(r"[_-]", name.lower())
    version, pending = [], None
    while len(tokens) > 2:  # keep the prefix and at least one name token
        tok = tokens[-1]
        if pending is None and tok.isdigit() and len(tokens) > 3 and _parse_token(tokens[-2]):
            pending = int(tok)
            tokens.pop()
            continue
        parsed = _parse_token(tok)
        if parsed is None:
            break
        if pending is not None:
            parsed[-1] += (pending,)
            pending = None
        version = parsed + version
        tokens.pop()
    if pending is not None:
        tokens.append(str(pending))
    if not version and len(tokens) >= 2:
        m = _ATTACHED.match(tokens[-1])
        if m and (parsed := _parse_token(m.group(2))):
            tokens[-1] = m.group(1)
            version = parsed
    family = "_".join(tokens)
    suffix = name[len(family):].lstrip("_-")
    # Every key ends with RELEASE, so v4 ranks above its own beta v4_b2
    return family, tuple(version) + ((RELEASE,),), suffix


def is_beta(key):
    """Test, alpha, beta or release candidate anywhere in the version."""
    return any(part[0] <= STAGE_RANK["rc"] for part in key)


def pick(maps, include=()):
    """Choose the maps for the filtered mapcycles: per family the best
    non-beta version, or the best beta if there is no other.

    -> (kept names, [{family, kept, dropped}] for families with several maps).
    """
    parsed = {m: family_and_version(m) for m in maps}
    by_norm = {m.lower().replace("-", "_"): m for m in maps}
    for m, (fam, key, suffix) in list(parsed.items()):
        norm = m.lower().replace("-", "_")
        if suffix:
            continue
        # Shortest existing map that this name extends with a number
        split = next((i for i, c in enumerate(norm) if c == "_" and norm[:i] in by_norm
                      and _NUMBER_SUFFIX.fullmatch(norm[i + 1:])), None)
        if split is not None:
            stem, number = parsed[by_norm[norm[:split]]], norm[split + 1:]
            nums = tuple(int(x) for x in re.split(r"[._]", number))
            parsed[m] = (stem[0], ((STAGE_RANK["v"],) + nums, (RELEASE,)), number)
        elif (n := _LETTERED.fullmatch(norm)) and n.group(1) in by_norm:
            stem = parsed[by_norm[n.group(1)]]
            parsed[m] = (stem[0], stem[1][:-1] + ((RELEASE, ord(n.group(2)) - 96),), n.group(2))
    versioned = {f for f, _, s in parsed.values() if s}
    families = {}
    for m, (fam, key, suffix) in parsed.items():
        # A map whose whole name is another map's family is that family's
        # release, even if it looks versioned (ns_siegeg4b2s, ns_siegeg4b2s_v3_b1)
        norm = m.lower().replace("-", "_")
        if suffix and norm in versioned:
            fam, key, suffix = norm, ((RELEASE,),), ""
        families.setdefault(fam, []).append((m, key, suffix))
    force = {x.lower() for x in include}
    kept, report = [], []
    for fam, members in sorted(families.items()):
        members.sort(key=lambda x: (not is_beta(x[1]), x[1], x[0].lower()))
        best = members[-1]
        keep = {best[0]}
        if best[2] == "":
            keep |= {m for m, _, s in members if s.lower() in SEPARATE_FROM_BASE}
        keep |= {m for m, _, _ in members if m.lower() in force}
        kept += keep
        if len(members) > 1:
            report.append({"family": fam, "kept": sorted(keep, key=str.lower),
                           "dropped": [m for m, _, _ in reversed(members) if m not in keep]})
    return sorted(kept, key=str.lower), report


def category(name):
    n = name.lower()
    if "siege" in n:
        return "siege"
    if n.startswith("co_"):
        return "co"
    if n.startswith("ns_"):
        return "ns"
    return None


def read_mapcycle(text):
    """Map names from a mapcycle.txt, in order."""
    out = []
    for line in text.splitlines():
        line = line.split("//", 1)[0].strip()
        if line:
            out.append(line.split()[0].strip('"'))
    return out


def write_mapcycle(path, title, maps, minplayers, maxplayers):
    lines = [f"// {title}", "// Generated by mapmerge/merge.py. Use with +mapcyclefile <this file>.", ""]
    lines += [f'{m} "\\minplayers\\{minplayers}\\maxplayers\\{maxplayers}\\"' for m in maps]
    path.write_text("\n".join(lines) + "\n")


def build(server_maps, original, rules):
    """-> ({file name: (title, maps)}, variant report)."""
    r = rules["mapcycle"]
    excluded = [g.lower() for g in r["exclude"]]
    available = [m for m in server_maps if not any(fnmatch.fnmatch(m.lower(), g) for g in excluded)]
    kept, variants = pick(available, r["include"])
    by_cat = {"siege": [], "co": [], "ns": []}
    for m in kept:
        if (c := category(m)):
            by_cat[c].append(m)
    on_server = {m.lower() for m in server_maps}
    cycles = {
        "mapcycle.all.txt": ("Every map on the server, all versions", sorted(available, key=str.lower)),
        "mapcycle.siege.txt": ("Siege maps (\"siege\" in the name), one version each", by_cat["siege"]),
        "mapcycle.co.txt": ("Combat maps (co_), one version each, no siege maps", by_cat["co"]),
        "mapcycle.ns.txt": ("NS maps (ns_), one version each, no siege maps", by_cat["ns"]),
        "mapcycle.original.txt": ("The stock NS mapcycle", [m for m in original if m.lower() in on_server]),
    }
    return cycles, variants
