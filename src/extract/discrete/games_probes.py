#!/usr/bin/env python3
"""Untrusted authored games checks. No independent-language evidence claim.
Uses exact enumeration for small dice and combinatorial card counts, rather
than the runtime's recurrence. No upstream writes.
"""
import argparse,itertools,json,math,random,re,subprocess
from fractions import Fraction
from pathlib import Path

def cases(seed=181109):
    rng=random.Random(seed);rows=[]
    for sides in [2,6,20]:
        for n in [0,1,3]:
            for face in [-1,0,1,sides,sides+1]:
                # Enumerated sample space, including the sole empty tuple.
                outcomes=list(itertools.product(range(1,sides+1),repeat=n))
                p=Fraction(sum(face in xs for xs in outcomes),len(outcomes))
                rows.append(dict(q=f'What is the probability of at least one {face} in {n} rolls of a {sides}-sided die?',value=str(p),kind='at_least_one'))
    cats=[('aces',4),('kings',4),('face cards',12),('hearts',13),('red cards',26)]
    for category,g in cats:
        for k in [0,1,2,4,5,13,26,52,53]:
            for replace in [False,True]:
                p=Fraction(g,52)**k if replace else Fraction(math.comb(g,k),math.comb(52,k)) if k<=g else Fraction(0)
                rows.append(dict(q=f'What is the probability of drawing {k} {category} in a row {"with" if replace else "without"} replacement from a standard deck of cards?',value=str(p)))
    for _ in range(50):
        category,g=rng.choice(cats);k=rng.randrange(1,54);replace=bool(rng.randrange(2))
        p=Fraction(g,52)**k if replace else Fraction(math.comb(g,k),math.comb(52,k)) if k<=g else Fraction(0)
        rows.append(dict(q=f'What is the chance of pulling {k} {category} in a row {"with" if replace else "without"} replacement from a deck of 52 cards?',value=str(p)))
    for word,k in [('five',5),('eleven',11),('twenty-five',25),('twenty five',25),('fifty-three',53),('one hundred',100)]:
        rows.append(dict(q=f'What is the probability of drawing {word} hearts in a row without replacement from a deck of cards?',value=str(Fraction(math.comb(13,k),math.comb(52,k)) if k<=13 else Fraction(0))))
    rows.append(dict(q='What is the probability of at least one minus one in three rolls of a 6-sided die?',value='0'))
    rows.append(dict(q='What is the probability of at least one 1 in 3 rolls of a 1-sided die?',value='1'))
    for face,sides,p in [('twenty one',20,Fraction(0)),('minus twenty one',20,Fraction(0)),('twenty one',30,1-Fraction(29,30)**3)]:
        rows.append(dict(q=f'What is the probability of at least one {face} in three rolls of a {sides}-sided die?',value=str(p),kind='at_least_one'))
    for q in [
        'What is the probability of at least one twenty tenth in three rolls of a 20-sided die?',
        'What is the probability of at least one twenty 1 in three rolls of a 20-sided die?',
        'What is the probability of drawing two aces and three kings from a deck of cards?',
        'What is the probability of drawing two hearts and three hearts from a deck of cards?',
        'What is the probability of not drawing a heart from a deck of cards?',
        'What is the probability of drawing two hearts from a 40-card deck?',
        'What is the probability of drawing several hearts in a row from a deck of cards?',
        'What is the probability of at least one 6 or 5 in 3 rolls of a 6-sided die?',
        'What is the probability of at least one 6 on a die in 3?',
        'What is the probability of drawing an ace of hearts from a deck of cards?',
        'What is the probability of drawing exactly two hearts in five draws from a deck of cards?',
        'What is the probability of drawing 2.5 hearts in a row from a deck of cards?',
        'What is the probability of drawing -2 hearts in a row from a deck of cards?',
        'What is the probability of at least one 1.5 in 3 rolls of a 6-sided die?',
        'What is the probability of at least one 6 in -3 rolls of a 6-sided die?',
        'What is the probability of at least one 6 in 2.5 rolls of a 6-sided die?',
        'What is the probability of at least one 6 in 3 rolls of a 6-sided and a 20-sided die?',
    ]: rows.append(dict(q=q,unsupported=True))
    return rows

def check(it,rep):
    if it.get('unsupported'):
        return rep.get('status')=='withheld' and rep.get('kind')=='unsupported' and rep.get('provenance',{}).get('taken') is True
    m=re.match(r'The probability is (\d+(?:/\d+)?)\b',rep.get('response',''))
    return rep.get('status')=='answered' and m is not None and Fraction(m[1])==Fraction(it['value']) and (not it.get('kind') or rep.get('kind')==it['kind'])

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--binary',default='var/discrete/bin/discrete');ap.add_argument('--seed',default=181109,type=int);ap.add_argument('--out',required=True);args=ap.parse_args()
    items=cases(args.seed)
    p=subprocess.run([args.binary,'--specialist','games-v3'],input=''.join(json.dumps({'id':i,'q':r['q']})+'\n' for i,r in enumerate(items)),capture_output=True,text=True,check=True,timeout=60)
    rows=[dict(case=it,reply=rep,ok=check(it,rep)) for it,rep in zip(items,map(json.loads,p.stdout.splitlines()),strict=True)]
    report=dict(n=len(rows),right=sum(x['ok'] for x in rows),rows=rows)
    Path(args.out).write_text(json.dumps(report,indent=2)+'\n');print(report['right'],report['n'])
    if report['right']!=report['n']:raise SystemExit(1)
if __name__=='__main__':main()
