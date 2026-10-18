#!/usr/bin/env python3
"""eval_specialists - the rebuilt names_v1 under all 161 rel-* specialist organs, unmodified.

For every upstream/root/specialists/rel-*/ with a relation_panel_v2.json:
  - instantiate the SHIPPED RelationOrganV2 (organ init from its manifest.json),
  - answer every panel item, score with the SHIPPED relspec_scorer.ok (right / silent / false yes),
  - instrument relation_spec_v2.slot_candidates (the names_v1 hot path: the readers' entity slot)
    and compare its top qid / top-6 qids with the panel item's gold `entity`.

The panel's `expect` is the store's own value (the shipped panels test reading, not Wikidata truth),
so a wrong link shows up as silent-or-wrong, and a right answer proves the link AND the read.

Usage: python3 eval_specialists.py [--sample N] [--only rel-actors,rel-films] [--per-specialist]
"""
import importlib.util
import json
import os
import sys
import time
from multiprocessing import Pool

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
UP = "/Users/ember/dev/o7vn/upstream"
SPEC = UP + "/root/specialists"
O7ROOT = os.environ.get("VERI7VN_LINKER_ROOT", os.path.join(REPO, "var", "linker", "o7root"))   # overlay from make_overlay.py
os.environ["ORACLE7_ROOT"] = O7ROOT
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
sys.path.insert(0, UP + "/root/wander-train")

REC = {"calls": []}          # slot_candidates recorder, per worker process


def one_specialist(dirname):
    import relation_spec_v2 as RS2
    d = os.path.join(SPEC, dirname)
    man = json.load(open(os.path.join(d, "manifest.json")))
    init = man.get("organ", {}).get("init", {})

    # instrument slot_candidates: record (slot, qids, links) then call the original
    orig = RS2.slot_candidates.__wrapped__ if hasattr(RS2.slot_candidates, "__wrapped__") else RS2.slot_candidates

    def rec(text):
        out = orig(text)
        REC["calls"].append((text, out[0], out[1]))
        return out

    RS2.slot_candidates = rec

    if d not in sys.path:                    # some organs import their own siblings (organ_relation_v2g -> v2)
        sys.path.insert(0, d)
    spec = importlib.util.spec_from_file_location(dirname + "_organ", os.path.join(d, man["organ"]["module"] + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    try:
        organ = getattr(mod, man["organ"]["class"])(**init)
    except Exception as e:  # noqa: BLE001 - an organ that cannot even load is a finding, not a crash
        return dirname, {"n": 0, "valid": 0, "right": 0, "silent": 0, "wrong": 0, "invalid": 0, "falseyes": 0,
                         "link_n": 0, "link_top1": 0, "link_top6": 0, "error": repr(e)[:120]}
    scorer_spec = importlib.util.spec_from_file_location(dirname + "_scorer", os.path.join(d, "relspec_scorer.py"))
    scorer = importlib.util.module_from_spec(scorer_spec)
    scorer_spec.loader.exec_module(scorer)

    panel = json.load(open(os.path.join(d, "relation_panel_v2.json")))
    st = {"n": 0, "valid": 0, "right": 0, "silent": 0, "wrong": 0, "invalid": 0, "falseyes": 0,
          "link_n": 0, "link_top1": 0, "link_top6": 0}
    for p in panel:
        st["n"] += 1
        REC["calls"].clear()
        r = None
        try:
            r = organ.answer(p["q"])
        except Exception as e:  # noqa: BLE001 - an organ error is a data point, not a crash of the eval
            r = {"error": repr(e)}
        ok, asserted = scorer.ok(p, r)
        if not p["valid"]:
            st["invalid"] += 1
            st["falseyes"] += bool(asserted)
            continue
        st["valid"] += 1
        if ok:
            st["right"] += 1
        elif (r or {}).get("status") == "answered":
            st["wrong"] += 1
        else:
            st["silent"] += 1
        gold = p.get("entity")
        if isinstance(gold, str):
            gold = int(gold.lstrip("Q"))
        if gold and REC["calls"]:
            qids = REC["calls"][0][1]
            st["link_n"] += 1
            st["link_top1"] += bool(qids and qids[0] == gold)
            st["link_top6"] += bool(gold in qids)
    return dirname, st


def main():
    args = sys.argv[1:]
    sample = 0
    only = None
    per = False
    if "--sample" in args:
        sample = int(args[args.index("--sample") + 1])
    if "--only" in args:
        only = args[args.index("--only") + 1].split(",")
    if "--per-specialist" in args:
        per = True
    dirs = sorted(x for x in os.listdir(SPEC) if x.startswith("rel-")
                  and os.path.exists(os.path.join(SPEC, x, "relation_panel_v2.json")))
    if only:
        dirs = [d for d in dirs if d in only]
    if sample:
        dirs = dirs[:sample]
    t0 = time.time()
    with Pool(min(8, len(dirs))) as pool:
        results = pool.map(one_specialist, dirs)
    tot = {"n": 0, "valid": 0, "right": 0, "silent": 0, "wrong": 0, "invalid": 0, "falseyes": 0,
           "link_n": 0, "link_top1": 0, "link_top6": 0}
    for _, st in results:
        for k in tot:
            tot[k] += st[k]
    if per:
        for name, st in results:
            if st.get("error"):
                print("%-24s LOAD ERROR %s" % (name, st["error"]))
                continue
            print("%-24s valid %3d right %3d silent %3d wrong %2d | link n %3d top1 %3d top6 %3d" %
                  (name, st["valid"], st["right"], st["silent"], st["wrong"], st["link_n"], st["link_top1"], st["link_top6"]))
    v = tot["valid"]
    print("TOTAL %d specialists, %d items (%d valid, %d invalid)" % (len(results), tot["n"], v, tot["invalid"]))
    if v:
        print("  right %d (%.1f%%)  silent %d (%.1f%%)  wrong %d (%.1f%%)  false-yes %d/%d" %
              (tot["right"], 100.0 * tot["right"] / v, tot["silent"], 100.0 * tot["silent"] / v,
               tot["wrong"], 100.0 * tot["wrong"] / v, tot["falseyes"], tot["invalid"]))
    if tot["link_n"]:
        print("  slot link (first slot per item): top-1 %d/%d = %.1f%%   top-6 %d/%d = %.1f%%" %
              (tot["link_top1"], tot["link_n"], 100.0 * tot["link_top1"] / tot["link_n"],
               tot["link_top6"], tot["link_n"], 100.0 * tot["link_top6"] / tot["link_n"]))
    print("  (%.0fs)" % (time.time() - t0))


if __name__ == "__main__":
    main()
