#!/usr/bin/env python3
"""Read-only bounded comparison with Oracle7's code chat organ.
The upstream organ executes only its own library templates; request source is
never executed. No head/fleet or shipped-specialist panel result is inferred.
"""
import argparse
import hashlib
import json
import sys
import time
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'upstream/root/wander-train'))
from organ_code_chat_v2 import CodeChat

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=ROOT/'var/codeorgan-sol/upstream-comparison.json');args=p.parse_args()
    probes=json.loads((Path(__file__).parent/'probes.json').read_text())
    selected=[r for r in probes if r['valid']]
    rows=[]
    for item in selected:
        chat=CodeChat();chat.persist=False
        t=time.monotonic()
        try:
            r=chat.answer(item['q'])
            rows.append({'id':item['id'],'new_expected_status':item['status'],
                'upstream_program':r is not None,'upstream_confident':r.get('confident') if r else None,
                'upstream_passed':r.get('passed') if r else None,'upstream_source':r.get('program') if r else None,
                'elapsed_seconds':time.monotonic()-t})
        except Exception as e:
            rows.append({'id':item['id'],'upstream_error':str(e),'elapsed_seconds':time.monotonic()-t})
    result={'scope':f'{len(selected)} authored valid requests, isolated CodeChat instance per request; no shipped code specialist panel exists',
      'source_hashes':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in
        [ROOT/'upstream/root/wander-train/organ_code_chat_v2.py',ROOT/'upstream/root/wander-train/code_organ_v3.py']},
      'total':len(rows),'upstream_programs':sum(r.get('upstream_program',False) for r in rows),
      'upstream_confident_programs':sum(bool(r.get('upstream_confident')) for r in rows),
      'new_supported':sum(r['status']=='answered' for r in selected),
      'new_withheld_valid':sum(r['status']=='withheld' for r in selected),'rows':rows}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in {'rows','source_hashes'}},indent=2))
if __name__=='__main__':main()
