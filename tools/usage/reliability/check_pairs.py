#!/usr/bin/env python3
"""Untrusted scalar-answer experiment checker; no proof or admission authority.

Inspects retained runner replies. It never queries or changes Oracle7. Comparing
scalars does not verify units, provenance truth, or the specialist panel criteria.
Unknown answer forms remain unparsed rather than guessed from arbitrary numbers.
"""
import argparse
import json
import math
from collections import Counter
from pathlib import Path
import re

NUMBER = r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?"


def observe(row):
    if row.get('state') != 'response' or row.get('http_status') != 200:
        return {'kind': 'transport_failure', 'value': None}
    reply = (row.get('response') or {}).get('reply', {})
    status = reply.get('status')
    if status in ('withheld', 'clarification'):
        return {'kind': 'refusal', 'value': None, 'status': status}
    if status != 'answered':
        return {'kind': 'unparsed', 'value': None, 'status': status}
    text = reply.get('response', '')
    patterns = [rf'^\[ev:derived\]\s+({NUMBER})(?=\s|\.)',
                rf'\bThe answer is ({NUMBER})(?=\.|\s|$)',
                rf'^{NUMBER}\s*°[CF]\s+is\s+({NUMBER})\s*°[CF]']
    values = [float(match.group(1)) for pattern in patterns
              if (match := re.search(pattern, text))]
    if values and all(math.isfinite(v) and v == values[0] for v in values):
        claimed = reply.get('provenance', {}).get('value')
        if claimed is not None and claimed != values[0]:
            return {'kind': 'inconsistent_reply', 'value': None, 'status': status}
        return {'kind': 'number', 'value': values[0], 'status': status}
    return {'kind': 'unparsed', 'value': None, 'status': status}


def matches(actual, expected):
    return actual['kind'] == expected['kind'] and (
        actual['kind'] == 'refusal' or
        math.isclose(actual['value'], expected['value'], rel_tol=1e-9, abs_tol=1e-9))


def evaluate(rows, expectations):
    by_id = {}
    for row in rows:
        if row['id'] in by_id:
            raise ValueError('duplicate case id cannot be paired unambiguously: ' + row['id'])
        by_id[row['id']] = row
    expected_ids = set(expectations['cases'])
    if set(by_id) != expected_ids:
        raise ValueError('result ids differ from expectation ids')
    cases = {}
    for key, expected in expectations['cases'].items():
        actual = observe(by_id[key])
        correct = matches(actual, expected)
        if actual['kind'] in ('transport_failure', 'unparsed', 'inconsistent_reply'):
            outcome = actual['kind']
        elif correct:
            outcome = 'correct_scalar' if actual['kind'] == 'number' else 'safe_refusal'
        elif actual['kind'] == 'refusal':
            outcome = 'needless_refusal'
        else:
            outcome = 'wrong_answer'
        cases[key] = {'expected': expected, 'actual': actual, 'correct': correct, 'outcome': outcome}
    pairs = []
    for pair in expectations['pairs']:
        left, right = cases[pair['left']], cases[pair['right']]
        same = left['actual']['kind'] == right['actual']['kind'] and left['actual']['value'] == right['actual']['value']
        relation_holds = same if pair['relation'] == 'same' else not same
        # Two equally wrong answers/refusals never count as a passing invariant.
        passed = left['correct'] and right['correct'] and relation_holds
        pairs.append({**pair, 'observed_relation_holds': relation_holds, 'passed': passed})
    return {'scope': 'Scalar task and pair experiments only; no panel scores or proof claim.',
            'counts': dict(Counter(c['outcome'] for c in cases.values())),
            'pairs_passed': sum(p['passed'] for p in pairs), 'pairs_total': len(pairs),
            'cases': cases, 'pairs': pairs}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--results', type=Path, required=True)
    parser.add_argument('--expectations', type=Path, default=Path(__file__).with_name('expectations.json'))
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    rows = [json.loads(line) for line in args.results.read_text().splitlines() if line.strip()]
    result = evaluate(rows, json.loads(args.expectations.read_text()))
    result['receipts'] = str(args.results.resolve())
    with args.out.open('x') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')
    print(json.dumps({key: result[key] for key in ('counts', 'pairs_passed', 'pairs_total')}))
    return 0 if all(c['correct'] for c in result['cases'].values()) and all(p['passed'] for p in result['pairs']) else 1


if __name__ == '__main__':
    raise SystemExit(main())
