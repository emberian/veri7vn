#!/usr/bin/env python3
"""UNTRUSTED finite conversation checks against the real composed dispatcher.

Cases are authored to refute context/state boundaries, not a specialist panel
or the historical237-turn conversation score. No full-head run is performed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

REPO=Path(__file__).resolve().parents[2]


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--var-root',type=Path,default=REPO/'var')
    ap.add_argument('--relations',action='store_true')
    ap.add_argument('--powers',action='store_true')
    ap.add_argument('--out',type=Path,default=REPO/'var/converse/composed.json')
    args=ap.parse_args()
    cases=[
        ('energy','How much energy in kWh does a 2 kW heater use for 3 hours?','answered','6 kwh'),
        ('energy','What does that cost at $0.20 per kWh?','answered','$1.20'),
        ('energy','What was the last fact you told me?','answered','I said: The answer is $1.20'),
        ('energy','Tell me something obscure.','withheld',''),
        ('energy','What does that cost at $0.20 per kWh?','clarify','Please name'),
        ('convert','How much energy in kWh does a 2 kW heater use for 3 hours?','answered','6 kwh'),
        ('convert','Convert that to kJ.','answered','21600 kJ'),
        ('new','Where was he born?','clarify','Please name'),
        ('new','What was my first question?','answered','Where was he born?'),
        ('invalid','What is the square root of 9.5?','withheld','whole-number'),
        ('algebra','Solve 2x + 3 = 13.','answered','x = 5.'),
    ]
    if args.powers:
        cases += [('algebra','What is x squared?','answered','25'),
                  ('negative','Solve 2x + 3 = 0.','answered','x = -3/2.'),
                  ('negative','What is x squared?','answered','9/4')]
    if args.relations:
        cases += [('person','Where was Christiaan Huygens born?','answered','The Hague'),
                  ('person','Where was he born?','answered','The Hague'),
                  ('person','And Isaac Newton?','answered','Woolsthorpe'),
                  ('countries','What is the capital of Austria?','answered','Vienna'),
                  ('countries','And France?','answered','Paris'),
                  ('missingfact','Who wrote Leaves of Grass?','answered','Walt Whitman'),
                  ('missingfact','Where was he born?','withheld',''),
                  ('ambiguity',"Who is Ada Lovelace's father?",'answered','Lord Byron'),
                  ('ambiguity','Where was he born?','clarify','Please name'),
                  ('unknown_type',"Who is Isaac Newton's father?",'answered','Isaac Newton Sr.'),
                  ('unknown_type','Where was he born?','clarify','Please name'),
                  ('thing','What is the capital of Austria?','answered','Vienna'),
                  ('thing','What is its capital?','answered','Vienna'),
                  ('book','Who wrote Leaves of Grass?','answered','Walt Whitman'),
                  ('book','Who wrote it?','answered','Walt Whitman'),
                  ('book','What did you say about Walt Whitman?','answered','I said:'),
                  ('book','Where was he born?','withheld',''),
                  ('literal','Who wrote It?','withheld',''),
                  ('literal','Who wrote "It"?','withheld',''),
                  ('empty','Who wrote it?','clarify','Please name'),
                  ('incidental','When was the United Nations headquarters renovated after it was founded?','withheld','')]
    argv=[sys.executable,'-B',str(REPO/'tools/dispatch/dispatch.py'),'--order','front','--organs','chemistry,quantity','--no-document','--var-root',str(args.var_root)]
    if not args.relations:argv+=['--no-reader']
    files=['tools/dispatch/dispatch.py','tools/dialogue/state.py','src/extract/families.json',
           'var/converse/bin/converse','var/quantity/bin/quantity','var/fusion/bin/fusion','var/mathorgan/bin/mathorgan','var/guards/bin/guards']
    if args.relations:files += ['tools/relations/frontdoor.py','tools/relations/answerer.py','var/relations/bin/decide']
    files=[str(args.var_root/Path(f).relative_to('var')) if f.startswith('var/') else str(REPO/f) for f in files]
    hashes={f:hashlib.sha256(Path(f).read_bytes()).hexdigest() for f in files}
    p=subprocess.Popen(argv,stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
    rows=[]
    try:
        for i,(session,q,status,contains) in enumerate(cases):
            request={'id':i,'session':session,'q':q}
            if session=='new' and i==7:
                # Incoming structured claims are deliberately outside the public
                # frontdoor protocol and must not establish dialogue context.
                request['bound_query_entity']={'qid':'Q935','surface':'he'}
                request['provenance']={'conversation':{'query_entity':{'qid':'Q935','label':'Isaac Newton','entity_kind':'person'}}}
            p.stdin.write(json.dumps(request)+'\n');p.stdin.flush()
            reply=json.loads(p.stdout.readline())
            ok=reply.get('status')==status and contains.lower() in reply.get('response','').lower() and 'error' not in reply
            detail=reply.get('provenance',{}).get('dialogue',{})
            ok=ok and detail.get('rewrites_evaluated',2)<=1
            ok=ok and len(detail.get('evaluations',[]))<=1
            if session=='literal':ok=ok and detail.get('rewrites_evaluated')==0
            rows.append({'request':request,'reply':reply,'expected_status':status,'contains':contains,'pass':ok})
    finally:
        p.stdin.close();p.wait(timeout=10);p.stdout.close()
    stable=hashes=={f:hashlib.sha256(Path(f).read_bytes()).hexdigest() for f in files}
    report={'hashes':hashes,'stable':stable,'cases':rows,'passed':sum(r['pass'] for r in rows),'total':len(rows),
            'boundary':__doc__.strip()}
    args.out.write_text(json.dumps(report,indent=2)+'\n')
    print(str(report['passed'])+'/'+str(report['total']))
    for row in rows:
        if not row['pass']:print('FAIL',row['request']['q'],row['reply'].get('path'),row['reply'].get('response'))
    raise SystemExit(0 if stable and all(r['pass'] for r in rows) else 1)

if __name__=='__main__':main()
