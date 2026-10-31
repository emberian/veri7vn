#!/usr/bin/env python3
"""Independent analytic calibration panel scorer; not Oracle7 exam.py's scorer.

Reports right/wrong/withheld/false-yes counts on manufactured structured requests.
No sampling simulation or empirical interval-coverage claim is made.
"""
import argparse
import json
import math
from pathlib import Path
import subprocess
import sys
import urllib.error

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from calibration import hosted, exact_extracted, strict_json, ExactInputError


def close(actual, expected):
    return type(actual) in (int, float) and math.isfinite(actual) and abs(actual-expected) <= 2e-7*max(1, abs(expected))


def check(result, expected, exact=False):
    if exact:
        if expected.get('withheld'):
            return result.get('status') == 'withheld'
        return result.get('status') == 'answered' and all(
            (all(close(a,b) for a,b in zip(result[k], v)) and len(result[k]) == len(v)) if isinstance(v,list)
            else close(result.get(k), v) for k,v in expected.items())
    estimates = result.get('estimates', [])
    if len(estimates) != len(expected['values']):
        return False
    for estimate, wanted in zip(estimates, expected['values']):
        if (wanted is None and estimate.get('value') is not None) or (wanted is not None and not close(estimate.get('value'),wanted)):
            return False
        if expected.get('no_interval') and estimate.get('pointwise_interval') is not None:
            return False
        if expected.get('any_reason') and not estimate.get('unavailable_reasons'):
            return False
        if expected.get('reason') and expected['reason'] not in estimate.get('unavailable_reasons',[]):
            return False
        if expected.get('unit') and estimate.get('unit') != expected['unit']:
            return False
    if 'outside' in expected and [e.get('outside_training_range') for e in estimates] != expected['outside']:
        return False
    if 'beta' in expected:
        beta=result.get('fit',{}).get('coefficient_candidate',[])
        if len(beta)!=len(expected['beta']) or not all(close(a,b) for a,b in zip(beta, expected['beta'])):
            return False
    if 'interval' in expected:
        # Independent analytic X'X=diag(3,2), SSE=6, df=1.
        # Student t with df=1 is Cauchy. Mean variance=2; new noise adds 6.
        variance = 2 if expected['interval'] == 'mean_cauchy' else 8
        width = math.tan(math.pi*.475)*math.sqrt(variance)
        interval = estimates[0].get('pointwise_interval')
        if not isinstance(interval,list) or len(interval)!=2 or not all(close(a,b) for a,b in zip(interval,[1-width,1+width])):
            return False
    return True


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    group=parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--native',type=Path,help='oracle-statistics one-request CLI')
    group.add_argument('--base',help='host base URL; exercises typed hosted operation')
    group.add_argument('--geostats',type=Path,help='existing geostats binary; runs exact comparison cases only')
    parser.add_argument('--tenant',default='calibration-panel')
    parser.add_argument('--out',type=Path)
    args=parser.parse_args()
    panel=strict_json(Path(__file__).with_name('panel.json').read_text())
    exact=args.geostats is not None
    base=panel['exact_base' if exact else 'base']
    cases=panel['exact_cases' if exact else 'cases']
    rows=[]
    for case in cases:
        request={**base,**case['overrides']}
        expected=case['expect']
        result=None
        host_refusal=None
        failed=False
        try:
            if exact:
                result=exact_extracted(args.geostats,request)
            elif args.native:
                proc=subprocess.run([str(args.native.resolve())], input=json.dumps({'operation':'statistics.calibration','arguments':request}),
                    text=True,capture_output=True,timeout=30)
                wire=strict_json(proc.stdout)
                if proc.returncode:
                    # A process launch, parser error or cancellation must not count
                    # as correct semantic rejection of a deliberately invalid input.
                    if wire.get('error',{}).get('code') not in ('invalid_input','invalid_json'):
                        raise RuntimeError('unexpected native failure: '+str(wire))
                    failed=True
                else:
                    result=wire
            else:
                reply=hosted(args.base,args.tenant,request)
                result=reply.get('result')
                if result is None:
                    if reply.get('status')=='withheld' and reply.get('reason')=='native_request_refused':
                        failed=True
                        host_refusal=reply
                    else:
                        raise RuntimeError('host did not retain calibration result for '+case['id']+': '+json.dumps(reply))
        except (ExactInputError, urllib.error.HTTPError) as error:
            if isinstance(error,urllib.error.HTTPError) and error.code not in (400,422):
                raise
            failed=True
        correct=failed if expected.get('error') else not failed and check(result,expected,exact)
        refused=failed or (result is not None and (result.get('status')=='withheld' if exact
            else all(e.get('value') is None for e in result.get('estimates',[]))))
        expect_refusal=expected.get('error') or expected.get('withheld') or expected.get('values')==[None]
        rows.append({'id':case['id'],'right':bool(correct),'withheld':bool(refused),'false_yes':bool(expect_refusal and not refused),
                     'result':result,'host_refusal':host_refusal})
    report={'scope':panel['scope'],'mode':'extracted_rounded_comparison' if exact else 'native' if args.native else 'hosted',
        'total':len(rows),'right':sum(r['right'] for r in rows),'wrong':sum(not r['right'] and not r['withheld'] for r in rows),
        'withheld':sum(r['withheld'] for r in rows),'false_yes':sum(r['false_yes'] for r in rows),'cases':rows}
    rendered=json.dumps(report,indent=2,allow_nan=False)+'\n'
    if args.out:
        args.out.write_text(rendered)
    print(rendered,end='')
    return 0 if all(r['right'] for r in rows) else 1


if __name__=='__main__':
    sys.exit(main())
