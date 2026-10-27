#!/usr/bin/env python3
"""Untrusted, offline reader of Oracle replies; not a proof checker or fact verifier.

Classifications describe returned evidence, never strengthen the answer's status.
The JSON view retains the entire input, including unknown and withheld fields.
No paths, URLs, formulas or commands supplied by the answer are executed.
"""
import argparse
import json
from pathlib import Path
import re
import sys

SCOPE = ("No theorem is established by this inspector. Theorem names, 'proved', "
         "'verified', and native agreement are returned claims. Recognizer correctness, "
         "theorem premises, source truth and completeness are not checked here.")
CATEGORIES = ('source_citation', 'computed_value', 'native_kernel_crosscheck',
              'proof_scope', 'clarification', 'unsupported_claim', 'unavailable_metadata')


def inspect_record(record):
    """Return evidence observations plus the unchanged complete input record."""
    if not isinstance(record, dict):
        raise ValueError('input record must be a JSON object')
    envelope = record.get('response') if isinstance(record.get('response'), dict) else record
    reply = envelope.get('reply') if isinstance(envelope.get('reply'), dict) else envelope
    observations = {key: [] for key in CATEGORIES}

    def add(category, field, detail, value=None):
        item = {'field': field, 'detail': detail}
        if value is not None:
            item['returned_value'] = value
        observations[category].append(item)

    # Error envelopes and missing/invalid engine payloads are never answers.
    if not isinstance(reply.get('status'), str) or not isinstance(reply.get('response'), str):
        add('unavailable_metadata', 'reply', 'No complete engine answer in this record.')
        return {'id': record.get('id'), 'question': record.get('text'),
                'status': None, 'answer': None, 'observations': observations, 'original': record}
    text, status = reply['response'], reply['status']
    prov = reply.get('provenance') if isinstance(reply.get('provenance'), dict) else {}
    path = reply.get('path', '')
    path = path if isinstance(path, str) else ''
    refs = reply.get('references')
    if isinstance(refs, list) and refs:
        for n, ref in enumerate(refs):
            add('source_citation', f'reply.references[{n}]',
                'Returned reference; content, relevance and coverage have not been checked.', ref)
    else:
        add('unavailable_metadata', 'reply.references',
            'No structured citations returned; this does not establish that no source exists.')
    # Only the active answer is scanned. Historical/replaced responses are not support for it.
    inline = re.findall(r'\bQ[0-9]+\b|\bP[0-9]+\b|\bsimplewiki_[a-zA-Z0-9_]+\b', text)
    if inline:
        add('source_citation', 'reply.response',
            'Source identifiers embedded in the active answer; no source record fetched.', list(dict.fromkeys(inline)))
    if re.search(r'\bNIST\b', text):
        add('source_citation', 'reply.response',
            'Named source without a returned document locator.', 'NIST')
    kind = prov.get('kind')
    computed = status == 'answered' and (kind in ('computation', 'organ_math') or isinstance(reply.get('value'), (int, float)))
    if computed:
        add('computed_value', 'reply.provenance',
            'Computation reported by the engine; this inspector does not recompute it.', prov)
        if 'value' in reply:
            add('computed_value', 'reply.value', 'Returned value.', reply['value'])
    elif status == 'answered' and 'specialist:' in path and re.search(r'\d', text) and not inline:
        add('computed_value', 'reply.response',
            'Specialist presents a numerical result in prose; no structured calculation supplied.', text)
    if status == 'answered' and re.search(r'(?<!\w)(?:zoo|nan|NaN|Infinity)(?!\w)', text):
        add('unsupported_claim', 'reply.response',
            'Non-finite/undefined marker in an answered result; a numeric check label does not establish a usable finite answer.')
    check = reply.get('kernel_check')
    if isinstance(check, dict):
        add('native_kernel_crosscheck', 'reply.kernel_check',
            'Returned native comparison; agreement is not proof of the English claim.', check)
        if check.get('comparison') == 'unsupported':
            add('unsupported_claim', 'reply.kernel_check.comparison', 'The comparator did not establish agreement.')
        if check.get('comparison') == 'disagreement':
            add('unsupported_claim', 'reply.kernel_check.comparison', 'The comparator reports a contradiction; preserve the original answer status.')
    else:
        add('unavailable_metadata', 'reply.kernel_check',
            'No native cross-check returned. Whether it was unavailable, skipped or never requested is unknown.')
    add('proof_scope', 'inspector', SCOPE)
    if 'proved' in reply:
        add('proof_scope', 'reply.proved', 'Upstream proof label only; no theorem checked.', reply['proved'])
    for key in ('verified', 'check', 'kernel', 'session', 'theorems'):
        if key in prov:
            add('proof_scope', 'reply.provenance.' + key,
                'Returned assurance claim, not an independently checked theorem.', prov[key])
    if not (isinstance(check, dict) or any(k in prov for k in ('theorems', 'kernel', 'session'))):
        add('unavailable_metadata', 'proof', 'No kernel/theorem identification returned.')
    if isinstance(reply.get('evidential'), dict):
        add('proof_scope', 'reply.evidential', 'Engine evidence label; not a proof or citation.', reply['evidential'])
    if status in ('clarification', 'withheld'):
        add('clarification', 'reply.status', 'The engine did not provide an admitted answer.', status)
    if status == 'answered' and not observations['source_citation'] and not observations['computed_value'] and not isinstance(check, dict):
        add('unsupported_claim', 'reply.response',
            'No citation, computation or native comparison identified in the returned fields. This flags missing support, not demonstrated falsity.')
    if status == 'answered' and prov.get('parent_status') == 'withheld':
        add('proof_scope', 'reply.provenance.parent_status',
            'A later route answered after an earlier refusal. Review the active answer and its support separately.')
    return {'id': record.get('id'), 'question': record.get('text'), 'status': status,
            'answer': text, 'route': path, 'observations': observations, 'original': record}


def render(view, raw=False):
    lines = [f"{view.get('id') or '(reply)'} — {view['status'] or 'no engine answer'}"]
    if view.get('question'):
        lines.append('Question: ' + view['question'])
    if view.get('answer') is not None:
        lines.append('Answer: ' + view['answer'])
    for category, entries in view['observations'].items():
        for item in entries:
            lines.append(f"{category}: {item['detail']} [{item['field']}]")
            if 'returned_value' in item:
                lines.append('  ' + json.dumps(item['returned_value'], ensure_ascii=False))
    if raw:
        lines.extend(['Complete original record:', json.dumps(view['original'], ensure_ascii=False, indent=2)])
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path, help='runner results.jsonl, JSON reply, or JSON array')
    parser.add_argument('--format', choices=('text', 'json'), default='text')
    parser.add_argument('--case', help='select a runner case by its exact ID')
    parser.add_argument('--raw', action='store_true', help='include complete original records in text mode; JSON always includes them')
    args = parser.parse_args()
    try:
        content = args.input.read_text()
        try:
            parsed = json.loads(content)
            records = parsed if isinstance(parsed, list) else [parsed]
        except json.JSONDecodeError:
            records = [json.loads(line) for line in content.splitlines() if line.strip()]
        views = [inspect_record(record) for record in records
                 if not args.case or isinstance(record, dict) and record.get('id') == args.case]
        if not views:
            raise ValueError('no matching records')
        if args.format == 'json':
            print(json.dumps(views, ensure_ascii=False, indent=2, allow_nan=False))
        else:
            print('\n\n'.join(render(view, args.raw) for view in views))
    except (OSError, ValueError, TypeError) as error:
        parser.exit(2, str(error) + '\n')


if __name__ == '__main__':
    main()
