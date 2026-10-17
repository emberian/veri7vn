#!/usr/bin/env python3
"""Score the extracted stores binary on the six shipped panels, read-only.

For each specialist (cooking, cooking-v2, cooking-v3, cooking-v3-r2, warehouse, warehouse-r2) this speaks the
answerer contract to `stores --specialist <id>`, scores every panel item with that specialist's own scorer, and
compares each reply with the shipped organ on the same question and session (same answered/withheld status, same
kind, same response text, same value within the scorer's tolerance). Each item gets its own session, as in the
harness (exam-<id>-<split>-<i>); the warehouse session file is a fresh one under var/stores/score-state/ for each
run. Also times a cold start (process start to first reply, including the fetch shim and the first store read)
and the per-item round trip and in-binary time.

  score.py [--binary var/stores/bin/stores] [--out var/stores/score.json] [--only id,id]

The board number comes from tools/parity/harness.py; this is the lane's own cross-check against the organs.
Nothing under upstream/ is written (bytecode off; sqlite opened read-only by the organs themselves)."""
from __future__ import annotations

import argparse
import importlib
import json
import select
import statistics
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"
SPECIALISTS = [  # id, organ folder, module, class, panel folder, panel, store
    ("cooking", "cooking", "organ_nutrition_v1", "NutritionOrgan", "cooking", "nutrition_panel_v1.json", "cooking/nutrition_v1.sqlite3"),
    ("cooking-v2", "cooking-v2", "organ_nutrition_v2", "NutritionOrganV2", "cooking-v2", "nutrition_panel_v2.json", "cooking/nutrition_v1.sqlite3"),
    ("cooking-v3", "cooking-v3", "organ_nutrition_v3", "NutritionOrganV3", "cooking-v3", "nutrition_panel_v3.json", "cooking/nutrition_v1.sqlite3"),
    ("cooking-v3-r2", "cooking-v3-r2", "organ_cooking_v3_r2", "NutritionOrganV3Boundary", "cooking-v3", "nutrition_panel_v3.json", "cooking/nutrition_v1.sqlite3"),
    ("warehouse", "warehouse", "organ_site_v2", "SiteOrgan", "warehouse", "site_fresh_panel.json", "warehouse/site_fresh.sqlite3"),
    ("warehouse-r2", "warehouse-r2", "organ_site_v3", "SiteOrganV3", "warehouse-r2", "site_fresh_panel.json", "warehouse/site_fresh.sqlite3"),
]


def load(folder, module):
    for m in [m for m in sys.modules if m.startswith(("organ_", "narrow_v1", "cooking_scorer", "warehouse_scorer"))]:
        sys.modules.pop(m)
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


def start(binary, sid, state):
    if state.exists():
        state.unlink()                      # this script's own scratch file
    return subprocess.Popen([binary, "--specialist", sid, "--state", str(state)], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, text=True)


def ask(proc, rid, q, session):
    t0 = time.perf_counter()
    proc.stdin.write(json.dumps({"id": rid, "q": q, "session": session}) + "\n")
    proc.stdin.flush()
    ready, _, _ = select.select([proc.stdout], [], [], 20)     # 20 s per item, then the run stops
    if not ready:
        proc.kill()                                            # our own child, by its Popen handle
        raise SystemExit("item %s took over 20 s; binary stopped" % rid)
    line = proc.stdout.readline()
    return json.loads(line), 1000 * (time.perf_counter() - t0)


def value_close(a, b, sc):
    if isinstance(b, list):
        return a is None or a == b                 # the low list: the binary states no value field for it
    try:
        a, b = float(a), float(b)
    except (TypeError, ValueError):
        return a == b or (a in (None, "") and b in (None, ""))
    return abs(a - b) <= max(0.05 * abs(b), 0.15) if sc == "cooking" else abs(a - b) <= 1e-9 * max(1, abs(b))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", default=str(REPO / "var/stores/bin/stores"))
    ap.add_argument("--out", default=str(REPO / "var/stores/score.json"))
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    sdir = REPO / "var/stores/score-state"
    sdir.mkdir(parents=True, exist_ok=True)
    report = {"binary": args.binary, "size_bytes": Path(args.binary).stat().st_size, "specialists": {}}
    for sid in ("cooking-v3", "warehouse"):
        colds = []
        for _ in range(3):
            t0 = time.perf_counter()
            p = start(args.binary, sid, sdir / "cold.json")
            ask(p, "cold", "How much protein is in 100 g of cooked lentils?" if sid.startswith("cook") else "M4 valve count?", "cold")
            colds.append(1000 * (time.perf_counter() - t0))
            p.stdin.close()
            p.wait()
        report["cold_start_ms_" + sid] = colds
    only = set(args.only.split(",")) if args.only else None
    for sid, folder, mod, cls, pfolder, panel_file, store in SPECIALISTS:
        if only and sid not in only:
            continue
        organ = getattr(load(folder, mod), cls)(str(SPEC / store))
        scname = "cooking" if sid.startswith("cooking") else "warehouse"
        scorer = load(pfolder, scname + "_scorer")
        panel = json.loads((SPEC / pfolder / panel_file).read_text())
        man = json.loads((SPEC / folder / "manifest.json").read_text())
        excl = set(man.get("panel", {}).get("exclude_kinds_composed", []))
        vpath = SPEC / folder / "verdict_heldout.json"
        shipped = json.loads(vpath.read_text())["domain"]["spec"] if vpath.exists() else None
        proc = start(args.binary, sid, sdir / (sid + ".json"))
        entry = {"budget_p50_ms": man["budgets"]["latency_p50_ms"],
                 "shipped_heldout": {k: shipped.get(k) for k in ("correct", "false_yes", "n")} if shipped else None,
                 "splits": {}, "organ_disagreements": []}
        rtt, inb = [], []
        for split in ("dev", "heldout"):
            t = {"n": 0, "right": 0, "wrong": 0, "withheld_valid": 0, "false_yes": 0, "fails": [],
                 "aligned": {"n": 0, "right": 0, "wrong": 0, "withheld_valid": 0, "false_yes": 0}}
            for i, it in enumerate(x for x in panel if x["split"] == split):
                rid, sess = "%s:%s:%d" % (sid, split, i), "exam-%s-%s-%d" % (sid, split, i)
                rep, ms = ask(proc, rid, it["q"], sess)
                rtt.append(ms)
                inb.append(float((rep.get("provenance") or {}).get("specialist_ms", 0)))
                good, asserted = scorer.ok(it, rep)
                for tt in ([t, t["aligned"]] if it["kind"] not in excl else [t]):
                    tt["n"] += 1
                    if not it["valid"]:
                        tt["right"] += good
                        tt["false_yes"] += asserted
                    elif good:
                        tt["right"] += 1
                    elif asserted:
                        tt["wrong"] += 1
                    else:
                        tt["withheld_valid"] += 1
                if not good:
                    t["fails"].append({"kind": it["kind"], "q": it["q"], "expect": it["expect"], "status": rep.get("status"),
                                       "response": rep.get("response"), "error": rep.get("error")})
                o = organ.answer(it["q"], sess) or {"kind": None, "status": "withheld", "value": None, "response": ""}
                taken = bool((rep.get("provenance") or {}).get("taken"))
                same = ((o["status"] == "answered") == (rep.get("status") == "answered")
                        and (o["kind"] == rep.get("kind") or (o["kind"] is None and not taken))
                        and (o["status"] != "answered" or value_close(rep.get("value"), o.get("value"), scname)))
                same_text = (o.get("response") or "") == (rep.get("response") or "")
                if not same or not same_text:
                    entry["organ_disagreements"].append({"split": split, "q": it["q"], "decision_differs": not same,
                                                         "organ": [o["kind"], o["status"], o.get("value"), o.get("response")],
                                                         "binary": [rep.get("kind"), rep.get("status"), rep.get("value"), rep.get("response")]})
            entry["splits"][split] = t
        proc.stdin.close()
        proc.wait()
        entry["p50_rtt_ms"] = statistics.median(rtt)
        entry["p50_specialist_ms"] = statistics.median(inb)
        entry["max_specialist_ms"] = max(inb)
        report["specialists"][sid] = entry
    Path(args.out).write_text(json.dumps(report, indent=1))
    print("binary %s, %d bytes; cold start ms: cooking %s, warehouse %s" % (
        args.binary, report["size_bytes"], ", ".join("%.0f" % c for c in report["cold_start_ms_cooking-v3"]),
        ", ".join("%.0f" % c for c in report["cold_start_ms_warehouse"])))
    for sid, e in report["specialists"].items():
        for split, t in e["splits"].items():
            a = t["aligned"]
            print("%-13s %-7s n=%3d right=%3d wrong=%d withheld_valid=%d false_yes=%d | aligned n=%3d right=%3d   p50 %.2f ms (in-binary %.2f, budget %d)"
                  % (sid, split, t["n"], t["right"], t["wrong"], t["withheld_valid"], t["false_yes"], a["n"], a["right"],
                     e["p50_rtt_ms"], e["p50_specialist_ms"], e["budget_p50_ms"]))
            for f in t["fails"]:
                print("    FAIL", f["kind"], "|", f["q"], "| expect", f["expect"], "| got", f["status"], f["response"], f["error"] or "")
        dd = [d for d in e["organ_disagreements"] if d["decision_differs"]]
        print("    organ disagreements: %d in decision, %d in text only" % (len(dd), len(e["organ_disagreements"]) - len(dd)))
        for d in dd[:15]:
            print("     ", d)
        print("    shipped heldout:", e["shipped_heldout"])


if __name__ == "__main__":
    main()
