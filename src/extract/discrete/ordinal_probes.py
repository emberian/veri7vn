#!/usr/bin/env python3
"""Untrusted development checks for complete polynomial derivative ordinals.

The author's finite English ordinal table and exact integer arithmetic are
separate from the SML recognizer, but authored in the same lane: these are not
independent heldout language evidence. No upstream files are written.
"""
import argparse, json, math, subprocess
from pathlib import Path

WORDS = ('first second third fourth fifth sixth seventh eighth ninth tenth '
         'eleventh twelfth thirteenth fourteenth fifteenth sixteenth seventeenth '
         'eighteenth nineteenth twentieth').split()
for ten, cardinal, ordinal in [(20,'twenty','thirtieth'),(30,'thirty','fortieth'),(40,'forty','fiftieth')]:
    WORDS.extend(cardinal+'-'+word for word in WORDS[:9])
    WORDS.append(ordinal)
assert len(WORDS)==50

def numeric(n):
    ending='th' if 10 <= n%100 <= 20 else {1:'st',2:'nd',3:'rd'}.get(n%10,'th')
    return str(n)+ending

def cases():
    rows=[]
    def add(word,n):
        rows.append({'q':f'Find the {word} derivative of x^50 at x = 1',
                     'order':n,'value':math.factorial(50)//math.factorial(50-n)})
    for n,word in enumerate(WORDS,1):
        add(word,n);add(numeric(n),n)
        if '-' in word:add(word.replace('-',' '),n)
    for word,n in [('twenty-first order',21),('twenty-first-order',21),
                   ('twenty first partial',21),('first-order',1),('second partial',2)]:
        add(word,n)
    for word in ['-1st','-2nd','+1st','21.5th','1.5th','-21st','0th','51st','100th',
                 '2st','3nd','11st','12nd','13rd','21th','twenty-tenth',
                 'one hundred first','one-hundred-first','minus first','negative first',
                 'minus 1st','- first','2 first','twenty 1st','twenty-firstst','1e3rd',
                 '0x1st','twenty-first-order-order','first order order',
                 '− first','1/2 first','1e2 first','−1 first','.5 first','– first']:
        rows.append({'q':f'Find the {word} derivative of x^2','unsupported':True})
    rows.append({'q':'Find derivative of x^2 at x = 1','order':1,'value':2})
    return rows

def check(it,rep):
    if it.get('unsupported'):
        return rep.get('status')=='withheld' and rep.get('kind')=='unsupported' and (rep.get('provenance') or {}).get('taken') is True
    names={1:'derivative',2:'second derivative',3:'third derivative',4:'fourth derivative'}
    label='The '+names.get(it['order'],f"{it['order']}-th derivative")+' at '
    return rep.get('status')=='answered' and rep.get('value')==it['value'] and rep.get('response','').startswith(label)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--binary',default='var/discrete/bin/discrete')
    ap.add_argument('--out',required=True)
    args=ap.parse_args();items=cases()
    p=subprocess.run([args.binary,'--specialist','calculus'],input=''.join(json.dumps({'id':i,'q':it['q']})+'\n' for i,it in enumerate(items)),capture_output=True,text=True,timeout=30,check=True)
    rows=[dict(case=it,reply=rep,ok=check(it,rep)) for it,rep in zip(items,map(json.loads,p.stdout.splitlines()),strict=True)]
    result=dict(n=len(rows),right=sum(x['ok'] for x in rows),rows=rows)
    Path(args.out).write_text(json.dumps(result,indent=2)+'\n')
    print('ordinal probes',result['right'],'/',result['n'])
    for row in rows:
        if not row['ok']:print('FAIL',row['case']['q'],row['reply'].get('response'))
    if result['right'] != result['n']:
        raise SystemExit(1)
if __name__=='__main__':main()
