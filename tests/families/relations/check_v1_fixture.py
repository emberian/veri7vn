#!/usr/bin/env python3
"""Check the exact v1 observation used by Novel_Relations, without world adoption."""
from pathlib import Path
import sqlite3
root = Path(__file__).resolve().parents[3]
path = root / 'upstream/root/relstore/relations_v1.sqlite3'
connection = sqlite3.connect(f'file:{path}?mode=ro', uri=True)
rows = connection.execute('SELECT s,p,o,lit FROM fact WHERE s=? AND p=?', (170583,50)).fetchall()
assert rows == [(170583,50,36322,None)], rows
assert connection.execute('SELECT label FROM entity WHERE qid=?',(36322,)).fetchone() == ('Jane Austen',)
print('PASS: exact retained v1 Q170583/P50/Q36322 observation; no v2 snapshot or domain closure claimed')
