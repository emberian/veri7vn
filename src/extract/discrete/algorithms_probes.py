#!/usr/bin/env python3
"""Untrusted authored algorithm checks using independent finite enumeration.
Not independent-language evidence. Random graphs are deliberately small.
"""
import argparse,itertools,json,random,re,subprocess,sys
from fractions import Fraction
from pathlib import Path

def tree_weight(nodes,edges):
    vals=[]
    for picked in itertools.combinations(edges,len(nodes)-1):
        seen={nodes[0]}
        while True:
            more=seen|{a for a,b,w in picked if b in seen}|{b for a,b,w in picked if a in seen}
            if more==seen:break
            seen=more
        if len(seen)==len(nodes):vals.append(sum((w for a,b,w in picked),Fraction(0)))
    return min(vals) if vals else None

def shortest_dag(nodes,edges,start,end):
    # Enumerate actual finite directed paths in a DAG; no Dijkstra recurrence.
    def paths(u,seen):
        if u==end:return [Fraction(0)]
        return [w+d for a,b,w in edges if a==u and b not in seen for d in paths(b,seen|{b})]
    values=paths(start,{start});return min(values) if values else None

def cases(seed=181301):
    rng=random.Random(seed);rows=[]
    lists=[[Fraction(1,2),Fraction(3),Fraction(4),Fraction(5)],[Fraction(1),Fraction(2),Fraction(3),Fraction(4,5)],[],[Fraction(-1,3)],[Fraction(1,3),Fraction(2,7),Fraction(-1,3)]]
    lists += [[Fraction(rng.randrange(-20,21),rng.randrange(1,11)) for _ in range(rng.randrange(2,10))] for _ in range(20)]
    for xs in lists:
        for desc in [False,True]:
            rows.append(dict(q=f'Sort [{", ".join(map(str,xs))}] in {"descending" if desc else "ascending"} order',kind='sorted',exact=list(map(str,sorted(xs,reverse=desc)))))
    for xs in [sorted(x) for x in lists if x]:
        x=rng.choice(xs);rows.append(dict(q=f'Using binary search for {x} in the sorted list [{", ".join(map(str,xs))}], what index is it at?',kind='bsearch',list=list(map(str,xs)),target=str(x)))
    for _ in range(25):
        nodes=list('ABCD');edges=[(a,b,Fraction(rng.randrange(-8,15),rng.randrange(1,5))) for a,b in itertools.combinations(nodes,2) if rng.random()<.8]
        wt=tree_weight(nodes,edges)
        if wt is None:continue
        q='Edges: '+', '.join(f'{a}-{b}({w})' for a,b,w in edges)+'. What is the weight of the minimum spanning tree?'
        rows.append(dict(q=q,kind='mst',exact=str(wt)))
    for _ in range(25):
        nodes=list('ABCD');edges=[(a,b,Fraction(rng.randrange(-8,15),rng.randrange(1,5))) for a,b in itertools.combinations(nodes,2) if rng.random()<.8]
        dist=shortest_dag(nodes,edges,'A','D')
        if dist is None:continue
        q='Edges: '+', '.join(f'{a}->{b}({w})' for a,b,w in edges)+'. What is the shortest path from A to D?'
        rows.append(dict(q=q,kind='shortest_path',exact=str(dist),certified_or_withheld=any(w<0 for a,b,w in edges)))
    rows.extend([
      dict(q='Edges: A-a(1), a-B(2), A-B(10). What is the shortest path from A to B?',kind='shortest_path',exact='3'),
      dict(q='Edges: A to B(1), B to C(2). What is the shortest path from C to A?',kind='unreachable'),
      dict(q='Edges: A-A(7). What is the weight of the minimum spanning tree?',kind='mst',exact='0'),
      dict(q='Edges: A-B(9), A-B(-2), B-C(1). What is the weight of the minimum spanning tree?',kind='mst',exact='-1'),
      dict(q='Sort [+1/2, -3/-4, .25, -0.5]',kind='sorted',exact=['-1/2','1/4','1/2','3/4']),
      dict(q='Using binary search for 1/7 in the sorted list [], what index is it at?',kind='not_found'),
      dict(q='Using binary search for 1/7 in the sorted list [1/9, 1/8], what index is it at?',kind='not_found')])
    rows += [dict(q='Edges: A->B(-1), B->C(2), A->C(10). What is the shortest path from A to C?',kind='shortest_path',exact='1'),dict(q='Edges: A->B(2), A->C(5), C->B(-7). What is the shortest path from A to B?',certified_or_withheld=True,exact='-2'),dict(q='Edges: A->B(-1), B->A(-1), B->C(1). What is the shortest path from A to C?',unsupported=True,semantic='valid')]
    for q in ['Sort [1/0, 2, 3]','Sort [1, two, 3]','Sort [1, 2, 3] and [4, 5, 6]','Edges: A-B(-1), B-C(2), A-C(10). What is the weight of the minimum spanning tree?','Edges: A-B(1/2), B-C(2/3), A-C(10). What is the weight of the minimum spanning tree?']:
        if '-1' in q:rows.append(dict(q=q,kind='mst',exact='1'))
        elif '1/2' in q:rows.append(dict(q=q,kind='mst',exact='7/6'))
        else:rows.append(dict(q=q,unsupported=True,semantic='undefined' if '1/0' in q else 'valid'))
    for q,semantic in [
      ('Sort [1, 2, 3,]', 'ambiguous'), ('Sort [[1, 2], 3]', 'valid'),
      ('Sort [1, 2, 3] and then reverse twice','valid'),
      ('Sort [1e3, 2, 3]','valid'),('Sort [1, 2, 3] in ascending order and descending order','ambiguous'),
      ('Edges: A-B(-1), B-C(2), A-C(10), C-D(unknown). What is the weight of the minimum spanning tree?','ambiguous'),
      ('Edges: A-B(1/0), B-C(2), A-C(10). What is the weight of the minimum spanning tree?','undefined'),
      ('Edges: A-B(1e3), B-C(2), A-C(10). What is the weight of the minimum spanning tree?','valid'),
      ('Edges: A->B(1), B->C(2). What is the weight of the minimum spanning tree?','ambiguous'),
      ('Edges: A-B(1), B-C(2). Nodes: A, B, C, D. What is the weight of the minimum spanning tree?','valid'),
      ('Using binary search for 1/2+1 in the sorted list [1, 2, 3], what index is it at?','valid'),
    ]:rows.append(dict(q=q,unsupported=True,semantic=semantic))
    return rows

def check(it,rep):
    if it.get('unsupported'):return rep.get('status')=='withheld' and rep.get('provenance',{}).get('taken') is True
    if it.get('certified_or_withheld') and rep.get('status')=='withheld':return rep.get('provenance',{}).get('taken') is True
    if rep.get('status')!='answered':return False
    if it.get('kind') and rep.get('kind')!=it['kind']:return False
    if it.get('kind') in ['unreachable','not_found']:return True
    if it.get('kind')=='bsearch':
        i=rep.get('value');return isinstance(i,int) and 0<=i<len(it['list']) and Fraction(it['list'][i])==Fraction(it['target'])
    if it.get('kind')=='sorted':
        body=rep.get('response','').partition(':')[2].strip().rstrip('.')
        try:got=[] if not body or body=='[]' else [Fraction(x.strip()) for x in body.split(',')]
        except ValueError:return False
        return got==list(map(Fraction,it['exact'])) and isinstance(rep.get('value'),list) and [Fraction(str(x)) for x in rep['value']]==got
    m=re.search(r'(?:weight|length) is (-?\d+(?:/\d+|\.\d+)?)',rep.get('response',''))
    return bool(m) and Fraction(m[1])==Fraction(it['exact']) and Fraction(str(rep.get('value')))==Fraction(it['exact'])

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--binary',default='var/discrete/bin/discrete');ap.add_argument('--out',required=True);ap.add_argument('--seed',default=181301,type=int);ap.add_argument('--dispatch',choices=['pinned','unpinned']);a=ap.parse_args();items=cases(a.seed)
    cmd=[a.binary,'--specialist','algorithms']
    if a.dispatch:
        cmd=[sys.executable,'-B','tools/dispatch/dispatch.py','--order','front','--organs','discrete','--no-reader','--no-document','--no-routes']
        if a.dispatch=='pinned':cmd+=['--specialist','algorithms']
    p=subprocess.run(cmd,input=''.join(json.dumps({'id':i,'q':x['q']})+'\n' for i,x in enumerate(items)),text=True,capture_output=True,check=True,timeout=60)
    rows=[dict(case=it,reply=rep,ok=check(it,rep)) for it,rep in zip(items,map(json.loads,p.stdout.splitlines()),strict=True)]
    if a.dispatch:
        for row in rows:
            if row['reply'].get('status')=='withheld' and row['ok']:row['ok'] &= row['reply'].get('provenance',{}).get('dispatch',{}).get('decisive') is True
    valid=[r for r in rows if r['case'].get('semantic','valid')=='valid'];other=[r for r in rows if r not in valid]
    answered=lambda r:r['reply'].get('status')=='answered'
    outcomes=dict(valid_requests=len(valid),answered_correct=sum(answered(r) and r['ok'] for r in valid),answered_wrong=sum(answered(r) and not r['ok'] for r in valid),withheld_valid=sum(not answered(r) for r in valid),ambiguous_or_undefined=len(other),other_answered=sum(answered(r) for r in other),other_withheld=sum(not answered(r) for r in other))
    report=dict(seed=a.seed,command=cmd,n=len(rows),assertions_passed=sum(r['ok'] for r in rows),outcomes=outcomes,rows=rows);Path(a.out).write_text(json.dumps(report,indent=2)+'\n');print(report['assertions_passed'],report['n'],outcomes)
    if report['assertions_passed']!=report['n']:raise SystemExit(1)
if __name__=='__main__':main()
