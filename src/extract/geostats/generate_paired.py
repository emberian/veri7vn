"""Untrusted seeded rational paired-data probes, independent Python Fraction oracle."""
import json,random,sys
from fractions import Fraction as F
from pathlib import Path
seed=int(sys.argv[1]);r=random.Random(seed);rows=[]
for i in range(10):
 n=r.randint(3,9);xs=[F(r.randint(-30,30),r.choice([1,2,4,5])) for _ in range(n)]
 if len(set(xs))==1:xs[-1]+=1
 a=F(r.randint(-15,15),r.choice([1,2,3]));b=F(r.randint(-10,10),r.choice([1,2,5]))
 ys=[a+b*x+(F(r.randint(-5,5),2) if i%2 else 0) for x in xs]
 mx=sum(xs)/n;my=sum(ys)/n;cross=sum((x-mx)*(y-my) for x,y in zip(xs,ys));spread=sum((x-mx)**2 for x in xs)
 slope=cross/spread;intercept=my-slope*mx;t=F(r.randint(-20,20),r.choice([1,2,3]))
 lists='x values ['+', '.join(map(str,xs))+'] and y values ['+', '.join(map(str,ys))+']'
 for op,expected,kind in [('population covariance',cross/n,'covariance'),('sample covariance',cross/(n-1),'covariance'),('regression slope',slope,'regression_slope'),('regression intercept',intercept,'regression_intercept'),('least-squares line',[str(intercept),str(slope)],'regression_line'),('regression prediction at x = '+str(t),intercept+slope*t,'regression_prediction')]:
  rows.append(dict(q='What is the '+op+' for '+lists+'?',valid=True,expected=expected if isinstance(expected,list) else str(expected),expect_kind=kind,seed=seed,source='https://www.itl.nist.gov/div898/handbook/pmd/section4/pmd431.htm'))
Path(sys.argv[2]).write_text(json.dumps(rows,indent=2)+'\n')
