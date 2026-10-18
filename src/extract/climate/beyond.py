#!/usr/bin/env python3
"""Score this family's shipped panels, fresh generator seeds, and author probes.

The upstream generators/scorers and recognizers are untrusted. Seed offsets
change the generator's own numeric samples, not its wording or assumptions.
Missing generators are reported, never silently replaced with shipped panels.
All writes stay under --out (normally var/<family>/beyond).
"""
import argparse
import contextlib
import hashlib
import importlib.util
import io
import json
import math
from pathlib import Path
import random
import runpy
import statistics
import subprocess
import sys
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
FAMILY = HERE.name
ROOT = HERE.parents[2]
SPEC = ROOT / 'upstream/root/specialists'
spec = importlib.util.spec_from_file_location('family_score', HERE / 'score.py')
score = importlib.util.module_from_spec(spec)
spec.loader.exec_module(score)


def count(items, replies, scorer):
    result = {}
    for it, rep in zip(items, replies):
        row = result.setdefault(it.get('split', 'probe'), dict(n=0, right=0, wrong=0, false_yes=0, withheld=0))
        good, asserted = scorer.ok(it, rep)
        row['n'] += 1
        row['right'] += bool(good)
        row['wrong'] += bool(it['valid'] and not good and asserted)
        row['false_yes'] += bool(not it['valid'] and asserted)
        row['withheld'] += bool(it['valid'] and not good and not asserted)
    return result


def ask(binary, sid, items):
    replies, elapsed = [], []
    p = subprocess.Popen([str(binary), '--specialist', sid], text=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    try:
        for i, it in enumerate(items):
            rep, ms = score.ask(p, str(i), it['q'])
            replies.append(rep)
            elapsed.append(ms)
    finally:
        p.stdin.close()
        p.wait(timeout=10)
    return replies, elapsed


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--binary', type=Path, default=ROOT / 'var' / FAMILY / 'bin' / FAMILY)
    ap.add_argument('--out', type=Path, default=ROOT / 'var' / FAMILY / 'beyond')
    ap.add_argument('--seeds', default='701,1701', help='Comma-separated offsets added to original generator seeds')
    ap.add_argument('--skip-shipped', action='store_true')
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    report = {'family': FAMILY, 'binary_sha256': hashlib.sha256(args.binary.read_bytes()).hexdigest(),
              'size_bytes': args.binary.stat().st_size, 'missing_generators': [], 'panels': {}, 'probes': {}}
    seeds = [int(x) for x in args.seeds.split(',') if x]
    for row in score.SPECIALISTS:
        sid = row[0]
        orgmod, cls, panelname, scorermod, _ = row[-5:]
        organ = getattr(score.load(sid, orgmod), cls)()
        scorer = score.load(sid, scorermod)
        panelpath = SPEC / sid / panelname
        gen = panelpath.with_suffix('.py')
        if not gen.exists():
            alternate = {'greenhouse': 'greenhouse-r2', 'coldchain': 'coldchain-v2'}.get(sid)
            if alternate:
                gen = SPEC / alternate / gen.name
        panels = []
        if not args.skip_shipped:
            panels.append(('shipped', json.loads(panelpath.read_text())))
        if not gen.exists():
            report['missing_generators'].append(sid)
        else:
            for seed in seeds:
                path = args.out / (sid + '-seed-' + str(seed) + '.json')
                original = random.Random
                class ShiftedRandom(original):
                    def __init__(self, s=None):
                        super().__init__(s + seed if isinstance(s, int) else s)
                random.Random = ShiftedRandom
                argv = sys.argv
                sys.argv = [str(gen), str(path)]
                try:
                    with contextlib.redirect_stdout(io.StringIO()):
                        runpy.run_path(str(gen), run_name='__main__')
                finally:
                    random.Random, sys.argv = original, argv
                panels.append(('seed-' + str(seed), json.loads(path.read_text())))
        for label, items in panels:
            if isinstance(items, dict):
                items = [dict(it, split=split) for split, part in items.items() for it in part]
            reps, elapsed = ask(args.binary, sid, items)
            originals = [organ.answer(it['q']) or {'status': 'withheld'} for it in items]
            entry = {'kernel': count(items, reps, scorer), 'organ': count(items, originals, scorer),
                     'p50_ms': statistics.median(elapsed), 'items': items, 'replies': reps}
            report['panels'][sid + '/' + label] = entry
            print(sid, label, entry['kernel'], flush=True)
        probes = [it for it in json.loads((HERE / 'beyond-probes.json').read_text())['items'] if it['specialist'] == sid]
        if probes:
            reps, _ = ask(args.binary, sid, probes)
            result = []
            for it, rep in zip(probes, reps):
                good = rep.get('status') == it['status']
                expected, value = it['expected'], rep.get('value')
                if good and expected is not None:
                    if isinstance(expected, bool):
                        good = value is expected or rep.get('response', '').startswith(('Yes', 'Within') if expected else ('No', 'Past'))
                    else:
                        good = isinstance(value, (int, float)) and math.isclose(value, expected, rel_tol=.005, abs_tol=.005)
                if good and it.get('kind'):
                    good = rep.get('kind') == it['kind']
                result.append({'ok': good, **it, 'reply': rep})
            report['probes'][sid] = result
    cold = []
    for _ in range(5):
        start = time.perf_counter()
        subprocess.run([str(args.binary)], input='{"q":"xyzzy"}\n', text=True, capture_output=True, check=True)
        cold.append((time.perf_counter() - start) * 1000)
    report['cold_ms'] = cold
    (args.out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('probe correct', sum(it['ok'] for part in report['probes'].values() for it in part),
          'of', sum(map(len, report['probes'].values())), 'cold p50', statistics.median(cold),
          'missing generators', report['missing_generators'])


if __name__ == '__main__':
    main()
