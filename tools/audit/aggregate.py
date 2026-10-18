"""Aggregate var/audit/class/*.txt with markers.json into the audit table
(var/audit/table.json and a markdown table on stdout)."""
import json, pathlib
from collections import Counter, defaultdict
R = pathlib.Path('/Users/ember/dev/o7vn/var/audit')
T = json.load(open(R/'thms.json')); M = json.load(open(R/'markers.json'))
def key(t): return t['name'] or (t['file'].split('/')[-1][:-4] + ':' + str(t['line']))
scanned = defaultdict(set)
for m in M: scanned[m['dir'].split('/')[-1]] |= set(m['scanned'])
rows = []; tot = Counter(); tots = Counter()
for f in sorted((R/'class').glob('*.txt')):
    fam = f.stem; cls = {}
    for line in open(f):
        p = line.split()
        if p and not p[0].startswith('#'):
            for n in p[1:]: cls[n] = p[0]
    ts = [t for t in T if t['dir'].split('/')[-1] == fam]
    c = Counter(cls[key(t)] for t in ts)
    cs = Counter(cls[key(t)] for t in ts if t['name'] in scanned[fam])
    claims = sum(c[k] for k in 'VDBXE')
    rows.append(dict(fam=fam, total=len(ts), **{k: c[k] for k in 'VDBXEA'},
                     scanned=sum(cs.values()), scannedB=cs['B'],
                     bshare=round(100 * c['B'] / claims) if claims else 0))
    tot.update(c); tots.update(cs)
json.dump(dict(rows=rows, total=dict(tot), scanned=dict(tots)), open(R/'table.json', 'w'), indent=1)
print('| Family | Theorems | Vacuous | Definitional | Binding | External | Example | Helper | Binding share of claims | Scanned (binding) |')
print('|---|---|---|---|---|---|---|---|---|---|')
for r in rows:
    print(f"| {r['fam']} | {r['total']} | {r['V']} | {r['D']} | {r['B']} | {r['X']} | {r['E']} | {r['A']} | {r['bshare']}% | {r['scanned']} ({r['scannedB']}) |")
claims = sum(tot[k] for k in 'VDBXE')
print(f"| **all** | {sum(tot.values())} | {tot['V']} | {tot['D']} | {tot['B']} | {tot['X']} | {tot['E']} | {tot['A']} | {round(100*tot['B']/claims)}% | {sum(tots.values())} ({tots['B']}) |")
print('scanned by class', dict(tots))
