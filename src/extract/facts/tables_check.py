#!/usr/bin/env python3
"""Transcription check for the FactsOrgan tables (lane O19-facts).

Facts_Tables.thy carries the 21 shipped stores (22 specialists) as Standard ML string literals from which
the HOL constants <store>_rules / <store>_store / organ_<id> are defined. This script reads that ML text
(not the HOL terms: the ML literals are the only source the definitions are built from), and for each of
the 22 specialists loads the store its manifest names from that specialist's own folder (read-only, no
bytecode) and fails on any difference: GATE, BLOCK, ASK (absent -> organ_facts_v1.DEFAULT_ASK), KIND,
every FACTS row (pattern, value, sentence) in order, the organ class (FactsOrgan, or medicine-r2's
FactsOrganBoundary with its NOT_MINE / MINE patterns), and the family list. Values and sentences are
compared after decoding the tables' text escape (\\uXXXX, \\\\).

  python3 src/extract/facts/tables_check.py      # one line per check, exit 1 on a mismatch
"""
from __future__ import annotations

import importlib
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"
THY = (Path(__file__).resolve().parent / "Facts_Tables.thy").read_text(encoding="utf-8")
IDS = ["literature-v2", "worldhistory", "arthistory", "medicine-r2", "medicine", "law", "psychology", "sociology",
       "linguistics", "poetry", "botany", "entomology", "marinebio", "ornithology", "mycology", "mycelial", "pets",
       "childdev", "etiquette", "firesafety-v2", "firstaid", "javascript"]
FAILS: list[str] = []


def check(label, ok, detail=""):
    print("%-4s %s%s" % ("ok" if ok else "FAIL", label, (": " + detail) if detail and not ok else ""))
    if not ok:
        FAILS.append(label)


def load(folder, module):
    for k in list(sys.modules):
        if k.startswith("facts_") or k in ("narrow_v1", "organ_facts_v1", "organ_medicine_r2"):
            del sys.modules[k]
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


# --- a tiny reader for the SML value syntax used in the data structure -----------------------------------
DATA = THY.split("structure Facts_Tables_Data =")[1].split("\\<close>")[0]
TOK = re.compile(r'\s*(?:"((?:[^"\\]|\\.)*)"|([A-Za-z_][A-Za-z0-9_]*)|(.))', re.S)


def sml_string(body):
    out, i = [], 0
    while i < len(body):
        c = body[i]
        if c == "\\":
            n = body[i + 1]
            if n in '\\"':
                out.append(n); i += 2; continue
            raise SystemExit("unexpected SML escape \\%s" % n)
        out.append(c); i += 1
    return "".join(out)


def tokens(text):
    pos, out = 0, []
    while pos < len(text):
        m = TOK.match(text, pos)
        if not m or m.end() == pos:
            break
        pos = m.end()
        if m.group(1) is not None:
            out.append(("s", sml_string(m.group(1))))
        elif m.group(2):
            out.append(("id", m.group(2)))
        elif m.group(3) and not m.group(3).isspace():
            out.append(("p", m.group(3)))
    return out


def parse_value(ts, i):
    k, v = ts[i]
    if k == "s":
        return v, i + 1
    if k == "id" and v == "SOME":
        x, j = parse_value(ts, i + 1)
        return ("SOME", x), j
    if k == "id" and v == "NONE":
        return None, i + 1
    if k == "p" and v in "([{":
        close = {"(": ")", "[": "]", "{": "}"}[v]
        items, rec, j = [], {}, i + 1
        while ts[j] != ("p", close):
            if v == "{":
                key = ts[j][1]; assert ts[j + 1] == ("p", "="), ts[j:j + 3]
                rec[key], j = parse_value(ts, j + 2)
            else:
                x, j = parse_value(ts, j); items.append(x)
            if ts[j] == ("p", ","):
                j += 1
        return (rec if v == "{" else tuple(items) if v == "(" else items), j + 1
    raise SystemExit("unexpected token %r" % (ts[i],))


ts = tokens(DATA)
vals = {}
i = 0
while i < len(ts):
    if ts[i] == ("id", "val"):
        name = ts[i + 1][1]
        j = i + 2
        while ts[j] != ("p", "="):
            j += 1
        vals[name], i = parse_value(ts, j + 1)
    else:
        i += 1


def decode(s):
    return re.sub(r"\\u([0-9a-f]{4})|\\\\", lambda m: chr(int(m.group(1), 16)) if m.group(1) else "\\", s)


def opt(x):
    return x[1] if isinstance(x, tuple) and x and x[0] == "SOME" else None


fo = load("literature-v2", "organ_facts_v1")
check("DEFAULT_ASK", vals["default_ask"] == fo.DEFAULT_ASK)
organs = vals["organs"]
check("family: 22 organs in order", [o[0] for o in organs] == IDS, str([o[0] for o in organs]))
hol_organs = re.search(r'"organs = \[(.*?)\]"', THY, re.S).group(1)
check("HOL organs list", [x.strip() for x in hol_organs.split(",")] == ["organ_" + s.replace("-", "_") for s in IDS])
for sid, store, boundary in organs:
    m = json.loads((SPEC / sid / "manifest.json").read_text())
    st = load(sid, m["organ"]["init"]["store"])
    rec = vals.get(store)
    problems = []
    if m["organ"]["init"]["store"] != store or rec is None or rec["name"] != store:
        problems.append("store name")
    else:
        if rec["kind"] != getattr(st, "KIND", "fact"): problems.append("KIND")
        if rec["gate"] != st.GATE: problems.append("GATE")
        if opt(rec["block"]) != (getattr(st, "BLOCK", None) or None): problems.append("BLOCK")
        if opt(rec["ask"]) != getattr(st, "ASK", None): problems.append("ASK")
        rows = [(p, decode(v), decode(s)) for p, v, s in rec["rules"]]
        if rows != [tuple(f) for f in st.FACTS]:
            bad = [k for k, (a, b) in enumerate(zip(rows, st.FACTS)) if a != tuple(b)]
            problems.append("FACTS (%d vs %d rows, first differing %s)" % (len(rows), len(st.FACTS), bad[:3]))
        if ("local_setup \\<open>Facts_Tables_Define.define_store Facts_Tables_Data.%s\\<close>" % store) not in THY:
            problems.append("store not defined in HOL")
    cls = m["organ"]["class"]
    if cls == "FactsOrgan":
        if m["organ"]["module"] != "organ_facts_v1" or boundary is not None: problems.append("organ class")
    elif cls == "FactsOrganBoundary":
        om = load(sid, m["organ"]["module"])
        b = opt(boundary)
        if b != (om.NOT_MINE.pattern, om.MINE.pattern) or not (om.NOT_MINE.flags & re.I and om.MINE.flags & re.I):
            problems.append("boundary")
    else:
        problems.append("unknown organ class %s" % cls)
    check("%-14s %-22s %3d rows" % (sid, store, len(st.FACTS)), not problems, "; ".join(problems))

print("tables_check: %d failures" % len(FAILS))
sys.exit(1 if FAILS else 0)
