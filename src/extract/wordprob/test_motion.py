"""Independent finite journey checks. English recognition and Python expectations
are untrusted; the HOL model is scalar total distance divided by elapsed time.
These are selected capability probes, not specialist-panel completion numbers.
"""
import json
import subprocess
import tempfile
import unittest
from fractions import Fraction
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
BIN = ROOT / 'var/wordprob/bin/wordprob'


def question(body, output='km/hour'):
    return f'A car travels {body}. What is its average speed in {output}?'


CASES = [
    (question('at 60 km/hour for 1 hour, then at 30 km/hour for 2 hours'), Fraction(40)),
    (question('60 km in 1 hour, then 60 km in 2 hours'), Fraction(40)),
    (question('at 60 km/hour and 30 km/hour for equal times'), Fraction(45)),
    (question('equal distances at 60 km/hour and 30 km/hour'), Fraction(40)),
    (question('for equal times at 60 km/h and 30 km/h'), Fraction(45)),
    (question('for equal distances at 60 km/h and 30 km/h'), Fraction(40)),
    (question('at 60 km/hour and 30 km/hour for equal distances'), Fraction(40)),
    (question('1000 m in 60 seconds, then 2 km in 2 minutes'), Fraction(60)),
    (question('at 60 km/hour for 1 hour, then stops for 30 minutes'), Fraction(40)),
    (question('at 60 km/hour for 1 hour, then at 0 km/hour for 1 hour'), Fraction(30)),
    (question('60 km at 60 km/hour, then 60 km at 30 km/hour'), Fraction(40)),
    (question('1000 m at 1 km/minute, then 2 km in 2 minutes'), Fraction(60)),
    (question('0 km in 0 hours, then 60 km in 1 hour'), Fraction(60)),
    (question('0 km in 1 hour, then 0 km in 2 hours'), Fraction(0)),
    (question('at 0 km/hour and 0 km/hour for equal times'), Fraction(0)),
    (question('0 km at 10 km/hour, then 60 km in 1 hour'), Fraction(60)),
    (question('at 1e1 km/hour for .5 hours, then at 2e1 km/hour for 1/2 hour'), Fraction(15)),
    (question('at 60 km/hour for 1 hour, then at 30 km/hour for 2 hours', 'meters per second'), Fraction(100,9)),
    (question('30 km in 1 hour, then 60 km in 1 hour, then 90 km in 1 hour'), Fraction(60)),
    (question('equal distances at 1 km/second and 3600 km/hour'), Fraction(3600)),
]


class JourneyTests(unittest.TestCase):
    def ask(self, questions):
        run = subprocess.run([str(BIN)], input=''.join(json.dumps({'id':i,'q':q})+'\n'
            for i,q in enumerate(questions)),text=True,capture_output=True,check=True,timeout=30)
        replies=[json.loads(line) for line in run.stdout.splitlines()]
        self.assertEqual(len(replies),len(questions))
        return replies

    def test_weighting_units_stops_and_exact_literals(self):
        for (q,expected),reply in zip(CASES,self.ask([q for q,_ in CASES])):
            with self.subTest(q=q):
                self.assertEqual(reply['status'],'answered',reply)
                self.assertEqual(reply['kind'],'motion_legs',reply)
                self.assertEqual(reply['provenance']['kernel'],'Wordprob.journey_reply')
                self.assertLessEqual(abs(Fraction(reply['value'])-expected),abs(expected)/200000)

    def test_kernel_refuses_undefined_or_impossible_trip(self):
        questions=[
            question('0 km in 0 hours, then 0 km in 0 hours'),
            question('1 km in 0 hours, then 1 km in 1 hour'),
            question('60 km at 0 km/hour, then 60 km in 1 hour'),
            question('0 km at 0 km/hour, then 60 km in 1 hour'),
            question('equal distances at 0 km/hour and 30 km/hour'),
            question('at -1 km/hour for 1 hour, then at 30 km/hour for 1 hour'),
            question('-1 km in 1 hour, then 30 km in 1 hour'),
            question('1 km in -1 hour, then 30 km in 1 hour'),
        ]
        for q,reply in zip(questions,self.ask(questions)):
            with self.subTest(q=q):
                self.assertEqual(reply['status'],'withheld',reply)
                self.assertEqual(reply['kind'],'invalid_journey',reply)
                self.assertTrue(reply['provenance']['taken'])

    def test_ambiguous_malformed_and_unconsumed_text_refuse(self):
        questions=[
            question('at 60 km/hour and 30 km/hour'),
            question('60 km in 1 hour, then 30 km'),
            question('at 60 km/hour for equal times and equal distances'),
            question('for equal times at 60 km/hour and 30 km/hour for equal distances'),
            question('for equal times at 60 km/hour and 30 km/hour for 1 hour'),
            question('60 km in 1 hour, then 30 km in 1 hour with an extra 10 km'),
            question('60 km in 1 hour, then 30 km in 1 hour except the return trip'),
            question('1e+ km in 1 hour, then 30 km in 1 hour'),
            question('1,23 km in 1 hour, then 30 km in 1 hour'),
            question('qnum0q km in 1 hour, then 30 km in 1 hour'),
            question('QNUM0Q km in 1 hour, then 30 km in 1 hour'),
            question('60 kg in 1 hour, then 30 km in 1 hour'),
            question('at 60 km/kg for 1 hour, then at 30 km/hour for 1 hour'),
            question('60 km in 1 hour, then 30 km in 1 hour','kg/hour'),
            question('60 km in 1 hour, then 30 km in 1 hour','km'),
            question(', then '.join(['1 km in 1 hour']*9)),
            question('60 km in 1 hour, then 30 km in 1 hour')+' Also give the maximum speed.',
        ]
        for q,reply in zip(questions,self.ask(questions)):
            with self.subTest(q=q):
                self.assertEqual(reply['status'],'withheld',reply)
                self.assertTrue(reply['provenance']['taken'])
                self.assertNotIn('value',reply)

    def test_single_leg_existing_measured_route_survives(self):
        q=question('60 km in 2 hours')
        r=self.ask([q])[0]
        self.assertEqual(r['status'],'answered',r)
        self.assertEqual(r['value'],'30')
        self.assertEqual(r['provenance']['kernel'],'Wordprob.measured_reply')

    def test_actual_route_and_guards(self):
        sys.path.insert(0,str(ROOT/'tools/dispatch'))
        from dispatch import Child
        from routes import RouteStages
        with tempfile.TemporaryDirectory() as directory:
            stages=RouteStages(ROOT,ROOT/'var',10,Path(directory),Child,enabled=('wordprob','guards'))
            try:
                for i,(q,expected) in enumerate(CASES):
                    with self.subTest(q=q):
                        raw=stages.answer_wordprob(i,q,{})
                        self.assertIsNotNone(raw)
                        reply=stages.apply_guards(q,raw)
                        self.assertEqual(reply['status'],'answered',reply)
                        self.assertLessEqual(abs(Fraction(reply['value'])-expected),abs(expected)/200000)
            finally:
                stages.close()


if __name__=='__main__': unittest.main()
