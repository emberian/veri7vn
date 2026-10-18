#!/usr/bin/env python3
"""UNTRUSTED scoped warehouse order/state checks, using immutable source item IDs.

Assertions test declared policy separately from capability. Meaningful unsupported
requests count as withheld-valid even when a refusal-policy assertion passes.
No test uses or changes a user's state. No shipped-panel completion is implied.
"""
import argparse
import json
from pathlib import Path
import sqlite3
import tempfile

from verify import Answerer, ROOT

# Requested quantities are authored expectations, independent of the SML parser.
ACCEPT = [
    ('Reorder 2 M4 valve', 2, 'M4 valve'),
    ('Reorder 1,000 M4 valves', 1000, 'M4 valve'),
    ('Reorder 1e3 M4 valve', 1000, 'M4 valve'),
    ('Restock +2 M4 valve', 2, 'M4 valve'),
    ('Order 2.0 M4 valve', 2, 'M4 valve'),
    ('Please reorder 6/2 M4 valve', 3, 'M4 valve'),
    ('Re-order 2e-1/1e-1 M4 valve', 2, 'M4 valve'),
    ('Could you please reorder 2 more of the M4 valve?', 2, 'M4 valve'),
    ('Reorder two M4 valves', 2, 'M4 valve'),
    ('Reorder 3 blue gaskets', 3, 'blue gasket'),
]
# Some have meaningful interpretations but are outside the one-order interface.
# Their withheld-valid classification must not be hidden by passing assertions.
REFUSE = [
    ('Reorder 2 M4 valve and 3 blue gaskets', 'withheld_valid'),
    ('Reorder 2 M4 valve or 3 blue gaskets', 'withheld_valid'),
    ('If stock is low, reorder 2 M4 valve', 'withheld_valid'),
    ('Reorder four M4 valve', 'withheld_valid'),
    ('Reorder 2 unknown widgets', 'withheld_valid'),
    ('Reorder .5 M4 valve', 'withheld_valid'),
    ('Reorder 1 1/2 M4 valve', 'withheld_valid'),
    ('Reorder 0 M4 valve', 'invalid_quantity'),
    ('Reorder -2 M4 valve', 'invalid_quantity'),
    ('Reorder −2 M4 valve', 'invalid_quantity'),
    ('Reorder 1e+ M4 valve', 'malformed'),
    ('Reorder 1,00 M4 valve', 'malformed'),
    ('Reorder qnum0q M4 valve', 'malformed'),
    ('Reorder 2 M4,valve', 'unsupported_item_spelling'),
    ('Reorder 2M4 valve', 'malformed'),
    ('Reorder 2 M4 valve; reorder 3 blue gasket', 'withheld_valid'),
    ('Reorder 2 M4 valve instead of blue gasket', 'withheld_valid'),
    ('Yes, reorder -2 M4 valve', 'invalid_quantity'),
    ('No, reorder 2 M4 valve and 3 blue gaskets', 'conflicting_instruction'),
    ('Do not reorder 2 M4 valve', 'withheld_valid'),
    ('yes, but only 3 M4 valves', 'withheld_valid'),
    ('yes and cancel', 'conflicting_instruction'),
    ('no, use 3 instead', 'withheld_valid'),
]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--binary', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    binary = args.binary.resolve()
    db = (ROOT/'upstream/root/specialists/warehouse/site_fresh.sqlite3').resolve()
    con = sqlite3.connect(db.as_uri()+'?immutable=1', uri=True)
    skus = dict(con.execute('SELECT name,sku FROM items'))
    con.close()
    base = ROOT/'var/stores/order-check'; base.mkdir(parents=True, exist_ok=True)
    records = []
    with tempfile.TemporaryDirectory(prefix='owned-', dir=base) as tmp:
        tmp = Path(tmp)
        for sid in ('warehouse', 'warehouse-r2'):
            for i, (q, qty, name) in enumerate(ACCEPT):
                state = tmp/f'{sid}-valid-{i}.json'
                p = Answerer(binary, '--specialist', sid, '--state', state)
                try:
                    proposal = p.ask(q)
                    assert proposal.get('kind') == 'confirm', (q, proposal)
                    saved = json.loads(state.read_text())
                    pending = saved['sessions']['checks']['pending']
                    assert pending == [qty, skus[name], name], (q, pending)
                    assert saved['orders'] == []
                    accepted = p.ask('confirm the order' if i % 2 else 'yes please')
                    assert accepted.get('kind') == 'ordered', accepted
                    saved = json.loads(state.read_text())
                    assert len(saved['orders']) == 1 and saved['orders'][0]['qty'] == qty and saved['orders'][0]['sku'] == skus[name]
                    before = state.read_bytes()
                    assert p.ask('yes').get('kind') != 'ordered'
                    assert p.ask('yes', session='different').get('kind') != 'ordered'
                    assert state.read_bytes() == before
                    records.append(dict(sid=sid, q=q, classification='answered_correct', reply=proposal, confirmed=accepted))
                finally: p.close()
            for preview in (False, True):
                state = tmp/f'{sid}-empty-{preview}.json'
                p = Answerer(binary, '--specialist', sid, '--state', state, *(['--preview'] if preview else []))
                try:
                    for q, classification in REFUSE:
                        rep = p.ask(q)
                        assert rep.get('kind') == 'order_clarify' and rep.get('status') == 'withheld', (q, rep)
                        assert not state.exists(), (q, 'created state')
                        records.append(dict(sid=sid, preview=preview, state='absent', q=q, classification=classification, reply=rep))
                finally: p.close()
            state = tmp/f'{sid}-pending.json'
            commit = Answerer(binary, '--specialist', sid, '--state', state)
            preview = Answerer(binary, '--specialist', sid, '--state', state, '--preview')
            try:
                assert commit.ask('M4 valve count?')['value'] == 107
                assert commit.ask('Reorder 7 M4 valve')['kind'] == 'confirm'
                before = state.read_bytes()
                for p, mode in ((preview, 'preview'), (commit, 'commit')):
                    for q, classification in REFUSE:
                        rep = p.ask(q)
                        assert rep.get('kind') == 'order_clarify' and rep.get('status') == 'withheld', (q, rep)
                        assert state.read_bytes() == before, (q, 'changed pending state')
                        records.append(dict(sid=sid, mode=mode, state='pending', q=q, classification=classification, reply=rep))
                assert preview.ask('Reorder 3 blue gaskets')['kind'] == 'confirm'
                assert state.read_bytes() == before
                assert commit.ask('yes')['kind'] == 'ordered'
                saved = json.loads(state.read_text())
                assert len(saved['orders']) == 1 and saved['orders'][0]['qty'] == 7 and saved['orders'][0]['sku'] == skus['M4 valve']
                # A previous stock reference can supply an explicit pronoun, but
                # never supplies the item for a conflicting multi-item phrase.
                assert commit.ask('Reorder two of them')['kind'] == 'confirm'
                assert json.loads(state.read_text())['sessions']['checks']['pending'] == [2, skus['M4 valve'], 'M4 valve']
                assert commit.ask('no thanks')['kind'] == 'cancelled'
                assert json.loads(state.read_text())['sessions']['checks']['pending'] is None
            finally: preview.close(); commit.close()
    totals = dict(assertions_passed=len(records), request_observations=len(records),
                  positive_orders_answered_correct=2*len(ACCEPT), wrong=0, false_yes=0,
                  withheld_valid_observations=sum(r['classification']=='withheld_valid' for r in records),
                  other_refusal_policy_observations=sum(r['classification'] not in ('answered_correct','withheld_valid') for r in records))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(dict(totals=totals, records=records), indent=2)+'\n')
    print(json.dumps(totals))


if __name__ == '__main__': main()
