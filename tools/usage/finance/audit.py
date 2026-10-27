#!/usr/bin/env python3
"""Untrusted comparison aid; retains Oracle reply and never upgrades a refusal.

Only an answered computation with a recognizable final-answer sentence is
compared. A numeric value inside withheld provenance is never an answer.
"""
import argparse
import hashlib
import json
import re
from fractions import Fraction
from pathlib import Path

FINAL = re.compile(r'The answer is (-?(?:[0-9]+(?:\.[0-9]+)?|[0-9]+/[0-9]+))\.$')


def assess(row, contract):
    result = {'id': row['id'], 'local_expected_rational': contract['local_expected_rational'],
              'output_unit': contract['output_unit'], 'oracle_reply': row.get('response', {}).get('reply'),
              'latency_seconds': row.get('latency_seconds')}
    if row['id'] != contract['id'] or row['text'] != 'Calculate '+contract['expression']+'.':
        result['assessment'] = 'request_mismatch'
        return result
    reply = result['oracle_reply'] or {}
    if row.get('http_status') != 200 or reply.get('status') != 'answered':
        result['assessment'] = 'not_answered'
        return result
    match = FINAL.search(reply.get('response', ''))
    if reply.get('provenance', {}).get('kind') != 'computation' or not match:
        result['assessment'] = 'needs_review'
        return result
    result['oracle_final_number'] = match.group(1)
    result['assessment'] = ('exact_match' if Fraction(match.group(1)) == Fraction(contract['local_expected_rational']) else 'different_number')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('contracts', type=Path)
    parser.add_argument('results', type=Path)
    args = parser.parse_args()
    contracts = {r['id']: r for r in json.loads(args.contracts.read_text())}
    raw = args.results.read_bytes()
    rows = [json.loads(line) for line in raw.splitlines()]
    assessments = [assess(row, contracts[row['id']]) for row in rows]
    print(json.dumps({'scope': 'caller-model agreement, not verified financial semantics or specialist panel scores',
                      'source_results': str(args.results.resolve()),
                      'source_results_sha256': hashlib.sha256(raw).hexdigest(),
                      'contracts_sha256': hashlib.sha256(args.contracts.read_bytes()).hexdigest(),
                      'missing_ids': sorted(set(contracts)-{r['id'] for r in rows}),
                      'assessments': assessments}, indent=2))


if __name__ == '__main__':
    main()
