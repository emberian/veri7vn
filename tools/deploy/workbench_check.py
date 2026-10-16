#!/usr/bin/env python3
"""Actual installed workbench CLI/restart test; exclusive steward slot required."""
import argparse
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time


def run(command, directory, timeout):
    process=subprocess.Popen(command,cwd=directory,stdin=subprocess.DEVNULL,
                             stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
    try:
        stdout,stderr=process.communicate(timeout=timeout)
        return process.returncode,stdout,stderr
    except subprocess.TimeoutExpired:
        os.killpg(process.pid,signal.SIGTERM)
        try: process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid,signal.SIGKILL)
            process.communicate(timeout=5)
        raise


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('installation',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--steward-slot',required=True)
    args=parser.parse_args()
    generation=(args.installation/'current').resolve(strict=True)
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=False)
    # Pin a facade once; an installer may subsequently select another generation.
    facade=output/'installation';facade.mkdir();(facade/'current').symlink_to(generation)
    state=output/'state'
    launcher=Path(__file__).with_name('stage.py').resolve()
    base=[sys.executable,str(launcher),'launch','--state',str(state),'--surface','workbench',str(facade),'--']
    checks=[]
    def observe(tail,label,expected):
        started=time.monotonic()
        code,stdout,stderr=run(base+tail,output,150)
        (output/(label+'.stdout')).write_bytes(stdout)
        (output/(label+'.stderr')).write_bytes(stderr)
        passed=code==0 and expected in stdout
        checks.append(dict(label=label,returncode=code,passed=passed,seconds=time.monotonic()-started))
        (output/'result.json').write_text(json.dumps(dict(generation=generation.name,steward_slot=args.steward_slot,checks=checks,
            assurance='actual installed workbench CLI native result and restart inspection; browser, search, edit/admission and Linux acceptance separate'),indent=2)+'\n')
        if not passed: raise RuntimeError('installed workbench check failed: '+label)
        return stdout
    stdout=observe(['run','the sum of -2 and 3'],'run',b'<p>The exact sum of -2 and 3 is 1.</p>')
    request=re.search(rb'^Request (\d+)\s*$',stdout,re.M)
    if request is None: raise RuntimeError('missing actual retained request ID')
    observe(['result',request.group(1).decode()],'restored-result',b'<p>The exact sum of -2 and 3 is 1.</p>')
    print('INSTALLED_WORKBENCH_CLI_RESTART_PASS '+str(output))

if __name__=='__main__':main()
