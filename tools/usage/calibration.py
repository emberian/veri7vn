#!/usr/bin/env python3
"""Untrusted supplied-data calibration client, with no source or sampling authority.

Numerical mode invokes the hosted statistics.calibration operation. Exact mode
calls a caller-selected existing GeoStats extraction on bounded integer data.
The extracted rational fit is rendered to four decimals by the existing kernel;
this client does not claim those rounded values are exact rational coefficients.
No reverse fit, inverse interval or unit conversion is silently substituted.
"""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
import subprocess
import sys
import urllib.request
from hosted_reasoning import normalize_tenant, invoke_envelope

OPERATION = 'statistics.calibration'


class ExactInputError(ValueError):
    """A deliberately unsupported exact-consumer request, before execution."""


def strict_json(text):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError('duplicate JSON key: ' + key)
            result[key] = value
        return result
    def reject(value):
        raise ValueError('nonfinite JSON constant: ' + value)
    return json.loads(text, object_pairs_hook=unique, parse_constant=reject)


def hosted(base, tenant, arguments):
    """Pure HTTP workflow; backpressure/errors are surfaced without retries."""
    tenant = normalize_tenant(tenant)
    def transport(path, body=None):
        request = urllib.request.Request(base.rstrip('/') + path,
            data=None if body is None else json.dumps(body, allow_nan=False).encode(),
            headers={'Content-Type': 'application/json', 'x-mini-oracle-tenant': tenant})
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read(2**20 + 1)
        if len(raw) > 2**20:
            raise ValueError('host response exceeds client limit')
        return strict_json(raw)
    descriptor = transport('/operations/' + OPERATION)
    if descriptor.get('id') != OPERATION or descriptor.get('availability') != 'live_direct':
        raise ValueError('calibration operation unavailable')
    envelope = transport('/invoke', invoke_envelope(OPERATION, arguments, 'supplied-calibration'))
    if envelope.get('outcome') != 'completed' or envelope.get('operation_id') != OPERATION:
        raise ValueError('host operation failed: ' + json.dumps(envelope))
    reply = envelope.get('reply', {})
    if (reply.get('operation_id') != OPERATION or reply.get('authority') != 'computation_only'
            or reply.get('status') not in ('answered', 'withheld')):
        raise ValueError('invalid host structured reply')
    result = reply.get('result')
    if result is not None:
        if (result.get('operation') != OPERATION or result.get('direction') != arguments['direction']
                or result.get('uncertainty') != arguments['uncertainty']
                or result.get('fit', {}).get('model', {}).get('assumptions') != arguments['assumptions']
                or [e.get('supplied_value') for e in result.get('estimates', [])] != arguments['values']):
            raise ValueError('host reply does not bind requested calibration')
        forward = arguments['direction'] != 'inverse_point'
        if (result.get('input_unit') != arguments['x_unit' if forward else 'response_unit']
                or result.get('output_unit') != arguments['response_unit' if forward else 'x_unit']):
            raise ValueError('host reply unit mismatch')
    return reply


def exact_extracted(binary, arguments):
    """Real extracted consumer, narrow admission, preserving raw kernel replies.

    Python framing and binary selection are untrusted. Existing kernel theorem:
    a returned rational line has zero residual and x-weighted residual sums and
    minimizes SSE among rational intercept/slope lines on exactly supplied rows.
    It proves no error model or inference and does not prove this transport.
    """
    allowed = {'x', 'response', 'x_name', 'x_unit', 'response_unit', 'assumptions',
               'direction', 'uncertainty', 'values'}
    if set(arguments) != allowed:
        raise ExactInputError('exact extraction accepts only x,response,x_name,x_unit,response_unit,assumptions,direction,uncertainty,values; no covariance or weights')
    if arguments['direction'] != 'forward_mean' or arguments['uncertainty'] != 'point_only':
        raise ExactInputError('exact extraction supports forward fitted points only; no inverse or intervals')
    for key in ('x_name', 'x_unit', 'response_unit'):
        if not isinstance(arguments[key], str) or not 1 <= len(arguments[key].encode()) <= 1024:
            raise ExactInputError('invalid label')
    if (not isinstance(arguments['assumptions'], list) or not 1 <= len(arguments['assumptions']) <= 16
            or any(not isinstance(a, str) or not 1 <= len(a.encode()) <= 1024 for a in arguments['assumptions'])):
        raise ExactInputError('explicit bounded caller assumptions required')
    x, y, values = (arguments[k] for k in ('x', 'response', 'values'))
    if (not all(isinstance(v, list) for v in (x, y, values)) or not 1 <= len(x) <= 128
            or len(x) != len(y) or not 1 <= len(values) <= 32
            or any(type(v) is not int or abs(v) > 10**9 for seq in (x, y, values) for v in seq)):
        raise ExactInputError('exact extraction requires equally long 1..128 bounded integer pairs and 1..32 integer queries')
    data = ' for x = [' + ', '.join(map(str, x)) + '], y = [' + ', '.join(map(str, y)) + ']'
    questions = [('intercept', 'regression intercept' + data), ('slope', 'regression slope' + data)]
    questions += [('prediction', 'regression prediction at x = ' + str(v) + data) for v in values]
    requests = ''.join(json.dumps({'id': str(i), 'q': q, 'session': 'supplied-calibration'}) + '\n'
                       for i, (_, q) in enumerate(questions))
    completed = subprocess.run([str(Path(binary).resolve()), '--specialist', 'statistics-v3'],
        input=requests, text=True, capture_output=True, timeout=30, check=True)
    if len(completed.stdout.encode()) > 2**20:
        raise ValueError('extracted response too large')
    replies = [strict_json(line) for line in completed.stdout.splitlines() if line.strip()]
    if len(replies) != len(questions):
        raise ValueError('extracted reply count mismatch')
    for i, ((kind, _), reply) in enumerate(zip(questions, replies)):
        if reply.get('id') != str(i) or reply.get('status') not in ('answered', 'withheld'):
            raise ValueError('extracted reply identity/status mismatch')
        if reply['status'] == 'answered':
            if (reply.get('kind') != 'regression_' + kind
                    or type(reply.get('value')) not in (int, float) or not math.isfinite(reply['value'])
                    or reply.get('provenance', {}).get('kernel') != 'GeoStats.g_reply/s_reply/weighted_reply/paired_reply'):
                raise ValueError('unexpected extracted result')
    return {'mode': 'existing_geostats_extraction', 'status': 'answered' if all(r['status'] == 'answered' for r in replies) else 'withheld',
        'assurance': 'Existing exact rational kernel, rendered to four decimals; Python transport and binary identity untrusted. No uncertainty theorem.',
        'arguments': arguments, 'input_unit': arguments['x_unit'], 'output_unit': arguments['response_unit'],
        'kernel_questions': [q for _, q in questions],
        'rounded_intercept': replies[0].get('value'), 'rounded_slope': replies[1].get('value'),
        'rounded_predictions': [r.get('value') for r in replies[2:]], 'raw_kernel_replies': replies}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path, help='JSON arguments object (not an operation envelope)')
    parser.add_argument('--base', default='http://127.0.0.1:8000')
    parser.add_argument('--tenant', default='calibration')
    parser.add_argument('--geostats', type=Path, help='use this existing extracted executable instead of numerical host')
    args = parser.parse_args()
    raw = args.input.read_bytes()
    if len(raw) > 2**20:
        raise ValueError('input exceeds client limit')
    arguments = strict_json(raw)
    result = exact_extracted(args.geostats, arguments) if args.geostats else hosted(args.base, args.tenant, arguments)
    print(json.dumps(result, indent=2, allow_nan=False))


if __name__ == '__main__':
    main()
