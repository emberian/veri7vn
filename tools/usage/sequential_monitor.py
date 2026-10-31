#!/usr/bin/env python3
"""Untrusted supplied-data sequential client; no sampling or source authority.

This delegates numerical decisions to the real host. The optional finite-path
check uses independent exact rational arithmetic; it is a refutation tool, not a
proof of distribution-free coverage. No hosted experiment registry is created.
"""
from __future__ import annotations
import argparse
from fractions import Fraction
import json
from pathlib import Path
from hosted_reasoning import Client, invoke_envelope, unique_object, invalid_constant

OPERATION = 'statistics.sequential_monitor'


def strict_json(text):
    return json.loads(text, object_pairs_hook=unique_object, parse_constant=invalid_constant)


def hosted(base, tenant, arguments):
    client = Client(base, tenant, timeout=30)
    descriptor = client.transport('/operations/' + OPERATION)
    if descriptor.get('id') != OPERATION or descriptor.get('availability') != 'live_direct':
        raise ValueError('sequential operation unavailable')
    envelope = client.transport('/invoke', invoke_envelope(
        OPERATION, arguments, 'supplied-sequential-monitor'))
    if envelope.get('outcome') != 'completed' or envelope.get('operation_id') != OPERATION:
        raise ValueError('host failed: ' + json.dumps(envelope))
    reply = envelope.get('reply', {})
    if (reply.get('operation_id') != OPERATION or reply.get('authority') != 'computation_only'
            or reply.get('status') not in ('answered', 'withheld')):
        raise ValueError('unexpected structured host reply')
    result = reply.get('result')
    if result is None:
        return reply
    if result.get('operation') != OPERATION or result.get('state') != {
            'config': arguments['config'], 'position': len(arguments['observations']),
            'observations': arguments['observations']}:
        raise ValueError('host result is not bound to supplied ordered observations/config')
    if [p.get('position') for p in result.get('history', [])] != list(range(1, len(arguments['observations']) + 1)):
        raise ValueError('host sequence positions disagree')
    return reply


def exact_crossings(bits, mean, alpha):
    """Independent rational capital oracle, with analytic integer threshold."""
    threshold = 0
    scaled = alpha
    while scaled < 2:
        scaled *= 2
        threshold += 1
    weighted = Fraction(0)
    weights = Fraction(0)
    penalty = Fraction(0)
    ever = False
    answer = []
    for t, x in enumerate(bits, 1):
        lam = Fraction(1, 2**((t.bit_length() - 1)//2))
        weighted += lam*x
        weights += lam
        penalty += lam*lam/8
        ever |= abs(weighted - mean*weights) > threshold + penalty
        answer.append(ever)
    return answer


def enumerate_adversary(base, tenant, config, horizon):
    """Stop at the first false exclusion; compare every prefix to exact arithmetic.

    Bernoulli distributions only. Passing cannot establish arbitrary bounded-law
    validity or the truth of the supplied sampling assumptions.
    """
    if not 1 <= horizon <= 12:
        raise ValueError('enumeration horizon must be 1..12')
    if config['bounds'] != [0, 1]:
        raise ValueError('enumeration requires bounds [0,1]')
    alpha = Fraction(str(config['alpha']))
    masses = {}
    for mean in (Fraction(1, 4), Fraction(1, 2), Fraction(3, 4)):
        mass = Fraction(0)
        for path in range(2**horizon):
            bits = [(path >> j) & 1 for j in range(horizon)]
            reply = hosted(base, tenant, {'config': config, 'observations': bits})
            result = reply.get('result')
            if result is None:
                raise ValueError('enumeration withheld: ' + json.dumps(reply))
            expected = exact_crossings(bits, mean, alpha)
            for point, crossing in zip(result['history'], expected):
                interval = point['interval']
                actual = interval is None or not interval[0] <= float(mean) <= interval[1]
                if actual != crossing:
                    raise ValueError(f'capital mismatch at path {path}, mean {mean}, position {point["position"]}')
            if expected[-1]:
                ones = sum(bits)
                mass += mean**ones * (1-mean)**(horizon-ones)
        if mass > alpha:
            raise ValueError('ever-exclusion probability exceeds allocation')
        masses[str(mean)] = {'ever_exclusion_probability': float(mass), 'exact': str(mass)}
    return {'horizon': horizon, 'distributions': masses,
            'status': 'finite Bernoulli path check only; not a general coverage proof'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('--base', required=True)
    parser.add_argument('--tenant', default='sequential-inspection')
    parser.add_argument('--enumerate', type=int, metavar='HORIZON',
                        help='optional exhaustive host check; at most 12, up to 12288 calls')
    args = parser.parse_args()
    raw = args.input.read_bytes()
    if len(raw) > 2**20:
        raise ValueError('input limit exceeded')
    supplied = strict_json(raw)
    if args.enumerate is not None:
        result = enumerate_adversary(args.base, args.tenant, supplied['config'], args.enumerate)
    else:
        result = hosted(args.base, args.tenant, supplied)
    print(json.dumps(result, indent=2, allow_nan=False))


if __name__ == '__main__':
    main()
