#!/usr/bin/env python3
"""Score the extracted mechanics binary on the nine shipped panels, read-only.

For each specialist (the nine mechanics-family manifests) this
speaks the answerer contract to the binary, scores every panel item with that
specialist's own shipped scorer, and compares each reply with the shipped organ
on the same question (same answered/withheld status, same kind, values within
the scorer's tolerance). It runs the binary twice per panel: with
--specialist <id> (only that manifest's organ) and with no argument (the whole
family in the recognizer's fixed order). It also times a cold start (process
start to first reply) and the per-item round trip and in-binary time.

  score.py [--binary var/mechanics/bin/mechanics] [--out var/mechanics/score.json]

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
SPECIALISTS = [  # id, organ module, class, panel, scorer, value tolerance (relative, absolute)
    ("physics", "organ_mechanics_v1", "MechanicsOrgan", "mechanics_panel_v1.json", "mechanics_scorer", (0.005, 1e-9)),
    ("physics-r2", "organ_mechanics_v2", "MechanicsOrganV2", "mechanics_panel_v1.json", "mechanics_scorer", (0.005, 1e-9)),
    ("physics-r3", "organ_physics_r3", "MechanicsOrganV2Boundary", "mechanics_panel_v1.json", "mechanics_scorer", (0.005, 1e-9)),
    ("mechanisms", "organ_mechanisms_v1", "MechanismsOrgan", "mechanisms_panel_v1.json", "mechanisms_scorer", (0.005, 1e-9)),
    ("mechanisms-v2", "organ_mechanisms_v2", "MechanismsOrganV2", "mechanisms_panel_v2.json", "mechanisms_scorer", (0.005, 1e-9)),
    ("bodies-v2", "organ_bodies_v2", "BodiesOrganV2", "bodies_panel_v2.json", "bodies_scorer", (0.005, 1e-9)),
    ("sports", "organ_sports_v1", "SportsOrgan", "sports_panel_v1.json", "sports_scorer", (0.005, 0.06)),
    ("fleet", "organ_fleet_v1", "FleetOrgan", "fleet_panel_v1.json", "fleet_scorer", (0.005, 0.006)),
    ("fluids-r2", "organ_fluids_v2", "FluidsOrganV2", "fluids_panel_v1.json", "fluids_scorer", (0.005, 1e-9)),
]
MODULES = ("narrow_v1", "names_narrowing_v1", "numbers_rule_v1", "organ_mechanics_v1", "organ_mechanics_v2",
           "organ_mechanisms_v1", "organ_mechanisms_v2", "organ_bodies_v1", "organ_bodies_v2", "organ_sports_v1",
           "organ_fleet_v1", "organ_fluids_v1", "organ_fluids_v2", "organ_physics_r3")


def load(folder, module):
    for m in MODULES + (module,):
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
    ap.add_argument("--binary", default=str(REPO / "var/mechanics/bin/mechanics"))
    ap.add_argument("--out", default=str(REPO / "var/mechanics/score.json"))
    args = ap.parse_args()
    report = {"binary": args.binary, "size_bytes": Path(args.binary).stat().st_size, "specialists": {}}
    colds = []
    first_q = json.loads((SPEC / "physics/mechanics_panel_v1.json").read_text())[0]["q"]
    for _ in range(5):
        t0 = time.perf_counter()
        p = subprocess.Popen([args.binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        ask(p, "cold", first_q)
        colds.append(1000 * (time.perf_counter() - t0))
        p.stdin.close()
        p.wait()
    report["cold_start_ms"] = colds
    for sid, mod, cls, panel_file, scorer_mod, tol in SPECIALISTS:
        organ = getattr(load(sid, mod), cls)()
        scorer = load(sid, scorer_mod)
        panel = json.loads((SPEC / sid / panel_file).read_text())
        if isinstance(panel, dict):
            panel = [dict(x, split=k) for k, v in panel.items() if isinstance(v, list) for x in v]
        budget = json.loads((SPEC / sid / "manifest.json").read_text())["budgets"]["latency_p50_ms"]
        vf = SPEC / sid / "verdict_heldout.json"
        if not vf.exists():
            vf = SPEC / sid / "verdict_heldout_inherited.json"
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
