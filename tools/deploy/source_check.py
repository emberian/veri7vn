#!/usr/bin/env python3
"""Actual packaged source import/edit/reopen test; starts no native authority."""
import argparse
import json
from pathlib import Path
import re
import sys
from workbench_check import run


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('installation',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    generation=(args.installation/'current').resolve(strict=True)
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=False)
    facade=output/'installation';facade.mkdir();(facade/'current').symlink_to(generation)
    source=output/'fixture';source.mkdir()
    original=b'# retained original specialist source\nclass Specialist:\n    value = 7\n'
    replacement=b'# retained revised specialist source\nclass Specialist:\n    value = 8\n'
    (source/'specialist.py').write_bytes(original)
    (source/'manifest.json').write_text(json.dumps(dict(id='packaged-source-fixture',name='Inert packaged source edit fixture',sources=[],
        organ=dict(module='specialist',**{'class':'Specialist'},init={})))+'\n')
    expected=output/'expected';expected.write_bytes(original)
    proposed=output/'replacement';proposed.write_bytes(replacement)
    base=[sys.executable,str(Path(__file__).with_name('stage.py').resolve()),'launch',
          '--state',str(output/'state'),'--surface','source',str(facade),'--']
    checks=[]
    def save():
        (output/'result.json').write_text(json.dumps(dict(generation=generation.name,checks=checks,
          passed=len(checks)==4 and all(check['passed'] for check in checks),
          assurance='actual installed native-free shared source CLI import/edit/reopen; no native admission or browser qualification'),indent=2)+'\n')
    def command(label,tail,contains=None,exact=None):
        try:
            code,stdout,stderr=run(base+tail,output,60)
        except Exception as error:
            checks.append(dict(label=label,passed=False,error=str(error)))
            save();raise
        (output/(label+'.stdout')).write_bytes(stdout);(output/(label+'.stderr')).write_bytes(stderr)
        passed=code==0 and (contains is None or contains in stdout) and (exact is None or stdout==exact)
        checks.append(dict(label=label,returncode=code,passed=passed))
        save()
        if not passed:raise RuntimeError('packaged source check failed: '+label)
        return stdout
    command('import',['import-original','packaged-source',str(source),'source-check-import'])
    description=command('inspect',['inspect','packaged-source'],b'specialist.py')
    revision=re.search(rb'^Source revision (\S+)$',description,re.M)
    manifest=re.search(rb'^Edit token (\S+)$',description,re.M)
    if not revision or not manifest:raise RuntimeError('missing captured source revision/edit token')
    command('edit',['edit','packaged-source',manifest.group(1).decode(),revision.group(1).decode(),
          'specialist.py','0',str(len(original)),str(expected),str(proposed),'source-check-edit'])
    command('reopened-source',['source','packaged-source','specialist.py'],exact=replacement)
    print('INSTALLED_SOURCE_IMPORT_EDIT_REOPEN_PASS '+str(output))

if __name__=='__main__':main()
