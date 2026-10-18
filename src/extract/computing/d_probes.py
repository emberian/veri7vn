#!/usr/bin/env python3
"""Untrusted D semantic probes, independent of HOL implementation and panel scorers.

Capacity enumerates Boolean addresses; UART builds a frame bit list. Reference
expectations use the recorded CPython v3.12.3 source row, never API execution.
The author also wrote the implementation, so these are regression evidence,
not an independent audit or a proof of natural-language interpretation.
"""
import argparse
from fractions import Fraction
import hashlib
import itertools
import json
import math
from pathlib import Path
import random
import subprocess
import sys
sys.dont_write_bytecode = True
from score import ask


def cases(seed):
    rng = random.Random(seed)
    for n, w in [(0, 1), (1, 3), (2, 7), (3, 1), (12, 16)] + [(rng.randrange(0, 9), rng.randrange(1, 25)) for _ in range(15)]:
        address_count = sum(1 for _ in itertools.product((False, True), repeat=n))
        yield dict(specialist='embedded', q=f'How much memory with a {n}-bit address bus and {w}-bit data words?', status='answered', value=str(Fraction(address_count * w, 8)), contains=['bytes'])
    for baud, data, parity, stops in [(9600, 7, 'E', 1), (19200, 5, 'O', 2), (115200, 9, 'N', 1), (57600, 8, 'N', 1)]:
        frame = ['start'] + ['data'] * data + ([] if parity == 'N' else ['parity']) + ['stop'] * stops
        fmt = f'{data}{parity}{stops}'
        yield dict(specialist='embedded', q=f'At {baud} baud UART {fmt}, how many characters per second?', status='answered', value=str(Fraction(baud, len(frame))), contains=['characters per second'])
        yield dict(specialist='embedded', q=f'How long to send 13 characters over UART at {baud} baud ({fmt})?', status='answered', value=str(Fraction(13 * len(frame), baud)), contains=['13 characters'])
        for q in [f'At {baud} baud UART {fmt}, how many bytes per second?', f'How long to send 13 bytes over UART at {baud} baud ({fmt})?']:
            yield dict(specialist='embedded', q=q, status='answered' if data == 8 else 'withheld', contains=['bytes'] if data == 8 else ['eight bits', 'map'], kind='uart_throughput' if data == 8 and 'per second' in q else 'uart_time' if data == 8 else 'underspecified')
    for q in ['At 9600 baud UART 7E1 with seven-bit characters, how many bytes per second?', 'How long to send 13 bytes over UART at 9600 baud using 7E1 characters?']:
        yield dict(specialist='embedded', q=q, status='withheld', kind='underspecified', contains=['eight bits', 'map'])
    for premise in ['not uniformly', 'nonuniformly', 'with biased selection', 'not independently', 'with correlated choices']:
        yield dict(specialist='cyber', q=f'A password is 12 characters long, chosen from alphanumeric characters {premise}. Entropy in bits?', status='withheld', kind='underspecified', contains=['probability model'])
        yield dict(specialist='cyber', q=f'A password is 12 characters long, chosen from alphanumeric characters {premise}. Average brute-force time at 1 billion guesses per second?', status='withheld', kind='underspecified', contains=['probability model'])
    yield dict(specialist='cyber', q='A password is 1 character long, drawn nonuniformly from an alphabet of 2 symbols with probabilities 0.9 and 0.1. What is its entropy in bits?', status='withheld', kind='underspecified', contains=['probability model'], capability='valid_unsupported', answer_value=-(0.9 * math.log2(0.9) + 0.1 * math.log2(0.1)))
    yield dict(specialist='cyber', q='A password is 12 characters long, chosen uniformly and independently from alphanumeric characters. Entropy in bits?', status='answered', contains=['71.45 bits'])
    yield dict(specialist='cyber', q='Worst-case time to exhaust all 4-character passwords from lowercase letters with biased selection at 1 million guesses per second?', status='answered', contains=['0.457 seconds'])
    for sid in ('python', 'python-r2'):
        yield dict(specialist=sid, q='Explain what os.remove does in Python.', status='answered', contains=['Remove a file (same as unlink()).', 'Python 3.12.3'])
        yield dict(specialist=sid, q='What is the signature of os.remove in Python?', status='answered', contains=['(path, *, dir_fd=None)'])
        yield dict(specialist=sid, q='Which module contains os.remove in Python?', status='answered', contains=['the os module'])
        for name in ['os.mkdir', 'math.frobnicate']:
            yield dict(specialist=sid, q=f'Explain what {name} does in Python.', status='withheld', kind='unknown', contains=[f'reference has no entry for {name}', 'does not establish whether the API exists'])
        yield dict(specialist=sid, q='What is the signature of sys.set_asyncgen_hooks in Python?', status='withheld', kind='no_signature', contains=['reference has no recorded signature'])


def evaluate(case, rep):
    errors = []
    if rep.get('status') != case['status']:
        errors.append('status')
    if case.get('kind') and rep.get('kind') != case['kind']:
        errors.append('kind')
    if not rep.get('provenance', {}).get('taken'):
        errors.append('not taken')
    for text in case['contains']:
        if text not in rep.get('response', ''):
            errors.append('missing ' + text)
    if 'value' in case:
        try:
            expected, actual = Fraction(case['value']), Fraction(rep['value'])
            if abs(expected - actual) > max(Fraction(1, 10**9), abs(expected) / 10**9):
                errors.append('value')
        except (KeyError, ValueError, TypeError, ZeroDivisionError):
            errors.append('missing numeric value')
    return errors


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--binary', default='var/computing/bin/computing')
    ap.add_argument('--seed', type=int, default=911029)
    ap.add_argument('--out', required=True)
    ap.add_argument('--dispatch', action='store_true', help='Use installed computing binary through actual dispatcher')
    args = ap.parse_args()
    rows, processes = [], {}
    try:
        for case in cases(args.seed):
            if 'capability' not in case:
                if case['status'] == 'answered':
                    case['capability'] = 'answerable'
                elif 'os.mkdir' in case['q'] or 'sys.set_asyncgen_hooks' in case['q']:
                    case['capability'] = 'valid_unsupported'
                elif 'math.frobnicate' in case['q']:
                    case['capability'] = 'reference_unknown'
                else:
                    case['capability'] = 'underspecified'
            sid = case['specialist']
            if args.dispatch:
                cmd = [sys.executable, '-B', 'tools/dispatch/dispatch.py', '--organs', 'computing', '--specialist', sid, '--no-reader', '--no-document', '--no-routes', '--order', 'front']
                p = subprocess.run(cmd, input=json.dumps({'id':str(len(rows)), 'q':case['q']})+'\n', text=True, capture_output=True, check=True)
                rep = json.loads(p.stdout)
            else:
                if sid not in processes:
                    processes[sid] = subprocess.Popen([args.binary, '--specialist', sid], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
                rep, _ = ask(processes[sid], str(len(rows)), case['q'])
            errors = evaluate(case, rep)
            if args.dispatch:
                dispatch = rep.get('provenance', {}).get('dispatch', {})
                if dispatch.get('decisive') is not True or dispatch.get('stages_run') != ['specs']:
                    errors.append('dispatcher did not retain specialist reply')
            rows.append(dict(case=case, reply=rep, errors=errors))
    finally:
        for proc in processes.values():
            proc.stdin.close()
            proc.wait()
    capability = dict(answered_correct=0, wrong=0, withheld_valid=0, unscored_valid_answer=0,
                      underspecified_withheld=0, underspecified_asserted=0,
                      reference_unknown_withheld=0, reference_unknown_asserted=0)
    for row in rows:
        case, rep = row['case'], row['reply']
        asserted = rep.get('status') == 'answered'
        cls = case['capability']
        if cls in ('answerable', 'valid_unsupported'):
            if not asserted:
                capability['withheld_valid'] += 1
            elif cls == 'answerable':
                capability['wrong' if row['errors'] else 'answered_correct'] += 1
            elif 'answer_value' in case:
                try:
                    correct = abs(float(rep['value']) - case['answer_value']) < 0.0001
                except (KeyError, ValueError, TypeError):
                    correct = False
                capability['answered_correct' if correct else 'wrong'] += 1
            else:
                capability['unscored_valid_answer'] += 1
        else:
            capability[cls + ('_asserted' if asserted else '_withheld')] += 1
    report = dict(binary=args.binary, binary_sha256=hashlib.sha256(Path(args.binary).read_bytes()).hexdigest(), seed=args.seed, dispatch=args.dispatch, n=len(rows), policy_assertions_passed=sum(not r['errors'] for r in rows), capability=capability, results=rows)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k != 'results'}))
    for r in rows:
        if r['errors']:
            print(json.dumps(r))
    return 0 if report['policy_assertions_passed'] == report['n'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
