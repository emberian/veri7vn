#!/usr/bin/env python3
"""UNTRUSTED authored physical-reaction probes with independent Fraction oracles.
Transport/scoring reuse does not import any kernel arithmetic.
"""
from fractions import Fraction as F
import check_solutions as runner

UNITS=[('mol',None,1),('mmol',None,F(1,1000)),('micromoles',None,F(1,1000000)),
       ('g','mass',1),('mg','mass',F(1,1000)),('kg','mass',1000),('micrograms','mass',F(1,1000000))]
runner.ALIASES.update({u:(u,) for u,_,_ in UNITS})

def cases():
    for sid in ('chemistry','chemistry-v3'):
        for input_unit,mass_unit,input_scale in UNITS:
            for h in [F(0),F(1,2),F(4)]:
                source=h*(F('2.016') if mass_unit else 1)/input_scale
                formed=min(h,2)
                for output_unit,out_mass,out_scale in UNITS:
                    expected=formed*(F('18.015') if out_mass else 1)/out_scale
                    q=f'2 H2 + O2 -> 2 H2O; {source} {input_unit} H2, 31.998 g O2; yield H2O in {output_unit}'
                    yield sid,q,float(expected),'answer',output_unit
        for q,expected,label in [
          ('2 H2 + O2 -> 2 H2O; 4.032 g H2, 1 mol O2, 18.015 g H2O; remaining H2O in g',F('54.045'),'g'),
          ('2 H2 + O2 -> 2 H2O; 4.032 g H2, 1 mol O2, 18.015 g H2O; yield H2O in g',F('36.03'),'g'),
          ('H2 + H2 + O2 + Pt -> 2 H2O + Pt; .004032 kg H2, 31998 mg O2, 0 g Pt; yield H2O in kg',F('.03603'),'kg'),
          ('2 H2 + O2 + Pt -> 2 H2O + Pt; 4.032 g H2, 1 mol O2, .001 g Pt; remaining Pt in mg',1,'mg'),
          ('N2 + 3 H2 -> 2 NH3; 28.014 g N2, 3.024 g H2; yield NH3 in g',F('17.031'),'g'),
          ('2 H2 + O2 -> 2 H2O; 6.048 g H2, 1 mol O2; remaining H2 in g',F('2.016'),'g'),
          ('2 H2 + O2 -> 2 H2O; 0 g H2, 1 mol O2; remaining O2 in g',F('31.998'),'g'),
          ('2 H2 + O2 -> 2 H2O; 4.032 g H2, 1 mol O2; how many mg of H2O form',36030,'mg'),
          ('2 H2 + O2 -> 2 H2O; 4.032 g H2, 1 mol O2; how many micrograms of H2 remain',0,'micrograms'),
        ]:yield sid,q,float(expected),'answer',label
        for q in [
          '2 H2 + O2 -> 2 H2O; -4.032 g H2, 1 mol O2; yield H2O in g',
          '2 H2 + O2 -> 2 H2O; −4.032 g H2, 1 mol O2; yield H2O in g',
          '2 H2 + O2 -> 2 H2O; 4.032 g/s H2, 1 mol O2; yield H2O in g',
          '2 H2 + O2 -> 2 H2O; 4.032 grams per second H2, 1 mol O2; yield H2O in g',
          '2 H2 + O2 -> 2 H2O; 4.032 g H2, 1 mol O2; yield H2O in g/s',
          '2 H2 + O2 -> 2 H2O; 4.032 g H2, 1 mol O2; yield H2O in grams per second',
          '2 H2 + O2 -> 2 H2O; 4.032e+ g H2, 1 mol O2; yield H2O in g',
          '2 H2 + O2 -> 2 H2O; 1/0 g H2, 1 mol O2; yield H2O in g',
          '2 H2 + O2 -> 2 H2O; QNUM0Q g H2, 1 mol O2; yield H2O in g',
          '2 H2 + O2 -> H2O; 4.032 g H2, 1 mol O2; yield H2O in g',
          'H0 -> H0; 1 g H0; remaining H0 in g',
        ]:yield sid,q,None,'invalid',None
        for q in [
          '2 H2 + O2 -> 2 H2O; 4.032 g H2, 1 mol O2; yield NaCl in g',
          '2 H2 + O2 -> 2 H2O; 1 pound H2, 1 mol O2; yield H2O in g',
          '2 H2 + O2 -> 2 H2O; 4.032 g H2, 1 mol O2; yield H2O in ounces',
          '2 H2 + O2 -> 2 H2O; 2.016 g H2, 2.016 g H2, 1 mol O2; yield H2O in g',
        ]:yield sid,q,None,'withheld-valid',None

if __name__=='__main__':
    runner.cases=cases
    raise SystemExit(runner.run())
