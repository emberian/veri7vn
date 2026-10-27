"""Narrow checks of retained evidence and relation mismatch review."""
import copy
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("research_dossier", ROOT / "tools/usage/research/dossier.py")
DOSSIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DOSSIER)


def row(text, **extra):
    reply = {"status": "answered", "response": text,
             "references": ["opaque-source-123", {"unknown": [1, 2]}], **extra}
    return {"id": "r12", "state": "response", "http_status": 200,
            "response": {"outcome": "completed", "reply": reply},
            "response_body_base64": "unaltered-by-review"}


class DossierTests(unittest.TestCase):
    def test_live_regression_notable_work_does_not_establish_composition(self):
        r = row("James Arnold Taylor. From the Wikidata relation store: James Arnold Taylor (Q2536187) - wrote (P800) - Star Wars (Q462). [rel-singers]")
        result = DOSSIER.annotate(r, {"acceptable_properties": ["P86"]})
        self.assertIn("property_mismatch", result["review_flags"])
        self.assertEqual(result["observed_property_ids"], ["P800"])

    def test_preserves_complete_reply_and_opaque_evidence(self):
        r = row("Mary Shelley", future_evidence={"unfamiliar": True})
        before = copy.deepcopy(r)
        result = DOSSIER.annotate(r)
        self.assertEqual(result["original_result"], before)
        self.assertEqual(r, before)
        result["original_result"]["response"]["reply"]["references"].clear()
        self.assertEqual(r, before)

    def test_replaced_response_cannot_supply_missing_property(self):
        r = row("James Arnold Taylor (P800)", provenance={"replaced_response": "John Williams (P86)"})
        result = DOSSIER.annotate(r, {"acceptable_properties": ["P86"]})
        self.assertIn("property_mismatch", result["review_flags"])

    def test_valid_property_is_only_navigation_not_certification(self):
        r = row("John Williams (Q131285), composer (P86)")
        result = DOSSIER.annotate(r, {"acceptable_properties": ["P86"]})
        self.assertNotIn("property_mismatch", result["review_flags"])
        self.assertTrue(all(n["purpose"] == "navigation_only_not_verified_support" for n in result["navigation"]))

    def test_safe_refusal_is_not_answered(self):
        result = DOSSIER.annotate(row("I cannot verify that", status="withheld"))
        self.assertEqual(result["status"], "withheld")
        self.assertIn("not_answered", result["review_flags"])

    def test_ids_need_boundaries(self):
        result = DOSSIER.annotate(row("opaqueQ123 P86suffix Q01 wd:Q47152"))
        self.assertEqual([n["identifier"] for n in result["navigation"]], ["Q47152"])


if __name__ == "__main__":
    unittest.main()
