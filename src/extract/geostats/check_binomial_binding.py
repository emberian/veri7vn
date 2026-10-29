#!/usr/bin/env python3
"""Untrusted, independent binomial binding regressions against a real consumer.

Expected masses enumerate Bernoulli outcome sequences with exact fractions;
they never parse the literal from the question or use a binomial coefficient.
The supplied probability fixtures are independent mathematical expectations.
Also run the three shipped statistics panels with their own scorers read-only.
No theorem, build or full Engine qualification is implied by this check.
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import importlib.util
from itertools import product
import json
import math
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]


def mass(case):
    p = Fraction(*case['probability'])
    return sum((math.prod(p if bit else 1-p for bit in bits)
                for bits in product((0, 1), repeat=case['n'])
                if sum(bits) == case['k']), Fraction())


def ask(proc, index, question):
    proc.stdin.write(json.dumps({'id': str(index), 'q': question})+'\n')
    proc.stdin.flush()
    return json.loads(proc.stdout.readline())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, default=REPO/'var/geostats/bin/geostats')
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    cases = json.loads((HERE/'binomial_binding_probes.json').read_text())
    result = {'binary': str(args.binary.resolve()), 'modes': {}}
    failures = 0
    for mode, version in [('family', None), ('statistics', 1),
                          ('statistics-v2', 2), ('statistics-v3', 3)]:
        argv = [str(args.binary)] + ([] if mode == 'family' else ['--specialist', mode])
        proc = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        checks = {'n': len(cases), 'passed': 0, 'fails': []}
        for i, case in enumerate(cases):
            reply = ask(proc, i, case['q'])
            good = reply['status'] == case['status']
            if case['status'] == 'answered':
                want = float(mass(case))
                value = reply.get('value')
                good = (good and reply.get('kind') == 'binomial'
                        and isinstance(value, (int, float))
                        and math.isclose(value, want, rel_tol=1e-5, abs_tol=0.0))
            if good:
                checks['passed'] += 1
            else:
                checks['fails'].append({'q': case['q'], 'reply': reply})
        entry = {'probes': checks}
        failures += len(checks['fails'])
        if version:
            folder = REPO/'upstream/root/specialists'/mode
            spec = importlib.util.spec_from_file_location('binomial_panel_scorer', folder/'stats_scorer.py')
            scorer = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(scorer)
            panel = json.loads((folder/f'stats_panel_v{version}.json').read_text())
            entry['panels'] = {}
            for split in ('dev', 'heldout'):
                counts = dict(n=0, correct=0, wrong=0, false_yes=0, withheld_valid=0)
                for i, case in enumerate(item for item in panel if item['split'] == split):
                    reply = ask(proc, i, case['q'])
                    good, asserted = scorer.ok(case, reply)
                    counts['n'] += 1
                    counts['correct'] += int(good)
                    if not good:
                        key = ('wrong' if asserted else 'withheld_valid') if case['valid'] else 'false_yes'
                        counts[key] += 1
                entry['panels'][split] = counts
                failures += counts['wrong'] + counts['false_yes']
        proc.stdin.close()
        if proc.wait() != 0:
            failures += 1
        result['modes'][mode] = entry
        print(mode, f"probes {checks['passed']}/{checks['n']}", entry.get('panels', ''))
    result['failures'] = failures
    if args.out:
        args.out.write_text(json.dumps(result, indent=2)+'\n')
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
