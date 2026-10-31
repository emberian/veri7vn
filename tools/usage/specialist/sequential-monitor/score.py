#!/usr/bin/env python3
"""Manufactured sequential consumer panel, independent exact rational oracle.

Not Oracle7 exam.py's scorer and not an all-distribution coverage proof.
"""
import argparse
from fractions import Fraction as F
import json
import math
from pathlib import Path
import subprocess
import sys
import urllib.error
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from sequential_monitor import hosted, strict_json


def reference(arguments):
    c = arguments['config']
    a, b = map(F, c['bounds'])
    alpha = F(c['alpha'])
    boundary = 0
    while alpha < 2:
        alpha *= 2
        boundary += 1
    s = w = v = F(0)
    hull = [F(0), F(1)]
    answer = []
    for t, x in enumerate(arguments['observations'], 1):
        l = F(1, 2**((t.bit_length()-1)//2))
        s += l*(F(x)-a)/(b-a)
        w += l
        v += l*l/8
        if hull is not None:
            hull = [max(hull[0], (s-boundary-v)/w), min(hull[1], (s+boundary+v)/w)]
            if hull[0] > hull[1]:
                hull = None
        answer.append(None if hull is None else [a+(b-a)*z for z in hull])
    return answer


def check(result, arguments):
    expected = reference(arguments)
    actual = result.get('history', [])
    if len(actual) != len(expected):
        return False
    for point, interval in zip(actual, expected):
        out = point.get('interval')
        if interval is None:
            if out is not None:
                return False
        elif out is None or len(out) != 2:
            return False
        else:
            # Enclosure must go outward; also reject vacuous [bounds] responses
            # once the exact reference has become informative.
            if F(out[0]) > interval[0] or F(out[1]) < interval[1]:
                return False
            bounds = arguments['config']['bounds']
            # Account for representable original-unit spacing, including a large
            # offset over a narrow range, rather than a relative-offset tolerance.
            rounding = 128*max(math.ulp(bounds[0]), math.ulp(bounds[1]))
            width = bounds[1]-bounds[0]
            tolerance = max(rounding, width*1e-10)
            if any(abs(float(e)-o) > tolerance for e, o in zip(interval, out)):
                return False
    final = actual[-1]['interval'] if actual else arguments['config']['bounds']
    return result.get('interval') == final and result.get('state') == {
        'config': arguments['config'], 'position': len(expected), 'observations': arguments['observations']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--native', type=Path)
    group.add_argument('--base')
    parser.add_argument('--tenant', default='sequential-panel')
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    panel = strict_json(Path(__file__).with_name('panel.json').read_text())
    rows = []
    for case in panel['cases']:
        c = {**panel['config'], **case.get('config', {})}
        arguments = {'config': c, 'observations': case['observations']}
        result = None
        rejected = False
        refusal = None
        expected_code = case.get('refusal_code', 'invalid_input')
        try:
            if args.native:
                proc = subprocess.run([str(args.native.resolve())], input=json.dumps({
                    'operation': 'statistics.sequential_monitor', 'arguments': arguments}),
                    text=True, capture_output=True, timeout=30)
                wire = strict_json(proc.stdout)
                if proc.returncode:
                    if wire.get('error', {}).get('code') not in ('invalid_input', 'invalid_json', 'resource_limit'):
                        raise RuntimeError('unexpected native failure: ' + str(wire))
                    rejected = True
                    refusal = wire
                    if case.get('reject') and (wire['error']['code'] != expected_code
                            or (expected_code == 'resource_limit' and not str(wire['error'].get('message', '')).startswith('resource limit: sequential rows'))):
                        raise RuntimeError('wrong native refusal for '+case['id']+': '+json.dumps(wire))
                else:
                    result = wire
            else:
                reply = hosted(args.base, args.tenant, arguments)
                result = reply.get('result')
                if result is None:
                    # The production host returns native admission failures as
                    # completed structured refusals, rather than HTTP errors.
                    # Only the intended error family can satisfy a reject case.
                    prefix = ('resource limit: sequential rows' if expected_code == 'resource_limit'
                              else 'invalid input: ')
                    semantic = (reply.get('status') == 'withheld'
                        and reply.get('reason') == 'native_request_refused'
                        and isinstance(reply.get('detail'), str)
                        and reply['detail'].startswith(prefix))
                    if case.get('reject') and semantic:
                        rejected = True
                        refusal = reply
                    else:
                        raise RuntimeError('unexpected resultless host reply for '+case['id']+': '+json.dumps(reply))
        except urllib.error.HTTPError as error:
            if error.code not in (400, 422):
                raise
            rejected = True
            refusal = {'http_status': error.code, 'detail': error.read(1048576).decode('utf-8', errors='replace')}
        correct = rejected if case.get('reject') else not rejected and check(result, arguments)
        rows.append({'id': case['id'], 'right': bool(correct), 'withheld': rejected,
                     'false_yes': bool(case.get('reject') and not rejected), 'result': result,
                     'refusal': refusal})
    report = {'scope': panel['scope'], 'mode': 'native' if args.native else 'hosted',
              'total': len(rows), 'right': sum(r['right'] for r in rows),
              'wrong': sum(not r['right'] and not r['withheld'] for r in rows),
              'withheld': sum(r['withheld'] for r in rows),
              'false_yes': sum(r['false_yes'] for r in rows), 'cases': rows}
    rendered = json.dumps(report, indent=2, allow_nan=False)+'\n'
    if args.out:
        args.out.write_text(rendered)
    print(rendered, end='')
    return 0 if all(r['right'] for r in rows) else 1


if __name__ == '__main__':
    sys.exit(main())
