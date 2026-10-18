#!/usr/bin/env python3
"""UNTRUSTED original optical model challenge generator.
Exact Fraction equations are independent of the extracted implementation.
Templates were authored alongside recognition; reserved seeds check numeric
and role generalization, not blind natural-language coverage.
"""
import argparse,json,random
from fractions import Fraction as F
from pathlib import Path
C=F(299792458);H=F(662607015,10**42);QE=F(1602176634,10**28)
SOURCE='https://openstax.org/books/university-physics-volume-3/pages/1-3-refraction'
def literal(q):
 q=F(q)
 return str(q.numerator) if q.denominator==1 else str(q.numerator)+'/'+str(q.denominator)
def generate(seed,n=24):
 rng=random.Random(seed);rows=[]
 def add(q,v,kind,law):rows.append(dict(q=q,expect=float(v),kind=kind,valid=True,split='fresh',source=SOURCE,derivation=law))
 for _ in range(n):
  ns=F(rng.randint(10,28),10);nt=F(rng.randint(10,28),10)
  f=F(rng.randint(80,900),rng.choice([1,2,3,4]));l=F(rng.randint(250,1800),rng.choice([1,2,3]))
  add(f'Light of frequency {literal(f)} THz travels in a medium with refractive index {literal(nt)}. What is its wavelength?',C/(nt*f*10**12),'wavelength','n_target f lambda = c')
  add(f'Light has wavelength {literal(l)} nm in a medium with refractive index {literal(ns)}. What is its frequency?',C/(ns*l/10**9),'frequency','n_source f lambda_source = c')
  roles=f'source index {literal(ns)} and target index {literal(nt)}' if rng.randrange(2) else f'target index {literal(nt)} and source index {literal(ns)}'
  add(f'Light has wavelength {literal(l)} nm with {roles}. What is its wavelength?',ns*l/nt/10**9,'wavelength','n_source lambda_source = n_target lambda_target')
  add(f'A photon has wavelength {literal(l)} nm in a medium of index {literal(ns)}. What is its energy?',H*C/(ns*l/10**9*QE),'photon_energy','E = h f; n_source f lambda_source = c; reported eV')
 return rows
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--seed',type=int,required=True);ap.add_argument('--out',type=Path,required=True);args=ap.parse_args()
 rows=generate(args.seed);args.out.write_text(json.dumps(rows,indent=2)+'\n');print(len(rows),'original questions')
