#!/usr/bin/env python3
"""UNTRUSTED isolated sensor evidence checks; no production store is modified.

Expected clocks, timestamp ties and ranges are evaluated independently in Python.
Guard/refusal assertion passes are not counted as answered capability. Meaningful
questions without an unambiguous current reading are withheld-valid.
"""
import argparse
from datetime import datetime, timedelta
from decimal import Decimal
import json
from pathlib import Path
import re
import shutil
import sqlite3
import tempfile

from verify import Answerer, ROOT


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--binary', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    original = ROOT/'upstream/root/specialists/warehouse/site_fresh.sqlite3'
    con = sqlite3.connect(original.resolve().as_uri()+'?immutable=1', uri=True)
    meta = dict(con.execute('SELECT key,value FROM meta'))
    sensors = con.execute("SELECT s.id,s.kind,s.lo,s.hi FROM sensors s JOIN zones z ON z.id=s.zone_id WHERE z.name='Aisle 1' ORDER BY s.kind").fetchall()
    con.close()
    now = datetime.fromisoformat(meta['now']); fresh = int(meta['fresh_minutes'])
    stamp = lambda age: (now-timedelta(seconds=age)).isoformat()
    specs = [
        ('future', [(-1, 0)], 'sensor_time', 'dated after'),
        ('conflict-a', [(10, 0), (10, 1)], 'sensor_conflict', 'latest readings disagree'),
        ('conflict-b', [(10, 1), (10, 0)], 'sensor_conflict', 'latest readings disagree'),
        ('same-value-tie', [(10, 0), (10, 0)], None, None),
        ('fresh-boundary', [(fresh*60, 0)], None, None),
        ('stale-boundary', [(fresh*60+1, 0)], 'stale', 'sensor stale'),
        ('at-now', [(0, 0)], None, None),
        ('old-conflict-latest-clear', [(20, 0), (20, 1), (10, 0)], None, None),
        ('missing', [], 'sensor_missing_data', 'has no reading'),
    ]
    base = ROOT/'var/stores/sensor-check'; base.mkdir(parents=True, exist_ok=True)
    records=[]
    with tempfile.TemporaryDirectory(prefix='owned-', dir=base) as tmp:
        tmp=Path(tmp)
        for sid in ('warehouse','warehouse-r2'):
            for sensor_id,kind,lo,hi in sensors:
                good=(Decimal(str(lo))+Decimal(str(hi)))/2
                bad=Decimal(str(hi))+abs(Decimal(str(hi))-Decimal(str(lo)))+1
                values=[good,bad]
                for case,readings,decline,zone_flag in specs:
                    db=tmp/'site.sqlite3';shutil.copyfile(original,db)
                    con=sqlite3.connect(db)
                    con.execute('DELETE FROM readings WHERE sensor_id=?',(sensor_id,))
                    con.executemany('INSERT INTO readings VALUES(?,?,?)',[(stamp(age),sensor_id,float(values[i])) for age,i in readings])
                    con.commit();con.close()
                    state=tmp/(sid+'-'+kind+'-'+case+'.state.json')
                    p=Answerer(args.binary.resolve(),'--specialist',sid,'--site',db,'--preview','--state',state)
                    try:
                        for query_kind,q in [('sensor',f'What is the {kind} in Aisle 1?'),('range',f'Is the {kind} in Aisle 1 within range?')]:
                            r=p.ask(q)
                            if decline:
                                assert r.get('status')=='withheld' and r.get('kind')==decline,(case,kind,r)
                                classification='withheld_valid'
                            else:
                                assert r.get('status')=='answered' and r.get('kind')==query_kind,(case,kind,r)
                                if query_kind=='sensor':assert abs(Decimal(str(r['value']))-good)<Decimal('.000001'),r
                                else:assert r.get('value')=='yes',r
                                classification='answered_correct'
                            records.append(dict(sid=sid,sensor=kind,case=case,q=q,classification=classification,reply=r))
                        r=p.ask('How is Aisle 1?')
                        assert r.get('status')=='answered' and r.get('kind')=='zone_status',r
                        text=r.get('response','').lower()
                        if decline:
                            assert zone_flag in text,(case,kind,r)
                            assert not re.search(r'\b'+re.escape(kind)+r'\s+-?\d',text),(case,kind,r)
                            assert 'all readings in range' not in text,(case,kind,r)
                        else:assert re.search(r'\b'+re.escape(kind)+r'\s+[-\d]',text),(case,kind,r)
                        records.append(dict(sid=sid,sensor=kind,case=case,q='How is Aisle 1?',classification='zone_policy_checked',reply=r))
                        assert not state.exists()
                    finally:p.close()
    totals=dict(observations=len(records),assertions_passed=len(records),
                answered_correct=sum(r['classification']=='answered_correct' for r in records),
                withheld_valid=sum(r['classification']=='withheld_valid' for r in records),
                zone_policy_checks=sum(r['classification']=='zone_policy_checked' for r in records),
                wrong_assertions=0,state_files_created=0)
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(dict(totals=totals,records=records),indent=2)+'\n')
    print(json.dumps(totals))


if __name__=='__main__':main()
