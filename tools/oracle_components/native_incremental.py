"""Untrusted finite dependency batches; no hosted persistent subscription.

The scope argument is an echoed user label, never tenant authority. A supplied
complete finite graph is the only coverage premise. Native code decides graph
and version semantics and owns all temporary arrangements.
"""
from __future__ import annotations
from .native_science import NativeStructuredOperations, obj, array, string, positive_limits

NODE = {"type": "integer", "minimum": 0, "maximum": 2**32-1}


class NativeIncrementalOperations(NativeStructuredOperations):
    def __init__(self, catalog, call, identity):
        super().__init__(catalog, call, identity)
        limits = positive_limits(catalog, ("max_nodes", "max_epochs", "max_mutations", "max_queries", "max_id_bytes", "max_live_facts"))
        if catalog.get("schema") != 1 or catalog.get("provider") != "oracle-incremental" or not {"insert", "retract", "reachable", "impact"} <= set(catalog.get("operations", [])):
            raise ValueError("unsupported incremental catalog")
        mutation = {"anyOf": [obj({"op": {"const": "insert"}, "fact_id": string(limits["max_id_bytes"]), "from": NODE, "to": NODE}),
                              obj({"op": {"const": "retract"}, "fact_id": string(limits["max_id_bytes"])})]}
        query = {"anyOf": [obj({"op": {"const": "reachable"}, "from": NODE, "to": NODE}),
                    obj({"op": {"const": "impact"}, "roots": array(NODE, limits["max_nodes"]),
                         "direction": {"type": "string", "enum": ["upstream", "downstream"]}, "include_roots": {"type": "boolean"}}, ["op", "roots", "direction"])]}
        epoch = obj({"version": {"type": "integer", "minimum": 0, "maximum": 2**64-2},
                     "mutations": array(mutation, limits["max_mutations"]), "queries": array(query, limits["max_queries"])}, ["version", "mutations"])
        graph = obj({"scope": string(limits["max_id_bytes"]), "nodes": array(NODE, limits["max_nodes"]),
                     "epochs": array(epoch, limits["max_epochs"])})
        example = {"scope": "supplied-build-graph", "nodes": [0, 1], "epochs": [
            {"version": 1, "mutations": [{"op": "insert", "fact_id": "dependency", "from": 0, "to": 1}],
             "queries": [{"op": "reachable", "from": 0, "to": 1}]},
            {"version": 2, "mutations": [{"op": "retract", "fact_id": "dependency"}],
             "queries": [{"op": "reachable", "from": 0, "to": 1}]}]}
        self.add("incremental.dependencies", graph,
                 "Evaluate finite versioned dependency inserts, independent supports, retractions, reachability and impact against the complete supplied node universe.", example,
                 ["All-pairs closure may be quadratic. No facts or subscriptions survive a call. Absent external knowledge is never treated as false.",
                  "Scope is a descriptive label. Versions must strictly increase. Aggregate mutation/query and state limits are enforced by native admission."])
        if "rooted_v2" in catalog.get("versioned_operations", []):
            roots = obj({"downstream": array(NODE, limits["max_nodes"]), "upstream": array(NODE, limits["max_nodes"])})
            self.add("incremental.rooted_dependencies", obj({"roots": roots, "graph": graph}),
                     "Evaluate only paths demanded by fixed upstream/downstream roots, with host-selected fresh execution and explicit settlement evidence.",
                     {"roots": {"downstream": [0], "upstream": []}, "graph": example},
                     ["Queries must fit the declared roots. Fresh settlement is a closed finite version, not a timely frontier claim. No performance advantage is asserted."])

    @staticmethod
    def request(operation, arguments):
        if operation == "incremental.dependencies":
            return arguments
        return {"operation": "rooted_v2", **arguments}

    def interpret(self, operation, result):
        if result.get("status") == "refused" and isinstance(result.get("error"), dict):
            return self.withheld(operation, "native_request_refused", result)
        if result.get("status") != "ok" or not isinstance(result.get("result"), dict):
            return self.withheld(operation, "native_reply_invalid")
        body = result["result"]
        graph = body.get("result") if operation == "incremental.rooted_dependencies" else body
        if not isinstance(graph, dict) or not isinstance(graph.get("epochs"), list) or any(
                not isinstance(epoch, dict) or epoch.get("settled") is not True for epoch in graph["epochs"]):
            return self.withheld(operation, "native_unsettled_or_invalid_reply", result)
        return self.answered(operation, body, "finite_supplied_graph_computation")
