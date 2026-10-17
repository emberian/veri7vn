#!/usr/bin/env python3
"""Cold start of a family binary: process start to first reply, 5 runs.

  coldstart.py <binary> <specialists-dir> <specialist-id>

The question is the first item of the specialist's shipped panel (read from
<specialists-dir>/<id>, the staging copy on the deploy host), so the measurement
also smoke-tests a real recognition.
"""
import glob
import json
import subprocess
import sys
import time
from pathlib import Path

bin_ = sys.argv[1]
sdir = Path(sys.argv[2]) / sys.argv[3]
panel = sorted(glob.glob(str(sdir / "*panel*.json")))[0]
d = json.loads(Path(panel).read_text(encoding="utf-8"))
items = d["heldout"] if isinstance(d, dict) and "heldout" in d else d
q = json.dumps({"id": "cold", "q": items[0]["q"], "session": "cold"})

colds, answered = [], None
for _ in range(5):
    t0 = time.perf_counter()
    p = subprocess.Popen([bin_], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    p.stdin.write(q + "\n")
    p.stdin.flush()
    line = p.stdout.readline()
    colds.append(1000 * (time.perf_counter() - t0))
    answered = json.loads(line).get("status")
    p.stdin.close()
    p.wait()
print("cold start ms over 5 runs: %s (min %.1f); first reply status: %s"
      % (", ".join("%.1f" % c for c in colds), min(colds), answered))
