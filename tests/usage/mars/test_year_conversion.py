"""Real specialist-chain and family checks, with independent conversion expectations."""
import json
import math
import os
from pathlib import Path
import re
import sys
import unittest

ROOT=Path(__file__).resolve().parents[3]
SOURCE=Path(os.environ.get('MARS_SOURCE',ROOT/'var/ap1-upstream-slim')).resolve()
DATA=Path(os.environ.get('MARS_DATA_ROOT',ROOT/'var/usage-20261026/candidate-final/root')).resolve()
os.environ['ORACLE7_ROOT']=str(DATA)
sys.path.insert(0,str(SOURCE/'root/specialists/_gate'))
from combo_runtime_v1 import _Organ, Family
IDS=['astronomy','astronomy-v2','astronomy-v3','astronomy-v3-r2']


class YearConversionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dirs=[SOURCE/'root/specialists'/sid for sid in IDS]
        cls.organs=[_Organ(str(d/'manifest.json'),organ_dir=str(d)) for d in cls.dirs]
        cls.cases=json.loads((ROOT/'tools/usage/mars/cases.json').read_text())
        cls.expected=json.loads((ROOT/'tools/usage/mars/case-expectations.json').read_text())

    def test_all_versions_handle_21_cases(self):
        for organ in self.organs:
            for case in self.cases:
                with self.subTest(organ=organ.id,case=case['id']):
                    with organ._env(): reply=organ.organ.answer(case['text'])
                    expect=self.expected[case['id']]['value']
                    if expect is None:
                        self.assertIsNotNone(reply)
                        self.assertNotEqual(reply['status'],'answered',reply)
                    else:
                        self.assertEqual(reply['status'],'answered',reply)
                        self.assertTrue(math.isclose(reply['value'],expect,rel_tol=1e-12,abs_tol=1e-12),reply)

    def test_family_in_both_orders(self):
        for dirs in [self.dirs,list(reversed(self.dirs))]:
            family=Family([str(d/'manifest.json') for d in dirs],organ_dirs=[str(d) for d in dirs])
            for case in self.cases:
                with self.subTest(order=[d.name for d in dirs],case=case['id']):
                    reply=family.reply(case['text'])
                    expect=self.expected[case['id']]['value']
                    if expect is None:
                        self.assertTrue(reply is None or reply['status']!='answered',reply)
                    else:
                        self.assertEqual(reply['status'],'answered',reply)
                        got=re.search(r'are about ([\d.]+) (\w+) years',reply['response'])
                        self.assertIsNotNone(got,reply)
                        self.assertTrue(math.isclose(float(got[1]),expect,rel_tol=1e-10,abs_tol=1e-10),reply)

    def test_short_conversion_forms(self):
        for question in ['3 Mars years in Earth years','3 Mars years are how many Earth years?',
                         'How many Earth years in 3 Mars years?', 'How many Earth years are 3 years on Mars?']:
            with self.subTest(question=question),self.organs[2]._env():
                answer=self.organs[2].organ.answer(question)
                self.assertAlmostEqual(answer['value'],2061/365.25)

    def test_correct_units_and_input_origin(self):
        with self.organs[2]._env():
            answer=self.organs[2].organ.answer(self.cases[0]['text'])
            reverse=self.organs[2].organ.answer(self.cases[1]['text'])
            default=self.organs[2].organ.answer('Convert 3 Mars years to Earth years.')
        self.assertIn('5.64271047228 Earth years',answer['response'])
        self.assertIn('Mars supplied, Earth supplied',answer['response'])
        self.assertIn('1.59497816594 Mars years',reverse['response'])
        self.assertIn('Mars NASA table, Earth Earth-year convention',default['response'])

    def test_context_conditions_never_silently_become_periods(self):
        for question in ['Mars takes 687 days to rotate. How many Earth years are 3 Mars years?',
                         'Mars takes 687 days, but Earth takes 365.25 hours. How many Earth years are 3 Mars years?',
                         'How many Earth years are 3.2.1 Mars years?',
                         'How many Earth years are 3e2 Mars years?',
                         'Mars takes NaN days. How many Earth years are 3 Mars years?']:
            with self.subTest(question=question),self.organs[2]._env():
                answer=self.organs[2].organ.answer(question)
                self.assertTrue(answer is None or answer['status']!='answered',answer)

    def test_unrelated_mass_query_not_taken_by_conversion(self):
        with self.organs[2]._env():
            reply=self.organs[2].organ.answer('How many times more massive is Jupiter than Mars?')
        self.assertEqual(reply['kind'],'ratio')
        self.assertIn("Jupiter's mass",reply['response'])

    def test_imported_copies_are_local_to_their_specialist(self):
        for organ,directory in zip(self.organs,self.dirs):
            for name,module in organ.mods.items():
                if name.startswith('organ_astronomy'):
                    self.assertEqual(Path(module.__file__).parent,directory)


if __name__=='__main__':unittest.main()
