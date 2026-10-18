#!/usr/bin/env python3
"""UNTRUSTED scoped panel runner. Uses the shipped authors' generators and scorers.
Fresh seeds vary generator choices, not the fixed phrasing templates. The generated
questions stay under var; no upstream files are written. This is evidence, not proof.
"""
import argparse, importlib.util, json, sys
from pathlib import Path
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location('humanities_score', HERE/'score.py')
score = importlib.util.module_from_spec(spec); spec.loader.exec_module(score)
p = argparse.ArgumentParser(); p.add_argument('--binary',required=True); p.add_argument('--out',required=True)
p.add_argument('--seeds',default='610018,710019'); a=p.parse_args()
out=Path(a.out); out.mkdir(parents=True,exist_ok=True)
report={}
for salt in map(int,a.seeds.split(',')):
    for sid,folder,mod,cls,pfolder,panel_file,scorer_mod,tol in score.SPECIALISTS:
        source=score.SPEC/pfolder/panel_file.replace('.json','.py')
        dest=out/(sid+'-'+str(salt)+'.json')
        source_text=source.read_text().replace('random.Random(seed)', 'random.Random(seed + '+str(salt)+')')
        assert source_text != source.read_text(), source
        oldargv=sys.argv; sys.argv=[str(source),str(dest)]
        try: exec(compile(source_text,str(source),'exec'),{'__name__':'__main__','__file__':str(source)})
        finally: sys.argv=oldargv
        organ=getattr(score.load(folder,mod),cls)()
        scorer=score.load(pfolder,scorer_mod)
        result=score.run_panel(a.binary,['--specialist',sid],sid,json.loads(dest.read_text()),scorer,organ,tol)
        result.pop('rtt_ms'); result.pop('specialist_ms')
        control = {}
        for item in json.loads(dest.read_text()):
            t = control.setdefault(item['split'], dict(n=0,right=0,wrong=0,false_yes=0,withheld_valid=0))
            reply = organ.answer(item['q']) or {'status':'withheld','response':''}
            good, asserted = scorer.ok(item,reply)
            t['n'] += 1; t['right'] += int(good)
            if not item['valid']: t['false_yes'] += int(asserted)
            elif not good: t['wrong' if asserted else 'withheld_valid'] += 1
        result['shipped_organ'] = control
        report[sid+':'+str(salt)]=result
        print(sid,salt,{split:{k:v for k,v in t.items() if k!='fails'} for split,t in result['splits'].items()})
(out/'report.json').write_text(json.dumps(report,indent=2))
