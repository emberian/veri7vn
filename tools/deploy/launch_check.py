#!/usr/bin/env python3
"""Actual staged public-main reasoning/restart check; run only in steward slot."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('installation',type=Path)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
installation=args.installation.resolve(strict=True)
generation=(installation/'current').resolve(strict=True)
output=args.output.resolve()
output.mkdir(parents=True,exist_ok=True)
state=output/('workspace-'+uuid.uuid4().hex)
state.mkdir()
launcher=Path(__file__).with_name('stage.py').resolve()
records=[]
# EOF closes the actual public main between requests. The second process must
# restore the nonempty native workspace before accepting the second proposal.
for index,(question,expected) in enumerate((
    ('the sum of -2 and 3','<p>The exact sum of -2 and 3 is 1.</p>'),
    ('the product of 6 and 7','<p>The exact product of 6 and 7 is 42.</p>'))):
    command=[sys.executable,str(launcher),'launch',str(installation),'--state',str(state)]
    started=time.monotonic()
    result=subprocess.run(command,input=(question+'\n').encode(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                          cwd=state,timeout=150)
    (output/f'launch-{index}.stdout').write_bytes(result.stdout)
    (output/f'launch-{index}.stderr').write_bytes(result.stderr)
    record=dict(index=index,returncode=result.returncode,seconds=time.monotonic()-started,
                expected_html=expected,passed=result.returncode==0 and expected.encode() in result.stdout and (installation/'current').resolve()==generation)
    records.append(record)
    (output/'result.json').write_text(json.dumps(dict(
        generation=generation.name,state=str(state),checks=records,
        assurance='actual staged public RuntimeMain local math reasoning and nonempty startup restore; broader offline/search/edit/admission acceptance unqualified'),indent=2)+'\n')
    if not record['passed']:
        raise SystemExit('DEPLOYMENT_LAUNCH_FAILED: see '+str(output))
print('DEPLOYMENT_LAUNCH_RESTART_PASS '+str(output))
