#!/usr/bin/env python3
"""UNTRUSTED count-serving regression check, with independent Decimal arithmetic.

Reads immutable USDA rows directly; never imports generated kernel arithmetic or
the recognizer. Cases are authored alongside the change, not an external panel.
The shipped cooking scorers remain the completion metric. Source row accuracy,
omission-free fetching and English interpretation are still outside the proof.
"""
import argparse
from decimal import Decimal, ROUND_HALF_UP
import json
from pathlib import Path
import sqlite3

from verify import Answerer, ROOT


def cases():
    db = ROOT / 'upstream/root/specialists/cooking/nutrition_v1.sqlite3'
    con = sqlite3.connect(db.as_uri() + '?immutable=1', uri=True)
    # Exact independently selected rows and labels, not the kernel's search.
    servings = [(168203, 'granny smith apples', s, '1 ' + s)
                for s in ('small', 'medium', 'large')]
    servings += [(170402, 'raw chayotes', '', '1 chayote (5-3/4")'),
                 (170393, 'raw carrots', 'slices of', '1 slice'),
                 (170393, 'raw carrots', 'large strips of', '1 strip large (3" long)'),
                 (170393, 'raw carrots', 'medium strips of', '1 strip medium')]
    quantities = [('1', '1'), ('two', '2'), ('3', '3'), ('1/2', '.5'),
                  ('1 / 2', '.5'), ('1 1/2', '1.5'), ('half a', '.5'), ('2.5', '2.5'),
                  ('.5', '.5'), ('+2.5', '2.5'), ('2e0', '2'), ('2.5e-1', '.25'),
                  ('1,000', '1000'), ('1e3', '1000'), ('1e-3', '.001'),
                  ('1e3/2e3', '.5'), ('1 1 / 2', '1.5'), ('1 1.5/3', '1.5')]
    result = []
    for fid, food, size, label in servings:
        weights = con.execute('SELECT grams FROM portions WHERE fdc_id=? AND label=?', (fid, label)).fetchall()
        assert len(weights) == 1, (fid, label, weights)
        grams = Decimal(str(weights[0][0]))
        for nutrient, amount in con.execute('SELECT key,amount FROM nut WHERE fdc_id=? ORDER BY key', (fid,)):
            # Other carrot nutrients can legitimately clarify baby vs regular
            # carrots; these part-form arithmetic probes ask carbohydrate only.
            if fid == 170393 and nutrient != 'carbohydrate':
                continue
            for text, quantity in quantities:
                phrase, modifier = food, size
                if Decimal(quantity) <= 1:
                    if ' of' in modifier:
                        modifier = modifier.replace('slices', 'slice').replace('strips', 'strip')
                    else:
                        phrase = food[:-1]  # the two chosen whole-food nouns end in s
                q = 'How much %s is in %s?' % (nutrient, ' '.join(x for x in (text, modifier, phrase) if x))
                expected = Decimal(str(amount)) * grams * Decimal(quantity) / 100
                result.append(dict(q=q, kind='nutrient', value=float(expected.quantize(Decimal('.01'), rounding=ROUND_HALF_UP)),
                                   fdc_id=fid, portion=label))
    for food in ('2 granny smith apples', 'two granny smith apples', '2 small raw bananas', '2 strips of raw carrots'):
        result.append(dict(q='How much carbohydrate is in ' + food + '?', kind='clarify'))
    for food in ('two jumbo granny smith apples', 'two large raw chayotes', '2 slices of granny smith apples'):
        result.append(dict(q='How much carbohydrate is in ' + food + '?', kind='no_portion'))
    for food in ('-2 small granny smith apples', '2 1/0 small granny smith apples'):
        result.append(dict(q='How much carbohydrate is in ' + food + '?', kind=None, status='withheld'))
    for food in ('2 small large granny smith apples', '2 mediumish granny smith apples'):
        result.append(dict(q='How much carbohydrate is in ' + food + '?', kind='unknown_food', status='withheld'))
    for amount in ('−2', '− 2', '- two', "2'000", '1 000', '1.2.3', '1e+', '1,00',
                   '1 -1/2', '1 3/2', '1.5 1/2', '½', 'qnum0q', 'QNUM0Q 2', '2 3'):
        result.append(dict(q='How much carbohydrate is in ' + amount + ' small granny smith apples?', status='withheld'))
    for amount in ('−100', '1 000', '1.2.3', 'qnum0q', 'QNUM0Q 100'):
        result.append(dict(q='How much carbohydrate is in ' + amount + ' g of granny smith apples?', status='withheld'))
    protein = Decimal(str(con.execute('SELECT amount FROM nut WHERE fdc_id=170402 AND key="protein"').fetchone()[0]))
    cup = Decimal(str(con.execute('SELECT grams FROM portions WHERE fdc_id=? AND label=?',
                                  (170402, '1 cup (1" pieces)')).fetchone()[0]))
    for unit, grams in [('g', Decimal(1)), ('kg', Decimal(1000)), ('cup', cup)]:
        for text, quantity in quantities:
            expected = protein * Decimal(quantity) * grams / 100
            result.append(dict(q='How much protein is in %s %s of raw chayote?' % (text, unit),
                               kind='nutrient', value=float(expected.quantize(Decimal('.01'), rounding=ROUND_HALF_UP)),
                               fdc_id=170402, role=unit))
    for q in ('How much protein is in qnum0q g of raw chayote and 100 g of raw chayote?',
              'How much protein is in 100 g of raw chayote and 2 apples?',
              'How much protein is in 3.19/gallon of raw chayote?',
              'How much carbohydrate is in granny smith apples ^3?',
              'How much carbohydrate is in ½ granny smith apple?'):
        result.append(dict(q=q, status='withheld'))
    con.close()
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--binary', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--require-pass', action='store_true')
    args = ap.parse_args()
    p = Answerer(args.binary.resolve(), '--specialist', 'cooking-v3')
    records = []
    try:
        for item in cases():
            reply = p.ask(item['q'])
            good = 'kind' not in item or reply.get('kind') == item['kind']
            if 'status' in item:
                good = good and reply.get('status') == item['status']
            if 'value' in item:
                good = good and reply.get('status') == 'answered' and abs(reply.get('value', -1) - item['value']) < 1e-9
            records.append(dict(expected=item, reply=reply, passed=good))
    finally:
        p.close()
    totals = dict(n=len(records), passed=sum(x['passed'] for x in records),
                  failed_answers=sum(not x['passed'] and x['reply'].get('status') == 'answered' for x in records))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(dict(totals=totals, records=records), indent=1))
    print(json.dumps(totals))
    if args.require_pass:
        assert totals['passed'] == totals['n'], [x for x in records if not x['passed']][:3]


if __name__ == '__main__':
    main()
