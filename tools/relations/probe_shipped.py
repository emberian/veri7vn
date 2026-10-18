#!/usr/bin/env python3
"""probe_shipped - the SHIPPED relation organs (RelationOrganV2 / V2G), unmodified, over the overlay root
(var/linker/o7root: relations_v1 as the store, the reconstructed names_v1 as the linker index, the merged domains
file), one JSON record per panel item. This is the reference W5-02's kernel is compared against item for item.

UNTRUSTED measurement glue (it runs shipped code; it proves nothing). Read-only against upstream/.

  PYTHONDONTWRITEBYTECODE=1 python3 -I tools/relations/probe_shipped.py [--only a,b] [--jobs 8]
  -> var/relations/shipped/<id>.jsonl
"""
import importlib.util
import json
import os
import sys
from multiprocessing import Pool

sys.dont_write_bytecode = True
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UP = "/Users/ember/dev/o7vn/upstream/root"
SPEC = UP + "/specialists"
O7ROOT = os.environ.get("VERI7VN_LINKER_ROOT", os.path.join(REPO, "var/linker/o7root"))
os.environ["ORACLE7_ROOT"] = O7ROOT
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
sys.path.insert(0, UP + "/wander-train")
OUT = os.path.join(REPO, "var/relations/shipped")


def one(sid):
    import relation_spec_v1 as RS1
    import relation_spec_v2 as RS2
    d = os.path.join(SPEC, sid)
    man = json.load(open(os.path.join(d, "manifest.json")))
    rec = {}
    orig_slot = RS2.slot_candidates

    def slot(text):
        out = orig_slot(text)
        rec.setdefault("slots", []).append([text, out[0], out[1]])
        return out
    RS2.slot_candidates = slot
    orig2, orig1 = RS2.answer, RS1.answer

    def a2(*a, **k):
        r = orig2(*a, **k)
        rec["rs2"] = r
        return r

    def a1(*a, **k):
        r = orig1(*a, **k)
        rec["rs1"] = r
        return r
    RS2.answer, RS1.answer = a2, a1
    if d not in sys.path:
        sys.path.insert(0, d)
    spec = importlib.util.spec_from_file_location(sid + "_organ", os.path.join(d, man["organ"]["module"] + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    organ = getattr(mod, man["organ"]["class"])(**man["organ"].get("init", {}))
    sc = importlib.util.spec_from_file_location(sid + "_scorer", os.path.join(d, "relspec_scorer.py"))
    scorer = importlib.util.module_from_spec(sc)
    sc.loader.exec_module(scorer)
    panel = json.load(open(os.path.join(d, "relation_panel_v2.json")))
    os.makedirs(OUT, exist_ok=True)
    tally = [0, 0, 0]
    with open(os.path.join(OUT, sid + ".jsonl"), "w", encoding="utf-8") as f:
        for it in panel:
            rec.clear()
            try:
                r = organ.answer(it["q"])
            except Exception as e:  # noqa: BLE001
                r = {"error": repr(e)}
            good, asserted = scorer.ok(it, r)
            status = (r or {}).get("status", "silent")
            tally[0 if good else (2 if status == "answered" else 1)] += 1
            f.write(json.dumps({"split": it["split"], "q": it["q"], "expect": it["expect"], "relation": it["relation"],
                                "entity": it["entity"], "status": status, "response": (r or {}).get("response", ""),
                                "good": good, "rs2": rec.get("rs2"), "rs1": rec.get("rs1"),
                                "slots": rec.get("slots", [])}, ensure_ascii=False) + "\n")
    return sid, tally


def main():
    args = sys.argv[1:]
    only = args[args.index("--only") + 1].split(",") if "--only" in args else None
    jobs = int(args[args.index("--jobs") + 1]) if "--jobs" in args else 8
    sids = sorted(x for x in os.listdir(SPEC) if x.startswith("rel-"))
    if only:
        sids = [s for s in sids if s in only]
    tot = [0, 0, 0]
    with Pool(jobs) as pool:
        for sid, t in pool.imap_unordered(one, sids):
            print("%-26s right %4d silent %4d wrong %3d" % (sid, *t), flush=True)
            tot = [a + b for a, b in zip(tot, t)]
    print("TOTAL right %d silent %d wrong %d" % tuple(tot))


if __name__ == "__main__":
    main()
