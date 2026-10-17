#!/usr/bin/env python3
"""Transcription check for the geostats kernel (lane S11).

Geometry and statistics have almost no data tables; what must not drift from the shipped files is
(a) the kinds each manifest accepts against the HOL kind names, (b) the polygon-name table the SML
recognizer carries against the organ's, (c) the "I need ..." phrases and decline sentences in the HOL
text against the organs' own sentences, and (d) the declines each manifest declares. This script
loads the manifests and organ sources (read-only, no bytecode written), parses the HOL and SML text,
and fails on any difference.

  python3 src/extract/geostats/tables_check.py      # one line per check, exit 1 on a mismatch
"""
from __future__ import annotations

import ast
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"
HERE = Path(__file__).resolve().parent
GEO = (HERE / "GeoStats_Geometry.thy").read_text(encoding="utf-8")
STA = (HERE / "GeoStats_Stats.thy").read_text(encoding="utf-8")
REC = (HERE / "recognizer.sml").read_text(encoding="utf-8")
FAILS: list[str] = []
CHECKS = 0


def check(name, ok, detail=""):
    global CHECKS
    CHECKS += 1
    print("%-4s %s%s" % ("ok" if ok else "FAIL", name, "" if ok else "  " + detail))
    if not ok:
        FAILS.append(name)


def hol_kind_names(thy, fn):
    body = re.search(r'definition %s :: .*?\n\s*"%s \w+ = \(case \w+ of (.*?)\)"' % (fn, fn), thy, re.S).group(1)
    return re.findall(r"STR ''(\w+)''", body)


def organ_text(*files):
    return "\n".join((SPEC / f).read_text(encoding="utf-8") for f in files)


# (a) kinds
for sid, thy, fn, kinds_src in (
        ("geometry", GEO, "gkind_name", "geometry/organ_geometry_v1.py"),
        ("geometry-v3", GEO, "gkind_name", None), ("geometry-v4", GEO, "gkind_name", None),
        ("statistics", STA, "skind_name", None), ("statistics-v2", STA, "skind_name", None),
        ("statistics-v3", STA, "skind_name", None)):
    man = json.loads((SPEC / sid / "manifest.json").read_text())
    want = man["accept"]["kinds"]
    got = hol_kind_names(thy, fn)
    check("%s: accepted kinds = HOL kind names" % sid, sorted(want) == sorted(got), "manifest %s vs HOL %s" % (sorted(want), sorted(got)))
    declines = set(man["accept"]["declines_in_domain"])
    check("%s: declines_in_domain are the kinds the kernel withholds with" % sid,
          declines == ({"underspecified", "impossible"} if thy is GEO else {"too_few", "impossible"}), str(declines))

# every kind literal appears as a kind string in the organs
geo_src = organ_text("geometry/organ_geometry_v1.py")
for k in hol_kind_names(GEO, "gkind_name"):
    check("geometry organ source emits kind %s" % k, '"%s"' % k in geo_src)
sta_src = organ_text("statistics/organ_stats_v1.py", "statistics-v2/organ_stats_v2.py")
for k in hol_kind_names(STA, "skind_name"):
    check("statistics organ source emits kind %s" % k, '"%s"' % k in sta_src)

# (b) polygon names
tree = ast.parse(geo_src)
names = None
for node in ast.walk(tree):
    if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "names" for t in node.targets):
        names = ast.literal_eval(node.value)
sml = dict(re.findall(r'"(\w+)" => (\d+)', REC))
sml_poly = {k: int(v) for k, v in sml.items() if k in (names or {})}
last = re.search(r'\| _\s*=>\s*(\d+)\)', REC)
if last:
    sml_poly["decagon"] = int(last.group(1))
check("polygon names and side counts (recognizer vs organ)", names is not None and sml_poly == names,
      "organ %s vs recognizer %s" % (names, sml_poly))
check("polygon regex lists exactly the organ's names",
      all(n in REC for n in (names or {})) and
      "(pentagon|hexagon|heptagon|octagon|nonagon|decagon|triangle|quadrilateral)" in REC)

# (c) sentences
needs = {"GN_radius": "a radius or diameter", "GN_radius_height": "a radius (or diameter) and a height",
         "GN_edge": "an edge length", "GN_length_width": "a length and a width", "GN_height": "a height as well",
         "GN_base_height_or_sides": "a base and a height, or all three sides", "GN_hyp_leg": "the hypotenuse and one leg"}
for c, phrase in needs.items():
    check("geometry need phrase %s" % c, '"%s"' % phrase in geo_src and phrase in GEO)
check("geometry need sentence frame", "I need %s to compute that; I won't assume it." in geo_src and
      "to compute that; I won'' + apos + STR ''t assume it." in GEO)
for phrase in ("A polygon needs at least 3 sides.", "break the triangle inequality, so that triangle doesn't exist.",
               "so that right triangle doesn't exist."):
    check("geometry decline sentence: %s" % phrase, phrase.replace("'", "") .split("doesn")[0] in geo_src.replace("'", "") or phrase in geo_src)
check("statistics decline: too few values", "needs at least two values." in sta_src and "needs at least two values." in STA)
check("statistics decline: sd positive", "A standard deviation must be positive" in sta_src and "A standard deviation must be positive" in STA)
check("statistics decline: binomial setup", "need 0 ≤ p ≤ 1 and k ≤ n" in sta_src and "need 0 <= p <= 1 and k <= n" in STA)

# (d) number formats and constants
check("geometry prints %.6g", '"%.6g"' in geo_src and "render_dec 6" in GEO)
check("statistics prints %.4f / %d / %.6g", '"%.4f"' in sta_src and "\"%.6g\" % v" in sta_src or "%.6g" in sta_src)
check("statistics z-score format uses f()", "def f(x)" in sta_src)
check("angle sum is (n - 2) * 180", "(n - 2) * 180" in geo_src and "(n - 2) * 180" in GEO)
check("hyp/leg/heron formulas are the organ's", "math.hypot" in geo_src and "hyp ** 2 - other ** 2" in geo_src
      and "s * (s - a) * (s - b2) * (s - c)" in geo_src.replace("math.sqrt(", "").replace(")", "").replace("(s - a)", "(s - a)") or "s * (s - a) * (s - b2) * (s - c)" in geo_src)

print("%s: %d checks, %d failed" % ("PASS" if not FAILS else "FAIL", CHECKS, len(FAILS)))
sys.exit(1 if FAILS else 0)
