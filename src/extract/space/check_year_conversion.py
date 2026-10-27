#!/usr/bin/env python3
"""Untrusted native boundary checks for orbital-year quantities.

The expected rational values are independent arithmetic, not a claim that
English interpretation is proved. Checks all public astronomy IDs and family
routing, including refusals that must not fall back to a one-year property.
"""
import argparse
from fractions import Fraction
import hashlib
import json
import math
import shlex
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
EXPECTED = {
    'orbital_ratio': Fraction(2748, 487), 'reverse': Fraction(1461, 916),
    'venus': Fraction(5, 4), 'jupiter_to_mars': Fraction(64, 5),
    'half_mars': Fraction(458, 487), 'zero': Fraction(0),
    'three_word': Fraction(2748, 487), 'year_definition': Fraction(2748, 487),
    'table_default': Fraction(2748, 487), 'supplied_override': Fraction(6),
    'duplicate_consistent': Fraction(2748, 487), 'same_planet': Fraction(3),
}
EXTRA = [
    ('short', '3 Mars years in Earth years', Fraction(2748, 487)),
    ('count_first', '3 Mars years are how many Earth years?', Fraction(2748, 487)),
    ('in_count', 'How many Earth years in 3 Mars years?', Fraction(2748, 487)),
    ('years_on', 'How many Earth years are 3 years on Mars?', Fraction(2748, 487)),
    ('source_default', 'Earth takes 350 days. How many Earth years are 3 Mars years?', Fraction(2061, 350)),
    ('target_default', 'Mars takes 700 days. How many Earth years are 3 Mars years?', Fraction(2800, 487)),
    ('swapped_premises', 'Mars takes 687 days and Earth takes 365.25 days. How many Mars years are 3 Earth years?', Fraction(1461, 916)),
    ('rotation_not_orbit', 'Mars takes 687 days to rotate. How many Earth years are 3 Mars years?', None),
    ('hours_not_days', 'Mars takes 687 days and Earth takes 365.25 hours. How many Earth years are 3 Mars years?', None),
    ('third_period', 'Mars takes 687 days and Jupiter takes 4300 days. How many Earth years are 3 Mars years?', None),
    ('extra_quantity', 'Mars takes 687 days and Earth takes 365.25 days with 2 moons. How many Earth years are 3 Mars years?', None),
    ('incomplete_quantity', 'Mars takes 687 days. How many Earth years are 3 years?', None),
    ('partial_number', 'How many Earth years are 3.2.1 Mars years?', None),
    ('scientific_count', 'How many Earth years are 3e2 Mars years?', Fraction(274800, 487)),
    ('fraction_count', 'How many Earth years are 1/2 Mars years?', Fraction(458, 487)),
]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--binary', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--host', help='Execute the exact binary path on this SSH host')
    a = p.parse_args()
    cases = [(x['id'], x['text'], EXPECTED.get(x['id'])) for x in json.loads(
        (ROOT / 'tools/usage/mars/cases.json').read_text())] + EXTRA
    rows = []
    for mode in ['family', 'astronomy', 'astronomy-v2', 'astronomy-v3', 'astronomy-v3-r2']:
        args = [str(a.binary) if a.host else str(a.binary.resolve())] + ([] if mode == 'family' else ['--specialist', mode])
        if a.host:
            args = ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15', a.host, shlex.join(args)]
        request = ''.join(json.dumps({'id': name, 'q': text}) + '\n' for name, text, _ in cases)
        run = subprocess.run(args, input=request, capture_output=True, text=True, check=True, timeout=30)
        replies = [json.loads(line) for line in run.stdout.splitlines()]
        assert len(replies) == len(cases), (mode, run.stdout, run.stderr)
        for (name, text, expect), reply in zip(cases, replies):
            asserted = reply.get('status') == 'answered'
            if 'error' in reply:
                verdict = 'error'
            elif expect is None:
                verdict = 'false_yes' if asserted else 'right'
            else:
                # Space's existing JSON value contract rounds exact answers to
                # six significant digits; the new conversion prose uses twelve.
                right = asserted and reply.get('kind') == 'year_years' and math.isclose(
                    float(reply.get('value', 'nan')), float(expect), rel_tol=5e-6, abs_tol=1e-12)
                verdict = 'right' if right else ('wrong' if asserted else 'withheld_valid')
            rows.append(dict(mode=mode, id=name, q=text, expected=None if expect is None else str(expect),
                             reply=reply, verdict=verdict))
    counts = {mode: {v: sum(r['mode'] == mode and r['verdict'] == v for r in rows)
                    for v in ['right', 'wrong', 'false_yes', 'withheld_valid', 'error']}
              for mode in dict.fromkeys(r['mode'] for r in rows)}
    if a.host:
        digest = subprocess.run(['ssh', '-o', 'BatchMode=yes', a.host,
                                 shlex.join(['sha256sum', str(a.binary)])],
                                text=True, capture_output=True, check=True, timeout=30).stdout.split()[0]
    else:
        digest = hashlib.sha256(a.binary.read_bytes()).hexdigest()
    result = dict(host=a.host, binary=str(a.binary) if a.host else str(a.binary.resolve()), sha256=digest,
                  cases_per_mode=len(cases), counts=counts, rows=rows)
    a.out.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(counts))
    for row in rows:
        if row['verdict'] != 'right':
            print(json.dumps(row))
    raise SystemExit(int(any(r['verdict'] != 'right' for r in rows)))


if __name__ == '__main__':
    main()
