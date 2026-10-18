#!/usr/bin/env python3
"""Real native/consumer/composition checks for the finite integer extension.
Python arithmetic/list references are independent and untrusted. No supplied or
rendered program source is executed. Expected refusal is never a fabricated case.
"""
import hashlib
import json
import math
import random
import subprocess
import sys
from pathlib import Path
from answerer import ROOT,Kernel,answer
sys.path.insert(0,str(ROOT/'tools'))
from code_evidence import validate_code

binary=ROOT/'var/codeorgan/bin/codeorgan-kernel'
k=Kernel(binary)
try:
    # Complete bounded factorial domain, split below the native64-case limit.
    factorial={'base':{'op':'arg','index':0},'moves':[{'op':'factorial'}]}
    for start in range(0,101,50):
        cs=[{'args':[n],'expected':math.factorial(n)} for n in range(start,min(start+50,101))]
        r=k.check(factorial,cs)
        assert r['accepted'] is True and r['results']==[c['expected'] for c in cs]
    for n in [-1,101]:
        r=k.check(factorial,[{'args':[n],'expected':0}]);assert r['accepted'] is False and r['results']==[None]
    r=k.check(factorial,[{'args':[0],'expected':True}]);assert r['accepted'] is False and r['results']==[1]
    # Euclidean references include signed values, zeros and large exact inputs.
    rng=random.Random(948531)
    gcd_cases=[{'args':[a,b],'expected':math.gcd(a,b)} for a,b in [(0,0),(-12,18),(0,-19),(-24,-36)]]
    gcd_cases += [{'args':[a,b],'expected':math.gcd(a,b)} for a,b in ((rng.randrange(-10**20,10**20),rng.randrange(-10**20,10**20)) for _ in range(196))]
    gcd_program={'base':{'op':'gcd','left':0,'right':1},'moves':[]}
    for start in range(0,len(gcd_cases),50):
        cs=gcd_cases[start:start+50];r=k.check(gcd_program,cs)
        assert r['accepted'] is True and r['results']==[c['expected'] for c in cs]
    probes=json.loads((Path(__file__).parent/'probes_integer.json').read_text())
    authored=[]
    for item in probes:
        r=answer({'id':item['id'],'q':item['q']},k)
        assert r['status']==item['status'],(item,r)
        if r['status']=='answered':
            p=r['provenance']['evidence']['checked_computation']
            assert validate_code(r,p)['status']=='consistent'
            # Every actual upstream prose example is exactly ONE case.
            if item['origin']=='actual stored upstream request':assert len(p['examples'])==1
        authored.append(r)
    # Fresh values/observations were reserved before the first native run.
    # Grammar is authored; this is not an untouched natural-language benchmark.
    rng=random.Random(714239)
    reserved=[]
    for i in range(120):
        mode=i%6;name='r'+str(i)
        if mode==0:
            a,b=rng.randrange(-10**18,10**18),rng.randrange(-10**18,10**18)
            q=f'Write a function {name} that returns the greatest common divisor, so {a} and {b} give {math.gcd(a,b)}.'
        elif mode==1:
            n=rng.randrange(101)
            q=f'Write a function {name} that returns the factorial: {name}({n}) == {math.factorial(n)}'
        elif mode==2:
            xs=[rng.randrange(-30,31) for _ in range(rng.randrange(16))]
            q=f'Write a function {name} that returns a list doubled, so {xs!r} gives {[2*x for x in xs]!r}.'
        elif mode==3:
            xs=sorted(rng.randrange(-30,31) for _ in range(rng.randrange(10)))
            ys=sorted(rng.randrange(-30,31) for _ in range(rng.randrange(10)))
            q=f'Write a function {name} that merges two sorted lists, so {xs!r} and {ys!r} give {sorted(xs+ys)!r}.'
        elif mode==4:
            rank=rng.randrange(1,5);values=rng.sample(range(-40,41),8)
            xs=values+[values[0],values[0],values[1]];rng.shuffle(xs)
            distinct=i%12==4
            target=sorted(set(xs) if distinct else xs,reverse=True)[rank-1]
            ordinal={1:'1st',2:'2nd',3:'3rd',4:'4th'}[rank]
            label=f'{ordinal} distinct largest number' if distinct else f'{ordinal} largest number including duplicates'
            q=f'Write a function {name} that returns the {label}, so {xs!r} gives {target}.'
        else:
            xs=[rng.randrange(-8,9) for _ in range(18)]
            target=list(dict.fromkeys(xs))
            q=f'Write a function {name} that removes duplicates keeping order, so {xs!r} gives {target!r}.'
        r=answer({'id':'reserved-'+str(i),'q':q},k)
        assert r['status']=='answered',r
        assert validate_code(r,r['provenance']['evidence']['checked_computation'])['status']=='consistent'
        reserved.append(r)
finally:k.close()

# Full default composition on all stored upstream requests and boundary probes.
command=[sys.executable,'-B',str(ROOT/'tools/dispatch/dispatch.py')]
requests=[{'id':x['id'],'q':x['q'],'session':'integer-'+x['id']} for x in probes]
proc=subprocess.run(command,input=''.join(json.dumps(x)+'\n' for x in requests),capture_output=True,text=True,timeout=90,check=True)
composed=[json.loads(line) for line in proc.stdout.splitlines()]
assert len(composed)==len(probes)
for item,r in zip(probes,composed):
    assert r['id']==item['id'] and r['status']==item['status'],(item,r)
    if r['status']=='answered':assert r['provenance']['evidence']['consumer_validation']['status']=='consistent'
result={'factorial_domain_cases':101,'factorial_boundary_refusals':3,'gcd_reference_cases':len(gcd_cases),
 'authored_total':len(probes),'authored_supported':sum(r['status']=='answered' for r in authored),
 'authored_withheld_valid':sum(x['valid'] and r['status']=='withheld' for x,r in zip(probes,authored)),
 'authored_invalid_refused':sum(not x['valid'] and r['status']=='withheld' for x,r in zip(probes,authored)),
 'stored_upstream_total':15,'stored_upstream_supported':sum(x['origin']=='actual stored upstream request' and r['status']=='answered' for x,r in zip(probes,authored)),
 'reserved_total':len(reserved),'reserved_supported':len(reserved),'full_default_total':len(composed),
 'wrong':0,'false_yes':0,'shipped_specialist_panels':None,
 'hashes':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [Path(__file__).parent/'answerer.py',binary,ROOT/'tools/code_evidence.py',ROOT/'tools/dispatch/dispatch.py']},
 'authored_replies':authored,'reserved_replies':reserved,'full_default_replies':composed,'stderr':proc.stderr}
(ROOT/'var/codeorgan-sol/integer.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if not k.endswith('_replies')},indent=2))
