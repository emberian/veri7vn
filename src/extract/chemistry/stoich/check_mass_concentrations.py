#!/usr/bin/env python3
"""UNTRUSTED authored mass-to-concentration probes using independent Fraction arithmetic.
This imports only the common probe transport/scoring, not kernel calculations.
"""
from fractions import Fraction
import check_solutions as runner

def cases():
    for sid in ('labsolutions','labsolutions-r2'):
        for formula,mass in [('H2O',Fraction('18.015')),('NaCl',Fraction('58.44'))]:
            for mass_unit,scale in [('grams',1),('milligrams',Fraction(1,1000)),('kg',1000),('micrograms',Fraction(1,1000000))]:
                for q in ['0','.05844','1e3']:
                    for output,out_scale in [('M',1),('mM',Fraction(1,1000)),('micromolar',Fraction(1,1000000))]:
                        query=f'What is the molarity in {output} of {q} {mass_unit} of {formula} in 500 mL of solution?'
                        expected=Fraction(q)*scale/mass/Fraction(1,2)/out_scale
                        yield sid,query,float(expected),'answer',output
        for unit,label in [('liters','L'),('mL','mL'),('microliters','microlitres')]:
            yield sid,f'How many {unit} of 0 M stock are needed to make 0 mL of 0 M solution?',0,'answer',label
        for q in [
            'What is the molarity in mM of -1 gram of NaCl in 500 mL of solution?',
            'What is the molarity in mM of 0 grams of NaCl in 0 mL of solution?',
            'What is the molarity in micromolar of 1 gram of H0 in 500 mL of solution?',
            'What is the molarity in mM of 1 gram of Xx in 500 mL of solution?',
            'What is the molarity in mM of 1 gram per second of NaCl in 500 mL of solution?',
            'What is the molarity in mM per second of 1 gram of NaCl in 500 mL of solution?',
            'What is the molarity in mM of 1 gram of NaCl in 500 mL per second of solution?',
            'What is the molarity in mM of 1e+ gram of NaCl in 500 mL of solution?',
            'What is the molarity in mM of QNUM0Q grams of NaCl in 500 mL of solution?',
            'How much 0 M stock is needed to make -1 mL of 0 M solution?',
        ]:yield sid,q,None,'invalid',None
        yield sid,'How much 0 M stock is needed to make 100 mL of 0 M solution?',None,'withheld-valid',None
        yield sid,'What is the molarity in nanomolar of 1 gram of NaCl in 500 mL of solution?',None,'withheld-valid',None

if __name__=='__main__':
    runner.cases=cases
    raise SystemExit(runner.run())
