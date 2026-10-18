#!/usr/bin/env python3
"""Successor checks against the real native checker and independent consumer.
The reserved English templates and numbers are separate from recognizer probes.
No request/generated Python code is executed.
"""
import hashlib
import json
import random
import subprocess
import sys
from pathlib import Path
from answerer import ROOT,Kernel,answer,deduplication_note
sys.path.insert(0,str(ROOT/'tools'))
from code_evidence import validate_code

kernel_path=ROOT/'var/codeorgan/bin/codeorgan-kernel'
k=Kernel(kernel_path)
try:
    author=json.loads((Path(__file__).parent/'probes_first_unique.json').read_text())
    replies=[]
    for item in author:
        r=answer({'id':item['id'],'q':item['q']},k)
        assert r['status']==item['status'],(item,r)
        if r['status']=='answered':
            assert validate_code(r,r['provenance']['evidence']['checked_computation'])['status']=='consistent'
        replies.append(r)
    # This seed and 60 observation sets were not used to tune the recognizer.
    rng=random.Random(530813)
    reserved=[]
    for i in range(60):
        xs=[rng.randrange(-12,13) for _ in range(rng.randrange(1,20))]
        # Nonadjacent repeats distinguish first/last policies on every request.
        a,b=rng.sample(range(20,40),2)
        xs=[a,b,a]+xs
        ys=[b,a,b]+list(reversed(xs))
        first=lambda data:list(dict.fromkeys(data))
        phrase=['preserving original order','keeping first occurrences','keeping order'][i%3]
        name='f'+str(i)
        q=f'Write a function {name} that removes duplicates {phrase}: {name}({xs!r}) == {first(xs)!r}, {name}({ys!r}) == {first(ys)!r}'
        r=answer({'id':'reserved-'+str(i),'q':q},k)
        assert r['status']=='answered',r
        p=r['provenance']['evidence']['checked_computation']
        assert p['results']==[first(xs),first(ys)]
        assert validate_code(r,p)['status']=='consistent'
        reserved.append(r)
    # Mixed macros must not present a global first-occurrence claim.
    assert "last occurrence" in deduplication_note([{'op':x} for x in ['reverse','unique','reverse','unique']])
    assert "first occurrence" in deduplication_note([{'op':x} for x in ['reverse','unique','reverse']])
finally:k.close()

all_replies=replies+reserved
command=[sys.executable,'-B',str(ROOT/'tools/dispatch/dispatch.py'),'--order','front','--organs','computing','--no-reader','--no-document','--no-dialogue','--timeout','10']
requests=[{'id':r['id'],'q':r['provenance']['request_text'],'session':'first-'+r['id']} for r in all_replies if r['status']=='answered']
# Include authored refusals with the original request, too.
requests += [{'id':item['id'],'q':item['q'],'session':'first-'+item['id']} for item in author if item['status']!='answered']
proc=subprocess.run(command,input=''.join(json.dumps(r)+'\n' for r in requests),text=True,capture_output=True,timeout=60,check=True)
composed=[json.loads(line) for line in proc.stdout.splitlines()]
expected={r['id']:r['status'] for r in all_replies}
assert len(composed)==len(expected)
for r in composed:
    assert r['status']==expected[r['id']],r
    if r['status']=='answered':assert r['provenance']['evidence']['consumer_validation']['status']=='consistent'
result={'author_total':len(author),'author_supported':sum(r['status']=='answered' for r in replies),
 'author_withheld_valid':sum(x['valid'] and r['status']=='withheld' for x,r in zip(author,replies)),
 'author_invalid_refused':sum(not x['valid'] and r['status']=='withheld' for x,r in zip(author,replies)),
 'reserved_total':len(reserved),'reserved_supported':len(reserved),'dispatch_total':len(composed),
 'wrong':0,'false_yes':0,'shipped_specialist_panels':None,
 'source_sha256':hashlib.sha256((Path(__file__).parent/'answerer.py').read_bytes()).hexdigest(),
 'kernel_sha256':hashlib.sha256(kernel_path.read_bytes()).hexdigest(),
 'consumer_sha256':hashlib.sha256((ROOT/'tools/code_evidence.py').read_bytes()).hexdigest(),
 'authored_replies':replies,'reserved_replies':reserved,'composed_replies':composed}
(ROOT/'var/codeorgan-sol/first-unique.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if not k.endswith('_replies')},indent=2))
