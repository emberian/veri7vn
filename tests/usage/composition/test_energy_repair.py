"""Independent requested-quantity checks for the actual private v3 organ chain."""
import importlib
import json
import math
import os
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[3]
DIRECTORY = Path(os.environ.get('ENERGY_ORGAN_DIRECTORY', ROOT / 'var/ap1-upstream-slim/root/specialists/energy-v3'))
sys.path.insert(0, str(DIRECTORY))
from organ_energy_v3 import EnergyOrganV3


class EnergyRepairTests(unittest.TestCase):
    def setUp(self):
        self.organ = EnergyOrganV3()

    def value(self, q, expected, kind=None):
        reply = self.organ.answer(q)
        self.assertIsNotNone(reply, q)
        self.assertEqual(reply['status'], 'answered', reply)
        self.assertAlmostEqual(reply['value'], expected, msg=reply)
        self.assertTrue(math.isfinite(reply['value']))
        if kind: self.assertEqual(reply['kind'],kind)
        return reply

    def refusal(self, q):
        reply = self.organ.answer(q)
        self.assertTrue(reply is None or reply['status'] != 'answered', reply)
        return reply

    def test_original_six_energy_failures(self):
        results = {'solar_useful':1.6, 'net_energy':3.5, 'battery_roles':7.2,
                   'battery_plain':7.2, 'battery_rating_first':7.2, 'battery_invalid':None}
        for file in ['composition/cases.json','engineering/cases.json','engineering/followup_cases.json']:
            for c in json.loads((ROOT/'tools/usage'/file).read_text()):
                if c['id'] in results:
                    with self.subTest(case=c['id']):
                        value=results[c['id']]
                        if value is None: self.refusal(c['text'])
                        else: self.value(c['text'],value)

    def test_runtime_role_permutations_and_kw_units(self):
        for detail in ['with a 500 W rated inverter run a 100 W load',
                       'run a 100 W load through a 500 W rated inverter',
                       'with an inverter rated at 0.5 kW run a 0.1 kW load']:
            self.value('How long can a 1000 Wh battery '+detail+' with 90% inverter efficiency and 80% depth of discharge?',7.2,'runtime')
        self.value('How long can a 24 V 50 Ah battery run a 200 W load with efficiency 0.9 and usable fraction 0.8?',4.32)

    def test_zero_and_full_factors(self):
        for eff,depth,value in [(0,80,0),(90,0,0),(100,100,10)]:
            self.value(f'How long can a 1000 Wh battery run a 100 W load with {eff}% efficiency and {depth}% depth of discharge?',value)

    def test_bad_factor_ranges_and_unbound_conditions(self):
        for adjustment in ['120% efficiency','-10% efficiency','110% depth of discharge',
                           '90% charging efficiency','90% motor efficiency','20% reserve',
                           'inverter efficiency unspecified','temperature derate 0.8',
                           'half full','a variable load','0.8 state of charge']:
            with self.subTest(adjustment=adjustment):
                self.refusal('How long can a 1000 Wh battery run a 100 W load with '+adjustment+'?')

    def test_loss_is_not_multiplied_twice(self):
        self.value('How long can a 1000 Wh battery run a 100 W load with 10% inverter losses and 80% depth of discharge?',7.2)
        self.value('How long can a 1000 Wh battery run a 100 W load with 90% efficiency and 10% losses?',9)
        self.refusal('How long can a 1000 Wh battery run a 100 W load with 90% efficiency and 20% losses?')
        self.refusal('How long can a 1000 Wh battery run a 100 W load with 90% efficiency and 80% efficiency?')

    def test_power_constraints_and_ambiguity(self):
        for q in ['How long can a 1000 Wh battery run a 600 W load through a 500 W inverter?',
                  'How long can a 1000 Wh battery run a 0 W load?',
                  'How long can a 1000 Wh battery run a -100 W load?',
                  'How long can a 1000 Wh battery run a 100 W fan and a 200 W heater?',
                  'How long can a 1000 Wh battery with a 500 W inverter run?',
                  'How long can a 1000 Wh battery run a 100 W load with a 5 W standby draw?']:
            self.refusal(q)

    def test_conflicting_capacity_and_negative_values(self):
        self.refusal('How long can a 1000 Wh battery with 12 V and 10 Ah run a 100 W load?')
        self.refusal('How long can a -1000 Wh battery run a 100 W load?')
        self.value('How long can a 120 Wh battery with 12 V and 10 Ah run a 100 W load?',1.2)

    def test_remaining_uses_battery_side_withdrawal(self):
        r=self.value('A battery initially stores 5 kWh. A 500 W load runs for 3 hours with 90% inverter efficiency. How much energy remains in the battery?',5-1.5/0.9)
        self.assertIn('remaining energy',r['response'])
        r=self.value('A battery initially stores 5 kWh. A 500 W load runs for 5 hours with 80% depth of discharge. How much usable energy remains?',1.5)
        self.assertIn('usable remaining',r['response'])

    def test_remaining_requires_initial_and_feasible_duration(self):
        for q in ['A 5 kWh battery supplies a 500 W load for 3 hours. How much energy remains?',
                  'A battery initially stores 1 kWh. A 500 W load runs for 3 hours. How much energy remains?',
                  'A battery initially stores 1 kWh. A 500 W load runs for -1 hours. How much energy remains?',
                  'A battery initially stores 1 kWh. A 500 W load runs for 1 hours with 0% efficiency. How much energy remains?',
                  'A battery initially stores 1 kWh. A 500 W load runs for 1 hours and then 2 hours. How much energy remains?']:
            self.refusal(q)

    def test_storage_from_power_or_energy(self):
        self.value('A 400 W solar panel produces power for 5 hours with 80% charging efficiency. How much energy is stored?',1.6)
        self.value('A solar panel produces 2 kWh. A battery stores 80% of this energy. What is the stored energy?',1.6)
        self.value('A 400 W solar panel gets 5 peak sun hours. A battery stores 80% of this energy. What is the stored energy?',1.6)
        self.value('3 panels each produce 400 W for 5 hours. A battery stores 80% of this energy. What is the stored energy?',4.8)
        self.value('A 400 W solar panel produces power for 5 hours. Ignoring losses, how much energy is stored?',2)

    def test_storage_unbound_and_conflicting_conditions(self):
        for q in ['A 400 W solar panel runs for 5 hours. What is the stored energy?',
                  'A 400 W solar panel runs for 5 hours. A battery stores 120% of this energy. What is the stored energy?',
                  'A 400 W solar panel runs for 5 hours. A battery stores 80% of this energy with 50% depth of discharge. What is the stored energy?',
                  '3 panels produce 400 W for 5 hours. A battery stores 80% of this energy. What is the stored energy?',
                  'A 400 W solar panel runs for -5 hours. A battery stores 80% of this energy. What is the stored energy?',
                  'A 400 W solar panel runs for 5 hours. A battery stores 80% of this energy at 90% storage efficiency. What is the stored energy?']:
            self.refusal(q)

    def test_changed_numbers_check_arithmetic_independently(self):
        # Independent arithmetic, outside the shipped examples/templates.
        for cap,load,eff,depth in [(1630,270,86,70),(300,50,75,40),(4200,350,95,90)]:
            self.value(f'How long can a {cap} Wh battery run a {load} W load with {eff}% inverter efficiency and {depth}% depth of discharge?', cap*eff*depth/(10000*load))

    def test_malformed_groups_and_multiple_sources_do_not_salvage_a_number(self):
        for q in ['A battery initially stores 1,2 kWh. A 100 W load runs for 1 hour. How much energy remains?',
                  'How long can a 1,2 kWh battery run a 100 W load?',
                  'How long can a 1000 Wh battery run a 1,00 W load?',
                  'How long can a 1000 Wh battery run a 100 W load with 90,5% efficiency?',
                  'How long can two 1000 Wh batteries run a 100 W load?',
                  'How long can 2 batteries each 1000 Wh run a 100 W load?',
                  'How long can a 1000 Wh battery run two 100 W fans?']:
            self.refusal(q)
        self.value('How long can a 1,000 Wh battery run a 100 W load?',10)


if __name__ == '__main__': unittest.main()
