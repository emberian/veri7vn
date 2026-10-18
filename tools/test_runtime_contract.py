"""Boundary tests for family ownership and acceptance shared by both consumers."""
import json
import re
import tempfile
import unittest
from pathlib import Path

from runtime_contract import ContractError, acceptance, validate_capabilities, enforce_reply_evidence


class RuntimeContractTests(unittest.TestCase):
    def setUp(self):
        scratch = Path(__file__).resolve().parents[1] / "var/runtime-contract-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        self.tmp = tempfile.TemporaryDirectory(dir=scratch)
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name)
        self.registry = {"schema_version": 1, "families": [
            {"family": "example", "role": "specialist", "binary": "var/example/bin/example",
             "build": "src/extract/example/build.sh", "specialists": ["one"], "specialist_flag": True}]}
        self.cap = {"schema_version": 1, "family": "example", "specialists": {
            "one": {"accept": {"kinds": ["new"], "declines_in_domain": ["impossible"]},
                    "context_regex_additions": [r"new subject"],
                    "evidence": {"computation": "Exact arithmetic on a parsed request",
                                 "untrusted": ["The natural-language parser"]}}}}
        self.write("src/extract/families.json", self.registry)
        self.write("src/extract/example/capabilities.json", self.cap)
        self.write("upstream/root/specialists/one/manifest.json", {"accept": {
            "kinds": ["old"], "declines_in_domain": ["underspecified"], "context_regex": "old subject",
            "kept_field": 17}})

    def write(self, name, value):
        p = self.repo / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(value))

    def test_extensions_preserve_original_rules(self):
        result = acceptance(self.repo, self.repo / "upstream", "one")
        self.assertEqual(result["kinds"], ["old", "new"])
        self.assertEqual(result["declines_in_domain"], ["underspecified", "impossible"])
        self.assertEqual(result["context_regex"], "(?:old subject)|(?:new subject)")
        self.assertEqual(result["kept_field"], 17)
        self.assertNotIn("evidence", result)

    def test_only_inspected_broken_word_boundaries_are_repaired(self):
        from runtime_contract import _BROKEN_CONTEXTS
        self.registry["families"][0]["specialists"] = ["decay"]
        self.write("src/extract/families.json", self.registry)
        self.write("src/extract/example/capabilities.json", {
            "schema_version": 1, "family": "example", "specialists": {}})
        def accepted(pattern):
            self.write("upstream/root/specialists/decay/manifest.json", {"accept": {
                "kinds": [], "declines_in_domain": ["impossible"], "context_regex": pattern}})
            return acceptance(self.repo, self.repo / "upstream", "decay")["context_regex"]
        repaired = accepted(_BROKEN_CONTEXTS["decay"])
        self.assertTrue(re.search(repaired, "The isotope has negative activity."))
        self.assertFalse(re.search(repaired, "the word yisotopeology"))
        self.assertNotIn("\b", repaired)
        valid = r"\bdecay\b"
        self.assertEqual(accepted(valid), valid)
        changed = "\bchanged upstream\b"
        self.assertEqual(accepted(changed), changed)

    def test_cross_family_extension_rejected(self):
        self.cap["specialists"]["foreign"] = {}
        self.write("src/extract/example/capabilities.json", self.cap)
        with self.assertRaisesRegex(ContractError, "not owned"):
            validate_capabilities(self.repo)

    def test_unknown_accept_field_rejected(self):
        self.cap["specialists"]["one"]["accept"]["accept_all"] = True
        self.write("src/extract/example/capabilities.json", self.cap)
        with self.assertRaisesRegex(ContractError, "unknown fields"):
            validate_capabilities(self.repo)

    def test_unknown_specialist_and_invalid_regex_rejected(self):
        with self.assertRaisesRegex(ContractError, "unknown specialist"):
            acceptance(self.repo, self.repo / "upstream", "foreign")
        self.cap["specialists"]["one"]["context_regex_additions"] = ["["]
        self.write("src/extract/example/capabilities.json", self.cap)
        with self.assertRaisesRegex(ContractError, "invalid context"):
            validate_capabilities(self.repo)

    def test_specialist_owner_and_role_are_explicit(self):
        self.registry["families"][0]["role"] = "guard"
        self.write("src/extract/families.json", self.registry)
        with self.assertRaisesRegex(ContractError, "only specialist"):
            validate_capabilities(self.repo)

    def test_duplicate_ownership_rejected(self):
        self.registry["families"].append(dict(self.registry["families"][0], family="other"))
        self.write("src/extract/families.json", self.registry)
        with self.assertRaisesRegex(ContractError, "multiply owned"):
            validate_capabilities(self.repo)


class ComputationEvidenceTests(unittest.TestCase):
    def reply(self):
        def rat(n, d=1):
            return {"num": str(n), "den": str(d)}
        return {"status": "answered", "kind": "discount_tax", "value": 64.80,
                "path": "specialist:retail>discount_tax",
                "response": "The final price is $64.80 ($80.00 less 25% = $60.00, plus 8% tax = $4.80).",
                "provenance": {"taken": True, "evidence": {"checked_computation": {
                    "schema_version": 1, "kind": "discount_tax", "checker": "Finance.check_discount_tax",
                    "accepted": True, "inputs": {"price": rat(80), "discounts_percent": [rat(25)],
                                                  "tax_rate": rat(2, 25)}, "result": rat(324, 5)}}}}

    def packet(self, reply):
        return reply["provenance"]["evidence"]["checked_computation"]

    def test_consistent_packet_explains_actual_amount(self):
        result = enforce_reply_evidence(self.reply())
        validation = result["provenance"]["evidence"]["consumer_validation"]
        self.assertEqual(result["status"], "answered")
        self.assertEqual(validation["status"], "consistent")
        self.assertIn("$64.80", validation["explanation"])
        self.assertIn("not formally verified", validation["boundary"])

    def test_mutations_cannot_rely_on_accepted_label(self):
        for mutation in ("result", "price", "negative_tax", "value", "text", "checker"):
            with self.subTest(mutation=mutation):
                reply = self.reply()
                packet = self.packet(reply)
                if mutation == "result": packet["result"]["num"] = "325"
                if mutation == "price": packet["inputs"]["price"]["num"] = "81"
                if mutation == "negative_tax": packet["inputs"]["tax_rate"]["num"] = "-2"
                if mutation == "value": reply["value"] = 64.81
                if mutation == "text": reply["response"] = "The final price is $65.00."
                if mutation == "checker": packet["checker"] = "invented"
                result = enforce_reply_evidence(reply)
                self.assertEqual(result["status"], "withheld")
                self.assertEqual(result["kind"], "discount_tax")
                self.assertTrue(result["provenance"]["taken"])
                self.assertEqual(result["response"], "")
                self.assertNotIn("value", result)

    def test_numeric_text_is_bounded_and_money_format_unambiguous(self):
        for bad in ("64.8e999999999", "64.8e-999999999", "NaN", "Infinity"):
            reply = self.reply()
            reply["value"] = bad
            self.assertEqual(enforce_reply_evidence(reply)["status"], "withheld")
        for text in ("The final price is $6,4.80.", "The final price is $64.80.5."):
            reply = self.reply()
            reply["response"] = text
            self.assertEqual(enforce_reply_evidence(reply)["status"], "withheld")
        reply = self.reply()
        reply["value"] = "6.48e1"
        self.assertEqual(enforce_reply_evidence(reply)["status"], "answered")

    def test_half_cent_rounding_and_stacked_discounts(self):
        reply = self.reply()
        packet = self.packet(reply)
        packet["inputs"] = {"price": {"num": "1", "den": "1"},
                            "discounts_percent": [{"num": "25", "den": "1"}, {"num": "30", "den": "1"}],
                            "tax_rate": {"num": "0", "den": "1"}}
        packet["result"] = {"num": "21", "den": "40"}
        reply.update(value=0.53, response="The final price is $0.53.")
        self.assertEqual(enforce_reply_evidence(reply)["status"], "answered")

    def test_no_packet_makes_no_claim(self):
        reply = {"status": "answered", "value": 3}
        self.assertIs(enforce_reply_evidence(reply), reply)

    def test_malformed_present_evidence_is_not_absence(self):
        malformed = [
            {"status": "answered", "provenance": "malformed"},
            {"status": "answered", "provenance": []},
            {"status": "answered", "provenance": {"evidence": "malformed"}},
            {"status": "answered", "provenance": {"evidence": {"checked_computation": None}}},
            ["not", "an", "object"],
        ]
        for reply in malformed:
            with self.subTest(reply=reply):
                result = enforce_reply_evidence(reply)
                self.assertEqual(result["status"], "withheld")
                self.assertEqual(result["provenance"]["evidence"]["consumer_validation"]["status"], "rejected")


if __name__ == "__main__":
    unittest.main()
