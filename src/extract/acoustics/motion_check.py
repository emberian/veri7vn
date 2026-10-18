#!/usr/bin/env python3
"""UNTRUSTED joint-Doppler challenge with independent exact Fraction formulas.
Counts authored decline checks separately from valid computable withheld forms.
No wind/frame conversion or physical experiment is claimed by these tests.
"""
import argparse,json,random,subprocess,hashlib,math
from fractions import Fraction as F
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);ap.add_argument('--seed',type=int,default=2026102501);ap.add_argument('--binary',default='var/acoustics/bin/acoustics');a=ap.parse_args();rng=random.Random(a.seed);cases=[]
def add(q,x=None,kind=None,valid=True):cases.append(dict(q=q,expected=None if x is None else str(x),kind=kind,valid=valid))
def question(f,us,ds,ul,dl,c,swap=False):
 src=f'A source emitting {f} Hz moves {"toward" if ds==1 else "away from"} the listener at {us} m/s'
 obs=f'a listener moves {"toward" if dl==1 else "away from"} the source at {ul} m/s'
 return (obs.capitalize()+' and '+src.lower() if swap else src+' and '+obs)+f'. What frequency is heard if the sound speed is {c} m/s?'
for ds in (-1,1):
 for dl in (-1,1):
  for i in range(20):
   c=rng.randint(300,370);us=F(rng.randint(0,250),10);ul=F(rng.randint(0,250),10);f=rng.randint(100,3000)
   add(question(f,us,ds,ul,dl,c,i%2==1),F(f)*(c+dl*ul)/(c-ds*us),'doppler')
for ds in (-1,1):
 for dl in (-1,1):
  for us,ul in [(0,17),(23,0),(0,0)]:
   add(question(643,us,ds,ul,dl,337),F(643)*(337+dl*ul)/(337-ds*us),'doppler')
add(question(500,0,1,330,-1,330),0,'doppler')
add(question(500,10,-1,330,-1,330),0,'doppler')
for q,x in [
 ('A source emitting 500 Hz is stationary and a listener moves toward the source at 10 m/s. What frequency is heard with sound speed 330 m/s?',F(17000,33)),
 ('A source emitting 500 Hz moves toward the listener at 30 m/s and a listener is stationary. What frequency is heard with sound speed 330 m/s?',550),
 ('A source emitting .5e3 Hz moves toward the listener at 3e1 m/s and a listener moves away from the source at 1/ 2 m/s. What frequency is heard with sound speed 330 m/s?',F(3295,6)),
]:add(q,x,'doppler')
for f,us,ul,c in [(0,10,10,330),(500,-1,10,330),(500,10,-1,330),(500,10,10,0)]:add(question(f,us,1,ul,1,c),kind='impossible',valid=False)
for us,ul,dl in [(330,0,1),(400,10,-1),(10,331,-1)]:add(question(500,us,1,ul,dl,330),kind='unsupported_model',valid=True)
for tail in ['with a 5 m/s tailwind','with wind 5 m/s toward the listener','with moving air at 5 m/s']:
 add(question(500,30,1,10,1,330)+' '+tail+'.',kind='unsupported_model')
for q in [
 question(500,30,1,10,1,330).replace('30 m/s','30 ft/s',1),
 question(500,30,1,10,1,330).replace('30 m/s','30 m/s2',1),
 question(500,30,1,10,1,330).replace('30 m/s','30 m/s × min',1),
 question(500,30,1,10,1,330).replace('30 m/s','30 m/s.min',1),
 question(500,30,1,10,1,330)+' Another speed is 7 m/s.',
 question(500,30,1,10,1,330).replace('emitting 500 Hz','emitting 500 kHz'),
 question(500,30,1,10,1,330).replace('What frequency','What frequency in kHz'),
]:add(q,kind='unsupported_model',valid=not any(x in q for x in ['m/s2','m/s ×','m/s.min']))
for q in [
 'A 500 Hz source and listener approach each other at 10 m/s and 20 m/s. What frequency is heard with sound speed 330 m/s?',
 'A 500 Hz siren moves toward a listener at 10 m/s and another speed is 20 m/s. What frequency is heard with sound speed 330 m/s?',
 'A 500 Hz and 600 Hz siren moves toward a listener at 10 m/s. What frequency is heard with sound speed 330 m/s?',
]:add(q,kind='unsupported_model',valid=True)
# Explicit temperature changes the common propagation speed once.
for t in (-10,0,30):
 c=331.3*math.sqrt(1+t/273.15)
 q=f'A source emitting 500 Hz moves toward the listener at 20 m/s and a listener moves away from the source at 10 m/s. What frequency is heard in air at {t} degrees C?'
 add(q,500*(c-10)/(c-20),'doppler')
add('A source emitting 500 Hz is stationary and a listener moves away from the source at 331.3 m/s. What frequency is heard in air at 0 degrees C?',0,'doppler')
add('A source emitting 500 Hz moves toward the listener at 331.3 m/s and a listener is stationary. What frequency is heard in air at 0 degrees C?',kind='unsupported_model',valid=True)
add('A source emitting 500 Hz moves toward the listener at 20 m/s and a listener moves away from the source at 10 m/s. What frequency is heard in air at -300 degrees C?',kind='impossible',valid=False)
report={'seed':a.seed,'binary_sha256':hashlib.sha256((ROOT/a.binary).read_bytes()).hexdigest(),'checks_passed':0,'right':0,'wrong':0,'false_yes':0,'withheld_valid':0,'cases':[]}
p=subprocess.Popen([str(ROOT/a.binary)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
for i,x in enumerate(cases):
 p.stdin.write(json.dumps({'id':str(i),'q':x['q']})+'\n');p.stdin.flush();r=json.loads(p.stdout.readline());ans=r.get('status')=='answered'
 if x['expected'] is None:good=not ans and (not x['kind'] or r.get('kind')==x['kind'])
 else:
  expected=F(x['expected']);v=r.get('value');good=ans and r.get('kind')==x['kind'] and v is not None and abs(F(str(v))-expected)<=max(abs(expected)*F(1,1000),F(1,10**9))
 report['checks_passed']+=bool(good);report['right']+=bool((not x['valid'] and not ans) or (good and x['expected'] is not None));report['wrong']+=bool(x['valid'] and ans and not good);report['false_yes']+=bool(not x['valid'] and ans);report['withheld_valid']+=bool(x['valid'] and not ans);report['cases'].append(dict(**x,reply=r,check_passed=good))
p.stdin.close();assert p.wait()==0;report['n']=len(cases);(ROOT/a.out).write_text(json.dumps(report,indent=2)+'\n');print({k:v for k,v in report.items() if k!='cases'})
