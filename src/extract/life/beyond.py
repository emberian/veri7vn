#!/usr/bin/env python3
"""Untrusted evaluation driver; upstream generators/scorers stay read-only.

Fresh panels change only Random(seed) in the author's generator. They test new
samples of the same templates, not independently authored language or models.
Offsets 10181001/10182003 are development; 10183007 is reserved until tuning ends.
This driver also supports the sibling anatomyagri family.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import statistics
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("family", choices=("life", "anatomyagri"))
    ap.add_argument("--offset", type=int, required=True)
    ap.add_argument("--binary", required=True)
    ap.add_argument("--label", required=True)
    args = ap.parse_args()
    spec = importlib.util.spec_from_file_location("family_score", ROOT / "src/extract" / args.family / "score.py")
    scoring = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(scoring)
    out = ROOT / "var" / args.family / "c-beyond"
    out.mkdir(parents=True, exist_ok=True)
    report = {}
    for sid, mod, cls, panel_name, scorer_mod, tol in scoring.SPECIALISTS:
        panel_path = out / f"{sid}-{args.offset}.json"
        if not panel_path.exists():
            source = (scoring.SPEC / sid / panel_name.replace(".json", ".py")).read_text()
            assert "random.Random(seed)" in source
            source = source.replace("random.Random(seed)", f"random.Random(seed + {args.offset})")
            generator = out / f"{sid}-{args.offset}.py"
            generator.write_text(source)
            subprocess.run([sys.executable, "-B", str(generator), str(panel_path)], check=True, capture_output=True)
        panel = json.loads(panel_path.read_text())
        organ = getattr(scoring.load(sid, mod), cls)()
        scorer = scoring.load(sid, scorer_mod)
        result = scoring.run_panel(args.binary, ["--specialist", sid], sid, panel, scorer, organ, tol)
        result["p50_rtt_ms"] = statistics.median(result.pop("rtt_ms"))
        result["p50_specialist_ms"] = statistics.median(result.pop("specialist_ms"))
        result["organ"] = {}
        for split in ("dev", "heldout"):
            counts = dict(n=0, right=0, wrong=0, withheld_valid=0, false_yes=0)
            for item in (x for x in panel if x["split"] == split):
                reply = organ.answer(item["q"]) or {"status": "withheld"}
                good, asserted = scorer.ok(item, reply)
                counts["n"] += 1
                if good:
                    counts["right"] += 1
                elif not item["valid"] and asserted:
                    counts["false_yes"] += 1
                elif asserted:
                    counts["wrong"] += 1
                else:
                    counts["withheld_valid"] += 1
            result["organ"][split] = counts
        report[sid] = result
        print(sid, {s: {k: v for k, v in x.items() if k != "fails"} for s, x in result["splits"].items()}, flush=True)
    target = out / f"{args.label}-{args.offset}.json"
    target.write_text(json.dumps(report, indent=2))
    print(target)


if __name__ == "__main__":
    main()
