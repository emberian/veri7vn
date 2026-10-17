#!/usr/bin/env python3
"""Score the extracted space binary on the eight shipped panels, read-only.

For each specialist (orbits, planetary, spacecraft, spacecomms, astronomy, -v2, -v3, -v3-r2) this
speaks the answerer contract to the binary, scores every panel item with that
specialist's own shipped scorer, and compares each reply with the shipped organ
on the same question (same answered/withheld status, same kind, values within
the scorer's tolerance). It runs the binary twice per panel: with
--specialist <id> (only that manifest's organ) and with no argument (the whole
family in the recognizer's fixed order). It also times a cold start (process
start to first reply) and the per-item round trip and in-binary time.

  score.py [--binary var/space/bin/space] [--out var/space/score.json]

The board number comes from tools/parity/harness.py; this script is the lane's
own cross-check against the organs. Nothing under upstream/ is written
(bytecode off)."""
from __future__ import annotations

import argparse
import importlib
import json
import statistics
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"
SHEET = str(SPEC / "astronomy/nasa_planetary_factsheet.html")
SPECIALISTS = [  # id, organ module, class, panel, scorer, value tolerance (relative, absolute), organ init kwargs
    ("orbits", "organ_orbits_v1", "OrbitsOrgan", "orbits_panel_v1.json", "orbits_scorer", (0.003, 1e-9), {}),
    ("planetary", "organ_planetary_v1", "PlanetaryOrgan", "planetary_panel_v1.json", "planetary_scorer", (0.005, 1e-9), {}),
    ("spacecraft", "organ_spacecraft_v1", "SpacecraftOrgan", "spacecraft_panel_v1.json", "spacecraft_scorer", (0.005, 1e-9), {}),
    ("spacecomms", "organ_spacecomms_v1", "SpaceCommsOrgan", "spacecomms_panel_v1.json", "spacecomms_scorer", (0.003, 0.06), {}),
    ("astronomy", "organ_astronomy_v1", "AstronomyOrgan", "astronomy_panel_v1.json", "astronomy_scorer", (0.01, 0.05), {"sheet_path": SHEET}),
    ("astronomy-v2", "organ_astronomy_v2", "AstronomyOrganV2", "astronomy_panel_v2.json", "astronomy_scorer", (0.01, 0.05), {"sheet_path": SHEET}),
    ("astronomy-v3", "organ_astronomy_v3", "AstronomyOrganV3", "astronomy_panel_v3.json", "astronomy_scorer", (0.01, 0.05), {"sheet_path": SHEET}),
    ("astronomy-v3-r2", "organ_astronomy_v3_r2", "AstronomyOrganV3Boundary", "astronomy_panel_v3.json", "astronomy_scorer", (0.01, 0.05), {"sheet_path": SHEET}),
]


def load(folder, module):
    for m in ("narrow_v1", "organ_astronomy_v1", "organ_astronomy_v2", "organ_astronomy_v3", module):
        sys.modules.pop(m, None)
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


def ask(proc, rid, q):
    t0 = time.perf_counter()
    proc.stdin.write(json.dumps({"id": rid, "q": q, "session": rid}) + "\n")
    proc.stdin.flush()
    line = proc.stdout.readline()
    return json.loads(line), 1000 * (time.perf_counter() - t0)


def run_panel(binary, argv, sid, panel, scorer, organ, tol):
    proc = subprocess.Popen([binary, *argv], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    out = {"splits": {}, "organ_disagreements": [], "rtt_ms": [], "specialist_ms": []}
    for split in ("dev", "heldout"):
        t = {"n": 0, "right": 0, "wrong": 0, "withheld_valid": 0, "false_yes": 0, "fails": []}
        for i, it in enumerate(x for x in panel if x["split"] == split):
            rid = "%s:%s:%d" % (sid, split, i)
            rep, ms = ask(proc, rid, it["q"])
            out["rtt_ms"].append(ms)
            out["specialist_ms"].append(float((rep.get("provenance") or {}).get("specialist_ms", 0)))
            good, asserted = scorer.ok(it, rep)
            t["n"] += 1
            if not it["valid"]:
                t["right"] += good
                t["false_yes"] += asserted
            elif good:
                t["right"] += 1
            elif asserted:
                t["wrong"] += 1
            else:
                t["withheld_valid"] += 1
            if not good:
                t["fails"].append({"kind": it["kind"], "q": it["q"], "expect": it["expect"],
                                   "status": rep.get("status"), "response": rep.get("response"), "path": rep.get("path")})
            o = organ.answer(it["q"]) or {"kind": None, "status": "withheld", "value": None}
            taken = bool((rep.get("provenance") or {}).get("taken"))
            same_status = (o["status"] == "answered") == (rep.get("status") == "answered")
            same_kind = o["kind"] == rep.get("kind") or (o["kind"] is None and not taken)
            same_value = True
            ov, bv = o.get("value"), rep.get("value")
            if isinstance(ov, (int, float)) and not isinstance(ov, bool) and bv is not None:
                same_value = abs(float(bv) - ov) <= tol[0] * abs(ov) + tol[1]
            if not (same_status and same_kind and same_value):
                out["organ_disagreements"].append({"q": it["q"], "organ": [o["kind"], o["status"], ov],
                                                   "binary": [rep.get("kind"), rep.get("status"), bv]})
        out["splits"][split] = t
    proc.stdin.close()
    proc.wait()
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", default=str(REPO / "var/space/bin/space"))
    ap.add_argument("--out", default=str(REPO / "var/space/score.json"))
    args = ap.parse_args()
    report = {"binary": args.binary, "size_bytes": Path(args.binary).stat().st_size, "specialists": {}}
    colds = []
    first_q = json.loads((SPEC / "planetary/planetary_panel_v1.json").read_text())[0]["q"]
    for _ in range(5):
        t0 = time.perf_counter()
        p = subprocess.Popen([args.binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        ask(p, "cold", first_q)
        colds.append(1000 * (time.perf_counter() - t0))
        p.stdin.close()
        p.wait()
    report["cold_start_ms"] = colds
    for sid, mod, cls, panel_file, scorer_mod, tol, kw in SPECIALISTS:
        organ = getattr(load(sid, mod), cls)(**kw)
        scorer = load(sid, scorer_mod)
        panel = json.loads((SPEC / sid / panel_file).read_text())
        budget = json.loads((SPEC / sid / "manifest.json").read_text())["budgets"]["latency_p50_ms"]
        vf = SPEC / sid / "verdict_heldout.json"
        shipped = json.loads(vf.read_text())["domain"]["spec"] if vf.exists() else {}
        entry = {"budget_p50_ms": budget, "shipped_heldout": {k: shipped.get(k) for k in ("correct", "false_yes", "wrong", "n")}}
        for mode, argv in (("specialist", ["--specialist", sid]), ("family", [])):
            r = run_panel(args.binary, argv, sid, panel, scorer, organ, tol)
            r["p50_rtt_ms"] = statistics.median(r.pop("rtt_ms"))
            sm = r.pop("specialist_ms")
            r["p50_specialist_ms"] = statistics.median(sm)
            r["max_specialist_ms"] = max(sm)
            entry[mode] = r
        report["specialists"][sid] = entry
    Path(args.out).write_text(json.dumps(report, indent=1))
    print("binary %s, %d bytes; cold start ms (5 runs): %s" % (args.binary, report["size_bytes"], ", ".join("%.1f" % c for c in colds)))
    for sid, e in report["specialists"].items():
        for mode in ("specialist", "family"):
            r = e[mode]
            for split, t in r["splits"].items():
                print("%-9s %-10s %-7s n=%3d right=%3d wrong=%d withheld_valid=%d false_yes=%d   p50 %.2f ms (in-binary %.2f, budget %d)"
                      % (sid, mode, split, t["n"], t["right"], t["wrong"], t["withheld_valid"], t["false_yes"],
                         r["p50_rtt_ms"], r["p50_specialist_ms"], e["budget_p50_ms"]))
                for f in t["fails"]:
                    print("    FAIL", f["kind"], "|", f["q"], "| expect", f["expect"], "| got", f["status"], f["response"])
            print("    organ disagreements (%s): %d" % (mode, len(r["organ_disagreements"])))
            for d in r["organ_disagreements"][:12]:
                print("     ", d)
        print("    shipped heldout:", e["shipped_heldout"])


if __name__ == "__main__":
    main()
