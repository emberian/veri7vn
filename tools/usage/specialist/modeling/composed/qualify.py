#!/usr/bin/env python3
"""Untrusted bounded HTTP qualification for explicit-owner composition, not original admission."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import time
import urllib.error
import urllib.request

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[2]))
import events_exposure
from hosted_reasoning import normalize_tenant
sys.path.insert(0, str(HERE.parent))
from organ_modeling import Organ, PREFIX


def need(condition, message):
    if not condition:
        raise ValueError(message)


def close(value, gold):
    return type(value) in (int, float) and math.isfinite(value) and abs(value-gold) <= 1e-6*max(1, abs(gold))


def numeric_rows(rows, field, gold):
    need(len(rows) == len(gold), field+' length')
    need(all(close(row.get(field), expected) for row, expected in zip(rows, gold)), field+' analytic values')


def score(case, envelope):
    """No fit or candidate prose is used to construct mathematical gold."""
    need(envelope.get('outcome') == 'completed', 'completed query envelope')
    r = envelope.get('reply', {})
    kind = case['expect']['kind']; gold = case['expect']
    if kind.startswith('core_'):
        need(r.get('status') == 'answered' and r.get('path') != 'native:modeling', 'ordinary core owns answer')
        if kind == 'core_identity':
            # Architecture self-description, independently expected from core about route.
            need('oracle' in r.get('response', '').lower(), 'identity describes Oracle')
            need('act:about' in r.get('path', '') or r.get('provenance', {}).get('kind') == 'self_description', 'core self provenance')
        else:
            value = r.get('value')
            response = r.get('response', '').strip()
            if not close(value, gold['value']):
                # Accept a numeric answer, or explicit result after "is"/"="; never a mention among input rows.
                token = re.escape(str(gold['value']))+r'(?:\.0+)?'
                need(bool(re.search(r'(?:^'+token+r'\s*\.?$|(?:\bis\s+|=\s*)'+token+r'(?![\d.]))', response, re.I)), 'independent ordinary arithmetic result')
        return
    if kind == 'native_unsupported':
        need(r.get('status') == 'withheld' and r.get('path') == 'native:context>unsupported', 'outside prefix retains native owner')
        return
    need(r.get('path') == 'native:modeling', 'explicit modeling owner')
    need(r.get('authority') == 'computation_only', 'conditional computation authority')
    if kind == 'invalid':
        need(r.get('status') == 'withheld' and r.get('reason') == 'invalid_input' and r.get('kind') == 'modeling_input', 'owned invalid input refusal')
        need('result' not in r, 'invalid request has no fit')
        return
    supplied = events_exposure.strict_json(case['q'][len(PREFIX):])
    a = supplied['arguments']; result = r.get('result', {})
    need(r.get('supplied') == supplied, 'complete request binding')
    need(r.get('operation_id') == supplied['operation'] == result.get('operation'), 'operation binding')
    need('checked_reply' not in r, 'single numerical payload projection')
    need(isinstance(r.get('response'), str) and not r['response'].startswith('Supplied modeling result: '), 'human response without serialized payload')
    need(bool(result.get('assurance')), 'native assurance retained')
    refused = kind.endswith('_refusal')
    need(r.get('status') == ('withheld' if refused else 'answered'), 'answer/refusal status')
    need(r.get('modeling_reason') == ('model_refused' if refused else 'model_result'), 'conversational modeling reason')
    if refused:
        need(r.get('reason') == ('calibration_unavailable' if kind.startswith('calibration') else gold['status']), 'native provider refusal reason retained')
    else:
        classification = ('numerical_calibration_conditional_on_supplied_model' if kind.startswith('calibration') else 'numerical_glm_with_exact_finite_existence_certificate')
        need(r.get('classification') == classification and isinstance(r.get('runtime_identity'), str) and bool(r['runtime_identity']), 'native classification and runtime identity retained')
        need('reason' not in r, 'answered native metadata preserved without invented provider reason')
    if kind.startswith('calibration'):
        need(result.get('direction') == a['direction'] and result.get('uncertainty') == a['uncertainty'], 'calibration quantity')
        need(result.get('fit', {}).get('model', {}).get('assumptions') == a['assumptions'], 'calibration assumptions preserved')
        forward = a['direction'] != 'inverse_point'
        need(result.get('input_unit') == a['x_unit' if forward else 'response_unit'], 'input unit')
        need(result.get('output_unit') == a['response_unit' if forward else 'x_unit'], 'output unit')
        rows = result.get('estimates', [])
        need([row.get('supplied_value') for row in rows] == a['values'], 'query values preserved')
        if refused:
            need(all(row.get('value') is None and row.get('pointwise_interval') is None and gold['reason'] in row.get('unavailable_reasons', []) for row in rows), 'inverse uncertainty explicitly refused')
        else:
            numeric_rows(rows, 'value', gold['values'])
            need(all(row.get('unit') == gold['unit'] for row in rows), 'estimate units')
            if 'interval' in gold:
                interval = rows[0].get('pointwise_interval')
                need(isinstance(interval, list) and len(interval) == 2 and all(close(x,y) for x,y in zip(interval,gold['interval'])), 'independent t interval')
            else:
                need(all(row.get('pointwise_interval') is None for row in rows), 'point-only has no interval')
    else:
        # Independent exact witness replay, not trust in the host's own checked flag.
        replay = events_exposure.validate_result(a, result)
        rows = result['predictions']
        if refused:
            need(result.get('status') == gold['status'] and bool(replay['client_certificate_replay'].get('separation')), 'exact separation replay')
        else:
            need(result.get('status') == 'finite_mle_converged' and bool(replay['client_certificate_replay'].get('finite_existence')), 'finite existence replay')
            for field in ('probability', 'expected_count', 'rate_per_exposure_unit'):
                if field in gold:
                    numeric_rows(rows, field, gold[field])


def transport(base, tenant, raw, timeout):
    request = urllib.request.Request(base.rstrip('/')+'/query', data=raw,
        headers={'Content-Type':'application/json', 'X-Mini-Oracle-Tenant':tenant})
    try:
        response = urllib.request.urlopen(request, timeout=timeout)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        data = response.read(2**20+1)
        status = response.status
    need(len(data) <= 2**20, 'bounded response')
    return status, data


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--url', required=True)
    p.add_argument('--tenant', default='structured-modeling-composed-panel')
    p.add_argument('--split', choices=('dev','heldout','both'), default='both')
    p.add_argument('--controls', choices=('native','engine','none'), default='native')
    p.add_argument('--mode', choices=('panel','profile-unavailable','readonly'), default='panel')
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--timeout', type=float, default=30)
    p.add_argument('--run-id', default='modeling-composed-v1')
    p.add_argument('--replay-from', type=Path, help='After an externally managed host restart, replay a prior receipt verbatim.')
    args=p.parse_args()
    need(0 < args.timeout <= 120, 'bounded timeout')
    need(bool(re.fullmatch(r'[A-Za-z0-9_-]{1,40}', args.run_id)), 'bounded run identifier')
    tenant=normalize_tenant(args.tenant); fixture=HERE/'panel.json'; panel=json.loads(fixture.read_text())
    rows=[]; failures=[]
    if args.replay_from:
        original=json.loads(args.replay_from.read_text())
        need(original['tenant'] == tenant and not original['failures'], 'successful receipt and same tenant for exact replay')
        for old in original['records']:
            status, raw=transport(args.url,tenant,old['request'].encode(),args.timeout)
            good=status==old['http_status'] and raw.decode()==old['response']
            rows.append(dict(id=old['id'],exact_replay=good))
            if not good:failures.append(old['id'])
        report=dict(scope='exact retry after externally managed restart',records=rows,failures=failures)
    else:
        cases=[]
        for split in (('dev','heldout') if args.split=='both' else (args.split,)):
            cases.extend((split,case) for case in panel[split])
        if args.mode != 'panel':cases=[cases[0]]
        else:cases.extend(('control',case) for case in panel.get(args.controls+'_controls', []))
        for index,(split,case) in enumerate(cases):
            request=json.dumps(dict(request_id=args.run_id+'-'+str(index),conversation_id=args.run_id+'-'+str(index),text=case['q']),ensure_ascii=False,separators=(',',':'))
            started=time.monotonic();row=dict(id=split+'/'+case['id'],request=request,gold_kind=case['expect']['kind'])
            try:
                status, raw=transport(args.url,tenant,request.encode(),args.timeout)
                row.update(http_status=status,response=raw.decode(),elapsed_ms=(time.monotonic()-started)*1000)
                envelope=events_exposure.strict_json(raw)
                row['asserted']=envelope.get('reply',{}).get('status')=='answered'
                if args.mode=='profile-unavailable':
                    need(status==503 and envelope.get('error')=='modeling_profile_unavailable', 'absent profile is execution failure HTTP503')
                elif args.mode=='readonly':
                    need(status==200 and envelope.get('outcome')=='completed' and envelope.get('reply',{}).get('reason')=='conversation_transition_unsupported' and envelope['reply'].get('status')=='withheld', 'readonly transition refused')
                else:
                    need(status==200, 'HTTP200 for semantic outcomes');score(case,envelope)
                retry_status,retry_raw=transport(args.url,tenant,request.encode(),args.timeout)
                need(retry_status==status and retry_raw==raw, 'immediate exact-byte retry')
                row['correct']=True
            except (ValueError,TypeError,KeyError,OSError,RecursionError) as error:
                row.update(correct=False,error=str(error));failures.append(row['id'])
            rows.append(row)
        # Standalone exclusion is an independent structural check with no HTTP calls.
        lane_controls={q:Organ(args.url,tenant).answer(q,'standalone-exclusion') is None for q in panel['standalone_controls']}
        failures.extend('standalone/'+q for q,good in lane_controls.items() if not good)
        counts={'correct':sum(row['correct'] for row in rows),'wrong_assertions':sum(not row['correct'] and row.get('asserted',False) for row in rows),'false_yes_invalid':sum(row['gold_kind']=='invalid' and row.get('asserted',False) for row in rows)}
        report=dict(scope=panel['composition'],counts=counts,mode=args.mode,fixture_sha256=hashlib.sha256(fixture.read_bytes()).hexdigest(),tenant=tenant,records=rows,standalone_controls=lane_controls,failures=failures)
    args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(dict(scope=report['scope'],requests=len(rows),failed=len(failures),receipt=str(args.out))))
    return int(bool(failures))

if __name__=='__main__':raise SystemExit(main())
