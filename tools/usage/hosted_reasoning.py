#!/usr/bin/env python3
"""Untrusted demonstration client for the Rust host's finite logic operations.

All observations are manufactured fixture data. This is advice about a supplied
build plan, never authority to deploy. Python transport and witness checks are
not proved. No world completeness is inferred from missing observations.
"""
import argparse
import copy
import hashlib
import json
import urllib.error
import urllib.request


class ContractError(ValueError):
    pass


def compact(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'))


def program_text(arguments):
    lines = []
    for rule in arguments['rules']:
        head = '' if rule['head'] is None else f"a{rule['head']}"
        terms = [f'a{x}' for x in rule['positive']] + [f'not a{x}' for x in rule['negative']]
        lines.append(head + (':-' + ','.join(terms) if rule['head'] is None or terms else '') + '.\n')
    return ''.join(lines)


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def stable(arguments, model):
    """Independent bounded client check; host checker is still handwritten Rust."""
    reduct = [r for r in arguments['rules'] if not set(r['negative']) & model]
    closure = set()
    while True:
        next_set = closure | {r['head'] for r in reduct if r['head'] is not None and set(r['positive']) <= closure}
        if next_set == closure:
            break
        closure = next_set
    return closure == model and not any(r['head'] is None and set(r['positive']) <= closure for r in reduct)


def validate_reply(operation, arguments, envelope):
    def require(test, reason):
        if not test:
            raise ContractError(reason)
    require(isinstance(envelope, dict), 'invalid envelope')
    require(envelope.get('outcome') == 'completed' and envelope.get('operation_id') == operation, 'operation failed or mismatched')
    structured = envelope.get('reply')
    require(isinstance(structured, dict) and structured.get('operation_id') == operation
            and structured.get('authority') == 'computation_only'
            and structured.get('status') in ('answered', 'withheld'), 'invalid structured reply')
    reply = structured.get('result')
    require(isinstance(reply, dict), 'missing result')
    require(reply.get('schema') == 'oracle-logic-experimental-v1' and reply.get('operation_id') == operation, 'logic schema/operation mismatch')
    require(reply.get('scope') == arguments['scope'], 'scope mismatch')
    require(reply.get('program_identity') == digest(program_text(arguments)), 'program identity mismatch')
    request = {'operation': operation.split('.')[-1], **arguments}
    require(reply.get('request_identity') == digest(compact(request)), 'request identity mismatch')
    require(reply.get('witness_check') == 'handwritten_gl_reduct', 'unknown witness checker')
    require(reply.get('status') in ('consistent', 'inconsistent', 'inconclusive'), 'invalid status')
    require((structured['status'] == 'withheld') == (reply['status'] == 'inconclusive'), 'structured status mismatch')
    require(type(reply.get('enumeration_complete')) is bool, 'invalid enumeration status')
    require(operation != 'logic.query' or not reply['enumeration_complete'], 'query claims enumeration')
    require(reply.get('completeness_trust') in ('none', 'solver_trusted_query_unsat_no_certificate',
            'solver_trusted_no_certificate', 'witnesses_only_backend_inconsistent'), 'unknown absence trust')
    models = reply.get('models')
    require(isinstance(models, list) and len(models) <= 128, 'invalid model list')
    for model in models:
        require(isinstance(model, list) and all(type(a) is int and 0 <= a < len(arguments['atoms']) for a in model), 'invalid model atoms')
        require(model == sorted(set(model)), 'duplicate or unordered model atoms')
        require(stable(arguments, set(model)), 'invalid stable witness')
    answers = reply.get('answers')
    require(isinstance(answers, list) and [a.get('atom') for a in answers if isinstance(a, dict)] == arguments['queries'], 'missing/duplicate/unexpected query answers')
    require(reply['status'] != 'inconsistent' or not models, 'inconsistent reply has models')
    absence_trusted = reply['completeness_trust'].startswith('solver_trusted_')
    require(reply['status'] != 'inconsistent' or absence_trusted, 'untrusted inconsistency claim')
    for answer in answers:
        require(set(answer) == {'atom', 'skeptical', 'credulous', 'true_witness', 'false_witness'}, 'invalid answer fields')
        require(type(answer['atom']) is int, 'invalid query atom type')
        atom = answer['atom']
        for key in ('skeptical', 'credulous'):
            require(answer.get(key) is None or type(answer[key]) is bool, 'invalid truth value')
        for key, contains in (('true_witness', True), ('false_witness', False)):
            index = answer.get(key)
            require(index is None or (type(index) is int and 0 <= index < len(models) and (atom in models[index]) == contains), 'invalid witness reference')
        s, c = answer.get('skeptical'), answer.get('credulous')
        require(not (s is True and c is False), 'impossible truth pair')
        require(absence_trusted or (s is not True and c is not False), 'absence claim without solver trust')
        require(c is not True or answer.get('true_witness') is not None, 'missing existential witness')
        require(s is not False or answer.get('false_witness') is not None, 'missing counterexample witness')
        require(not any((s is True and atom not in m) or (c is False and atom in m) for m in models), 'truth contradicts witness')
        if reply['status'] == 'inconsistent':
            require(s is None and c is None and not models and answer.get('true_witness') is None and answer.get('false_witness') is None, 'inconsistent reply asserts truth')
        if reply['status'] == 'consistent':
            require(models and s is not None and c is not None, 'consistent reply lacks completed answers')
    return reply


def unique_object(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ContractError('duplicate JSON key')
        value[key] = item
    return value


def invalid_constant(value):
    raise ContractError('non-finite JSON number')


class Client:
    def __init__(self, base, tenant, timeout=15, retries=0):
        self.base, self.tenant, self.timeout, self.retries = base.rstrip('/'), tenant, timeout, retries

    def transport(self, path, body=None):
        request = urllib.request.Request(self.base + path, data=None if body is None else compact(body).encode(),
            headers={'Content-Type': 'application/json', 'x-mini-oracle-tenant': self.tenant})
        with urllib.request.urlopen(request, timeout=self.timeout) as response:
            raw = response.read(1048577)
        if len(raw) > 1048576:
            raise ContractError('reply exceeds client limit')
        return json.loads(raw, object_pairs_hook=unique_object, parse_constant=invalid_constant)

    def discover(self):
        # Exact descriptor lookup under /operations avoids catalog page omissions.
        for operation in ('logic.query', 'logic.enumerate'):
            descriptor = self.transport('/operations/' + operation)
            if not isinstance(descriptor, dict) or descriptor.get('id') != operation or descriptor.get('availability') != 'live_direct':
                raise ContractError('required operation absent: ' + operation)

    def invoke(self, operation, arguments):
        body = {'operation_id': operation, 'arguments': arguments,
                'request_id': 'reasoning-' + digest(compact([operation, arguments]))[:32],
                'conversation_id': 'hosted-reasoning'}
        # Pure computation only. Request IDs correlate; they do not promise durable
        # replay. Explicit retries repeat the full immutable snapshot from scratch.
        for attempt in range(self.retries + 1):
            try:
                return validate_reply(operation, arguments, self.transport('/invoke', body))
            except urllib.error.HTTPError as error:
                if error.code not in (429, 503) or attempt == self.retries:
                    raise
            except (urllib.error.URLError, TimeoutError):
                if attempt == self.retries:
                    raise
        raise ContractError('retry exhausted')


class BuildPlan:
    """Complete local policy; external approval is explicitly an open observation."""
    atoms = ['dependency_ready', 'risk', 'plan_viable', 'reuse_cache', 'rebuild',
             'candidate', 'verified', 'compromised', 'approval_seen', 'denial_seen']

    def __init__(self, tenant):
        self.tenant = tenant
        self.evidence = {}
        self.history = []
        self.rules = [self.rule('plan_viable', ['dependency_ready'], ['risk']),
            self.rule('risk', ['compromised']),
            self.rule('reuse_cache', ['plan_viable'], ['rebuild']),
            self.rule('rebuild', ['plan_viable'], ['reuse_cache']),
            self.rule('candidate', ['reuse_cache']), self.rule('candidate', ['rebuild']),
            self.rule(None, ['verified', 'compromised'])]

    def rule(self, head, positive=(), negative=()):
        return {'head': None if head is None else self.atoms.index(head),
                'positive': [self.atoms.index(x) for x in positive],
                'negative': [self.atoms.index(x) for x in negative]}

    def revise(self, changes):
        draft = copy.deepcopy(self.evidence)
        for change in changes:
            if change[0] == 'assert':
                _, token, atom, source = change
                if token in draft or atom not in self.atoms:
                    raise ContractError('invalid or reused evidence token')
                draft[token] = {'atom': atom, 'source': source, 'active': True}
            elif change[0] == 'withdraw':
                token = change[1]
                if token not in draft or not draft[token]['active']:
                    raise ContractError('withdrawal names no active token')
                draft[token]['active'] = False
            else:
                raise ContractError('unknown revision')
        self.evidence = draft
        self.history.append(copy.deepcopy(changes))

    def snapshot(self):
        rules = self.rules + [self.rule(row['atom']) for _, row in sorted(self.evidence.items()) if row['active']]
        # Covers policy, labels, observations/provenance (including withdrawals),
        # and revision history. This label is never a cache key by itself.
        identity = digest(compact([self.tenant, self.atoms, rules, self.evidence, self.history]))
        return {'scope': {'tenant': self.tenant, 'snapshot': 'build-plan-' + identity, 'complete_program': True},
                'atoms': list(self.atoms), 'rules': rules, 'queries': list(range(len(self.atoms)))}


def classification(answer, status):
    if status == 'inconsistent':
        return 'inconsistent'
    if answer['skeptical'] is True:
        return 'skeptical'
    if answer['credulous'] is True:
        return 'credulous'
    if answer['credulous'] is False:
        return 'false-in-local-program'
    return 'unknown'


def workflow(client):
    client.discover()
    plan = BuildPlan(client.tenant)
    revisions = [
        ('default: two alternative build candidates', [('assert', 'inventory/dependency', 'dependency_ready', 'manufactured inventory')]),
        ('exception: scanner reports compromise', [('assert', 'scanner/alert', 'compromised', 'manufactured scanner alert')]),
        ('conflict: auditor also reports verified', [('assert', 'auditor/clean', 'verified', 'manufactured audit')]),
        ('repair: withdraw mistaken scanner evidence', [('withdraw', 'scanner/alert')]),
        ('dependency withdrawn: candidate no longer follows', [('withdraw', 'inventory/dependency')]),
    ]
    for title, changes in revisions:
        plan.revise(changes)
        arguments = plan.snapshot()
        replies = {op: client.invoke(op, arguments) for op in ('logic.query', 'logic.enumerate')}
        query, enumeration = replies.values()
        if query['status'] != enumeration['status']:
            raise ContractError('query/enumeration status disagreement')
        if enumeration['enumeration_complete']:
            if [(a['skeptical'], a['credulous']) for a in query['answers']] != [(a['skeptical'], a['credulous']) for a in enumeration['answers']]:
                raise ContractError('query/enumeration truth disagreement')
        conclusions = {arguments['atoms'][a['atom']]: classification(a, query['status']) for a in query['answers']}
        # Neither approval nor denial is observed: external approval stays unknown,
        # even though each observation atom is false in this complete local program.
        approval = 'unknown' if query['status'] == 'consistent' and all(query['answers'][i]['credulous'] is False for i in (8, 9)) else query['status']
        yield {'revision': title, 'scope': arguments['scope'], 'evidence': copy.deepcopy(plan.evidence),
               'conclusions': conclusions, 'external_approval': approval, 'replies': replies,
               'trust': 'Witnesses independently rechecked by this untrusted client; absence/completeness trusts admitted solver. No action authorized.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', default='http://127.0.0.1:8765')
    parser.add_argument('--tenant', default='reasoning-demo')
    parser.add_argument('--retries', type=int, choices=range(4), default=0, help='opt-in repeats of pure calls; no durable replay promise')
    args = parser.parse_args()
    for result in workflow(Client(args.url, args.tenant, retries=args.retries)):
        print(compact(result), flush=True)


if __name__ == '__main__':
    main()
