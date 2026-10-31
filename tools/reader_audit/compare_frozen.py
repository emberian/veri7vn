#!/usr/bin/env python3
"""Untrusted frozen four-way reader comparison, retaining complete native replies.

Manifest supplies pinned artifacts, original retained100 list and targeted16.
Each cell runs in a fresh child. Dataset answers are labeled as such; only
source-verified targeted cases qualify as independent semantic checks.
No template/form/agreement policy is changed. No source program is executed.
"""
import argparse
from collections import Counter
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import sqlite3

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'native/tests'))
import qualify_reader as common
import qualify_composition_cases as targeted

CELLS = {'baseline': ('control', 'control'), 'code_only': ('candidate', 'control'),
         'data_only': ('control', 'candidate'), 'combined': ('candidate', 'candidate')}

def bound(item):
    path = Path(item['path']).resolve()
    if common.digest(path) != item['sha256']:
        raise ValueError(f'frozen artifact differs: {path}')
    return path

def cases(manifest):
    retained = common.read_json(bound(manifest['retained100']), 16 * 1024 * 1024)
    cohort = common.read_json(bound(manifest['targeted16']), 256 * 1024)
    if len(retained) != 100 or len(cohort['cases']) != 16:
        raise ValueError('must retain all original 100 + 16 cases')
    out = [{'id': f"retained100:{c['source_index']}", 'question': c['question'],
            'expected': {'answer': c['gold'], 'kind': 'dataset_gold'}, 'source': c} for c in retained]
    out += [dict(c, id='targeted16:' + c['id']) for c in cohort['cases']]
    if len(set(c['id'] for c in out)) != 116:
        raise ValueError('repeated frozen case identity')
    return out, cohort

def child(a, manifest):
    code, data = CELLS[a.cell]
    extension = bound(manifest['extensions'][code])
    image_path = bound(manifest['images'][data])
    spec = importlib.util.spec_from_file_location('oracle_native', str(extension))
    native = importlib.util.module_from_spec(spec)
    sys.modules['oracle_native'] = native
    spec.loader.exec_module(native)
    image = native.Image(str(image_path), manifest['images'][data]['sha256'], common.canonical(manifest['limits']))
    runtime = native.Runtime.from_image(image, str(a.work / 'state.sqlite'))
    observations = []
    for i, c in enumerate(cases(manifest)[0]):
        # Fresh tenant prevents Previous from leaking between independent cases.
        tenant = runtime.tenant(f'frozen_{i}')
        try:
            result = json.loads(tenant.read_whole(c['question'], native.Cancellation()))
            if result['coverage'] != manifest['extensions'][code]['coverage']:
                raise ValueError('coverage differs from frozen declaration')
            expected = c['expected']
            if result['status'] not in ('answered', 'unknown', 'refused', 'ambiguous'):
                raise ValueError('invalid reader status')
            if result['status'] == 'answered' and (not isinstance(result.get('answer'), str)
                    or result.get('distinct_answers') != [result['answer']] or result.get('reason') is not None):
                raise ValueError('malformed agreed answer')
            if result['status'] != 'answered' and (result.get('answer') is not None or not isinstance(result.get('reason'), str)):
                raise ValueError('malformed reader decline')
            if result['status'] == 'answered':
                correct = result['answer'] == expected['answer'] and not expected['kind'].startswith('decline_')
                ids = expected.get('entity_ids')
                if ids is not None:
                    # Require every successful interpretation to select intended
                    # referents, even when two sets happen to print the same name.
                    correct &= bool(result['readings']) and all(sorted(r['result']['entities']) == sorted(ids) for r in result['readings'])
                outcome = 'answered_correct' if correct else 'answered_wrong'
            else:
                outcome = 'declined_expected' if expected['kind'].startswith('decline_') else 'unanswered'
            observation = {'id': c['id'], 'outcome': outcome, 'result': result}
        except Exception as e:
            observation = {'id': c['id'], 'outcome': 'errors', 'error_type': type(e).__name__, 'error': str(e)}
        observations.append(observation)
        if image.active_workers:
            raise RuntimeError('reader retained an active worker after serial call')
    common.write_json(a.work / 'observations.json', observations)

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--manifest', type=Path, required=True)
    p.add_argument('--work', type=Path, required=True)
    p.add_argument('--cell', choices=CELLS, help=argparse.SUPPRESS)
    a = p.parse_args()
    manifest = common.read_json(a.manifest, 256 * 1024)
    all_cases, cohort = cases(manifest)
    if a.cell:
        child(a, manifest)
        return
    for category in ('extensions', 'images'):
        for artifact in manifest[category].values():
            bound(artifact)
    a.work.mkdir(parents=True, exist_ok=False)
    # A grammar-only image replacement must preserve the finite fact universe.
    # Compare source metadata first; the builder's KB pin/receipt is mandatory
    # additional provenance, rather than trusting equality of printed answers.
    sources = []
    for artifact in manifest['images'].values():
        with sqlite3.connect(bound(artifact).as_uri() + '?mode=ro&immutable=1', uri=True) as db:
            db.execute('PRAGMA query_only=ON')
            sources.append(db.execute("SELECT value FROM metadata WHERE key='source_sha256'").fetchone())
    if any(source != (cohort['image']['source_sha256'],) for source in sources):
        raise ValueError('four-way images do not share the pinned source KB')
    # Ground truth uses ORIGINAL source image. Candidate grammar changes must
    # not rewrite expected referents, wording availability or source evidence.
    evidence = targeted.verify_source(cohort, bound(manifest['images']['control']))
    common.write_json(a.work / 'source-evidence.json', evidence)
    common.write_json(a.work / 'cases.json', all_cases)
    common.write_json(a.work / 'manifest.json', manifest)
    reports, observations = {}, {}
    for cell in CELLS:
        work = a.work / cell
        work.mkdir()
        command = [sys.executable, '-B', str(Path(__file__).resolve()), '--manifest', str(a.manifest.resolve()),
                   '--work', str(work.resolve()), '--cell', cell]
        with (work / 'stdout').open('x') as out, (work / 'stderr').open('x') as err:
            process = subprocess.run(command, stdout=out, stderr=err, timeout=manifest.get('process_timeout_seconds', 600))
        if process.returncode:
            raise RuntimeError(f'{cell} child failed; retained stdout/stderr')
        rows = common.read_json(work / 'observations.json', 128 * 1024 * 1024)
        if [r['id'] for r in rows] != [c['id'] for c in all_cases]:
            raise ValueError('child changed frozen cohort/order')
        reports[cell] = {prefix: dict(Counter(r['outcome'] for r in rows if r['id'].startswith(prefix))) for prefix in ('retained100:', 'targeted16:')}
        observations[cell] = rows
    def semantic(row):
        if 'result' not in row:
            return row
        result = row['result']
        keys = ('status', 'reason', 'answer', 'distinct_answers', 'unsupported_programs', 'ambiguous_executions')
        value = {k: result.get(k) for k in keys}
        # Derivation ordering and support can change with learning; retain full
        # originals and compare distinct denotations/evidence without those.
        value['readings'] = sorted({common.canonical({
            'program': r['program'], 'answer': r['answer'],
            'result': {k: v for k, v in r['result'].items() if k not in ('image', 'coverage')}
        }) for r in result.get('readings', [])})
        return value
    comparisons = {}
    for before, after in (('baseline', 'code_only'), ('baseline', 'data_only'), ('data_only', 'combined'), ('baseline', 'combined')):
        comparisons[before + '_to_' + after] = [
            {'id': old['id'], 'before': old['outcome'], 'after': new['outcome']}
            for old, new in zip(observations[before], observations[after], strict=True)
            if semantic(old) != semantic(new)]
    common.write_json(a.work / 'summary.json', {'counts': reports,
        'changed_semantics_or_evidence': comparisons,
        'scope': 'finite reader cohorts; no shipped specialist panel score; retained100 are dataset text controls, targeted16 additionally require source-verified entity sets',
        'comparison': 'Complete readings/programs/entities/facts/attributes retained in each observations.json; review evidence and changed refusal obligations before accepting code equivalence.'})
    print(json.dumps(reports, indent=2))
    if any(r['outcome'] in ('answered_wrong', 'errors') for rows in observations.values() for r in rows):
        raise SystemExit(1)

if __name__ == '__main__':
    main()
