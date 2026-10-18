#!/usr/bin/env python3
"""Untrusted authored mythology checks against the transcribed source tables.

These check requested relationships, not historical truth or all English forms.
Refusing a meaningful unsupported request remains a capability miss even when
the regression policy passes. Inputs/expectations were saved before the repair.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess


def assess(cases, replies):
    assert len(cases) == len(replies)
    rows = []
    for case, reply in zip(cases, replies):
        answered = reply.get('status') == 'answered'
        supported = case['expect'] is not None
        correct = (answered and supported and reply.get('value') == case['expect']
                   and reply.get('kind') == case['kind'])
        bucket = 'right' if correct else 'wrong' if answered else 'valid_withheld'
        rows.append({'case': case, 'reply': reply, 'outcome': bucket,
                     'policy_passed': correct or (not answered and
                                      (not supported or case.get('policy_withheld', False)))})
    return {'counts': dict(Counter(r['outcome'] for r in rows)),
            'policy_passed': sum(r['policy_passed'] for r in rows),
            'total': len(rows), 'rows': rows}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', required=True, type=Path)
    parser.add_argument('--cases', type=Path, default=Path(__file__).with_name('mythology_probes.json'))
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    cases = json.loads(args.cases.read_text())
    results = {}
    for mode in ('pinned', 'family'):
        command = [str(args.binary)] + (['--specialist', 'mythology'] if mode == 'pinned' else [])
        proc = subprocess.run(command, input=''.join(json.dumps({'id': str(i), 'q': c['q']}) + '\n'
                                                  for i, c in enumerate(cases)),
                              capture_output=True, text=True, check=True, timeout=60)
        results[mode] = assess(cases, [json.loads(line) for line in proc.stdout.splitlines()])
        print(mode, results[mode]['counts'], 'policy', results[mode]['policy_passed'], '/', len(cases))
    args.out.write_text(json.dumps({'binary_sha256': hashlib.sha256(args.binary.read_bytes()).hexdigest(),
                                    'modes': results}, indent=2) + '\n')
    raise SystemExit(0 if all(r['policy_passed'] == r['total'] for r in results.values()) else 1)
