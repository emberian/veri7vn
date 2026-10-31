#!/usr/bin/env python3
"""Untrusted independent analytic scorer. Does not import native solver code.

Only explicit structured refusal counts; transport/contract errors remain errors.
Numerical thresholds test these analytic cases, not rigorous global guarantees.
"""
import argparse
import json
import math
from pathlib import Path
import sys
import urllib.error
sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
from thermal_transient import Client
ROOT=Path(__file__).resolve().parents[4]


def cases():
    folder=Path(__file__).resolve().parent
    panel=json.loads((folder/'panel.json').read_text())
    base=json.loads((ROOT/'native/oracle-science/examples/thermal-transient-heater.json').read_text())['arguments']
    for case in panel['cases']:
        arguments=json.loads(json.dumps(base));kind=case['kind']
        if kind=='cooling':
            arguments.update(initial_temperature_k=[310,300],duration_s=10,sample_times_s=[5],events=[],loads=[{'start_time_s':0,'applied_heat_w':[0,0]}])
        elif kind=='disconnected':
            arguments['network']['links']=[]
            arguments.update(events=[],loads=[{'start_time_s':0,'applied_heat_w':[2,0]}])
        elif kind=='closed':
            arguments['network']['nodes'][1].pop('fixed_temperature_k')
            arguments.update(capacities_j_per_k=[10,10],initial_temperature_k=[310,290],events=[],loads=[{'start_time_s':0,'applied_heat_w':[0,0]}])
        elif kind=='all_fixed':
            arguments['network']['nodes'][0]['fixed_temperature_k']=300
            arguments['events']=[]
        elif kind=='no_crossing':arguments['events'][0]['temperature_k']=320
        elif kind=='zero_capacity':arguments['capacities_j_per_k'][0]=0
        elif kind=='negative_capacity':arguments['capacities_j_per_k'][1]=-1
        elif kind=='boundary_mismatch':arguments['initial_temperature_k'][1]=301
        elif kind=='unsorted':arguments['loads'][1]['start_time_s']=0
        elif kind=='exhausted':arguments['integration']['max_steps']=1
        elif kind=='below_zero':
            arguments['network']['links']=[];arguments.update(duration_s=1,sample_times_s=[],events=[],loads=[{'start_time_s':0,'applied_heat_w':[-1e6,0]}])
        yield case,arguments


def truth(model,t):
    if model=='heater_switch':return [300+10*(1-math.exp(-t/5)) if t<=10 else 300+10*(1-math.exp(-2))*math.exp(-(t-10)/5),300]
    if model=='cooling':return [300+10*math.exp(-t/5),300]
    if model=='isolated_linear':return [300+0.2*t,300]
    if model=='closed_pair':return [300+10*math.exp(-0.4*t),300-10*math.exp(-0.4*t)]
    if model=='fixed':return [300,300]
    raise ValueError('unknown independent truth model')


def score(case,reply):
    expected=case['expect'];asserted=reply.get('status')=='answered'
    if expected.get('refused'):return {'right':reply.get('status')=='withheld','wrong':asserted,'false_yes':asserted}
    if not asserted:return {'right':False,'wrong':False,'false_yes':False}
    right=bool(reply.get('samples'))
    for sample in reply.get('samples',[]):
        want=truth(expected['model'],sample['time_s']);got=sample.get('temperature_k',[])
        right=right and len(got)==len(want) and all(type(x) in (int,float) and math.isfinite(x) and abs(x-y)<=expected['temperature_tolerance_k'] for x,y in zip(got,want))
    events=reply.get('events',[]);right=right and len(events)==expected['event_count']
    if expected['event_count']==2 and len(events)==2:
        times=[5*math.log(2),10+5*math.log(2*(1-math.exp(-2)))]
        right=right and [e['direction'] for e in events]==['rising','falling'] and all(abs(e['linear_estimate_s']-t)<=expected['event_time_tolerance_s'] for e,t in zip(events,times))
    energy=reply.get('energy',{})
    if expected['model']=='closed_pair':right=right and abs(energy.get('storage_change_j',float('inf')))<=1e-6
    if expected['model']=='fixed':right=right and abs(energy.get('reservoir_heat_j',float('inf'))+200)<=1e-6
    return {'right':bool(right),'wrong':not right,'false_yes':False}


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--url',required=True);parser.add_argument('--tenant',default='transient-panel')
    args=parser.parse_args();client=Client(args.url,args.tenant);client.discover()
    totals={'right':0,'wrong':0,'false_yes':0,'execution_errors':0};records=[]
    for case,arguments in cases():
        try:result=score(case,client.invoke(arguments))
        except urllib.error.HTTPError as error:
            body=json.loads(error.read())
            if error.code==400 and body.get('outcome')=='error' and body.get('error')=='invalid_arguments':result=score(case,{'status':'withheld'})
            else:result={'execution_errors':1,'detail':str(error)}
        except Exception as error:result={'execution_errors':1,'detail':str(error)}
        for key in totals:totals[key]+=int(result.get(key,0))
        records.append({'id':case['id'],**result})
    print(json.dumps({'scope':'new supplied transient workflow panel; no upstream panel score','totals':totals,'cases':records},indent=2))
    return int(totals['wrong'] or totals['false_yes'] or totals['execution_errors'] or totals['right']!=len(records))
if __name__=='__main__':raise SystemExit(main())
