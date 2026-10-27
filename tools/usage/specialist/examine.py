#!/usr/bin/env python3
"""Untrusted Workbench experiment using exact retained Oracle replies, not Mini admission.

Copies only exam.py, its published general panel, and this specialist to fresh
scratch. Workbench's original six checks then run without importing its launcher.
The held-out gate is a replay against real core replies, not a fresh live engine.
"""
import argparse
import base64
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent


def load_exam(path):
    spec = importlib.util.spec_from_file_location('usage_workbench_exam', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class RetainedCore:
    def __init__(self, evidence):
        self.directory = Path(evidence)
        summary = json.loads((self.directory/'summary.json').read_text())
        if not summary.get('finished') or summary.get('stop_reason') or summary.get('transport_errors') or summary.get('http_errors'):
            raise ValueError('Core batch was not successfully completed')
        self.capabilities = summary['capabilities']
        self.tip = self.capabilities['tip']
        self.replies = {}
        for line in (self.directory/'results.jsonl').read_text().splitlines():
            row = json.loads(line)
            if row['http_status'] != 200 or row['state'] != 'response':
                raise ValueError('Non-success core evidence')
            raw = json.loads(base64.b64decode(row['response_body_base64'], validate=True))
            if raw != row['response'] or raw['outcome'] != 'completed':
                raise ValueError('Retained decoded reply differs from raw HTTP bytes')
            if row['text'] in self.replies:
                raise ValueError('Duplicate question: replay cannot resolve conversation context')
            self.replies[row['text']] = raw['reply']

    def chat(self, text, session_id):
        # Exact lookup deliberately fails for any unmeasured question.
        return copy.deepcopy(self.replies[text])


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--dev-evidence', type=Path, required=True)
    ap.add_argument('--heldout-evidence', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    out = args.out.resolve()
    scratch = (ROOT/'var/usage-20261026/specialist').resolve()
    if scratch not in out.parents:
        ap.error('Output must be a fresh directory beneath var/usage-20261026/specialist')
    dev, held = RetainedCore(args.dev_evidence), RetainedCore(args.heldout_evidence)
    if dev.capabilities != held.capabilities:
        raise ValueError('Core capabilities changed between dev and held-out runs')
    out.mkdir(parents=True, exist_ok=False)
    wb = out/'workbench'
    (wb/'data').mkdir(parents=True)
    for rel in ('exam.py', 'data/core_panel.json'):
        shutil.copyfile(ROOT/'upstream/workbench'/rel, wb/rel)
    specialist = out/'data-transfer-explicit'
    shutil.copytree(HERE/'data-transfer', specialist)
    exam = load_exam(wb/'exam.py')
    verdicts = {'dev': exam.run(specialist, 'dev', dev),
                'heldout': exam.run(specialist, 'heldout', held)}
    receipt = {
        'scope': 'Isolated original Workbench exam replay using measured real core replies; not live appliance or Mini admission.',
        'core_capabilities': held.capabilities,
        'evidence': {name: {'directory': str(engine.directory.resolve()),
                           'sha256': hashlib.sha256((engine.directory/'results.jsonl').read_bytes()).hexdigest()}
                     for name, engine in [('dev', dev), ('heldout', held)]},
        'workbench_sha256': hashlib.sha256((wb/'exam.py').read_bytes()).hexdigest(),
        'specialist': str(specialist),
        'status': exam.status(specialist)['state'],
        'verdicts': verdicts,
    }
    (out/'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps(receipt, indent=2))
    return 0 if receipt['status'] == 'admitted' else 1


if __name__ == '__main__':
    raise SystemExit(main())
