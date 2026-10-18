#!/usr/bin/env python3
"""UNTRUSTED probe check with the shipped scorer; no upstream writes.

The committed probes cite their model and expected values. They were written
by the recognizer author, so are regression evidence, not independent panels.
"""
import argparse
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("beyond", ROOT / "src/extract/quantity/beyond_check.py")
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)
sys.path.insert(0, str(ROOT / "upstream/root/specialists/acoustics"))
import acoustics_scorer
import organ_acoustics_v1

ap = argparse.ArgumentParser()
ap.add_argument("--binary", required=True)
ap.add_argument("--out", required=True)
args = ap.parse_args()
items = json.loads((Path(__file__).parent / "beyond_probes.json").read_text())
p = subprocess.run([str(ROOT / args.binary)], input="".join(json.dumps({"id": str(i), "q": it["q"]}) + "\n" for i, it in enumerate(items)), text=True, capture_output=True, check=True)
replies = [json.loads(line) for line in p.stdout.splitlines()]
assert len(replies) == len(items)
organ = organ_acoustics_v1.AcousticsOrgan()
oreplies = [organ.answer(it["q"]) or {"status": "withheld", "response": ""} for it in items]
report = {"kernel": b.counts(items, replies, acoustics_scorer), "organ": b.counts(items, oreplies, acoustics_scorer)}
(ROOT / args.out).write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
