#!/usr/bin/env python3
"""UNTRUSTED summary consumer probes and synthetic evidence controls.

These authored questions measure answerability on this source snapshot. Expected
refusals are policy checks, not answered questions or shipped-panel scores.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from anchor_answerer import AnchorAnswerer, DEFAULT_BINARY


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, default=DEFAULT_BINARY)
    parser.add_argument('--out', type=Path, default=HERE.parents[1] / 'var/document/summary-check.json')
    args = parser.parse_args()
    digest = hashlib.sha256(args.binary.read_bytes()).hexdigest()
    adapter = AnchorAnswerer(args.binary)
    questions, controls = [], []

    def raw(ev):
        adapter.proc.stdin.write(json.dumps(ev) + '\n')
        adapter.proc.stdin.flush()
        return json.loads(adapter.proc.stdout.readline())

    def cited_rows(ev, reply):
        cites = reply.get('cites', [])
        candidates = {r['id']: r for r in ev['rows']}
        sentences = [candidates[c]['sentence'] for c in cites if c in candidates]
        return (0 < len(cites) <= 3 and len(cites) == len(set(cites))
                and len(sentences) == len(cites) and len(sentences) == len(set(sentences))
                and all(s in reply.get('response', '') for s in sentences))

    try:
        cases = json.loads((HERE / 'summary_probes.json').read_text())
        for i, case in enumerate(cases):
            reply = adapter.answer({'id': i, 'q': case['q']})
            answered = reply.get('status') == 'answered'
            ok = not reply.get('error') and answered == case['answer']
            if answered:
                ev = adapter.fetch.evidence(case['q'])
                ok = ok and reply.get('path') == 'document:summary' and cited_rows(ev, reply)
            questions.append({'case': case, 'reply': reply, 'ok': ok})

        base = adapter.fetch.evidence('Summarize photosynthesis.')
        page = base['aliases'][0]
        # Synthetic rows isolate selection and witness checking, not source truth.
        base['rows'] = [dict(page_id=page['page_id'], source_page_id=page['page_id'],
                            page=page['title'], id='synthetic-' + str(i), sentence=s)
                        for i, s in enumerate([
                            'Photosynthesis is a process in plants.',
                            'Photosynthesis uses sunlight.',
                            'Photosynthesis can produce glucose.',
                            'Photosynthesis occurs in plants.'])]
        checks = [('bounded_four_rows', copy.deepcopy(base), ['synthetic-0', 'synthetic-1', 'synthetic-2'])]
        for field, value in [('page_id', 'wrong'), ('source_page_id', 'wrong'),
                             ('page', 'Different title'), ('id', '   '),
                             ('sentence', 'Chlorophyll is a pigment.')]:
            ev = copy.deepcopy(base); ev['rows'][2][field] = value
            checks.append(('third_row_' + field, ev, ['synthetic-0', 'synthetic-1', 'synthetic-3']))
        ev = copy.deepcopy(base); ev['rows'][1]['sentence'] = ev['rows'][0]['sentence']
        checks.append(('duplicate_sentence', ev, ['synthetic-0', 'synthetic-2', 'synthetic-3']))
        ev = copy.deepcopy(base); ev['rows'][1]['id'] = ev['rows'][0]['id']
        checks.append(('duplicate_citation', ev, ['synthetic-0', 'synthetic-2', 'synthetic-3']))
        ev = copy.deepcopy(base); ev['aliases'].append(dict(page, page_id=''))
        checks.append(('blank_matching_alias', ev, 'ambiguous_anchor'))
        ev = copy.deepcopy(base); ev['request']['question'] = 'Summarize photosynthesis and compare respiration.'
        checks.append(('whole_request_disagreement', ev, 'silent'))
        ev = copy.deepcopy(base)
        for r in ev['rows']: r['source_page_id'] = 'wrong'
        ev.update(resolved=True, released=True)
        checks.append(('flags_cannot_release_wrong_source', ev, 'no_direct_clause'))
        for name, ev, expected in checks:
            reply = raw(ev)
            if isinstance(expected, list):
                ok = (reply.get('status') == 'answered' and reply.get('cites') == expected
                      and cited_rows(ev, reply))
                # Repeated IDs are intentionally ambiguous as Python map keys;
                # check the selected first row's quotation directly in that control.
                if name == 'duplicate_citation':
                    ok = (reply.get('status') == 'answered' and reply.get('cites') == expected
                          and all(ev['rows'][i]['sentence'] in reply['response'] for i in [0, 2, 3]))
            else:
                ok = (reply.get('status') == 'withheld'
                      and reply.get('provenance', {}).get('kernel_outcome') == expected)
            controls.append({'name': name, 'expected': expected, 'reply': reply,
                             'ok': ok and not reply.get('error')})
    finally:
        adapter.close()
    if hashlib.sha256(args.binary.read_bytes()).hexdigest() != digest:
        raise RuntimeError('binary changed during summary checks')
    report = {'scope': __doc__, 'binary_sha256': digest,
              'question_assertions_passed': sum(x['ok'] for x in questions), 'question_total': len(questions),
              'source_answers': sum(x['reply'].get('status') == 'answered' for x in questions),
              'source_withheld': sum(x['reply'].get('status') != 'answered' and not x['reply'].get('error') for x in questions),
              'source_errors': sum(bool(x['reply'].get('error')) for x in questions),
              'controls_passed': sum(x['ok'] for x in controls), 'controls_total': len(controls),
              'questions': questions, 'controls': controls}
    args.out.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k not in ['questions', 'controls']}, indent=2))
    raise SystemExit(0 if all(x['ok'] for x in questions + controls) else 1)


if __name__ == '__main__':
    main()
