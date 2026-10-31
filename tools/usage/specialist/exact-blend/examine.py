#!/usr/bin/env python3
"""Untrusted separate supplied-blend panel, using actual host calls and exact replay."""
import argparse
import importlib.util
import json
from pathlib import Path
p = Path(__file__).resolve().parents[2] / 'exact_blend.py'
spec = importlib.util.spec_from_file_location('exact_blend', p)
blend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(blend)
parser = argparse.ArgumentParser()
parser.add_argument('--url', default='http://127.0.0.1:8765')
args = parser.parse_args()
counts = dict(right=0, wrong=0, withheld=0)
for case in json.loads(Path(__file__).with_name('cases.json').read_text()):
    out = blend.invoke(args.url, 'blend-panel', case['input'])
    status = out['result']['status']
    verdict = 'withheld' if status == 'unknown' else 'right' if status == case['expected'] else 'wrong'
    counts[verdict] += 1
    print(json.dumps(dict(id=case['id'], verdict=verdict, output=out)))
print(json.dumps(counts))
