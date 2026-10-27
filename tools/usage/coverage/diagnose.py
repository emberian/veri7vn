#!/usr/bin/env python3
"""Untrusted, read-only coverage triage; neither an answerer nor proof authority.

Operator-supplied entity/property hypotheses select bounded indexed probes.
A row's presence does not establish relevance, truth, uniqueness, or completeness.
Missing rows never establish that a real-world proposition is false.
"""
import argparse
import json
from pathlib import Path
import re
import sqlite3
import unicodedata

ROOT = Path(__file__).resolve().parents[3]
DISCLAIMER = ('Store observations only: absence is not falsity; rows are not proof of '
              'truth, uniqueness, completeness, or suitability for the question.')


def norm(text):
    # Same normalization as the shipped entity_linker_v1; do not silently repair it.
    text = unicodedata.normalize('NFKD', str(text))
    text = ''.join(c for c in text if not unicodedata.combining(c)).lower()
    return ' '.join(re.findall(r'[a-z0-9]+', text))


def connect(path):
    db = sqlite3.connect(Path(path).resolve().as_uri() + '?mode=ro&immutable=1', uri=True)
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA query_only=ON')
    # Fail closed on unexpected schemas/plans rather than scan a huge store.
    calls = 0
    def budget():
        nonlocal calls
        calls += 1
        return calls > 1000  # one million VM instructions per connection
    db.set_progress_handler(budget, 1000)
    return db


def probe(names, relations, spec):
    name = spec['entity_name']
    qid, prop = spec.get('expected_qid'), spec.get('property')
    if qid is not None and (type(qid) is not int or qid <= 0):
        raise ValueError('expected_qid must be a positive integer or null')
    if prop is not None and (type(prop) is not int or prop <= 0):
        raise ValueError('property must be a positive integer or null')
    if not isinstance(name, str) or len(name) > 500:
        raise ValueError('entity_name must be a string up to 500 characters')
    # LIMIT protects output; the progress handler bounds work even for common aliases.
    candidates = [dict(r) for r in names.execute('''
        SELECT qid, MAX(links) AS links, MIN(alias) AS alias FROM name INDEXED BY name_norm
        WHERE norm=? GROUP BY qid ORDER BY MAX(links) DESC LIMIT 9''', (norm(name),))]
    truncated = len(candidates) > 8
    candidates = candidates[:8]
    for candidate in candidates:
        label = names.execute('SELECT label FROM label WHERE qid=?', (candidate['qid'],)).fetchone()
        candidate['label'] = label['label'] if label else None
    entity = relations.execute('SELECT qid,label,enwiki FROM entity WHERE qid=?', (qid,)).fetchone() if qid else None
    metadata = relations.execute('SELECT * FROM prop_src WHERE p=?', (prop,)).fetchone() if prop else None
    property_seen = bool(relations.execute('SELECT 1 FROM fact INDEXED BY fact_po WHERE p=? LIMIT 1', (prop,)).fetchone()) if prop else None
    # Exhaustive inverse lists need a different coverage contract; a forward probe is irrelevant.
    values = []
    if qid and prop and spec.get('operation') != 'enumerate_all':
        values = [dict(r) for r in relations.execute('SELECT o,lit FROM fact INDEXED BY fact_sp WHERE s=? AND p=? LIMIT 17', (qid, prop))]
    values_truncated = len(values) > 16
    values = values[:16]
    for value in values:
        label = relations.execute('SELECT label FROM entity WHERE qid=?', (value['o'],)).fetchone() if value['o'] else None
        value['label'] = label['label'] if label else None
    return {'entity_name': name, 'normalized_name': norm(name), 'candidates': candidates,
            'candidates_truncated': truncated, 'expected_entity': dict(entity) if entity else None,
            'property': prop, 'property_metadata': dict(metadata) if metadata else None,
            'property_has_any_rows': property_seen, 'values': values, 'values_truncated': values_truncated}


def classify(spec, reply, evidence):
    """Suggest an investigation; never replace the original reply or score truth."""
    qid = spec.get('expected_qid')
    observed = reply.get('provenance', {}).get('subject_qid')
    if observed and qid and observed != f'Q{qid}':
        return 'entity_mismatch', 'Investigate partial-name linking: returned subject differs from the operator-intended entity; add a sourced alias and require unresolved name tokens to be accounted for.'
    if spec.get('operation') == 'ambiguous':
        return 'ambiguous_question', 'Ask which entity is meant before choosing a fact; candidate popularity is not disambiguation.'
    if spec.get('operation') == 'enumerate_all':
        return 'unsupported_coverage_operation', 'Define the edition/time/domain scope and obtain an explicit complete inventory before claiming every item; offer a clearly labeled sample otherwise.'
    if reply.get('status') == 'answered':
        return 'answer_requires_review', 'Compare the original response and requested relation/qualifiers with the independent source; answering does not establish correctness.'
    if spec.get('operation') == 'qualified':
        return 'qualifier_not_covered', 'Check a source for the requested event qualifier; an unqualified property row cannot establish the qualified answer.'
    if evidence['expected_entity'] is None:
        return 'entity_not_in_relation_store', 'Resolve the entity ID independently and obtain a sourced entity record; do not infer nonexistence.'
    if evidence['values']:
        if not any(c['qid'] == qid for c in evidence['candidates']):
            return 'alias_resolution_gap', 'The intended entity has relation rows but is absent from this bounded exact-name candidate list; verify/add the alias and inspect linker selection.'
        return 'stored_fact_not_reached', 'The intended name and relation rows exist: inspect parsing, relation routing, admission and evidence fit before importing duplicate data.'
    if evidence['property_has_any_rows'] is False:
        return 'relation_not_in_store', 'This property has no rows in the selected store; inspect its import policy and add primary-source-backed coverage before retrying.'
    return 'entity_relation_not_in_store', 'The property exists elsewhere but this entity/property pair has no rows; acquire a relevant source record after confirming the operator mapping.'


def diagnose(runtime, cases, results):
    store = runtime / 'root/relstore'
    names, relations = connect(store / 'names_v1.sqlite3'), connect(store / 'relations_v2.sqlite3')
    output = []
    try:
        for spec in cases:
            result = results.get(spec['id'])
            if result is None:
                output.append({'id': spec['id'], 'category': 'not_run', 'action': 'Run this case before diagnosing behavior.'})
                continue
            reply = result.get('response', {}).get('reply', {})
            if result.get('state') != 'response' or not reply:
                output.append({'id': spec['id'], 'category': 'transport_or_backend_failure', 'action': 'Inspect the original runner failure before attributing it to knowledge coverage.'})
                continue
            evidence = probe(names, relations, spec)
            category, action = classify(spec, reply, evidence)
            output.append({'id': spec['id'], 'category': category, 'action': action,
                           'source_to_check': spec.get('source'), 'expected': spec['expected'],
                           'original_status': reply.get('status'), 'original_path': reply.get('path'),
                           'original_response': reply.get('response'), 'observations': evidence})
    finally:
        names.close()
        relations.close()
    manifest = json.loads((runtime / 'APPLIANCE.json').read_text())
    return {'disclaimer': DISCLAIMER, 'runtime': str(runtime),
            'release': {k: manifest.get(k) for k in ('profile', 'source_revision')},
            'store_metadata': [s for s in manifest.get('stores', []) if s['path'] in ('root/relstore/names_v1.sqlite3', 'root/relstore/relations_v2.sqlite3')],
            'hash_note': 'Hashes are package manifest declarations, not newly computed integrity checks.', 'cases': output}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', type=Path, default=ROOT / 'var/appliance-20261026/candidate')
    parser.add_argument('--expectations', type=Path, required=True)
    parser.add_argument('--results', type=Path, required=True)
    args = parser.parse_args()
    cases = json.loads(args.expectations.read_text())['cases']
    if not 1 <= len(cases) <= 30:
        parser.error('expectations must contain 1..30 cases')
    results = {}
    for line in args.results.read_text().splitlines():
        row = json.loads(line)
        if row['id'] in results:
            parser.error('duplicate result IDs need separate analysis, not silent overwrite')
        results[row['id']] = row
    print(json.dumps(diagnose(args.runtime.resolve(), cases, results), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
