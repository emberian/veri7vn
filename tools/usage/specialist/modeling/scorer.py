"""Independent analytic gold; never solves a model or imports a model provider."""
import math
import json


def close(x, y):
    return type(x) in (int, float) and math.isfinite(x) and abs(x-y) <= 1e-6 * max(1, abs(y))


def ok(item, reply):
    reply = reply or {}
    text = reply.get('response', '')
    if 'result' not in reply and isinstance(text, str) and text.startswith('Supplied modeling result: '):
        try:
            decoded = json.loads(text[len('Supplied modeling result: '):])
            if isinstance(decoded, dict) and decoded.get('status') == reply.get('status'):
                reply = decoded
        except (ValueError, TypeError):
            pass
    asserted = reply.get('status') == 'answered'
    if item.get('lane_control'):
        return not asserted, asserted
    if not item.get('valid', True):
        return not asserted and reply.get('reason') != 'execution_failure', asserted
    if reply.get('reason') == 'execution_failure':
        return False, asserted
    r = reply.get('result', {})
    if item.get('refusal'):
        return (not asserted and reply.get('reason') == 'model_refused' and
                r.get('status') == item['refusal'] and
                (item['refusal'] != 'separation_certified' or bool(reply.get('checked_reply', {}).get('client_certificate_replay', {}).get('separation')))), asserted
    if not asserted:
        return False, False
    try:
        if 'values' in item:
            actual = [e['value'] for e in r['estimates']]
            good = len(actual) == len(item['values']) and all(close(x, y) for x, y in zip(actual, item['values']))
            good = good and all(e['unit'] == item['unit'] for e in r['estimates'])
            if 'interval' in item:
                interval = r['estimates'][0]['pointwise_interval']
                good = good and isinstance(interval, list) and len(interval) == 2 and all(close(x,y) for x,y in zip(interval,item['interval']))
        else:
            actual = [p[item['field']] for p in r['predictions']]
            good = r['status'] == 'finite_mle_converged' and bool(r.get('finite_mle_certificate'))
            good = good and bool(reply['checked_reply']['client_certificate_replay'].get('finite_existence'))
            good = good and len(actual) == len(item['values_glm']) and all(close(x, y) for x, y in zip(actual, item['values_glm']))
            if 'glm_probability_interval' in item:
                interval = r['predictions'][0]['pointwise_probability_interval']
                good = good and isinstance(interval, list) and len(interval) == 2 and all(close(x,y) for x,y in zip(interval,item['glm_probability_interval']))
        return good and reply.get('authority') == 'computation_only', True
    except (KeyError, TypeError):
        return False, True
