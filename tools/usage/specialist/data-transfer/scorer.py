"""Independent literal-gold scorer; does not import the organ or search echoed input numbers.

Only an explicit time result at the start of the reply counts. Both the numeric
value and seconds unit must match; arbitrary numbers in an explanation do not.
This format is deliberately strict and suitable for this specialist's own panel.
"""
from decimal import Decimal, InvalidOperation
import re

RESULT = re.compile(r"\AEstimated transfer time: (-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?) seconds\.")


def ok(item, reply):
    asserted = reply.get('status') == 'answered'
    if not item.get('valid', True):
        return not asserted, asserted
    if not asserted:
        return False, False
    match = RESULT.match(str(reply.get('response', '')))
    if not match:
        return False, True
    try:
        got, want = Decimal(match[1]), Decimal(item['a'])
        return abs(got-want) <= max(Decimal('1e-12'), abs(want)*Decimal('1e-10')), True
    except (InvalidOperation, KeyError):
        return False, True
