#!/usr/bin/env python3
"""Untrusted isolated training/export driver. Never edits upstream or reads pickles.

Run on the host retaining the pinned corpus. This performs full learning, not a
row deletion or post-export adjustment. Output must be a NEW scratch directory.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

CONTROL = 'f37f687e8190f08ff862738543790d6bcd56185a1a807ffdbd5cf8340da85354'
PATCHED = '03e43e4e742b1bc6093fb67d00425ab47b679278fe1519b799b8cab91b90e57f'
TRAIN = 'e9fbe4c1cdf207aac83ae0d5e4a1a53a9965a2b13b403de699ca6d5dae6e4510'
KB = '04da7408320c5cb7023c44372cce32846d56d369d8865d2e61a18c3956661a7c'
ROOT = Path(__file__).resolve().parents[2]

def sha(p):
    with Path(p).open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('source-dir', 'train', 'kb', 'work'):
        p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    for path, expected in ((a.source_dir / 'reader_v7.py', CONTROL), (a.train, TRAIN), (a.kb, KB)):
        if sha(path) != expected:
            raise ValueError(f'pinned input changed: {path}')
    a.work.mkdir(parents=True, exist_ok=False)
    source = a.work / 'source'
    shutil.copytree(a.source_dir, source, ignore=shutil.ignore_patterns('__pycache__', '*.pyc', '*.pkl', '*.pickle'))
    patch = ROOT / 'tools/reader_audit/canonical_plural_first.patch'
    with patch.open('rb') as f:
        subprocess.run(['patch', '--fuzz=0', '-p3', str((source / 'reader_v7.py').resolve())], stdin=f, check=True)
    if sha(source / 'reader_v7.py') != PATCHED:
        raise ValueError('patched source is not the reviewed source bytes')
    env = dict(os.environ, PYTHONHASHSEED='0', PYTHONDONTWRITEBYTECODE='1')
    commands = [
        [sys.executable, '-B', str(ROOT / 'tools/reader_audit/test_canonical_plural_first.py'), '--source-dir', str(source.resolve())],
        [sys.executable, '-B', str(ROOT / 'native/tools/export_reader_tables.py'), '--source-dir', str(source.resolve()),
         '--train', str(a.train.resolve()), '--kb', str(a.kb.resolve()), '--out', str((a.work / 'reader-plural.json').resolve())],
    ]
    manifest = {'scope': 'isolated canonical-plural-first full learning; no data-label edits',
                'inputs': {str(path.resolve()): sha(path) for path in (a.train, a.kb, patch)},
                'source_control_sha256': CONTROL, 'source_candidate_sha256': PATCHED, 'commands': commands}
    (a.work / 'recipe.json').write_text(json.dumps(manifest, indent=2) + '\n')
    for i, command in enumerate(commands):
        with (a.work / f'step-{i}.stdout').open('xb') as out, (a.work / f'step-{i}.stderr').open('xb') as err:
            subprocess.run(command, env=env, stdout=out, stderr=err, check=True)
    # Exact row deltas are produced separately from exports; all policies/forms
    # stay visible and must not be weakened to make this experiment succeed.
    print(json.dumps({'reader': str(a.work / 'reader-plural.json'), 'sha256': sha(a.work / 'reader-plural.json')}))

if __name__ == '__main__':
    main()
