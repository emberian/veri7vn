"""Untrusted adapter contracts with manufactured replies; no panel scores."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools/appliance"))
from oracle_components.native_bio import NativeBioOperations, search_identities
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



class CollectionAdapter(unittest.TestCase):
    def setUp(self):
        import copy
        self.catalog = copy.deepcopy(CATALOG)
        self.catalog["operations"].append({"id": "bio.search_collection"})
        self.catalog["sequence_collection"] = {"schema": "oracle-sequence-collection-v1"}
        self.arguments = {"collection": {"schema": "oracle-sequence-collection-v1", "records": [{"label": "sample", "sequence": "TTTCGTAA"}]},
                          "patterns": [{"label": "fragment", "sequence": "ACG"}], "page_size": 1}

    def result(self):
        collection, request = search_identities(self.arguments)
        return {"schema": "oracle-sequence-search-v1", "collection_sha256": collection, "request_sha256": request,
                "coverage_start": None, "complete": True, "next_cursor": None,
                "hits": [{"record_index": 0, "record_label": "sample", "pattern_index": 0, "pattern_label": "fragment",
                          "strand": "reverse", "start": 3, "end": 6, "matched_sequence": "CGT"}]}

    def test_search_schema_and_positive_original_coordinate_replay(self):
        adapter = NativeBioOperations(self.catalog, lambda _: self.result(), "bio-test")
        descriptor = next(d for d in adapter.catalog() if d["id"] == "bio.search_collection")
        validate(self.arguments, descriptor["input_schema"])
        self.assertEqual(adapter.invoke("bio.search_collection", self.arguments)["status"], "answered")
        for bad in ("N", "AC U", ""):
            import copy
            args = copy.deepcopy(self.arguments); args["patterns"][0]["sequence"] = bad
            with self.assertRaises(OperationError):
                validate(args, descriptor["input_schema"])

    def test_final_newline_is_rejected_by_explicit_fullmatch_before_native_call(self):
        import copy
        arguments = copy.deepcopy(self.arguments)
        arguments["patterns"][0]["sequence"] = "ACGT\n"
        adapter = NativeBioOperations(self.catalog, lambda _: self.fail("must not call native"), "bio-test")
        self.assertEqual(adapter.invoke("bio.search_collection", arguments)["reason"], "invalid_arguments")

    def test_wrong_source_identity_coordinates_orientation_and_completion_withhold(self):
        changes = [lambda r: r.update(collection_sha256="0"*64),
                   lambda r: r.update(request_sha256="0"*64),
                   lambda r: r["hits"][0].update(start=2),
                   lambda r: r["hits"][0].update(strand="forward"),
                   lambda r: r["hits"][0].update(record_index=True),
                   lambda r: r["hits"][0].update(pattern_label="wrong source"),
                   lambda r: r["hits"][0].update(matched_sequence="ACG"),
                   lambda r: r.update(complete=False, next_cursor=None),
                   lambda r: r.update(next_cursor={"request_sha256":"0"*64})]
        for change in changes:
            result=self.result(); change(result)
            adapter=NativeBioOperations(self.catalog, lambda _: result, "bio-test")
            self.assertEqual(adapter.invoke("bio.search_collection",self.arguments)["status"], "withheld")


if __name__ == "__main__":
    unittest.main()
