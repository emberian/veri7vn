#!/usr/bin/env python3
"""Untrusted public-table manufacturer; no Engine, sessions or private state.

Run against a NEW patched/admitted U8 materialization. This invokes the original
reader learners once, then publishes their trusted executable pickle artifacts.
"""
import argparse
import hashlib
import importlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

REPO = Path(__file__).resolve().parents[3]
sys.dont_write_bytecode = True
sys.path.insert(0, str(REPO / 'tools/appliance'))
from package_native import publish_directory


def publish(tree, cache, output, helper):
    output = Path(output).absolute()
    tree = Path(tree).resolve()
    if output == tree or tree in output.parents or output in tree.parents:
        raise ValueError('public artifact and source materialization must be disjoint')
    if output.exists() or not output.parent.is_dir() or '..' in output.parts or any(p.is_symlink() for p in (output, *output.parents)):
        raise ValueError('fresh output below existing nonsymlink parent required')
    files = sorted(Path(cache).iterdir())
    if len(files) != 2 or sum(p.name.startswith('reader90_') for p in files) != 1 or sum(p.name.startswith('clause101_') for p in files) != 1:
        raise ValueError('manufacture must yield exactly the two public table files')
    with tempfile.TemporaryDirectory(prefix='.public-reader-', dir=output.parent) as tmp:
        stage = Path(tmp) / 'payload'
        stage.mkdir()
        rows = {}
        for p in files:
            if p.is_symlink() or not p.is_file() or not __import__('re').fullmatch(r'(reader90_[0-9a-f]{24}|clause101_[0-9a-f]{20})\.pickle', p.name) or not 0 < p.stat().st_size <= helper.MAX_ARTIFACT_BYTES:
                raise ValueError('invalid manufactured table')
            shutil.copyfile(p, stage / p.name)
            rows[p.name] = {'sha256': helper.sha(stage / p.name), 'bytes': p.stat().st_size}
        m = {'schema': helper.SCHEMA, 'identity': helper.identity(tree), 'files': rows,
             'assurance': 'Trusted executable pickle under operator custody; no new theorem or answer-coverage claim.'}
        raw = (json.dumps(m, sort_keys=True, indent=2) + '\n').encode()
        if len(raw) > helper.MAX_MANIFEST_BYTES:
            raise ValueError('manifest exceeds serving limit')
        (stage / 'MANIFEST.json').write_bytes(raw)
        for p in stage.iterdir():
            p.chmod(0o444)
        # Atomic no-replace publication; an existing output is never overwritten.
        publish_directory(stage, output)
        output.chmod(0o555)
    return {'directory': str(output), 'manifest_sha256': hashlib.sha256(raw).hexdigest(), 'identity': m['identity']}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--tree', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    tree = a.tree.resolve()
    if tree == (REPO / 'upstream').resolve() or (REPO / 'upstream').resolve() in tree.parents or tree == (REPO / 'var/appliance-20261029/candidate-u8').resolve():
        p.error('use a NEW patched materialization; primary/upstream U8 are immutable')
    if os.environ.get('ORACLE7_PREPARED_SERVING') == '1':
        p.error('manufacturing cannot run in prepared-serving mode')
    os.environ['ORACLE7_ROOT'] = str(tree / 'root')
    sys.path.insert(0, str(tree / 'workbench/swarm'))
    helper = importlib.import_module('runtime_preparation')
    before = helper.identity(tree)
    RC = importlib.import_module('reader_cache10')
    CL = importlib.import_module('clause101')
    KB = importlib.import_module('steps_kb')
    # No organs10 import: it owns private MADE paths. Direct public reader APIs
    # accept all source paths and a fresh scratch cache explicitly.
    with tempfile.TemporaryDirectory(prefix='.reader-learning-', dir=a.output.absolute().parent) as tmp:
        kq = KB.KQA(str(tree / 'root/organs10/kqa/kb.json'))
        train = str(tree / 'root/organs10/kqa/train.json')
        rd, _ = RC.build(train, str(tree / 'root/organs10/kqa/kb.json'), kq, tmp)
        CL.Clauses(rd, train, tmp)
        if helper.identity(tree) != before:
            raise ValueError('public source/data identity changed during manufacture')
        result = publish(tree, tmp, a.output, helper)
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
