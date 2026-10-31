#!/usr/bin/env python3
"""Untrusted supplied events/exposure client with independent exact cone replay.

Grouped binomial trials are sampling counts, not precision weights. Poisson
exposure is an explicit log offset. Source completeness, independence, grouping
and units remain caller assertions. No individual-count prediction interval,
Firth fallback, regularization, causal interpretation or coverage proof is made.
"""
from __future__ import annotations
import argparse
from fractions import Fraction
import json
import math
from pathlib import Path
import subprocess
import sys
# Direct CLI and path-based panel imports use the same sibling transport.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from hosted_reasoning import Client, invoke_envelope, ContractError, unique_object, invalid_constant

OPERATION = 'statistics.events_exposure'
SUCCESS = 'finite_mle_converged'
STATUSES = {SUCCESS, 'separation_certified', 'rank_deficient', 'design_ill_conditioned',
            'no_finite_mle_established', 'not_converged'}


def strict_json(raw):
    return json.loads(raw, object_pairs_hook=unique_object, parse_constant=invalid_constant)


def request_preserved(provided, reported):
    """Bind all provided fields while permitting native explicit defaults."""
    if isinstance(provided, dict):
        return isinstance(reported, dict) and all(k in reported and request_preserved(v, reported[k]) for k, v in provided.items())
    if isinstance(provided, list):
        return isinstance(reported, list) and len(provided) == len(reported) and all(request_preserved(a, b) for a, b in zip(provided, reported))
    return provided == reported


class NativeRefusal(ValueError):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


class RationalReplay:
    """Bounded independent checker; no numerical solver metadata is trusted."""
    def __init__(self):
        self.work = 0

    def q(self, value):
        self.work += 1
        if self.work > 400000:
            raise ContractError('client exact replay work exhausted')
        if isinstance(value, str):
            if not value or len(value) > 2500:
                raise ContractError('invalid bounded rational witness')
            try:
                value = Fraction(value)
            except (ValueError, ZeroDivisionError) as error:
                raise ContractError('invalid rational witness') from error
        if max(value.numerator.bit_length(), value.denominator.bit_length()) > 4096:
            raise ContractError('client exact replay bit limit')
        return value

    def dot(self, row, weights):
        total = self.q(Fraction(0))
        for a, b in zip(row, weights):
            total = self.q(total + self.q(a*b))
        return total

    def full_rank(self, rows, p):
        matrix = [row[:] for row in rows]
        if len(matrix) != p or any(len(row) != p for row in matrix):
            return False
        for column in range(p):
            pivot = next((i for i in range(column, p) if matrix[i][column]), None)
            if pivot is None:
                return False
            matrix[column], matrix[pivot] = matrix[pivot], matrix[column]
            divisor = matrix[column][column]
            matrix[column] = [self.q(v/divisor) for v in matrix[column]]
            for i in range(column+1, p):
                multiple = matrix[i][column]
                matrix[i] = [self.q(a-self.q(multiple*b)) for a, b in zip(matrix[i], matrix[column])]
        return True


def cone(arguments, checker):
    family = arguments['family']
    features = arguments['features']
    if (arguments.get('method') != 'maximum_likelihood' or type(arguments.get('intercept')) is not bool
            or not isinstance(features, list) or not 1 <= len(features) <= 256 or not isinstance(features[0], list)):
        raise ContractError('client design row limit')
    n = len(features)
    def integers(values, minimum):
        return isinstance(values, list) and len(values) == n and all(type(v) is int and minimum <= v <= 1_000_000_000 for v in values)
    if family == 'grouped_binomial_logit':
        successes, trials = arguments.get('successes'), arguments.get('trials')
        if (not integers(successes, 0) or not integers(trials, 1) or any(s > t for s, t in zip(successes, trials))
                or any(arguments.get(k) is not None for k in ('counts', 'exposures', 'exposure_unit'))):
            raise ContractError('invalid binomial sampling support')
    elif family == 'poisson_log':
        exposures = arguments.get('exposures')
        if (not integers(arguments.get('counts'), 0) or not isinstance(exposures, list) or len(exposures) != n
                or any(type(e) not in (int, float) or not math.isfinite(e) or e <= 0 or abs(math.log(e)) > 500 for e in exposures)
                or any(arguments.get(k) is not None for k in ('successes', 'trials'))):
            raise ContractError('invalid Poisson sampling support or exposure')
    else:
        raise ContractError('unsupported GLM family')
    q = len(features[0])
    p = q + int(arguments['intercept'])
    if not 1 <= p <= 16:
        raise ContractError('client parameter limit')
    rows, strict = [], []
    for i, features_row in enumerate(features):
        if not isinstance(features_row, list) or len(features_row) != q:
            raise ContractError('ragged supplied design')
        values = ([1] if arguments['intercept'] else []) + features_row
        if any(type(v) not in (int, float) or not math.isfinite(v) for v in values):
            raise ContractError('nonfinite supplied design')
        row = [checker.q(Fraction.from_float(float(v))) for v in values]
        if family == 'grouped_binomial_logit':
            successes, trials = arguments['successes'][i], arguments['trials'][i]
            if successes > 0:
                rows.append(row[:]); strict.append(True)
            if successes < trials:
                rows.append([-v for v in row]); strict.append(True)
        elif family == 'poisson_log':
            rows.append(row); strict.append(arguments['counts'][i] == 0)
        else:
            raise ContractError('unsupported GLM family')
    return rows, strict, p


def replay_finiteness(arguments, certificate):
    if not isinstance(certificate, dict) or certificate.get('family') != arguments['family']:
        raise ContractError('missing/mismatched finite existence certificate')
    checker = RationalReplay()
    rows, strict, p = cone(arguments, checker)
    weights = certificate.get('weights')
    basis = certificate.get('basis_rows')
    if (not isinstance(weights, list) or len(weights) != len(rows) or any(not isinstance(w, str) for w in weights)
            or not isinstance(basis, list) or len(basis) != p
            or any(type(i) is not int or not 0 <= i < len(rows) for i in basis) or len(set(basis)) != p):
        raise ContractError('invalid finite witness shape')
    weights = [checker.q(w) for w in weights]
    if any(required and w <= 0 for required, w in zip(strict, weights)):
        raise ContractError('finite witness is not strictly positive where required')
    if any(checker.dot([r[j] for r in rows], weights) for j in range(p)):
        raise ContractError('finite witness does not exactly balance original rows')
    if not checker.full_rank([rows[i] for i in basis], p):
        raise ContractError('finite witness has no exact independent row basis')
    return {'accepted': True, 'checker': 'independent_python_fraction_cone_balance_and_rank',
            'work_units': checker.work, 'scope': 'finite ordinary MLE existence and exact identifiability on supplied dyadic rows; no numerical-optimality or model-truth proof'}


def replay_separation(arguments, certificate):
    if not isinstance(certificate, dict) or certificate.get('family') != arguments['family']:
        raise ContractError('missing/mismatched separation certificate')
    checker = RationalReplay()
    rows, strict, p = cone(arguments, checker)
    direction = certificate.get('direction')
    if not isinstance(direction, list) or len(direction) != p or any(not isinstance(v, str) for v in direction):
        raise ContractError('invalid separation direction')
    direction = [checker.q(v) for v in direction]
    improved = False
    for row, zero_count in zip(rows, strict):
        margin = checker.dot(row, direction)
        if arguments['family'] == 'grouped_binomial_logit':
            if margin < 0:
                raise ContractError('binomial direction decreases an observed support likelihood term')
            improved |= margin > 0
        elif zero_count:
            if margin > 0:
                raise ContractError('Poisson direction increases a zero-count mean')
            improved |= margin < 0
        elif margin:
            raise ContractError('Poisson direction changes a positive-count linear predictor')
    if not improved:
        raise ContractError('separation direction has no strict improvement')
    return {'accepted': True, 'checker': 'independent_python_fraction_recession_direction',
            'work_units': checker.work, 'scope': 'no finite ordinary likelihood maximizer on these supplied rows; not infeasibility of a physical or probabilistic model'}


def validate_result(arguments, result):
    cone(arguments, RationalReplay())
    if (not isinstance(result, dict) or result.get('operation') != OPERATION
            or result.get('schema') != 'oracle-statistics-experimental-v1' or result.get('status') not in STATUSES):
        raise ContractError('invalid GLM result envelope')
    supplied = result.get('supplied')
    if not isinstance(supplied, dict) or not request_preserved(arguments, supplied):
        raise ContractError('result does not preserve the complete supplied request')
    status = result['status']
    p = len(arguments['features'][0]) + int(arguments['intercept'])
    candidate = result.get('coefficient_candidate')
    if (not isinstance(candidate, list) or len(candidate) != p
            or any(type(v) not in (int, float) or not math.isfinite(v) for v in candidate)):
        raise ContractError('invalid last coefficient candidate')
    predictions = result.get('predictions')
    if not isinstance(predictions, list) or len(predictions) != len(arguments.get('predictions', [])):
        raise ContractError('GLM prediction count mismatch')
    for prediction, request in zip(predictions, arguments.get('predictions', [])):
        if any(prediction.get(k) != request.get(k) for k in ('features', 'exposure', 'trials')):
            raise ContractError('prediction request binding mismatch')
        probability = prediction.get('probability')
        if probability is not None and (type(probability) not in (int, float) or not math.isfinite(probability) or not 0 <= probability <= 1):
            raise ContractError('invalid fitted probability')
        for key in ('rate_per_exposure_unit', 'expected_count'):
            if prediction.get(key) is not None and (type(prediction[key]) not in (int, float) or not math.isfinite(prediction[key]) or prediction[key] < 0):
                raise ContractError('invalid positive mean/rate')
        if any(key in prediction for key in ('observation_interval', 'individual_count_interval')):
            raise ContractError('unsupported individual count interval')
        if status != SUCCESS and any(prediction.get(k) is not None for k in ('probability', 'rate_per_exposure_unit', 'expected_count',
                'pointwise_probability_interval', 'pointwise_rate_interval', 'pointwise_expected_count_interval')):
            raise ContractError('nonaccepted GLM iterate supplied predictions or uncertainty')
    finite = result.get('finite_mle_certificate')
    separation = result.get('separation_certificate')
    if finite is not None and separation is not None:
        raise ContractError('contradictory finite and separation certificates')
    replay = {}
    if finite is not None:
        replay['finite_existence'] = replay_finiteness(arguments, finite)
    if separation is not None:
        replay['separation'] = replay_separation(arguments, separation)
    if status == SUCCESS:
        diagnostics = result.get('diagnostics', {})
        if (finite is None or diagnostics.get('numerical_design_rank') != p
                or type(diagnostics.get('score_scaled_infinity_norm')) not in (int, float)
                or not 0 <= diagnostics['score_scaled_infinity_norm'] <= 1e-8
                or type(diagnostics.get('newton_decrement_squared')) not in (int, float)
                or not 0 <= diagnostics['newton_decrement_squared'] <= 1e-16):
            raise ContractError('accepted GLM missing existence witness or numerical score/decrement convergence')
    elif result.get('inference') is not None:
        raise ContractError('nonaccepted iterate supplied statistical inference')
    if status == 'separation_certified' and separation is None:
        raise ContractError('separation claim without checked direction')
    return {'operation_id': OPERATION, 'status': 'answered' if status == SUCCESS else 'withheld',
            'authority': 'computation_only', 'result': result, 'client_certificate_replay': replay}


def native(binary, arguments):
    completed = subprocess.run([str(Path(binary).resolve())],
        input=json.dumps({'operation': OPERATION, 'arguments': arguments}, allow_nan=False),
        text=True, capture_output=True, timeout=60)
    if len(completed.stdout.encode()) > 2**20:
        raise ContractError('native GLM response exceeds client limit')
    response = strict_json(completed.stdout)
    if completed.returncode:
        error = response.get('error', {})
        if error.get('code') in ('invalid_input', 'invalid_json', 'resource_limit', 'cancelled', 'numerical_failure'):
            raise NativeRefusal(error['code'], error.get('message', error['code']))
        raise ContractError('native process failed without a recognized refusal')
    return validate_result(arguments, response)


def hosted(base, tenant, arguments):
    # Reuse the host's established tenant-label normalization and mandatory
    # request/conversation envelope. Pure retries would repeat the entire fit.
    transport = Client(base, tenant, timeout=60, retries=0)
    descriptor = transport.transport('/operations/' + OPERATION)
    if descriptor.get('id') != OPERATION or descriptor.get('availability') != 'live_direct':
        raise ContractError('events/exposure operation unavailable')
    envelope = transport.transport('/invoke', invoke_envelope(OPERATION, arguments, 'supplied-events-exposure'))
    if envelope.get('outcome') != 'completed' or envelope.get('operation_id') != OPERATION:
        raise ContractError('host GLM invocation incomplete: ' + json.dumps(envelope))
    reply = envelope.get('reply', {})
    if (reply.get('operation_id') == OPERATION and reply.get('authority') == 'computation_only'
            and reply.get('status') == 'withheld' and reply.get('reason') == 'native_request_refused'
            and reply.get('result') is None):
        detail = reply.get('detail', '')
        code = ('resource_limit' if detail.startswith('resource limit:') else 'cancelled' if detail.startswith('cancelled')
                else 'numerical_failure' if detail.startswith('numerical computation refused:') else 'native_request_refused')
        raise NativeRefusal(code, detail)
    if (reply.get('operation_id') != OPERATION or reply.get('authority') != 'computation_only'
            or reply.get('status') not in ('answered', 'withheld') or not isinstance(reply.get('result'), dict)):
        raise ContractError('invalid hosted GLM structured reply')
    checked = validate_result(arguments, reply['result'])
    if checked['status'] != reply['status']:
        raise ContractError('host structured acceptance does not match numerical/certificate status')
    checked['host_reply'] = reply
    return checked


def describe(reply):
    result = reply['result']
    if result['status'] != SUCCESS:
        return 'No accepted finite MLE: ' + result['status'] + '. Last numerical candidate is diagnostic only; predictions and uncertainty are withheld.'
    lines = ['Accepted approximate maximum-likelihood fit under the supplied model.']
    for prediction in result['predictions']:
        if result['supplied']['family'] == 'grouped_binomial_logit':
            lines.append('Fitted success probability: ' + str(prediction['probability'])
                + ('; expected successes: ' + str(prediction['expected_count']) if prediction['expected_count'] is not None else '') + '.')
        else:
            lines.append('Fitted rate per ' + result['supplied']['exposure_unit'] + ': ' + str(prediction['rate_per_exposure_unit'])
                + '; expected count at supplied exposure: ' + str(prediction['expected_count']) + '.')
    lines.append('Grouping, independence, units and model assumptions are caller assertions. Any intervals are pointwise asymptotic mean intervals.')
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path, help='JSON GlmInput arguments object')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--native', type=Path, help='already built oracle-statistics one-request executable')
    group.add_argument('--base', help='host base URL with events/exposure operation')
    parser.add_argument('--tenant', default='events-exposure')
    parser.add_argument('--summary', action='store_true')
    args = parser.parse_args()
    raw = args.input.read_bytes()
    if len(raw) > 2**20:
        raise ContractError('GLM input exceeds client limit')
    arguments = strict_json(raw)
    reply = native(args.native, arguments) if args.native else hosted(args.base, args.tenant, arguments)
    print(describe(reply) if args.summary else json.dumps(reply, indent=2, allow_nan=False))


if __name__ == '__main__':
    main()
