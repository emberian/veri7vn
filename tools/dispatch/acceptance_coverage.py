#!/usr/bin/env python3
"""Replay existing shipped-panel receipts through the current acceptance gate.

UNTRUSTED diagnostic, not a new correctness proof or fleet run. Receipt panel
hashes must match the current shipped questions. Recorded binaries may be old;
mtime chooses a receipt, not the current implementation. Optional issue probes
run only selected direct/composed questions, never the head or a full panel.
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path[:0] = [str(HERE), str(REPO / 'tools'), str(REPO / 'tools/parity')]
import dispatch as D
import panels
from runtime_contract import load_registry, validate_capabilities


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def classify(entry, sid, question, reply):
    """Use the dispatcher's own gate; labels explain why a reply was rejected."""
    problem = D.reply_shape_error(reply)
    if problem or 'error' in reply:
        return {'category': 'error', 'detail': problem or reply['error']}
    provenance = reply.get('provenance', {})
    if provenance.get('taken') is not True:
        return {'category': 'not_taken', 'detail': 'explicit_false' if provenance.get('taken') is False else 'marker_missing'}
    obj = D.Dispatcher.__new__(D.Dispatcher)
    family = entry['family']
    obj.entries = {family: entry}
    obj.organs = [(None, family)]
    obj.pins = {}
    candidates = obj.organ_cands(question, '', 'replay', {family: reply})
    obj.pins = {family: sid}
    pinned = bool(obj.organ_cands(question, '', 'replay', {family: reply}))
    scope = {'family_accepted': bool(candidates), 'pinned_accepted': pinned}
    rsid = D.specialist_of(reply.get('path', ''))
    kind = reply.get('kind', '')
    if candidates:
        candidate = candidates[0]
        man = D.manifest(rsid)
        category = ('accepted_answer' if not candidate['declined'] else
                    'accepted_normal_refusal' if kind in man['kinds'] else 'accepted_context_refusal')
        return {'category': category, 'pinned_id_matches': rsid == sid, 'reply_specialist': rsid, **scope}
    if rsid not in entry['specialists']:
        return {'category': 'foreign_specialist', 'reply_specialist': rsid, **scope}
    man = D.manifest(rsid)
    return {'category': 'dropped_context' if kind in man['declines'] else 'dropped_kind',
            'reply_specialist': rsid, **scope}


def discover(owners, corpus):
    choices = collections.defaultdict(list)
    skipped = collections.Counter()
    files = subprocess.check_output(['rg', '--files', '--hidden', '--no-ignore', 'var'],
                                    cwd=REPO, text=True).splitlines()
    for name in files:
        p = REPO / name
        match = re.fullmatch(r'(.+)\.(dev|heldout)\.items\.jsonl', p.name)
        if not match or match[1] not in owners:
            continue
        sid, split = match.groups()
        vp = p.with_name(f'{sid}.{split}.json')
        try:
            verdict = json.loads(vp.read_text())
        except (OSError, ValueError):
            skipped['missing_or_invalid_verdict'] += 1
            continue
        items, fingerprint = corpus[sid, split]
        if verdict.get('panel_sha') != fingerprint or verdict.get('n') != len(items):
            skipped['different_or_partial_panel'] += 1
            continue
        cmd = ' '.join(verdict.get('answerer') or [])
        # These commands are composed/head/reference records, not direct family
        # outputs. Do not turn their wrappers' refusals into a kernel diagnosis.
        if any(s in cmd for s in ('dispatch.py', 'oracle7.py', 'organs', 'shipped')):
            skipped['composed_or_reference'] += 1
            continue
        family = owners[sid]['family']
        if f'/{family}/' not in '/' + str(p.parent.relative_to(REPO)) + '/' and f'/{family}/bin/' not in cmd:
            skipped['owner_not_identified'] += 1
            continue
        choices[sid, split].append((p.stat().st_mtime_ns, p, verdict))
    return choices, dict(skipped)


def receipt_records(path, expected_ids):
    """Require the actual reply rows, not only the scorer sidecar, to be complete."""
    expected = set(expected_ids)
    records, diagnostics = [], []
    try:
        lines = [(index, line) for index, line in enumerate(path.read_text().splitlines(), 1)
                 if line.strip()]
    except OSError as error:
        return None, [{'kind': 'unreadable_receipt', 'detail': str(error)}]
    if len(lines) != len(expected_ids):
        diagnostics.append({'kind': 'record_count', 'expected': len(expected_ids), 'actual': len(lines)})
    for line_number, line in lines:
        try:
            record = json.loads(line)
        except ValueError as error:
            diagnostics.append({'kind': 'malformed_json', 'line': line_number, 'detail': str(error)})
            continue
        if (not isinstance(record, dict) or not isinstance(record.get('id'), str) or
                not isinstance(record.get('reply'), dict)):
            diagnostics.append({'kind': 'malformed_record', 'line': line_number,
                                'detail': 'expected an object with string id and object reply'})
            continue
        records.append(record)
    counts = collections.Counter(record['id'] for record in records)
    for rid, count in sorted(counts.items()):
        if count != 1:
            diagnostics.append({'kind': 'duplicate_id', 'id': rid, 'count': count})
    missing, extra = expected - counts.keys(), counts.keys() - expected
    if missing:
        diagnostics.append({'kind': 'missing_ids', 'ids': sorted(missing)})
    if extra:
        diagnostics.append({'kind': 'extra_ids', 'ids': sorted(extra)})
    if diagnostics:
        return None, diagnostics
    return {record['id']: record['reply'] for record in records}, []


def snapshot(owners, corpus, choices):
    rows, issues, untaken = [], [], []
    for (sid, split), (items, fingerprint) in corpus.items():
        entry = owners[sid]
        row = {'specialist': sid, 'family': entry['family'], 'split': split,
               'panel_n': len(items), 'panel_sha256': fingerprint}
        if not items:
            row['coverage'] = 'NO_PANEL'
            rows.append(row)
            continue
        if not choices[sid, split]:
            row['coverage'] = 'NO_COMPATIBLE_RECEIPT'
            rows.append(row)
            continue
        stamp, path, verdict = max(choices[sid, split], key=lambda item: (item[0], str(item[1])))
        expected_ids = [f'{sid}:{split}:{index}' for index in range(len(items))]
        by_id, receipt_issues = receipt_records(path, expected_ids)
        if receipt_issues:
            row.update(coverage='INVALID_RECEIPT', receipt=str(path.relative_to(REPO)),
                       receipt_issues=receipt_issues)
            rows.append(row)
            continue
        counts, kinds, classifications = collections.Counter(), collections.defaultdict(collections.Counter), []
        for index, item in enumerate(items):
            reply = by_id.get(f'{sid}:{split}:{index}')
            observation = classify(entry, sid, item['q'], reply)
            category = observation['category']
            counts[category] += 1
            kind = reply.get('kind', '') if isinstance(reply, dict) else ''
            kinds[category][kind or '(no kind)'] += 1
            detail = {'specialist': sid, 'family': entry['family'], 'split': split, 'index': index,
                      'question': item['q'], 'panel_valid': item.get('valid'), 'kind': kind,
                      **observation, 'reply': reply, 'receipt': str(path.relative_to(REPO))}
            counts['pinned_accepted'] += bool(observation.get('pinned_accepted'))
            if observation.get('pinned_id_matches') is False:
                counts['pinned_id_mismatch'] += 1
            if category.startswith('dropped') or category in {'error', 'foreign_specialist'}:
                issues.append(detail)
            if category == 'not_taken':
                untaken.append(detail)
                counts['not_taken_valid' if item.get('valid') else 'not_taken_invalid'] += 1
            if item.get('valid') and isinstance(reply, dict) and reply.get('status') != 'answered':
                counts['nonanswer_on_valid'] += 1
            classifications.append({'index': index, 'kind': kind, **observation})
        row.update(coverage='recorded', receipt=str(path.relative_to(REPO)), receipt_sha256=sha(path),
                   receipt_mtime_utc=dt.datetime.fromtimestamp(stamp/1e9, dt.timezone.utc).isoformat(),
                   recorded_command=verdict.get('answerer'), recorded_score=verdict.get('with_specialist'),
                   freshness='receipt only; not a current-binary execution', counts=dict(counts),
                   kinds={k: dict(v) for k, v in kinds.items()}, classifications=classifications)
        rows.append(row)
    return rows, issues, untaken


def run_issues(issues, owners):
    grouped = collections.defaultdict(dict)
    for issue in issues:
        grouped[issue['specialist']].setdefault(issue['question'], issue)
    results = []
    for sid, questions in grouped.items():
        entry = owners[sid]
        binary = REPO / entry['binary']
        binary_before = sha(binary)
        requests = [dict(id=f'{sid}:issue:{i}', q=q, session=f'acceptance-{sid}-{i}')
                    for i, q in enumerate(questions)]
        direct = [str(binary)] + (['--specialist', sid] if entry.get('specialist_flag') else [])
        if entry.get('state_flag'):
            direct += ['--preview']
        composed = [sys.executable, '-B', str(HERE/'dispatch.py'), '--order', 'front',
                    '--organs', entry['family'], '--specialist', sid,
                    '--no-routes', '--no-reader', '--no-document']
        payload = ''.join(json.dumps(req)+'\n' for req in requests)
        pairs = []
        for label, command in [('direct', direct), ('composed', composed)]:
            process = subprocess.run(command, input=payload, text=True, capture_output=True,
                                     cwd=REPO, timeout=max(60, len(requests)*10))
            replies = [json.loads(line) for line in process.stdout.splitlines() if line.strip()]
            pairs.append((label, command, process.returncode, process.stderr, {r['id']: r for r in replies}))
        for req in requests:
            result = {'specialist': sid, 'question': req['q'], 'prior': questions[req['q']]['category'],
                      'binary_sha256': binary_before, 'binary_sha256_after': sha(binary),
                      'binary_changed_during_probes': binary_before != sha(binary), 'request': req}
            for label, cmd, code, stderr, replies in pairs:
                reply = replies.get(req['id'])
                result[label] = {'command': cmd, 'exit_code': code, 'stderr': stderr, 'reply': reply}
            result['current_admission'] = classify(entry, sid, req['q'], result['direct']['reply'])
            results.append(result)
    return results


def markdown(data):
    lines = ['# Specialist acceptance coverage', '',
             'This replays recorded direct replies through the current dispatcher gate. It does not rerun the head,',
             'prove that an answer is true, or identify a recorded binary with today\'s build. Source/model assumptions',
             'and untrusted recognition remain unchanged. A refusal can be correct; a valid panel item can also',
             'expect clarification. “Not taken” records the recognizer/adapter boundary, not a kernel refusal.', '',
             'Only receipts with an exact shipped-question fingerprint and full panel length are used. The newest',
             'compatible receipt is selected by modification time. Fresh-seed and partial-panel records are excluded.',
             'Scores below are the receipt\'s own scorer results; they are not new composed scores.', '',
             'Acceptance categories use family routing. The pinned total separately applies an explicit CLI',
             'specialist pin, which supplies context for declared decline kinds but cannot turn `taken=false`',
             'into a refusal or admit an undeclared kind. Historical family-mode receipts can answer under',
             'another owned ID. “Other ID” exposes these cases; it is not evidence that a current pinned',
             'execution would fail. Pinned admission is only a replay against the recorded reply.', '',
             '| Specialist | Split | N | Recorded right/wrong/FY | Accepted answers | Normal-kind refusals | Context refusals | Pinned accepted | Other ID | Not taken (valid) | Dropped kind/context | Coverage |',
             '|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---|']
    for row in data['specialists']:
        c = row.get('counts', {})
        score = row.get('recorded_score') or {}
        scores = '/'.join(str(score.get(k, '—')) for k in ('ok', 'wrong', 'fy'))
        lines.append(f"| {row['specialist']} | {row['split']} | {row['panel_n']} | {scores} | {c.get('accepted_answer',0)} | {c.get('accepted_normal_refusal',0)} | {c.get('accepted_context_refusal',0)} | {c.get('pinned_accepted',0)} | {c.get('pinned_id_mismatch',0)} | {c.get('not_taken',0)} ({c.get('not_taken_valid',0)}) | {c.get('dropped_kind',0)}/{c.get('dropped_context',0)} | {row['coverage']} |")
    rejected = [row for row in data['specialists'] if row.get('receipt_issues')]
    if rejected:
        lines += ['', '## Rejected reply files', '',
                  'These files do not supply exactly one well-formed reply record per expected request.',
                  'Their sidecar scores are not admitted as complete-panel coverage.', '']
        for row in rejected:
            lines.append(f"- **{row['specialist']} / {row['split']}** `{row['receipt']}`: " +
                         json.dumps(row['receipt_issues'], sort_keys=True))
    if data.get('policy_files_changed_during_run'):
        lines += ['', '**Policy files changed while this ran; rerun before comparing the live probes with replayed admission.**', '']
    lines += ['', '## Taken replies rejected by the current gate', '',
              'These are investigation candidates, not automatically defects. For example, an off-site reading should',
              'fall through; old receipts can predate a producer fix. The JSON includes every reply, kind, context,',
              'source receipt, fingerprint, command and current-policy classification.', '']
    for issue in data['issues']:
        lines.append(f"- **{issue['specialist']} / {issue['split']} {issue['index']}**, {issue['category']}, `{issue['kind']}`: {issue['question']}")
    lines += ['', '## Fresh issue probes', '',
              'Only listed issue questions and optional representative valid not-taken questions are rerun.',
              'Composed probes use a pinned family plus fusion;',
              'other routes are disabled so acceptance and fallthrough remain observable. These are diagnosis',
              'probes, not a new panel score.', '']
    for probe in data.get('fresh_probes', []):
        direct = probe['direct'].get('reply') or {}
        comp = probe['composed'].get('reply') or {}
        stages = (comp.get('provenance', {}).get('dispatch') or {}).get('stages_run', [])
        observation = probe['current_admission']
        lines.append(f"- **{probe['specialist']}**: {probe['question']} Direct `{direct.get('status')}/{direct.get('kind')}` → family `{observation['category']}`, pinned accepted `{observation.get('pinned_accepted', False)}`; composed `{comp.get('status')}`, stages `{','.join(stages)}`.")
    return '\n'.join(lines)+'\n'


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', type=Path, default=REPO/'var/dispatch/acceptance-coverage')
    ap.add_argument('--probe-issues', action='store_true')
    ap.add_argument('--probe-untaken-representatives', action='store_true',
                    help='rerun one recorded valid not-taken question per affected specialist')
    ap.add_argument('--prior-issues', type=Path, help='also replay issues from an earlier coverage.json snapshot')
    args = ap.parse_args()
    registry = validate_capabilities(REPO)
    source_paths = [REPO/'src/extract/families.json', HERE/'dispatch.py', REPO/'tools/runtime_contract.py']
    for entry in registry:
        for sid in entry['specialists']:
            source_paths.append(panels.specialist_dir(sid)/'manifest.json')
        cap = REPO/'src/extract'/entry['family']/'capabilities.json'
        if cap.exists():
            source_paths.append(cap)
    before = {str(p.relative_to(REPO)): sha(p) for p in source_paths}
    owners = {sid: entry for entry in registry if entry['role']=='specialist' for sid in entry['specialists']}
    corpus = {}
    for sid in owners:
        for split in ('dev', 'heldout'):
            items = panels.items(panels.specialist_dir(sid), split)
            corpus[sid, split] = items, panels.panel_sha(items)
    choices, skipped = discover(owners, corpus)
    rows, issues, untaken = snapshot(owners, corpus, choices)
    probes = list(issues)
    if args.prior_issues:
        old = json.loads(args.prior_issues.read_text())['issues']
        probes += [{**i, 'specialist': sid} for sid, group in old.items() for i in group] if isinstance(old, dict) else old
    selected_probes = probes if args.probe_issues else []
    if args.probe_untaken_representatives:
        representatives = {}
        for row in untaken:
            if row.get('panel_valid'):
                representatives.setdefault(row['specialist'], row)
        selected_probes = selected_probes + list(representatives.values())
    data = {'scope': 'recorded direct replies; current acceptance replay; no head run',
            'generated_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
            'registered_specialist_ids': len(owners), 'discovery_exclusions': skipped,
            'consumer_sha256': sha(HERE/'dispatch.py'), 'specialists': rows,
            'issues': issues, 'not_taken': untaken,
            'fresh_probes': run_issues(selected_probes, owners)}
    after = {str(p.relative_to(REPO)): sha(p) for p in source_paths}
    data['acceptance_source_sha256'] = before
    data['policy_files_changed_during_run'] = [path for path in before if before[path] != after[path]]
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out/'coverage.json').write_text(json.dumps(data, indent=2)+'\n')
    (args.out/'coverage.md').write_text(markdown(data))
    counts = collections.Counter(row['coverage'] for row in rows)
    print(json.dumps({'coverage': counts, 'issues':len(issues), 'not_taken':len(untaken),
                      'fresh_probes':len(data['fresh_probes']), 'report':str(args.out/'coverage.md')}))


if __name__ == '__main__':
    main()
