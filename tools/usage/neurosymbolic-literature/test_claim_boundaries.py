"""UNTRUSTED finite illustrations of different empirical and symbolic claims.

No real model, learned embedding, mechanistic interpretation or Oracle answerer
is evaluated here. Hand-written functions make the distinctions executable.
"""
from dataclasses import dataclass, replace
from itertools import product
import unittest


@dataclass(frozen=True)
class Request:
    property: int
    subject: str
    kind: str


def typed(request):
    return (request.property in {50, 86} and request.subject in {"Q1", "Q2"}
            and request.kind in {"book", "song"})


def encode(hidden_quantity, nuisance):
    return (hidden_quantity + nuisance, nuisance)


def readout(state):
    return state[0] - state[1]


def base_output(state):
    return state[1]


def swap_quantity(base, source):
    return encode(readout(source), base[1])


class ClaimBoundaries(unittest.TestCase):
    def test_useful_readout_need_not_control_base_output(self):
        # Includes negative quantities and nuisance values outside a smaller
        # nominal range. This checks a specified decoder, not learned OOD skill.
        states = [encode(q, n) for q, n in product(range(-3, 4), repeat=2)]
        self.assertEqual(len(states), 49)
        for q, n in product(range(-3, 4), repeat=2):
            self.assertEqual(readout(encode(q, n)), q)
        for base, source in product(states, repeat=2):
            changed = swap_quantity(base, source)
            self.assertEqual(readout(changed), readout(source))
            self.assertEqual(base_output(changed), base_output(base))

    def test_observational_probe_does_not_establish_decoder_use(self):
        # Both coordinates predict q perfectly on this correlated support.
        for q in range(4):
            self.assertEqual(q, (q, q)[0])
            self.assertEqual(q, (q, q)[1])
        # The base decoder uses the second coordinate, so changing the first
        # does not implement the high-level counterfactual q := source.q.
        counterexamples = 0
        for base_q, source_q in product(range(4), repeat=2):
            changed = (source_q, base_q)
            counterexamples += base_output(changed) != source_q
        self.assertEqual(counterexamples, 12)

    def test_type_correct_program_can_misinterpret_question(self):
        intended = Request(86, "Q1", "song")
        wrong_relation = replace(intended, property=50)
        self.assertTrue(typed(intended))
        self.assertTrue(typed(wrong_relation))
        self.assertNotEqual(intended, wrong_relation)

    def test_unknown_and_false_are_distinct(self):
        evidence = {"Q1": True, "Q2": None}
        definitely_eligible = [q for q, value in evidence.items() if value is True]
        possible_eligible = [q for q, value in evidence.items() if value is not False]
        self.assertEqual(definitely_eligible, ["Q1"])
        self.assertEqual(possible_eligible, ["Q1", "Q2"])

    def test_readout_kind_cannot_establish_source_evidence(self):
        empirical_prediction = {"kind": "estimated", "value": 1800}
        sourced_fact = {"kind": "sourced", "value": 1800, "statement": "S1"}
        self.assertEqual(empirical_prediction["value"], sourced_fact["value"])
        self.assertNotEqual(empirical_prediction["kind"], sourced_fact["kind"])
        self.assertNotIn("statement", empirical_prediction)


if __name__ == "__main__":
    unittest.main(verbosity=2)
