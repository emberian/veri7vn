#!/usr/bin/env python3
"""Post-tuning numerical challenge, not an upstream-authored panel generator.

UNTRUSTED: expected values use Python's math library and OpenStax ch17 decibel
equations (the upstream manifest's source). Grammar is selected by the same
author as the recognizer. Use a reserved seed after tuning and record any
subsequent seed reuse as regression evidence. This tests enclosure coverage
and latency, including the guarded 32-to-64-bit retry.
"""
import argparse
import json
import math
import random
import statistics
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "upstream/root/specialists/acoustics"))
import acoustics_scorer

ap = argparse.ArgumentParser()
ap.add_argument("--binary", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--seed", type=int, default=2026101893)
args = ap.parse_args()
rng = random.Random(args.seed)
items = []
for _ in range(60):
    a, b = [round(rng.uniform(-30, 130), 4) for _ in range(2)]
    items.append(dict(q=f'What is the combined sound level of {a} dB and {b} dB?', kind='db_sum', expect=10*math.log10(10**(a/10)+10**(b/10)), valid=True))
    # Values either side of a four-digit rounding boundary, computed through
    # the inverse equation. The question states the decimal ratio exactly.
    target = rng.randint(1000, 9998)/100 + .005 + rng.choice([-1, 1])*1e-7
    ratio = f'{10**(target/10):.10f}'
    items.append(dict(q=f'What is the decibel level change for {ratio} times the intensity?', kind='db_ratio', expect=10*math.log10(float(ratio)), valid=True))
    r1, r2 = [round(rng.uniform(.1, 100), 4) for _ in range(2)]
    items.append(dict(q=f'A sound level is {a} dB at {r1} m. What is it at {r2} m?', kind='db_distance', expect=a-20*math.log10(r2/r1), valid=True))
p = subprocess.Popen([str(ROOT / args.binary)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
report = dict(seed=args.seed, n=len(items), right=0, wrong=0, withheld=0, failures=[])
times = []
for i, it in enumerate(items):
    t = time.perf_counter()
    p.stdin.write(json.dumps(dict(id=str(i), q=it['q'])) + '\n')
    p.stdin.flush()
    reply = json.loads(p.stdout.readline())
    times.append((time.perf_counter()-t)*1000)
    good, asserted = acoustics_scorer.ok(it, reply)
    report['right'] += bool(good)
    report['wrong'] += bool(asserted and not good)
    report['withheld'] += bool(not asserted)
    if not good:
        report['failures'].append(dict(item=it, reply=reply))
p.stdin.close()
assert p.wait() == 0
report['p50_ms'] = statistics.median(times)
report['max_ms'] = max(times)
(ROOT / args.out).write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
