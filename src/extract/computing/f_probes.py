#!/usr/bin/env python3
"""Untrusted authored Python batch probes with independent field expectations.
Gold jobs are supplied explicitly, never parsed by the tested recognizer. Values
come from the original partial reference plus separately sourced extensions;
this checks correspondence to reference data, not Python execution semantics.
"""
import argparse,hashlib,json,random,subprocess,sys
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
TABLE=json.loads((ROOT/'upstream/root/specialists/python/pyref_v1.json').read_text())['entries']
TABLE.update(json.loads(Path(__file__).with_name('pyref_extensions.json').read_text())['entries'])


def cases(seed):
    fixed=[
      ('Explain what os.remove and math.sqrt do in Python.',[('doc','os.remove'),('doc','math.sqrt')]),
      ('What is the signature of len and os.remove in Python?',[('signature','len'),('signature','os.remove')]),
      ('What is the signature of len and the module of os.remove in Python?',[('signature','len'),('module','os.remove')]),
      ('Describe os.remove and os.mkdir in Python.',[('doc','os.remove'),('doc','os.mkdir')]),
      ('Describe os.mkdir and os.remove in Python.',[('doc','os.mkdir'),('doc','os.remove')]),
      ('Which module contains math.sqrt and os.remove in Python?',[('module','math.sqrt'),('module','os.remove')]),
      ('What are the signatures of len() and os.remove() in Python?',[('signature','len'),('signature','os.remove')]),
      ('Describe `os.remove`, `math.sqrt`, and `len` in Python.',[('doc','os.remove'),('doc','math.sqrt'),('doc','len')]),
      ('In Python, give the signature of len and the module of os.remove.',[('signature','len'),('module','os.remove')]),
      ('Python: give the signature of len; describe os.remove.',[('signature','len'),('doc','os.remove')]),
      ('What is the signature of len and sys.set_asyncgen_hooks in Python?',[('signature','len'),('signature','sys.set_asyncgen_hooks')]),
      ('Describe zzzz_unknown and len in Python.',[('doc','zzzz_unknown'),('doc','len')]),
      ('Describe split and len in Python.',[('doc','split'),('doc','len')]),
      ('What is the signature of len and len in Python?',[('signature','len'),('signature','len')]),
      ('What is the signature of os.remove and the module of os.remove in Python?',[('signature','os.remove'),('module','os.remove')]),
      ('Give modules of math.sqrt and os.remove in Python.',[('module','math.sqrt'),('module','os.remove')]),
      ('Describe os.remove and write a recursive function in Python.',None),
      ('What is the signature of len and whether it is thread safe in Python?',None),
    ]
    rng=random.Random(seed)
    names=['len','divmod','ord','math.sqrt','os.remove','str.upper','str.lower','list.append','dict.get']
    for _ in range(12):
        a,b=rng.sample(names,2);ra,rb=rng.choices(['signature','module','doc'],k=2)
        def clause(role,name):return {'signature':f'the signature of {name}','module':f'the module of {name}','doc':f'the description of {name}'}[role]
        fixed.append((f'Give {clause(ra,a)} and {clause(rb,b)} in Python.',[(ra,a),(rb,b)]))
    for sid in ('python','python-r2'):
        for q,jobs in fixed:yield dict(specialist=sid,q=q,jobs=jobs)


def job_expectation(role,name):
    row=TABLE.get(name)
    if row:
        value=row[role]
        return bool(value or role!='signature'), value
    if name=='split':return False,'Several standard-library names match:'
    if '.' in name:return False,'reference has no entry for '+name
    return False,'reference cannot resolve '+name


def check(c,r):
    errors=[]
    if not r.get('provenance',{}).get('taken'):errors.append('not taken')
    if c['jobs'] is None:
        if r.get('status')!='withheld' or r.get('kind')!='reference_scope':errors.append('scope')
        return errors,False
    expects=[job_expectation(*j) for j in c['jobs']]
    complete=all(ok for ok,_ in expects)
    if r.get('status')!=('answered' if complete else 'withheld'):errors.append('complete status')
    if r.get('kind')!=('reference_batch' if complete else 'reference_incomplete'):errors.append('kind')
    chunks=r.get('response','').split(' | ')
    if len(chunks)!=len(c['jobs']):errors.append('job count')
    for i,((role,name),(covered,value)) in enumerate(zip(c['jobs'],expects)):
        if i>=len(chunks):continue
        text=chunks[i]
        label=('description' if role=='doc' else role)+' '+name+': '
        if label not in text:errors.append('job role/name/order '+str(i))
        if not covered and name in TABLE and role=='signature':
            value='reference has no recorded signature for '+name
        if value not in text:errors.append('job field '+str(i))
        if covered and role=='module' and ('the '+value+' module') not in text:errors.append('module value '+str(i))
    return errors,complete


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--binary',default='var/computing/bin/computing');ap.add_argument('--seed',type=int,default=821533);ap.add_argument('--out',required=True);ap.add_argument('--dispatch',action='store_true',help='Use actual dispatcher restricted to computing, with other front-stage roles disabled');args=ap.parse_args()
    rows=[];procs={};counts=dict(correct=0,wrong=0,valid_withheld=0)
    try:
        for c in cases(args.seed):
            sid=c['specialist']
            if sid not in procs:
                cmd=[sys.executable,'-B','tools/dispatch/dispatch.py','--organs','computing','--specialist',sid,'--no-reader','--no-document','--no-code','--no-routes','--order','front'] if args.dispatch else [args.binary,'--specialist',sid]
                procs[sid]=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
            p=procs[sid];p.stdin.write(json.dumps({'id':str(len(rows)),'q':c['q']})+'\n');p.stdin.flush();r=json.loads(p.stdout.readline())
            errors,covered=check(c,r)
            if args.dispatch and not r.get('provenance',{}).get('dispatch',{}).get('decisive'):errors.append('not decisive')
            # Every request in this suite is meaningful; missing coverage is a
            # valid withheld request, never counted as an answered capability.
            counts['valid_withheld' if r.get('status')!='answered' else 'wrong' if errors else 'correct']+=1
            rows.append(dict(case=c,reply=r,errors=errors,reference_covered=covered))
    finally:
        for p in procs.values():p.stdin.close();p.wait()
    result=dict(binary_sha256=hashlib.sha256(Path(args.binary).read_bytes()).hexdigest(),seed=args.seed,n=len(rows),policy_pass=sum(not r['errors'] for r in rows),capability=counts,results=rows)
    Path(args.out).parent.mkdir(parents=True,exist_ok=True);Path(args.out).write_text(json.dumps(result,indent=2)+'\n');print({k:v for k,v in result.items() if k!='results'})
    for r in rows:
        if r['errors']:print(r)
    return int(result['policy_pass']!=result['n'])

if __name__=='__main__':raise SystemExit(main())
