"""Portable untrusted regressions for complete binomial count/support binding.

ORACLE7_TEST_ROOT selects a read-only source tree. If installed under upstream
 tests/statistics/, the source root is inferred. Truth for small trials is an
independent enumeration of Bernoulli sequences, not the organ's comb formula.
"""
from fractions import Fraction
from itertools import product
import importlib
import math
import os
from pathlib import Path
import sys
import unittest

ROOT=Path(os.environ.get('ORACLE7_TEST_ROOT',Path(__file__).resolve().parents[2]))
SPECS=[('statistics','organ_stats_v1','StatsOrgan'),
       ('statistics-v2','organ_stats_v1','StatsOrgan'),
       ('statistics-v2','organ_stats_v2','StatsOrganV2'),
       ('statistics-v3','organ_stats_v1','StatsOrgan'),
       ('statistics-v3','organ_stats_v2','StatsOrganV2'),
       ('statistics-v3','organ_stats_v3','StatsOrganV3')]
LITERALS=[('0',Fraction(0)),('1',Fraction(1)),('0.5',Fraction(1,2)),
          ('25%',Fraction(1,4)),('0.5%',Fraction(1,200)),('0.5e-2',Fraction(1,200)),('100%',Fraction(1))]


def organ(spec):
    sid,module,cls=spec
    for name in ('organ_stats_v1','organ_stats_v2','organ_stats_v3'):
        sys.modules.pop(name,None)
    sys.path.insert(0,str(ROOT/'root/specialists'/sid))
    try:
        return getattr(importlib.import_module(module),cls)()
    finally:
        sys.path.pop(0)


def question(k,n,p):
    return f'What is the probability of exactly {k} successes in {n} trials with p = {p}?'


def mass(k,n,p):
    return sum((math.prod(p if bit else 1-p for bit in bits)
                for bits in product((0,1),repeat=n) if sum(bits)==k),Fraction())


class BinomialSupport(unittest.TestCase):
    def test_outside_support_is_zero_including_zero_trials_and_endpoints(self):
        for spec in SPECS:
            instance=organ(spec)
            for n in range(6):
                for k in range(n+1,n+5):
                    for literal,p in LITERALS:
                        with self.subTest(spec=spec,n=n,k=k,p=literal):
                            reply=instance.answer(question(k,n,literal))
                            self.assertIsNotNone(reply)
                            self.assertEqual(reply['status'],'answered')
                            self.assertEqual(reply['kind'],'binomial')
                            self.assertEqual(reply['value'],float(mass(k,n,p)))
                            self.assertNotIn('^-',reply['response'])

    def test_within_support_small_exact_sequence_truth_is_unchanged(self):
        for spec in SPECS:
            instance=organ(spec)
            for n in range(6):
                for k in range(n+1):
                    for literal,p in LITERALS:
                        with self.subTest(spec=spec,n=n,k=k,p=literal):
                            reply=instance.answer(question(k,n,literal))
                            self.assertIsNotNone(reply)
                            self.assertEqual(reply['status'],'answered')
                            self.assertAlmostEqual(reply['value'],float(mass(k,n,p)),places=13)

    def test_invalid_or_unsafe_probability_cannot_be_rescued_by_k_above_n(self):
        invalid=['-0.5','-0.5%','1.01','101%','1e2','1e-10000','0.'+'9'*400,
                 '0.5%%','0.5/2','0.5e-2x','1.2.3','0.5e+']
        for spec in SPECS:
            instance=organ(spec)
            for p in invalid:
                with self.subTest(spec=spec,p=p):
                    reply=instance.answer(question(5,3,p))
                    self.assertTrue(reply is None or reply['status']!='answered')

    def test_negative_fractional_and_scientific_count_tokens_are_not_digit_prefixes(self):
        bad=['-3','3.5','.5','3/2','3e2','3e-2','3e+','3e+2x','3%','3,5']
        for spec in SPECS:
            instance=organ(spec)
            for token in bad:
                # Both previously masked out-of-support and in-support parses.
                for k,n in [(50,token),(0,token),(token,1),(token,50)]:
                    with self.subTest(spec=spec,k=k,n=n):
                        reply=instance.answer(question(k,n,'0.5'))
                        self.assertTrue(reply is None or reply['status']!='answered')

    def test_probability_roles_use_the_same_support_rule(self):
        roles=['p = 0.5%','chance of success is 0.5%','probability of success on each trial is 0.5%',
               'success probability is 0.5%','with probability 0.5%']
        for spec in [s for s in SPECS if s[1]!='organ_stats_v1']:
            instance=organ(spec)
            for role in roles:
                with self.subTest(spec=spec,role=role):
                    reply=instance.answer(f'Probability of exactly 5 successes in 3 trials, {role}?')
                    self.assertIsNotNone(reply)
                    self.assertEqual(reply['status'],'answered')
                    self.assertEqual(reply['value'],0.0)

    def test_complete_signed_nonnegative_integer_counts(self):
        for spec in SPECS:
            instance=organ(spec)
            for k,n,wanted in [('+5','+3',0.0),('1','-0',0.0),('+0','+0',1.0)]:
                with self.subTest(spec=spec,k=k,n=n):
                    reply=instance.answer(question(k,n,'1'))
                    self.assertIsNotNone(reply)
                    self.assertEqual(reply['status'],'answered')
                    self.assertEqual(reply['value'],wanted)

    def test_comma_and_parenthesis_delimiters_preserve_integer_atoms(self):
        forms=[
            'What is the probability of exactly {k}, in {n} trials with p = 0.5?',
            'What is the probability of exactly {k} successes in ({n} trials) with p = 0.5?',
            'What is the probability of exactly {k}, in ({n} trials) with p = 0.5?',
            'What is the probability of exactly ({k}) successes in ({n}) trials with p = 0.5?',
            'What is the probability of exactly (({k})), in (({n} trials)) with p = 0.5?']
        for spec in SPECS:
            instance=organ(spec)
            for form in forms:
                for k,n in [(2,3),(5,3),(1,0)]:
                    with self.subTest(spec=spec,form=form,k=k,n=n):
                        reply=instance.answer(form.format(k=k,n=n))
                        self.assertIsNotNone(reply)
                        self.assertEqual(reply['status'],'answered')
                        self.assertEqual(reply['value'],float(mass(k,n,Fraction(1,2))))

    def test_delimiters_do_not_hide_invalid_tokens_or_count_expressions(self):
        bad=['(-3)','(3.5)','(3e2)','(3e-2)','(3/2)','3,5,','(3,5)',
             '(2+3)','2+3','(2)*3','3/(2)','(3)/(2)','3e(2)']
        for spec in SPECS:
            instance=organ(spec)
            for token in bad:
                for k,n in [(0,token),(token,50)]:
                    with self.subTest(spec=spec,k=k,n=n):
                        reply=instance.answer(question(k,n,'0.5'))
                        self.assertTrue(reply is None or reply['status']!='answered')


if __name__=='__main__':
    unittest.main()
