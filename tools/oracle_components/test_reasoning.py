"""Adapter contract checks using a fake, known module; no native math evidence.

Run: python3 -B -m unittest discover -s tools/oracle_components -p test_reasoning.py
The root runs actual extension and mathematical checks separately.
"""
import importlib.util
import json
from pathlib import Path
from types import ModuleType
import unittest
from unittest.mock import Mock, patch


HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("reasoning_adapter_contract", HERE / "reasoning.py")
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
HOST_SPEC = importlib.util.spec_from_file_location("reasoning_host_contract", HERE.parent / "appliance/operations.py")
HOST = importlib.util.module_from_spec(HOST_SPEC)
HOST_SPEC.loader.exec_module(HOST)


def native_catalog():
    # Deliberately unlike the native defaults: adapter ceilings must come from
    # its bound catalog, not mirrored constants in this Python file.
    return {"schema": ADAPTER.CATALOG_SCHEMA,
            "limits": {"request_bytes": 8192, "vertices": 7, "edges": 9,
                       "expression_nodes": 20, "expression_depth": 8,
                       "polynomial_terms": 10, "coefficient_bits": 128,
                       "polynomial_work": 1000, "egraph_nodes": 99,
                       "iterations": 3, "search_ms": 5, "graph_work": 3000, "graph_reply_bytes": 4096},
            "operations": [{"id": op_id,
                            **({"dimension_order": list(ADAPTER.DIMENSION_ORDER), "max_exponent": 5}
                               if op_id == ADAPTER.DIMENSIONAL else {}),
                            **({"chemistry_limits": {"species": 6, "conserved_rows": 5,
                                                      "coefficient_bits": 96, "work": 700,
                                                      "free_coefficient_bound": 3, "search_candidates": 11}}
                               if op_id == ADAPTER.CHEMISTRY else {}),
                            **({"path_limits": {"vertices": 7, "edges": 9, "work": 3000,
                                                "milliseconds": 5, "reply_bytes": 4096}}
                               if op_id == ADAPTER.SHORTEST else {})}
                           for op_id in ADAPTER.OPERATION_IDS]}


def graph_reply():
    return {"schema": "oracle-minimum-spanning-forest-v1", "edge_ids": [0],
            "total_weight": str(ADAPTER.I64_MAX), "components": 1,
            "connected": True, "check": "fake contract result; no mathematical evidence",
            "build_us": 2**80, "search_us": 2, "check_us": 0}


def algebra_reply():
    return {"schema": "oracle-polynomial-optimization-v1", "expression": "x",
            "original_cost": 3, "selected_cost": 1, "cost_model": "contract fixture",
            "polynomial_terms": 1, "search_stop": "fixture", "iterations": 1,
            "egraph_nodes": 100, "check": "fake contract result; no mathematical evidence",
            "normalize_us": 1, "search_us": 2, "check_us": 3}


def dimensional_reply():
    result = algebra_reply()
    result.update(schema="oracle-dimensional-polynomial-optimization-v1",
                  output_dimension=[1, 0, 0, 0, 0, 0, 0],
                  dimension_order=list(ADAPTER.DIMENSION_ORDER),
                  dimension_check="contract fixture", unit_convention="contract fixture",
                  selection_fallback=None)
    return result


def chemistry_arguments():
    return {"species": [
        {"name": "H2", "side": "reactant", "composition": {"H": 2}, "charge": 0},
        {"name": "O2", "side": "reactant", "composition": {"O": 2}, "charge": 0},
        {"name": "H2O", "side": "product", "composition": {"H": 2, "O": 1}, "charge": 0}]}


def chemistry_reply():
    return {"schema": "oracle-stoichiometry-v1", "operation": ADAPTER.CHEMISTRY,
            "status": "unique_positive", "rank": 2, "nullity": 1,
            "nullspace_basis": [["1", "1/2", "1"]], "free_species_indices": [2],
            "coefficients": ["2", "1", "2"], "conservation": [
                {"inventory": "H", "reactant": "4", "product": "4"},
                {"inventory": "O", "reactant": "2", "product": "2"},
                {"inventory": "charge", "reactant": "0", "product": "0"}],
            "searched_candidates": 0, "free_coefficient_bound": 3,
            "assurance": "fake contract result; no native mathematical evidence"}


def known_module(declaration=None, reply=None):
    module = ModuleType("oracle_native")
    module.reasoning_catalog = Mock(return_value=json.dumps(native_catalog() if declaration is None else declaration))
    module.reasoning_call = Mock(return_value=json.dumps(graph_reply() if reply is None else reply))
    return module


def operation(rows, operation_id):
    return next(row for row in rows if row["id"] == operation_id)


class ReasoningContract(unittest.TestCase):
    def bind(self, module=None, **options):
        binding = dict(native_module=known_module() if module is None else module,
                       runtime_identity="test-host-runtime", enabled=True)
        binding.update(options)
        return ADAPTER.create_reasoning_operations("unused-runtime", "unused-workspace", **binding)

    def test_plain_provider_and_factory_default_are_disabled(self):
        module = known_module()
        providers = [ADAPTER.ReasoningOperations("unused", "unused"),
                     ADAPTER.create_reasoning_operations("unused", "unused", native_module=module,
                                                         runtime_identity="test")]
        for provider in providers:
            self.assertTrue(all(row["availability"] == "unavailable" for row in provider.catalog()))
            self.assertTrue(all(row["native_limits"] is None for row in provider.catalog()))
            self.assertEqual(provider.invoke(ADAPTER.GRAPH, {"enabled": True})["reason"], "operator_enablement_required")
        module.reasoning_catalog.assert_not_called()
        module.reasoning_call.assert_not_called()

    def test_unavailable_backend_feature_and_identity_do_not_call(self):
        cases = [({"backend": "python"}, "unsupported_backend"),
                 ({"runtime_identity": None}, "runtime_identity_required"),
                 ({"runtime_identity": ""}, "runtime_identity_required"),
                 ({"enabled": "yes"}, "operator_enablement_required")]
        for change, reason in cases:
            module = known_module()
            options = dict(enabled=True, native_module=module, runtime_identity="runtime")
            options.update(change)
            provider = ADAPTER.create_reasoning_operations("unused", "unused", **options)
            self.assertEqual(operation(provider.catalog(), ADAPTER.GRAPH)["unavailable_reason"], reason)
            module.reasoning_catalog.assert_not_called()
            module.reasoning_call.assert_not_called()
        provider = self.bind(ModuleType("oracle_native"))
        self.assertEqual(operation(provider.catalog(), ADAPTER.GRAPH)["unavailable_reason"], "native_reasoning_feature_absent")
        provider = self.bind(ModuleType("arbitrary_caller_module"))
        self.assertEqual(operation(provider.catalog(), ADAPTER.GRAPH)["unavailable_reason"], "native_backend_unavailable")

    def test_binding_never_imports_a_module(self):
        module = known_module()
        with patch("importlib.import_module", side_effect=AssertionError("must use host binding")):
            provider = self.bind(module)
            self.assertEqual(operation(provider.catalog(), ADAPTER.GRAPH)["availability"], "live_direct")

    def test_schema_ceilings_follow_bound_catalog_and_copies_do_not_mutate(self):
        provider = self.bind()
        catalog = {row["id"]: row for row in provider.catalog()}
        graph = catalog[ADAPTER.GRAPH]
        self.assertEqual(graph["input_schema"]["properties"]["vertices"]["maximum"], 7)
        self.assertEqual(graph["input_schema"]["properties"]["edges"]["maxItems"], 9)
        self.assertEqual(graph["implementation"]["runtime_identity"], "test-host-runtime")
        self.assertEqual(len(graph["implementation"]["native_catalog_sha256"]), 64)
        self.assertIn("20 tokens", catalog[ADAPTER.ALGEBRA]["input_schema"]["properties"]["expression"]["description"])
        graph["native_limits"]["vertices"] = 999
        graph["input_schema"]["properties"]["vertices"]["maximum"] = 999
        self.assertEqual(operation(provider.catalog(), ADAPTER.GRAPH)["native_limits"]["vertices"], 7)
        self.assertEqual(operation(provider.catalog(), ADAPTER.GRAPH)["input_schema"]["properties"]["vertices"]["maximum"], 7)

    def test_malformed_catalog_is_unavailable(self):
        for mutation in ("schema", "missing_limits", "bool_limit", "duplicate_operation"):
            declaration = native_catalog()
            if mutation == "schema":
                declaration["schema"] = "unsupported"
            elif mutation == "missing_limits":
                del declaration["limits"]["request_bytes"]
            elif mutation == "bool_limit":
                declaration["limits"]["edges"] = True
            else:
                declaration["operations"].append(operation(declaration["operations"], ADAPTER.GRAPH))
            module = known_module(declaration)
            self.assertEqual(operation(self.bind(module).catalog(), ADAPTER.GRAPH)["unavailable_reason"], "native_reasoning_catalog_unsupported")
            module.reasoning_call.assert_not_called()

    def test_unknown_native_operation_is_ignored_and_missing_known_is_unavailable(self):
        declaration = native_catalog()
        declaration["operations"] = [{"id": ADAPTER.GRAPH}, {"id": "unknown.future.operation"}]
        provider = self.bind(known_module(declaration))
        catalog = {row["id"]: row for row in provider.catalog()}
        self.assertNotIn("unknown.future.operation", catalog)
        self.assertEqual(catalog[ADAPTER.GRAPH]["availability"], "live_direct")
        self.assertEqual(catalog[ADAPTER.ALGEBRA]["unavailable_reason"], "native_operation_absent")
        self.assertEqual(provider.invoke(ADAPTER.ALGEBRA, {"expression": "x"})["reason"], "native_operation_absent")

    def test_exact_graph_request_and_complete_reply_are_preserved(self):
        module = known_module()
        provider = self.bind(module)
        arguments = {"vertices": 2, "edges": [[0, 1, ADAPTER.I64_MAX]]}
        result = provider.invoke(ADAPTER.GRAPH, arguments)
        self.assertEqual(json.loads(module.reasoning_call.call_args.args[0]),
                         {"operation": ADAPTER.GRAPH, "arguments": arguments})
        self.assertEqual(result["result"], graph_reply())
        self.assertEqual(result["result"]["total_weight"], "9223372036854775807")
        self.assertEqual(result["authority"], "computation_only")
        self.assertEqual(result["runtime_identity"], "test-host-runtime")
        HOST.validate(arguments, operation(provider.catalog(), ADAPTER.GRAPH)["input_schema"])
        HOST.validate(result, operation(provider.catalog(), ADAPTER.GRAPH)["output_schema"])

    def test_invalid_structured_arguments_do_not_enter_native(self):
        module = known_module()
        provider = self.bind(module)
        arguments = [{"vertices": True, "edges": []}, {"vertices": 8, "edges": []},
                     {"vertices": 0, "edges": [[0, 0, 1]]},
                     {"vertices": 2, "edges": [[0, 2, 1]]},
                     {"vertices": 2, "edges": [[0, 1, 1.0]]},
                     {"vertices": 2, "edges": [[0, 1, ADAPTER.I64_MAX + 1]]},
                     {"vertices": 2, "edges": [[0, 1, 1, 2]]},
                     {"vertices": 2, "edges": [], "enabled": True},
                     {"vertices": 2, "edges": [[0, 1, 1]] * 10}]
        for value in arguments:
            with self.assertRaises(ValueError):
                provider.invoke(ADAPTER.GRAPH, value)
        with self.assertRaises(ValueError):
            provider.invoke("module.arbitrary", {})
        module.reasoning_call.assert_not_called()

    def test_native_algebra_result_is_preserved_without_asserting_global_optimality(self):
        module = known_module(reply=algebra_reply())
        provider = self.bind(module)
        result = provider.invoke(ADAPTER.ALGEBRA, {"expression": "(+ x 0)"})
        self.assertEqual(result["result"], algebra_reply())
        # A cooperative e-graph ceiling may be exceeded by one iteration.
        self.assertGreater(result["result"]["egraph_nodes"], native_catalog()["limits"]["egraph_nodes"])
        catalog = {row["id"]: row for row in provider.catalog()}
        HOST.validate(result, catalog[ADAPTER.ALGEBRA]["output_schema"])

    def test_dimensional_schema_uses_native_exponent_ceiling_and_preserves_full_result(self):
        module = known_module(reply=dimensional_reply())
        provider = self.bind(module)
        arguments = {"expression": "(+ x 0)", "variables": [
            {"name": "x", "dimension": [1, 0, 0, 0, 0, 0, 0]}], "output_dimension": None}
        result = provider.invoke(ADAPTER.DIMENSIONAL, arguments)
        self.assertEqual(result["result"], dimensional_reply())
        catalog = {row["id"]: row for row in provider.catalog()}
        schema = catalog[ADAPTER.DIMENSIONAL]["input_schema"]
        self.assertEqual(schema["properties"]["variables"]["maxItems"], 20)
        self.assertEqual(schema["properties"]["variables"]["items"]["properties"]["dimension"]["items"]["maximum"], 5)
        HOST.validate(arguments, schema)
        HOST.validate(result, catalog[ADAPTER.DIMENSIONAL]["output_schema"])
        fixture = dimensional_reply()
        fixture["selection_fallback"] = "retained original expression: contract fixture"
        module.reasoning_call.return_value = json.dumps(fixture)
        self.assertEqual(provider.invoke(ADAPTER.DIMENSIONAL, arguments)["result"], fixture)

    def test_unsupported_dimensional_catalog_leaves_other_operations_available(self):
        declaration = native_catalog()
        del operation(declaration["operations"], ADAPTER.DIMENSIONAL)["max_exponent"]
        provider = self.bind(known_module(declaration))
        catalog = {row["id"]: row for row in provider.catalog()}
        self.assertEqual(catalog[ADAPTER.GRAPH]["availability"], "live_direct")
        self.assertEqual(catalog[ADAPTER.ALGEBRA]["availability"], "live_direct")
        self.assertEqual(catalog[ADAPTER.DIMENSIONAL]["unavailable_reason"], "native_operation_schema_unsupported")

    def test_invalid_dimensional_annotations_do_not_enter_native(self):
        module = known_module()
        provider = self.bind(module)
        rows = [[{"name": "x", "dimension": [6, 0, 0, 0, 0, 0, 0]}],
                [{"name": "x", "dimension": [0] * 7, "kind": "affine"}],
                [{"name": "x", "dimension": [False] * 7}],
                [{"name": "x", "dimension": [0] * 6}],
                [{"name": "x", "dimension": [0] * 7}] * 2]
        for variables in rows:
            with self.assertRaises(ValueError):
                provider.invoke(ADAPTER.DIMENSIONAL, {"expression": "x", "variables": variables})
        module.reasoning_call.assert_not_called()

    def test_encoded_request_bound_applies_before_call(self):
        module = known_module()
        provider = self.bind(module)
        with self.assertRaises(ValueError):
            provider.invoke(ADAPTER.ALGEBRA, {"expression": "x" * 8192})
        module.reasoning_call.assert_not_called()

    def test_optional_phase_telemetry_preserves_older_results_and_rejects_unknown_fields(self):
        for operation, fixture, arguments in (
            (ADAPTER.GRAPH, graph_reply, {"vertices": 2, "edges": [[0, 1, 1]]}),
            (ADAPTER.ALGEBRA, algebra_reply, {"expression": "x"}),
            (ADAPTER.DIMENSIONAL, dimensional_reply, {"expression": "x", "variables": [
                {"name": "x", "dimension": [1, 0, 0, 0, 0, 0, 0]}]}),
        ):
            older = {key: value for key, value in fixture().items() if not key.endswith("_us")}
            provider = self.bind(known_module(reply=older))
            self.assertEqual(provider.invoke(operation, arguments)["result"], older)
            for field, value in (("check_us", -1), ("search_us", True),
                                 ("check_us", 2**128), ("unrecognized_us", 1)):
                invalid = fixture()
                invalid[field] = value
                provider = self.bind(known_module(reply=invalid))
                self.assertEqual(provider.invoke(operation, arguments)["reason"], "native_reply_invalid")

    def test_native_refusals_stay_refusals_with_bounded_details(self):
        module = known_module()
        module.reasoning_call.side_effect = ValueError("resource limit: " + "x" * 1000)
        provider = self.bind(module)
        result = provider.invoke(ADAPTER.ALGEBRA, {"expression": "x"})
        self.assertEqual(result["status"], "withheld")
        self.assertEqual(result["reason"], "native_request_refused")
        self.assertEqual(len(result["detail"]), 512)
        HOST.validate(result, operation(provider.catalog(), ADAPTER.ALGEBRA)["output_schema"])
        module.reasoning_call.side_effect = RuntimeError("not an input error")
        self.assertEqual(provider.invoke(ADAPTER.ALGEBRA, {"expression": "x"})["reason"], "native_execution_failed")

    def test_invalid_native_replies_are_never_answered(self):
        for raw in ("{}", "NaN", '{"schema":1,"schema":2}', "[]", "x" * (ADAPTER.MAX_REPLY_BYTES + 1)):
            module = known_module()
            module.reasoning_call.return_value = raw
            self.assertEqual(self.bind(module).invoke(ADAPTER.GRAPH, {"vertices": 0, "edges": []})["reason"], "native_reply_invalid")
        invalid = graph_reply()
        invalid["total_weight"] = ADAPTER.I64_MAX
        self.assertEqual(self.bind(known_module(reply=invalid)).invoke(ADAPTER.GRAPH, {"vertices": 2, "edges": [[0, 1, 1]]})["reason"], "native_reply_invalid")

    def test_chemistry_discovery_uses_bound_catalog_and_preserves_exact_full_result(self):
        module = known_module(reply=chemistry_reply())
        provider = self.bind(module)
        catalog = {row["id"]: row for row in provider.catalog()}
        item = catalog[ADAPTER.CHEMISTRY]
        self.assertEqual(item["availability"], "live_direct")
        self.assertEqual(item["input_schema"]["properties"]["species"]["maxItems"], 6)
        self.assertEqual(item["chemistry_limits"]["conserved_rows"], 5)
        arguments = chemistry_arguments()
        reply = provider.invoke(ADAPTER.CHEMISTRY, arguments)
        self.assertEqual(reply["status"], "answered")
        self.assertEqual(reply["answer_kind"], "positive_balance")
        self.assertEqual(reply["result"], chemistry_reply())
        self.assertIn("no reaction feasibility", reply["scope"])
        self.assertEqual(json.loads(module.reasoning_call.call_args.args[0]),
                         {"operation": ADAPTER.CHEMISTRY, "arguments": arguments})
        HOST.validate(arguments, item["input_schema"])
        HOST.validate(reply, item["output_schema"])

    def test_chemistry_mathematical_negatives_are_answers_scoped_to_supplied_inventory(self):
        for status, rank, basis, free in (("no_nonzero_balance", 3, [], []),
                                        ("no_strictly_positive_balance", 2, [["1", "0", "1"]], [2])):
            fixture = chemistry_reply()
            fixture.update(status=status, rank=rank, nullity=len(basis), nullspace_basis=basis,
                           free_species_indices=free, coefficients=None, conservation=[])
            provider = self.bind(known_module(reply=fixture))
            reply = provider.invoke(ADAPTER.CHEMISTRY, chemistry_arguments())
            self.assertEqual(reply["status"], "answered")
            self.assertEqual(reply["answer_kind"], "mathematical_negative")
            self.assertEqual(reply["result"], fixture)
            self.assertEqual(reply["scope"], ADAPTER.CHEMISTRY_SCOPE)
            HOST.validate(reply, operation(provider.catalog(), ADAPTER.CHEMISTRY)["output_schema"])

    def test_chemistry_inconclusive_search_withholds_and_keeps_basis_diagnostics(self):
        fixture = chemistry_reply()
        fixture.update(status="multiple_search_inconclusive", rank=1, nullity=2,
                       nullspace_basis=[["1", "1", "0"], ["1", "0", "1"]],
                       free_species_indices=[1, 2], coefficients=None, conservation=[], searched_candidates=11)
        provider = self.bind(known_module(reply=fixture))
        reply = provider.invoke(ADAPTER.CHEMISTRY, chemistry_arguments())
        self.assertEqual(reply["status"], "withheld")
        self.assertEqual(reply["reason"], "positive_balance_search_inconclusive")
        self.assertEqual(reply["answer_kind"], "search_inconclusive")
        self.assertEqual(reply["result"], fixture)
        HOST.validate(reply, operation(provider.catalog(), ADAPTER.CHEMISTRY)["output_schema"])

    def test_chemistry_multiple_candidate_is_an_answer_without_optimality_claim(self):
        fixture = chemistry_reply()
        fixture.update(status="multiple_with_positive_candidate", rank=1, nullity=2,
                       nullspace_basis=[["1", "1", "0"], ["1", "0", "1"]],
                       free_species_indices=[1, 2], searched_candidates=1)
        reply = self.bind(known_module(reply=fixture)).invoke(ADAPTER.CHEMISTRY, chemistry_arguments())
        self.assertEqual(reply["status"], "answered")
        self.assertEqual(reply["answer_kind"], "positive_balance")
        self.assertEqual(reply["result"], fixture)

    def test_chemistry_bad_metadata_withholds_only_that_operation(self):
        for field, value in (("species", True), ("species", 1), ("conserved_rows", 0),
                             ("free_coefficient_bound", 2**32), ("search_candidates", -1)):
            declaration = native_catalog()
            operation(declaration["operations"], ADAPTER.CHEMISTRY)["chemistry_limits"][field] = value
            catalog = {row["id"]: row for row in self.bind(known_module(declaration)).catalog()}
            self.assertEqual(catalog[ADAPTER.CHEMISTRY]["unavailable_reason"], "native_operation_schema_unsupported")
            self.assertEqual(catalog[ADAPTER.GRAPH]["availability"], "live_direct")
        declaration = native_catalog()
        del operation(declaration["operations"], ADAPTER.CHEMISTRY)["chemistry_limits"]
        self.assertEqual(operation(self.bind(known_module(declaration)).catalog(), ADAPTER.CHEMISTRY)["availability"], "unavailable")

    def test_chemistry_invalid_structured_arguments_never_enter_native(self):
        module = known_module(reply=chemistry_reply())
        provider = self.bind(module)
        for field, value in (("charge", 0.0), ("charge", True), ("charge", ADAPTER.I64_MAX + 1),
                             ("side", "unknown"), ("name", ""), ("composition", {"H": 0}),
                             ("composition", {"H": 1.0}), ("composition", {"H": 2**64}),
                             ("composition", {"C-013": 1}), ("composition", {})):
            arguments = chemistry_arguments()
            arguments["species"][0][field] = value
            with self.assertRaises(ValueError):
                provider.invoke(ADAPTER.CHEMISTRY, arguments)
        for mutation in ("too_many", "duplicate_name", "one_side", "inventory_union"):
            arguments = chemistry_arguments()
            if mutation == "too_many":
                arguments["species"] *= 3
            elif mutation == "duplicate_name":
                arguments["species"][1]["name"] = "H2"
            elif mutation == "one_side":
                arguments["species"][2]["side"] = "reactant"
            else:
                arguments["species"][0]["composition"] = {"H": 1, "C": 1, "C-13": 1, "Fe": 1}
            with self.assertRaises(ValueError):
                provider.invoke(ADAPTER.CHEMISTRY, arguments)
        module.reasoning_call.assert_not_called()

    def test_chemistry_exact_u64_counts_and_explicit_electrons_reach_native(self):
        module = known_module()
        module.reasoning_call.side_effect = ValueError("fixture refusal after observing arguments")
        provider = self.bind(module)
        arguments = {"species": [
            {"name": "supplied-ion", "side": "reactant", "composition": {"Fe": 2**64 - 1}, "charge": -2},
            {"name": "supplied-electron", "side": "product", "composition": {}, "charge": -1}]}
        reply = provider.invoke(ADAPTER.CHEMISTRY, arguments)
        self.assertEqual(reply["reason"], "native_request_refused")
        self.assertEqual(json.loads(module.reasoning_call.call_args.args[0])["arguments"], arguments)

    def test_chemistry_bad_result_shapes_do_not_become_mathematical_claims(self):
        for mutation in ("float_coefficient", "missing_charge", "mismatched_totals", "wrong_basis_size", "unknown_status"):
            fixture = chemistry_reply()
            if mutation == "float_coefficient":
                fixture["coefficients"][0] = 2.0
            elif mutation == "missing_charge":
                fixture["conservation"].pop()
            elif mutation == "mismatched_totals":
                fixture["conservation"][0]["reactant"] = "5"
            elif mutation == "wrong_basis_size":
                fixture["nullspace_basis"][0].pop()
            else:
                fixture["status"] = "reaction_impossible"
            reply = self.bind(known_module(reply=fixture)).invoke(ADAPTER.CHEMISTRY, chemistry_arguments())
            self.assertEqual(reply["status"], "withheld")
            self.assertEqual(reply["reason"], "native_reply_invalid")

    def test_shortest_path_discovery_and_all_certificate_shapes(self):
        cases = [
            ({"vertices": 2, "source": 0, "target": 1, "edges": [[0, 1, 7]]},
             {"outcome": "finite", "distance": "7", "path": [0], "labels": ["0", "7"]}),
            ({"vertices": 2, "source": 0, "target": 1, "edges": []},
             {"outcome": "unreachable", "reachable": [True, False]}),
            ({"vertices": 2, "source": 0, "target": 1, "edges": [[0, 0, -1], [0, 1, 0]]},
             {"outcome": "unbounded", "prefix": [], "cycle": [0], "suffix": [1]}),
        ]
        for arguments, fixture in cases:
            module = known_module(reply=fixture)
            provider = self.bind(module)
            item = {row["id"]: row for row in provider.catalog()}[ADAPTER.SHORTEST]
            self.assertEqual(item["availability"], "live_direct")
            self.assertEqual(item["path_limits"]["work"], 3000)
            self.assertEqual(item["input_schema"]["properties"]["vertices"]["minimum"], 1)
            reply = provider.invoke(ADAPTER.SHORTEST, arguments)
            self.assertEqual(reply["result"], fixture)
            HOST.validate(arguments, item["input_schema"])
            HOST.validate(reply, item["output_schema"])

    def test_shortest_path_rejects_bad_endpoints_and_witness_transport(self):
        arguments = {"vertices": 2, "source": 0, "target": 1, "edges": [[0, 1, 7]]}
        for change in ({"source": True}, {"target": 2}, {"vertices": 0}, {"work": 999}):
            module = known_module()
            with self.assertRaises(ValueError):
                self.bind(module).invoke(ADAPTER.SHORTEST, dict(arguments, **change))
            module.reasoning_call.assert_not_called()
        for fixture in (
            {"outcome": "finite", "distance": "7", "path": [1], "labels": ["0", "7"]},
            {"outcome": "finite", "distance": "7", "path": [0], "labels": ["0"]},
            {"outcome": "finite", "distance": "07", "path": [0], "labels": ["0", "07"]},
            {"outcome": "unreachable", "reachable": [True, False]},
            {"outcome": "unbounded", "prefix": [], "cycle": [], "suffix": [0]},
            {"outcome": "unbounded", "prefix": [], "cycle": [0], "suffix": [0]},
            {"outcome": "finite", "distance": "7", "path": [0], "labels": ["0", "7"], "extra": 1},
        ):
            reply = self.bind(known_module(reply=fixture)).invoke(ADAPTER.SHORTEST, arguments)
            self.assertEqual(reply["reason"], "native_reply_invalid", fixture)

    def test_shortest_path_metadata_and_native_reply_byte_ceiling(self):
        for key, value in (("vertices", 8), ("work", True), ("reply_bytes", 0), ("milliseconds", 6)):
            declaration = native_catalog()
            operation(declaration["operations"], ADAPTER.SHORTEST)["path_limits"][key] = value
            provider = self.bind(known_module(declaration))
            rows = {row["id"]: row for row in provider.catalog()}
            self.assertEqual(rows[ADAPTER.SHORTEST]["unavailable_reason"], "native_operation_schema_unsupported")
            self.assertEqual(rows[ADAPTER.GRAPH]["availability"], "live_direct")
        declaration = native_catalog()
        declaration["limits"]["graph_reply_bytes"] = 40
        operation(declaration["operations"], ADAPTER.SHORTEST)["path_limits"]["reply_bytes"] = 40
        fixture = {"outcome": "finite", "distance": "0", "path": [], "labels": ["0"]}
        reply = self.bind(known_module(declaration, fixture)).invoke(ADAPTER.SHORTEST,
            {"vertices": 1, "source": 0, "target": 0, "edges": []})
        self.assertEqual(reply["reason"], "native_reply_invalid")



class ExactLinearContract(unittest.TestCase):
    bind = ReasoningContract.bind
    def test_exact_transport_and_unknown_withholding(self):
        arguments = {"variables": ["x"], "rows": [{"id": "low", "coefficients": ["-1"], "bound": "-1"}]}
        for status, certificate in (("feasible", {"kind": "feasible", "point": ["1"]}), ("unknown", None)):
            reply = {"status": status, "certificate": certificate, "reason": "limit" if status == "unknown" else None,
                     "assurance": "fake transport fixture; no mathematical evidence"}
            provider = self.bind(known_module(reply=reply))
            result = provider.invoke(ADAPTER.EXACT, arguments)
            self.assertEqual(result["status"], "withheld" if status == "unknown" else "answered")
            self.assertEqual(result["result"], reply)
            if status == "unknown":
                self.assertEqual(result["reason"], "exact_feasibility_inconclusive")
        provider = self.bind(known_module(reply={"status": "infeasible", "certificate": {"kind": "feasible", "point": ["1"]},
                                         "reason": None, "assurance": "fake fixture"}))
        self.assertEqual(provider.invoke(ADAPTER.EXACT, arguments)["reason"], "native_reply_invalid")

    def test_exact_rejects_mismatched_dimensions(self):
        provider = self.bind()
        with self.assertRaises(ValueError):
            provider.invoke(ADAPTER.EXACT, {"variables": ["x"], "rows": [{"id": "r", "coefficients": [], "bound": "0"}]})

if __name__ == "__main__":
    unittest.main()
