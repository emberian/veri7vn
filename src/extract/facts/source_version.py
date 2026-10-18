#!/usr/bin/env python3
"""Untrusted build metadata: version the exact checked source-table snapshot.

This digest identifies source data; it does not prove author identity or English
interpretation. Native compiler input receipts bind the emitted SML constant.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

p=argparse.ArgumentParser()
p.add_argument('--repo',type=Path,required=True)
p.add_argument('--export',dest='export',type=Path,required=True)
p.add_argument('--receipt',type=Path)
p.add_argument('--out',type=Path,required=True)
a=p.parse_args()
sys.path.insert(0,str(a.repo/'tools/dev'))
from native_compile import select_receipt
receipt, record, _, _ = select_receipt(a.repo,'facts','Veri7vn_Facts',[a.export],a.receipt)
sources=json.loads(receipt.with_name('source-sha256.json').read_text())
h=hashlib.sha256(b'veri7vn-facts-source-v1\0')
for name in ['src/extract/facts/Facts_Tables.thy','src/extract/facts/Facts_Rows.thy']:
    content=(receipt.parent/name).read_bytes()
    if hashlib.sha256(content).hexdigest()!=sources.get(name):
        raise ValueError('immutable source input mismatch: '+name)
    label=name.encode('utf-8')
    h.update(len(label).to_bytes(8,'big'));h.update(label)
    h.update(len(content).to_bytes(8,'big'));h.update(content)
version='sha256:'+h.hexdigest()
a.out.write_text('(* Generated from immutable checked table inputs; untrusted build metadata. *)\nstructure FactsSourceVersion = struct val version = "'+version+'" end\n')
print(version)
