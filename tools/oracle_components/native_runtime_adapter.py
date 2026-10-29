"""Untrusted discovery/response adapter for a host-admitted native data runtime.

The host closure injects tenant and canonical outer invocation IDs. It imports
no extension and grants no path, release, tenant, effects or code authority.
"""
from __future__ import annotations
import copy
import json
import re
from .native_science import obj, string

SCHEMA = "oracle-native-runtime-host-v1"
OPERATIONS = {"graph.query": ("plan_json", False), "graph.execute": ("plan_json", True),
              "kqa.query": ("program_json", False), "kqa.execute": ("program_json", True),
              "reader.whole": ("question", False), "reader.execute": ("question", True)}
HASH = re.compile(r"[0-9a-f]{64}\Z")


class NativeRuntimeOperations:
    def __init__(self, catalog, call, identity):
        self.native_catalog, self.call = copy.deepcopy(catalog), call
        if (not isinstance(catalog, dict) or catalog.get("schema") != SCHEMA
                or catalog.get("durable_replay") is not True
                or any(not isinstance(catalog.get(k), str) or not HASH.fullmatch(catalog[k])
                       for k in ("runtime_identity", "image_sha256", "resource_identity"))
                or not isinstance(catalog.get("operations"), list) or not catalog["operations"]
                or any(op not in OPERATIONS for op in catalog["operations"])
                or len(set(catalog["operations"])) != len(catalog["operations"])
                or not isinstance(catalog.get("limits"), dict)
                or type(catalog["limits"].get("request_bytes")) is not int
                or not 1 <= catalog["limits"]["request_bytes"] <= 2**63 - 1):
            raise ValueError("unsupported native runtime catalog")
        self.identity = catalog["runtime_identity"]
        self.declarations = {}
        for operation in catalog["operations"]:
            field, stateful = OPERATIONS[operation]
            properties = {field: string(catalog["limits"]["request_bytes"])}
            if stateful:
                properties["expected_version"] = {"type": "integer", "minimum": 0, "maximum": 2**63 - 2}
            example = ({"question": "Who is Alice?"} if field == "question" else
                       {"plan_json": '{"nodes":[{"op":"find","name":"Alice"}],"output":0,"projection":{"kind":"unique_name"}}'}
                       if field == "plan_json" else {"program_json": '[{"function":"Find","dependencies":[],"inputs":["Alice"]},{"function":"What","dependencies":[0],"inputs":[]}]'})
            if stateful:
                example["expected_version"] = 0
            self.declarations[operation] = {"id": operation, "name": operation.replace(".", " "),
                "description": ("Commit a bounded native data/language turn and retain its exact reply for retry."
                                if stateful else "Read the operator's fixed native data image without changing session state."),
                "availability": "live_direct", "input_schema": obj(properties),
                "output_schema": {"type": "object", "description":
                    "Authoritative exact core_reply_json and bounded core_metadata, with committed version even when withheld. JSON numeric tokens in core_reply_json are exact; no decoded numerical body is returned."},
                "examples": [{"arguments": example, "source": "Manufactured usage example; no panel score."}],
                "sources": [], "implementation": {"backend": "oracle_native_runtime",
                    "runtime_identity": self.identity, "resource_identity": catalog["resource_identity"],
                    "image_sha256": catalog["image_sha256"], "artifact_profile_identity": identity},
                "durable_replay": stateful,
                "limitations": ["Untrusted host boundary; no new theorem, specialist-panel score or signed Mini qualification.",
                    "Operator image and admitted release only; no full Oracle Engine, teaching or external effects.",
                    "Host supplies tenant and outer request/conversation IDs; the private tenant header is not authentication.",
                    "Exact native reply bytes replay. HTTP wrapper/containment metadata need not be byte-identical.",
                    "Retry stateful calls with the same outer IDs, exact input string and expected_version after response loss."
                    if stateful else "Pure calls do not retain a retry reply or change the previous selection."]}

    def catalog(self):
        return copy.deepcopy(list(self.declarations.values()))

    def invoke(self, operation, arguments):
        if operation not in self.declarations:
            raise ValueError("unknown runtime operation")
        result = self.call({"operation": operation, "arguments": arguments})
        if (not isinstance(result, dict) or result.get("schema") != SCHEMA
                or result.get("operation") != operation
                or result.get("runtime_identity") != self.identity
                or result.get("resource_identity") != self.native_catalog["resource_identity"]
                or result.get("stateful") is not OPERATIONS[operation][1]
                or not isinstance(result.get("core_reply_json"), str)):
            raise ValueError("native runtime reply invalid")
        # Numbers remain inert lexical tokens. In particular 1e1000 never
        # becomes infinity and precise decimals never become rounded answers.
        class JsonNumber(str):
            pass
        def pairs(rows):
            value = {}
            for key, item in rows:
                if key in value:
                    raise ValueError("duplicate native reply key")
                value[key] = item
            return value
        def constant(_):
            raise ValueError("non-finite native JSON")
        core = json.loads(result["core_reply_json"], parse_int=JsonNumber, parse_float=JsonNumber,
                          parse_constant=constant, object_pairs_hook=pairs)
        if not isinstance(core, dict):
            raise ValueError("native runtime reply must be an object")
        stateful = OPERATIONS[operation][1]
        version = None
        if stateful:
            token = core.get("version")
            if (type(token) is not JsonNumber or not re.fullmatch(r"(?:0|[1-9][0-9]{0,18})", token)
                    or int(token) != arguments["expected_version"] + 1 or int(token) >= 2**63):
                raise ValueError("native runtime version invalid")
            version = int(token)
            payload = core.get("language" if operation == "reader.execute" else "result")
        else:
            payload = core
        if not isinstance(payload, dict) or type(payload.get("image")) is not str or payload.get("image") != self.native_catalog["image_sha256"]:
            raise ValueError("native runtime result image invalid")
        coverage = payload.get("coverage")
        if type(coverage) is not str or not 1 <= len(coverage.encode("utf-8")) <= 160:
            raise ValueError("native runtime coverage invalid")
        metadata = {"image": payload["image"], "coverage": coverage}
        reason = None
        if operation.startswith("reader."):
            status = payload.get("status")
            if type(status) is not str or status not in ("answered", "unknown", "ambiguous", "refused"):
                raise ValueError("native language status invalid")
            metadata["semantic_status"] = status
            if status != "answered":
                reason = payload.get("reason") or status
        elif isinstance(payload.get("value"), dict):
            status = payload["value"].get("status")
            if status in ("absent", "ambiguous", "incomparable", "ambiguous_operands", "incomplete"):
                reason = status
            if type(status) is str and len(status.encode("utf-8")) <= 80:
                metadata["semantic_status"] = status
        if reason is not None and (type(reason) is not str or len(reason.encode("utf-8")) > 80):
            raise ValueError("native runtime reason invalid")
        reply = {"status": "withheld" if reason else "answered", "operation_id": operation,
                 "authority": "sourced_data", "runtime_identity": self.identity,
                 "resource_identity": self.native_catalog["resource_identity"], "stateful": stateful,
                 "core_metadata": metadata, "core_reply_json": result["core_reply_json"]}
        if stateful:
            reply["version"] = version
        if reason:
            reply["reason"] = reason
        return reply
