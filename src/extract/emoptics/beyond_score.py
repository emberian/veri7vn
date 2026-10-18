#!/usr/bin/env python3
"""UNTRUSTED measurement harness. Uses shipped generators/scorers read-only.
Fresh panels change generator seeds, not templates or their author's assumptions.
Wiring has no shipped generator, and is explicitly absent from fresh totals.
"""
import argparse, contextlib, io, json, statistics, subprocess, sys, time
from pathlib import Path
sys.dont_write_bytecode = True
import score

def run(binary, sid, panel, scorer):
    p = subprocess.Popen([str(binary), '--specialist',sid],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
    counts = {}; misses=[]; times=[]
    for i,it in enumerate(panel):
        rep,ms=score.ask(p,str(i),it['q']); times.append(ms)
        good,asserted=scorer.ok(it,rep)
        c=counts.setdefault(it['split'],dict(n=0,right=0,wrong=0,false_yes=0,withheld=0))
        c['n']+=1;c['right']+=bool(good)
        if not good:
            c['false_yes' if not it['valid'] and asserted else 'wrong' if asserted else 'withheld']+=1
            misses.append(dict(item=it,reply=rep))
    p.stdin.close();p.wait()
    return dict(counts=counts,misses=misses,p50_ms=statistics.median(times))

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--binary',type=Path,required=True);ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--offsets',default='71019,82031');args=ap.parse_args();args.out.mkdir(parents=True,exist_ok=True)
    results={}
    for sid,mod,cls,panel_file,scorer_mod,tol in score.SPECIALISTS:
        scorer=score.load(sid,scorer_mod);organ=getattr(score.load(sid,mod),cls)()
        datasets={'shipped':json.loads((score.SPEC/sid/panel_file).read_text())}
        gen=score.SPEC/sid/panel_file.replace('.json','.py')
        if not gen.exists() and sid.startswith('optics'):gen=score.SPEC/'optics-v5'/gen.name
        if gen.exists():
            for offset in map(int,args.offsets.split(',')):
                dest=args.out/f'{sid}-seed-plus-{offset}.json'
                src=gen.read_text().replace('random.Random(seed)',f'random.Random(seed + {offset})')
                old=sys.argv;sys.argv=[str(gen),str(dest)]
                try:
                    with contextlib.redirect_stdout(io.StringIO()):exec(compile(src,str(gen),'exec'),{'__name__':'__main__'})
                finally:sys.argv=old
                datasets[f'seed-plus-{offset}']=json.loads(dest.read_text())
        result={}
        for ds,items in datasets.items():
            r=run(args.binary,sid,items,scorer)
            organ_counts={}
            for it in items:
                rep=organ.answer(it['q']) or {};good,asserted=scorer.ok(it,rep)
                c=organ_counts.setdefault(it['split'],dict(n=0,right=0,wrong=0,false_yes=0,withheld=0))
                c['n']+=1;c['right']+=bool(good)
                if not good:c['false_yes' if not it['valid'] and asserted else 'wrong' if asserted else 'withheld']+=1
            r['organ']=organ_counts;result[ds]=r
            print(sid,ds,r['counts'],flush=True)
        results[sid]=result
    (args.out/'results.json').write_text(json.dumps(results,indent=2))
if __name__=='__main__':main()
