#!/usr/bin/env python3
"""Untrusted authored coordinate-calculus checks, using exact coefficient math.
Expected derivatives use falling factorial coefficients rather than repeated
kernel differentiation. The shipped scorer reads returned polynomial syntax.
Generated language is authored with the recognizer, not independent evidence.
"""
import argparse,json,math,random,re,subprocess,sys
from fractions import Fraction
from pathlib import Path
import score
sys.dont_write_bytecode=True

def ordinal(n):
    return str(n)+('th' if 10<=n%100<=20 else {1:'st',2:'nd',3:'rd'}.get(n%10,'th'))
def expression(cs,v):
    text=' + '.join(f'{c}{v}^{i}' if i else str(c) for i,c in enumerate(cs) if c)
    return text.replace('+ -','- ') or '0'
def derivative(cs,n,same):
    if not same:return [Fraction(0)]
    result=[c*Fraction(math.factorial(i),math.factorial(i-n)) for i,c in enumerate(cs) if i>=n]
    return result or [Fraction(0)]
def evaluate(cs,x):return sum(c*x**i for i,c in enumerate(cs))
def cases(seed):
    rng=random.Random(seed);rows=[]
    for _ in range(25):
        cs=[Fraction(rng.randrange(-8,9),rng.randrange(1,6)) for _ in range(rng.randrange(1,8))]
        source=rng.choice('xzt');n=rng.choice([1,2,3,5,7]);point=Fraction(rng.randrange(-4,5),rng.randrange(1,4))
        for target in [source,{'x':'y','z':'x','t':'s'}[source]]:
            exp=derivative(cs,n,source==target);expr=expression(cs,source)
            pre=f'Find the {ordinal(n)} partial derivative of '
            rows.append(dict(q=pre+expr+f' with respect to {target}',coefs=list(map(str,exp)),target=target,order=n))
            rows.append(dict(q=pre+expr+f' with respect to {target} at {target} = {point}',exact=str(evaluate(exp,point)),target=target,order=n))
            rows.append(dict(q=f'Find the {ordinal(n)} derivative of f({target}) = '+expr,coefs=list(map(str,exp)),target=target,order=n))
            first=derivative(cs,1,source==target)
            rows.append(dict(q=f"If f({target}) = {expr}, what is f'({point})?",exact=str(evaluate(first,point)),target=target,order=1))
    for source,target in [('x','y'),('x','x'),('y','x'),('y','y')]:
        for q in [f'd/d{target} {source}^2',f'Differentiate {source}^2 wrt {target}',f'Differentiate {source}^2 with respect to {target}.',f'Find the derivative of f({target})={source}^2']:
            rows.append(dict(q=q,coefs=['0','2'] if source==target else ['0'],target=target,order=1))
    rows += [dict(q='Differentiate 3 with respect to y',coefs=['0'],target='y',order=1),dict(q='Find the 21st partial derivative of x^25 with respect to x at x = 1',exact=str(math.factorial(25)//math.factorial(4)),target='x',order=21),dict(q='Find the twenty first partial derivative of x^25 with respect to y',coefs=['0'],target='y',order=21)]
    for q,semantic in [
      ('Differentiate x^2 with respect to y if x=y','valid'),
      ('Differentiate x(y)^2 with respect to y','valid'),
      ('Find the derivative of f(y)=x(y)^2','valid'),
      ('Find the derivative of f(y)=x^2 with respect to x','valid'),
      ('Differentiate x^2 with respect to y and then with respect to x','valid'),
      ('Differentiate x^2 with respect to y at x=3','valid'),
      ('Differentiate x^2 with respect to y at y=3 and x=4','valid'),
      ('Differentiate x^2 with respect to y but assume x depends on y','valid'),
      ('Differentiate x^2 with respect to y. Then integrate the result.','valid'),
      ('Differentiate x^2 with respect to x. Then integrate the result.','valid'),
      ('Find the derivative of x^2 with respect to x then find its antiderivative','valid'),
      ('Find the banana derivative of x^2 with respect to y','ambiguous'),
      ('Find the -1st derivative of x^2 with respect to y','valid'),
      ('Find the 0th derivative of x^2 with respect to y','valid'),
      ('Find the 51st derivative of x^2 with respect to y','valid'),
      ('Differentiate x^2 with respect to y at y=1/0','undefined'),
      ('Differentiate 1e-3 with respect to e','valid'),
      ('Differentiate x^2 with respect to y at y=1.5abc','ambiguous'),
      ('Find the derivative of f(y)=x^2 and g(y)=y^2','valid'),
    ]:rows.append(dict(q=q,unsupported=True,semantic=semantic))
    return rows

def check(it,rep,scorer):
    if it.get('unsupported'):return rep.get('status')=='withheld' and rep.get('provenance',{}).get('taken') is True
    if rep.get('status')!='answered':return False
    if 'exact' in it:
        expected=Fraction(it['exact']);match=re.search(r' is (-?\d+(?:/\d+)?) \(from ',rep.get('response',''))
        if not match or Fraction(match[1])!=expected:return False
        panel=dict(q=it['q'],valid=True,kind='value',expect=dict(value=[expected.numerator,expected.denominator]))
    else:
        cs=list(map(Fraction,it['coefs']));panel=dict(q=it['q'],valid=True,kind='derivative',expect=dict(var=it['target'],coefs=[[c.numerator,c.denominator] for c in cs]))
    ok,_=scorer.ok(panel,rep)
    names={1:'derivative',2:'second derivative',3:'third derivative',4:'fourth derivative'}
    return ok and rep.get('response','').startswith('The '+names.get(it['order'],f"{it['order']}-th derivative")+' ')

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--binary',default='var/discrete/bin/discrete');ap.add_argument('--out',required=True);ap.add_argument('--seed',type=int,default=181501);ap.add_argument('--dispatch',choices=['pinned','unpinned']);a=ap.parse_args();items=cases(a.seed);scorer=score.load('calculus','calculus_scorer')
    cmd=[a.binary,'--specialist','calculus']
    if a.dispatch:
        cmd=[sys.executable,'-B','tools/dispatch/dispatch.py','--order','front','--organs','discrete','--no-reader','--no-document','--no-routes']
        if a.dispatch=='pinned':cmd+=['--specialist','calculus']
    proc=subprocess.run(cmd,input=''.join(json.dumps({'id':i,'q':x['q']})+'\n' for i,x in enumerate(items)),text=True,capture_output=True,check=True,timeout=60)
    rows=[dict(case=it,reply=rep,ok=check(it,rep,scorer)) for it,rep in zip(items,map(json.loads,proc.stdout.splitlines()),strict=True)]
    if a.dispatch:
        for r in rows:
            if r['ok'] and r['reply'].get('status')=='withheld':r['ok'] &= r['reply'].get('provenance',{}).get('dispatch',{}).get('decisive') is True
    valid=[r for r in rows if r['case'].get('semantic','valid')=='valid'];other=[r for r in rows if r not in valid];ans=lambda r:r['reply'].get('status')=='answered'
    outcomes=dict(valid_requests=len(valid),answered_correct=sum(ans(r) and r['ok'] for r in valid),answered_wrong=sum(ans(r) and not r['ok'] for r in valid),withheld_valid=sum(not ans(r) for r in valid),ambiguous_or_undefined=len(other),other_answered=sum(ans(r) for r in other),other_withheld=sum(not ans(r) for r in other))
    report=dict(seed=a.seed,command=cmd,n=len(rows),assertions_passed=sum(r['ok'] for r in rows),outcomes=outcomes,rows=rows);Path(a.out).write_text(json.dumps(report,indent=2)+'\n');print(report['assertions_passed'],report['n'],outcomes)
    if report['assertions_passed']!=report['n']:raise SystemExit(1)
if __name__=='__main__':main()
