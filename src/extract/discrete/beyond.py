#!/usr/bin/env python3
"""Untrusted test harness: upstream generators/scorers, plus explicit calculus probes.

Never writes upstream. Generator seeds are shifted without modifying their source.
Only games, logic and formats ship generators; algorithms/calculus have no generator
in the supplied snapshot. Fresh samples share their authors' tables and templates.
Probes are authored with this recognizer and are not independent external evidence.
"""
import argparse, json, random, runpy, statistics, sys, time
from pathlib import Path
import score
sys.dont_write_bytecode = True
GENERATORS = {'games-v3': 'games_panel_v3.py', 'logic-v3': 'logic_panel_v3.py', 'dataformats': 'formats_panel_v1.py'}

def generate(sid, seed, dest):
    original, argv, path = random.Random, sys.argv, sys.path[:]
    random.Random = lambda n=None: original((n or 0) + seed)
    sys.argv = [GENERATORS[sid], str(dest)]
    sys.path.insert(0, str(score.SPEC / sid))
    try:
        runpy.run_path(str(score.SPEC / sid / GENERATORS[sid]), run_name='__main__')
    finally:
        random.Random, sys.argv, sys.path = original, argv, path

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--binary', default='var/discrete/bin/discrete')
    ap.add_argument('--seeds', nargs='+', type=int, default=[181013,181027])
    ap.add_argument('--out', required=True)
    args=ap.parse_args(); out=Path(args.out);out.mkdir(parents=True,exist_ok=True)
    report={}
    for seed in args.seeds:
        for sid, mod, cls, _, scorer_mod, tol in score.SPECIALISTS:
            if sid not in GENERATORS: continue
            panelpath=out / f'{sid}-{seed}.json'; generate(sid,seed,panelpath)
            panel=score.read_panel(panelpath)
            organ=getattr(score.load(sid,mod),cls)(); scorer=score.load(sid,scorer_mod)
            result=score.run_panel(args.binary,['--specialist',sid],sid,panel,scorer,organ,tol)
            result['p50_rtt_ms']=statistics.median(result.pop('rtt_ms'))
            result['p50_kernel_ms']=statistics.median(result.pop('specialist_ms'))
            shipped={}
            for split in ('dev','heldout'):
                counts=dict(n=0,right=0,wrong=0,withheld_valid=0,false_yes=0)
                for it in (x for x in panel if x['split']==split):
                    rep=organ.answer(it['q']) or {};good,asserted=scorer.ok(it,rep);counts['n']+=1
                    if good:counts['right']+=1
                    elif not it['valid']:counts['false_yes']+=int(asserted)
                    elif asserted:counts['wrong']+=1
                    else:counts['withheld_valid']+=1
                shipped[split]=counts
            result['shipped_organ']=shipped;report[f'{sid}-{seed}']=result
    (out/'report.json').write_text(json.dumps(report,indent=2))
    for key,r in report.items():
        print(key, {s:{k:v for k,v in c.items() if k!='fails'} for s,c in r['splits'].items()},'organ',r['shipped_organ'])
if __name__=='__main__':main()
