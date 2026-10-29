#!/usr/bin/env python3
"""Untrusted private-loopback service for explicitly admitted pure native exports.

Run: python3 tools/appliance/native_service.py --config /operator/native.json
The trusted bridge MUST isolate loopback from untrusted local processes and
supply X-Mini-Oracle-Tenant itself. That header is routing, not authentication.
No Engine, tenant worker, public data load, durable conversation or replay journal
is created. Reusing request_id does fresh computation. Only the operator config
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

from native_pool import NativePool, NativeProvider, NativeLimits, NativePoolError
from native_worker import decode
from operations import Operations, OperationError
from serve import Server, TENANT_KEY, IDENTIFIER, encode, failure

# Repository-local Python adapters, never a request-selected import location.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from oracle_components.native_science import NativeScienceOperations
from oracle_components.native_incremental import NativeIncrementalOperations
from oracle_components.reasoning import create_reasoning_operations

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
                        return json.dumps(call(decode(raw)), ensure_ascii=False, allow_nan=False)
                    proxy = types.SimpleNamespace(__name__="oracle_native", reasoning_call=reasoning_call,
                                                  reasoning_catalog=lambda catalog=catalog: json.dumps(catalog, allow_nan=False))
                    adapter = create_reasoning_operations(None, None, native_module=proxy,
                                                          runtime_identity=identity, enabled=True)
                elif provider.profile == "science":
                    adapter = NativeScienceOperations(catalog, call, identity)
                elif provider.profile == "incremental":
                    adapter = NativeIncrementalOperations(catalog, call, identity)
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
                result = self.pool.execute(context["tenant"], provider_id, request,
                                           cancellation=self.cancellation)
            except NativePoolError as error:
                # Existing reasoning adapter converts exceptions to withholding;
                # preserve host admission failures for the outer HTTP boundary.
                context["errors"].append(error)
                raise
            context["receipts"].append({"admission": result.admission, "containment": result.containment})
            return result.reply
        return call

    @staticmethod
    def _tenant(tenant):
        if not isinstance(tenant, str) or not TENANT_KEY.fullmatch(tenant):
            raise OperationError("host_tenant_required", 400)

    def health(self):
        pool_health = self.pool.health()
        return {**pool_health, "ready": pool_health["ready"] and not self.stopping,
                "backend": "pure_native_providers", "durable_replay": False}

    def capabilities(self, tenant):
        try:
            self._tenant(tenant)
        except OperationError as error:
            return error.status, failure(error.code)
        return 200, {"protocol": "oracle-appliance-v1", "backend": "pure_native_providers",
            "operation_discovery": {"protocol": "oracle-operations-v1", "list": "/operations",
                "detail": "/operations/{operation_id}", "invoke": "/invoke", "state": "ready",
                "counts": {"live_direct": len(self.operations.items), "text_only": 0, "unavailable": 0}},
            "scope": "pure computations on supplied arguments; host-assigned tenant admission",
            "durable_conversations": False, "durable_replay": False, "request_id_semantics": "correlation only; retries recompute",
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
        context = {"tenant": tenant, "receipts": [], "errors": []}
        token = _CONTEXT.set(context)
        try:
            reply = self.operations.invoke(request["operation_id"], request["arguments"], request["conversation_id"])
            if context["errors"]:
                raise context["errors"][0]
            result = {"outcome": "completed", "operation_id": request["operation_id"], "reply": reply,
                      "native_execution": context["receipts"], "durable_replay": False}
            if len(encode(result)) > self.config.max_reply_bytes:
                return 502, failure("reply_too_large", execution_completed=True, state_may_have_changed=False)
            return 200, result
        except OperationError as error:
            return error.status, failure(error.code, **error.details)
        except NativePoolError as error:
            status = 429 if error.code in ("pool_busy", "tenant_busy") else 503
            if error.code == "native_refused":
                withheld = {"status": "withheld", "operation_id": request["operation_id"],
                            "reason": "native_request_refused"}
                if error.detail is not None:
                    withheld["detail"] = error.detail
                if request["operation_id"].startswith(("science.", "incremental.")):
                    withheld["authority"] = "computation_only"
                return 200, {"outcome": "completed", "operation_id": request["operation_id"],
                             "reply": withheld, "durable_replay": False}
            return status, failure(error.code, retryable=status == 429, state_may_have_changed=False)
        except (ValueError, TypeError, UnicodeError, RecursionError):
            return 502, failure("native_adapter_invalid_reply", state_may_have_changed=False)
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
        if not isinstance(row, dict) or set(row) != {"id", "extension", "sha256", "profile"} or any(not isinstance(v, str) for v in row.values()):
            raise ValueError("invalid provider declaration")
        if not Path(row["extension"]).is_absolute():
            raise ValueError("operator extension path must be absolute")
        providers.append(NativeProvider(**{**row, "extension": Path(row["extension"])}))
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
                          "backend": "pure_native_providers", "durable_replay": False}), flush=True)
        server.serve_forever(poll_interval=0.2)
    finally:
        service.cancellation.set()
        if server is not None:
            server.server_close()
        service.close()


if __name__ == "__main__":
    main()
