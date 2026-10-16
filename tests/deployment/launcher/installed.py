#!/usr/bin/env python3
"""Actual installed shell source/native restart qualification; sole steward only."""
import argparse
import json
import os
from pathlib import Path
import re
import signal
import shlex
import subprocess
import time


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('installation',type=Path)
    p.add_argument('--output',required=True,type=Path)
    p.add_argument('--steward-slot',required=True)
    a=p.parse_args()
    generation=(a.installation/'current').resolve(strict=True)
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    state=out/'state';state.mkdir()
    marker=out/'settings-executed'
    identifier=(generation/'runtime/etc/ISABELLE_IDENTIFIER').read_text().strip()
    settings=state/'user-home/.isabelle'/identifier/'etc/settings'
    settings.parent.mkdir(parents=True)
    settings.write_text('echo forbidden > '+shlex.quote(str(marker))+'\n')
    fixture=out/'original';fixture.mkdir()
    original=b'# retained source\nclass Specialist:\n    value = 7\n'
    (fixture/'specialist.py').write_bytes(original)
    (fixture/'manifest.json').write_text(json.dumps(dict(id='launcher-installed',name='Launcher source fixture',sources=[],organ=dict(module='specialist',**{'class':'Specialist'},init={})))+'\n')
    shell=generation/'bin/veri7vn'
    env=dict(os.environ,USER='spoofed-user',LOGNAME='spoofed-logname',JAVA_TOOL_OPTIONS='--veri7vn-invalid-startup-option',BASH_ENV=str(settings))
    checks=[]
    def run(label,surface,tail,expected=None):
        start=time.monotonic()
        proc=subprocess.Popen([str(shell),'launch','--state',str(state),'--surface',surface,'--',*tail],cwd=out,env=env,
          stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
        try: stdout,stderr=proc.communicate(timeout=180)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid,signal.SIGTERM)
            try: proc.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid,signal.SIGKILL);proc.communicate(timeout=5)
            raise
        (out/(label+'.stdout')).write_bytes(stdout);(out/(label+'.stderr')).write_bytes(stderr)
        passed=proc.returncode==0 and not marker.exists() and (expected is None or expected in stdout)
        checks.append(dict(label=label,returncode=proc.returncode,passed=passed,seconds=time.monotonic()-start))
        (out/'result.json').write_text(json.dumps(dict(generation=generation.name,steward_slot=a.steward_slot,checks=checks,
          assurance='actual standalone shell source import/reopen and native result/restart; no full product acceptance'),indent=2)+'\n')
        if not passed: raise RuntimeError('installed launcher failed: '+label)
        return stdout
    run('source-import','source',['import-original','launcher-source',str(fixture),'launcher-source-import'])
    assert run('source-reopen','source',['source','launcher-source','specialist.py'])==original
    native=run('native-run','workbench',['run','the sum of -2 and 3'],b'<p>The exact sum of -2 and 3 is 1.</p>')
    request=re.search(rb'^Request (\d+)\s*$',native,re.M)
    if request is None: raise RuntimeError('missing native retained request')
    run('native-restart','workbench',['result',request.group(1).decode()],b'<p>The exact sum of -2 and 3 is 1.</p>')
    print('INSTALLED_STANDALONE_LAUNCHER_PASS '+str(out))

if __name__=='__main__': main()
