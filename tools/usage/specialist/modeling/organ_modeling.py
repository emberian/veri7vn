"""Untrusted supplied-data specialist; all fits execute in the Rust HTTP host.

Parsing, assumption declarations and certificate replay are untrusted boundaries.
No Python fit, inference, automatic family selection or fallback is provided.
"""
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import calibration
import events_exposure

PREFIX = 'Model supplied data: '
MAX_BYTES = 65536
RESULT_PREFIX = 'Supplied modeling result: '


def wire_reply(row):
    # Original Workbench Loaded.reply retains response but projects custom fields.
    # Carry the complete record there too, so its unchanged scorer can inspect it.
    return {**row, 'response': RESULT_PREFIX + json.dumps(row, allow_nan=False, separators=(',', ':'))}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def label(value):
    return isinstance(value, str) and 0 < len(value.strip()) <= 512


def numbers(values, maximum=256):
    return isinstance(values, list) and 0 < len(values) <= maximum and all(
        type(x) in (int, float) and math.isfinite(x) for x in values)


def validate(request):
    require(isinstance(request, dict) and set(request) == {'operation', 'arguments'}, 'Explicit operation and arguments required.')
    operation, a = request['operation'], request['arguments']
    require(isinstance(a, dict), 'Arguments must be an object.')
    if operation == 'statistics.calibration':
        required = {'x', 'response', 'x_name', 'x_unit', 'response_unit', 'assumptions', 'covariance', 'direction', 'uncertainty', 'values'}
        allowed = required | {'relative_precisions', 'observation_relative_precision', 'confidence_level', 'rank_relative'}
        require(required <= set(a) <= allowed, 'Complete calibration fields required; unknown fields refused.')
        require(numbers(a['x']) and numbers(a['response']) and len(a['x']) == len(a['response']), 'Complete finite paired rows required.')
        require(all(label(a[k]) for k in ('x_name', 'x_unit', 'response_unit')), 'Explicit predictor and unit labels required.')
        require(a['direction'] in ('forward_mean', 'forward_observation', 'inverse_point'), 'Unsupported calibration direction.')
        require(a['uncertainty'] in ('point_only', 'pointwise_interval'), 'Explicit supported uncertainty required.')
        require(a['covariance'] in ('classical_normal_errors', 'hc3_asymptotic'), 'Explicit covariance model required.')
        require(numbers(a['values'], 32), 'Finite requested values required.')
        if a['direction'] == 'forward_observation':
            require(type(a.get('observation_relative_precision')) in (int, float) and math.isfinite(a['observation_relative_precision']) and a['observation_relative_precision'] > 0, 'New observation precision required.')
        assumptions = a['assumptions']
    elif operation == 'statistics.events_exposure':
        required = {'family', 'method', 'features', 'intercept', 'uncertainty', 'model', 'predictions'}
        allowed = required | {'successes', 'trials', 'counts', 'exposures', 'exposure_unit', 'confidence_level', 'rank_relative', 'solver'}
        require(required <= set(a) <= allowed, 'Complete GLM fields required; unknown fields refused.')
        require(a['uncertainty'] in ('none', 'model_based_wald'), 'Explicit supported uncertainty required.')
        m = a['model']
        require(isinstance(m, dict) and set(m) == {'description', 'predictor_names', 'predictor_units', 'independent_unit', 'grouping', 'assumptions'}, 'Explicit sampling unit, grouping and model declarations required.')
        require(all(label(m[k]) for k in ('description', 'independent_unit', 'grouping')), 'Nonempty sampling declarations required.')
        require(isinstance(a['features'], list) and a['features'] and isinstance(a['features'][0], list), 'Supplied design required.')
        q = len(a['features'][0])
        require(all(isinstance(m[k], list) and len(m[k]) == q and all(label(x) for x in m[k]) for k in ('predictor_names', 'predictor_units')), 'Every predictor needs a name and unit.')
        require(isinstance(a['predictions'], list) and 0 < len(a['predictions']) <= 32, 'Explicit bounded prediction rows required.')
        for p in a['predictions']:
            require(isinstance(p, dict) and isinstance(p.get('features'), list) and len(p['features']) == q and (q == 0 or numbers(p['features'], 16)), 'Complete finite prediction features required.')
            if a['family'] == 'poisson_log':
                require(set(p) == {'features', 'exposure'} and type(p['exposure']) in (int, float) and math.isfinite(p['exposure']) and p['exposure'] > 0, 'Every Poisson prediction requires exposure.')
            else:
                require(set(p) == {'features', 'trials'} and type(p['trials']) is int and 0 < p['trials'] <= 10**9, 'Every binomial prediction requires explicit trials.')
        if a['family'] == 'poisson_log':
            require(label(a.get('exposure_unit')), 'Explicit exposure unit required.')
        events_exposure.cone(a, events_exposure.RationalReplay())
        assumptions = m['assumptions']
    else:
        raise ValueError('Unsupported modeling operation.')
    require(isinstance(assumptions, list) and 0 < len(assumptions) <= 16 and all(label(x) for x in assumptions), 'Explicit bounded model assumptions required.')
    return operation, a


class Organ:
    def __init__(self, url='http://127.0.0.1:8765', tenant='modeling-specialist'):
        self.url, self.tenant = url, tenant

    def takes(self, text):
        return isinstance(text, str) and text.startswith(PREFIX)

    def answer(self, text, session):
        if not self.takes(text):
            return None
        try:
            require(len(text.encode('utf-8')) <= MAX_BYTES, 'Supplied request exceeds byte cap.')
            request = calibration.strict_json(text[len(PREFIX):])
            operation, arguments = validate(request)
        except (ValueError, KeyError, TypeError, OverflowError, RecursionError) as error:
            return wire_reply({'status': 'withheld', 'kind': 'modeling_input', 'reason': 'invalid_input', 'detail': str(error)})
        try:
            client = calibration if operation == 'statistics.calibration' else events_exposure
            checked = client.hosted(self.url, self.tenant, arguments)
            result = checked.get('result')
            require(isinstance(result, dict), 'Host supplied no model result.')
            status = checked['status']
            require(status in ('answered', 'withheld'), 'Invalid model status.')
        except (ValueError, KeyError, TypeError, OSError, OverflowError, RecursionError) as error:
            return wire_reply({'status': 'withheld', 'kind': 'modeling_input', 'reason': 'execution_failure', 'detail': str(error)})
        return wire_reply({'status': status, 'kind': 'supplied_modeling', 'operation_id': operation,
                'authority': 'computation_only', 'result': result, 'checked_reply': checked,
                'supplied': request, 'reason': 'model_result' if status == 'answered' else 'model_refused',
                'interpretation': 'Conditional computation on supplied rows and declared assumptions; no model-truth or causal claim.'})
