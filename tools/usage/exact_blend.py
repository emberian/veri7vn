#!/usr/bin/env python3
"""Untrusted supplied-stock blend adapter and independent rational witness replay.

Amounts are kg, stock fractions kg solute/kg stock, cost money/kg. Supplied
stocks are a complete local model, never evidence of real availability, safety,
chemical compatibility or uncertain composition. This client has no HOL proof.
"""
import argparse
from fractions import Fraction as F
import json
import re
from pathlib import Path
import urllib.request
from hosted_reasoning import normalize_tenant, invoke_envelope

OP = 'reasoning.exact_linear_feasibility'


def rational(value):
    if (not isinstance(value, str) or len(value) > 8195
            or re.fullmatch(r'-?(0|[1-9][0-9]*)(/[1-9][0-9]*)?', value) is None):
        raise ValueError('bounded exact rational string required')
    q = F(value)
    if q.numerator.bit_length() > 4096 or q.denominator.bit_length() > 4096:
        raise ValueError('rational coefficient exceeds 4096 bits')
    return q


def model(spec):
    if set(spec) != {'stocks', 'total_kg', 'fraction_min', 'fraction_max'}:
        raise ValueError('expected complete stocks, total_kg and fraction bounds')
    stocks = spec['stocks']
    if not isinstance(stocks, list) or not 1 <= len(stocks) <= 12:
        raise ValueError('one to twelve supplied stocks required')
    total, low, high = map(rational, (spec['total_kg'], spec['fraction_min'], spec['fraction_max']))
    if total <= 0 or not 0 <= low <= high <= 1:
        raise ValueError('positive kg total and fractions 0<=min<=max<=1 required')
    names, rows, fractions = [], [], []
    for i, stock in enumerate(stocks):
        if set(stock) != {'name', 'available_kg', 'fraction'}:
            raise ValueError('stock requires name, available_kg, fraction')
        name = stock['name']
        if not isinstance(name, str) or not name.strip() or len(name.encode()) > 128 or name in names:
            raise ValueError('unique nonblank stock names required')
        available, fraction = map(rational, (stock['available_kg'], stock['fraction']))
        if available < 0 or not 0 <= fraction <= 1:
            raise ValueError('nonnegative kg availability and fraction 0..1 required')
        names.append(name)
        fractions.append(fraction)
        for sign, bound, label in ((-1, F(0), 'nonnegative'), (1, available, 'stock')):
            rows.append({'id': f'{i}:{label}', 'coefficients': [str(sign if j == i else 0) for j in range(len(stocks))], 'bound': str(bound)})
    for sign in (1, -1):
        rows.append({'id': f'total:{sign}', 'coefficients': [str(sign)] * len(stocks), 'bound': str(sign * total)})
    rows += [{'id': 'solute:upper', 'coefficients': list(map(str, fractions)), 'bound': str(high * total)},
             {'id': 'solute:lower', 'coefficients': [str(-x) for x in fractions], 'bound': str(-low * total)}]
    return {'variables': names, 'rows': rows, 'objective': None}


def check(problem, result):
    """Replay the original normalized rows; never trust elimination metadata."""
    rows = problem['rows']
    n, m = len(problem['variables']), len(rows)
    def dot(a, b):
        if len(a) != len(b):
            raise ValueError('vector size differs')
        return sum((rational(x) * rational(y) for x, y in zip(a, b)), F(0))
    cert = result['certificate']
    if result['status'] == 'unknown':
        if cert is not None:
            raise ValueError('unknown with certificate')
        return
    if not isinstance(cert, dict) or cert.get('kind') != result['status']:
        raise ValueError('certificate status differs')
    if cert['kind'] == 'feasible':
        point = cert['point']
        if len(point) != n or any(dot(row['coefficients'], point) > rational(row['bound']) for row in rows):
            raise ValueError('supplied blend constraint violated')
    elif cert['kind'] == 'infeasible':
        y = cert['multipliers']
        if len(y) != m or any(rational(v) < 0 for v in y):
            raise ValueError('invalid Farkas multipliers')
        if any(dot([r['coefficients'][j] for r in rows], y) != 0 for j in range(n)) or dot([r['bound'] for r in rows], y) >= 0:
            raise ValueError('invalid supplied-row contradiction')
    else:
        raise ValueError('blend workflow expects feasibility, not optimization')


def invoke(url, tenant, spec):
    tenant = normalize_tenant(tenant)
    problem = model(spec)
    descriptor_request = urllib.request.Request(url.rstrip('/') + '/operations/' + OP, headers={'x-mini-oracle-tenant': tenant})
    with urllib.request.urlopen(descriptor_request, timeout=15) as response:
        descriptor = json.load(response)
    if descriptor.get('id') != OP or descriptor.get('availability') != 'live_direct':
        raise ValueError('exact linear operation unavailable')
    request = urllib.request.Request(url.rstrip('/') + '/invoke', data=json.dumps(invoke_envelope(OP, problem, 'supplied-exact-blend'), allow_nan=False).encode(),
        headers={'Content-Type': 'application/json', 'x-mini-oracle-tenant': tenant})
    with urllib.request.urlopen(request, timeout=15) as response:
        raw = response.read(262145)
    if len(raw) > 262144:
        raise ValueError('oversized host reply')
    envelope = json.loads(raw)
    if envelope.get('outcome') != 'completed' or envelope.get('operation_id') != OP:
        raise ValueError('host operation failed')
    reply = envelope['reply']
    if reply.get('operation_id') != OP or reply.get('authority') != 'computation_only' or reply.get('status') not in ('answered', 'withheld'):
        raise ValueError('invalid host reply')
    result = reply['result']
    check(problem, result)
    return {'result': result, 'rows': problem, 'scope': 'Supplied exact kg stocks and one solute fraction; no safety or real-world completeness claim.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('--url', default='http://127.0.0.1:8765')
    parser.add_argument('--tenant', default='exact-blend')
    args = parser.parse_args()
    print(json.dumps(invoke(args.url, args.tenant, json.loads(args.input.read_text()))))


if __name__ == '__main__':
    main()
