#!/usr/bin/env python3
"""Record actual imported base chain and method calls; static, no execution."""
import json
from pathlib import Path
from classify import ROOT
folder=ROOT/'upstream/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted'
head=json.loads((folder/'HEAD_MANIFEST.json').read_text())
rows=[]
for name in head['chain_tip_to_base']:
    p=folder/(name+'.py')
    if not p.exists():
        rows.append({'module':name,'missing':True});continue
    rows.append({'module':name,'path':str(p.relative_to(ROOT))})
out={'tip':head['tip'],'chain':rows,'scope':'No runtime imported. This is only the HEAD denominator; actual imported C3 class order and method resolution live in dispatch.json.'}
(ROOT/'docs/coverage/classification/runtime-chain.json').write_text(json.dumps(out,indent=2)+'\n')
print(len(rows),'chain modules retained')
