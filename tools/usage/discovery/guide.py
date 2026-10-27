#!/usr/bin/env python3
"""Untrusted, read-only caller guide; declarations and historical runs are not proof.

Reads JSON data without importing the Oracle launcher or any specialist code.
Does not answer questions, rewrite replies, run engines, or claim panel scores.
"""
from __future__ import annotations

import argparse
from decimal import Decimal, InvalidOperation
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
DEFAULT_RUNTIME = HERE.parents[2] / 'var/appliance-20261026/candidate'
IDENTIFIER = re.compile(r'[A-Za-z0-9_-]{1,80}\Z')


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'))


def local_path(runtime, name):
    """Accept only files inside the selected runtime, including symlink targets."""
    runtime = Path(runtime).resolve()
    path = (runtime / name).resolve()
    if not path.is_relative_to(runtime):
        raise ValueError(f'source path escapes runtime: {name}')
    return path


def source_ref(runtime, path):
    return {'path': str(path.relative_to(runtime)),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def observations(query=''):
    data = read_json(HERE / 'observations.json')
    terms = set(re.findall(r'[a-z0-9]+', query.lower()))
    rows = [r for r in data['cases'] if not terms or terms.intersection(
        re.findall(r'[a-z0-9]+', (' '.join(r['topics']) + ' ' + r['text']).lower()))]
    return {'scope': data['scope'], 'runtime_identity': data['runtime_identity'],
            'cases': rows}


def catalog(runtime, query='', limit=8, examples=2):
    """Return searchable declared tasks with dev examples and historical observations."""
    if not 1 <= limit <= 300 or not 0 <= examples <= 10:
        raise ValueError('limit must be 1..300 and examples 0..10')
    runtime = Path(runtime).resolve()
    index_path = local_path(runtime, 'workbench/data/specialists.json')
    index = read_json(index_path)
    terms = set(re.findall(r'[a-z0-9]+', query.lower()))
    historical = observations()
    matches = []
    for item in index['items']:
        manifest_path = local_path(runtime, f"root/specialists/{item['id']}/manifest.json")
        manifest = read_json(manifest_path) if manifest_path.exists() else {}
        searchable = ' '.join([item['id'], item['name'], item.get('group', ''),
                               *item.get('takes', []), *manifest.get('routing_cues', [])]).lower()
        words = set(re.findall(r'[a-z0-9]+', searchable))
        id_words = set(re.findall(r'[a-z0-9]+', item['id'].lower()))
        name_words = set(re.findall(r'[a-z0-9]+', item['name'].lower()))
        score = 10 * len(terms.intersection(id_words)) + 2 * len(terms.intersection(name_words)) + len(terms.intersection(words))
        if terms and not score:
            continue
        matches.append((score, item, manifest, manifest_path))
    matches.sort(key=lambda x: (-x[0], x[1]['id']))
    result = []
    for _, item, manifest, manifest_path in matches[:limit]:
        entry = {'id': item['id'], 'name': item['name'], 'group': item.get('group'),
                 'evidence_level': 'declared_not_measured_here',
                 'declared_tasks': manifest.get('accept', {}).get('kinds', item.get('takes', [])),
                 'declared_declines': manifest.get('accept', {}).get('declines_in_domain', []),
                 'routing_cues': manifest.get('routing_cues', []),
                 'sources': manifest.get('sources', []), 'examples': [],
                 'declaration_source': source_ref(runtime, manifest_path) if manifest else source_ref(runtime, index_path)}
        panel_name = manifest.get('panel', {}).get('path')
        if panel_name and examples:
            prefix = '__ORACLE7_ROOT__/'
            # Support release manifests, without following arbitrary absolute paths.
            name = 'root/' + panel_name[len(prefix):] if panel_name.startswith(prefix) else panel_name
            panel_path = local_path(runtime, name)
            if panel_path.exists():
                for row in read_json(panel_path):
                    if (row.get('split') == 'dev' and row.get('valid') is True
                            and row.get('kind') in entry['declared_tasks'] and isinstance(row.get('q'), str)):
                        entry['examples'].append({'text': row['q'], 'kind': row['kind'],
                                                  'evidence_level': 'declared_dev_example',
                                                  'historical_exact_request_ids': [r['id'] for r in historical['cases'] if r['text'] == row['q']],
                                                  'source': source_ref(runtime, panel_path)})
                        if len(entry['examples']) == examples:
                            break
        result.append(entry)
    return {'schema': 'oracle-request-guide-v1', 'query': query,
            'meaning': 'Search of shipped declarations, not a guarantee that the adapter routes these tasks.',
            'index_source': source_ref(runtime, index_path), 'matching_declarations': len(matches),
            'declarations': result, 'historical_measurements': observations(query),
            'caller_rules': [
                'Use a concrete question with named entities or quantities and units.',
                'If a required quantity is missing, ask for it; do not invent it.',
                'Read status and the entire reply. answered alone does not establish task completion.',
                'Keep references and provenance; upstream verified labels are not Mini authority.',
                'A refusal is not evidence that the requested fact is false or absent from every store.',
                'Dev examples are declarations. historical_exact_request_ids links exact earlier trials; an empty list means no trial retained here.',
                'Historical measurements apply only to their exact requests and recorded deployment; receipt metadata does not verify current file contents.']}


def prepare_conversion(amount=None, from_unit=None, to_unit=None,
                       request_id='conversion-1', conversation_id='conversion'):
    """Ask for missing inputs; produce a request only with explicit caller values."""
    if not IDENTIFIER.fullmatch(request_id) or not IDENTIFIER.fullmatch(conversation_id):
        raise ValueError('IDs require 1..80 ASCII letters, digits, underscores or hyphens')
    values = {'amount': amount, 'from_unit': from_unit, 'to_unit': to_unit}
    missing = [key for key, value in values.items() if value is None or not str(value).strip()]
    if missing:
        questions = {'amount': 'What amount should be converted?',
                     'from_unit': 'What unit is that amount measured in?',
                     'to_unit': 'What unit do you want in the answer?'}
        return {'outcome': 'needs_input', 'missing': missing,
                'questions': [questions[k] for k in missing], 'request': None}
    amount = str(amount).strip()
    if len(amount) > 100 or not re.fullmatch(r'[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?', amount):
        raise ValueError('amount must be a finite decimal number, without units')
    try:
        if not Decimal(amount).is_finite():
            raise ValueError('amount must be finite')
    except InvalidOperation:
        raise ValueError('amount must be a finite decimal number') from None
    from_unit, to_unit = str(from_unit).strip(), str(to_unit).strip()
    for unit in (from_unit, to_unit):
        if len(unit) > 80 or not re.fullmatch(r'[A-Za-z°µμΩ][A-Za-z0-9°µμΩ /^²³_-]*', unit):
            raise ValueError('units must be short unit names or symbols, without instructions')
    text = f'Convert {amount} {from_unit} to {to_unit}.'
    exact = [r['id'] for r in observations()['cases'] if r['text'] == text]
    return {'outcome': 'prepared', 'request': {'request_id': request_id,
            'conversation_id': conversation_id, 'text': text},
            'runner_case': {'id': request_id, 'conversation_id': conversation_id, 'text': text},
            'historical_exact_request_ids': exact,
            'support': 'Request shape only; supported units, dimensional compatibility, and the answer must be checked by the engine.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    cat = sub.add_parser('catalog', help='Search declared tasks and retained exact-request measurements')
    cat.add_argument('query', nargs='?', default='')
    cat.add_argument('--runtime', type=Path, default=DEFAULT_RUNTIME)
    cat.add_argument('--limit', type=int, default=8)
    cat.add_argument('--examples', type=int, default=2)
    prep = sub.add_parser('convert', help='Prepare a unit-conversion request, or ask for missing inputs')
    prep.add_argument('--amount')
    prep.add_argument('--from-unit')
    prep.add_argument('--to-unit')
    prep.add_argument('--id', default='conversion-1')
    prep.add_argument('--conversation-id', default='conversion')
    prep.add_argument('--cases', action='store_true', help='Emit a runner case array; fail if input is missing')
    args = parser.parse_args()
    try:
        if args.command == 'catalog':
            result = catalog(args.runtime, args.query, args.limit, args.examples)
        else:
            result = prepare_conversion(args.amount, args.from_unit, args.to_unit, args.id, args.conversation_id)
            if args.cases:
                if result['request'] is None:
                    parser.error('missing conversion inputs: ' + ', '.join(result['missing']))
                result = [result['runner_case']]
        print(json.dumps(result, indent=2, ensure_ascii=False))
    except (ValueError, OSError, KeyError) as exc:
        parser.error(str(exc))


if __name__ == '__main__':
    main()
