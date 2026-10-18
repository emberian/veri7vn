#!/usr/bin/env python3
"""Read-only upstream comparison for quantity, its variants and acoustics.

UNTRUSTED test harness, not a proof. Fresh panels retain the upstream author's
templates and independent answer tables; only the two random seeds change.
Acoustics has no generator in this snapshot and is reported as such. The
separate probes share their author's assumptions with the recognizer changes.
"""
import argparse
import importlib.util
import json
import re
import statistics
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
SPEC = ROOT / "upstream/root/specialists"


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    out = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(out)
    return out


def counts(items, replies, scorer):
    out = dict(n=0, right=0, wrong=0, false_yes=0, withheld_valid=0, failures=[])
    for item, reply in zip(items, replies):
        good, asserted = scorer.ok(item, reply)
        out["n"] += 1
        out["right"] += bool(good)
        out["wrong"] += bool(item["valid"] and asserted and not good)
        out["false_yes"] += bool(not item["valid"] and asserted)
        out["withheld_valid"] += bool(item["valid"] and not asserted and not good)
        if not good:
            out["failures"].append(dict(item=item, reply=reply))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--seed", type=int, default=2026101801)
    ap.add_argument("--acoustics-binary", default="var/acoustics/bin/acoustics")
    ap.add_argument("--variants-binary", default="var/variants/bin/variants")
    ap.add_argument("--quantity-binary", default="var/quantity/bin/quantity")
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    outdir = ROOT / args.out
    outdir.mkdir(parents=True, exist_ok=True)
    qs = module(ROOT / "src/extract/quantity/score.py", "quantity_score")
    vs = module(ROOT / "src/extract/variants/score.py", "variant_score")
    entries = [("quantity", row) for row in qs.SPECIALISTS] + [("variants", row) for row in vs.VARIANTS]
    entries += [("acoustics", ("acoustics", "organ_acoustics_v1", "AcousticsOrgan", "acoustics_panel_v1.json", "acoustics_scorer", None))]
    report = {}
    for family, (sid, omod, cls, panel, smod, _) in entries:
        if args.only and sid not in args.only.split(","):
            continue
        organ = getattr(vs.load(sid, omod), cls)()
        scorer = vs.load(sid, smod)
        datasets = {"shipped": json.loads((SPEC / sid / panel).read_text())}
        probes = [dict(it, split="dev") for it in json.loads((Path(__file__).parent / "beyond_probes.json").read_text()) if it["specialist"] == sid]
        if probes:
            datasets["probes"] = probes
        generator = SPEC / sid / panel.replace(".json", ".py")
        if not generator.exists() and sid.startswith("units-v"):
            generator = SPEC / "units-v3-r2" / panel.replace(".json", ".py")
        if not generator.exists() and sid == "densities-r2":
            generator = SPEC / "densities" / "densities_panel_v1.py"
        if generator.exists():
            source, n = re.subn(r'\(\("dev", \d+\), \("heldout", \d+\)\)',
                               f'(("dev", {args.seed}), ("heldout", {args.seed + 1}))', generator.read_text())
            assert n == 1, generator
            generated = outdir / (sid + ".fresh.json")
            script = outdir / (sid + ".generator.py")
            script.write_text(source)
            subprocess.run([sys.executable, "-B", str(script), str(generated)], check=True, capture_output=True)
            datasets["fresh"] = json.loads(generated.read_text())
        binary = ROOT / (args.acoustics_binary if family == "acoustics" else args.variants_binary if family == "variants" else args.quantity_binary)
        cmd = [str(binary), "--specialist", sid]
        row = {"generator": str(generator) if generator.exists() else None, "binary_bytes": binary.stat().st_size, "datasets": {}}
        for name, items in datasets.items():
            p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
            replies, latencies = [], []
            for i, item in enumerate(items):
                reply, latency = qs.ask(p, str(i), item["q"])
                replies.append(reply)
                latencies.append(latency)
            p.stdin.close()
            assert p.wait() == 0
            oreplies = [organ.answer(it["q"]) or {"status": "withheld", "response": ""} for it in items]
            results = {}
            for split in ("dev", "heldout"):
                ix = [i for i, it in enumerate(items) if it["split"] == split]
                its = [items[i] for i in ix]
                results[split] = {"kernel": counts(its, [replies[i] for i in ix], scorer),
                                  "organ": counts(its, [oreplies[i] for i in ix], scorer)}
            row["datasets"][name] = results
            row[name + "_p50_ms"] = statistics.median(latencies)
        cold = []
        for i in range(5):
            t = time.perf_counter()
            subprocess.run(cmd, input=json.dumps({"id": "cold", "q": datasets["shipped"][0]["q"]}) + "\n", text=True, capture_output=True, check=True)
            cold.append((time.perf_counter() - t) * 1000)
        row["cold_ms"] = cold
        report[sid] = row
        print(sid, json.dumps({n: {s: {who: {k: v for k, v in c.items() if k != "failures"} for who, c in r.items()} for s, r in d.items()} for n, d in row["datasets"].items()}), flush=True)
    (outdir / "report.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
