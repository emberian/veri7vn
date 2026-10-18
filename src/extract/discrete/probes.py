#!/usr/bin/env python3
"""Untrusted calculus regression probes, authored alongside the recognizer.
Expected values use elementary polynomial differentiation/integration; the shipped
calculus scorer independently reads the answer polynomial. These are development
probes, not a claimed independent heldout generator.
"""
import json, subprocess, sys
from pathlib import Path
import score

def poly(q, cs, var='x', kind='derivative'):
    return dict(q=q,valid=True,kind=kind,expect=dict(var=var,coefs=[[c,1] for c in cs]))
def value(q,n,d=1):
    return dict(q=q,valid=True,kind='value',expect=dict(value=[n,d]))
def decline(q):return dict(q=q,valid=False,kind='unsupported',expect='decline')
PROBES=[
    poly('Find the fifth derivative of x^6',[0,720]),
    poly('Find the sixth derivative of 2x^6',[1440]),
    poly('Find the 7th derivative of x^8',[0,40320]),
    poly('Find the 10th derivative of x^4',[0]),
    poly('Find the 50th derivative of x^2',[0]),
    poly('Find a primitive of 6x^2',[0,0,0,2],kind='anti'),
    poly('Find the anti-derivative of 2x',[0,0,1],kind='anti'),
    poly('Find a primitive of 3 with respect to y',[0,3],var='y',kind='anti'),
    value('Find the fifth derivative of x^6 at x = 2',1440),
    value('Integrate x^2 from 3 to -2',-35,3),
    value('Integrate 3x^2 from 1/2 to 3/2',13,4),
    value('Find the derivative of x^2 at x = 1.5',3),
    poly('Differentiate x^2 with respect to x',[0,2]),
    poly('Differentiate 3 with respect to y',[0]),
    decline('Differentiate 1/0x^2'),
    decline('Find the derivative of x^3 at x = 1/0'),
    decline('Integrate x^2 from 1/0 to 2'),
    decline('Differentiate x^2 with respect to y'),
    decline('Find the derivative of x^2 at y = 2'),
    decline('Find the derivative of x^2 at x = 1.5abc'),
    decline('Integrate x^2 from 1 to 2.5abc'),
    decline('Find the 51st derivative of x^50'),
    decline('Find the hundredth derivative of x^3'),
    decline('Integrate x^2 from zero to 2'),
]

# Check the requested order in the prose too; the polynomial scorer alone would
# accept a correct fifth-derivative polynomial mislabeled as the fourth.
for index, order in [(0,5),(1,6),(2,7),(3,10),(4,50),(8,5)]:
    PROBES[index]['label'] = f'The {order}-th derivative'

def main():
    binary=sys.argv[1] if len(sys.argv)>1 else 'var/discrete/bin/discrete'
    proc=subprocess.run([binary,'--specialist','calculus'],input=''.join(json.dumps({'id':i,'q':x['q']})+'\n' for i,x in enumerate(PROBES)),capture_output=True,text=True,check=True)
    scorer=score.load('calculus','calculus_scorer');rows=[]
    counts=dict(n=len(PROBES),right=0,wrong=0,false_yes=0,withheld_valid=0)
    for it,line in zip(PROBES,proc.stdout.splitlines(),strict=True):
        rep=json.loads(line); good,asserted=scorer.ok(it,rep)
        if it.get('label') and not rep.get('response','').startswith(it['label']): good=False
        counts['right' if good else 'false_yes' if not it['valid'] else 'wrong' if asserted else 'withheld_valid']+=1
        rows.append(dict(probe=it,reply=rep,ok=good,decisive=(rep.get('kind')=='unsupported' and (rep.get('provenance') or {}).get('taken') is True) if not it['valid'] else None))
    print(json.dumps(dict(counts=counts,rows=rows),indent=2))
if __name__=='__main__':main()
