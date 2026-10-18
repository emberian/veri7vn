#!/usr/bin/env python3
"""Untrusted evaluation harness: shipped generators/scorers, reseeded read-only.

The generators share their author's assumptions. An offset changes random
choices, not their question templates. SQL has no shipped generator. Keep the
second offset untouched until recognizer tuning is finished.
"""
import argparse
import contextlib
import io
import json
from pathlib import Path
import random
import runpy
import sys
import time

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import score


def panel_for(sid, folder, panel_file, offset, dest):
    source = score.SPEC / folder / panel_file.replace('.json', '.py')
    if not source.exists():
        return None
    original = random.Random
    random.Random = lambda seed=None: original((seed or 0) + offset)
    old_argv = sys.argv
    args = [str(source)]
    if sid.startswith('python'):
        args.append(str(score.SPEC / folder / 'pyref_v1.json'))
    args.append(str(dest))
    sys.argv = args
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            runpy.run_path(str(source), run_name='__main__')
    finally:
        sys.argv = old_argv
        random.Random = original
    return json.loads(dest.read_text())


def tally(panel, scorer, organ):
    out = {}
    for split in ('dev', 'heldout'):
        t = dict(n=0, right=0, wrong=0, withheld_valid=0, false_yes=0)
        for item in (i for i in panel if i['split'] == split):
            r = organ.answer(item['q']) or dict(status='withheld', response='', path='')
            good, asserted = scorer.ok(item, r)
            t['n'] += 1
            if good: t['right'] += 1
            elif asserted: t['wrong' if item['valid'] else 'false_yes'] += 1
            elif item['valid']: t['withheld_valid'] += 1
        out[split] = t
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--binary', required=True)
    ap.add_argument('--offset', type=int, required=True)
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    report = {'offset': args.offset, 'binary': args.binary, 'specialists': {}}
    for sid, folder, mod, cls, panel_file, scorer_mod, tol in score.SPECIALISTS:
        panel = panel_for(sid, folder, panel_file, args.offset, args.out / (sid + '.panel.json'))
        if panel is None:
            report['specialists'][sid] = {'remaining': 'No shipped generator; independent SQL probes are separate.'}
            continue
        organ = (getattr(score.load(folder, mod), cls)(str(score.SPEC / folder / 'pyref_v1.json'))
                 if mod == 'organ_pyref_v1' else getattr(score.load(folder, mod), cls)())
        scorer = score.load(folder, scorer_mod)
        r = score.run_panel(args.binary, ['--specialist', sid], sid, panel, scorer, organ, tol)
        r.pop('rtt_ms'); r.pop('specialist_ms')
        report['specialists'][sid] = {'kernel': r, 'organ': tally(panel, scorer, organ)}
        print(sid, {s: {k: v for k, v in t.items() if k != 'fails'} for s,t in r['splits'].items()})
    (args.out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__': main()
