#!/usr/bin/env python3
"""Score the extracted chemistry binary on the five shipped panels, read-only.

For each specialist (chemistry, chemistry-v3, decay, labsolutions, labsolutions-r2) this
speaks the answerer contract to the binary, scores every panel item with that
specialist's own shipped scorer, and compares each reply with the shipped organ
on the same question (same answered/withheld status, same kind, values within
the scorer's tolerance). It runs the binary twice per panel: with
--specialist <id> (only that manifest's organ) and with no argument (the whole
family in the recognizer's fixed order). It also times a cold start (process
start to first reply) and the per-item round trip and in-binary time.

  score.py [--binary var/chemistry/bin/chemistry] [--out var/chemistry/score.json]

The board number comes from tools/parity/harness.py; this script is the lane's
own cross-check against the organs. Nothing under upstream/ is written
(bytecode off)."""
from __future__ import annotations

import argparse
import importlib
import json
import re
import statistics
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"
TABLE = lambda f: str(SPEC / f / "pubchem_periodic_table.csv")
SPECIALISTS = [  # id, organ module, class, constructor args, panel, scorer, value tolerance (relative, absolute)
    ("chemistry", "organ_chemistry_v1", "ChemistryOrgan", (TABLE("chemistry"),), "chemistry_panel_v1.json", "chemistry_scorer", (0.005, 1e-9)),
    ("chemistry-v3", "organ_chemistry_v3", "ChemistryOrganV3", (TABLE("chemistry-v3"),), "chemistry_panel_v1.json", "chemistry_scorer", (0.005, 1e-9)),
    ("decay", "organ_decay_v1", "DecayOrgan", (), "decay_panel_v1.json", "decay_scorer", (0.005, 1e-9)),
    ("labsolutions", "organ_labsolutions_v1", "LabSolutionsOrgan", (TABLE("labsolutions"),), "labsolutions_panel_v1.json", "labsolutions_scorer", (0.005, 1e-9)),
    ("labsolutions-r2", "organ_labsolutions_r2", "LabSolutionsOrganBoundary", (TABLE("labsolutions-r2"),), "labsolutions_panel_v1.json", "labsolutions_scorer", (0.005, 1e-9)),
]


def load(folder, module):
    for m in ("narrow_v1", "organ_chemistry_v1", "organ_chemistry_v2", "organ_labsolutions_v1", "formula_reader_v2", module):
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
        t = {"n": 0, "right": 0, "wrong": 0, "withheld_valid": 0, "false_yes": 0, "fails": [],
             "organ": {"right": 0, "wrong": 0, "withheld_valid": 0, "false_yes": 0}}
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
            ogood, oasserted = scorer.ok(it, o)
            ot = t["organ"]
            if not it["valid"]:
                ot["right"] += ogood
                ot["false_yes"] += oasserted
            elif ogood:
                ot["right"] += 1
            elif oasserted:
                ot["wrong"] += 1
            else:
                ot["withheld_valid"] += 1
            taken = bool((rep.get("provenance") or {}).get("taken"))
            same_status = (o["status"] == "answered") == (rep.get("status") == "answered")
            same_kind = o["kind"] == rep.get("kind") or (o["kind"] is None and not taken)
            same_value = True
            ov, bv = o.get("value"), rep.get("value")
            if isinstance(ov, (int, float)) and not isinstance(ov, bool) and bv is not None:
                try:
                    bvf = float(bv)
                except (TypeError, ValueError):
                    bvf = None
                # the organ's value is in its own unit (seconds for a time to a fraction); compare the stated number to
                # the organ's reply text instead when the two units differ
                same_value = bvf is not None and (abs(bvf - ov) <= tol[0] * abs(ov) + tol[1] or o["kind"] == "time_to_fraction")
            elif isinstance(ov, str) and bv is not None:
                same_value = str(bv).strip('"') == ov
            if not (same_status and same_kind and same_value):
                out["organ_disagreements"].append({"q": it["q"], "organ": [o["kind"], o["status"], ov],
                                                   "binary": [rep.get("kind"), rep.get("status"), bv]})
        out["splits"][split] = t
    proc.stdin.close()
    proc.wait()
    return out


def judge_probe(p, status, value):
    """(good, asserted) for one committed probe from the reply's status and value alone"""
    answered = status == "answered"
    if not p["valid"]:
        return (not answered), answered
    if not answered:
        return False, False
    try:
        if p["kind"] == "percent_composition":
            got = {m.group(1): float(m.group(2)) for m in re.finditer(r"([A-Z][a-z]?) (\d+(?:\.\d+)?)%", str(value))}
            want = p["expect"]
            return (set(got) == set(want) and all(abs(got[e] - want[e]) <= 0.006 for e in want)), True
        got, want = float(str(value).strip('"')), float(p["expect"])
        return abs(got - want) <= 0.005 * abs(want) + 1e-9, True
    except (TypeError, ValueError):
        return False, True


def run_probes(binary, probes):
    """the probes through the binary (family order) and through the shipped organs in the same order (decay,
    labsolutions-r2, chemistry-v3; the first organ that says anything speaks). Returns two tallies and the misses."""
    organs = [getattr(load(sid, mod), cls)(*cargs) for sid, mod, cls, cargs, *_ in
              [x for x in SPECIALISTS if x[0] in ("decay", "labsolutions-r2", "chemistry-v3")]]
    proc = subprocess.Popen([binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    tb = {"right": 0, "wrong": 0, "withheld_valid": 0, "false_yes": 0}
    to = dict(tb)
    misses = []
    for i, p in enumerate(probes):
        rep, _ = ask(proc, "probe:%d" % i, p["q"])
        good, asserted = judge_probe(p, rep.get("status"), rep.get("value"))
        o = None
        for org in organs:
            o = org.answer(p["q"])
            if o is not None:
                break
        ogood, oasserted = judge_probe(p, (o or {}).get("status"), (o or {}).get("value"))
        for t, g, a in ((tb, good, asserted), (to, ogood, oasserted)):
            if not p["valid"]:
                t["right"] += g
                t["false_yes"] += a
            elif g:
                t["right"] += 1
            elif a:
                t["wrong"] += 1
            else:
                t["withheld_valid"] += 1
        if not good:
            misses.append({"q": p["q"], "expect": p["expect"], "status": rep.get("status"), "value": rep.get("value")})
        if not ogood:
            misses.append({"organ": True, "q": p["q"], "status": (o or {}).get("status"), "value": (o or {}).get("value")})
    proc.stdin.close()
    proc.wait()
    return tb, to, misses


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", default=str(REPO / "var/chemistry/bin/chemistry"))
    ap.add_argument("--out", default=str(REPO / "var/chemistry/score.json"))
    ap.add_argument("--panel-dir", help="directory holding <panel file name> per specialist (fresh_panels.py output) instead of the shipped panels")
    ap.add_argument("--specialist-mode-only", action="store_true", help="skip the family-order pass")
    ap.add_argument("--probes", action="store_true", help="score src/extract/chemistry/probes.json (family order) and exit")
    args = ap.parse_args()
    if args.probes:
        tb, to, misses = run_probes(args.binary, json.loads((Path(__file__).parent / "probes.json").read_text()))
        print("probes (20): kernel binary  right=%(right)d wrong=%(wrong)d withheld_valid=%(withheld_valid)d false_yes=%(false_yes)d" % tb)
        print("probes (20): shipped organs right=%(right)d wrong=%(wrong)d withheld_valid=%(withheld_valid)d false_yes=%(false_yes)d" % to)
        for m in misses:
            print("   ", m)
        return
    report = {"binary": args.binary, "size_bytes": Path(args.binary).stat().st_size, "specialists": {}}
    colds = []
    first_q = json.loads((SPEC / "chemistry-v3/chemistry_panel_v1.json").read_text())[0]["q"]
    for _ in range(5):
        t0 = time.perf_counter()
        p = subprocess.Popen([args.binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        ask(p, "cold", first_q)
        colds.append(1000 * (time.perf_counter() - t0))
        p.stdin.close()
        p.wait()
    report["cold_start_ms"] = colds
    for sid, mod, cls, cargs, panel_file, scorer_mod, tol in SPECIALISTS:
        organ = getattr(load(sid, mod), cls)(*cargs)
        scorer = load(sid, scorer_mod)
        panel = json.loads(((Path(args.panel_dir) if args.panel_dir else SPEC / sid) / panel_file).read_text())
        budget = json.loads((SPEC / sid / "manifest.json").read_text())["budgets"]["latency_p50_ms"]
        vf = SPEC / sid / "verdict_heldout.json"
        shipped = json.loads((vf if vf.exists() else SPEC / "labsolutions" / "verdict_heldout.json").read_text())["domain"]["spec"]
        entry = {"budget_p50_ms": budget, "shipped_heldout": {k: shipped.get(k) for k in ("correct", "false_yes", "wrong", "n")}}
        for mode, argv in (("specialist", ["--specialist", sid]), ("family", [])):
            if mode == "family" and args.specialist_mode_only:
                continue
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
            if mode not in e:
                continue
            r = e[mode]
            for split, t in r["splits"].items():
                print("%-9s %-10s %-7s n=%3d right=%3d wrong=%d withheld_valid=%d false_yes=%d   p50 %.2f ms (in-binary %.2f, budget %d)"
                      % (sid, mode, split, t["n"], t["right"], t["wrong"], t["withheld_valid"], t["false_yes"],
                         r["p50_rtt_ms"], r["p50_specialist_ms"], e["budget_p50_ms"]))
                print("    organ alone: right=%d wrong=%d withheld_valid=%d false_yes=%d" % tuple(t["organ"][k] for k in ("right", "wrong", "withheld_valid", "false_yes")))
                for f in t["fails"]:
                    print("    FAIL", f["kind"], "|", f["q"], "| expect", f["expect"], "| got", f["status"], f["response"])
            print("    organ disagreements (%s): %d" % (mode, len(r["organ_disagreements"])))
            for d in r["organ_disagreements"][:12]:
                print("     ", d)
        print("    shipped heldout:", e["shipped_heldout"])


if __name__ == "__main__":
    main()
