#!/usr/bin/env python3
"""Untrusted read-only geometry-v4 panel replay, not the six-criterion exam.

Runs shipped list-format split rows through the actual standalone acceptance
wrapper and the specialist's own scorer. No admission log/verdict is modified.
"""
import argparse
import hashlib
import json
from pathlib import Path
import statistics
import time

from test_geometry_route import SOURCE, SPECIALIST, actual_consumer, load


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    family, _ = actual_consumer()
    organ = family.organs[0]
    scorer = load(SPECIALIST / 'geometry_scorer.py', 'geometry_own_scorer')
    panel = SPECIALIST / 'geometry_panel_v3.json'
    rows = []
    for item in json.loads(panel.read_text()):
        started = time.perf_counter()
        reply = organ.reply(item['q'])
        elapsed = (time.perf_counter()-started)*1000
        good, asserted = scorer.ok(item, reply)
        rows.append({'question':item, 'reply':reply, 'scorer_good':bool(good),
                     'scorer_asserted':bool(asserted), 'latency_ms':elapsed})
    summary = {}
    for split in sorted({r['question']['split'] for r in rows}):
        selected = [r for r in rows if r['question']['split'] == split]
        summary[split] = {'n':len(selected), 'scorer_good':sum(r['scorer_good'] for r in selected),
                         'valid_correct':sum(r['question']['valid'] and r['scorer_good'] for r in selected),
                         'valid_wrong':sum(r['question']['valid'] and r['scorer_asserted'] and not r['scorer_good'] for r in selected),
                         'valid_withheld':sum(r['question']['valid'] and not r['scorer_asserted'] for r in selected),
                         'correct_refusal':sum(not r['question']['valid'] and r['scorer_good'] for r in selected),
                         'false_yes':sum(not r['question']['valid'] and r['scorer_asserted'] for r in selected),
                         'median_ms':statistics.median(r['latency_ms'] for r in selected)}
    result = {'scope':'Published geometry-v4 rows through actual standalone organ acceptance and own scorer. Not six-criterion exam, fresh heldout/admission, or full Engine.',
              'source':str(SPECIALIST.resolve()), 'summary':summary,
              'sha256':{name:hashlib.sha256((SPECIALIST/name).read_bytes()).hexdigest() for name in ('organ_geometry_v4.py','manifest.json','geometry_scorer.py','geometry_panel_v3.json')},
              'rows':rows}
    with args.out.open('x') as out:
        json.dump(result,out,indent=2)
        out.write('\n')
    print(json.dumps(summary,indent=2))
    return 0 if all(r['scorer_good'] for r in rows) else 1


if __name__ == '__main__':
    raise SystemExit(main())
