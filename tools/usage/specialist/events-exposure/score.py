#!/usr/bin/env python3
"""Independent analytic supplied-GLM gold scorer; not Oracle7's six criteria."""
import copy
import json
import math
from pathlib import Path
import subprocess
import sys
import urllib.error
import argparse

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from events_exposure import native, hosted, strict_json, NativeRefusal, SUCCESS, OPERATION

ROOT=Path(__file__).resolve().parents[4]
Z95=1.959963984540054


def merge(base, changes):
    result=copy.deepcopy(base)
    for k,v in changes.items():
        result[k]=merge(result[k],v) if isinstance(v,dict) and isinstance(result.get(k),dict) else copy.deepcopy(v)
    return result


def close(a,b):
    return type(a) in (int,float) and math.isfinite(a) and abs(a-b)<=2e-7*max(abs(b),1e-8)


def gold(name):
    if name=='binomial_saturated':
        return [0,math.log(4)],[[.3125,0],[0,.3125]],.5,10,None
    if name=='binomial_half':
        return [0],[[.2]],.5,10,None
    if name=='binomial_two_fifths':
        return [math.log(2/3)],[[5/12]],.4,8,None
    if name=='binomial_cubic':
        # Symmetric score reduces to t^3-t-2=0, t=exp(slope).
        t=(1+math.sqrt(26/27))**(1/3)+(1-math.sqrt(26/27))**(1/3)
        p1=t/(1+t);p2=t*t/(1+t*t)
        return [0,math.log(t)],[[1/(2*p1*(1-p1)+2*p2*(1-p2)),0],
                               [0,1/(2*p1*(1-p1)+8*p2*(1-p2))]],.5,10,None
    if name=='poisson_rate_one':
        return [0],[[.25]],None,2,1
    if name=='poisson_rescaled':
        return [-math.log(1000)],[[.25]],None,2,.001
    if name=='poisson_saturated':
        return [math.log(3),math.log(3)],[[5/18,-2/9],[-2/9,5/18]],None,6,3
    if name=='poisson_rate_two':
        return [math.log(2)],[[.25]],None,4,2
    if name=='poisson_overlap':
        return [-math.log(3),0],[[1,0],[0,1.5]],None,2/3,1/3
    if name=='poisson_zero_no_intercept':
        return [0],[[.5]],None,2,1
    if name=='poisson_extreme':
        return [math.log(2)-200*math.log(10)],[[.5]],None,None,2e-200
    raise ValueError('unknown gold identity: '+name)


def check(result,name):
    beta,covariance,probability,expected_count,rate=gold(name)
    if result['status']!=SUCCESS or len(result['coefficient_candidate'])!=len(beta):
        return False
    if not all(close(a,b) for a,b in zip(result['coefficient_candidate'],beta)):
        return False
    inference=result.get('inference')
    if not isinstance(inference,dict):
        return False
    actual_cov=inference.get('coefficient_covariance')
    if not isinstance(actual_cov,list) or len(actual_cov)!=len(covariance):
        return False
    for actual,wanted in zip(actual_cov,covariance):
        if len(actual)!=len(wanted) or not all(close(a,b) for a,b in zip(actual,wanted)):
            return False
    prediction=result['predictions'][0]
    for key,wanted in [('probability',probability),('expected_count',expected_count),('rate_per_exposure_unit',rate)]:
        if wanted is None:
            if prediction.get(key) is not None:
                return False
        elif not close(prediction.get(key),wanted):
            return False
    # Independently propagate the known information covariance on the link,
    # then transform endpoints; no statrs/native quantile is reused.
    request=result['supplied']['predictions'][0]
    row=([1] if result['supplied']['intercept'] else [])+request['features']
    link=sum(x*b for x,b in zip(row,beta))
    variance=sum(row[i]*covariance[i][j]*row[j] for i in range(len(beta)) for j in range(len(beta)))
    interval=[link-Z95*math.sqrt(max(0,variance)),link+Z95*math.sqrt(max(0,variance))]
    if probability is not None:
        wanted=[1/(1+math.exp(-v)) for v in interval]
        actual=prediction.get('pointwise_probability_interval')
    else:
        wanted=[math.exp(v) for v in interval]
        actual=prediction.get('pointwise_rate_interval')
    if not isinstance(actual,list) or len(actual)!=2 or not all(close(a,b) for a,b in zip(actual,wanted)):
        return False
    if name=='poisson_extreme':
        if not prediction['unavailable_reasons'] or not any('floating-point boundary' in w for w in result['warnings']):
            return False
    return True


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    group=parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--native',type=Path)
    group.add_argument('--base')
    parser.add_argument('--tenant',default='events-exposure-panel')
    parser.add_argument('--out',type=Path)
    args=parser.parse_args()
    panel=strict_json(Path(__file__).with_name('panel.json').read_text())
    bases={name:strict_json((ROOT/'native/oracle-statistics/examples'/('glm-'+name+'.json')).read_text()) for name in ('binomial','poisson')}
    if args.native:
        catalog_process=subprocess.run([str(args.native.resolve()),'--catalog'],text=True,capture_output=True,check=True,timeout=30)
        catalog=strict_json(catalog_process.stdout)
        if OPERATION not in catalog.get('operations',[]):
            raise RuntimeError('native executable lacks events/exposure operation')
    records=[]
    for case in panel['cases']:
        request=merge(bases[case['base']],case.get('overrides',{}))
        if case.get('expand_bernoulli'):
            features=[];successes=[]
            for row,s,t in zip(request['features'],request['successes'],request['trials']):
                for k in range(t):
                    features.append(row[:]);successes.append(int(k<s))
            request.update(features=features,successes=successes,trials=[1]*len(features))
        reply=None;refusal=None
        try:
            reply=native(args.native,request) if args.native else hosted(args.base,args.tenant,request)
        except NativeRefusal as error:
            refusal={'code':error.code,'detail':str(error)}
        except urllib.error.HTTPError as error:
            if error.code not in (400,422):
                raise
            refusal={'code':'input_http_'+str(error.code),'detail':error.read(4096).decode(errors='replace')}
        if case.get('error'):
            correct=refusal is not None and refusal['code'] in ('invalid_input','invalid_json','native_request_refused','input_http_400','input_http_422')
        elif refusal:
            correct=False
        elif case.get('truth'):
            correct=check(reply['result'],case['truth'])
        elif case.get('status'):
            correct=reply['result']['status']==case['status']
        else:
            correct=case.get('not_success',False) and reply['result']['status']!=SUCCESS
        withheld=refusal is not None or reply['status']=='withheld'
        expected_refusal=case.get('error') or case.get('status') or case.get('not_success')
        records.append({'id':case['id'],'right':bool(correct),'withheld':bool(withheld),
                        'false_yes':bool(expected_refusal and not withheld),'refusal':refusal,'reply':reply})
    report={'scope':panel['scope'],'mode':'native' if args.native else 'hosted','total':len(records),
            'right':sum(r['right'] for r in records),'wrong':sum(not r['right'] for r in records),
            'withheld':sum(r['withheld'] for r in records),'false_yes':sum(r['false_yes'] for r in records),'cases':records}
    text=json.dumps(report,indent=2,allow_nan=False)+'\n'
    if args.out:
        args.out.write_text(text)
    print(text,end='')
    return 0 if all(r['right'] for r in records) else 1


if __name__=='__main__':
    sys.exit(main())
