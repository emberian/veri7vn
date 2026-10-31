"""Small independent truth fixtures; no solver, stores or builds required."""
import copy
import importlib.util
import itertools
from pathlib import Path
import unittest

SOURCE = Path(__file__).resolve().parents[2] / 'tools/usage/hosted_reasoning.py'
spec = importlib.util.spec_from_file_location('hosted_reasoning', SOURCE)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def powerset(items):
    return [set(c) for n in range(len(items) + 1) for c in itertools.combinations(items, n)]


def oracle(arguments):
    # Stable iff M is a subset-minimal model of its positive reduct. This does
    # not reuse the client's forward closure algorithm. Ten fixture atoms only.
    result = []
    for candidate in powerset(list(range(len(arguments['atoms'])))):
        reduct = [r for r in arguments['rules'] if not set(r['negative']) & candidate]
        def satisfies(model):
            return all(not set(r['positive']) <= model or r['head'] in model for r in reduct)
        if satisfies(candidate) and not any(satisfies(s) for s in powerset(sorted(candidate)) if s < candidate):
            result.append(sorted(candidate))
    return result


def envelope(operation, arguments, models):
    answers = []
    for atom in arguments['queries']:
        yes = next((i for i, v in enumerate(models) if atom in v), None)
        no = next((i for i, v in enumerate(models) if atom not in v), None)
        answers.append({'atom': atom, 'skeptical': no is None if models else None,
                        'credulous': yes is not None if models else None,
                        'true_witness': yes, 'false_witness': no})
    result = {'schema': 'oracle-logic-experimental-v1', 'operation_id': operation,
        'scope': arguments['scope'], 'status': 'consistent' if models else 'inconsistent',
        'models': models, 'answers': answers, 'enumeration_complete': operation.endswith('enumerate'),
        'completeness_trust': 'solver_trusted_no_certificate' if operation.endswith('enumerate') else 'solver_trusted_query_unsat_no_certificate',
        'witness_check': 'handwritten_gl_reduct',
        'program_identity': m.digest(m.program_text(arguments)),
        'request_identity': m.digest(m.compact({'operation': operation.split('.')[-1], **arguments}))}
    return {'outcome': 'completed', 'operation_id': operation,
            'reply': {'status': 'answered', 'operation_id': operation, 'authority': 'computation_only', 'result': result}}


class FixtureClient(m.Client):
    def __init__(self):
        super().__init__('http://unused', 'fixture')
        self.calls = []
    def transport(self, path, body=None):
        self.calls.append((path, copy.deepcopy(body)))
        if path.startswith('/operations/'):
            return {'id': path.split('/')[-1], 'availability': 'live_direct'}
        return envelope(body['operation_id'], body['arguments'], oracle(body['arguments']))


class HostedReasoningTests(unittest.TestCase):
    def test_complete_revision_workflow(self):
        client = FixtureClient()
        rows = list(m.workflow(client))
        self.assertEqual(len(client.calls), 12)
        self.assertEqual(len({r['scope']['snapshot'] for r in rows}), 5)
        # Hand-derived alternatives, independent of truth calculation implementation.
        expected = [[[0, 2, 3, 5], [0, 2, 4, 5]], [[0, 1, 7]], [],
                    [[0, 2, 3, 5, 6], [0, 2, 4, 5, 6]], [[6]]]
        for row, models in zip(rows, expected):
            self.assertEqual(sorted(row['replies']['logic.enumerate']['models']), models)
        self.assertEqual(rows[0]['conclusions']['candidate'], 'skeptical')
        self.assertEqual(rows[0]['conclusions']['reuse_cache'], 'credulous')
        self.assertEqual(rows[0]['external_approval'], 'unknown')
        self.assertEqual(rows[1]['conclusions']['candidate'], 'false-in-local-program')
        self.assertEqual(rows[2]['conclusions']['candidate'], 'inconsistent')
        self.assertFalse(rows[3]['evidence']['scanner/alert']['active'])
        self.assertEqual(rows[4]['conclusions']['candidate'], 'false-in-local-program')

    def test_reject_absent_operation(self):
        client = FixtureClient()
        client.transport = lambda *args: {'id': 'logic.query', 'availability': 'unavailable'}
        with self.assertRaises(m.ContractError):
            list(m.workflow(client))

    def test_invalid_replies_are_rejected(self):
        plan = m.BuildPlan('fixture')
        plan.revise([('assert', 'dep', 'dependency_ready', 'fixture')])
        args = plan.snapshot()
        good = envelope('logic.query', args, [[0, 2, 3, 5], [0, 2, 4, 5]])
        m.validate_reply('logic.query', args, good)
        def changes(value):
            result = value['reply']['result']
            yield result['scope'], 'tenant', 'another-tenant'
            yield result['scope'], 'snapshot', 'stale'
            yield result, 'program_identity', '0' * 64
            yield result, 'request_identity', '0' * 64
            yield result, 'models', [[0, 2, 3]]  # missing supported candidate
            yield result, 'answers', []
            yield result['answers'][0], 'skeptical', 'true'
            yield result['answers'][0], 'true_witness', 99
            yield result['answers'][3], 'skeptical', True  # false in another witness
        # Derive each mutation from a separate original envelope.
        for index in range(9):
            bad = copy.deepcopy(good)
            target, key, value = list(changes(bad))[index]
            target[key] = value
            with self.subTest(index=index), self.assertRaises(m.ContractError):
                m.validate_reply('logic.query', args, bad)

    def test_unknown_is_not_inconsistent_or_false(self):
        self.assertEqual(m.classification({'skeptical': None, 'credulous': None}, 'inconclusive'), 'unknown')
        self.assertEqual(m.classification({'skeptical': None, 'credulous': None}, 'inconsistent'), 'inconsistent')
        self.assertEqual(m.classification({'skeptical': False, 'credulous': False}, 'consistent'), 'false-in-local-program')

    def test_atomic_revision_and_no_token_reuse(self):
        plan = m.BuildPlan('fixture')
        before = plan.snapshot()
        with self.assertRaises(m.ContractError):
            plan.revise([('assert', 'dep', 'dependency_ready', 'fixture'), ('withdraw', 'missing')])
        self.assertEqual(plan.snapshot(), before)
        plan.revise([('assert', 'dep', 'dependency_ready', 'fixture')])
        plan.revise([('withdraw', 'dep')])
        with self.assertRaises(m.ContractError):
            plan.revise([('assert', 'dep', 'dependency_ready', 'fixture')])


if __name__ == '__main__':
    unittest.main()
