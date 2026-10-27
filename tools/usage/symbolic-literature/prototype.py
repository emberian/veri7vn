#!/usr/bin/env python3
"""UNTRUSTED symbolic research fixture. No formal proof or production authority.

Replays one hand-written conditional identity, demonstrates finite-domain CEGIS,
and compares an isolated copy of the actual AP1 chain selector with guarded
alternative selection. This is deliberately not an e-graph or an SMT solver.
"""
from dataclasses import dataclass
from fractions import Fraction
from pathlib import Path
import ast
import hashlib
import json

ROOT = Path(__file__).resolve().parents[3]

@dataclass(frozen=True)
class Interval:
    lo: Fraction
    hi: Fraction
    def __post_init__(self):
        if self.lo > self.hi:
            raise ValueError('empty interval is not evidence')
    def disjoint(self, other):
        return self.hi < other.lo or other.hi < self.lo

# The certificate is data. The checker does not execute producer code.
ORIGINAL = ('div', ('sub', ('mul', 'x', 'x'), ('mul', 'y', 'y')), ('sub', 'x', 'y'))
SIMPLIFIED = ('add', 'x', 'y')

def replay(certificate, domains, units):
    if certificate != {'rule': 'difference_of_squares_cancel', 'from': ORIGINAL, 'to': SIMPLIFIED}:
        return False, 'unknown or mismatched rule instance'
    if units.get('x') != units.get('y'):
        return False, 'addition/subtraction unit mismatch'
    if not domains['x'].disjoint(domains['y']):
        return False, 'x != y is unproved; keep original domain'
    return True, 'guard x != y supported by disjoint rational enclosures'


def guarded_cases():
    cert = {'rule': 'difference_of_squares_cancel', 'from': ORIGINAL, 'to': SIMPLIFIED}
    safe = {'x': Interval(Fraction(3), Fraction(4)), 'y': Interval(Fraction(1), Fraction(2))}
    overlap = {'x': Interval(Fraction(1), Fraction(4)), 'y': Interval(Fraction(1), Fraction(2))}
    cases = []
    for name, domains, units, expected in [
        ('separated-lengths', safe, {'x': 'm', 'y': 'm'}, True),
        ('possible-singularity', overlap, {'x': 'm', 'y': 'm'}, False),
        ('different-dimensions', safe, {'x': 'm', 'y': 's'}, False),
    ]:
        accepted, why = replay(cert, domains, units)
        assert accepted == expected
        cases.append({'case': name, 'accepted': accepted, 'reason': why})
    tampered = dict(cert, to=('sub', 'x', 'y'))
    assert replay(tampered, safe, {'x':'m','y':'m'})[0] is False
    checked = 0
    for x in range(3, 5):
        for y in range(1, 3):
            assert Fraction(x*x-y*y, x-y) == x+y
            checked += 1
    # Explicitly record the actual singularity, not a numeric disagreement.
    try:
        Fraction(2*2-2*2,2-2)
    except ZeroDivisionError:
        cases.append({'case':'x=y=2','original':'undefined','unguarded_candidate':4})
    else:
        raise AssertionError('singularity not exercised')
    return {'cases': cases, 'tampered_certificate_rejected':True, 'point_checks':checked,
            'scope':'Python rule replay and sample checks only; no HOL theorem'}


def packet_spec(n, d, q):
    return q >= 0 and q*d >= n and (q == 0 or (q-1)*d < n)


def cegis():
    # Mathematical integers, not fixed-width machine words. Domain is explicit.
    domain = [(n,d) for n in range(65) for d in range(1,17)]
    candidates = [('n // d',lambda n,d:n//d),
                  ('(n + 1) // d',lambda n,d:(n+1)//d),
                  ('(n + d - 1) // d',lambda n,d:(n+d-1)//d)]
    examples = [(4,2)]
    rounds = []
    for _ in range(len(candidates)):
        name, run = next((name,run) for name,run in candidates if all(packet_spec(n,d,run(n,d)) for n,d in examples))
        bad = next(((n,d) for n,d in domain if not packet_spec(n,d,run(n,d))),None)
        rounds.append({'candidate':name,'counterexample':bad})
        if bad is None:
            assert name == '(n + d - 1) // d'
            return {'query':'How many packets hold n payload bytes with capacity d bytes per packet?',
                    'domain':'n integer 0..64, d integer 1..16', 'rounds':rounds,
                    'exhaustively_checked_inputs':len(domain),
                    'scope':'finite enumeration as the verifier; no SMT solver or unbounded proof'}
        examples.append(bad)
    raise AssertionError('CEGIS failed')


def planning():
    source = ROOT/'var/ap1-upstream-slim/workbench/swarm/point.py'
    parsed = ast.parse(source.read_text())
    node = next(n for n in parsed.body if isinstance(n,ast.FunctionDef) and n.name=='_chain')
    # Only this function is loaded. No Engine, module import, network or program execution.
    space = {}
    exec(compile(ast.Module(body=[node],type_ignores=[]),str(source),'exec'),space)
    formulas = [
        {'id':'pump-a', 'in_dims':['volume (L)','pump a rate (L/s)'],'out_dim':'fill time (s)'},
        {'id':'pump-b', 'in_dims':['volume (L)','pump b rate (L/s)'],'out_dim':'fill time (s)'},
    ]
    known = {'volume (L)':Fraction(60),'pump a rate (L/s)':Fraction(0),'pump b rate (L/s)':Fraction(2)}
    old = space['_chain'](formulas,known,'fill time (s)')
    assert [p['id'] for p in old] == ['pump-a']
    # A tiny positive relational rule: keep every producer whose guard is true.
    # This fixture uses one step; it makes no general planning-completeness claim.
    alternatives = []
    rejected = []
    for p in formulas:
        volume, rate = (known[k] for k in p['in_dims'])
        if volume >= 0 and rate > 0:
            alternatives.append({'plan':p['id'],'seconds':str(volume/rate)})
        else:
            rejected.append({'plan':p['id'],'guard':'volume >= 0 and rate > 0'})
    assert alternatives == [{'plan':'pump-b','seconds':'30'}]
    return {'query':'Fill a 60 L cistern with either pump A at 0 L/s or pump B at 2 L/s.',
            'source':str(source.relative_to(ROOT)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
            'existing_chain_selected':[p['id'] for p in old],
            'existing_selected_route':'division by zero would fail at execution; no wrong answer claimed',
            'guarded_alternatives':alternatives,'rejected':rejected,
            'scope':'actual _chain selection versus isolated one-step guarded fixture; not a full planner run'}


if __name__=='__main__':
    result = {'guarded_rewrite':guarded_cases(),'cegis':cegis(),'planning':planning(),
              'specialist_panel_scores':None,'formal_theorems_added':0}
    print(json.dumps(result,indent=2))
