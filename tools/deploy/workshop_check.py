#!/usr/bin/env python3
"""Installed bundled tutorial import, two browser saves, and fresh CLI reopen."""
import argparse
import json
from pathlib import Path
import sys
from stage import locate
from workbench_check import run


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('installation',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    generation=(args.installation/'current').resolve(strict=True)
    output=args.output.resolve();output.mkdir(mode=0o700,parents=True,exist_ok=False)
    facade=output/'installation';facade.mkdir();(facade/'current').symlink_to(generation)
    tutorial=locate(facade,'retained-identity')
    state=output/'state';launcher=Path(__file__).with_name('stage.py').resolve()
    command=[sys.executable,str(launcher),'launch','--state',str(state),'--surface','source',str(facade),'--',
        'import-native','identity',str(tutorial),'installed-identity-import']
    result=dict(generation=generation.name,tutorial=str(tutorial),passed=False,
        assurance='installed bundled editable identity source import, two browser saves and fresh CLI source read; no build/admission/native execution or recipient trial')
    try:
        code,stdout,stderr=run(command,output,60)
        (output/'import.stdout').write_bytes(stdout);(output/'import.stderr').write_bytes(stderr)
        if code!=0 or b'Committed' not in stdout:raise RuntimeError('bundled tutorial import did not commit')
        result['import']=dict(returncode=code,passed=True)
        browser=Path(__file__).with_name('source_browser_check.py').resolve()
        code,stdout,stderr=run([sys.executable,str(browser),str(facade),'--state',str(state),
            '--draft','identity','--file','Retained_Identity.thy','--expected-file',str(tutorial/'Retained_Identity.thy'),
            '--save-twice','--output',str(output/'browser')],output,150)
        (output/'browser-driver.stdout').write_bytes(stdout);(output/'browser-driver.stderr').write_bytes(stderr)
        result['browser']=json.loads((output/'browser/result.json').read_text())
        if code!=0 or not result['browser']['passed']:raise RuntimeError('installed two-save source workflow failed')
        result['passed']=True
    except BaseException as error:
        result['error']=str(error);raise
    finally:(output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print('INSTALLED_BUNDLED_IDENTITY_TWO_SAVE_REOPEN_PASS '+str(output))

if __name__=='__main__':main()
