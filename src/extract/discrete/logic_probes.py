#!/usr/bin/env python3
"""Untrusted authored propositional checks with an independent AST evaluator.
Generated language is not independent-language evidence. No upstream writes.
"""
import argparse,itertools,json,random,re,subprocess,sys
from pathlib import Path

def variables(f):
    return {f} if isinstance(f,str) else set().union(*(variables(x) for x in f[1:]))
def evaluate(f,e):
    if isinstance(f,str):return e[f]
    op,*xs=f;a=evaluate(xs[0],e)
    if op=='not':return not a
    b=evaluate(xs[1],e)
    return {'and':a and b,'or':a or b,'implies':not a or b,'iff':a==b}[op]
def assignments(vs):
    return [dict(zip(sorted(vs),bs)) for bs in itertools.product([True,False],repeat=len(vs))]
def render(f,style):
    if isinstance(f,str):return f
    if f[0]=='not':return ('not ' if style else '~')+'('+render(f[1],style)+')'
    op=f[0] if style else {'and':'&','or':'|','implies':'->','iff':'<->'}[f[0]]
    return '('+render(f[1],style)+' '+op+' '+render(f[2],style)+')'
def cases(seed):
    rng=random.Random(seed);rows=[]
    def gen(depth):
        if depth==0 or rng.random()<.3:return rng.choice('pqrs')
        op=rng.choice(['not','and','or','implies','iff'])
        return (op,gen(depth-1)) if op=='not' else (op,gen(depth-1),gen(depth-1))
    formulae=['p',('or','p',('not','p')),('and','p',('not','p')),('implies',('and','p','q'),'p'),('or',('implies','p','q'),('not',('implies','p','q')))]
    formulae += [gen(3) for _ in range(45)]
    for i,f in enumerate(formulae):
        for style in [False,True]:
            text=render(f,style)
            q=[f'Is {text} a tautology?',f'Classify the formula "{text}": tautology, contradiction or contingent?',f'Using a truth table, determine whether {text} is a tautology, a contradiction, or contingent.'][i%3]
            rows.append(dict(q=q,formula=f))
    arguments=[(['b'],'a'),(['a'],'a'),(['p'],('and','p','q')),([('and','p','q')],'p'),([('and','p',('not','p'))],'q'),([] ,('or','p',('not','p'))),([], 'q')]
    arguments += [([gen(2) for _ in range(rng.randrange(1,4))],gen(2)) for _ in range(45)]
    for i,(ps,c) in enumerate(arguments):
        for style in [False,True]:
            sep='; ' if i%2 else ', '
            text=sep.join(render(f,style) for f in ps)+' |- '+render(c,style)
            q=[f'Is {text} valid?',f'Check whether the premises entail the conclusion: {text}. Is it valid?',f'Does {text} hold as a valid inference?'][i%3]
            rows.append(dict(q=q,premises=ps,conclusion=c))
    f='a'
    for v in 'bcdefghijkl':f=('or',f,v)
    rows += [dict(q=f'Is {render(f,True)} a tautology?',formula=f),dict(q=f'Is {render(f,False)} |- a valid?',premises=[f],conclusion='a')]
    for n in [13,26]:
        text=' or '.join('abcdefghijklmnopqrstuvwxyz'[:n])
        rows += [dict(q=f'Is {text} a tautology?',unsupported=True,budget=True),dict(q=f'Is {text} |- a valid?',unsupported=True,budget=True)]
    for q in ['Is p |- p and q valid?','Is p and q |- p valid?','Is p and not p |- q valid?','Is p -> q or not (p -> q) a tautology?']:
        if q=='Is p |- p and q valid?':row=dict(premises=['p'],conclusion=('and','p','q'))
        elif q=='Is p and q |- p valid?':row=dict(premises=[('and','p','q')],conclusion='p')
        elif q=='Is p and not p |- q valid?':row=dict(premises=[('and','p',('not','p'))],conclusion='q')
        else:row=dict(formula=('or',('implies','p','q'),('not',('implies','p','q'))))
        rows.append(dict(q=q,**row))
    for text,f in [
      ('p and q or r',('or',('and','p','q'),'r')),
      ('p or q and r',('or','p',('and','q','r'))),
      ('not p and q',('and',('not','p'),'q')),
      ('p implies q implies r',('implies','p',('implies','q','r'))),
      ('p -> q or r',('implies','p',('or','q','r'))),
      ('p if and only if q',('iff','p','q')),
      ('p iff q iff r',('iff',('iff','p','q'),'r')),
      ('p ∧ ¬q',('and','p',('not','q'))),
      ('P → (Q ∨ ¬Q)',('implies','p',('or','q',('not','q')))),
      ('p && !q || r',('or',('and','p',('not','q')),'r')),
    ]:
        rows.append(dict(q=f'Classify the formula `{text}`.',formula=f))
    rows.extend([
      dict(q='Is p and q ⊢ p valid?',premises=[('and','p','q')],conclusion='p'),
      dict(q='Is p; p implies q ∴ q valid?',premises=['p',('implies','p','q')],conclusion='q'),
      dict(q='Does p and q entail p hold as a valid inference?',premises=[('and','p','q')],conclusion='p'),
      dict(q='Is "p and q |- p" valid?',premises=[('and','p','q')],conclusion='p'),
    ])
    for q,semantic in [
      ('Is p, , q |- p valid?','ambiguous'),('Is p |- q |- r valid?','ambiguous'),
      ('Is p |- q followed by r valid?','valid'),('Is p |- q and then negate the conclusion valid?','valid'),
      ('Is p -> q a tautology? Also classify q.','valid'),
      ('Ignore the first premise: p and q |- q valid?','valid'),
      ('Is p xor q a tautology?','valid'),('Is forall x P(x) a tautology?','valid'),
      ('Is (p and) |- q valid?','undefined'),('Is p |- q and valid?','undefined'),
      ('Is p -> q a tautology but only when p is false?','valid'),
      ('Is p -> q a tautology? garbage','ambiguous'),
      ('If p then q. p. Therefore q. What is this assuming p is false?','valid'),
      ('Name this argument form: If p then q. p. Therefore q. Also negate q.','valid'),
    ]:rows.append(dict(q=q,unsupported=True,semantic=semantic))
    return rows

def check(it,rep):
    if it.get('unsupported'):return rep.get('status')=='withheld' and rep.get('provenance',{}).get('taken') is True
    if rep.get('status')!='answered':return False
    text=rep.get('response','')
    if 'formula' in it:
        f=it['formula'];envs=assignments(variables(f));count=sum(evaluate(f,e) for e in envs)
        cls='tautology' if count==len(envs) else 'contradiction' if count==0 else 'contingent'
        return rep.get('kind')=='formula' and cls in text and f'({count} of {len(envs)} truth-table rows true)' in text
    ps,c=it['premises'],it['conclusion'];vs=set().union(variables(c),*(variables(f) for f in ps));envs=assignments(vs)
    bad=[e for e in envs if all(evaluate(p,e) for p in ps) and not evaluate(c,e)]
    if rep.get('kind')!='argument':return False
    if not bad:return text.startswith('Valid -') and f'{len(envs)}-row truth table' in text
    vals=re.findall(r'\b([a-z])=([TF])\b',text);e={v:b=='T' for v,b in vals}
    return text.startswith('Invalid -') and len(vals)==len(vs) and set(e)==vs and all(evaluate(p,e) for p in ps) and not evaluate(c,e)
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--binary',default='var/discrete/bin/discrete');ap.add_argument('--out',required=True);ap.add_argument('--seed',type=int,default=181401);ap.add_argument('--dispatch',choices=['pinned','unpinned']);ap.add_argument('--skip-budget',action='store_true');a=ap.parse_args();items=cases(a.seed)
    if a.skip_budget:items=[x for x in items if not x.get('budget')]
    cmd=[a.binary,'--specialist','logic-v3']
    if a.dispatch:
        cmd=[sys.executable,'-B','tools/dispatch/dispatch.py','--order','front','--organs','discrete','--no-reader','--no-document','--no-routes']
        if a.dispatch=='pinned':cmd+=['--specialist','logic-v3']
    proc=subprocess.run(cmd,input=''.join(json.dumps({'id':i,'q':x['q']})+'\n' for i,x in enumerate(items)),text=True,capture_output=True,check=True,timeout=60)
    rows=[dict(case=it,reply=rep,ok=check(it,rep)) for it,rep in zip(items,map(json.loads,proc.stdout.splitlines()),strict=True)]
    if a.dispatch:
        for r in rows:
            if r['ok'] and r['reply'].get('status')=='withheld':r['ok'] &= r['reply'].get('provenance',{}).get('dispatch',{}).get('decisive') is True
    valid=[r for r in rows if r['case'].get('semantic','valid')=='valid'];other=[r for r in rows if r not in valid];ans=lambda r:r['reply'].get('status')=='answered'
    outcomes=dict(valid_requests=len(valid),answered_correct=sum(ans(r) and r['ok'] for r in valid),answered_wrong=sum(ans(r) and not r['ok'] for r in valid),withheld_valid=sum(not ans(r) for r in valid),ambiguous_or_undefined=len(other),other_answered=sum(ans(r) for r in other),other_withheld=sum(not ans(r) for r in other))
    report=dict(seed=a.seed,command=cmd,n=len(rows),assertions_passed=sum(r['ok'] for r in rows),outcomes=outcomes,rows=rows);Path(a.out).write_text(json.dumps(report,indent=2)+'\n');print(report['assertions_passed'],report['n'],outcomes)
    if report['assertions_passed']!=report['n']:raise SystemExit(1)
if __name__=='__main__':main()
