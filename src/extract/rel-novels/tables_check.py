#!/usr/bin/env python3
"""Transcription check for the novels reader's tables (lane W5-01, after lane G's quantity/tables_check.py).

Novel_Reader.thy transcribes a handful of tables from the shipped relation specialist
(upstream/root/specialists/rel-novels, class RelationOrganV2 over relation_spec_v2 and
relation_readers_v1): the reader table (keys, forward phrasing counts, the dropped phrasing), the novels
domain roots, the time-variant property list, and the two selection constants (dominance 10, three
candidates). This script imports the shipped modules read-only (no bytecode written), parses the HOL text,
and fails on any difference, so the tables cannot drift silently.

What it does not check: the phrasings themselves. They are not transcribed. The untrusted answerer
(tools/reader-novels/answerer.py) imports the shipped compiled regexes directly, so there is no copy to
drift; this script checks that the shipped module still has the phrasing COUNTS the verified decision
assumes, per key and per direction.

  python3 -I src/extract/rel-novels/tables_check.py      # one line per table, exit 1 on a mismatch
"""
from __future__ import annotations

import inspect
import json
import os
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
UP = REPO / "upstream/root"
os.environ.setdefault("ORACLE7_ROOT", str(UP))
sys.path.insert(0, str(UP / "wander-train"))
THY = (Path(__file__).resolve().parent / "Novel_Reader.thy").read_text(encoding="utf-8")
SPEC = UP / "specialists/rel-novels"
FAILS: list[str] = []


def check(name: str, got, want) -> None:
    ok = got == want
    print("%-28s %s" % (name, "ok" if ok else "MISMATCH"))
    if not ok:
        FAILS.append(name)
        print("   thy    : %r\n   shipped: %r" % (got, want))


def body(defn: str) -> str:
    m = re.search(r'definition %s\s*::[^\n]*\n\s*"%s\s*=\s*(.*?)"\s*\n' % (defn, defn), THY, re.S)
    assert m, "definition %s not found in Novel_Reader.thy" % defn
    return m.group(1)


def nums(text: str) -> list[int]:
    return [int(x) for x in re.findall(r"\d+", text)]


import entity_linker_v2  # noqa: E402,F401  (imported by relation_spec_v2)
import relation_readers_v1 as RD  # noqa: E402
import relation_spec_v2 as RS2  # noqa: E402

X = RS2.X
readers = json.load(open(SPEC / "readers.json"))
manifest = json.load(open(SPEC / "manifest.json"))
keys = [int(k) for k in readers["keys"]]

# 1. reader table: (key, number of forward phrasings, dropped indices), in the shipped loop order
thy_readers = re.findall(r"\((\d+),\s*(\d+),\s*\[([\d,\s]*)\]\)", body("readers"))
thy_table = [(int(k), int(n), [int(i) for i in d.split(",") if i.strip()]) for k, n, d in thy_readers]
want_table = [(k, len(RD.PROPS[k].get("fwd", [])),
               sorted(int(i) for k2, d, i in readers["dropped"] if int(k2) == k and d == "fwd")) for k in keys]
check("reader table", thy_table, want_table)

# 2. only forward phrasings are read (the decision has no inverse walk) and none of the dropped ones is inverse
check("no inverse phrasings", [len(RD.PROPS[k].get("inv", [])) for k in keys], [0] * len(keys))
check("dropped are all forward", sorted({d for _, d, _ in readers["dropped"]}), ["fwd"])

# 3. prop_of k = k: the property compiled for each key is the key itself
check("prop_of k = k", [RS2.compiled(k)["prop"] for k in keys], keys)
check("prop_of equation in thy", re.search(r'"prop_of k = k"', THY) is not None, True)

# 4. the novels domain: roots only, no occupations, no excluded properties; this specialist's domain id
dom = {d["id"]: d for d in json.load(open(UP / "relstore/relation_domains_v2.json"))}["novels"]
check("novels domain roots", nums(body("novel_roots")), list(dom["roots"]))
check("novels domain occ/exclude", (dom.get("occ", []), dom.get("exclude_props", [])), ([], []))
check("manifest domain", manifest["organ"]["init"]["domain"], "novels")

# 5. time-variant properties (an answer to a past-tense question about these is silenced)
check("time_variant", sorted(nums(body("time_variant"))), sorted(X.TIME_VARIANT))
check("time_variant order kept", nums(body("time_variant")), [36, 35, 6, 54, 159, 27, 17, 131, 286, 488,
                                                              1037, 108, 39, 463, 102, 26])

# 6. selection constants: dominance 10 over the linker's whole list, then at most three candidates
src = inspect.getsource(RS2.answer)
check("dominance constant", (X.DOMINANCE, "10 * max 1" in THY), (10, True))
check("dominance rule in organ", "links[0] >= V1.X.DOMINANCE * max(1, max(links[1:]))" in src, True)
check("take three in organ", "qids[:3]" in src and "take 3" in THY, True)
check("agree-on-one-value rule", "len(set(sets)) != 1 or len(sets[0]) != 1" in src, True)

# 7. a restating answer or a time-variant past question silences the turn
check("silence rules in organ", "V1._restates(low, val)" in src and "V1.X.PAST.search(low)" in src, True)

if FAILS:
    sys.exit("tables_check: %d mismatch(es): %s" % (len(FAILS), ", ".join(FAILS)))
print("tables_check: all tables equal the shipped organ's")
