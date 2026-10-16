#!/usr/bin/env python3
"""Read-only deployment diagnosis. Does not start Isabelle or modify its state."""
import argparse
import json
from pathlib import Path
import sqlite3
from stage import digest


def inspect(heap, database, receipt, repo):
    record=json.loads(receipt.read_text())
    mismatches=[]
    absent=[]
    for name,expected in record.get('sources_sha256',{}).items():
        source=repo/name
        if not source.is_file(): absent.append(name)
        elif digest(source)!=expected: mismatches.append(name)
    result={'session':'Veri7vn_Runtime_Service','producer_attempt':record.get('attempt_id'),
            'producer_status':record.get('status'),'heap_exists':heap.is_file(),
            'source_absent':absent,'source_changed_since_receipt':mismatches,
            'build_metadata':None,'ready':False,
            'assurance':'read-only prerequisite diagnosis; not native launch qualification'}
    if database.is_file():
        # mode=ro never creates a missing database; timeout avoids waiting for builds.
        try:
            connection=sqlite3.connect(database.resolve().as_uri()+'?mode=ro',uri=True,timeout=0)
            try:
                rows=connection.execute('SELECT session_name,return_code,uuid,sources,input_heaps,output_heap FROM isabelle_session_info WHERE session_name=?',('Veri7vn_Runtime_Service',)).fetchall()
                result['build_metadata']=[dict(zip(('session','return_code','uuid','sources','input_heaps','output_heap'),r)) for r in rows]
            finally: connection.close()
        except sqlite3.Error as error: result['database_error']=str(error)
    result['ready']=bool(record.get('status') == 'passed' and result['heap_exists'] and result['build_metadata'] and
                         result['build_metadata'][0]['return_code']==0 and not absent and not mismatches)
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--heap',required=True,type=Path)
    parser.add_argument('--database',required=True,type=Path)
    parser.add_argument('--receipt',required=True,type=Path)
    parser.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[2])
    args=parser.parse_args()
    report=inspect(args.heap,args.database,args.receipt,args.repo)
    print(json.dumps(report,indent=2))
    raise SystemExit(0 if report['ready'] else 1)

if __name__=='__main__': main()
