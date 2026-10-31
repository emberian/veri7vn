#!/usr/bin/env python3
"""Untrusted actual-host discovery/call qualification, separate from custody checks.

Central starts the relocated bundle from an unrelated cwd with its external state
root. This helper calls that loopback service; it never starts or stops processes.
Cases contain provider, operation_id (or query text), arguments, and nonempty
expected JSON-pointer/value assertions derived independently of the implementation.
No fixture input, reference answer, tenant/restart or specialist panel is invented.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.parse import urlsplit
from package_host import digest, encoded
from package_native import clean_path, read_regular


def pointer(value, path):
    if not path.startswith('/'):
        raise ValueError('expected assertion requires JSON pointer')
    for part in path[1:].split('/'):
        part = part.replace('~1', '/').replace('~0', '~')
        value = value[int(part)] if isinstance(value, list) else value[part]
    return value


def qualify(bundle, url, cases, tenant):
    parsed = urlsplit(url)
    if parsed.scheme != 'http' or parsed.hostname != '127.0.0.1' or parsed.path not in ('', '/') or parsed.query or parsed.fragment or parsed.username:
        raise ValueError('plain loopback host URL required')
    bundle = clean_path(bundle)
    manifest_data = read_regular(bundle / 'MANIFEST.json')
    manifest = json.loads(manifest_data)
    config = json.loads(read_regular(bundle / 'host.template.json'))
    for name, row in manifest['files'].items():
        relative = Path(name)
        if relative.is_absolute() or '..' in relative.parts or digest(read_regular(bundle / relative)) != row['sha256']:
            raise ValueError('payload mismatch: ' + name)
    def call(path, body=None):
        data = encoded(body) if body is not None else None
        request = Request(url.rstrip('/') + path, data=data,
                          headers={'X-Mini-Oracle-Tenant': tenant, 'Content-Type': 'application/json'})
        with urlopen(request, timeout=120) as response:
            return json.load(response)
    capabilities = call('/capabilities')
    if capabilities['host']['binary_sha256'] != manifest['host_sha256']:
        raise ValueError('live host differs from packaged binary')
    operations = {}
    offset = 0
    while True:
        page = call('/operations?limit=50&offset=' + str(offset))
        for row in page['operations']:
            if row['id'] in operations:
                raise ValueError('duplicate operation discovery')
            operations[row['id']] = row
        next_offset = page['next_offset']
        if next_offset is None:
            break
        if not isinstance(next_offset, int) or next_offset <= offset:
            raise ValueError('nonprogressing discovery')
        offset = next_offset
    required = set((config.get('pure') or {}).get('profiles', []))
    if config.get('native'): required.add('runtime')
    if config.get('engine'): required.add('engine')
    required.update('organ:' + row['id'] for row in (config.get('kernels') or {}).get('organs', []))
    covered, results = set(), []
    # Profile ownership comes from the existing derived descriptors, not id prefixes.
    declared = {}
    release = manifest.get('release')
    if release:
        snapshot_digest = release['descriptors']['sha256']
    else:
        snapshot_digest = None
    snapshot_path = bundle / 'release-descriptors.json'
    if snapshot_path.exists():
        snapshot_data = read_regular(snapshot_path)
        if digest(snapshot_data) != snapshot_digest:
            raise ValueError('descriptor snapshot mismatch')
        declared = {p: {d['id'] for d in v['declarations']} for p, v in json.loads(snapshot_data)['profiles'].items()}
    pure_ids = set().union(*declared.values()) if declared else set()
    for index, case in enumerate(cases):
        provider = case['provider']
        expected = case['expected']
        if provider not in required or not expected:
            raise ValueError('case needs enabled provider and independent assertions')
        if 'operation_id' in case:
            ident = case['operation_id']
            if provider == 'runtime' and ident in pure_ids:
                raise ValueError('runtime case names a pure operation')
            if ident not in operations or (provider in declared and ident not in declared[provider]):
                raise ValueError('case operation is absent or belongs to another profile')
            if provider in required - {'runtime', 'engine'} and not provider.startswith('organ:') and provider not in declared:
                raise ValueError('pure profile calls require packaged derived descriptors')
            body = {'operation_id': ident, 'arguments': case['arguments']}
            endpoint = '/invoke'
        else:
            if provider != 'engine' and not provider.startswith('organ:'):
                raise ValueError('query cases are for Engine/extracted routes')
            body = {'text': case['text']}
            endpoint = '/query'
        body.update(request_id='release-case-' + str(index), conversation_id='release-case-' + str(index))
        reply = call(endpoint, body)
        if endpoint == '/invoke':
            if reply.get('outcome') != 'completed' or pointer(reply, '/native_execution/0/admission/route') != provider:
                raise ValueError('call did not complete through its declared provider')
            if not any(path.startswith('/reply/') and path != '/reply/status' for path in expected):
                raise ValueError('call requires an independent result assertion, beyond status')
        elif not any('path' in path or 'route' in path for path in expected):
            raise ValueError('query requires an asserted deciding route')
        for path, value in expected.items():
            if pointer(reply, path) != value:
                raise ValueError('independent assertion failed: case ' + str(index) + ' ' + path)
        results.append({'provider': provider, 'request': body, 'response': reply, 'assertions': expected})
        covered.add(provider)
    if covered != required:
        raise ValueError('missing enabled provider calls: ' + ','.join(sorted(required - covered)))
    return {'schema': 'oracle-host-release-qualification-v1', 'status': 'passed',
            'manifest_sha256': digest(manifest_data), 'host_sha256': manifest['host_sha256'],
            'capabilities': capabilities, 'operations': operations,
            'discovery_sha256': digest(encoded(operations)), 'calls': results,
            'profiles_qualified': sorted(covered),
            'scope': 'actual discovery and supplied independent assertions; tenant/restart/retry and panel scores require separate central receipts'}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--bundle', required=True)
    ap.add_argument('--url', required=True)
    ap.add_argument('--cases', required=True)
    ap.add_argument('--tenant', default='a' * 64)
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    receipt = qualify(a.bundle, a.url, json.loads(read_regular(a.cases)), a.tenant)
    with clean_path(a.out).open('xb') as stream:
        stream.write(encoded(receipt))

if __name__ == '__main__':
    main()
