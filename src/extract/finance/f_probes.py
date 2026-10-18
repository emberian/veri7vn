"""UNTRUSTED inventory-period probes, exact independent physical rates."""
from fractions import Fraction as Q
from pathlib import Path
import json,subprocess,argparse
CASES=[]
def add(q,expected,kind,valid=True):CASES.append(dict(q=q,expected=None if expected is None else str(Q(expected)),kind=kind,valid=valid))
for units,days in [('hour',Q(1,24)),('day',Q(1)),('week',Q(7)),('year',Q(365))]:
 for n in ['1','2','.5']:
  add(f'COGS is $700 over {n} {units}s and average inventory is $100. What are the days of inventory?',Q(n)*days/7,'days_inventory')
for rateunit,rate_days in [('hour',Q(1,24)),('day',Q(1)),('week',Q(7)),('year',Q(365))]:
 for leadunit,lead_days in [('hours',Q(1,24)),('days',Q(1)),('weeks',Q(7))]:
  add(f'Demand is 70 units per {rateunit}, lead time is 2 {leadunit}, safety stock is 20. What is the reorder point?',Q(70)*2*lead_days/rate_days+20,'rop')
for q,e,k in [
('COGS is $700 per week and average inventory is $100. What are the days of inventory?',1,'days_inventory'),
('COGS is $3000 over 30 days and average inventory is $1000. What are the days of inventory?',10,'days_inventory'),
('Weekly COGS is $700 and average inventory is $100. What are the days of inventory?',1,'days_inventory'),
('Annual COGS is $36500 and average inventory is $100. What are the days of inventory?',1,'days_inventory'),
('COGS is $36500 and average inventory is $100. What are the days of inventory?',1,'days_inventory'),
('Average inventory is $100. COGS is $700 over 1 week. What are the days of inventory?',1,'days_inventory'),
('COGS is $7k over 1 week and average inventory is $1k. What are the days of inventory?',1,'days_inventory'),
('Demand is 70 units per week, lead time is 5 days, safety stock is 20. What is the reorder point?',70,'rop'),
('Demand is 10 units per day, lead time is 2 weeks, safety stock is 20. What is the reorder point?',160,'rop'),
('Demand is 140 units per 2 weeks, lead time is 5 days, safety stock is 20. What is the reorder point?',70,'rop'),
('Daily demand is 10, lead time is 5 days and safety stock is 20. What is the reorder point?',70,'rop'),
('Daily demand is 10 units a day with a 14 day lead time and 50 units of safety stock. What is the reorder point?',190,'rop'),
('Find the reorder point: daily sales of 40 units per day, lead time of 14 days, safety stock of 20.',580,'rop'),
('Lead time is 5 days, with demand of 10 units per day and 20 units of safety stock. What is the reorder point?',70,'rop'),
('Demand is 10 units per day with a 5-day lead time and safety stock is 20. What is the reorder point?',70,'rop'),
('Demand is .5 units per hour, lead time is 2 days, safety stock is 0. What is the reorder point?',24,'rop'),
('Demand is 1/2 units per hour, lead time is 2 days. What is the reorder point?',24,'rop'),
('Demand is 10 units per day, lead time is 5 days with no safety stock. What is the reorder point?',50,'rop'),
('Demand is 0 units per day, lead time is 2 weeks, safety stock is 0. What is the reorder point?',0,'rop'),
('COGS is $700 per week and average inventory is $0. What are the days of inventory?',0,'days_inventory'),
]: add(q,e,k)
for q in [
'COGS is $-700 over 1 week and average inventory is $100. What are the days of inventory?',
'COGS is $0 over 1 week and average inventory is $100. What are the days of inventory?',
'COGS is $700 over 0 weeks and average inventory is $100. What are the days of inventory?',
'COGS is $700 over -1 weeks and average inventory is $100. What are the days of inventory?',
'COGS is $700 over 1 week and average inventory is $-100. What are the days of inventory?',
'Demand is -70 units per week, lead time is 5 days, safety stock is 20. What is the reorder point?',
'Demand is 70 units per 0 weeks, lead time is 5 days, safety stock is 20. What is the reorder point?',
'Demand is 70 units per week, lead time is -5 days, safety stock is 20. What is the reorder point?',
'Demand is 70 units per week, lead time is 5 days, safety stock is -20. What is the reorder point?',
]:add(q,None,'impossible',False)
for q in [
'Demand is 10 cases per day, lead time is 5 days, safety stock is 20 units. What is the reorder point?',
'Demand is 10 units per day, lead time is 5 days, safety stock is 20 cases. What is the reorder point?',
'Demand is 10 units per day/person, lead time is 5 days. What is the reorder point?',
'COGS is $700 per month and average inventory is $100. What are the days of inventory?',
'COGS is $700 over 5 business days and average inventory is $100. What are the days of inventory?',
'COGS is $700 over 7 days and $600 over 6 days; average inventory is $100. What are the days of inventory?',
'Demand is 70 units per week, lead time is 1 month and safety stock is 20. What is the reorder point?',
'Demand is 70 units per week, then 140 units per week, lead time is 5 days and safety stock is 20. What is the reorder point?',
'Demand is 70 units per week, lead time is 5 days or 7 days, safety stock is 20. What is the reorder point?',
'COGS is $700 over 1 week and average inventory is $100. Use a 360-day year. What are the days of inventory?',
'Demand is 10 units per day, lead time is 5 days and safety stock is 20. What is the reorder point breakdown?',
'Demand is 10 units per day and lead time is 5 days. Safety stock is unknown. What is the reorder point?',
]:add(q,None,'unsupported_model')

for q,e in [
('COGS is $700 per week and average inventory is $100. What is the annual inventory turnover?',365),
('COGS is $3000 over 30 days and average inventory is $1000. What is the inventory turnover for that 30-day period?',3),
('COGS is $700 per week and average inventory is $100. What is the inventory turnover?',7),
('COGS is $700 weekly and average inventory is $100. What is the annual inventory turnover?',365),
('Weekly COGS is $700 and average inventory is $100. What is the annual inventory turnover?',365),
('COGS is $36500 per year and average inventory is $100. What is the weekly inventory turnover?',7),
('COGS is $700 per day and average inventory is $100. What is the weekly inventory turnover?',49),
('COGS is $100 per hour and average inventory is $700. What is the weekly inventory turnover?',24),
('COGS is $36500 and average inventory is $100. What is the inventory turnover?',365),
('COGS is $36500 and average inventory is $100. What is the inventory turnover for 7 days?',7),
('COGS is $700 per week and average inventory is $100. What is the inventory turnover for 14 days?',14),
('COGS is $0 per week and average inventory is $100. What is the annual inventory turnover?',0),
('COGS is $700 per week and average inventory is $100. What is the daily inventory turnover?',1),
('COGS is $700 per week and average inventory is $100. What is the hourly inventory turnover?',Q(1,24)),
]:add(q,e,'turnover')
for q in [
'COGS is $-700 per week and average inventory is $100. What is the annual inventory turnover?',
'COGS is $700 per week and average inventory is $0. What is the annual inventory turnover?',
'COGS is $700 per week and average inventory is $100. What is the inventory turnover for 0 days?',
]:add(q,None,'impossible',False)
for q in [
'COGS is $700 per week and average inventory is $100. What is the monthly inventory turnover?',
'COGS is $700 per week and average inventory is $100. What is the annual inventory turnover and weekly inventory turnover?',
'COGS is $700 over several weeks and average inventory is $100. What is the annual inventory turnover?',
'COGS is $700 per week and average inventory is $100. What is the inventory turnover and days of inventory?',
'Demand is 70 units per week, lead time is 5 days. What is the reorder point and inventory turnover?',
'Demand is 70 units per week, lead time is 5 days. What is the reorder point and days of inventory?',
]:add(q,None,'unsupported_model')

def run(binary):
 rows=[]
 for x in CASES:
  for mode in ['retail','family']:
   r=json.loads(subprocess.check_output([binary]+([] if mode=='family' else ['--specialist',mode]),input=json.dumps({'q':x['q']})+'\n',text=True)); ans=r.get('status')=='answered'; e=x['expected']
   # Existing g4 display, half a unit in the fourth significant figure.
   tolerance=Q(1,2000)*max(Q(1),abs(Q(e))) if e is not None else Q(0)
   ok=(not ans and r.get('kind')==x['kind']) if e is None else ans and r.get('value') is not None and abs(Q(str(r['value']))-Q(e))<=tolerance and r.get('kind')==x['kind']
   verdict=('unassessed_answered' if ans else 'withheld_valid') if e is None and x['valid'] else ('false_yes' if ans else 'right') if e is None else ('right' if ok else 'wrong' if ans else 'withheld_valid')
   rows.append(dict(**x,mode=mode,policy_pass=ok,verdict=verdict,reply=r))
 return dict(n=len(rows),policy_passed=sum(x['policy_pass'] for x in rows),counts={k:sum(x['verdict']==k for x in rows) for k in ['right','wrong','false_yes','withheld_valid','unassessed_answered']},rows=rows)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--binary',required=True);p.add_argument('--out',required=True);a=p.parse_args();r=run(a.binary);Path(a.out).write_text(json.dumps(r,indent=2)+'\n');print({k:v for k,v in r.items() if k!='rows'})
 for x in r['rows']:
  if not x['policy_pass']:print(x['q'],x['mode'],x['reply'])
