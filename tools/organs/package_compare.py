#!/usr/bin/env python3
"""package_compare - check a package smoke run (smoke.py --dump) against the family lanes' own harness runs.

  python3 -B tools/organs/package_compare.py <smoke dump.json> [--harness DIR]

DIR holds <family>/<id>.<split>.json and .items.jsonl as written by tools/parity/harness.py (default
var/linux/macos, the baseline W5-04 uses). For every folder and split it compares, against the harness run of the
family binary: n, ok, wrong and false-yes counts, and every reply's (status, response) one by one. Exit 1 on any
difference. The harness binary and the packaged binary are different files (the package carries the build of the
day), so equal replies are evidence that the package carries the same behaviour the lane scored."""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
# water-r3 ships no panel of its own; lane S08 (and materials/score.py) score it on water's, so water's harness run is its lane run
PANEL_OF = {"water-r3": "water"}


def main():
    args = sys.argv[1:]
    harness = REPO / "var/linux/macos"
    if "--harness" in args:
        i = args.index("--harness")
        harness = Path(args[i + 1])
        del args[i:i + 2]
    dump = json.loads(Path(args[0]).read_text(encoding="utf-8"))
    reg = json.loads((REPO / "src/extract/families.json").read_text(encoding="utf-8"))["families"]
    fam_of = {s: e["family"] for e in reg for s in e["specialists"]}
    rows = bad = replies = 0
    for r in dump["folders"]:
        sid = r["id"].replace("-veri7vn", "")
        fam = fam_of[sid]
        for split, t in r["splits"].items():
            hid = PANEL_OF.get(sid, sid)
            vp = harness / fam / ("%s.%s.json" % (hid, split))
            ip = harness / fam / ("%s.%s.items.jsonl" % (hid, split))
            if not vp.exists():
                print("NO HARNESS RUN for %s %s" % (sid, split))
                bad += 1
                continue
            v = json.loads(vp.read_text(encoding="utf-8"))
            if v.get("decision") == "NO PANEL":                   # the harness has no items for this split either
                if t["n"]:
                    bad += 1
                    print("DIFFERS %s %s: harness has no panel, package has %d items" % (sid, split, t["n"]))
                continue
            w = v["with_specialist"]
            same = (v["n"], w["ok"], w["wrong"], w["fy"]) == (t["n"], t["ok"], t["wrong"], t["fy"])
            items = [json.loads(x) for x in ip.read_text(encoding="utf-8").splitlines()]
            mine = dump["replies"][r["id"]][split]
            diff = [i for i, (a, b) in enumerate(zip(items, mine)) if [a["reply"].get("status"), a["reply"].get("response", "")] != b]
            same = same and len(items) == len(mine) and not diff
            rows += 1
            replies += len(mine)
            if not same:
                bad += 1
                print("DIFFERS %s %s: lane n/ok/wrong/fy %s, package %s, %d replies differ (first %s)" % (
                    sid, split, (v["n"], w["ok"], w["wrong"], w["fy"]), (t["n"], t["ok"], t["wrong"], t["fy"]), len(diff), diff[:3]))
    print("%d folder-splits, %d replies compared with %s: %d differ" % (rows, replies, harness, bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
