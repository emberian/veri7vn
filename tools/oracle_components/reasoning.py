"""Untrusted adapter for explicitly enabled experimental native computations.

This does not import or discover native modules, read activation from requests,
or register Mini capabilities. The host supplies its already selected module
and deployment identity. That identity is a host assertion, not an attestation.
Search limits are cooperative; this adapter provides no hard containment.
"""
from __future__ import annotations

import copy
import hashlib
import json
import re


LIMIT_NAMES = ("request_bytes", "vertices", "edges", "expression_nodes",
               "expression_depth", "polynomial_terms", "coefficient_bits",
               "polynomial_work", "egraph_nodes", "iterations", "search_ms")
I64_MIN, I64_MAX = -(2**63), 2**63 - 1
GRAPH = "graph.minimum_spanning_forest"
SHORTEST = "graph.shortest_path"
ALGEBRA = "algebra.optimize_polynomial"
DIMENSIONAL = "algebra.optimize_dimensional_polynomial"
CHEMISTRY = "chemistry.balance_reaction"
CHEMISTRY_LIMIT_NAMES = ("species", "conserved_rows", "coefficient_bits", "work",
                         "free_coefficient_bound", "search_candidates")
CHEMISTRY_STATUSES = ("unique_positive", "no_nonzero_balance", "no_strictly_positive_balance",
                      "multiple_with_positive_candidate", "multiple_search_inconclusive")
CHEMISTRY_SCOPE = "Exact conservation of caller-supplied species inventories and charge only; no reaction feasibility, chemical identity, kinetics or thermodynamics claim."
DIMENSION_ORDER = ("length", "mass", "time", "electric_current", "temperature", "amount", "luminous_intensity")
CATALOG_SCHEMA = "oracle-reasoning-experimental-v1"
MAX_REPLY_BYTES = 262144


def _object(properties, required=None):
    return {"type": "object", "properties": properties,
            "required": list(properties) if required is None else required,
            "additionalProperties": False}


def _integer(low, high):
    return {"type": "integer", "minimum": low, "maximum": high}


def _string(limit, **fields):
    return dict(type="string", minLength=1, maxLength=limit, **fields)


WEIGHT = _integer(I64_MIN, I64_MAX)


def _dimension(max_exponent=None):
    maximum = 32767 if max_exponent is None else max_exponent
    return {"type": "array", "minItems": len(DIMENSION_ORDER), "maxItems": len(DIMENSION_ORDER),
            "items": _integer(-maximum, maximum), "description": "Integer SI exponents in order: " + ", ".join(DIMENSION_ORDER)}


def _chemistry_input(limits):
    composition = {"type": "object", "additionalProperties": _integer(1, 2**64 - 1),
                   "propertyNames": {"pattern": r"^[A-Z][a-z]?(?:-[1-9][0-9]{0,2})?$"},
                   "description": "Actual element symbol, optionally an isotope label such as C-13, mapped to a positive u64 count. Isotope and unspecified-element inventories stay separate; native code checks element membership. Empty only for a supplied electron with charge -1."}
    species = {"type": "array", "minItems": 2, "items": _object({
        "name": _string(128, description="Unique display label, nonblank, at most 128 UTF-8 bytes; no formula parsing or identity lookup."),
        "side": {"type": "string", "enum": ["reactant", "product"]},
        "composition": composition, "charge": _integer(I64_MIN, I64_MAX)}),
        "description": "Complete supplied species, with both sides present. Water, protons and electrons are never inserted."}
    if limits is not None:
        species["maxItems"] = limits["species"]
        composition["maxProperties"] = limits["conserved_rows"] - 1
    return _object({"species": species})


def _chemistry_result(limits):
    count = lambda name: limits[name] if limits is not None else 2**64 - 1
    digits = min(MAX_REPLY_BYTES, count("coefficient_bits") + 2)
    integer_text = _string(digits, pattern=r"^-?(0|[1-9][0-9]*)$")
    rational_text = _string(min(MAX_REPLY_BYTES, 2 * count("coefficient_bits") + 3),
                            pattern=r"^-?(0|[1-9][0-9]*)(/[1-9][0-9]*)?$")
    vector = {"type": "array", "minItems": 2, "maxItems": count("species"), "items": rational_text}
    return _object({
        "schema": {"const": "oracle-stoichiometry-v1"}, "operation": {"const": CHEMISTRY},
        "status": {"type": "string", "enum": list(CHEMISTRY_STATUSES), "minLength": 1, "maxLength": 80},
        "rank": _integer(0, count("species")), "nullity": _integer(0, count("species")),
        "nullspace_basis": {"type": "array", "maxItems": count("species"), "items": vector},
        "free_species_indices": {"type": "array", "maxItems": count("species"),
                                 "items": _integer(0, count("species") - 1)},
        "coefficients": {"anyOf": [{"type": "array", "minItems": 2, "maxItems": count("species"),
                                      "items": _string(digits, pattern=r"^[1-9][0-9]*$")}, {"type": "null"}]},
        "conservation": {"type": "array", "maxItems": count("conserved_rows"), "items": _object({
            "inventory": _string(16), "reactant": integer_text, "product": integer_text})},
        "searched_candidates": _integer(0, count("search_candidates")),
        "free_coefficient_bound": _integer(0, 2**32 - 1) if limits is None else {"const": limits["free_coefficient_bound"]},
        "assurance": _string(1024),
    })


def _inputs(limits, max_exponent=None, chemistry_limits=None):
    endpoint = {"type": "integer", "minimum": 0}
    vertices = {"type": "integer", "minimum": 0}
    if limits is not None:
        endpoint["maximum"] = limits["vertices"] - 1
        vertices["maximum"] = limits["vertices"]
    edge = {"type": "array", "minItems": 3, "maxItems": 3,
            "prefixItems": [endpoint, endpoint, WEIGHT], "items": WEIGHT,
            "description": "[source vertex, target vertex, exact i64 weight]. Endpoints must be less than vertices."}
    edges = {"type": "array", "items": edge,
             "description": "Undirected multigraph. Edge IDs are zero-based list positions; loops and parallel edges are allowed."}
    expression = {"type": "string", "minLength": 1,
                  "description": "Prefix expression with binary +, -, *; i64 literals and ASCII identifiers [A-Za-z_][A-Za-z0-9_]{0,63}. Exact commutative integer-polynomial semantics; no floats or division. Native limits apply to tokens, nesting and whole encoded request bytes."}
    if limits is not None:
        edges["maxItems"] = limits["edges"]
        expression["maxLength"] = limits["request_bytes"]
        expression["description"] += f" At most {limits['expression_nodes']} tokens and {limits['expression_depth']} parenthesis levels."
    annotations = {"type": "array", "items": _object({
        "name": _string(64, pattern=r"^[A-Za-z_][A-Za-z0-9_]*$"),
        "dimension": _dimension(max_exponent), "kind": {"type": "string", "enum": ["linear"]}},
        required=["name", "dimension"]),
        "description": "Exactly one annotation for each original variable, with no unused or duplicate names. Omitted kind means linear. Affine quantities are unsupported."}
    if limits is not None:
        annotations["maxItems"] = limits["expression_nodes"]
    dimensional_expression = copy.deepcopy(expression)
    dimensional_expression["description"] = dimensional_expression["description"].replace(
        "Exact commutative integer-polynomial semantics", "Exact commutative polynomial semantics for coherent linear SI quantities")
    directed_edges = copy.deepcopy(edges)
    directed_edges["description"] = "Complete supplied directed multigraph only. Stable edge IDs are list positions; loops and parallel edges are allowed."
    positive_vertices = dict(vertices, minimum=1)
    return {GRAPH: _object({"vertices": vertices, "edges": edges}),
            SHORTEST: _object({"vertices": positive_vertices, "edges": directed_edges,
                               "source": endpoint, "target": endpoint}),
            ALGEBRA: _object({"expression": expression}),
            DIMENSIONAL: _object({"expression": dimensional_expression, "variables": annotations,
                                  "output_dimension": {"anyOf": [_dimension(max_exponent), {"type": "null"}]}},
                                 required=["expression", "variables"]),
            CHEMISTRY: _chemistry_input(chemistry_limits)}


def _results(limits, max_exponent=None, chemistry_limits=None):
    # Output schemas also describe unavailable operations, whose actual native
    # ceilings are not known. Bounds then state only the stable u64 contract.
    count = lambda name: limits[name] if limits is not None else 2**64 - 1
    results = {GRAPH: _object({
        "schema": {"const": "oracle-minimum-spanning-forest-v1"},
        "edge_ids": {"type": "array", "items": _integer(0, count("edges") - 1),
                     "maxItems": count("vertices") - 1},
        "total_weight": _string(40, pattern=r"^-?(0|[1-9][0-9]*)$",
                                description="Exact decimal integer string; preserves sums outside the JavaScript integer range."),
        "components": _integer(0, count("vertices")), "connected": {"type": "boolean"},
        "check": _string(512),
    }),
    ALGEBRA: _object({
        "schema": {"const": "oracle-polynomial-optimization-v1"},
        "expression": _string(MAX_REPLY_BYTES),
        "original_cost": _integer(1, 2**64 - 1), "selected_cost": _integer(1, 2**64 - 1),
        "cost_model": _string(512), "polynomial_terms": _integer(0, count("polynomial_terms")),
        "search_stop": _string(512), "iterations": _integer(0, 2**64 - 1),
        "egraph_nodes": _integer(0, 2**64 - 1), "check": _string(512),
    }),
    }
    dimensional = copy.deepcopy(results[ALGEBRA]["properties"])
    dimensional.update({"schema": {"const": "oracle-dimensional-polynomial-optimization-v1"},
                        "output_dimension": _dimension(max_exponent),
                        "dimension_order": {"const": list(DIMENSION_ORDER)},
                        "dimension_check": _string(1024), "unit_convention": _string(1024),
                        "selection_fallback": {"anyOf": [_string(MAX_REPLY_BYTES), {"type": "null"}]}})
    results[DIMENSIONAL] = _object(dimensional)
    results[CHEMISTRY] = _chemistry_result(chemistry_limits)
    decimal = _string(40, pattern=r"^(0|-[1-9][0-9]*|[1-9][0-9]*)$")
    path = {"type": "array", "maxItems": count("vertices"), "items": _integer(0, count("edges") - 1)}
    labels = {"type": "array", "maxItems": count("vertices"),
              "items": {"anyOf": [decimal, {"type": "null"}]}}
    results[SHORTEST] = {"anyOf": [
        _object({"outcome": {"const": "finite"}, "distance": decimal, "path": path, "labels": labels}),
        _object({"outcome": {"const": "unreachable"}, "reachable": {
            "type": "array", "maxItems": count("vertices"), "items": {"type": "boolean"}}}),
        _object({"outcome": {"const": "unbounded"}, "prefix": path,
                 "cycle": dict(path, minItems=1), "suffix": path})]}
    # Named telemetry is optional across experimental native revisions. Keep
    # every supplied timing without weakening the required semantic contract
    # or accepting arbitrary additional result fields.
    for operation, names in ((GRAPH, ("build_us", "search_us", "check_us")),
                             (ALGEBRA, ("normalize_us", "search_us", "check_us")),
                             (DIMENSIONAL, ("normalize_us", "search_us", "check_us"))):
        for name in names:
            results[operation]["properties"][name] = dict(
                _integer(0, 2**128 - 1), description="Native measured phase time in microseconds; telemetry, not a hard limit.")
    return results


OPERATION_IDS = (GRAPH, ALGEBRA, DIMENSIONAL, CHEMISTRY, SHORTEST)
LIMITATIONS = [
    "Experimental computation only. No specialist panel numbers, release admission, Isabelle proof or Mini capability authority.",
    "The host must enable this provider explicitly and supply its runtime identity. Identity is a host assertion, not an independent attestation.",
    "Native search limits are cooperative; no hard deadline, memory containment, cancellation or tenant isolation is supplied here.",
    "Existing host transport limits still apply to the whole request and reply; schema ceilings do not override them.",
]


def _json(text, maximum):
    if not isinstance(text, str) or len(text) > maximum or len(text.encode("utf-8")) > maximum:
        raise ValueError("native JSON exceeds byte limit or is not a string")

    def pairs(rows):
        result = {}
        for key, value in rows:
            if key in result:
                raise ValueError("duplicate native JSON key")
            result[key] = value
        return result

    def constant(_):
        raise ValueError("non-finite native JSON")

    return json.loads(text, object_pairs_hook=pairs, parse_constant=constant)


def _valid(value, schema):
    """Check our small output schema subset, without coercing native values."""
    if "anyOf" in schema:
        return any(_valid(value, choice) for choice in schema["anyOf"])
    kind = schema.get("type")
    if "const" in schema and (type(value) is not type(schema["const"]) or value != schema["const"]):
        return False
    if "enum" in schema and value not in schema["enum"]:
        return False
    if kind == "object":
        return (isinstance(value, dict) and set(schema["required"]) <= set(value) <= set(schema["properties"])
                and all(_valid(v, schema["properties"][k]) for k, v in value.items()))
    if kind == "array":
        return (isinstance(value, list) and schema.get("minItems", 0) <= len(value) <= schema["maxItems"]
                and all(_valid(v, schema["items"]) for v in value))
    if kind == "integer":
        return type(value) is int and schema["minimum"] <= value <= schema["maximum"]
    if kind == "boolean":
        return type(value) is bool
    if kind == "null":
        return value is None
    if kind == "string":
        return (isinstance(value, str) and schema["minLength"] <= len(value) <= schema["maxLength"]
                and ("pattern" not in schema or re.fullmatch(schema["pattern"], value) is not None))
    return "const" in schema


class ReasoningOperations:
    """Fixed-provider interface. The ordinary two-path constructor stays disabled.

    ``runtime`` and ``workspace`` match other appliance providers; neither path
    is opened. Use ``create_reasoning_operations`` for explicit host binding.
    No option in an operation's arguments can change this binding or enable it.
    """

    def __init__(self, runtime, workspace, *, enabled=False, backend="oracle_native",
                 native_module=None, runtime_identity=None):
        self._call = None
        self._identity = None
        self._catalog_digest = None
        self._limits = None
        self._chemistry_limits = None
        self._path_limits = None
        self._available_ids = set()
        self._operation_unavailable = {}
        self._inputs, self._results = _inputs(None), _results(None)
        self.unavailable_reason = "operator_enablement_required"
        if enabled is not True:
            return
        if backend != "oracle_native":
            self.unavailable_reason = "unsupported_backend"
            return
        if not isinstance(runtime_identity, str) or not 1 <= len(runtime_identity) <= 256:
            self.unavailable_reason = "runtime_identity_required"
            return
        self._identity = runtime_identity
        if getattr(native_module, "__name__", None) not in ("oracle_native", "oracle_native.oracle_native"):
            self.unavailable_reason = "native_backend_unavailable"
            return
        call = getattr(native_module, "reasoning_call", None)
        catalog = getattr(native_module, "reasoning_catalog", None)
        if not callable(call) or not callable(catalog):
            self.unavailable_reason = "native_reasoning_feature_absent"
            return
        try:
            raw = catalog()
            declaration = _json(raw, 16384)
            rows = declaration["operations"]
            limits = declaration["limits"]
            if (declaration["schema"] != CATALOG_SCHEMA or not isinstance(limits, dict)
                    or not set(LIMIT_NAMES) <= set(limits)
                    or any(type(limits[k]) is not int or not 1 <= limits[k] <= 2**64 - 1 for k in LIMIT_NAMES)
                    or not isinstance(rows, list) or len(rows) > 64
                    or any(not isinstance(row, dict) or not isinstance(row.get("id"), str) for row in rows)
                    or len({row["id"] for row in rows}) != len(rows)):
                raise ValueError("unsupported native catalog")
        except Exception:
            self.unavailable_reason = "native_reasoning_catalog_unsupported"
            return
        self._catalog_digest = hashlib.sha256(raw.encode("utf-8")).hexdigest()
        self._limits = {key: limits[key] for key in LIMIT_NAMES}
        self._available_ids = set(OPERATION_IDS).intersection(row["id"] for row in rows)
        max_exponent = None
        if DIMENSIONAL in self._available_ids:
            dimensions = next(row for row in rows if row["id"] == DIMENSIONAL)
            maximum = dimensions.get("max_exponent")
            if (dimensions.get("dimension_order") != list(DIMENSION_ORDER)
                    or type(maximum) is not int or not 1 <= maximum <= 32767):
                self._available_ids.remove(DIMENSIONAL)
                self._operation_unavailable[DIMENSIONAL] = "native_operation_schema_unsupported"
            else:
                max_exponent = maximum
        if CHEMISTRY in self._available_ids:
            chemistry = next(row for row in rows if row["id"] == CHEMISTRY).get("chemistry_limits")
            if (not isinstance(chemistry, dict) or not set(CHEMISTRY_LIMIT_NAMES) <= set(chemistry)
                    or any(type(chemistry[k]) is not int or not 0 <= chemistry[k] <= 2**64 - 1
                           for k in CHEMISTRY_LIMIT_NAMES)
                    or chemistry["species"] < 2 or any(chemistry[k] < 1 for k in
                       ("conserved_rows", "coefficient_bits", "work"))
                    or chemistry["free_coefficient_bound"] > 2**32 - 1):
                self._available_ids.remove(CHEMISTRY)
                self._operation_unavailable[CHEMISTRY] = "native_operation_schema_unsupported"
            else:
                self._chemistry_limits = {key: chemistry[key] for key in CHEMISTRY_LIMIT_NAMES}
        if SHORTEST in self._available_ids:
            path = next(row for row in rows if row["id"] == SHORTEST).get("path_limits")
            keys = ("vertices", "edges", "work", "milliseconds", "reply_bytes")
            if (not isinstance(path, dict) or not set(keys) <= set(path)
                    or any(type(path[k]) is not int or not 1 <= path[k] <= 2**64 - 1 for k in keys)
                    or path["vertices"] != limits["vertices"] or path["edges"] != limits["edges"]
                    or path["milliseconds"] != limits["search_ms"]
                    or path["work"] != limits.get("graph_work")
                    or path["reply_bytes"] != limits.get("graph_reply_bytes")):
                self._available_ids.remove(SHORTEST)
                self._operation_unavailable[SHORTEST] = "native_operation_schema_unsupported"
            else:
                self._path_limits = {key: path[key] for key in keys}
                self._limits.update(graph_work=path["work"], graph_reply_bytes=path["reply_bytes"])
        self._inputs = _inputs(self._limits, max_exponent, self._chemistry_limits)
        self._results = _results(self._limits, max_exponent, self._chemistry_limits)
        self._call = call
        self.unavailable_reason = None

    def catalog(self):
        rows = []
        for op_id, name, description, example, limitation in (
            (GRAPH, "Minimum spanning forest of a supplied graph",
             "Select a minimum-weight spanning forest of a supplied undirected multigraph. The native provider checks acyclicity, component coverage and cycle optimality independently of its candidate generator.",
             {"vertices": 3, "edges": [[0, 1, 4], [1, 2, -2], [0, 2, 9]]},
             "Caller supplies the graph. JSON clients must preserve i64 weights exactly before serialization; total_weight is a decimal string. Isolated vertices count as components; an empty graph is not connected."),
            (ALGEBRA, "Optimize an exact integer polynomial expression",
             "Search equivalent polynomial expressions and return one with its tree cost. The native provider checks exact polynomial normalization independently of its rewrite search.",
             {"expression": "(+ (* x y) (* x z))"},
             "Dimensionless commutative polynomials only. Tree cost assigns 4 to multiplication and 1 to other nodes; this is not measured speed or a guarantee of global optimality. E-graph size/time ceilings may be exceeded within an iteration."),
            (DIMENSIONAL, "Optimize a polynomial with supplied SI dimensions",
             "Check the original expression's supplied dimensions, search exact polynomial equivalents and check the selected expression's identity and dimensions. Retain the original if selection loses dimensional admission.",
             {"expression": "(+ (* m a) (* m b))", "variables": [
                 {"name": "m", "dimension": [0, 1, 0, 0, 0, 0, 0]},
                 {"name": "a", "dimension": [1, 0, -2, 0, 0, 0, 0]},
                 {"name": "b", "dimension": [1, 0, -2, 0, 0, 0, 0]}]},
             "Caller supplies coherent linear SI annotations. No scale or affine conversion, physical-law proof or floating-point equivalence is established. Numerical zero may take the requested dimension; variable-bearing zero retains its original type. Tree cost is not measured speed or global optimality; search ceilings are cooperative."),
            (CHEMISTRY, "Balance supplied species with exact inventory and charge conservation",
             "Compute an exact rational nullspace for caller-supplied compositions and sides. Independently replay any primitive positive integer candidate over those supplied inventories, including charge.",
             {"species": [
                 {"name": "H2", "side": "reactant", "composition": {"H": 2}, "charge": 0},
                 {"name": "O2", "side": "reactant", "composition": {"O": 2}, "charge": 0},
                 {"name": "H2O", "side": "product", "composition": {"H": 2, "O": 1}, "charge": 0}]},
             "Conservation does not establish that a species exists or a reaction occurs. Multidimensional positive-coefficient search is bounded: inconclusive search is withheld, not impossibility. A found primitive candidate need not minimize coefficients. Basis/rank are exact Rust computations, not independently certified rank proofs. Integer counts and charges must be serialized exactly; coefficients and basis entries are decimal/rational strings."),
            (SHORTEST, "Shortest walk in a supplied directed graph",
             "Return an exact finite minimum, unreachable, or unbounded-below result with a checked graph-local certificate.",
             {"vertices": 3, "edges": [[0, 1, 4], [1, 2, -2], [0, 2, 9]], "source": 0, "target": 2},
             "The graph is the complete supplied input, not the world. A negative cycle matters only when source-reachable and able to reach target. Distances and labels are exact decimal strings. Finite paths attain feasible-label lower bounds; unreachable sets are closed; unbounded witnesses connect source, negative cycle and target. Rust checks are not Isabelle proofs. Search, checking and capped serialization share cooperative budgets."),
        ):
            item = {"id": op_id, "name": name, "description": description,
                    "availability": "live_direct" if self._call is not None and op_id in self._available_ids else "unavailable",
                    "input_schema": copy.deepcopy(self._inputs[op_id]),
                    "output_schema": self._output_schema(op_id),
                    "units": ({"input": "caller-defined consistent edge weight units", "output": "same weight units"}
                              if op_id in (GRAPH, SHORTEST) else {"input": "coherent linear SI quantities", "output": "declared SI exponents; tree cost is an abstract count"}
                              if op_id == DIMENSIONAL else {"input": "exact atom/isotope counts and signed elementary-charge counts", "output": "dimensionless stoichiometric coefficients; exact inventory totals"}
                              if op_id == CHEMISTRY else {"input": "dimensionless", "output": "dimensionless; tree cost is an abstract count"}),
                    "sources": [], "examples": [{"arguments": example, "source": "usage example; not a panel result"}],
                    "implementation": {"backend": "oracle_native", "feature": "reasoning", "entrypoint": "reasoning_call",
                                       "native_catalog_schema": CATALOG_SCHEMA,
                                       "runtime_identity": self._identity,
                                       "native_catalog_sha256": self._catalog_digest},
                    "native_limits": copy.deepcopy(self._limits),
                    "adapter_limits": {"native_reply_bytes": MAX_REPLY_BYTES},
                    "limitations": LIMITATIONS + [limitation]}
            if op_id == CHEMISTRY:
                item["chemistry_limits"] = copy.deepcopy(self._chemistry_limits)
            if op_id == SHORTEST:
                item["path_limits"] = copy.deepcopy(self._path_limits)
            if item["availability"] == "unavailable":
                item["unavailable_reason"] = self.unavailable_reason or self._operation_unavailable.get(op_id, "native_operation_absent")
            rows.append(item)
        return rows

    def _output_schema(self, op_id):
        answered = {"status": {"const": "answered"}, "operation_id": {"const": op_id},
                    "result": copy.deepcopy(self._results[op_id]), "runtime_identity": _string(256),
                    "authority": {"const": "computation_only"}}
        if op_id == CHEMISTRY:
            answered.update(answer_kind={"type": "string", "enum": ["positive_balance", "mathematical_negative"]},
                            scope={"const": CHEMISTRY_SCOPE})
        branches = [_object(answered),
            _object({"status": {"const": "withheld"}, "operation_id": {"const": op_id},
                     "reason": _string(80), "detail": _string(512)},
                    required=["status", "operation_id", "reason"]),
        ]
        if op_id == CHEMISTRY:
            inconclusive = dict(answered, status={"const": "withheld"},
                                answer_kind={"const": "search_inconclusive"},
                                reason={"const": "positive_balance_search_inconclusive"})
            branches.append(_object(inconclusive))
        return {"anyOf": branches}

    def invoke(self, operation_id, arguments):
        if operation_id not in OPERATION_IDS:
            raise ValueError("unknown operation")
        if self._call is None:
            return self._withheld(operation_id, self.unavailable_reason)
        if operation_id not in self._available_ids:
            return self._withheld(operation_id, self._operation_unavailable.get(operation_id, "native_operation_absent"))
        self._validate_arguments(operation_id, arguments)
        request = json.dumps({"operation": operation_id, "arguments": arguments},
                             ensure_ascii=False, allow_nan=False, separators=(",", ":"))
        if len(request.encode("utf-8")) > self._limits["request_bytes"]:
            raise ValueError("encoded native request exceeds native byte limit")
        try:
            raw = self._call(request)
        except ValueError as error:
            # Native validation/resource/check failures are refusals. In
            # particular, post-search limits are not pre-work host validation.
            return self._withheld(operation_id, "native_request_refused", str(error)[:512] or "Native request refused.")
        except Exception:
            return self._withheld(operation_id, "native_execution_failed")
        try:
            maximum = min(MAX_REPLY_BYTES, self._path_limits["reply_bytes"]) if operation_id == SHORTEST else MAX_REPLY_BYTES
            result = _json(raw, maximum)
            if not _valid(result, self._results[operation_id]):
                raise ValueError("native result schema differs")
            if operation_id == SHORTEST:
                self._check_path_reply(arguments, result)
            if operation_id == CHEMISTRY:
                self._check_chemistry_reply(arguments, result)
        except Exception:
            return self._withheld(operation_id, "native_reply_invalid")
        reply = {"status": "answered", "operation_id": operation_id, "result": result,
                 "runtime_identity": self._identity, "authority": "computation_only"}
        if operation_id == CHEMISTRY:
            reply["scope"] = CHEMISTRY_SCOPE
            if result["status"] == "multiple_search_inconclusive":
                reply.update(status="withheld", answer_kind="search_inconclusive",
                             reason="positive_balance_search_inconclusive")
            else:
                reply["answer_kind"] = ("positive_balance" if result["coefficients"] is not None
                                        else "mathematical_negative")
        return reply

    @staticmethod
    def _check_path_reply(arguments, result):
        """Check transport coverage and edge-ID walks; Rust checks optimality."""
        vertices, edges = arguments["vertices"], arguments["edges"]
        def walk(path, start):
            if len(path) > vertices:
                raise ValueError("oversized witness walk")
            vertex, total = start, 0
            for edge_id in path:
                if edge_id >= len(edges) or edges[edge_id][0] != vertex:
                    raise ValueError("unknown or disconnected witness edge")
                _, vertex, weight = edges[edge_id]
                total += weight
            return vertex, total
        outcome = result["outcome"]
        if outcome == "finite":
            labels = result["labels"]
            if (len(labels) != vertices or labels[arguments["source"]] != "0"
                    or labels[arguments["target"]] != result["distance"]
                    or walk(result["path"], arguments["source"]) != (arguments["target"], int(result["distance"]))
                    or any(value is not None and not -(2**127) <= int(value) < 2**127 for value in labels)):
                raise ValueError("finite certificate transport differs from input")
        elif outcome == "unreachable":
            reachable = result["reachable"]
            if (len(reachable) != vertices or not reachable[arguments["source"]]
                    or reachable[arguments["target"]]
                    or any(reachable[a] and not reachable[z] for a, z, _ in edges)):
                raise ValueError("unreachable certificate differs from input")
        else:
            anchor, _ = walk(result["prefix"], arguments["source"])
            end, weight = walk(result["cycle"], anchor)
            if end != anchor or weight >= 0 or walk(result["suffix"], anchor)[0] != arguments["target"]:
                raise ValueError("negative-cycle witness differs from input")

    @staticmethod
    def _check_chemistry_reply(arguments, result):
        """Check transport shape/coverage, without recomputing rank or chemistry."""
        size = len(arguments["species"])
        nullity, status = result["nullity"], result["status"]
        if (result["rank"] + nullity != size or len(result["nullspace_basis"]) != nullity
                or any(len(vector) != size for vector in result["nullspace_basis"])
                or len(result["free_species_indices"]) != nullity
                or len(set(result["free_species_indices"])) != nullity
                or any(index >= size for index in result["free_species_indices"])):
            raise ValueError("native basis dimensions differ from supplied species")
        positive = status in ("unique_positive", "multiple_with_positive_candidate")
        if ((status == "no_nonzero_balance" and nullity != 0)
                or (status in ("unique_positive", "no_strictly_positive_balance") and nullity != 1)
                or (status.startswith("multiple_") and nullity < 2)):
            raise ValueError("native status differs from nullspace dimensions")
        if positive:
            rows = result["conservation"]
            labels = {"charge"}.union(*(set(row["composition"]) for row in arguments["species"]))
            if (result["coefficients"] is None or len(result["coefficients"]) != size
                    or len(rows) != len(labels) or {row["inventory"] for row in rows} != labels
                    or any(row["reactant"] != row["product"] for row in rows)):
                raise ValueError("positive native result lacks complete matching conservation diagnostics")
        elif result["coefficients"] is not None or result["conservation"]:
            raise ValueError("negative/inconclusive native result has candidate diagnostics")

    @staticmethod
    def _withheld(op_id, reason, detail=None):
        result = {"status": "withheld", "operation_id": op_id, "reason": reason}
        if detail is not None:
            result["detail"] = detail
        return result

    def _validate_arguments(self, op_id, arguments):
        schema = self._inputs[op_id]
        if (not isinstance(arguments, dict) or not set(schema["required"]) <= set(arguments)
                or not set(arguments) <= set(schema["properties"])):
            raise ValueError("unexpected or missing argument fields")
        if op_id == CHEMISTRY:
            species = arguments["species"]
            if not isinstance(species, list) or not 2 <= len(species) <= self._chemistry_limits["species"]:
                raise ValueError("species outside native chemistry range")
            names, sides, inventories = set(), set(), {"charge"}
            for row in species:
                if not isinstance(row, dict) or set(row) != {"name", "side", "composition", "charge"}:
                    raise ValueError("species fields differ from fixed chemistry schema")
                name, composition, charge = row["name"], row["composition"], row["charge"]
                if (not isinstance(name, str) or not name.strip() or len(name.encode("utf-8")) > 128
                        or name in names or row["side"] not in ("reactant", "product")
                        or type(charge) is not int or not I64_MIN <= charge <= I64_MAX
                        or not isinstance(composition, dict)
                        or len(composition) >= self._chemistry_limits["conserved_rows"]
                        or (not composition and charge != -1)):
                    raise ValueError("invalid supplied species name, side, composition or charge")
                names.add(name)
                sides.add(row["side"])
                for label, count in composition.items():
                    if (not isinstance(label, str) or re.fullmatch(r"[A-Z][a-z]?(?:-[1-9][0-9]{0,2})?", label) is None
                            or type(count) is not int or not 1 <= count <= 2**64 - 1):
                        raise ValueError("inventory labels/counts must be exact positive u64 declarations")
                    inventories.add(label)
                if len(inventories) > self._chemistry_limits["conserved_rows"]:
                    raise ValueError("supplied inventories exceed native chemistry range")
            if sides != {"reactant", "product"}:
                raise ValueError("both reaction sides are required")
            return
        if op_id in (ALGEBRA, DIMENSIONAL):
            expression = arguments["expression"]
            if not isinstance(expression, str) or not 1 <= len(expression) <= self._limits["request_bytes"]:
                raise ValueError("expression must be a bounded nonempty string")
            if op_id == DIMENSIONAL:
                annotations = arguments["variables"]
                if not isinstance(annotations, list) or len(annotations) > self._limits["expression_nodes"]:
                    raise ValueError("variables must be a bounded list of annotations")
                seen = set()
                for row in annotations:
                    if (not isinstance(row, dict) or not {"name", "dimension"} <= set(row)
                            or not set(row) <= {"name", "dimension", "kind"}
                            or not isinstance(row["name"], str) or len(row["name"]) > 64
                            or re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", row["name"]) is None
                            or row.get("kind", "linear") != "linear" or row["name"] in seen
                            or not _valid(row["dimension"], schema["properties"]["variables"]["items"]["properties"]["dimension"])):
                        raise ValueError("invalid or duplicate linear SI variable annotation")
                    seen.add(row["name"])
                if "output_dimension" in arguments and not _valid(arguments["output_dimension"], schema["properties"]["output_dimension"]):
                    raise ValueError("invalid requested SI output dimension")
            # Parsing and mathematical/type decisions belong to the native
            # provider. No Python expression evaluator or parser is selected.
            return
        vertices, edges = arguments["vertices"], arguments["edges"]
        if type(vertices) is not int or not 0 <= vertices <= self._limits["vertices"]:
            raise ValueError("vertices outside native range")
        if op_id == SHORTEST and (vertices < 1 or any(type(arguments[k]) is not int or not 0 <= arguments[k] < vertices for k in ("source", "target"))):
            raise ValueError("source/target outside nonempty supplied graph")
        if not isinstance(edges, list) or len(edges) > self._limits["edges"]:
            raise ValueError("edges outside native range")
        for edge in edges:
            if (not isinstance(edge, list) or len(edge) != 3
                    or any(type(value) is not int for value in edge)
                    or not 0 <= edge[0] < vertices or not 0 <= edge[1] < vertices
                    or not I64_MIN <= edge[2] <= I64_MAX):
                raise ValueError("edge must contain valid endpoints and an exact i64 weight")


def create_reasoning_operations(runtime, workspace, *, native_module, runtime_identity,
                                enabled=False, backend="oracle_native"):
    """Bind a host-selected module and identity; default remains disabled.

    Call once when the host builds its operation registry, on its existing
    runtime thread. The host owns module loading, deployment provenance,
    authorization, transport budgets and process containment. Neither a
    request nor a tenant can choose modules, identities or the enabled flag.
    """
    return ReasoningOperations(runtime, workspace, enabled=enabled, backend=backend,
                               native_module=native_module, runtime_identity=runtime_identity)
