#!/usr/bin/env python3
"""Live finite workflow checks, separate from Oracle7 specialist panels."""
import argparse
import copy
import json
from pathlib import Path
import sys
import tempfile
import uuid
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from hosted_reasoning import Client, compact, digest
from revisable_evidence import EvidenceCursor, strict_json
from thermal_revision import decide, queries, validate_package, ThermalClient


def score(url, tenant):
    plan = strict_json(Path(__file__).with_name('example.json').read_text())
    validate_package(plan['package'])
    plan['conversation'] += '-' + uuid.uuid4().hex
    thermal = ThermalClient(url, tenant)
    thermal.discover()
    rows = []
    right = wrong = errors = 0
    with tempfile.TemporaryDirectory(prefix='thermal-revision-') as directory:
        with EvidenceCursor(Client(url, tenant), Path(directory) / 'cursor.json', plan['conversation'], digest(compact(plan))) as cursor:
            for step in plan['steps']:
                try:
                    cursor.revise(step['revision'])
                    solved = cursor.solve(queries(plan['package']))
                    actual = decide(plan['package'], solved, thermal)
                    gold = step['expected']
                    ok = (actual.get('decision', actual['status']) == gold['decision']
                          and (gold['temperature_k'] is None or abs(actual['temperature_k'] - gold['temperature_k']) < 1e-8))
                    rows.append({'revision': step['revision']['expected_revision'] + 1, 'correct': ok, 'actual': actual})
                    right += int(ok)
                    wrong += int(not ok)
                    if len(rows) == 4:
                        before = copy.deepcopy(cursor.verify())
                        # A failed numerical request cannot mutate the already committed
                        # evidence. Retry the immutable snapshot, then confirm exact receipt.
                        class TimeoutThermal:
                            def invoke(self, arguments):
                                raise TimeoutError('injected numerical transport timeout')
                        try:
                            decide(plan['package'], solved, TimeoutThermal())
                            raise AssertionError('timeout unexpectedly answered')
                        except TimeoutError:
                            pass
                        assert cursor.verify() == before
                        retry = decide(plan['package'], cursor.solve(queries(plan['package'])), thermal)
                        assert retry == actual
                        right += 1
                except Exception as error:
                    errors += 1
                    rows.append({'error': type(error).__name__ + ': ' + str(error)})
                    break
    return {'right': right, 'wrong': wrong, 'execution_errors': errors,
            'scope': 'seven supplied revision cases plus injected numerical-timeout/retry preservation; no shipped specialist-panel score',
            'host_url': url, 'rows': rows}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', required=True)
    parser.add_argument('--tenant', default='thermal-revision-score')
    args = parser.parse_args()
    report = score(args.url, args.tenant)
    print(json.dumps(report, indent=2, allow_nan=False))
    raise SystemExit(bool(report['wrong'] or report['execution_errors']))
