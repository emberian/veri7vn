#!/usr/bin/env python3
"""Untrusted bounded witnesses against actual upstream reader modules.

Supply a directory with relation_spec_v1.py and relation_spec_v2.py obtained at
an explicit revision. Uses controlled linker/type/row fixtures, no Engine or
corpus. Assertions record buggy observations, not a correctness gate. Optional
--composer-source takes the proposed PR's v1 file to reproduce its composer path.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import types
from unittest.mock import patch


def load(path, name, modules):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    with patch.dict(sys.modules, modules):
        spec.loader.exec_module(m)
    return m


def router():
    return types.SimpleNamespace(
        L=types.SimpleNamespace(STOP=set(), candidates=lambda name, limit: [(1, 10), (2, 9)]),
        norm=lambda text: re.sub(r'[^a-z0-9]+', ' ', text.lower()).strip(),
        _show=lambda value, *args: value, DOMINANCE=10,
        TIME_VARIANT=set(), PAST=re.compile(r'\b(?:was|were)\b'))


def film_witness(source, explicit_composer=False):
    m = load(source, 'audited_relation_v1', {'exact_router_v1': router()})
    m.in_domain = lambda qid, domain: (qid, domain) in {(1, 'films'), (2, 'songs')}
    m.values = lambda qid, prop: frozenset({1: ['Film composer'], 2: ['Song composer']}[qid]) if prop == 86 else frozenset()
    m.analyse = lambda q: {'cands': [1, 2], 'feats': [('who', 'composed')]}
    q = 'Who composed the film Song of Dawn?'
    patterns = {} if explicit_composer else {'fwd|who|composed': [86]}
    film, song = m.answer(q, 'films', patterns), m.answer(q, 'songs', patterns)
    assert film['answer'] == 'Film composer' and song['answer'] == 'Song composer'
    assert m.kind_conflict(q, 'songs') is False
    # The title word alone disables the intended cross-domain rejection.
    assert m.kind_conflict('Who composed the film Dawn?', 'songs') is True
    return {'question': q, 'films': film, 'songs': song,
            'expected': 'Explicit film qualifier must not be satisfied by a song subject.'}


def inverse_witness(source):
    x = router()
    store = types.SimpleNamespace(label=lambda qid: {102: 'First spouse', 103: 'Second spouse'}[qid])
    v1 = types.SimpleNamespace(X=x, kind_conflict=lambda *args: False,
                              _restates=lambda *args: False, _rs=lambda: store)
    m = load(source, 'audited_relation_v2', {'relation_spec_v1': v1,
                                           'relation_readers_v1': types.SimpleNamespace(PROPS={})})
    m.compiled = lambda key: {'prop': 26, 'fwd': [], 'inv': [re.compile(r'^who is married to (?P<X>.+?)$')]}
    m.in_domain = lambda qid, domain: True
    seen = []
    def query(sql, args):
        seen.append(list(args))
        return {101: [102], 201: [103]}[args[1]]
    v1._q = query
    m.slot_candidates = lambda slot: ([101, 201], [10, 10])
    q = 'Who is married to Target?'
    result = m.answer(q, 'actors', [26])
    assert result['subject_qid'] == 102 and seen == [[26, 101]]
    first = {'reply': result, 'queries': list(seen)}
    seen.clear()
    m.slot_candidates = lambda slot: ([201, 101], [10, 10])
    result = m.answer(q, 'actors', [26])
    assert result['subject_qid'] == 103 and seen == [[26, 201]]
    return {'question': q, 'first_order': first, 'reverse_order': {'reply': result, 'queries': seen},
            'expected': 'Equally plausible distinct targets with different subjects require ambiguity/refusal.'}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', type=Path, required=True)
    ap.add_argument('--composer-source', type=Path)
    args = ap.parse_args()
    v1, v2 = args.source / 'relation_spec_v1.py', args.source / 'relation_spec_v2.py'
    out = {'source_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (v1, v2)},
           'inverse': inverse_witness(v2), 'film_main': film_witness(v1)}
    if args.composer_source:
        out['composer_source_sha256'] = hashlib.sha256(args.composer_source.read_bytes()).hexdigest()
        out['film_proposed_pr'] = film_witness(args.composer_source, explicit_composer=True)
    print(json.dumps(out, indent=2))


if __name__ == '__main__':
    main()
