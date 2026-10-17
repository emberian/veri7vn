#!/usr/bin/env python3
"""Score the extracted acoustics binary on the shipped acoustics panel, read-only.

Speaks the answerer contract to the binary (one process, JSON lines), scores every
item with the shipped acoustics_scorer.ok, and compares each reply with the shipped
organ (organ_acoustics_v1.AcousticsOrgan) on the same question: same answered or
withheld status, same kind, and values within the scorer's tolerance. Also times a
cold start (process start to first reply) and the per-item round trip.

  score.py [--binary var/acoustics/bin/acoustics] [--out var/acoustics/score.json]

The board number comes from tools/parity/harness.py; this script is the lane's own
cross-check against the organ. Nothing under upstream/ is written (bytecode off)."""
from __future__ import annotations

import argparse
import json
import statistics
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists/acoustics"
sys.path.insert(0, str(SPEC))
import acoustics_scorer  # noqa: E402
import organ_acoustics_v1  # noqa: E402


def ask(proc, rid, q):
    t0 = time.perf_counter()
    proc.stdin.write(json.dumps({"id": rid, "q": q, "session": rid}) + "\n")
    proc.stdin.flush()
    line = proc.stdout.readline()
    return json.loads(line), 1000 * (time.perf_counter() - t0)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", default=str(REPO / "var/acoustics/bin/acoustics"))
    ap.add_argument("--out", default=str(REPO / "var/acoustics/score.json"))
    args = ap.parse_args()
    panel = json.loads((SPEC / "acoustics_panel_v1.json").read_text())
    organ = organ_acoustics_v1.AcousticsOrgan()

    colds = []
    for _ in range(5):
        t0 = time.perf_counter()
        p = subprocess.Popen([args.binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        ask(p, "cold", panel[0]["q"])
        colds.append(1000 * (time.perf_counter() - t0))
        p.stdin.close()
        p.wait()

    proc = subprocess.Popen([args.binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    report = {"binary": args.binary, "cold_start_ms": colds, "splits": {}, "organ_disagreements": []}
    lat, spec_ms = [], []
    for split in ("dev", "heldout"):
        t = {"n": 0, "right": 0, "wrong": 0, "declined": 0, "false_yes": 0, "fails": []}
        for i, it in enumerate(x for x in panel if x["split"] == split):
            rid = "acoustics:%s:%d" % (split, i)
            rep, ms = ask(proc, rid, it["q"])
            lat.append(ms)
            spec_ms.append(float((rep.get("provenance") or {}).get("specialist_ms", 0)))
            good, asserted = acoustics_scorer.ok(it, rep)
            t["n"] += 1
            if not it["valid"]:
                t["right"] += good
                t["false_yes"] += asserted
            elif good:
                t["right"] += 1
            elif asserted:
                t["wrong"] += 1
            else:
                t["declined"] += 1
            if not good:
                t["fails"].append({"kind": it["kind"], "q": it["q"], "expect": it["expect"],
                                   "status": rep.get("status"), "response": rep.get("response")})
            o = organ.answer(it["q"]) or {"kind": None, "status": "withheld", "value": None}
            same_status = (o["status"] == "answered") == (rep.get("status") == "answered")
            same_kind = o["kind"] == rep.get("kind") or (o["kind"] is None and not (rep.get("provenance") or {}).get("taken"))
            same_value = True
            if o.get("value") is not None and rep.get("value") is not None:
                same_value = abs(float(rep["value"]) - o["value"]) <= 0.002 * abs(o["value"]) + 0.05
            if not (same_status and same_kind and same_value):
                report["organ_disagreements"].append({"q": it["q"], "organ": [o["kind"], o["status"], o.get("value")],
                                                      "binary": [rep.get("kind"), rep.get("status"), rep.get("value")]})
        report["splits"][split] = t
    proc.stdin.close()
    proc.wait()
    report["round_trip_ms"] = {"p50": statistics.median(lat), "max": max(lat), "n": len(lat)}
    report["specialist_ms"] = {"p50": statistics.median(spec_ms), "max": max(spec_ms)}
    report["cold_start_ms_median"] = statistics.median(colds)
    Path(args.out).write_text(json.dumps(report, indent=1))
    for split, t in report["splits"].items():
        print("%-8s n=%d right=%d wrong=%d declined=%d false_yes=%d" %
              (split, t["n"], t["right"], t["wrong"], t["declined"], t["false_yes"]))
        for f in t["fails"]:
            print("   FAIL", f["kind"], "|", f["q"], "| expect", f["expect"], "| got", f["status"], f["response"])
    print("cold start ms (5 runs): %s; round trip p50 %.3f ms; in-binary p50 %.3f ms" %
          (", ".join("%.1f" % c for c in colds), report["round_trip_ms"]["p50"], report["specialist_ms"]["p50"]))
    print("organ disagreements: %d" % len(report["organ_disagreements"]))
    for d in report["organ_disagreements"]:
        print("   ", d)


if __name__ == "__main__":
    main()
