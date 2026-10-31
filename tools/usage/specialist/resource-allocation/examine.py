#!/usr/bin/env python3
"""Untrusted actual-host panel with independent original-row certificate replay."""
import argparse
import importlib.util
import json
import sys
from pathlib import Path
p = Path(__file__).resolve().parents[2] / 'resource_allocation.py'
sys.path.insert(0, str(p.parent))
spec = importlib.util.spec_from_file_location('resource_allocation', p)
allocation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(allocation)
parser = argparse.ArgumentParser()
parser.add_argument('--url', default='http://127.0.0.1:8765')
args = parser.parse_args()
counts = dict(right=0, wrong=0, withheld=0)
for case in json.loads(Path(__file__).with_name('cases.json').read_text()):
    out = allocation.invoke(args.url, 'allocation-panel', case['input'])
    correct = out['status'] == case['expected'] and ('profit' not in case or allocation.rational(out['profit']['value']) == allocation.rational(case['profit']))
    verdict = 'withheld' if out['status'] == 'unknown' else 'right' if correct else 'wrong'
    counts[verdict] += 1
    print(json.dumps(dict(id=case['id'], verdict=verdict, output=out)))
print(json.dumps(counts))
