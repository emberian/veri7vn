#!/usr/bin/env python3
"""Untrusted exact export comparison; reports every changed row, not a score."""
import argparse
from collections import Counter
import json
from pathlib import Path

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('control', type=Path)
    p.add_argument('candidate', type=Path)
    p.add_argument('out', type=Path)
    a = p.parse_args()
    old, new = (json.loads(x.read_text()) for x in (a.control, a.candidate))
    encode = lambda x: json.dumps(x, sort_keys=True, separators=(',', ':'))
    report = {}
    for key in ('templates', 'shapes', 'aliases', 'words', 'forms'):
        before, after = Counter(map(encode, old[key])), Counter(map(encode, new[key]))
        report[key] = {'removed': [json.loads(x) for x in sorted((before-after).elements())],
                       'added': [json.loads(x) for x in sorted((after-before).elements())]}
    report['policy'] = {'control': old['policy'], 'candidate': new['policy']}
    report['metadata'] = {'control': old['metadata'], 'candidate': new['metadata']}
    with a.out.open('x') as f:
        json.dump(report, f, indent=2)
        f.write('\n')
    if old['policy'] != new['policy'] or old['forms'] != new['forms']:
        raise SystemExit('Policy/forms changed: review before running qualification')

if __name__ == '__main__':
    main()
