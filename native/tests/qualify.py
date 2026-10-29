#!/usr/bin/env python3
"""Untrusted Linux qualification harness, not a proof or an Oracle head scorer.

Runs the pinned upstream KQA and native reader in separate fresh processes so
reference data preparation cannot contaminate native memory measurements. Loads
only the explicitly supplied trusted steps_kb source, never an Oracle Engine.
"""
import argparse
import hashlib
import importlib.util
import json
import os
import platform
from pathlib import Path
import statistics
import subprocess
import sys
import time


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def memory():
    result = {}
    for path, keys in [('/proc/self/smaps_rollup', {'Pss', 'Private_Dirty', 'Private_Clean'}),
                       ('/proc/self/status', {'VmRSS', 'VmHWM', 'Threads'})]:
        for line in Path(path).read_text().splitlines():
            key, _, value = line.partition(':')
            if key in keys:
                result[key] = int(value.split()[0])
    return result


def reference(kqa, plan):
    values = []
    for step in plan['nodes']:
        op = step['op']
        if op == 'find':
            result = kqa.Find(step['name'])
        elif op == 'all':
            result = kqa.FindAll()
        elif op == 'relate':
            result = kqa.Relate(values[step['input']], step['predicate'], step['direction'])
        elif op == 'filter_concept':
            result = kqa.FilterConcept(values[step['input']], step['name'])
        else:
            raise ValueError(op)
        values.append(result)
    ids, facts = values[plan['output']]
    # Compare qualifier multiplicity per resulting entity, not arbitrary set order.
    return {'entities': sorted(ids), 'qualifiers': sorted(
        (entity, json.dumps(q, sort_keys=True, separators=(',', ':')))
        for entity, qs in facts.items() for q in qs)}


def make_cases(kqa, count):
    choices = []
    for subject in sorted(kqa.rel):
        for predicate, direction, _, _ in kqa.rel[subject]:
            choices.append((kqa.name(subject), predicate, direction))
    choices = sorted(set(choices))
    if not choices:
        raise ValueError('reference knowledge base contains no relations')
    cases = []
    for i in range(count):
        name, predicate, direction = choices[i * len(choices) // count]
        plan = {'nodes': [{'op': 'find', 'name': name},
                          {'op': 'relate', 'input': 0, 'predicate': predicate, 'direction': direction}],
                'output': 1, 'projection': {'kind': 'entities'}}
        cases.append({'plan': plan, 'expected': reference(kqa, plan)})
    concepts = sorted(kqa.cname)
    for i in range(min(32, len(concepts))):
        plan = {'nodes': [{'op': 'all'}, {'op': 'filter_concept', 'input': 0,
                                        'name': concepts[i * len(concepts) // min(32, len(concepts))]}],
                'output': 1, 'projection': {'kind': 'count'}}
        cases.append({'plan': plan, 'expected': reference(kqa, plan)})
    return cases


def native_signature(result):
    return {'entities': result['entities'], 'qualifiers': sorted(
        (f['object'], json.dumps(json.loads(f['qualifiers_json']), sort_keys=True, separators=(',', ':')))
        for f in result['facts'])}


def child(args):
    work = Path(args.work)
    if args.mode == 'prepare':
        steps = load_module('steps_kb_reference', args.steps)
        kqa = steps.KQA(args.source)
        cases = make_cases(kqa, args.cases)
        (work / 'cases.json').write_text(json.dumps(cases))
        return {'cases': len(cases), 'entities': len(kqa.ents), 'concepts': len(kqa.concepts)}
    cases = json.loads((work / 'cases.json').read_text())
    before = memory()
    started = time.perf_counter()
    if args.mode == 'reference':
        steps = load_module('steps_kb_reference', args.steps)
        kqa = steps.KQA(args.source)
    else:
        native = load_module('oracle_native', args.extension)
        receipt = json.loads((work / 'image-receipt.json').read_text())
        runtime = native.Runtime(str(work / 'image.sqlite'), receipt['image_sha256'],
                                 str(work / (args.mode + '-state.sqlite')),
                                 json.dumps({'workers': 2, 'timeout_ms': 10000}))
        client = runtime.tenant('qualification')
    ready_seconds = time.perf_counter() - started
    ready = memory()
    latencies, failures = [], []
    for i, case in enumerate(cases):
        started = time.perf_counter()
        if args.mode == 'reference':
            got = reference(kqa, case['plan'])
        else:
            text = json.dumps(case['plan'])
            result = json.loads(client.query(text, native.Cancellation()))
            got = native_signature(result)
        latencies.append(time.perf_counter() - started)
        # JSON round-trip normalizes tuples in the reference and retained expectations.
        if json.loads(json.dumps(got)) != case['expected']:
            failures.append(i)
    tenant_samples = []
    if args.mode == 'native':
        plan = json.dumps(cases[0]['plan'])
        handles = []
        for i in range(256):
            handles.append(runtime.tenant(f'tenant_{i}'))
            reply = handles[-1].execute('s', 'one', 0, plan, native.Cancellation())
            # Identical request IDs are independent across tenants; every new state is v1.
            assert json.loads(reply)['version'] == 1
            if i + 1 in (1, 16, 64, 256):
                tenant_samples.append({'tenants': i + 1, 'memory_kib': memory()})
        assert handles[0].execute('s', 'one', 0, plan, native.Cancellation()) == reply
    return {'mode': args.mode, 'cases': len(cases), 'wrong': len(failures), 'failure_indices': failures,
            'ready_seconds': ready_seconds, 'query_seconds_p50': statistics.median(latencies),
            'query_seconds_p95': sorted(latencies)[int(.95 * (len(latencies)-1))],
            'before_memory_kib': before, 'ready_memory_kib': ready, 'after_memory_kib': memory(),
            'tenant_samples': tenant_samples}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--extension', required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--steps', required=True)
    parser.add_argument('--work', required=True)
    parser.add_argument('--cases', type=int, default=256)
    parser.add_argument('--reuse-image', help='prior qualification directory; image remains immutable')
    parser.add_argument('--mode', choices=['prepare', 'reference', 'native'])
    args = parser.parse_args()
    if args.cases < 1:
        parser.error('cases must be positive')
    if args.mode:
        print(json.dumps(child(args)))
        return
    work = Path(args.work)
    work.mkdir(parents=True, exist_ok=False)
    command = [sys.executable, '-B', __file__, '--extension', args.extension, '--source', args.source,
               '--steps', args.steps, '--work', args.work, '--cases', str(args.cases)]
    prepared = json.loads(subprocess.check_output(command + ['--mode', 'prepare'], timeout=120))
    if args.reuse_image:
        prior = Path(args.reuse_image)
        receipt = json.loads((prior / 'image-receipt.json').read_text())
        with open(args.source, 'rb') as source:
            source_hash = hashlib.file_digest(source, 'sha256').hexdigest()
        if receipt['source_sha256'] != source_hash:
            raise ValueError('reused image source mismatch')
        os.link(prior / 'image.sqlite', work / 'image.sqlite')
        receipt['reused_image'] = True
    else:
        native = load_module('oracle_native', args.extension)
        started = time.perf_counter()
        receipt = json.loads(native.build_image(args.source, str(work / 'image.sqlite'), 512 * 1024 * 1024, 16 * 1024 * 1024))
        receipt['build_seconds'] = time.perf_counter() - started
    (work / 'image-receipt.json').write_text(json.dumps(receipt, indent=2))
    results = [json.loads(subprocess.check_output(command + ['--mode', mode], timeout=120))
               for mode in ('reference', 'native')]
    report = {'schema': 'oracle-native-qualification-v1', 'scope': 'KQA data access, not full Oracle or specialist panels',
              'extension_sha256': hashlib.sha256(Path(args.extension).read_bytes()).hexdigest(),
              'cases_sha256': hashlib.sha256((work / 'cases.json').read_bytes()).hexdigest(),
              'python': sys.version, 'platform': platform.platform(), 'load_average': os.getloadavg(),
              'steps_sha256': hashlib.sha256(Path(args.steps).read_bytes()).hexdigest(),
              'preparation': prepared, 'image': receipt, 'results': results}
    (work / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    if any(r['wrong'] for r in results):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
