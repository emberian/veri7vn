#!/usr/bin/env python3
"""Emit named exact questions for real core measurement; never executes an Engine."""
import argparse
import json
from pathlib import Path


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--split', choices=('dev','heldout'), required=True)
    p.add_argument('--out', type=Path, required=True)
    a=p.parse_args()
    panel=json.loads(Path(__file__).with_name('panel.json').read_text())[a.split]
    rows=[{'id':'modeling-'+a.split+'-'+item['id'], 'conversation_id':'modeling-'+a.split+'-'+item['id'], 'text':item['q']} for item in panel]
    with a.out.open('x') as f:
        json.dump(rows,f,indent=2); f.write('\n')

if __name__=='__main__':main()
