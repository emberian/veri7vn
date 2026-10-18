#!/usr/bin/env python3
"""Untrusted authored formats probes, not independent-language evidence.
Expected bytes use Python hashlib/base64/urllib/json and signed integers. The
seed varies payloads and numbers after the fixed adversarial grammar is frozen.
"""
import argparse,base64,hashlib,json,random,subprocess,sys,urllib.parse
from pathlib import Path

def cases(seed=181201):
    rng=random.Random(seed); rows=[]
    payloads=['','\x00','\x01','\b\f','a  b',' a b ','a\tb','a\nb','a\r\nb','é λ','\\n','base64 encode','followed by b','SHA256 hash of x','url decode: %20',"What's this?",'"a" and "b"','a\\"b']
    payloads += [''.join(rng.choice('abXYZ \t\nλé:') for _ in range(rng.randrange(1,25))) for _ in range(12)]
    for s in payloads:
        for alg in ['sha256','sha1','md5']:
            rows.append(dict(q=f'What is the {alg} hash of `{s}`?',kind='hash',value=getattr(hashlib,alg)(s.encode()).hexdigest()))
        enc=base64.b64encode(s.encode()).decode()
        rows.append(dict(q=f'Encode `{s}` in base64',kind='b64_encode',value=enc))
        rows.append(dict(q=f'Base64 decode "{enc}"',kind='b64_decode',value=s))
        rows.append(dict(q=f'URL encode `{s}`',kind='url_encode',value=urllib.parse.quote(s,safe='')))
        rows.append(dict(q=f'URL decode `{urllib.parse.quote(s,safe="")}`',kind='url_decode',value=s))
    for q,s in [('SHA256 hash of "a  b"','a  b'),("What's the SHA256 hash of 'a  b'?",'a  b'),('SHA256 hash of: a  b','a  b'),('Base64 encode ""','')]:
        rows.append(dict(q=q,kind='hash' if 'hash' in q else 'b64_encode',value=hashlib.sha256(s.encode()).hexdigest() if 'hash' in q else ''))
    for s in ['a "b" and "c"','a"unterminated','base64 encode: a  b','a\nb','a\tb']:
        rows.append(dict(q=f'SHA256 hash of: {s}',kind='hash',value=hashlib.sha256(s.encode()).hexdigest()))
    docs=['{"a":"a\nb"}','{"a":"a\tb"}','{"a":"a\rb"}','{"a":"a\\nb"}','{"a":\n 1}', '[1,\t2]','""','"\\u03bb"','"\\n"','true','null','12','{"a":}', '{"a":"base64 encode"}', '{"a":"SHA256 hash"}']
    for doc in docs:
        try:json.loads(doc);valid=True
        except json.JSONDecodeError:valid=False
        for q in [f'Is this valid JSON: {doc}',f'Is this valid JSON `{doc}`?']:
            rows.append(dict(q=q,kind='json_valid' if valid else 'json_invalid',value=valid))
    for n in [-255,-10,-1,0,1,10,255]+[rng.randrange(-1000000,1000000) for _ in range(12)]:
        for base,fmt in [('binary','b'),('octal','o'),('hexadecimal','x')]:
            rows.append(dict(q=f'Convert {n} decimal to {base}',kind='base',value=format(n,fmt)))
    for q,v in [('Convert -0xFF to decimal','-255'),('Convert +10 decimal to binary','1010'),('Convert −10 decimal to binary','-1010'),('What is -ff from hex in decimal?','-255'),('Convert -0 decimal to binary','-0')]:
        rows.append(dict(q=q,kind='base',value=v))
    for q in ['Convert 1.5 decimal to binary','Convert 1.5 to hexadecimal','SHA1 hash of \"a\" and \"b\"','Convert 1/2 decimal to binary','Convert 1e3 decimal to binary','Convert 1,000 decimal to binary','Convert 2 + 3 decimal to binary','Convert 0x10 from binary to decimal','Convert --10 decimal to binary','Convert - 10 decimal to binary','Convert 10 decimal to binary and hexadecimal','Convert abc10 decimal to binary extra','SHA256 hash of "a" and "b"','SHA256 hash and base64 encode "a"','SHA256 and SHA1 hash of "a"','Base64 encode and decode "a"','URL encode and decode "a"','Base64 decode this: "YQ==" extra','Is this valid JSON: `{}` garbage','SHA256 hash of "unterminated','SHA256 hash of "a" followed by b','SHA256 hash of "a" repeated twice','SHA256 hash of reversed "abc"','SHA256 hash of "a" + b','Base64 encode the string a: b','Base64 encode "a" twice','URL encode "a" then reverse','Is this valid JSON `{}` followed by null']:
        ambiguous = q in ['Convert 0x10 from binary to decimal','Convert abc10 decimal to binary extra','Base64 decode this: "YQ==" extra','Is this valid JSON: `{}` garbage','SHA256 hash of "unterminated','Base64 encode the string a: b']
        rows.append(dict(q=q,unsupported=True,semantic='ambiguous' if ambiguous else 'valid'))
    return rows

def check(it,rep):
    if it.get('unsupported'):return rep.get('status')=='withheld' and rep.get('kind')=='unsupported' and rep.get('provenance',{}).get('taken') is True
    value=rep.get('value')
    if it.get('kind')=='base' and isinstance(value,str):value=value.lower()
    return rep.get('status')=='answered' and rep.get('kind')==it['kind'] and value==it['value']

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--binary',default='var/discrete/bin/discrete');ap.add_argument('--seed',default=181201,type=int);ap.add_argument('--out',required=True);ap.add_argument('--dispatch',choices=['pinned','unpinned']);args=ap.parse_args()
    items=cases(args.seed)
    cmd=[args.binary,'--specialist','dataformats']
    if args.dispatch:
        cmd=[sys.executable,'-B','tools/dispatch/dispatch.py','--order','front','--organs','discrete','--no-reader','--no-document','--no-routes']
        if args.dispatch=='pinned':cmd+=['--specialist','dataformats']
    p=subprocess.run(cmd,input=''.join(json.dumps({'id':i,'q':r['q'],'session':f'formats-{i}'})+'\n' for i,r in enumerate(items)),capture_output=True,text=True,check=True,timeout=60)
    rows=[dict(case=it,reply=rep,ok=check(it,rep)) for it,rep in zip(items,map(json.loads,p.stdout.splitlines()),strict=True)]
    if args.dispatch:
        for row in rows:
            if row['case'].get('unsupported'):row['ok'] &= row['reply'].get('provenance',{}).get('dispatch',{}).get('decisive') is True
    valid=[r for r in rows if r['case'].get('semantic','valid')=='valid']
    ambiguous=[r for r in rows if r not in valid]
    answered=lambda r:r['reply'].get('status')=='answered'
    outcomes=dict(valid_requests=len(valid),answered_correct=sum(answered(r) and r['ok'] for r in valid),answered_wrong=sum(answered(r) and not r['ok'] for r in valid),withheld_valid=sum(not answered(r) for r in valid),ambiguous_requests=len(ambiguous),ambiguous_answered=sum(answered(r) for r in ambiguous),ambiguous_withheld=sum(not answered(r) for r in ambiguous))
    report=dict(command=cmd,seed=args.seed,n=len(rows),assertions_passed=sum(r['ok'] for r in rows),outcomes=outcomes,rows=rows)
    Path(args.out).write_text(json.dumps(report,indent=2)+'\n');print(report['assertions_passed'],report['n'],outcomes)
    if report['assertions_passed']!=report['n']:raise SystemExit(1)
if __name__=='__main__':main()
