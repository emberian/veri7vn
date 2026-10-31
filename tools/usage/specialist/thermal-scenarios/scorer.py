#!/usr/bin/env python3
"""Untrusted independent literal-gold scorer for the new thermal workflow.

Reads supplied reply values, never imports native science or solves its matrix.
A refusal must be explicit; arbitrary transport exceptions are execution errors.
"""
import argparse
import copy
import json
import math
from pathlib import Path
import sys
import urllib.error
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from thermal_scenarios import Client


def score(case, reply):
    expected = case['expect']
    asserted = reply.get('status') == 'answered'
    if expected.get('refused'):
        return {'right': not asserted and reply.get('status') == 'withheld', 'wrong': asserted, 'false_yes': asserted}
    if not asserted:
        return {'right': False, 'wrong': False, 'false_yes': False}
    temperatures = [list(s['temperature_k'].values()) for s in reply.get('scenarios', [])]
    derivatives = [s['temperature_derivative'] for s in reply.get('sensitivities', [])]
    def close(got, want):
        return (len(got) == len(want) and all(len(a) == len(b) and all(type(x) in (int,float) and math.isfinite(x)
            and abs(x-y) <= 1e-8 for x,y in zip(a,b)) for a,b in zip(got,want)))
    right = close(temperatures, expected['temperatures']) and close(derivatives, expected['derivatives'])
    return {'right': right, 'wrong': not right, 'false_yes': False}


def cases():
    folder = Path(__file__).resolve().parent
    panel = json.loads((folder/'panel.json').read_text())
    base = json.loads((folder/panel['base']).read_text())
    for case in panel['cases']:
        arguments = copy.deepcopy(base)
        if 'scenario_overrides' in case: arguments['scenarios'] = case['scenario_overrides']
        if 'sensitivity_overrides' in case: arguments['sensitivities'] = case['sensitivity_overrides']
        if case.get('fixed_all'):
            for node, t in zip(arguments['network']['nodes'], [306,302,300]): node['fixed_temperature_k'] = t
        if case.get('floating'):
            arguments['network']['nodes'][-1].pop('fixed_temperature_k')
            for scenario in arguments['scenarios']: scenario['fixed_temperature_k'][-1] = None
        if 'conductance_override' in case: arguments['network']['links'][0]['conductance_w_per_k'] = case['conductance_override']
        yield case, arguments


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', required=True)
    parser.add_argument('--tenant', default='thermal-panel')
    args = parser.parse_args()
    client = Client(args.url, args.tenant)
    client.discover()
    totals = {'right': 0, 'wrong': 0, 'false_yes': 0, 'execution_errors': 0}
    records = []
    for case, arguments in cases():
        try:
            reply = client.invoke(arguments)
            result = score(case, reply)
        except urllib.error.HTTPError as error:
            # Native admission errors become structured host failures. Only a
            # recognized provider input/refusal code is a scored refusal.
            body = json.loads(error.read())
            if error.code == 400 and body.get('outcome') == 'error' and body.get('error') == 'invalid_arguments':
                result = score(case, {'status': 'withheld'})
            else:
                result = {'execution_errors': 1, 'detail': str(error)}
        except Exception as error:
            result = {'execution_errors': 1, 'detail': str(error)}
        for key in totals: totals[key] += int(result.get(key, 0))
        records.append({'id': case['id'], **result})
    print(json.dumps({'scope':'new thermal workflow panel; no upstream specialist score', 'totals': totals, 'cases': records}, indent=2))
    return int(totals['wrong'] or totals['false_yes'] or totals['execution_errors'] or totals['right'] != len(records))

if __name__ == '__main__':
    raise SystemExit(main())
