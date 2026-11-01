#!/usr/bin/env python3
"""Check exact immutable baseline pins and patch applicability without mutation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--tree',type=Path,required=True)
    a=p.parse_args();here=Path(__file__).resolve().parent
    pins=json.loads((here/'pins.json').read_text())
    for rel,expected in pins['source_files_sha256'].items():
        if hashlib.sha256((a.tree/rel).read_bytes()).hexdigest()!=expected:
            raise ValueError('baseline source mismatch: '+rel)
    patch=here/'prepared-serving.patch'
    if hashlib.sha256(patch.read_bytes()).hexdigest()!=pins['patch_sha256']:
        raise ValueError('patch identity mismatch')
    subprocess.run(['git','apply','--no-index','--check',str(patch)],cwd=a.tree,
                   env={**os.environ,'GIT_CEILING_DIRECTORIES':str(a.tree.resolve().parent)},check=True)
    print(json.dumps({'source_pins':'match','patch_apply_check':'passed','scope':'U8 exact selected source only; no runtime qualification'}))


if __name__=='__main__':main()
