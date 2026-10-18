#!/usr/bin/env python3
"""Run the actual JSONL producer and independently replay its checked packets."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from answerer import ROOT
sys.path.insert(0,str(ROOT/'tools'))
from code_evidence import validate_code

probes=json.loads((Path(__file__).parent/'probes.json').read_text())
frontdoor=ROOT/'src/extract/codeorgan/answerer.py'
kernel=ROOT/'var/codeorgan/bin/codeorgan-kernel'
command=[sys.executable,str(frontdoor),'--kernel',str(kernel)]
p=subprocess.run(command,input=''.join(json.dumps({'id':x['id'],'q':x['q']})+'\n' for x in probes),
                 capture_output=True,text=True,timeout=20,check=True)
replies=[json.loads(x) for x in p.stdout.splitlines()]
assert len(replies)==len(probes)
count=0
for item,r in zip(probes,replies):
    assert r['id']==item['id'] and r['status']==item['status'],(item,r)
    if r['status']=='answered':
        checked=validate_code(r,r['provenance']['evidence']['checked_computation'])
        assert checked['status']=='consistent';count+=1
assert not (ROOT/'var/codeorgan-sol/INJECTED').exists()
result={'command':command,'requests':len(probes),'answers_replayed':count,'refusals':len(probes)-count,
    'exit_code':p.returncode,'all_ids_match':True,'injection_file_absent':True,
    'frontdoor_sha256':hashlib.sha256(frontdoor.read_bytes()).hexdigest(),
    'kernel_sha256':hashlib.sha256(kernel.read_bytes()).hexdigest(),
    'consumer_sha256':hashlib.sha256((ROOT/'tools/code_evidence.py').read_bytes()).hexdigest(),
    'replies':replies}
(ROOT/'var/codeorgan-sol/consumer.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='replies'},indent=2))
