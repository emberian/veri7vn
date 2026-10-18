#!/usr/bin/env python3
"""Scoped independent arithmetic/list replay and adversarial frontdoor checks.
Does not execute request text or generated source. Python reference is untrusted.
"""
import argparse
import ast
import hashlib
import itertools
import json
import random
from pathlib import Path
from answerer import Kernel, answer, ROOT, UNARY, PARAM

class Undefined(Exception): pass

def reference(p,args):
    def number(v):
        if type(v) is not int: raise Undefined()
        return v
    def numbers(v):
        if type(v) is not list or not all(type(x) is int for x in v): raise Undefined()
        return v
    b=p['base']
    try:
        if b['op']=='arg': v=args[b['index']]
        else:
            a,c=args[b['left']],args[b['right']]
            if b['op']=='add': v=number(a)+number(c)
            elif b['op']=='subtract': v=number(a)-number(c)
            elif b['op']=='multiply': v=number(a)*number(c)
            elif b['op']=='concat': v=numbers(a)+numbers(c)
            elif b['op']=='zip_add': v=[x+y for x,y in zip(numbers(a),numbers(c))]
            elif b['op']=='zip_multiply': v=[x*y for x,y in zip(numbers(a),numbers(c))]
            else: raise Undefined()
        for m in p['moves']:
            op=m['op']
            if op in {'absolute','square','cube','negate','is_even','is_odd'}:
                x=number(v)
                v={'absolute':lambda:abs(x),'square':lambda:x*x,'cube':lambda:x*x*x,
                   'negate':lambda:-x,'is_even':lambda:x%2==0,'is_odd':lambda:x%2!=0}[op]()
                continue
            xs=numbers(v)
            if op=='reverse': v=list(reversed(xs))
            elif op=='sort': v=sorted(xs)
            elif op=='sort_desc': v=sorted(xs,reverse=True)
            elif op=='unique': v=[x for i,x in enumerate(xs) if all(x!=z for z in xs[i+1:])]
            elif op=='square_each': v=[x*x for x in xs]
            elif op=='abs_each': v=[abs(x) for x in xs]
            elif op=='negate_each': v=[-x for x in xs]
            elif op=='even_only': v=[x for x in xs if x%2==0]
            elif op=='odd_only': v=[x for x in xs if x%2!=0]
            elif op=='positive_only': v=[x for x in xs if x>0]
            elif op=='negative_only': v=[x for x in xs if x<0]
            elif op=='sum': v=sum(xs)
            elif op=='product':
                v=1
                for x in xs: v*=x
            elif op=='length': v=len(xs)
            elif op=='maximum':
                if not xs: raise Undefined()
                v=max(xs)
            elif op=='minimum':
                if not xs: raise Undefined()
                v=min(xs)
            elif op=='all_same': v=all(x==xs[0] for x in xs)
            elif op=='all_unique': v=len(set(xs))==len(xs)
            elif op=='is_sorted': v=all(a<=b for a,b in zip(xs,xs[1:]))
            elif op=='add_each': v=[x+m['constant'] for x in xs]
            elif op=='multiply_each': v=[x*m['constant'] for x in xs]
            elif op=='above': v=[x for x in xs if x>m['constant']]
            elif op=='below': v=[x for x in xs if x<m['constant']]
            elif op=='take': v=xs[:m['constant']]
            elif op=='drop': v=xs[m['constant']:]
            else: raise Undefined()
        return v
    except (Undefined,IndexError): return None

def native_checks(kernel,seed,count):
    rng=random.Random(seed)
    unary=list(UNARY)+list(PARAM)
    scalar={'absolute','square','cube','negate','is_even','is_odd'}
    list_to_number={'sum','product','length','maximum','minimum'}
    list_to_bool={'all_same','all_unique','is_sorted'}
    defined=0
    for i in range(count):
        if i%3==0:
            args=[rng.randrange(-3,4),rng.randrange(-3,4)]
            base={'op':rng.choice(['add','subtract','multiply']),'left':0,'right':1}
        else:
            args=[[rng.randrange(-3,4) for _ in range(rng.randrange(7))] for _ in range(2)]
            base=rng.choice([{'op':'arg','index':0},{'op':'concat','left':0,'right':1},
                             {'op':'zip_add','left':0,'right':1},{'op':'zip_multiply','left':0,'right':1}])
        moves=[]
        typ='int' if i%3==0 else 'list'
        for _ in range(rng.randrange(5)):
            if typ=='bool': break
            choices=list(scalar) if typ=='int' else [o for o in unary if o not in scalar]
            op=rng.choice(sorted(choices))
            moves.append({'op':op,**({'constant':rng.randrange(4) if op in {'take','drop'} else rng.randrange(-3,4)} if op in PARAM else {})})
            if op in list_to_number: typ='int'
            elif op in list_to_bool or op in {'is_even','is_odd'}: typ='bool'
        p={'base':base,'moves':moves}
        expected=reference(p,args)
        defined += expected is not None
        cs=[{'args':args,'expected':0 if expected is None else expected}]
        r=kernel.check(p,cs)
        assert r.get('results')==[expected],(seed,i,p,args,expected,r)
        assert r['accepted']==(expected is not None),(seed,i,p,args,expected,r)
    # Distinct bool/int semantics and malformed source/index controls.
    for p,cs in [
      ({'base':{'op':'arg','index':0},'moves':[]},[{'args':[1],'expected':True}]),
      ({'base':{'op':'arg','index':9},'moves':[]},[{'args':[1],'expected':1}]),
      ({'base':{'op':'arg','index':0},'moves':[{'op':'square'}]},[{'args':[True],'expected':1}]),
    ]:
        assert kernel.check(p,cs)['accepted'] is False
    assert kernel.check({'base':{'op':'arg','index':0},'moves':[]},[])['accepted'] is False
    return {'defined':defined,'undefined':count-defined}

def frontdoor_checks(kernel,probes):
    replies=[]
    for item in probes:
        r=answer({'id':item['id'],'q':item['q']},kernel)
        assert r['status']==item['status'],(item,r)
        if r['status']=='answered':
            packet=r['provenance']['evidence']['checked_computation']
            # Data-only inspection of source; never run request/generated source.
            tree=ast.parse(packet['program_source'])
            assert any(isinstance(n,ast.FunctionDef) and n.name==packet['function_name'] for n in tree.body)
            assert packet['results']==[ex['expected'] for ex in packet['examples']]
            for ex in packet['examples']:
                got=reference(packet['program'],ex['args'])
                assert type(got) is type(ex['expected']) and got==ex['expected'],(item,got,r)
        replies.append({'id':item['id'],'status':r['status'],'path':r['path'],'reply':r})
    return replies

def main():
    a=argparse.ArgumentParser();a.add_argument('--kernel',type=Path,default=ROOT/'var/codeorgan/bin/codeorgan-kernel')
    a.add_argument('--output',type=Path,default=ROOT/'var/codeorgan-sol/check.json'); ns=a.parse_args()
    k=Kernel(ns.kernel)
    try:
        authored=native_checks(k,1847,200)
        reserved=native_checks(k,73661,160)
        probes=json.loads((Path(__file__).parent/'probes.json').read_text())
        replies=frontdoor_checks(k,probes)
    finally:k.close()
    summary={'kernel_sha256':hashlib.sha256(ns.kernel.read_bytes()).hexdigest(),
      'native_authored_seed_cases':200,'native_reserved_seed_cases':160,'native_authored_classification':authored,'native_reserved_classification':reserved,
      'frontdoor_total':len(probes),'frontdoor_supported':sum(x['status']=='answered' for x in probes),
      'frontdoor_withheld_valid':sum(x.get('valid') and x['status']=='withheld' for x in probes),
      'frontdoor_invalid_refused':sum(not x.get('valid') and x['status']=='withheld' for x in probes),
      'wrong':0,'false_yes':0,'shipped_specialist_panels':None,'replies':replies}
    ns.output.parent.mkdir(parents=True,exist_ok=True);ns.output.write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps({k:v for k,v in summary.items() if k!='replies'},indent=2))
if __name__=='__main__':main()
