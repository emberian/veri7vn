#!/usr/bin/env python3
"""Actual preview/guard/commit consumer checks against the built stores program.

UNTRUSTED test driver. Injected guard rejection and commit failure test sequencing,
not whether the guard's question recognizer is complete. Scratch receipts stay
under var/dispatch. No upstream data is written.
"""
import argparse
import hashlib
import json
from pathlib import Path
from types import SimpleNamespace

import dispatch as D


def driver(var, pin=''):
    args = SimpleNamespace(order='front' if pin else 'head', var_root=str(var),
        organs='stores,chemistry', specialist=pin, no_reader=True,
        no_document=True, no_routes=False, arb=str(D.REPO/'var/dispatch/bin/arb_check'), timeout=10)
    return D.Dispatcher(args)


def state_path(d):
    child = next(ch for ch, slug in d.organs if slug == 'stores')
    return Path(child.argv[child.argv.index('--state') + 1])


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--var-root', type=Path, default=D.REPO/'var')
    a = ap.parse_args()
    receipts = []
    d = driver(a.var_root)
    state = state_path(d)
    try:
        replies = [d.turn(str(i), q, 'preview') for i, q in enumerate(
            ['Reorder 5 M4 valve', 'yes', 'Reorder M4 valve. What is the molar mass of H2O?',
             'Reorder M4 valve. What is the molar mass of H2O?'])]
        assert all('error' not in r for r in replies), replies
        assert not state.exists()
        for r in replies[2:]:
            assert 'warehouse-r2' in r['provenance']['dispatch']['cands']
            assert 'specialist:warehouse' not in r['path']
        stock = d.turn('stock', 'M4 valve count?', 'stock')
        assert stock['status'] == 'answered' and stock['kind'] == 'stock', stock
        assert '107' in stock['response'] and stock['provenance']['preview'] is True, stock
        assert 'guards' in stock['provenance']['dispatch']['stages_run']
        assert not state.exists()
        cooking = d.turn('cook', 'How much protein is in 100 g of raw chayote?', 'cook')
        assert cooking['status'] == 'answered' and abs(cooking['value'] - .82) < 1e-8
        assert 'guards' in cooking['provenance']['dispatch']['stages_run']
        assert not state.exists()
        receipts.append(dict(case='unpinned_preview_and_losing_candidates', state_path=str(state),
                             replies=replies, stock=stock, cooking=cooking, state_exists=False))
    finally:
        d.close()

    d = driver(a.var_root, 'warehouse-r2')
    state = state_path(d)
    try:
        replies = [d.turn(str(i), q, session) for i, (q, session) in enumerate([
            ('Reorder 5 M4 valve', 'order'), ('yes', 'order'), ('yes', 'order'), ('yes', 'other')])]
        assert all('error' not in r for r in replies), replies
        assert len(json.loads(state.read_text())['orders']) == 1
        for r in replies[:2]:
            assert r['provenance']['dispatch']['stages_run'] == ['specs', 'guards', 'commit']
            assert r['provenance']['dispatch']['commit']['matches_preview'] is True
            assert r['provenance']['precision_guards']['checked_before_commit'] is True
            assert r['provenance']['preview'] is False
        read = d.turn('reference-stock', 'M4 valve count?', 'reference')
        follow = d.turn('reference-where', 'Where is it?', 'reference')
        fresh = d.turn('fresh-where', 'Where is it?', 'fresh-reference')
        assert read['kind'] == 'stock' and 'commit' in read['provenance']['dispatch']['stages_run'], read
        assert follow['kind'] == 'where' and 'A5-05' in follow['response'], follow
        assert fresh['status'] == 'withheld' and 'error' not in fresh, fresh
        assert len(json.loads(state.read_text())['orders']) == 1
        replies += [read, follow, fresh]
        receipts.append(dict(case='private_preview_guard_commit', state_path=str(state),
                             state=json.loads(state.read_text()), replies=replies))
    finally:
        d.close()

    d = driver(a.var_root, 'warehouse-r2')
    state = state_path(d)
    guard = d.routes.apply_guards
    def block(text, reply):
        return dict(reply, status='withheld', response='Injected guard rejection', path='test>guard_block')
    try:
        d.routes.apply_guards = block
        blocked_proposal = d.turn('block-proposal', 'Reorder 5 M4 valve', 'blocked')
        assert blocked_proposal['status'] == 'withheld' and not state.exists()
        d.routes.apply_guards = guard
        proposal = d.turn('proposal', 'Reorder 5 M4 valve', 'blocked')
        before = state.read_bytes()
        d.routes.apply_guards = block
        blocked_yes = d.turn('block-yes', 'yes', 'blocked')
        assert blocked_yes['status'] == 'withheld' and state.read_bytes() == before
        d.routes.apply_guards = guard
        ordered = d.turn('yes', 'yes', 'blocked')
        assert ordered['kind'] == 'ordered' and len(json.loads(state.read_text())['orders']) == 1
        receipts.append(dict(case='guard_block_preserves_state', state_path=str(state),
                             blocked_proposal=blocked_proposal, proposal=proposal,
                             blocked_yes=blocked_yes, ordered=ordered))
    finally:
        d.close()

    d = driver(a.var_root, 'warehouse-r2')
    state = state_path(d)
    try:
        calls = []
        def fail(*args):
            calls.append(args)
            return {'error': 'injected uncertain commit outcome'}
        d.commit_organs['stores'].ask = fail
        out = d.turn('error', 'Reorder 5 M4 valve', 'error')
        assert out['path'] == 'dispatch>commit_error' and len(calls) == 1
        assert out['provenance']['dispatch']['commit']['retries'] == 0
        assert not state.exists()
        receipts.append(dict(case='commit_error_no_retry', reply=out, calls=len(calls)))
    finally:
        d.close()
    out = a.var_root/'dispatch/c-runtime-final/state-transaction.json'
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({'stores_sha256': hashlib.sha256((a.var_root/'stores/bin/stores').read_bytes()).hexdigest(), 'cases': receipts}, indent=2)+'\n')
    print('PASS: preview and losing candidates do not write; guards precede one commit; blocked turns preserve state; failed commits are not retried')


if __name__ == '__main__':
    main()
