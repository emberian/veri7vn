#!/usr/bin/env python3
"""Score the extracted materials binary on the six shipped panels (soil-r2 and water-r3 use the panels of soil and water), read-only.

For each specialist (additive-v2, materials-v2, soil, soil-r2, water, water-r3) this
speaks the answerer contract to the binary, scores every panel item with that
specialist's own shipped scorer, and compares each reply with the shipped organ
on the same question (same answered/withheld status, same kind, values within
the scorer's tolerance). It runs the binary twice per panel: with
--specialist <id> (only that manifest's organ) and with no argument (the whole
family in the recognizer's fixed order). It also times a cold start (process
start to first reply) and the per-item round trip and in-binary time.

  score.py [--binary var/materials/bin/materials] [--out var/materials/score.json]

The board number comes from tools/parity/harness.py; this script is the lane's
own cross-check against the organs. Nothing under upstream/ is written
(bytecode off)."""
from __future__ import annotations

import argparse
import math
import importlib
import importlib.util
import json
import statistics
import random
import types
import contextlib
import io
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"
SPECIALISTS = [  # id, organ module, class, panel, scorer, value tolerance (relative, absolute)
    ("additive-v2", "organ_additive_v2", "AdditiveOrganV2", "additive_panel_v2.json", "additive_scorer", (0.005, 1e-9)),
    ("materials-v2", "organ_materials_v2", "MaterialsOrganV2", "materials_panel_v2.json", "materials_scorer", (0.005, 1e-9)),
    ("soil", "organ_soil_v1", "SoilOrgan", "soil_panel_v1.json", "soil_scorer", (0.005, 0.05)),
    ("soil-r2", "organ_soil_r2", "SoilOrganBoundary", "soil_panel_v1.json", "soil_scorer", (0.005, 0.05)),
    ("water", "organ_water_v1", "WaterOrgan", "water_panel_v1.json", "water_scorer", (0.003, 1e-15)),
    ("water-r3", "organ_water_r3", "WaterOrganBoundaryBoundary", "water_panel_v1.json", "water_scorer", (0.003, 1e-15)),
]


def load(folder, module):
    for m in ("narrow_v1", "organ_additive_v1", "organ_additive_v2", "organ_materials_v1", "organ_materials_v2", "organ_soil_v1", "organ_soil_r2", "organ_water_v1", "organ_water_r2", "organ_water_r3", module):
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


def run_probes(binary):
    fixture = json.loads(Path(__file__).with_name("probes.json").read_text())
    out = {"note": fixture["note"], "modes": {}}
    for mode in ("specialist", "family"):
        summary = dict(right=0, wrong=0, false_yes=0, withheld_valid=0)
        results = []
        for item in fixture["items"]:
            argv = ["--specialist", item["specialist"]] if mode == "specialist" else []
            proc = subprocess.Popen([binary, *argv], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
            rep, _ = ask(proc, "probe", item["q"])
            proc.stdin.close()
            proc.wait()
            yes = rep.get("status") == "answered"
            value = rep.get("value")
            good = not yes if not item["valid"] else (yes and isinstance(value, (int, float)) and
                math.isclose(value, item["expect"], rel_tol=0.0005, abs_tol=1e-9))
            bucket = "right" if good else "false_yes" if yes and not item["valid"] else "wrong" if yes else "withheld_valid"
            summary[bucket] += 1
            results.append(dict(item, reply=rep, good=good, policy_good=(not yes and (not item.get("policy_decline_kind") or rep.get("kind") == item["policy_decline_kind"])) if item.get("policy_withheld_expected") else None))
        out["modes"][mode] = dict(summary=summary, items=results, policy_assertions={"passed": sum(x["policy_good"] is True for x in results), "total": sum(x["policy_good"] is not None for x in results)})
    return out


def fresh_panels(seed, out):
    """Run shipped generators with a seed offset, preserving their templates/tables.

    This is fresh sampling, not independent question design. Missing generators
    are explicitly recorded and use the shipped panel instead.
    """
    out.mkdir(parents=True, exist_ok=True)
    notes = {}
    for sid, mod, cls, panel, scorer, tol in SPECIALISTS:
        candidates = sorted(SPEC.glob("*/" + panel.replace(".json", ".py")))
        src = SPEC / sid / panel.replace(".json", ".py")
        dest = out / (sid + ".json")
        if not candidates:
            dest.write_text((SPEC / sid / panel).read_text())
            notes[sid] = {"fresh": False, "reason": "No generator shipped; original panel retained."}
            continue
        src = src if src.exists() else candidates[0]
        spec = importlib.util.spec_from_file_location("fresh_generator", src)
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        generator.random = types.SimpleNamespace(Random=lambda original: random.Random(original + seed))
        saved = sys.argv
        try:
            sys.argv = [str(src), str(dest)]
            with contextlib.redirect_stdout(io.StringIO()):
                generator.main()
        finally:
            sys.argv = saved
        notes[sid] = {"fresh": True, "generator": str(src.relative_to(REPO)), "seed_offset": seed}
    (out / "generation.json").write_text(json.dumps(notes, indent=2) + "\n")
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", default=str(REPO / "var/materials/bin/materials"))
    ap.add_argument("--out", default=str(REPO / "var/materials/score.json"))
    ap.add_argument("--panel-root", type=Path, help="Optional directory of <specialist>.json panels (for fresh seeds).")
    ap.add_argument("--fresh-seed", type=int, help="Offset each shipped generator seed; see generation.json for missing generators.")
    ap.add_argument("--probes", action="store_true", help="Also score the authored extension and boundary probes.")
    args = ap.parse_args()
    if args.fresh_seed is not None:
        if args.panel_root:
            ap.error("choose --panel-root or --fresh-seed")
        args.panel_root = fresh_panels(args.fresh_seed, Path(args.out).parent / ("fresh-%d" % args.fresh_seed))
    report = {"binary": args.binary, "size_bytes": Path(args.binary).stat().st_size, "specialists": {}}
    colds = []
    first_q = json.loads((SPEC / "soil/soil_panel_v1.json").read_text())[0]["q"]
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
        panel_path = args.panel_root / (sid + ".json") if args.panel_root else SPEC / sid / panel_file
        panel = json.loads(panel_path.read_text())
        budget = json.loads((SPEC / sid / "manifest.json").read_text()).get("budgets", {}).get("latency_p50_ms", 50)
        vp = SPEC / sid / "verdict_heldout.json"
        if not vp.exists():  # soil-r2 and water-r3 ship no verdict of their own; their parents' is shown
            vp = SPEC / sid.split("-")[0] / "verdict_heldout.json"
        shipped = json.loads(vp.read_text())["domain"]["spec"]
        entry = {"budget_p50_ms": budget, "shipped_heldout": {k: shipped.get(k) for k in ("correct", "false_yes", "wrong", "n")}}
        for mode, argv in (("specialist", ["--specialist", sid]), ("family", [])):
            r = run_panel(args.binary, argv, sid, panel, scorer, organ, tol)
            r["p50_rtt_ms"] = statistics.median(r.pop("rtt_ms"))
            sm = r.pop("specialist_ms")
            r["p50_specialist_ms"] = statistics.median(sm)
            r["max_specialist_ms"] = max(sm)
            entry[mode] = r
        report["specialists"][sid] = entry
    if args.probes:
        report["probes"] = run_probes(args.binary)
        for mode, result in report["probes"]["modes"].items():
            print("authored probes", mode, result["summary"])
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
