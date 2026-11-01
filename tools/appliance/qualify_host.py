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
import base64
import json
import os
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
            if provider != 'engine' and not provider.startswith('organ:') and not (provider == 'runtime' and config.get('conversation_profile')):
                raise ValueError('query cases require an enabled query route')
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




def resolved_journey_body(step, previous_query):
    """Resolve the one supported dependency without mutating the case plan."""
    body = json.loads(encoded(step['body']))
    flag = step.get('use_previous_query_version', False)
    if not isinstance(flag, bool):
        raise ValueError('use_previous_query_version must be boolean')
    if flag:
        if step['endpoint'] != '/invoke' or 'expected_version' in body.get('arguments', {}):
            raise ValueError('dependent invoke must omit its literal expected_version')
        version = (previous_query or {}).get('conversation_version')
        if previous_query is None or previous_query.get('outcome') != 'completed' or type(version) is not int or not 0 <= version <= 2**63 - 2:
            raise ValueError('dependent invoke needs an immediately preceding completed query version')
        body['arguments']['expected_version'] = version
    return body


def native_journey(bundle, url, cases, tenant, phase, checkpoint):
    """Two-phase actual native-only consumer journey; central owns host restart.

    cases={before:[{endpoint,body,expected}],after:[...]} supplies real resource
    operations, natural-language turns and independently justified assertions.
    The last pre-restart request is retried byte-for-byte both before and after
    restart; subsequent after steps must continue that same conversation.
    """
    if phase not in ('before', 'after'):
        raise ValueError('invalid journey phase')
    checkpoint = clean_path(checkpoint)
    if phase == 'before' and checkpoint.exists():
        raise ValueError('pre-restart checkpoint must be absent')
    parsed = urlsplit(url)
    if parsed.scheme != 'http' or parsed.hostname != '127.0.0.1' or parsed.path not in ('', '/') or parsed.query or parsed.fragment or parsed.username:
        raise ValueError('plain loopback host URL required')
    bundle = clean_path(bundle)
    manifest_data = read_regular(bundle / 'MANIFEST.json')
    manifest = json.loads(manifest_data)
    for name, row in manifest['files'].items():
        relative = Path(name)
        if relative.is_absolute() or '..' in relative.parts or digest(read_regular(bundle / relative)) != row['sha256']:
            raise ValueError('payload mismatch: ' + name)
    config = json.loads(read_regular(bundle / 'host.template.json'))
    if config.get('conversation_profile') != 'native-v1' or config.get('engine'):
        raise ValueError('journey requires native-v1 with no Engine configured')
    def exchange(endpoint, body=None, raw=None):
        data = raw if raw is not None else (encoded(body) if body is not None else None)
        request = Request(url.rstrip('/') + endpoint, data=data,
                          headers={'X-Mini-Oracle-Tenant': tenant, 'Content-Type': 'application/json'})
        with urlopen(request, timeout=120) as response:
            reply = response.read(4194305)
            if len(reply) > 4194304:
                raise ValueError('journey response exceeds 4 MiB')
            return reply
    capabilities = json.loads(exchange('/capabilities'))
    if (capabilities.get('conversation_profile') or {}).get('id') != 'native-v1':
        raise ValueError('live service has not admitted native-v1 conversation profile')
    if capabilities['host']['binary_sha256'] != manifest['host_sha256']:
        raise ValueError('live host differs from packaged binary')
    health = json.loads(exchange('/health'))
    if 'engine' not in health or health['engine'] is not None:
        raise ValueError('live native journey has an Engine or omits its health state')
    native = config['native']
    admitted = [p for p in capabilities.get('providers', []) if p.get('provider_id') == 'native']
    if len(admitted) != 1 or any(p.get('provider_id') == 'engine' for p in capabilities.get('providers', [])):
        raise ValueError('live native provider admission is missing, duplicate or includes Engine')
    admission = admitted[0]['admission']
    if admission.get('image_sha256') != native['image_sha256']:
        raise ValueError('live image differs from packaged native image')
    if admission.get('release_admitted') is not True or admission.get('release_identity') != native['release']['identity']:
        raise ValueError('live release differs from packaged admitted native release')
    before, after = cases['before'], cases['after']
    if not before or not after:
        raise ValueError('journey needs pre-restart and post-restart consumer steps')
    conversation = before[0]['body']['conversation_id']
    ids = set()
    for step in before + after:
        body, expected = step['body'], step['expected']
        if step['endpoint'] not in ('/invoke', '/query') or body['conversation_id'] != conversation:
            raise ValueError('journey must continue one conversation through query/invoke')
        if body['request_id'] in ids or not expected:
            raise ValueError('journey requires distinct step request ids and independent assertions')
        ids.add(body['request_id'])
        if not any(p.startswith('/reply/') and p != '/reply/status' for p in expected):
            raise ValueError('journey requires independent result assertions beyond status')
        if step['endpoint'] == '/invoke':
            descriptor = json.loads(exchange('/operations/' + body['operation_id']))
            if descriptor.get('availability') != 'live_direct':
                raise ValueError('journey operation is not actually registered')
    replay_step = before[-1]
    if replay_step['endpoint'] == '/invoke' and replay_step['body']['operation_id'] not in capabilities.get('durable_operations', []):
        raise ValueError('restart retry must target a discovered durable operation or query')
    identity = {'manifest_sha256': digest(manifest_data), 'cases_sha256': digest(encoded(cases)), 'tenant': tenant}
    checkpoint = clean_path(checkpoint)
    records = []
    previous_query = None
    if phase == 'after':
        saved = json.loads(read_regular(checkpoint))
        if saved['identity'] != identity:
            raise ValueError('restart journey identity changed')
        retained = base64.b64decode(saved['response_base64'], validate=True)
        retried = exchange(saved['endpoint'], raw=base64.b64decode(saved['request_base64'], validate=True))
        if retried != retained:
            raise ValueError('post-restart exact retry differs from retained acknowledgement')
        records.append({'restart_exact_replay_sha256': digest(retried)})
        if saved['endpoint'] == '/query':
            previous_query = json.loads(retried)
    for step in before if phase == 'before' else after:
        resolved_body = resolved_journey_body(step, previous_query)
        raw_request = encoded(resolved_body)
        raw_reply = exchange(step['endpoint'], raw=raw_request)
        reply = json.loads(raw_reply)
        if reply.get('outcome') != 'completed':
            raise ValueError('journey step did not complete')
        for path, expected in step['expected'].items():
            if pointer(reply, path) != expected:
                raise ValueError('journey independent assertion failed: ' + path)
        records.append({'step': step, 'resolved_body': resolved_body, 'response': reply, 'response_sha256': digest(raw_reply)})
        previous_query = reply if step['endpoint'] == '/query' else None
    if phase == 'before':
        if exchange(step['endpoint'], raw=raw_request) != raw_reply:
            raise ValueError('same-launch exact retry differs from acknowledgement')
        saved = {'identity': identity, 'endpoint': step['endpoint'],
                 'request_base64': base64.b64encode(raw_request).decode(),
                 'response_base64': base64.b64encode(raw_reply).decode()}
        descriptor = os.open(checkpoint, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, 'wb') as stream:
            stream.write(encoded(saved))
    return {'schema': 'oracle-native-consumer-journey-v1', 'phase': phase, 'status': 'passed',
            'identity': identity, 'capabilities': capabilities, 'health': health, 'steps': records,
            'scope': 'supplied native-only consumer assertions and exact acknowledgement retry; central controls actual restart and records its process evidence'}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--bundle', required=True)
    ap.add_argument('--url', required=True)
    ap.add_argument('--cases', required=True, help='provider cases or two-phase native journey JSON')
    ap.add_argument('--journey-phase', choices=['before', 'after'])
    ap.add_argument('--checkpoint', help='new external checkpoint before restart, retained checkpoint after')
    ap.add_argument('--tenant', default='a' * 64)
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    cases = json.loads(read_regular(a.cases))
    if a.journey_phase:
        if not a.checkpoint:
            ap.error('--journey-phase requires --checkpoint')
        receipt = native_journey(a.bundle, a.url, cases, a.tenant, a.journey_phase, a.checkpoint)
    else:
        receipt = qualify(a.bundle, a.url, cases, a.tenant)
    with clean_path(a.out).open('xb') as stream:
        stream.write(encoded(receipt))

if __name__ == '__main__':
    main()
