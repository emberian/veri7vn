#!/usr/bin/env python3
"""Untrusted read-only source provenance audit; never executes a KB program.

Replays pinned learn7 for candidate training rows with the image's aliases.
This reconstructs contributions, not answers, and does not alter admission.
"""
import argparse
import hashlib
import importlib
import json
from pathlib import Path
import sqlite3
import sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--source-dir', required=True)
    ap.add_argument('--train', required=True)
    ap.add_argument('--image', required=True)
    ap.add_argument('--template', default='which X1')
    ap.add_argument('--terminal', default='Count')
    args = ap.parse_args()
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(Path(args.source_dir).resolve()))
    r7 = importlib.import_module('reader_v7')
    for module in (r7, r7.R4, r7.R6):
        if Path(module.__file__).resolve().parent != Path(args.source_dir).resolve():
            raise ValueError('import escaped pinned source')
    db = sqlite3.connect(Path(args.image).resolve().as_uri() + '?mode=ro&immutable=1', uri=True)
    db.execute('PRAGMA query_only=ON')
    aliases = {(p, k): t for p, k, t in db.execute('SELECT phrase,kind,canonical FROM reader_alias')}
    raw = Path(args.train).read_bytes()
    train = json.loads(raw)
    output = {'train_sha256': hashlib.sha256(raw).hexdigest(),
              'source_sha256': {Path(m.__file__).name: hashlib.sha256(Path(m.__file__).read_bytes()).hexdigest()
                                for m in (r7, r7.R4, r7.R6)}, 'contributions': []}
    del raw
    for category, words in [('operator', r7.R6.OPS), ('glue', r7.GLUE), ('keep', r7.R6.KEEPW)]:
        words.clear()
        words.update(w for (w,) in db.execute('SELECT word FROM reader_word WHERE category=?', (category,)))
    # Only exact outer templates are audited. Preserve the exported glue set;
    # per-row learn7 recalculates glue at level 0 after adding its exact rows.
    by_lit = {}
    for (phrase, kind), target in aliases.items():
        by_lit.setdefault((kind, target), []).append(phrase)
    output['forms'] = dict(db.execute('SELECT opening,kinds FROM reader_form'))
    for i, row in enumerate(train):
        if row['program'][-1]['function'] != args.terminal:
            continue
        if r7.R4.norm(row['question']).split()[0] != args.template.split()[0]:
            continue
        for level in (0, 1):
            _, outer, _, _ = r7.learn7([row], aliases, keys=bool(level))
            for sk, n in outer.get(args.template, {}).items():
                output['contributions'].append({'index': i, 'level': level, 'question': row['question'],
                    'alignment_spans': r7.align(row, bool(level), by_lit)[1],
                    'answer': row.get('answer'), 'program': row['program'], 'skeleton': json.loads(sk), 'support': n})
    output['stored_rows'] = [dict(level=l, skeleton=json.loads(s), support=n) for l, s, n in db.execute(
        'SELECT level,skeleton,support FROM reader_template WHERE family=? AND template=?', ('outer', args.template))
        if json.loads(s)[-1]['function'] == args.terminal]
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
