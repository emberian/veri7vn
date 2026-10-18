#!/usr/bin/env python3
"""Untrusted beyond-parity experiment driver for mechanics and space.

Uses the shipped generators/scorers; seed offsets change only their random
choices, not their authored wording. Missing generators are reported explicitly.
No file under upstream is written. Seed 20261019 is the tuning sample; 20261029
is the reserved evaluation. Hand probes are separate from either panel.
"""
import argparse, contextlib, importlib.util, io, json, random, statistics, subprocess, sys, time, types
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
SPECS = ROOT / 'upstream/root/specialists'

def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

def generate(score, record, seed, out):
    sid, _, _, panel, *_ = record
    candidates = sorted(SPECS.glob('*/' + Path(panel).with_suffix('.py').name))
    own = SPECS / sid / Path(panel).with_suffix('.py')
    path = own if own.exists() else next(iter(candidates), None)
    if path is None:
        return None
    dest = out / f'{sid}-seed{seed}.json'
    if not dest.exists():
        gen = module(path, 'fresh_' + sid.replace('-', '_'))
        gen.random = types.SimpleNamespace(Random=lambda original: random.Random(original + seed))
        argv = sys.argv
        sys.argv = [str(path)] + ([score.SHEET] if sid.startswith('astronomy') else []) + [str(dest)]
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                gen.main()
        finally:
            sys.argv = argv
    return json.loads(dest.read_text())

def counts(panel, replies, scorer):
    result = {}
    for split in ('dev', 'heldout'):
        stat = dict(n=0, right=0, wrong=0, false_yes=0, withheld_valid=0, fails=[])
        for item, rep in zip(panel, replies):
            if item['split'] != split: continue
            good, asserted = scorer.ok(item, rep)
            stat['n'] += 1
            if good: stat['right'] += 1
            elif asserted: stat['wrong' if item['valid'] else 'false_yes'] += 1
            elif item['valid']: stat['withheld_valid'] += 1
            if not good: stat['fails'].append(dict(item=item, reply=rep))
        result[split] = stat
    return result

def run():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--family', choices=['mechanics','space'], required=True)
    ap.add_argument('--seed', type=int, default=20261019)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--binary')
    ap.add_argument('--specialists', help='comma-separated specialist IDs to check')
    ap.add_argument('--generate-only', action='store_true')
    ap.add_argument('--shipped', action='store_true', help='score the immutable shipped panels instead of generating')
    args=ap.parse_args(); args.out.mkdir(parents=True,exist_ok=True)
    score=module(ROOT / f'src/extract/{args.family}/score.py','score_'+args.family)
    binary=args.binary or str(ROOT / f'var/{args.family}/bin/{args.family}')
    report=dict(family=args.family, seed=None if args.shipped else args.seed, specialists={}, missing_generators=[])
    for rec in score.SPECIALISTS:
        sid, mod, cls, _, scm, *_=rec
        if args.specialists and sid not in args.specialists.split(','): continue
        panel=json.loads((SPECS/sid/rec[3]).read_text()) if args.shipped else generate(score,rec,args.seed,args.out)
        if isinstance(panel,dict): panel=[dict(x,split=k) for k,v in panel.items() if isinstance(v,list) for x in v]
        if panel is None:
            report['missing_generators'].append(sid); continue
        if args.generate_only: continue
        kwargs=rec[6] if len(rec)>6 else {}
        organ=getattr(score.load(sid,mod),cls)(**kwargs)
        scorer=score.load(sid,scm)
        oreps=[]
        for item in panel:
            try: rep=organ.answer(item['q'])
            except Exception as e: rep=dict(status='withheld',response='',error=repr(e))
            oreps.append(rep or dict(status='withheld',response=''))
        proc=subprocess.Popen([binary,'--specialist',sid],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
        kreps=[]; timings=[]
        for n,item in enumerate(panel):
            rep,ms=score.ask(proc,str(n),item['q']); kreps.append(rep); timings.append(ms)
        proc.stdin.close(); proc.wait()
        report['specialists'][sid]=dict(organ=counts(panel,oreps,scorer),kernel=counts(panel,kreps,scorer),p50_ms=statistics.median(timings))
        print(sid,[(sp,st['right'],st['wrong'],st['false_yes'],st['withheld_valid']) for sp,st in report['specialists'][sid]['kernel'].items()],flush=True)
    (args.out / ('summary.json' if not args.generate_only else 'generation.json')).write_text(json.dumps(report,indent=2))
    print('missing generators:',report['missing_generators'])

if __name__=='__main__': run()
