#!/usr/bin/env python3
"""Untrusted source-query comparison client for the native graph.batch route.

Counts/existence describe distinct entity IDs in the supplied immutable image,
not alias completeness or world absence. Each item starts with empty Previous.
"""
import argparse
import json
from pathlib import Path
import sys
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hosted_reasoning import invoke_envelope, normalize_tenant

OPERATION = 'graph.batch'


def request(names):
    items = []
    for name in names:
        program = [{'function': 'Find', 'dependencies': [], 'inputs': [name]}]
        for demand in ('full', 'count', 'exists'):
            items.append({'dialect': 'kqa', 'input': program, 'demand': demand})
    return {'batch': {'items': items}}


def invoke(arguments, url, tenant):
    body = invoke_envelope(OPERATION, arguments, 'source-query-comparison')
    wire = urllib.request.Request(url.rstrip('/') + '/invoke', data=json.dumps(body).encode(),
        headers={'Content-Type': 'application/json', 'x-mini-oracle-tenant': normalize_tenant(tenant)})
    with urllib.request.urlopen(wire, timeout=30) as response:
        raw = response.read(8 * 1024 * 1024 + 1)
    if len(raw) > 8 * 1024 * 1024:
        raise ValueError('client response byte cap')
    envelope = json.loads(raw)
    reply = envelope.get('reply', {})
    if (envelope.get('outcome') != 'completed' or envelope.get('operation_id') != OPERATION
            or reply.get('operation_id') != OPERATION or reply.get('status') != 'answered'):
        raise ValueError('batch not completed; inspect host refusal')
    return reply['result']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('names', nargs='+', help='Related source entity names to compare')
    parser.add_argument('--url', help='Invoke a running admitted native host; otherwise emit arguments')
    parser.add_argument('--tenant', default='query-comparison')
    args = parser.parse_args()
    arguments = request(args.names)
    result = invoke(arguments, args.url, args.tenant) if args.url else arguments
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
