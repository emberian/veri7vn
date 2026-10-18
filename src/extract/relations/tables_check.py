#!/usr/bin/env python3
"""Transcription check for the relation kernel's tables (lane W5-02, after lane G's quantity/tables_check.py and
lane W5-01's rel-novels/tables_check.py).

Relation_Tables.thy holds, for each of the 161 relation specialists, the data the verified decision reads: its
reader keys in the shipped loop order, the property each key reads, the number of forward and inverse phrasings,
the dropped phrasings, the domain (roots, occupation roots, excluded properties) and the pronoun guard.
Relation_Reader.thy holds the shared constants (time-variant properties, dominance 10, three candidates, the
inverse cap of eight). This script re-reads every shipped source read-only (no bytecode written) and parses the
HOL TEXT (it does not reuse tools/relations/gen_tables.py), printing one line per specialist and per constant;
any difference exits 1.

Sources per specialist: readers.json (keys, dropped), manifest.json (organ class, domain id, the domain block),
relation_readers_v1.PROPS (property and phrasing counts, read as relation_spec_v2.compiled reads them), and the
domains file the organ itself reads, relation_domains_v2.json under the overlay root (var/linker/o7root; its 52
reconstructed entries come from the manifests, so the manifest is checked as a second source).

Not checked here: the phrasings themselves. They are not transcribed; the untrusted fetch imports the shipped
compiled regexes, so there is no copy to drift.

  python3 -I src/extract/relations/tables_check.py
"""
from __future__ import annotations

import inspect
import json
import os
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
UP = Path("/Users/ember/dev/o7vn/upstream/root")
O7 = REPO / "var/linker/o7root"
os.environ["ORACLE7_ROOT"] = str(O7)
sys.path.insert(0, str(UP / "wander-train"))
TABLES = (HERE / "Relation_Tables.thy").read_text(encoding="utf-8")
KERNEL = (HERE / "Relation_Reader.thy").read_text(encoding="utf-8")
FAILS: list[str] = []


def check(name, got, want):
    ok = got == want
    print("%-28s %s" % (name, "ok" if ok else "MISMATCH"))
    if not ok:
        FAILS.append(name)
        print("   thy    : %r\n   shipped: %r" % (got, want))


def nums(text):
    return [int(x) for x in re.findall(r"\d+", text)]


import entity_linker_v2  # noqa: E402,F401
import exact_router_v1 as X  # noqa: E402
import relation_readers_v1 as RD  # noqa: E402
import relation_spec_v1 as RS1  # noqa: E402
import relation_spec_v2 as RS2  # noqa: E402


def key_of(k):
    return k if isinstance(k, str) and not k.lstrip("-").isdigit() else int(k)


# ---- the HOL tables, parsed from the text
SPEC_RX = re.compile(r"mk_spec \(STR ''([^']+)''\) \[(.*?)\] \[([\d, ]*)\] \[([\d, ]*)\] \[([\d, ]*)\] (True|False)")
READER_RX = re.compile(r"mk_reader \(STR ''([^']+)''\) (\d+) (\d+) (\d+) \[([\d, ]*)\] \[([\d, ]*)\]")
thy = {}
for m in SPEC_RX.finditer(TABLES):
    sid, rds, ro, oc, ex, g = m.groups()
    thy[sid] = {"readers": [(k, int(p), int(nf), int(ni), nums(df), nums(di)) for k, p, nf, ni, df, di in READER_RX.findall(rds)],
                "roots": nums(ro), "occ": nums(oc), "excl": nums(ex), "guard": g == "True"}
check("mk_reader definition", re.search(r'"mk_reader k p nf ni df di = \\<lparr>rkey = k, rprop = p, nfwd = nf, '
                                        r'ninv = ni, dfwd = df, dinv = di\\<rparr>"', TABLES) is not None, True)
check("mk_spec definition", re.search(r'"mk_spec n rs ro oc ex g = \\<lparr>sid = n, readers = rs, roots = ro, '
                                      r'occs = oc, excl = ex, guard = g\\<rparr>"', TABLES) is not None, True)

# ---- the shipped sources, per specialist
doms = {d["id"]: d for d in json.load(open(O7 / "relstore/relation_domains_v2.json"))}
sids = sorted(x for x in os.listdir(UP / "specialists") if x.startswith("rel-"))
check("specialists in table", sorted(thy), sids)
for sid in sids:
    d = UP / "specialists" / sid
    man = json.load(open(d / "manifest.json"))
    r = json.load(open(d / "readers.json"))
    want_r = []
    for k in r["keys"]:
        c = RS2.compiled(key_of(k))
        e = RD.PROPS[key_of(k)]
        dr = [(dd, int(i)) for kk, dd, i in r.get("dropped", []) if str(kk) == str(k)]
        want_r.append((str(k), c["prop"], len(c["fwd"]), len(c["inv"]),
                       sorted(i for dd, i in dr if dd == "fwd"), sorted(i for dd, i in dr if dd == "inv")))
        assert len(c["fwd"]) == len(e.get("fwd", [])) and len(c["inv"]) == len(e.get("inv", []))
    did = man["organ"]["init"]["domain"]
    dom = doms[did]
    mdom = man["domain"]
    want = {"readers": want_r, "roots": list(dom.get("roots", [])), "occ": list(dom.get("occ", [])),
            "excl": list(dom.get("exclude_props", [])),
            "guard": man["organ"]["class"] == "RelationOrganV2G"}
    extra = (sorted(mdom.get("roots", [])) == sorted(want["roots"]) and
             sorted(mdom.get("occupations", [])) == sorted(want["occ"]) and
             [str(k) for k in man.get("readers", r["keys"])] == [str(k) for k in r["keys"]] and
             man["organ"]["class"] in ("RelationOrganV2", "RelationOrganV2G") and
             man["organ"]["module"] in ("organ_relation_v2", "organ_relation_v2g") and
             man["organ"]["init"].get("kind", did) == did and
             all(0 <= i for _, _, i in r.get("dropped", [])))
    got = thy.get(sid)
    check(sid, (got, True), (want, extra))

# ---- shared constants and rules, in the kernel text and the shipped source
def body(defn):
    m = re.search(r'definition %s\s*::[^\n]*\n\s*"%s\s*=\s*(.*?)"\s*\n' % (defn, defn), KERNEL, re.S)
    assert m, "definition %s not found" % defn
    return m.group(1)


src2 = inspect.getsource(RS2.answer)
src_dom = inspect.getsource(RS2.in_domain)
check("time_variant", nums(body("time_variant")), [36, 35, 6, 54, 159, 27, 17, 131, 286, 488, 1037, 108, 39, 463, 102, 26])
check("time_variant = shipped", sorted(nums(body("time_variant"))), sorted(X.TIME_VARIANT))
check("dominance 10", (X.DOMINANCE, "10 * max 1" in KERNEL), (10, True))
check("dominance rule in organ", "links[0] >= V1.X.DOMINANCE * max(1, max(links[1:]))" in src2, True)
check("take three", "qids[:3]" in src2 and "take 3" in KERNEL, True)
check("agree-on-one-value rule", "len(set(sets)) != 1 or len(sets[0]) != 1" in src2, True)
check("decline only forward", 'if direction == "fwd" and decline is None and in_domain(qids[0], did)' in src2, True)
check("inverse cap of eight", "LIMIT 8" in src2 and "len(subs) == 8" in src2 and "\\<not> capped a" in KERNEL, True)
check("inverse one subject", "if len(ins) != 1:" in src2, True)
check("silence rules in organ", "V1._restates(low, val)" in src2 and "V1.X.PAST.search(low)" in src2, True)
check("domain: excluded props", '"_exclude_props"' in src_dom and "excl sp" in KERNEL, True)
check("domain: occupation if human", "if 5 in c else []" in inspect.getsource(RS1.classes_of) and
      "5 \\<in> set (cls c)" in KERNEL, True)
g = (UP / "specialists/rel-films-v2/organ_relation_v2g.py").read_text()
sys.path.insert(0, str(REPO / "tools/relations"))
import fetch as FE  # noqa: E402  (the untrusted fetch, for its pronoun list)
check("pronoun list (V2G)", set(re.search(r"PRON = (\{.*?\})", g).group(1).replace('"', "").strip("{}").replace(" ", "").split(",")),
      FE.PRON)

if FAILS:
    sys.exit("tables_check: %d mismatch(es): %s" % (len(FAILS), ", ".join(FAILS[:20])))
print("tables_check: all %d specialists' tables and the shared constants equal the shipped organ's" % len(sids))
