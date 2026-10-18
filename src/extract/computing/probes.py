#!/usr/bin/env python3
"""Untrusted beyond-panel probes, written by the recognizer/proof author.

Direct expectations derive from the existing typed command/reference tables,
IPv4 host arithmetic, character-space arithmetic, and differential-drive law.
SQL expectations come from in-memory SQLite, independently of the HOL engine.
The SQL comparison checks the whole rendered result, unlike the shipped scorer's
ordered-substring check. These tests do not prove interpretation is correct.
"""
import argparse
import json
from pathlib import Path
import random
import sqlite3
import subprocess
import sys
sys.dont_write_bytecode = True
from score import ask, load

PROBES = [
 ('git', 'How do I bring back my git stash?', ['git stash pop']),
 ('git', 'What command restores the stash in git?', ['git stash pop']),
 ('git', 'What git command brings back stashed changes?', ['git stash pop']),
 ('git', 'How do I apply my git stash and keep it?', ['git stash apply']),
 ('git', 'How do I restore my git stash without dropping it?', ['git stash apply']),
 ('git', 'Which git command lists the saved stashes?', ['git stash list']),
 ('git', 'What command shows git stashes?', ['git stash list']),
 ('git', 'What git command cherry-picks a specific commit?', ['git cherry-pick']),
 ('git', 'What command shows the log in git?', ['git log']),
 ('git', 'How do I stash all my changes in git?', ['git stash']),
 ('git', 'What command deletes a git stash?', None),
 ('git', 'What command compares two git stashes?', None),
 ('git', 'What command encrypts the git stash?', None),
 ('git', 'Should I keep the git stash?', None),
 ('python', 'Explain what divmod does in Python.', 'Return the tuple (x//y, x%y).'),
 ('python', "What arguments does Python's ord take?", '(c, /)'),
 ('python', 'Explain what math.frobnicate does in Python.', None),
 ('networking', 'Which prefix would you use to fit 500 devices?', 23),
 ('networking', 'Which prefix would you use to fit 13 devices?', 28),
 ('networking', 'How many usable hosts are in a /35 subnet?', None),
 ('cyber', 'Worst-case time to exhaust all 4-character passwords from lowercase letters at 1 million guesses per second?', 0.456976),
 ('cyber', 'A password is 12 characters long, chosen randomly from alphanumeric characters. Entropy in bits?', 71.45035572464249),
 ('robotics-v2', "A rover's wheels are 0.5 m apart. Its right wheel runs at 0.8 m/s and its left wheel at 0.3 m/s. What is its rate of turn in rad/s?", 1.0),
 ('robotics-v2', "A rover's wheels are 0.5 m apart. Its right wheel runs at 0.3 m/s and its left wheel at 0.8 m/s. What is its rate of turn in rad/s?", -1.0),
]
SCORERS = dict(git='git_scorer', python='pyref_scorer', networking='networking_scorer', cyber='cyber_scorer', **{'robotics-v2':'robotics_scorer'})


def sql_cases(seed):
    rng = random.Random(seed)
    rows = [(rng.choice([None,'a','b']), rng.choice([None,-2,0,1,1,2,3])) for _ in range(12)]
    def lit(v): return 'NULL' if v is None else repr(v)
    setup = 'CREATE TABLE t (g TEXT, n INTEGER);' + ''.join('INSERT INTO t VALUES (%s,%s);' % (lit(g),lit(n)) for g,n in rows)
    queries = [
      'SELECT DISTINCT g FROM t ORDER BY g',
      'SELECT DISTINCT n FROM t ORDER BY n DESC',
      'SELECT DISTINCT g,n FROM t ORDER BY g,n',
      'SELECT DISTINCT g,n FROM t WHERE n > 0 ORDER BY n,g',
      'SELECT DISTINCT g FROM t WHERE n IS NULL ORDER BY g',
      'SELECT DISTINCT n FROM t WHERE n > 20',
      'SELECT DISTINCT n FROM t ORDER BY n LIMIT 2',
      'SELECT g,COUNT(*) FROM t GROUP BY g ORDER BY g',
      'SELECT g,COUNT(n) FROM t GROUP BY g ORDER BY g DESC',
      'SELECT g,COUNT(*) FROM t WHERE n > 0 GROUP BY g ORDER BY g',
      'SELECT g,COUNT(*) FROM t WHERE n IS NULL GROUP BY g ORDER BY g',
      'SELECT g,COUNT(*) FROM t WHERE n > 20 GROUP BY g ORDER BY g',
      'SELECT g,SUM(n),AVG(n),MIN(n),MAX(n) FROM t GROUP BY g ORDER BY g',
      'SELECT g,COUNT(DISTINCT n),SUM(DISTINCT n) FROM t GROUP BY g ORDER BY g',
    ]
    with sqlite3.connect(':memory:') as db:
        db.executescript(setup)
        for query in queries:
            yield f'Given `{setup}` what does `{query}` return?', db.execute(query).fetchall()
    # Integers and equal reals are one DISTINCT class. NULL is a class too.
    setup = 'CREATE TABLE t (n);INSERT INTO t VALUES (1),(1.0),(NULL),(NULL),(2),(2.0);'
    with sqlite3.connect(':memory:') as db:
        db.executescript(setup)
        for query in ['SELECT DISTINCT n FROM t ORDER BY n', 'SELECT n,COUNT(*) FROM t GROUP BY n ORDER BY n']:
            yield f'Given `{setup}` what does `{query}` return?', db.execute(query).fetchall()


def sql_expected(rows):
    def value(v):
        if v is None: return 'NULL'
        if isinstance(v,str): return "'" + v.replace("'", "''") + "'"
        return ('%.10g' % v) if isinstance(v,float) else str(v)
    if not rows: return 'It returns no rows'
    if len(rows)==1 and len(rows[0])==1: return 'It returns '+value(rows[0][0])
    return ('It returns %d %s: ' % (len(rows), 'row' if len(rows)==1 else 'rows') +
            '; '.join(value(row[0]) if len(row)==1 else '('+', '.join(value(v) for v in row)+')' for row in rows))


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--binary',default='var/computing/bin/computing')
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--seed',type=int,default=921877)
    args=ap.parse_args()
    procs={}
    def get(sid,q):
        if sid not in procs: procs[sid]=subprocess.Popen([args.binary,'--specialist',sid],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
        return ask(procs[sid],str(len(results)),q)[0]
    results=[]
    for sid,q,expected in PROBES:
        rep=get(sid,q)
        scorer=load(sid,SCORERS[sid])
        kind='doc' if sid=='python' and 'Explain' in q else 'signature' if sid=='python' else 'cmd' if sid=='git' else 'probe'
        item=dict(q=q,kind=kind,valid=expected is not None,expect=expected)
        good,asserted=scorer.ok(item,rep)
        results.append(dict(specialist=sid,q=q,expected=expected,reply=rep,right=good,wrong=bool(expected is not None and asserted and not good),false_yes=bool(expected is None and asserted)))
    for q,rows in sql_cases(args.seed):
        rep=get('sql',q)
        expected=sql_expected(rows)
        actual=rep.get('response','').split(' (computed from',1)[0].split(' (run in SQLite',1)[0]
        good=rep.get('status')=='answered' and actual==expected
        results.append(dict(specialist='sql',q=q,expected=expected,reply=rep,right=good,wrong=rep.get('status')=='answered' and not good,false_yes=False))
    for p in procs.values():p.stdin.close();p.wait()
    report=dict(seed=args.seed,n=len(results),right=sum(r['right'] for r in results),wrong=sum(r['wrong'] for r in results),false_yes=sum(r['false_yes'] for r in results),results=results)
    args.out.write_text(json.dumps(report,indent=2)+'\n')
    print({k:v for k,v in report.items() if k!='results'})
    for r in results:
        if not r['right']:print('FAIL',r['specialist'],r['q'],r['expected'],r['reply'])


if __name__=='__main__':main()
