"""Boundary checks for the untrusted independent typed-equation replay."""
import copy
import unittest

from runtime_contract import enforce_reply_evidence


def rat(n, d=1):
    return {"num": str(n), "den": str(d)}


def const(n, d=1):
    return {"op": "const", "value": rat(n, d)}


def var():
    return {"op": "var", "name": "x"}


def op(name, left, right):
    return {"op": name, "left": left, "right": right}


def fixture(classification="unique"):
    left = op("add", op("mul", const(2), var()), const(3))
    if classification == "unique":
        right, coeffs, root = const(0), (0, 0), rat(-3, 2)
        text = "x = -3/2."
    elif classification == "all":
        right, coeffs, root = op("add", const(3), op("mul", var(), const(2))), (2, 3), None
        text = "Every rational value of x satisfies this equation."
    else:
        right, coeffs, root = op("add", op("mul", var(), const(2)), const(4)), (2, 4), None
        text = "No rational value of x satisfies this equation."
    reply = {"status": "answered", "kind": "affine_equation", "path": "algebra:solved",
             "response": "[ev:derived] " + text,
             "provenance": {"taken": True, "evidence": {"checked_computation": {
                 "schema_version": 1, "kind": "affine_equation", "checker": "Mathkernel.check_affine",
                 "accepted": True, "assumptions": ["The typed equation represents the requested equation."],
                 "inputs": {"variable": "x", "left": left, "right": right},
                 "result": {"classification": classification, "root": root,
                            "left_affine": {"coefficient": rat(2), "constant": rat(3)},
                            "right_affine": {"coefficient": rat(coeffs[0]), "constant": rat(coeffs[1])}}}}}}
    if classification == "unique":
        reply["value"] = "-3/2"
    return reply


class AffineEvidenceTests(unittest.TestCase):
    def assert_rejected(self, reply):
        actual = enforce_reply_evidence(reply)
        self.assertEqual(actual["status"], "withheld", actual)
        self.assertTrue(actual["provenance"]["taken"])
        self.assertNotIn("value", actual)
        self.assertEqual(actual["provenance"]["evidence"]["consumer_validation"]["status"], "rejected")

    def test_three_solution_classes_replayed_from_original_ast(self):
        for classification in ("unique", "all", "none"):
            with self.subTest(classification=classification):
                reply = fixture(classification)
                actual = enforce_reply_evidence(reply)
                self.assertEqual(actual["status"], "answered")
                self.assertEqual(actual["provenance"]["evidence"]["consumer_validation"]["status"], "consistent")
                self.assertNotIn("consumer_validation", reply["provenance"]["evidence"])

    def test_selected_variable_binds_ast_and_each_solution_class(self):
        def rename(node, name):
            if node['op']=='var':node['name']=name
            for key in ('left','right','arg'):
                if key in node:rename(node[key],name)
        for name in ('t','e','z'):
            for classification in ('unique','all','none'):
                reply=fixture(classification)
                inputs=reply['provenance']['evidence']['checked_computation']['inputs']
                inputs['variable']=name
                rename(inputs['left'],name);rename(inputs['right'],name)
                reply['response']=reply['response'].replace('x',name)
                with self.subTest(name=name,classification=classification):
                    self.assertEqual(enforce_reply_evidence(reply)['status'],'answered')
                    wrong=copy.deepcopy(reply)
                    wrong['response']=wrong['response'].replace(f'] {name} =','] x =').replace(f'value of {name} ', 'value of x ')
                    self.assert_rejected(wrong)

    def test_target_mismatch_and_cancelled_foreign_variables_rejected(self):
        for change in ('target_only','foreign_cancelled','foreign_zero'):
            reply=fixture();inputs=reply['provenance']['evidence']['checked_computation']['inputs']
            if change=='target_only':inputs['variable']='t'
            else:
                y={'op':'var','name':'y'}
                zero=op('sub',y,copy.deepcopy(y)) if change=='foreign_cancelled' else op('mul',const(0),y)
                inputs['left']=op('add',inputs['left'],zero)
            with self.subTest(change=change):self.assert_rejected(reply)
        for name in ('','xy','X','α',True,None):
            reply=fixture();reply['provenance']['evidence']['checked_computation']['inputs']['variable']=name
            with self.subTest(name=name):self.assert_rejected(reply)

    def test_constant_division_and_negation(self):
        reply = fixture()
        packet = reply["provenance"]["evidence"]["checked_computation"]
        packet["inputs"]["left"] = op("add", op("div", var(), const(1, 2)),
                                       {"op": "neg", "arg": const(-3)})
        self.assertEqual(enforce_reply_evidence(reply)["status"], "answered")

    def test_affine_packets_are_required_but_legacy_replies_are_unchanged(self):
        for classification in ("unique", "all", "none"):
            for field in ("checked_computation", "evidence", "provenance"):
                reply = fixture(classification)
                if field == "checked_computation": del reply["provenance"]["evidence"][field]
                elif field == "evidence": del reply["provenance"][field]
                else: del reply[field]
                with self.subTest(classification=classification, field=field): self.assert_rejected(reply)
        legacy = {"status": "answered", "kind": "legacy", "response": "2"}
        self.assertIs(enforce_reply_evidence(legacy), legacy)

    def test_independent_replay_rejects_forged_claims(self):
        for field in ("input", "normalization", "root", "classification", "accepted", "value", "response"):
            reply = fixture()
            packet = reply["provenance"]["evidence"]["checked_computation"]
            if field == "input": packet["inputs"]["left"]["right"] = const(4)
            elif field == "normalization": packet["result"]["left_affine"]["coefficient"] = rat(3)
            elif field == "root": packet["result"]["root"] = rat(3, 2)
            elif field == "classification": packet["result"]["classification"] = "all"
            elif field == "accepted": packet["accepted"] = False
            elif field == "value": reply["value"] = "-1.5"
            else: reply["response"] = "[ev:derived] x = 3/2."
            with self.subTest(field=field): self.assert_rejected(reply)

    def test_unsupported_or_undefined_ast_is_not_verified(self):
        nodes = [op("mul", var(), var()), op("div", const(1), var()),
                 op("div", var(), const(0)), {"op": "var", "name": "y"},
                 {"op": "power", "left": var(), "right": const(2)},
                 {"op": "const", "value": rat(1, 0)}, {"op": []}, "malformed"]
        for node in nodes:
            reply = fixture()
            reply["provenance"]["evidence"]["checked_computation"]["inputs"]["left"] = node
            with self.subTest(node=node): self.assert_rejected(reply)

    def test_no_single_root_for_all_or_no_solutions(self):
        for classification in ("all", "none"):
            for field in ("root", "value", "response"):
                reply = fixture(classification)
                if field == "root":
                    reply["provenance"]["evidence"]["checked_computation"]["result"]["root"] = rat(0)
                elif field == "value": reply["value"] = "0"
                else: reply["response"] = "[ev:derived] x = 0."
                with self.subTest(classification=classification, field=field): self.assert_rejected(reply)

    def test_work_bounds_and_unexpected_fields(self):
        deep = var()
        for _ in range(33): deep = {"op": "neg", "arg": deep}
        wide = var()
        for _ in range(7): wide = op("add", copy.deepcopy(wide), copy.deepcopy(wide))
        for node in (deep, wide, const("1" * 257), {"op": "var", "name": "x", "ignored": 1}):
            reply = fixture()
            reply["provenance"]["evidence"]["checked_computation"]["inputs"]["left"] = node
            self.assert_rejected(reply)


if __name__ == "__main__":
    unittest.main()
