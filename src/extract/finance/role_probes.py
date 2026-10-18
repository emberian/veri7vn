"""UNTRUSTED retail percentage-role checks; exact independent rational arithmetic.
Refusal policy and unsupported valid capability are reported separately.
"""
import argparse,json,subprocess
from fractions import Fraction as Q
from pathlib import Path
CASES=[
('An $80 item is discounted 25%, then 8% sales tax is added. What is the final price?',Q('64.8')),
('An $80 item is reduced by 25%, then taxed at 8%. What is the final price?',Q('64.8')),
('An $80 item is 25% off. Sales tax is 8%. What is the final price?',Q('64.8')),
('An $80 item has a 25% discount and an 8% sales tax. What is the final price?',Q('64.8')),
('An $80 item has a discount of 25% and sales tax of 8%. What is the final price?',Q('64.8')),
('After a 25% discount, apply 8% sales tax to an $80 item. What is the final price?',Q('64.8')),
('Sales tax is 8%. An $80 item is discounted 25%. What is the final price?',Q('64.8')),
('An $80 item is 25% off, and 8% tax is calculated on the original price. What is the final price?',Q('66.4')),
('An $80 item is discounted 25 percent, then taxed at 8 percent. What is the final price?',Q('64.8')),
('An $100 item is discounted 20%, then reduced by 10%, with 5% sales tax. What is the final price?',Q('75.6')),
('An $80 item has a discount of 25% off, and tax is 8%. What is the final price?',Q('64.8')),
('An $80 item is discounted 25%. What is the final price?',Q(60)),
('An $80 item is taxed at 8%. What is the final price?',Q('86.4')),
('An $80 item has 25% and 8% sales tax. What is the final price?',None),
('An $80 item is discounted 25% and has an additional 8%. What is the final price?',None),
('An $80 item is discounted 25%, with sales tax of 8% and local tax of 2%. What is the final price?',None),
('An $80 item has a discount of 25% tax. What is the final price?',None),
('An $80 item is discounted 25% and sales tax applies. What is the final price?',None),
('An $80 item is discounted 25%, taxed at 8%, and an additional 2% applies. What is the final price?',None),
('An $80 item is discounted 25%, and sales tax is 8% of the shipping cost. What is the final price?',None),
('An $80 item is discounted 25%, and 8% tax applies to the shipping cost. What is the final price?',None),
('An $80 item is discounted 25%, and sales tax is 8% of the discounted price. What is the final price?',Q('64.8')),
('An $80 item is discounted 25%, and sales tax is 8% of the original price. What is the final price?',Q('66.4')),
('An $80 item has sales tax of 8%. What is the final price?',Q('86.4')),
('An $80 item has sales tax of 8% of the shipping cost. What is the final price?',None),
('An $80 item has a 25% discount, meaning it is 25% off, and sales tax is 8%. What is the final price?',None),
('An $80 item has a 25% discount, that is 25% off, and then sales tax is 8%. What is the final price?',None),
('An $80 item has successive discounts of 25% off then 25% off, and sales tax is 8%. What is the final price?',Q('48.6')),
('An $80 item is 25% off and 25% off, and sales tax is 8%. What is the final price?',None),
('An $80 item has stacked discounts: 25% off and 10% off, plus 8% tax. What is the final price?',Q('58.32')),

]
def run(binary):
 rows=[]
 for q,expect in CASES:
  for mode in ['retail','family']:
   command=[binary]+([] if mode=='family' else ['--specialist',mode])
   r=json.loads(subprocess.check_output(command,input=json.dumps({'q':q})+'\n',text=True))
   answered=r.get('status')=='answered'
   ok=(not answered and r.get('kind')=='unsupported_model') if expect is None else answered and r.get('value') is not None and abs(Q(str(r['value']))-expect)<=Q('.005')
   verdict=('unassessed_answered' if answered else 'withheld_valid') if expect is None else ('withheld_valid' if not answered else 'right' if ok else 'wrong')
   rows.append(dict(q=q,mode=mode,expected=None if expect is None else str(expect),policy_pass=ok,verdict=verdict,reply=r))
 return dict(policy_passed=sum(x['policy_pass'] for x in rows),total=len(rows),counts={k:sum(x['verdict']==k for x in rows) for k in ['right','wrong','withheld_valid','unassessed_answered']},rows=rows)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--binary',default='var/finance/bin/finance');p.add_argument('--out',required=True);a=p.parse_args();r=run(a.binary);Path(a.out).write_text(json.dumps(r,indent=2)+'\n');print({k:v for k,v in r.items() if k!='rows'});
 for x in r['rows']:
  if not x['policy_pass']:print(x['mode'],x['q'],x['reply'])
