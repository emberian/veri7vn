#!/usr/bin/env python3
"""Untrusted exact continuous resource allocation client for supplied rows.

Products are divisible amounts in their declared units. Resource consumption is
resource-unit/product-unit, capacity is resource-unit and profit is money per
product-unit. Unit strings are declarations, with no scale conversion. This is
not an integer production plan, a safety decision or a claim about real stocks.
"""
import argparse
from fractions import Fraction as F
import json
from pathlib import Path
import re
import urllib.request
from hosted_reasoning import normalize_tenant, invoke_envelope

OP = 'reasoning.optimize_linear'


def rational(text):
    if (not isinstance(text, str) or len(text) > 8195
            or re.fullmatch(r'-?(0|[1-9][0-9]*)(/[1-9][0-9]*)?', text) is None):
        raise ValueError('bounded exact rational string required')
    q = F(text)
    if max(q.numerator.bit_length(), q.denominator.bit_length()) > 4096:
        raise ValueError('rational exceeds 4096 bits')
    return q


def label(text):
    if not isinstance(text, str) or not text.strip() or len(text.encode()) > 64:
        raise ValueError('nonblank label at most 64 bytes required')
    return text


def model(spec):
    if set(spec) != {'money_unit', 'products', 'resources'}:
        raise ValueError('expected money_unit, complete products and resources')
    label(spec['money_unit'])
    products, resources = spec['products'], spec['resources']
    if not isinstance(products, list) or not 1 <= len(products) <= 16 or not isinstance(resources, list) or len(resources) > 64:
        raise ValueError('one to sixteen products and at most 64 resources required')
    ids, objective, rows, row_units = [], [], [], []
    n = len(products)
    for i, p in enumerate(products):
        if set(p) != {'id', 'unit', 'profit_per_unit', 'minimum', 'maximum'}:
            raise ValueError('product requires id, unit, profit_per_unit, minimum, maximum (or null)')
        pid, unit = label(p['id']), label(p['unit'])
        if pid in ids:
            raise ValueError('duplicate product')
        ids.append(pid)
        objective.append(str(-rational(p['profit_per_unit'])))
        minimum = rational(p['minimum'])
        maximum = None if p['maximum'] is None else rational(p['maximum'])
        if minimum < 0 or maximum is not None and maximum < 0:
            raise ValueError('product quantity bounds must be nonnegative')
        # Inconsistent min/max remains a valid infeasible question.
        for sign, rhs, kind in ((-1, -minimum, 'minimum'), (1, maximum, 'maximum')):
            if rhs is not None:
                rows.append({'id': f'product:{i}:{kind}', 'coefficients': [str(sign if j == i else 0) for j in range(n)], 'bound': str(rhs)})
                row_units.append(unit)
    seen = set()
    for i, r in enumerate(resources):
        if set(r) != {'id', 'unit', 'capacity', 'per_product'}:
            raise ValueError('resource requires id, unit, capacity and complete per_product map')
        rid, unit = label(r['id']), label(r['unit'])
        if rid in seen or not isinstance(r['per_product'], dict) or set(r['per_product']) != set(ids):
            raise ValueError('unique resource ID and exactly one coefficient per product required; explicit zero means no consumption')
        seen.add(rid)
        capacity = rational(r['capacity'])
        coefficients = [rational(r['per_product'][pid]) for pid in ids]
        if capacity < 0 or any(v < 0 for v in coefficients):
            raise ValueError('capacity and resource consumption must be nonnegative')
        rows.append({'id': f'resource:{i}:{rid}', 'coefficients': list(map(str, coefficients)), 'bound': str(capacity)})
        row_units.append(unit)
    return {'variables': ids, 'rows': rows, 'objective': objective}, row_units


def replay(problem, result):
    """Check primal/dual/Farkas/ray arithmetic on original supplied inequalities."""
    n, m = len(problem['variables']), len(problem['rows'])
    a = [[rational(v) for v in row['coefficients']] for row in problem['rows']]
    b = [rational(row['bound']) for row in problem['rows']]
    c = [rational(v) for v in problem['objective']]
    def vector(values, size):
        if not isinstance(values, list) or len(values) != size:
            raise ValueError('certificate vector size differs')
        return list(map(rational, values))
    def dot(x, y):
        return sum((v*w for v, w in zip(x, y)), F(0))
    def feasible(x):
        if any(dot(row, x) > rhs for row, rhs in zip(a, b)):
            raise ValueError('original resource row violated')
    status, cert = result['status'], result['certificate']
    if status == 'unknown':
        if cert is not None:
            raise ValueError('unknown must not carry an admitted certificate')
        return
    if not isinstance(cert, dict) or cert.get('kind') != status:
        raise ValueError('certificate status differs')
    if status in ('optimal', 'unbounded'):
        x = vector(cert['point'], n)
        feasible(x)
    if status in ('optimal', 'infeasible'):
        y = vector(cert['multipliers'], m)
        if any(v < 0 for v in y):
            raise ValueError('negative row multipliers')
        combined = [dot([row[j] for row in a], y) for j in range(n)]
        bound = dot(b, y)
        if status == 'optimal':
            if combined != [-v for v in c] or dot(c, x) != -bound:
                raise ValueError('objective does not match original-row dual bound')
        elif any(combined) or bound >= 0:
            raise ValueError('original-row Farkas contradiction absent')
    elif status == 'unbounded':
        d = vector(cert['direction'], n)
        if any(dot(row, d) > 0 for row in a) or dot(c, d) >= 0:
            raise ValueError('ray does not improve within original resource rows')
    else:
        raise ValueError('optimization requires an optimum, infeasibility, unboundedness or unknown')


def explain(spec, problem, row_units, result):
    summary = {'status': result['status'], 'model': problem, 'certificate': result['certificate'],
               'scope': 'Divisible supplied product quantities and exact declared consumption; no integer, safety, uncertainty or real-stock completeness claim.'}
    if result['status'] == 'optimal':
        cert = result['certificate']
        point = list(map(rational, cert['point']))
        summary['production'] = [{'id': p['id'], 'amount': str(x), 'unit': p['unit']} for p, x in zip(spec['products'], point)]
        summary['profit'] = {'value': str(-sum((rational(c)*x for c, x in zip(problem['objective'], point)), F(0))), 'unit': spec['money_unit']}
        summary['row_accounting'] = [{'id': r['id'], 'used': str(sum((rational(a)*x for a, x in zip(r['coefficients'], point)), F(0))),
            'at_most': r['bound'], 'unit': unit, 'dual_multiplier': y, 'dual_unit': spec['money_unit'] + '/' + unit}
            for r, unit, y in zip(problem['rows'], row_units, cert['multipliers'])]
    return summary


def unique_object(items):
    out = {}
    for k, v in items:
        if k in out:
            raise ValueError('duplicate JSON key')
        out[k] = v
    return out


def invoke(url, tenant, spec):
    tenant = normalize_tenant(tenant)
    problem, units = model(spec)
    def request(path, body=None):
        req = urllib.request.Request(url.rstrip('/') + path, data=None if body is None else json.dumps(body).encode(),
            headers={'Content-Type': 'application/json', 'x-mini-oracle-tenant': tenant})
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read(262145)
        if len(raw) > 262144:
            raise ValueError('host reply exceeds client limit')
        return json.loads(raw, object_pairs_hook=unique_object)
    descriptor = request('/operations/' + OP)
    if descriptor.get('id') != OP or descriptor.get('availability') != 'live_direct':
        raise ValueError('exact optimization operation unavailable')
    envelope = request('/invoke', invoke_envelope(OP, problem, 'supplied-resource-allocation'))
    if envelope.get('operation_id') != OP or envelope.get('outcome') != 'completed':
        raise ValueError('host operation failed or mismatched')
    reply = envelope['reply']
    if reply.get('operation_id') != OP or reply.get('authority') != 'computation_only' or reply.get('status') not in ('answered', 'withheld'):
        raise ValueError('invalid host result envelope')
    result = reply['result']
    replay(problem, result)
    if (reply['status'] == 'withheld') != (result['status'] == 'unknown'):
        raise ValueError('unknown must be withheld')
    return explain(spec, problem, units, result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('--url', default='http://127.0.0.1:8765')
    parser.add_argument('--tenant', default='resource-allocation')
    args = parser.parse_args()
    print(json.dumps(invoke(args.url, args.tenant, json.loads(args.input.read_text(), object_pairs_hook=unique_object))))


if __name__ == '__main__':
    main()
