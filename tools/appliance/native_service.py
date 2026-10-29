#!/usr/bin/env python3
"""Untrusted private-loopback service for explicitly admitted native exports.

Run: python3 tools/appliance/native_service.py --config /operator/native.json
The trusted bridge MUST isolate loopback from untrusted local processes and
supply X-Mini-Oracle-Tenant itself. That header is routing, not authentication.
Pure profiles compute supplied arguments. Runtime profiles add operator-fixed
images and durable native conversations/replay without a Python Engine. Only operator config
selects artifact paths, hashes, profiles and limits; requests cannot enable code.
"""
from __future__ import annotations
import argparse
from contextvars import ContextVar
from dataclasses import dataclass
import json
from pathlib import Path
import signal
import sys
import threading
import types

from native_pool import NativePool, NativeProvider, NativeLimits, NativePoolError, SolverResource
from native_worker import decode
from native_runtime import RuntimeProfile
from operations import Operations, OperationError
from serve import Server, TENANT_KEY, IDENTIFIER, encode, failure

# Repository-local Python adapters, never a request-selected import location.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from oracle_components.native_science import NativeScienceOperations
from oracle_components.native_incremental import NativeIncrementalOperations
from oracle_components.native_bio import NativeBioOperations
from oracle_components.native_statistics import NativeStatisticsOperations
from oracle_components.native_runtime_adapter import NativeRuntimeOperations
from oracle_components.reasoning import create_reasoning_operations
from oracle_components.logic import NativeLogicOperations

_CONTEXT = ContextVar("native_service_request", default=None)


@dataclass(frozen=True)
class ServiceConfig:
    max_request_bytes: int = 1048576
    max_reply_bytes: int = 2097152
    # Operations(None, ...) only uses this to construct an inert descriptor path.
    data_root: Path = Path("/nonexistent-native-service-data")


class NativeService:
    """One immutable registry and bounded native pool shared by all bridge users."""
    def __init__(self, providers, limits=NativeLimits(), *, pool_factory=NativePool):
        self.config = ServiceConfig(limits.request_bytes, limits.reply_bytes)
        self.stopping = False
        self.cancellation = threading.Event()
        self.pool = pool_factory(providers, limits)
        admitted = []
        self.admissions = []
        self.pool_provider_profiles = {provider.id: provider.profile for provider in providers}
        try:
            for provider in providers:
                catalog_reply = self.pool.catalog("operator-startup", provider.id, cancellation=self.cancellation)
                catalog = catalog_reply.reply
                identity = provider.sha256 + ":" + provider.profile
                self.admissions.append({"provider_id": provider.id, "admission": catalog_reply.admission,
                                        "containment": catalog_reply.containment})
                call = self._bound_call(provider.id)
                if provider.profile == "reasoning":
                    def reasoning_call(raw, call=call):
                        return json.dumps(call(decode(raw)), ensure_ascii=False, allow_nan=False, separators=(",", ":"))
                    proxy = types.SimpleNamespace(__name__="oracle_native", reasoning_call=reasoning_call,
                                                  reasoning_catalog=lambda catalog=catalog: json.dumps(catalog, allow_nan=False))
                    adapter = create_reasoning_operations(None, None, native_module=proxy,
                                                          runtime_identity=identity, enabled=True)
                elif provider.profile == "science":
                    adapter = NativeScienceOperations(catalog, call, identity)
                elif provider.profile == "incremental":
                    adapter = NativeIncrementalOperations(catalog, call, identity)
                elif provider.profile == "bio":
                    adapter = NativeBioOperations(catalog, call, identity)
                elif provider.profile == "statistics":
                    adapter = NativeStatisticsOperations(catalog, call, identity)
                elif provider.profile == "logic":
                    adapter = NativeLogicOperations(catalog, self._tenant_scoped(call), identity, provider.solver.sha256)
                elif provider.profile == "runtime":
                    adapter = NativeRuntimeOperations(catalog, call, identity)
                else:
                    raise ValueError("unknown native profile")
                # Only actual callable exports enter discovery. A malformed or
                # unsupported catalog is startup failure, never a fake live route.
                declarations = [item for item in adapter.catalog() if item["availability"] == "live_direct"]
                if not declarations:
                    raise ValueError("configured native profile has no supported callable operations")
                admitted.append((adapter, declarations))
            if not admitted:
                raise ValueError("at least one native provider is required")
            self.runtime_operations = {declaration["id"] for adapter, declarations in admitted
                                       if isinstance(adapter, NativeRuntimeOperations) for declaration in declarations}
            self.stateful_operations = self.runtime_operations.intersection({"graph.execute", "kqa.execute", "reader.execute"})
            self.operations = Operations(None, self.config)
            for adapter, declarations in admitted:
                self.operations.register_provider(adapter, declarations=declarations)
        except BaseException:
            self.pool.close()
            raise

    def _bound_call(self, provider_id):
        def call(request):
            context = _CONTEXT.get()
            if context is None:
                raise RuntimeError("host request context required")
            try:
                options = {"cancellation": self.cancellation}
                if self.pool_provider_profiles[provider_id] == "runtime":
                    options["host_context"] = {key: context[key] for key in ("tenant", "request_id", "conversation_id")}
                result = self.pool.execute(context["tenant"], provider_id, request, **options)
            except NativePoolError as error:
                # Existing reasoning adapter converts exceptions to withholding;
                # preserve host admission failures for the outer HTTP boundary.
                context["errors"].append(error)
                raise
            context["receipts"].append({"admission": result.admission, "containment": result.containment})
            return result.reply
        return call

    @staticmethod
    def _tenant_scoped(call):
        """A logic program's scope.tenant must be the host-assigned tenant."""
        def scoped(request):
            context = _CONTEXT.get()
            if context is None:
                raise RuntimeError("host request context required")
            if request["arguments"]["scope"]["tenant"] != context["tenant"]:
                raise OperationError("tenant_scope_mismatch", 403)
            return call(request)
        return scoped

    @staticmethod
    def _tenant(tenant):
        if not isinstance(tenant, str) or not TENANT_KEY.fullmatch(tenant):
            raise OperationError("host_tenant_required", 400)

    @property
    def backend(self):
        return "native_runtime_and_providers" if self.runtime_operations else "pure_native_providers"

    def health(self):
        pool_health = self.pool.health()
        return {**pool_health, "ready": pool_health["ready"] and not self.stopping,
                "backend": self.backend, "durable_replay": bool(self.stateful_operations)}

    def capabilities(self, tenant):
        try:
            self._tenant(tenant)
        except OperationError as error:
            return error.status, failure(error.code)
        return 200, {"protocol": "oracle-appliance-v1", "backend": self.backend,
            "operation_discovery": {"protocol": "oracle-operations-v1", "list": "/operations",
                "detail": "/operations/{operation_id}", "invoke": "/invoke", "state": "ready",
                "counts": {"live_direct": len(self.operations.items), "text_only": 0, "unavailable": 0}},
            "scope": "operator-admitted native operations; host-assigned tenant admission",
            "durable_conversations": bool(self.stateful_operations), "durable_replay": bool(self.stateful_operations),
            "durable_operations": sorted(self.stateful_operations),
            "request_id_semantics": ("stateful native turns: exact core reply replay; pure calls: correlation only"
                                     if self.stateful_operations else "correlation only; retries recompute"),
            "tenant_header_authentication": False, "mini_qualified": False,
            "providers": self.admissions}

    def discover(self, tenant, parameters):
        try:
            self._tenant(tenant)
            if self.stopping:
                raise OperationError("service_stopping", 503)
            return 200, self.operations.discover(**parameters)
        except OperationError as error:
            return error.status, failure(error.code, **error.details)

    def request(self, tenant, raw, path, method="POST"):
        if method != "POST" or path != "/invoke":
            return 404, failure("not_found")
        if len(raw) > self.config.max_request_bytes:
            return 413, failure("request_too_large")
        try:
            self._tenant(tenant)
            request = decode(raw)
            if not isinstance(request, dict) or set(request) != {"request_id", "conversation_id", "operation_id", "arguments"}:
                raise ValueError("invalid envelope")
            if any(not isinstance(request[k], str) or not IDENTIFIER.fullmatch(request[k]) for k in ("request_id", "conversation_id")):
                raise ValueError("invalid identifiers")
            if not isinstance(request["operation_id"], str) or not isinstance(request["arguments"], dict):
                raise ValueError("invalid invocation")
            encode(request)  # reject lone surrogates throughout arguments
        except OperationError as error:
            return error.status, failure(error.code)
        except (ValueError, TypeError, UnicodeError, RecursionError):
            return 400, failure("invalid_request")
        if self.stopping:
            return 503, failure("service_stopping")
        context = {"tenant": tenant, "request_id": request["request_id"], "conversation_id": request["conversation_id"],
                   "receipts": [], "errors": []}
        stateful = request["operation_id"] in self.stateful_operations
        token = _CONTEXT.set(context)
        try:
            reply = self.operations.invoke(request["operation_id"], request["arguments"], request["conversation_id"])
            if context["errors"]:
                raise context["errors"][0]
            result = {"outcome": "completed", "operation_id": request["operation_id"], "reply": reply,
                      "native_execution": context["receipts"], "durable_replay": stateful}
            if len(encode(result)) > self.config.max_reply_bytes:
                return 502, failure("reply_too_large", execution_completed=True, state_may_have_changed=stateful,
                                    retryable=stateful, exact_retry_required=stateful)
            return 200, result
        except OperationError as error:
            if request["operation_id"] in self.runtime_operations and context["receipts"]:
                return 502, failure("native_adapter_invalid_reply", state_may_have_changed=stateful,
                                    retryable=stateful, exact_retry_required=stateful)
            return error.status, failure(error.code, **error.details)
        except NativePoolError as error:
            status = (409 if error.code == "runtime_conflict" else
                      429 if error.code in ("pool_busy", "tenant_busy", "runtime_busy") else 503)
            if error.code == "native_refused" and request["operation_id"] not in self.runtime_operations:
                withheld = {"status": "withheld", "operation_id": request["operation_id"],
                            "reason": "native_request_refused"}
                if error.detail is not None:
                    withheld["detail"] = error.detail
                if request["operation_id"].startswith(("science.", "incremental.", "bio.", "statistics.", "logic.")):
                    withheld["authority"] = "computation_only"
                return 200, {"outcome": "completed", "operation_id": request["operation_id"],
                             "reply": withheld, "durable_replay": False}
            uncertain = stateful and error.code not in ("pool_busy", "tenant_busy", "runtime_busy", "runtime_conflict", "native_start_failed")
            return status, failure(error.code, retryable=status == 429 or uncertain,
                                   state_may_have_changed=uncertain, exact_retry_required=uncertain)
        except (ValueError, TypeError, UnicodeError, RecursionError):
            return 502, failure("native_adapter_invalid_reply", state_may_have_changed=stateful,
                                retryable=stateful, exact_retry_required=stateful)
        finally:
            _CONTEXT.reset(token)

    def close(self):
        self.stopping = True
        self.cancellation.set()
        self.pool.close()


def read_config(path):
    with Path(path).open("rb") as stream:
        raw = stream.read(65537)
    if len(raw) > 65536:
        raise ValueError("operator configuration exceeds 64 KiB")
    document = decode(raw)
    if not isinstance(document, dict) or set(document) - {"schema", "providers", "limits", "port"} or document.get("schema") != 1:
        raise ValueError("unsupported operator configuration")
    port = document.get("port", 7071)
    if type(port) is not int or not 0 <= port <= 65535:
        raise ValueError("invalid loopback port")
    rows = document.get("providers")
    if not isinstance(rows, list) or not 1 <= len(rows) <= 128:
        raise ValueError("invalid provider list")
    providers = []
    for row in rows:
        required = {"id", "extension", "sha256", "profile"}
        if (not isinstance(row, dict) or set(row) not in (required, required | {"runtime"}, required | {"solver"})
                or any(not isinstance(row[k], str) for k in required)):
            raise ValueError("invalid provider declaration")
        if (row["profile"] == "logic") != ("solver" in row):
            raise ValueError("logic provider requires exactly one operator solver resource")
        solver = None
        if "solver" in row:
            entry = row["solver"]
            if (not isinstance(entry, dict) or set(entry) != {"path", "sha256"}
                    or any(not isinstance(entry[k], str) for k in entry) or not Path(entry["path"]).is_absolute()):
                raise ValueError("logic solver requires an absolute path and SHA-256")
            # NativePool hashes and snapshots these bytes at startup; mismatch fails startup.
            solver = SolverResource(Path(entry["path"]), entry["sha256"])
        if not Path(row["extension"]).is_absolute():
            raise ValueError("operator extension path must be absolute")
        if (row["profile"] == "runtime") != ("runtime" in row):
            raise ValueError("runtime provider requires operator runtime configuration")
        runtime = RuntimeProfile.from_dict(row["runtime"]) if "runtime" in row else None
        providers.append(NativeProvider(**{**row, "extension": Path(row["extension"]), "runtime": runtime, "solver": solver}))
    options = document.get("limits", {})
    if not isinstance(options, dict):
        raise ValueError("invalid limits")
    try:
        limits = NativeLimits(**options)
    except TypeError as error:
        raise ValueError("unknown native limit") from error
    return providers, limits, port


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    args = parser.parse_args()
    providers, limits, port = read_config(args.config)
    service = NativeService(providers, limits)
    server = None
    try:
        server = Server(("127.0.0.1", port), service, tenant_pool=True)
        def stop(*_):
            service.stopping = True
            service.cancellation.set()
            threading.Thread(target=server.shutdown, daemon=True).start()
        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        print(json.dumps({"listening": f"http://127.0.0.1:{server.server_port}",
                          "backend": service.backend, "durable_replay": bool(service.stateful_operations)}), flush=True)
        server.serve_forever(poll_interval=0.2)
    finally:
        service.cancellation.set()
        if server is not None:
            server.server_close()
        service.close()


if __name__ == "__main__":
    main()
