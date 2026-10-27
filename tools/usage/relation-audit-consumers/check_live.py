#!/usr/bin/env python3
"""Check the actual P86 reader and store. This adapter and source data are untrusted."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(os.environ['ORACLE7_ROOT']).resolve()
sys.path.insert(0, str(root / 'wander-train'))
source = root / 'wander-train/relation_spec_v1.py'
patch = Path(__file__).with_name('composer-guard.patch').resolve()

def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

with tempfile.TemporaryDirectory() as t:
    candidate = Path(t) / 'root/wander-train/relation_spec_v1.py'
    candidate.parent.mkdir(parents=True)
    candidate.write_bytes(source.read_bytes())
    subprocess.run(['patch', '-s', '-p1', '-i', str(patch)], cwd=t, check=True)
    before, after = load(source, 'consumer_before'), load(candidate, 'consumer_after')
    question = 'Who composed the film The Song Remains the Same?'
    results = [(m.answer(question, 'films', {}), m.answer(question, 'songs', {})) for m in (before, after)]
    print('before:', results[0])
    print('after: ', results[1])
    assert results[0][0]['subject_qid'] == 510381 and results[0][1]['subject_qid'] == 152753
    assert results[1][0] == results[0][0] and results[1][1] is None
