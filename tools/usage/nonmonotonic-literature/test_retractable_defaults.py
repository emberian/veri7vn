"""Counterexample-driven checks for the untrusted finite research model."""
from itertools import product
import unittest

from retractable_defaults import Default, Fact, Scope, View


SCOPE = Scope("alice", "kg-v1", 20)
RULES = [Default("birds-usually-fly", "bird:t", "flies:t", ("abnormal:t",)),
         Default("flight-suggests-reachable", "flies:t", "reachable:t")]


def fact(id, atom, positive=True, **kw):
    return Fact(id, "alice", "kg-v1", atom, positive, **kw)


class ResearchChecks(unittest.TestCase):
    def test_default_is_not_a_fact_and_unknown_is_not_false(self):
        v = View(SCOPE, [fact("bird", "bird:t")])
        r = v.defaults(RULES)
        self.assertEqual(v.evidence("flies:t"), "unknown")
        self.assertEqual(v.evidence("abnormal:t"), "unknown")
        self.assertIn("flies:t", r)
        self.assertEqual(r["reachable:t"].support_ids, {"bird"})
        self.assertEqual(r["reachable:t"].rule_ids, {r.id for r in RULES})
        self.assertIn(("flies:t", False), r["reachable:t"].absence_guards)

    def test_new_exception_retracts_every_default_dependent(self):
        before = View(SCOPE, [fact("bird", "bird:t")])
        old = before.defaults(RULES)["reachable:t"]
        after = View(SCOPE, before.facts + [fact("injury", "abnormal:t")])
        self.assertEqual(after.defaults(RULES), {})
        self.assertFalse(after.receipt_is_current(old))
        restored = View(SCOPE, [fact("bird", "bird:t")])
        self.assertIn("reachable:t", restored.defaults(RULES))

    def test_explicit_negative_and_conflict_do_not_explode(self):
        base = [fact("bird", "bird:t"), fact("no-flight", "flies:t", False)]
        v = View(SCOPE, base)
        self.assertEqual(v.evidence("flies:t"), "false")
        self.assertEqual(v.defaults(RULES), {})
        v = View(SCOPE, base + [fact("flight", "flies:t")])
        self.assertEqual(v.evidence("flies:t"), "conflict")
        self.assertEqual(v.evidence("arbitrary-unrelated-claim"), "unknown")
        self.assertEqual(v.defaults(RULES), {})
        # A contradictory assertion does not erase independent evidence.
        self.assertEqual(v.evidence("bird:t"), "true")

    def test_retraction_keeps_independent_source_support(self):
        records = [fact("source-1", "bird:t"), fact("source-2", "bird:t")]
        both = View(SCOPE, records)
        old = both.defaults(RULES)["flies:t"]
        one = View(SCOPE, records[1:])
        self.assertEqual(one.defaults(RULES)["flies:t"].support_ids, {"source-2"})
        self.assertFalse(one.receipt_is_current(old))
        self.assertEqual(View(SCOPE, []).defaults(RULES), {})

    def test_scope_and_time_are_not_interchangeable(self):
        records = [fact("bird", "bird:t"), fact("old-injury", "abnormal:t", end=20),
                   Fact("other-tenant", "bob", "kg-v1", "flies:t", False),
                   Fact("other-snapshot", "alice", "kg-v2", "flies:t", False)]
        now = View(SCOPE, records)
        self.assertIn("flies:t", now.defaults(RULES))
        past = View(Scope("alice", "kg-v1", 19), records)
        self.assertEqual(past.defaults(RULES), {})
        self.assertFalse(past.receipt_is_current(now.defaults(RULES)["flies:t"]))

    def test_missing_gender_cannot_eliminate_alternative(self):
        v = View(SCOPE, [fact("known", "eligible:102")])
        candidates = ["eligible:102", "eligible:103"]
        # A default that calls 102 eligible still cannot close the candidate set.
        self.assertIsNone(v.unique_source_candidate(candidates, covered=True))
        v = View(SCOPE, v.facts + [fact("other-known", "eligible:103")])
        self.assertIsNone(v.unique_source_candidate(candidates, covered=True))
        v = View(SCOPE, [fact("known", "eligible:102"),
                         fact("explicit-exclusion", "eligible:103", False)])
        self.assertEqual(v.unique_source_candidate(candidates, covered=True), "eligible:102")
        self.assertIsNone(v.unique_source_candidate(candidates, covered=False))

    def test_every_finite_consistent_completion_agrees_with_unique_answer(self):
        checked = 0
        for n in range(5):
            candidates = [f"eligible:{i}" for i in range(n)]
            for statuses in product(("unknown", "true", "false", "conflict"), repeat=n):
                facts = []
                for atom, status in zip(candidates, statuses):
                    for positive, include in [(True, status in ("true", "conflict")),
                                              (False, status in ("false", "conflict"))]:
                        if include:
                            facts.append(fact(f"{atom}:{positive}", atom, positive))
                view = View(SCOPE, facts)
                chosen = view.unique_source_candidate(candidates, covered=True)
                if "conflict" in statuses:
                    self.assertIsNone(chosen)
                else:
                    unknowns = [i for i, s in enumerate(statuses) if s == "unknown"]
                    singleton_worlds = []
                    for values in product((False, True), repeat=len(unknowns)):
                        world = {a for a, s in zip(candidates, statuses) if s == "true"}
                        world |= {candidates[i] for i, val in zip(unknowns, values) if val}
                        singleton_worlds.append(world)
                    expected = next(iter(singleton_worlds[0])) if singleton_worlds and len(singleton_worlds[0]) == 1 and all(w == singleton_worlds[0] for w in singleton_worlds) else None
                    self.assertEqual(chosen, expected)
                checked += 1
        self.assertEqual(checked, 341)

    def test_recursive_defaults_are_rejected_instead_of_picking_a_model(self):
        with self.assertRaisesRegex(ValueError, "recursive"):
            View(SCOPE, []).defaults([Default("a", "b", "a"), Default("b", "a", "b")])


if __name__ == "__main__":
    unittest.main()
