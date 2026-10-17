#!/usr/bin/env python3
"""Score the extracted facts binary on the 22 shipped FactsOrgan panels, read-only (lane O19-facts).

For each specialist this speaks the answerer contract to the binary, scores every panel item with that
specialist's own shipped scorer (facts_scorer_v1.ok), and compares each reply with the shipped organ on the
same question: same answered/withheld status, same kind, same value and the same response text, byte for
byte. It runs the binary with --specialist <id> and, as a second view, with no argument (the family in
Facts.organs order). It also times a cold start and the per-item round trip and in-binary time.

  score.py [--binary var/facts/bin/facts] [--out var/facts/score.json] [--only id,id]

The board number comes from tools/parity/harness.py; this is the lane's own cross-check against the
organs. Nothing under upstream/ is written (bytecode off)."""
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
IDS = ["literature-v2", "worldhistory", "arthistory", "medicine-r2", "medicine", "law", "psychology", "sociology",
       "linguistics", "poetry", "botany", "entomology", "marinebio", "ornithology", "mycology", "mycelial", "pets",
       "childdev", "etiquette", "firesafety-v2", "firstaid", "javascript"]


def load(folder, module):
    for k in list(sys.modules):
        if k.startswith("facts_") or k in ("narrow_v1", "organ_facts_v1", "organ_medicine_r2", module):
            del sys.modules[k]
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


def panel_items(manifest):
    p = json.loads(Path(manifest["panel"]["path"].replace("__ORACLE7_ROOT__", str(REPO / "upstream/root"))).read_text())
    if isinstance(p, dict):
        p = [dict(x, split=k) for k, v in p.items() for x in v]
    return p


def ask(proc, rid, q):
    t0 = time.perf_counter()
    proc.stdin.write(json.dumps({"id": rid, "q": q, "session": rid}) + "\n")
    proc.stdin.flush()
    line = proc.stdout.readline()
    return json.loads(line), 1000 * (time.perf_counter() - t0)


def run_panel(binary, argv, sid, panel, scorer, organ):
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
                                   "status": rep.get("status"), "response": rep.get("response"), "path": rep.get("path"),
                                   "silence": (rep.get("provenance") or {}).get("silence")})
            o = organ.answer(it["q"]) or {"kind": None, "status": "withheld", "value": None, "response": ""}
            mine = (rep.get("kind"), rep.get("status"), rep.get("value"), rep.get("response"))
            theirs = (o["kind"], o["status"], o["value"], o["response"])
            if mine != theirs:
                out["organ_disagreements"].append({"q": it["q"], "organ": theirs, "binary": mine})
        out["splits"][split] = t
    proc.stdin.close()
    proc.wait()
    return out


def core_compare(binary, sid, organ):
    """every core-panel question (upstream/workbench/data/core_panel.json): the binary and the organ agree on
    status, kind, value and response text"""
    items = json.loads((REPO / "upstream/workbench/data/core_panel.json").read_text())["items"]
    proc = subprocess.Popen([binary, "--specialist", sid], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    taken, diffs = 0, []
    for i, it in enumerate(items):
        rep, _ = ask(proc, "core:%d" % i, it["q"])
        o = organ.answer(it["q"]) or {"kind": None, "status": "withheld", "value": None, "response": ""}
        taken += rep.get("status") == "answered"
        mine = (rep.get("kind"), rep.get("status"), rep.get("value"), rep.get("response"))
        theirs = (o["kind"], o["status"], o["value"], o["response"])
        if mine != theirs:
            diffs.append({"q": it["q"], "organ": theirs, "binary": mine})
    proc.stdin.close()
    proc.wait()
    return {"n": len(items), "taken": taken, "disagreements": diffs}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", default=str(REPO / "var/facts/bin/facts"))
    ap.add_argument("--out", default=str(REPO / "var/facts/score.json"))
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    ids = args.only.split(",") if args.only else IDS
    report = {"binary": args.binary, "size_bytes": Path(args.binary).stat().st_size, "specialists": {}}
    colds = []
    first_q = "Who wrote Pride and Prejudice?"
    for _ in range(5):
        t0 = time.perf_counter()
        p = subprocess.Popen([args.binary, "--specialist", "literature-v2"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        ask(p, "cold", first_q)
        colds.append(1000 * (time.perf_counter() - t0))
        p.stdin.close()
        p.wait()
    report["cold_start_ms"] = colds
    for sid in ids:
        m = json.loads((SPEC / sid / "manifest.json").read_text())
        cls = getattr(load(sid, m["organ"]["module"]), m["organ"]["class"])
        sys.path.insert(0, str(SPEC / sid))     # the organ imports its store at construction
        try:
            organ = cls(**m["organ"]["init"])
        finally:
            sys.path.pop(0)
        scorer = load(sid, m["panel"]["scorer_module"])
        panel = panel_items(m)
        try:
            shipped = json.loads((SPEC / sid / "verdict_heldout.json").read_text())["domain"]["spec"]
            shipped = {k: shipped.get(k) for k in ("correct", "false_yes", "wrong", "n")}
        except FileNotFoundError:
            shipped = None
        entry = {"budget_p50_ms": m["budgets"]["latency_p50_ms"], "shipped_heldout": shipped}
        for mode, argv in (("specialist", ["--specialist", sid]), ("family", [])):
            r = run_panel(args.binary, argv, sid, panel, scorer, organ)
            r["p50_rtt_ms"] = statistics.median(r.pop("rtt_ms"))
            sm = r.pop("specialist_ms")
            r["p50_specialist_ms"] = statistics.median(sm)
            r["max_specialist_ms"] = max(sm)
            entry[mode] = r
        entry["core"] = core_compare(args.binary, sid, organ)
        report["specialists"][sid] = entry
    Path(args.out).write_text(json.dumps(report, indent=1))
    print("binary %s, %d bytes; cold start ms (5 runs): %s" % (args.binary, report["size_bytes"], ", ".join("%.1f" % c for c in colds)))
    for sid, e in report["specialists"].items():
        for mode in ("specialist", "family"):
            r = e[mode]
            for split, t in r["splits"].items():
                print("%-13s %-10s %-7s n=%3d right=%3d wrong=%d withheld_valid=%d false_yes=%d   p50 %.2f ms (in-binary %.2f, budget %d)"
                      % (sid, mode, split, t["n"], t["right"], t["wrong"], t["withheld_valid"], t["false_yes"],
                         r["p50_rtt_ms"], r["p50_specialist_ms"], e["budget_p50_ms"]))
                for f in t["fails"]:
                    print("    FAIL", f["kind"], "|", f["q"], "| expect", f["expect"], "| got", f["status"], f["silence"] or "", f["response"])
            print("    organ disagreements (%s): %d" % (mode, len(r["organ_disagreements"])))
            for d in r["organ_disagreements"][:8]:
                print("     ", d)
        c = e["core"]
        print("    core panel: n=%d taken=%d organ disagreements=%d" % (c["n"], c["taken"], len(c["disagreements"])))
        for d in c["disagreements"][:5]:
            print("     ", d)
        print("    shipped heldout:", e["shipped_heldout"])


if __name__ == "__main__":
    main()
