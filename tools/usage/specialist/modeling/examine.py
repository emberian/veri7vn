#!/usr/bin/env python3
"""Isolated original six-criterion exam using exact retained real Engine replies.

Never supplies a fabricated core or writes into upstream. Missing evidence fails.
Copied client closure is source only; computation still uses the configured host.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(HERE.parent))
from examine import RetainedCore, load_exam


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--dev-evidence', type=Path, required=True)
    p.add_argument('--heldout-evidence', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--url', default='http://127.0.0.1:8765')
    p.add_argument('--tenant', default='modeling-exam')
    a = p.parse_args()
    out = a.out.resolve()
    if ROOT / 'var' not in out.parents or out.exists():
        p.error('output must be a new directory beneath repository var/')
    dev, held = RetainedCore(a.dev_evidence), RetainedCore(a.heldout_evidence)
    if dev.capabilities != held.capabilities:
        raise ValueError('Core capabilities changed between retained batches')
    out.mkdir(parents=True)
    wb = out / 'workbench'
    (wb / 'data').mkdir(parents=True)
    for rel in ('exam.py', 'data/core_panel.json'):
        shutil.copyfile(ROOT / 'upstream/workbench' / rel, wb / rel)
    # Preserve the authored module's relative client lookup in a fresh source closure.
    usage = out / 'tools/usage'
    specialist = usage / 'specialist/modeling'
    shutil.copytree(HERE, specialist, ignore=shutil.ignore_patterns('__pycache__', 'verdict*', 'exam_log.jsonl'))
    for name in ('calibration.py', 'events_exposure.py', 'hosted_reasoning.py'):
        shutil.copyfile(ROOT / 'tools/usage' / name, usage / name)
    manifest = json.loads((specialist / 'manifest.json').read_text())
    manifest['organ']['init'] = {'url': a.url, 'tenant': a.tenant}
    (specialist / 'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    # Require all exact domain questions before spending heldout. No substitutions.
    panel = json.loads((specialist / 'panel.json').read_text())
    for split, engine in (('dev', dev), ('heldout', held)):
        for item in panel[split]:
            engine.chat(item['q'], 'evidence-presence-only')
    exam = load_exam(wb / 'exam.py')
    verdicts = {'dev': exam.run(specialist, 'dev', dev), 'heldout': exam.run(specialist, 'heldout', held)}
    receipt = {'scope': 'Original six-criterion Workbench exam with retained actual core replies and live Rust HTTP specialist calls; no Mini qualification.',
               'core_capabilities': held.capabilities, 'verdicts': verdicts,
               'workbench_sha256': hashlib.sha256((wb/'exam.py').read_bytes()).hexdigest(),
               'general_panel_sha256': hashlib.sha256((wb/'data/core_panel.json').read_bytes()).hexdigest(),
               'core_evidence_sha256': {split: hashlib.sha256((engine.directory/'results.jsonl').read_bytes()).hexdigest() for split, engine in (('dev',dev),('heldout',held))},
               'client_closure_sha256': {name: hashlib.sha256((usage/name).read_bytes()).hexdigest() for name in ('calibration.py','events_exposure.py','hosted_reasoning.py')},
               'specialist': str(specialist), 'status': exam.status(specialist)['state']}
    (out / 'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt,indent=2))
    return int(receipt['status'] != 'admitted')


if __name__ == '__main__':
    raise SystemExit(main())
