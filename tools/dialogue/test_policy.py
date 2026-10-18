#!/usr/bin/env python3
"""Focused actual extracted-policy checks, not a specialist or dialogue panel."""
import argparse
import json
import subprocess
from pathlib import Path


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--binary',default='var/converse/bin/converse')
    ap.add_argument('--out')
    args=ap.parse_args()
    person={'qid':'Q1','entity_kind':'person'}
    other={'qid':'Q2','entity_kind':'person'}
    thing={'qid':'Q3','entity_kind':'thing'}
    unknown={'qid':'Q4','entity_kind':'unknown'}
    cases=[]
    def resolve(ref,q,a,n,v,want):
        cases.append(({'op':'resolve','reference':ref,'query':q,'answer':a,'number':n,'variable':v},'resolution',want))
    resolve('person',person,None,False,False,'query')
    resolve('person',None,person,False,False,'answer')
    resolve('person',person,other,False,False,'ambiguous')
    resolve('person',person,person,False,False,'query')
    resolve('person',thing,person,False,False,'answer')
    resolve('person',unknown,None,False,False,'missing')
    resolve('person',person,unknown,False,False,'ambiguous')
    resolve('person',unknown,person,False,False,'ambiguous')
    resolve('thing',thing,person,False,False,'query')
    resolve('thing',None,thing,False,False,'answer')
    resolve('thing',person,unknown,False,False,'missing')
    resolve('thing',unknown,thing,False,False,'ambiguous')
    resolve('answer_thing',thing,None,False,False,'missing')
    resolve('answer_thing',person,thing,False,False,'answer')
    resolve('subject',unknown,person,False,False,'query')
    resolve('subject',None,person,False,False,'missing')
    for ref in ('number','variable'):
        for available in (False,True):
            resolve(ref,None,None,available,available,ref if available else 'missing')
    for raw in ('answered','refused','failed','unrecognized'):
        for candidate in (None,'answered','refused','failed','unrecognized'):
            cases.append(({'op':'select','raw':raw,'candidate':candidate},'selection',
                          'rewritten' if raw=='unrecognized' and candidate not in (None,'unrecognized') else 'original'))
    for complete in (False,True):
        for q,a,want in ((person,None,'context'),(person,other,'clarify'),
                         (None,None,'clarify'),(unknown,person,'clarify')):
            cases.append(({'op':'interpret','complete':complete,'reference':'person',
                           'query':q,'answer':a,'number':False,'variable':False},
                          'interpretation',want if complete else 'raw'))
    p=subprocess.Popen([args.binary],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
    rows=[]
    try:
        for i,(request,key,want) in enumerate(cases):
            p.stdin.write(json.dumps({'id':i,**request})+'\n');p.stdin.flush()
            got=json.loads(p.stdout.readline())
            rows.append({'request':request,'reply':got,'expected':want,'pass':got.get(key)==want})
    finally:
        p.stdin.close();p.wait(timeout=10);p.stdout.close()
    import hashlib
    report={'binary':args.binary,'binary_sha256':hashlib.sha256(Path(args.binary).read_bytes()).hexdigest(),
            'checks':rows,'passed':sum(x['pass'] for x in rows),'total':len(rows),
            'boundary':'Actual finite policy protocol cases; not English or specialist-panel coverage.'}
    if args.out:Path(args.out).write_text(json.dumps(report,indent=2)+'\n')
    print(str(report['passed'])+'/'+str(report['total']))
    raise SystemExit(0 if all(x['pass'] for x in rows) else 1)

if __name__=='__main__':main()
