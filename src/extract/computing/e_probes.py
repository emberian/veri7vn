#!/usr/bin/env python3
"""Untrusted E permission-mode probes: independent stat masks, scoped live binary.
Authored by the implementing deputy. Fixed templates plus seeded finite modes;
no independent natural-language audit and no effective-access proof.
"""
import argparse,hashlib,json,random,stat,subprocess,sys
from pathlib import Path
sys.dont_write_bytecode=True
ACTIONS=('read','write','execute')
MASKS=((stat.S_IRUSR,stat.S_IWUSR,stat.S_IXUSR),(stat.S_IRGRP,stat.S_IWGRP,stat.S_IXGRP),(stat.S_IROTH,stat.S_IWOTH,stat.S_IXOTH))
CLASSES=('owner','group','others')

def expected(mode,who):
    m=int(mode,8)
    rows={c:[a for a,b in zip(ACTIONS,masks) if not m&b] for c,masks in zip(CLASSES,MASKS) if who is None or c==who}
    return ['Unset permission bits in mode',*['%s: %s'%(c,', '.join(acts) or 'none') for c,acts in rows.items()]]

def cases(seed):
    rng=random.Random(seed)
    fixed=[('775',None),('640',None),('4755',None),('000',None),('777',None),('4755','group'),('0640','owner'),('2770','others')]
    modes=fixed+[(format(rng.randrange(0o10000),'04o'),rng.choice((None,*CLASSES))) for _ in range(32)]
    for i,(mode,who) in enumerate(modes):
        subject='' if who is None else who+' '
        q=[f'For mode {mode}, what {subject}permissions are denied?',f'Which {subject}permission bits are unset in mode {mode}?',f'For mode {mode}, what {subject}permissions are not granted?',f'Which {subject}permissions are missing in mode {mode}?'][i%4]
        yield dict(q=q,valid=True,status='answered',kind='chmod_unset',contains=expected(mode,who))
    for mode in ('889','8888','798'):
        yield dict(q=f'Which permission bits are unset in mode {mode}?',valid=False,status='withheld',kind='impossible',contains=['0-7'])
    for q in ('For mode 640 with an ACL, what permissions are denied?', 'For mode 640, what effective permissions are denied?', 'For mode 640, what permissions are denied to a root user?'):
        yield dict(q=q,valid=None,status='withheld',kind='underspecified',contains=['Mode bits alone do not determine effective access'])
    for q in ('Which permission bits are unset in mode 640 and mode 775?', 'For mode 640, what permissions are denied and how do I change the owner?'):
        yield dict(q=q,valid=True,status='withheld',kind='underspecified',contains=['Ask about one mode'])
    # Positive polarity must not become complement merely because 'denied' occurs.
    yield dict(q='For mode 775, what permissions are not denied?',valid=True,status='answered',kind='chmod_symbolic',contains=['rwxrwxr-x'])
    yield dict(q='For mode 775, what permissions aren’t denied?',valid=True,status='answered',kind='chmod_symbolic',contains=['rwxrwxr-x'])


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--binary',default='var/computing/bin/computing');ap.add_argument('--seed',type=int,default=802311);ap.add_argument('--out',required=True);ap.add_argument('--dispatch',action='store_true');args=ap.parse_args()
    cmd=[sys.executable,'-B','tools/dispatch/dispatch.py','--organs','computing','--specialist','linux-v2','--no-reader','--no-document','--no-routes','--order','front'] if args.dispatch else [args.binary,'--specialist','linux-v2']
    proc=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
    rows=[];counts=dict(correct=0,wrong=0,withheld_valid=0,false_yes=0,invalid_withheld=0,underspecified_withheld=0,underspecified_asserted=0)
    try:
        for c in cases(args.seed):
            proc.stdin.write(json.dumps({'id':str(len(rows)),'q':c['q']})+'\n');proc.stdin.flush();r=json.loads(proc.stdout.readline())
            errors=[]
            if r.get('status')!=c['status']:errors.append('status')
            if r.get('kind')!=c['kind']:errors.append('kind')
            if not r.get('provenance',{}).get('taken'):errors.append('not taken')
            if any(s not in r.get('response','') for s in c['contains']):errors.append('response')
            if args.dispatch and not r.get('provenance',{}).get('dispatch',{}).get('decisive'):errors.append('not decisive')
            asserted=r.get('status')=='answered'
            if c['valid'] is True:counts['withheld_valid' if not asserted else 'wrong' if errors else 'correct']+=1
            elif c['valid'] is False:counts['false_yes' if asserted else 'invalid_withheld']+=1
            else:counts['underspecified_asserted' if asserted else 'underspecified_withheld']+=1
            rows.append(dict(case=c,reply=r,errors=errors))
    finally:proc.stdin.close();proc.wait()
    report=dict(binary_sha256=hashlib.sha256(Path(args.binary).read_bytes()).hexdigest(),seed=args.seed,n=len(rows),policy_pass=sum(not r['errors'] for r in rows),capability=counts,results=rows)
    Path(args.out).write_text(json.dumps(report,indent=2)+'\n');print({k:v for k,v in report.items() if k!='results'})
    for row in rows:
        if row['errors']:print(row)
    return int(report['policy_pass']!=report['n'])

if __name__=='__main__':raise SystemExit(main())
