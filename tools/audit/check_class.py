"""Check var/audit/class/<fam>.txt covers every theorem of the family once.
Format: lines '<CLASS> name name ...' with CLASS in V D B X E A; unnamed
lemmas are referred to as File:line. Prints counts per class."""
import json, sys, re, pathlib
from collections import Counter
T = json.load(open('/Users/ember/dev/o7vn/var/audit/thms.json'))
def key(t): return t['name'] or (t['file'].split('/')[-1][:-4] + ':' + str(t['line']))
res = {}
for fam in sys.argv[1:]:
    rows = [t for t in T if t['dir'].endswith('/' + fam)]
    keys = Counter(key(t) for t in rows)
    cls = {}
    for line in open(f'/Users/ember/dev/o7vn/var/audit/class/{fam}.txt'):
        line = line.strip()
        if not line or line.startswith('#'): continue
        c, *names = line.split()
        for n in names:
            if n in cls: print(fam, 'DUP', n)
            cls[n] = c
    missing = [k for k in keys if k not in cls]
    extra = [n for n in cls if n not in keys]
    cnt = Counter()
    for k, m in keys.items(): cnt[cls.get(k, '?')] += m
    print(f"{fam}: total={len(rows)} " + ' '.join(f"{c}={cnt[c]}" for c in 'VDBXEA?') + (f" MISSING={missing}" if missing else '') + (f" EXTRA={extra}" if extra else ''))
