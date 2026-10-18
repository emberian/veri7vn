#!/usr/bin/env python3
"""UNTRUSTED evaluation driver; never changes the upstream panels or stores.

Reuses each shipped cooking generator with a new RNG seed, unchanged question
construction, and immutable SQLite access. Generator and organ share an author;
new seeds test new sampled foods, not independently designed language. A second
seed should remain uninspected until implementation is frozen.
"""
import argparse
import importlib.util
import json
import random
import sqlite3
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import score


def generate(version, seed, destination):
    src = ROOT / 'upstream/root/specialists' / ('cooking' if version == 1 else 'cooking-v3-r2') / ('nutrition_panel_v%d.py' % version)
    spec = importlib.util.spec_from_file_location('panel_generator', src)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    # Only override the RNG seed and IO; preserve all sampling and question logic.
    class RandomModule:
        @staticmethod
        def Random(_):
            return random.Random(seed)
    class SQLiteModule:
        @staticmethod
        def connect(path):
            return sqlite3.connect(Path(path).resolve().as_uri() + '?immutable=1', uri=True)
    mod.random, mod.sqlite3 = RandomModule, SQLiteModule
    old = sys.argv
    sys.argv = [str(src), str(score.SPEC / 'cooking/nutrition_v1.sqlite3'), str(destination)]
    try:
        mod.main()
    finally:
        sys.argv = old


def evaluate(binary, sid, panel, out):
    row = next(x for x in score.SPECIALISTS if x[0] == sid)
    _, folder, module, cls, pfolder, _, store = row
    organ = getattr(score.load(folder, module), cls)(str(score.SPEC / store))
    scorer = score.load(pfolder, 'cooking_scorer')
    proc = score.start(str(Path(binary).resolve()), sid, out.with_suffix('.state.json'))
    totals = {source: {split: dict(n=0,right=0,wrong=0,false_yes=0,withheld=0) for split in ('dev','heldout')} for source in ('kernel','organ')}
    records = []
    try:
        for i,item in enumerate(json.loads(panel.read_text())):
            session = 'beyond-%s-%d' % (sid,i)
            rep,ms = score.ask(proc,str(i),item['q'],session)
            old = organ.answer(item['q'],session) or dict(status='withheld',response='')
            for source,r in [('kernel',rep),('organ',old)]:
                good,asserted = scorer.ok(item,r)
                t = totals[source][item['split']]
                t['n'] += 1
                t['right' if good else 'false_yes' if asserted and not item['valid'] else 'wrong' if asserted else 'withheld'] += 1
            records.append(dict(item=item,kernel=rep,organ=old,ms=ms))
    finally:
        proc.stdin.close()
        proc.wait(timeout=10)
    out.write_text(json.dumps(dict(totals=totals,records=records),indent=1))
    print(sid, panel.name, json.dumps(totals))


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--binary',default='var/stores/bin/stores')
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--seed',type=int)
    ap.add_argument('--only',default='cooking,cooking-v2,cooking-v3,cooking-v3-r2')
    args=ap.parse_args()
    args.out.mkdir(parents=True,exist_ok=True)
    for sid in args.only.split(','):
        row=next(x for x in score.SPECIALISTS if x[0]==sid)
        version=1 if sid=='cooking' else 2 if sid=='cooking-v2' else 3
        if args.seed is not None:
            panel=args.out / ('v%d-seed%d.panel.json'%(version,args.seed))
            if not panel.exists(): generate(version,args.seed,panel)
        else:
            panel=score.SPEC / row[4] / row[5]
        evaluate(args.binary,sid,panel,args.out/(sid+'.json'))

if __name__ == '__main__': main()
