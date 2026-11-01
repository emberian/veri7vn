#!/usr/bin/env python3
"""Derive a NEW exact U8 prepared source view; never modifies the baseline.

Copies all declared non-store files, shares only declared immutable store files
through symlinks, applies the pinned source patch, and inventories actual bytes
into a fresh APPLIANCE receipt. Stores must remain under read-only custody.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]
sys.path.insert(0,str(REPO/'tools/appliance'))
from package_native import publish_directory


def digest(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda:f.read(1048576),b''):h.update(b)
    return h.hexdigest()


def safe(name):
    p=PurePosixPath(name)
    if not isinstance(name,str) or not name or p.is_absolute() or '..' in p.parts or p.as_posix()!=name:
        raise ValueError('invalid materialization inventory path')
    return p


def derive(baseline,expected,output):
    baseline=Path(baseline).resolve();output=Path(output).absolute()
    if '..' in output.parts or output.exists() or not output.parent.is_dir() or baseline in output.parents or output in baseline.parents or any(p.is_symlink() for p in (output,*output.parents)):
        raise ValueError('new disjoint output under existing nonsymlink parent required')
    pins=json.loads((HERE/'pins.json').read_text())
    raw=(baseline/'APPLIANCE.json').read_bytes()
    if expected!=pins['base_appliance_sha256'] or hashlib.sha256(raw).hexdigest()!=expected:
        raise ValueError('baseline materialization must match exact admitted U8 pin')
    old=json.loads(raw);files=old['files'];stores={r['path'] for r in old['stores']}
    if set(p.relative_to(baseline).as_posix() for p in baseline.rglob('*') if p.is_file() or p.is_symlink()) != set(files)|{'APPLIANCE.json'}:
        raise ValueError('baseline contains missing/unlisted files')
    patch=HERE/'prepared-serving.patch'
    if digest(patch)!=pins['patch_sha256']:
        raise ValueError('source patch digest mismatch')
    for rel,expected_file in pins['source_files_sha256'].items():
        if digest(baseline/rel)!=expected_file:raise ValueError('baseline source pin mismatch: '+rel)
    with tempfile.TemporaryDirectory(prefix='.prepared-u8-',dir=output.parent) as tmp:
        stage=Path(tmp)/'source';stage.mkdir()
        for name,row in files.items():
            safe(name);src=baseline/name;dest=stage/name;dest.parent.mkdir(parents=True,exist_ok=True)
            if src.is_symlink() and name not in stores:raise ValueError('non-store baseline symlink refused')
            if not src.is_file() or src.stat().st_size!=row['size']:raise ValueError('baseline size/type mismatch: '+name)
            if name in stores:
                dest.symlink_to(src.resolve(strict=True))
            else:
                if digest(src)!=row['sha256']:raise ValueError('baseline source digest mismatch: '+name)
                shutil.copyfile(src,dest);dest.chmod(0o755 if row['executable'] else 0o644)
                if digest(dest)!=row['sha256'] or dest.stat().st_size!=row['size']:
                    raise ValueError('copied source differs from baseline inventory: '+name)
        env={**os.environ,'GIT_CEILING_DIRECTORIES':str(stage.parent)}
        for check in (True,False):
            command=['git','apply','--no-index']+(['--check'] if check else [])+['-']
            subprocess.run(command,cwd=stage,env=env,input=patch.read_bytes(),check=True)
        inventory={}
        for path in sorted(stage.rglob('*')):
            if path.is_dir():continue
            name=path.relative_to(stage).as_posix()
            if path.is_symlink() and name not in stores:raise ValueError('only declared stores may be shared')
            if not path.is_file():raise ValueError('special file in derived source')
            inventory[name]={'sha256':digest(path),'size':path.stat().st_size,'executable':bool(path.stat().st_mode & 0o111)}
        for name in stores:
            if inventory[name]!=files[name]:raise ValueError('shared store mismatch: '+name)
        if inventory['PACK_MANIFEST.json']!=files['PACK_MANIFEST.json']:
            raise ValueError('patch changed store declaration')
        receipt={**old,'files':inventory,'patches':old.get('patches',[])+[{'name':patch.name,'sha256':pins['patch_sha256']}],
                 'prepared_source':{'baseline_appliance_sha256':expected,'mode':'isolated_prepared_u8_w574','shared_stores':sorted(stores)},
                 'assurance':'New byte inventory and source patch only; public artifacts, startup and answer qualification remain separate.'}
        (stage/'APPLIANCE.json').write_text(json.dumps(receipt,indent=2,sort_keys=True)+'\n')
        for path in stage.rglob('*'):
            if path.is_file() and not path.is_symlink():path.chmod(0o555 if path.stat().st_mode & 0o111 else 0o444)
        publish_directory(stage,output)
    return {'directory':str(output),'materialization_sha256':digest(output/'APPLIANCE.json'),'baseline_appliance_sha256':expected,'files':len(inventory),'shared_stores':len(stores)}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--baseline',type=Path,required=True)
    p.add_argument('--baseline-sha256',required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();print(json.dumps(derive(a.baseline,a.baseline_sha256,a.output),indent=2))


if __name__=='__main__':main()
