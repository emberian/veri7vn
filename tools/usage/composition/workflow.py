#!/usr/bin/env python3
"""Untrusted explicit caller workflows over retained Oracle replies; no proof authority.

The caller chooses the plan and the meanings of inputs. Oracle computes named
atomic steps. This module checks request binding, reply shape and unit arithmetic,
then performs explicitly labelled local arithmetic. It is not a natural-language
planner, an Oracle answer, a specialist admission, or a semantic proof.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re

# Dimensions: energy, time, length, mass, money. Factors are relative to J/s/m/kg/$.
UNITS = {
    '1': ((0,0,0,0,0), 1), 'kWh': ((1,0,0,0,0), 3600000),
    'J': ((1,0,0,0,0), 1), 'W': ((1,-1,0,0,0), 1),
    'h': ((0,1,0,0,0), 3600), 's': ((0,1,0,0,0), 1),
    'min': ((0,1,0,0,0), 60), 'year': ((0,1,0,0,0), 31557600),
    'kg': ((0,0,0,1,0), 1), 'dollars': ((0,0,0,0,1), 1),
    'dollars/kg': ((0,0,0,-1,1), 1),
}
NUMBER = r'([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)'


def finite(value):
    if isinstance(value, bool) or not isinstance(value, (float, int)) or not math.isfinite(value):
        raise ValueError('quantity must be a finite number')
    return value


def recipe(step):
    """Return the exact request and permitted answer shape for an atomic step."""
    p, kind = step.get('parameters', {}), step['recipe']
    def n(name):
        return format(finite(p[name]), '.15g')
    if kind == 'device_consumption':
        question = f'How much energy in kWh does a {n("watts")} W appliance use for {n("hours")} hours?'
        patterns = [rf'The answer is {NUMBER} kWh\. \(path: core_math\)',
                    rf'It uses {NUMBER} kWh \([^\n]+\)\. \[energy-v3\]']
        return question, 'kWh', ('network>core_math', 'specialist_call>specialist:energy-v3>energy'), patterns
    if kind == 'solar_generation':
        question = f'A {n("watts")} W solar panel receives {n("hours")} peak sun hours. What is its daily energy yield in kWh?'
        return question, 'kWh', ('specialist_call>specialist:energy-v3>solar_yield',), [rf'The array makes about {NUMBER} kWh a day \([^\n]+before losses\)\. \[energy-v3\]']
    if kind == 'resistor_power':
        question = f'What is the power dissipated by a {n("ohms")} ohm resistor carrying {n("amps")} A?'
        return question, 'W', ('specialist_after_guard>P4_lookup_for_compute>specialist:electronics-r2>power',), [rf'The power is {NUMBER} W \([^\n]+\)\. \[electronics-r2\]']
    if kind == 'ratio':
        question = f'What is {n("numerator")} / {n("denominator")}?'
        return question, '1', ('compute:verified',), [rf'In steps: [^\n]+\. The answer is {NUMBER}\.']
    if kind == 'relation_year':
        subject, prop = p['subject'], p['property']
        if not isinstance(subject, str) or not re.fullmatch(r'[A-Za-z][A-Za-z -]{0,79}', subject):
            raise ValueError('unsupported subject name')
        if prop == 'birth':
            question, pid, noun = f'When was {subject} born?', 'P569', 'year of birth'
        elif prop == 'publication':
            question, pid, noun = f'When was {subject} first published?', 'P577', 'year of publication'
        else:
            raise ValueError('unsupported year relation')
        date = r'(?:\d{1,2} [A-Za-z]+ )?(\d{4})'
        pattern = date + r'\. From the Wikidata relation store: ' + re.escape(subject) + r' \(Q\d+\) - ' + noun + r' \(' + pid + r'\) - (?:\d{1,2} [A-Za-z]+ )?\1\. \[rel-[a-z-]+\]'
        return question, 'year', None, [pattern]
    raise ValueError('unsupported atomic recipe: ' + kind)


def cases(plan):
    result = []
    for step in plan['oracle_steps']:
        q, _, _, _ = recipe(step)
        result.append({'id': step['request_id'], 'conversation_id': 'composition_step_' + step['request_id'], 'text': q})
    return result


def extract(step, record):
    question, unit, paths, patterns = recipe(step)
    expected = {'id': step['request_id'], 'conversation_id': 'composition_step_' + step['request_id'], 'text': question}
    if any(record.get(k) != v for k, v in expected.items()):
        raise ValueError('receipt does not match this atomic request')
    response = record.get('response') or {}
    reply = response.get('reply') or {}
    if record.get('http_status') != 200 or response.get('outcome') != 'completed' or reply.get('status') != 'answered':
        raise ValueError('atomic request was not answered')
    if paths is not None and reply.get('path') not in paths:
        raise ValueError('unrecognized answer route; inspect its quantity manually')
    text = reply.get('response', '')
    for pattern in patterns:
        match = re.fullmatch(pattern, text)
        if match:
            return finite(float(match[1])), unit
    raise ValueError('answer does not state the expected atomic quantity')


def calculate(op, a, b, unit):
    av, au = a
    bv, bu = b
    ad, af = UNITS[au]
    bd, bf = UNITS[bu]
    od, of = UNITS[unit]
    if op in ('add', 'subtract'):
        if not ad == bd == od:
            raise ValueError('addition/subtraction requires compatible units')
        result = (av*af + (bv*bf if op == 'add' else -bv*bf))/of
    elif op in ('multiply', 'divide'):
        dimensions = tuple(x + (y if op == 'multiply' else -y) for x,y in zip(ad,bd))
        if dimensions != od:
            raise ValueError('output unit does not match this operation')
        if op == 'divide' and bv == 0:
            raise ValueError('division by zero')
        result = ((av*af)*(bv*bf) if op == 'multiply' else (av*af)/(bv*bf))/of
    else:
        raise ValueError('unsupported local operation')
    return finite(result), unit


def execute(plan, records):
    """Never upgrade a failed/partial step; preserve actual replies in the trace."""
    trace, known, indexed = [], {}, {}
    for record in records:
        indexed.setdefault(record.get('id'), []).append(record)
    try:
        def bind(name, quantity):
            if not isinstance(name, str) or not name or name in known:
                raise ValueError('quantity names must be unique and nonempty')
            if quantity[1] not in UNITS:
                raise ValueError('unsupported unit')
            known[name] = (finite(quantity[0]), quantity[1])
        for name, quantity in plan.get('inputs', {}).items():
            bind(name, (quantity['value'], quantity['unit']))
            trace.append({'kind':'caller_input', 'quantity':name, 'value':quantity['value'], 'unit':quantity['unit']})
        for step in plan['oracle_steps']:
            matches = indexed.get(step['request_id'], [])
            if len(matches) != 1:
                raise ValueError('need exactly one receipt for ' + step['request_id'])
            record = matches[0]
            evidence = {'kind':'oracle_atomic_step', 'quantity':step['output'], 'receipt':record}
            trace.append(evidence)
            value, unit = extract(step, record)
            bind(step['output'], (value,unit))
            evidence.update(value=value, unit=unit)
        for step in plan.get('local_steps', []):
            args = step['inputs']
            if len(args) != 2:
                raise ValueError('local operations take exactly two named inputs')
            quantity = calculate(step['operation'], known[args[0]], known[args[1]], step['unit'])
            bind(step['output'], quantity)
            trace.append({'kind':'local_arithmetic', **step, 'value':quantity[0]})
        value, unit = known[plan['target']]
        return {'status':'completed', 'authority':'untrusted caller workflow, not an Oracle final answer or proof',
                'target':plan['target'], 'value':value, 'unit':unit, 'trace':trace}
    except (ValueError, KeyError, TypeError, OverflowError) as error:
        return {'status':'blocked', 'reason':str(error), 'trace':trace}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--results', type=Path)
    parser.add_argument('--cases', action='store_true')
    args = parser.parse_args()
    plan = json.loads(args.plan.read_text())
    if args.cases:
        output = cases(plan)
    elif args.results:
        output = execute(plan, [json.loads(row) for row in args.results.read_text().splitlines()])
        output['receipts_sha256'] = hashlib.sha256(args.results.read_bytes()).hexdigest()
    else:
        parser.error('provide --cases or --results')
    print(json.dumps(output, indent=2, allow_nan=False))


if __name__ == '__main__':
    main()
