#!/usr/bin/env python3
"""Untrusted focused checker for exact-model logarithm probes.

Expected values use independent Decimal calculations, but the language is
written by the implementation author. A safe refusal of a valid equation is
counted as withheld_valid, never as a correct capability answer.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import time

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--binary',required=True,type=Path)
p.add_argument('--out',required=True,type=Path)
a=p.parse_args()
items=json.loads(Path(__file__).with_name('log_probes.json').read_text())['probes']
rows=[]
for mode in ['pinned','family']:
    for i,item in enumerate(items):
        args=[str(a.binary)]+(['--specialist',item['specialist']] if mode=='pinned' else [])
        start=time.perf_counter()
        run=subprocess.run(args,input=json.dumps({'id':i,'q':item['q']})+'\n',text=True,capture_output=True,check=True,timeout=30)
        reply=json.loads(run.stdout)
        asserted=reply.get('status')=='answered'
        # Spacecraft states four decimals; path loss states two. No permissive
        # absolute tolerance borrowed from unrelated orbital units.
        tolerance=0.0051 if item['specialist']=='spacecomms' else 0.000051
        value=reply.get('value')
        correct=asserted and value is not None and math.isclose(float(value),item['expect'],rel_tol=1e-6,abs_tol=tolerance)
        verdict='right' if correct else 'wrong' if asserted else 'withheld_valid'
        rows.append(dict(mode=mode,item=item,reply=reply,verdict=verdict,cold_ms=(time.perf_counter()-start)*1000))
counts={mode:{key:sum(r['mode']==mode and r['verdict']==key for r in rows) for key in ['right','wrong','false_yes','withheld_valid']} for mode in ['pinned','family']}
a.out.write_text(json.dumps(dict(binary=str(a.binary),binary_sha256=hashlib.sha256(a.binary.read_bytes()).hexdigest(),counts=counts,rows=rows),indent=2)+'\n')
print(json.dumps(counts))
raise SystemExit(0 if all(r['verdict']=='right' for r in rows) else 1)
