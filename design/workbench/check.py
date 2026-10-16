#!/usr/bin/env python3
"""Design consistency and source-patch reference checks, not native client tests."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
HERE=Path(__file__).resolve().parent
scenarios=json.loads((HERE/'scenarios.json').read_text())
ids={s['id'] for s in scenarios}
assert len(ids)==13
for s in scenarios:
    assert s['next'] in ids and len(s['axis'])==3
    assert [a.split(':')[0] for a in s['axis']]==['Math check','Example checks','Use']
    assert s['origin'] and s['cli'].startswith('v7 ')
    assert len(s['actions'])>=3 and len(s['rows'])>=4
    assert len(s['previews'])==len(s['actions'])
before=(HERE/'index.html').read_bytes()
subprocess.run([sys.executable,str(HERE/'render.py')],check=True,capture_output=True)
assert before==(HERE/'index.html').read_bytes(), 'preview must be reproducibly generated'

# Reference byte-span patch rule only. Native parser/source-map implementation is absent.
# These are synthetic declaration bytes; no invented recipe syntax is claimed supported.
source=b'theory Fixture imports Main begin\n(* recipe span *)\n(* expert: preserve \\xCE\\xBB bytes and comments *)\nlemma identity: "x = x" by simp\nend\n'
start=source.index(b'(* recipe span *)'); end=start+len(b'(* recipe span *)')
revision=lambda b:hashlib.sha256(b).hexdigest()
def apply(current,base,old,start,end,new):
    if revision(current)!=base or current[start:end]!=old:
        raise ValueError('source revision conflict')
    return current[:start]+new+current[end:]
replacement=b'(* revised recipe span; native proposal required *)'
patched=apply(source,revision(source),source[start:end],start,end,replacement)
assert patched[:start]==source[:start] and patched[start+len(replacement):]==source[end:]
try:
    apply(source+b'(* concurrent expert edit *)',revision(source),source[start:end],start,end,replacement)
    raise AssertionError('concurrent source was overwritten')
except ValueError: pass
# A stale byte span with a current revision also refuses rather than guessing target.
try:
    apply(source,revision(source),b'wrong source span',start,end,replacement)
    raise AssertionError('stale span accepted')
except ValueError: pass
report={'kind':'design-reference checks only; no native parser, theorem, runtime or human usability claim','scenario_count':13,'passed':['all scenario navigation targets and readiness axes','reproducible standalone rendering','source span replacement preserves opaque expert bytes','concurrent revision refusal','stale span refusal'],'native_remaining':['native source parser and offset mapping','native patch proposal validation','atomic source revision persistence','authority/host wire integration','production browser/CLI behavior']}
(HERE/'checks.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
