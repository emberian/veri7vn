"""Untrusted adapter contracts with manufactured replies; no panel scores."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools/appliance"))
from oracle_components.native_bio import NativeBioOperations
from operations import validate, OperationError

CATALOG = {"schema": "oracle-bio-experimental-v1", "operations": [{"id": "bio.align_pairwise"}],
           "limits": {"request_bytes": 262144, "sequence_bases": 4096, "dp_cells": 1048576,
                      "working_bytes_estimate": 16777216}}
ARGUMENTS = {"query": "ACGT", "reference": "ACGT", "mode": "global",
             "scoring": {"match_score": 2, "mismatch_score": -1, "gap_open": -3, "gap_extend": -1}}


def reply():
    return {"schema": CATALOG["schema"], "mode": "global", "ambiguity": "reject",
            "query_length": 4, "reference_length": 4,
            "candidate": {"score": 8, "query_start": 0, "query_end": 4, "reference_start": 0,
                          "reference_end": 4, "operations": ["match"] * 4},
            "checks": {"replayed_score": 8, "independently_computed_optimal_score": 8}}


class BioAdapter(unittest.TestCase):
    def test_fixed_dispatch_and_supplied_scoring(self):
        calls = []
        adapter = NativeBioOperations(CATALOG, lambda request: calls.append(request) or reply(), "artifact:bio")
        descriptor = adapter.catalog()[0]
        validate(ARGUMENTS, descriptor["input_schema"])
        result = adapter.invoke(descriptor["id"], ARGUMENTS)
        self.assertEqual(calls, [{"operation": "bio.align_pairwise", "arguments": ARGUMENTS}])
        self.assertEqual(result["status"], "answered")
        self.assertEqual(result["authority"], "computation_only")
        descriptor["native_limits"]["sequence_bases"] = 1
        self.assertEqual(adapter.catalog()[0]["native_limits"]["sequence_bases"], 4096)

    def test_structural_refusals_before_native_work(self):
        adapter = NativeBioOperations(CATALOG, lambda _: self.fail("must not execute"), "a")
        schema = adapter.catalog()[0]["input_schema"]
        invalid = [{**ARGUMENTS, "module": "/tmp/code"}, {**ARGUMENTS, "mode": "banded"},
                   {**ARGUMENTS, "ambiguity": "probabilistic"}, {**ARGUMENTS, "query": "A" * 4097},
                   {**ARGUMENTS, "reference": "AC U"},
                   {**ARGUMENTS, "scoring": {**ARGUMENTS["scoring"], "match_score": True}},
                   {**ARGUMENTS, "scoring": {**ARGUMENTS["scoring"], "gap_open": 1}}]
        for arguments in invalid:
            with self.subTest(arguments=arguments), self.assertRaises(OperationError):
                validate(arguments, schema)

    def test_disagreed_scores_and_coordinates_withhold(self):
        for mutate in (lambda r: r["checks"].update(replayed_score=7),
                       lambda r: r["checks"].update(independently_computed_optimal_score=9),
                       lambda r: r["candidate"].update(reference_end=5),
                       lambda r: r["candidate"].update(operations=["clip"])):
            result = reply()
            mutate(result)
            adapter = NativeBioOperations(CATALOG, lambda _: result, "a")
            self.assertEqual(adapter.invoke("bio.align_pairwise", ARGUMENTS)["reason"], "native_reply_invalid")

    def test_absent_operation_or_bad_catalog_is_not_live(self):
        for catalog in ({**CATALOG, "operations": []}, {**CATALOG, "schema": "other"},
                        {**CATALOG, "limits": {**CATALOG["limits"], "dp_cells": True}}):
            with self.assertRaises(ValueError):
                NativeBioOperations(catalog, lambda _: {}, "a")


if __name__ == "__main__":
    unittest.main()
