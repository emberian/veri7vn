#!/usr/bin/env python3
"""UNTRUSTED scoped executable checks of Fusion's numeric/model boundary.

Requires a freshly checked binary. This is not a full-head or specialist-panel
score. --reader-only exercises the malformed-reading boundary on a warm binary
without claiming the new zero-domain model was compiled.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
from types import SimpleNamespace

import answerer as A


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--binary', type=Path, required=True)
    ap.add_argument('--out', type=Path, default=A.REPO/'var/fusion/d-validity.json')
    ap.add_argument('--reader-only', action='store_true')
    args = ap.parse_args()
    rows = []
    binary_before = sha(args.binary)
    source_paths = ['tools/fusion/answerer.py', 'tools/fusion/numeric.py',
                    'tools/dispatch/dispatch.py', 'tools/dispatch/routes.py']
    source_hashes = {name: sha(A.REPO/name) for name in source_paths}
    fusion = A.Fusion(str(args.binary))
    try:
        malformed = ['1/0', '1 / 0', '1e3.5', '1,23', '1.2.3', '--2', '− 2']
        for token in malformed:
            question = 'Convert %s m to cm.' % token
            reply = fusion.reply(question)
            assert reply['status'] == 'withheld' and reply['kind'] == 'malformed_numbers', reply
            assert 'decision' not in reply['provenance'], reply
            rows.append(dict(scope='reader', question=question, reply=reply))
        question = 'Convert -5 m with 7 mysteries to cm.'
        reply = fusion.reply(question)
        assert reply['kind'] == 'unread_numbers' and 'decision' not in reply['provenance'], reply
        rows.append(dict(scope='reader', question=question, reply=reply))

        question = 'How much energy in kWh does a 1e-6 W lamp use over 2 hours?'
        reply = fusion.reply(question)
        assert reply['status'] == 'answered' and reply['value'] == 2e-9, reply
        assert '2.0000e-09 kwh' in reply['response'], reply
        rows.append(dict(scope='rendering', question=question, reply=reply))

        if not args.reader_only:
            cases = [
                ('zero_length', [A.Q(0, A.LEN)], A.LEN, 1, 'single', None),
                ('zero_power', [A.Q(0, A.POWER), A.Q(7200, A.TIME)], A.ENERGY, 1, 'answer', '0/1'),
                ('zero_time_product', [A.Q(100, A.POWER), A.Q(0, A.TIME)], A.ENERGY, 1, 'answer', '0/1'),
                ('zero_duty', [A.Q(0, A.DIMLESS, role='duty'), A.Q(2000, A.POWER), A.Q(86400, A.TIME)], A.ENERGY, 1, 'answer', '0/1'),
                ('negative_duty', [A.Q(-1, A.DIMLESS, role='duty')], A.ENERGY, 1, 'invalid', 1),
                ('overfull_duty', [A.Q(2, A.DIMLESS, role='duty')], A.ENERGY, 1, 'invalid', 1),
                ('zero_body_mass', [A.Q(0, A.DIMLESS, role='earth_mass')], A.ACC, 1, 'invalid', 5),
                ('zero_body_radius', [A.Q(0, A.DIMLESS, role='earth_radius')], A.ACC, 1, 'invalid', 5),
                ('zero_time_divisor', [A.Q(5, A.LEN), A.Q(0, A.TIME)], A.VEL, 1, 'noplan', None),
                ('zero_unit_factor', [A.Q(100, A.POWER), A.Q(3600, A.TIME)], A.ENERGY, 0, 'noplan', None),
                ('negative_unit_factor', [A.Q(100, A.POWER), A.Q(3600, A.TIME)], A.ENERGY, -1, 'noplan', None),
            ]
            for name, givens, dimension, factor, expected, detail in cases:
                request = A.typed('', givens, ('dim', dimension, 'unit', factor), A.read_ctx(''), 'pairwise')
                request['id'] = name
                reply = fusion.ask(request)
                assert reply['outcome'] == expected, (name, reply)
                if expected == 'answer':
                    assert reply['value'] == detail, (name, reply)
                elif expected == 'invalid':
                    assert reply['rule'] == detail, (name, reply)
                rows.append(dict(scope='typed_model', name=name, request=request, reply=reply))
            for literal in ['1/0', '1/-2', '1oops/2', '1/2oops', '1/2/3']:
                request = A.typed('', [A.Q(100, A.POWER), A.Q(3600, A.TIME)],
                                  ('dim', A.ENERGY, 'unit', 1), A.read_ctx(''), 'pairwise')
                request['id'] = literal
                request['givens'][0]['v'] = literal
                reply = fusion.ask(request)
                assert 'error' in reply and reply.get('outcome') != 'answer', reply
                rows.append(dict(scope='typed_wire', request=request, reply=reply))
            for question in [
                'How much energy in kWh does a 0 W lamp use over 2 hours?',
                'How much energy in kWh does a 100 W lamp use for 0 hours?',
                'How much energy in kWh does a 2 kW heater use for 0 hours a day over 30 days?',
                'What does a 2 kW heater cost at $0.15/kWh for 0 hours?']:
                reply = fusion.reply(question)
                assert reply['status'] == 'answered' and reply['value'] == 0, reply
                rows.append(dict(scope='english_model', question=question, reply=reply))
    finally:
        fusion.close()

    # Actual specialist-first dispatcher, followed by this Fusion binary. The
    # owned Child argv selects the candidate before it starts; no mock replies.
    sys.path.insert(0, str(A.REPO/'tools/dispatch'))
    import dispatch as D
    driver = D.Dispatcher(SimpleNamespace(order='front', var_root=str(A.REPO/'var'),
        organs='quantity,variants,acoustics', specialist='', no_reader=True,
        no_document=True, no_routes=True, arb=str(A.REPO/'var/dispatch/bin/arb_check'), timeout=10))
    driver.fusion.argv[driver.fusion.argv.index('--binary') + 1] = str(args.binary.resolve())
    try:
        for question in ['Convert 1/0 m to cm.', 'Convert 1e3.5 m to cm.', 'Convert 1,23 m to cm.']:
            reply = driver.turn(str(len(rows)), question, 'fusion-boundary')
            assert reply['status'] == 'withheld' and 'error' not in reply, reply
            assert reply['path'] != 'network>validity' and 'physical' not in reply['response'], reply
            assert reply['provenance']['dispatch']['stages_run'] == ['specs', 'net'], reply
            rows.append(dict(scope='composed', question=question, reply=reply))
        if not args.reader_only:
            question = 'How much energy in kWh does a 0 W lamp use over 2 hours?'
            reply = driver.turn('zero-composed', question, 'fusion-boundary')
            assert reply['status'] == 'answered' and reply['value'] == 0, reply
            assert reply['path'].startswith('network>'), reply
            rows.append(dict(scope='composed', question=question, reply=reply))
    finally:
        driver.close()

    route_hashes = {}
    if not args.reader_only:
        # Final integration with actual Wordprob and actual precision guards.
        # Chemistry is the scoped specialist fan-out; it does not recognize
        # these geometry/motion questions.
        names = ('chemistry', 'wordprob', 'mathorgan', 'guards')
        route_hashes = {name: sha(A.REPO/f'var/{name}/bin/{name}') for name in names}
        driver = D.Dispatcher(SimpleNamespace(order='front', var_root=str(A.REPO/'var'),
            organs='chemistry', specialist='', no_reader=True, no_document=True,
            no_routes=False, arb=str(A.REPO/'var/dispatch/bin/arb_check'), timeout=10))
        driver.fusion.argv[driver.fusion.argv.index('--binary') + 1] = str(args.binary.resolve())
        combined = [
            ('A cylinder has radius 0 cm and height 2 m. What is its volume in cubic meters?', 0),
            ('A rectangle has length 0 m and width 30 cm. What is its area in square meters?', 0),
            ('A car moves at 60 km/s for 0 hours. How far does it travel in meters?', 0),
            ('A car travels 0 km at 60 km/hour. How long does it take in hours?', 0),
            ('A train travels 10 km in 0 seconds. What is its speed in km/hour?', None),
            ('A car travels 10 km at 0 km/hour. How long does it take in hours?', None),
            ('How much energy in kWh does a 1e-6 W lamp use over 2 hours?', 2e-9),
        ]
        try:
            for question, expected in combined:
                reply = driver.turn(str(len(rows)), question, 'combined-zero-domain')
                assert 'error' not in reply, reply
                if expected is None:
                    assert reply['status'] == 'withheld' and 'physical' not in reply['response'], reply
                else:
                    assert reply['status'] == 'answered' and float(reply['value']) == expected, reply
                    assert reply['provenance']['precision_guards']['code'] is None, reply
                rows.append(dict(scope='combined_routes', question=question, expected=expected, reply=reply))
        finally:
            driver.close()
        assert route_hashes == {name: sha(A.REPO/f'var/{name}/bin/{name}') for name in names}, 'route binary changed'
    assert sha(args.binary) == binary_before, 'binary changed during checks'
    assert source_hashes == {name: sha(A.REPO/name) for name in source_paths}, 'consumer source changed'
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(dict(binary=str(args.binary), binary_sha256=binary_before,
        route_binary_sha256=route_hashes, consumer_source_sha256=source_hashes, reader_only=args.reader_only,
        cases=rows, passed=len(rows)), indent=2)+'\n')
    print('PASS %d scoped cases; reader_only=%s; receipt=%s' % (len(rows), args.reader_only, args.out))


if __name__ == '__main__':
    main()
