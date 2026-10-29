"""Untrusted supplied-DNA adapter; native checks establish only alignment scores.

The host supplies a fixed catalog and call closure. This module never imports a
caller-selected extension and infers no homology or biological significance.
"""
from __future__ import annotations
from .native_science import NativeStructuredOperations, obj, string, positive_limits


class NativeBioOperations(NativeStructuredOperations):
    def __init__(self, catalog, call, identity):
        super().__init__(catalog, call, identity)
        limits = positive_limits(catalog, ("request_bytes", "sequence_bases", "dp_cells", "working_bytes_estimate"))
        operations = catalog.get("operations")
        if (catalog.get("schema") != "oracle-bio-experimental-v1" or not isinstance(operations, list)
                or not any(isinstance(row, dict) and row.get("id") == "bio.align_pairwise" for row in operations)):
            raise ValueError("unsupported bio catalog")
        sequence = {**string(limits["sequence_bases"]), "pattern": "^[ACGTRYSWKMBDHVNacgtryswkmbdhvn]+$"}
        integer = lambda lo, hi: {"type": "integer", "minimum": lo, "maximum": hi}
        scoring = obj({"match_score": integer(1, 1000), "mismatch_score": integer(-1000, 0),
                       "gap_open": integer(-1000, -1), "gap_extend": integer(-1000, -1)})
        schema = obj({"query": sequence, "reference": sequence,
                      "mode": {"type": "string", "enum": ["global", "local", "query_global"]},
                      "scoring": scoring, "ambiguity": {"type": "string", "enum": ["reject", "always_mismatch"]}},
                     ["query", "reference", "mode", "scoring"])
        self.add("bio.align_pairwise", schema,
                 "Align two supplied DNA strings with explicit affine-gap scoring, then independently replay the path and recompute the optimal score.",
                 {"query": "ACGT", "reference": "ACGT", "mode": "global",
                  "scoring": {"match_score": 2, "mismatch_score": -1, "gap_open": -3, "gap_extend": -1}},
                 ["Gap run length k scores gap_open + (k-1)*gap_extend; require gap_open <= gap_extend. One optimal path is returned; tied paths need not be unique.",
                  "Global consumes both sequences; local may return an empty zero-score path; query_global consumes the entire query with free reference-end clipping.",
                  "DNA letters only, case insensitive; no U, whitespace, gaps or FASTA. Ambiguity defaults to reject. With always_mismatch every non-ACGT letter scores as mismatch, including N versus N.",
                  "Coordinates are zero-based half-open in supplied forward orientation; insertion consumes query and deletion consumes reference. No reverse-complement search, homology, variant interpretation, diagnostic or design claim.",
                  "Native admission checks sequence lengths, DP cells, estimated memory, mode, scoring and ambiguity before alignment allocation. Memory estimate excludes allocator metadata and process RSS; native alignment is not interruptible."])
        self.declarations["bio.align_pairwise"]["output_schema"]["anyOf"][0]["properties"]["result"]["description"] = (
            "Complete native candidate path, supplied scoring/mode, coordinates and independent score checks; no biological interpretation.")

    def interpret(self, operation, result):
        candidate, checks = result.get("candidate"), result.get("checks")
        if (result.get("schema") != self.native_catalog["schema"] or not isinstance(candidate, dict)
                or not isinstance(checks, dict) or type(candidate.get("score")) is not int
                or type(checks.get("replayed_score")) is not int
                or type(checks.get("independently_computed_optimal_score")) is not int
                or candidate["score"] != checks["replayed_score"]
                or candidate["score"] != checks["independently_computed_optimal_score"]
                or not isinstance(candidate.get("operations"), list)
                or any(edit not in ("match", "substitution", "insertion", "deletion") for edit in candidate["operations"])
                or result.get("mode") not in ("global", "local", "query_global")
                or result.get("ambiguity") not in ("reject", "always_mismatch")
                or any(type(result.get(k)) is not int or result[k] < 1 for k in ("query_length", "reference_length"))):
            return self.withheld(operation, "native_reply_invalid")
        for prefix in ("query", "reference"):
            start, end = candidate.get(prefix + "_start"), candidate.get(prefix + "_end")
            if type(start) is not int or type(end) is not int or not 0 <= start <= end <= result[prefix + "_length"]:
                return self.withheld(operation, "native_reply_invalid")
        return self.answered(operation, result, "integer_alignment_with_independent_score_checks")
