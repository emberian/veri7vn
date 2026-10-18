#!/usr/bin/env python3
"""tables_check - the HOL tables in Stores.thy and the recognizer's patterns and word tables in recognizer.sml must
equal the shipped organs' own (upstream/root/specialists/*), and the HOL nutrient units must equal the store's.

Checked (fails on any difference):
  Stores.thy      nutrient_order / nutrient_key   = organ_nutrition_v1.NUTRIENTS keys, in order
                  nutrient_unit                   = build_nutrition_store_v1.KEYS units, and every (key, unit) in the store
                  mass_names / grams_per          = organ_nutrition_v1.MASS (order and exact factor)
                  measure_names / measure_key     = organ_nutrition_v1.MEASURE (order)
                  skind_order / skind_key         = organ_site_v2.KIND_WORDS keys, in order
                  unit_suffixes                   = SiteOrgan._unit's table
  recognizer.sml  every Pats.pats entry           = the organ constant's pattern text (named groups and (?i) as written)
                  Pats.inline entries             = present verbatim in the organ source
                  FILLER, PRODUCT_TYPES, SPECIALTY, VARIANT, WORDNUM = the organ's sets / dict
This is a transcription check, not a proof. Nothing under upstream/ is written (bytecode off)."""
import ast
import importlib
import re
import sqlite3
import sys
from fractions import Fraction
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
SPEC = REPO / "upstream/root/specialists"
THY = (HERE / "Stores.thy").read_text(encoding="utf-8")
SML = (HERE / "recognizer.sml").read_text(encoding="utf-8")
bad = []


def check(what, got, want):
    if got != want:
        bad.append("%s:\n   HOL/SML %r\n   organ   %r" % (what, got, want))


def load(folder, module):
    for m in [m for m in sys.modules if m.startswith(("organ_", "narrow_v1"))]:
        sys.modules.pop(m)
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


def hol_fun(name):
    """fun name C = STR ''x''  ->  {C: x}"""
    return dict(re.findall(r'"%s (\w+) = STR \'\'(.*?)\'\'"' % name, THY))


def hol_list(name):
    body = re.search(r'"%s = \[(.*?)\]"' % name, THY, re.S).group(1)
    return [x.strip() for x in body.split(",")]


def hol_pairs(name):
    body = re.search(r'"%s = \[(.*?)\]"' % name, THY, re.S).group(1)
    return re.findall(r"\(STR ''(.*?)'', (\w+)\)", body)


def hol_str_pairs(name):
    body = re.search(r'"%s = \[(.*?)\]"' % name, THY, re.S).group(1)
    return re.findall(r"\(STR ''(.*?)'', STR ''(.*?)''\)", body)


def hol_rat(text):
    text = text.strip()
    if "/" in text:
        a, b = text.split("/")
        return Fraction(int(a), int(b))
    return Fraction(int(text))


def sml_unescape(s):
    out, i = bytearray(), 0
    while i < len(s):
        c = s[i]
        if c == "\\":
            n = s[i + 1]
            if n.isdigit():
                out.append(int(s[i + 1:i + 4]))
                i += 4
                continue
            out += {"\\": b"\\", '"': b'"', "n": b"\n", "t": b"\t"}[n]
            i += 2
            continue
        out += c.encode("utf-8")
        i += 1
    return out.decode("utf-8")


def sml_pairs(block):
    body = re.search(r"val %s : \(string \* string\) list = \[(.*?)\]\n" % block, SML, re.S).group(1)
    return [(sml_unescape(a), sml_unescape(b)) for a, b in re.findall(r'\("((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)"\)', body)]


def sml_strings(name):
    body = re.search(r"val %s = (?:String\.tokens Char\.isSpace)?\s*(.*?)\n  val " % name, SML, re.S).group(1)
    strs = [sml_unescape(x) for x in re.findall(r'"((?:[^"\\]|\\.)*)"', body)]
    if "String.tokens" in re.search(r"val %s = .*" % name, SML).group(0):
        return "".join(strs).split()
    return strs


v1 = load("cooking", "organ_nutrition_v1")
v2 = load("cooking-v3", "organ_nutrition_v2")
r2 = load("cooking-v3-r2", "organ_cooking_v3_r2")
site = load("warehouse", "organ_site_v2")
build_src = (SPEC / "cooking/build_nutrition_store_v1.py").read_text()
KEYS = ast.literal_eval(re.search(r"KEYS = (\{.*?\})\n\n", build_src, re.S).group(1))

# ---- nutrients
keys = hol_fun("nutrient_key")
units = hol_fun("nutrient_unit")
order = [keys[c] for c in hol_list("nutrient_order")]
check("nutrient_order", order, [k for k, _ in v1.NUTRIENTS])
check("nutrient_unit", {keys[c]: u for c, u in units.items()}, {k: u for k, u in KEYS.values()})
db = sqlite3.connect("file:%s?immutable=1" % (SPEC / "cooking/nutrition_v1.sqlite3"), uri=True)
check("store (key, unit) pairs", sorted(db.execute("SELECT DISTINCT key, unit FROM nut").fetchall()),
      sorted((keys[c], u) for c, u in units.items()))
# ---- mass and measure units
gp = {c: hol_rat(v) for c, v in re.findall(r'"grams_per (\w+) = ([\d /]+)"', THY)}
check("mass_names", [(n, gp[c]) for n, c in hol_pairs("mass_names")], [(n, Fraction(str(f))) for n, f in v1.MASS.items()])
mk = hol_fun("measure_key")
check("measure_names", [(n, mk[c]) for n, c in hol_pairs("measure_names")], list(v1.MEASURE.items()))
# ---- site
sk = hol_fun("skind_key")
check("skind_order", [sk[c] for c in hol_list("skind_order")], list(site.KIND_WORDS))
usrc = re.search(r"return (\{\"C\".*?\})\.get", (SPEC / "warehouse/organ_site_v2.py").read_text()).group(1)
check("unit_suffixes", hol_str_pairs("unit_suffixes"), list(ast.literal_eval(usrc).items()))

# ---- recognizer patterns
orgs = {"nutrition_v1": v1, "nutrition_v2": v2, "cooking_v3_r2": r2, "site_v2": site}
srcs = {"nutrition_v1": (SPEC / "cooking/organ_nutrition_v1.py").read_text(),
        "nutrition_v2": (SPEC / "cooking-v3/organ_nutrition_v2.py").read_text(),
        "site_v2": (SPEC / "warehouse/organ_site_v2.py").read_text()}
pats = sml_pairs("pats")
for key, pat in pats:
    mod, name = key.split(".", 1)
    o = orgs[mod]
    if name.startswith("NUTRIENTS."):
        want = dict(o.NUTRIENTS)[name[len("NUTRIENTS."):]]
    elif name.startswith("KIND_WORDS."):
        want = o.KIND_WORDS[name[len("KIND_WORDS."):]]
    else:
        want = getattr(o, name).pattern
    check("pattern " + key, pat, want)
check("pattern NUTRIENTS count", len([k for k, _ in pats if ".NUTRIENTS." in k]), len(v1.NUTRIENTS))
for key, pat in sml_pairs("inline"):
    mod = key.split(".", 1)[0]
    src = srcs[mod]
    consts = {n.value for n in ast.walk(ast.parse(src)) if isinstance(n, ast.Constant) and isinstance(n.value, str)}
    if pat not in consts and ("(?i)" + pat) not in consts:
        bad.append("inline pattern %s not found verbatim in the organ: %r" % (key, pat))

# ---- word tables
# Intentional beyond-parity correction: "total" can identify a USDA food
# (e.g. "total can contents"); only the question-prefix normalizer strips it.
check("FILLER", sorted(set(sml_strings("FILLER"))), sorted(v1.FILLER - {"total"}))
check("PRODUCT_TYPES", sorted(set(sml_strings("PRODUCT_TYPES"))), sorted(v1.PRODUCT_TYPES))
check("SPECIALTY", sorted(set(sml_strings("SPECIALTY"))), sorted(v1.SPECIALTY))
check("VARIANT", sorted(set(sml_strings("VARIANT"))), sorted(v1.VARIANT))
wn = dict((k, Fraction(int(a), int(b))) for k, a, b in re.findall(r'\("([a-z ]+)", \((\d+), (\d+)\)\)', SML))
check("WORDNUM", wn, {k: Fraction(str(v)) for k, v in v1.WORDNUM.items()})
prep = sml_strings("PREP")
src1 = srcs["nutrition_v1"]
check("PREP", sorted(prep), sorted(ast.literal_eval(re.search(r"want & (\{.*?\})", src1).group(1))))

if bad:
    print("TABLES DIFFER (%d):" % len(bad))
    for b in bad:
        print(" -", b)
    sys.exit(1)
print("tables_check: %d patterns, %d inline patterns, 13 nutrients, %d mass and %d measure names, 5 sensor kinds, "
      "5 unit suffixes, 6 word tables: equal to the organs and the store (except documented total-word preservation)"
      % (len(pats), len(sml_pairs("inline")), len(v1.MASS), len(v1.MEASURE)))
