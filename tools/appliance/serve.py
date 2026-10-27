#!/usr/bin/env python3
"""Untrusted transport for Oracle7 Engine.chat; no Mini admission or proof authority.

One process belongs to one host-assigned workspace. This is a private loopback
backend, not an authenticated public service. No Workbench entrypoint is loaded.
Optional tenant-pool mode bounds resident workers across host-assigned workspaces.
"""
from __future__ import annotations

import argparse
import fcntl
import hashlib
import importlib.util
import json
import math
import multiprocessing
import os
from pathlib import Path, PurePosixPath
import re
import signal
import socket
import sqlite3
import sys
import threading
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit
# Adapter modules live beside immutable packaged source as well.
sys.dont_write_bytecode = True
from operations import Operations, OperationError, ID as OPERATION_ID

REVISION = "083e3a6c0e2cfc131e62bdc16cb4ec1346194635"
PH = Path("fable-content/oracle-m-series-2026-08-15")
IDENTIFIER = re.compile(r"[A-Za-z0-9_-]{1,80}\Z")
TENANT_HEADER = "X-Mini-Oracle-Tenant"
TENANT_KEY = re.compile(r"[0-9a-f]{64}\Z")


def encode(value):
    return json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode("utf-8")


def failure(code, **fields):
    return {"outcome": "error", "error": code, **fields}


@dataclass(frozen=True)
class Config:
    runtime: Path
    data_root: Path
    workspace: Path
    source_revision: str = REVISION
    max_request_bytes: int = 16384
    max_reply_bytes: int = 2097152
    max_requests: int = 10000
    query_timeout: float = 120.0
    startup_timeout: float = 120.0
    shutdown_timeout: float = 5.0


def deployment_identity(config):
    """Capture small receipt metadata once; hash the receipt, not its files."""
    path = config.runtime / "APPLIANCE.json"
    try:
        with path.open("rb") as stream:
            raw = stream.read(4 * 1024 * 1024 + 1)
    except FileNotFoundError:
        return None  # source-only runs and transport fixtures need no receipt
    if len(raw) > 4 * 1024 * 1024:
        raise ValueError("APPLIANCE.json exceeds 4 MiB")
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError("duplicate receipt key")
            result[key] = value
        return result
    try:
        receipt = json.loads(raw, object_pairs_hook=pairs,
                             parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
        if not isinstance(receipt, dict) or receipt.get("schema") != 1:
            raise ValueError("unsupported receipt schema")
        if receipt.get("source_revision") != config.source_revision:
            raise ValueError("receipt base revision disagrees with configured revision")
        patches = receipt.get("patches", [])
        if not isinstance(patches, list) or len(patches) > 64:
            raise ValueError("invalid receipt patches")
        summary_patches = []
        for item in patches:
            if not isinstance(item, dict) or not isinstance(item.get("name"), str) or not 1 <= len(item["name"]) <= 256:
                raise ValueError("invalid patch name")
            if not isinstance(item.get("sha256"), str) or not re.fullmatch(r"[0-9a-f]{64}", item["sha256"]):
                raise ValueError("invalid patch hash")
            summary_patches.append({"name": item["name"], "sha256": item["sha256"]})
        overlay = receipt.get("kernel_overlay")
        overlay_sha = None
        if overlay is not None:
            if not isinstance(overlay, dict) or not isinstance(overlay.get("manifest_sha256"), str) or not re.fullmatch(r"[0-9a-f]{64}", overlay["manifest_sha256"]):
                raise ValueError("invalid kernel overlay identity")
            overlay_sha = overlay["manifest_sha256"]
        summary = {
            "receipt_sha256": hashlib.sha256(raw).hexdigest(),
            "base_source_revision": receipt["source_revision"],
            "patches": summary_patches,
            "kernel_overlay_manifest_sha256": overlay_sha,
            "kernel_base_revision": receipt.get("kernel_base_revision"),
            "kernel_source_revision": receipt.get("kernel_source_revision"),
            "kernel_families": receipt.get("kernel_families"),
            "kernel_platform": receipt.get("kernel_platform"),
            "metadata_verified_by_adapter": False,
            "verification": "Receipt bytes hashed only; deployment contents require independent host verification.",
        }
        for key in ("kernel_base_revision", "kernel_source_revision"):
            if summary[key] is not None and (not isinstance(summary[key], str) or not re.fullmatch(r"[0-9a-f]{40}", summary[key])):
                raise ValueError("invalid kernel revision")
        if summary["kernel_platform"] is not None and (not isinstance(summary["kernel_platform"], str) or len(summary["kernel_platform"]) > 128):
            raise ValueError("invalid kernel platform")
        count = summary["kernel_families"]
        if count is not None and (type(count) is not int or not 0 <= count <= 4096):
            raise ValueError("invalid kernel family count")
        if len(encode(summary)) > 16384:
            raise ValueError("deployment identity exceeds 16 KiB")
        return summary
    except (ValueError, UnicodeError, RecursionError) as error:
        raise ValueError("invalid APPLIANCE.json: " + str(error)) from error


def validate_paths(config):
    workspace = config.workspace.resolve()
    for root in (config.runtime.resolve(), config.data_root.resolve()):
        if workspace == root or root in workspace.parents or workspace in root.parents:
            raise ValueError("workspace and runtime/data roots must be mutually disjoint")


def preflight(config):
    """Check presence/size only. Deployment separately verifies content hashes."""
    if config.source_revision != REVISION:
        raise ValueError("this adapter supports only Oracle7 slim revision " + REVISION)
    if not (config.runtime / "oracle7.py").is_file():
        raise ValueError("missing oracle7.py")
    manifest = json.loads((config.runtime / "PACK_MANIFEST.json").read_text())
    if not manifest.get("files"):
        raise ValueError("empty PACK_MANIFEST")
    for item in manifest["files"]:
        path = PurePosixPath(item["path"])
        if path.is_absolute() or ".." in path.parts or path.parts[0] != "root":
            raise ValueError("unsafe store manifest path")
        target = config.data_root.joinpath(*path.parts[1:])
        if not target.is_file() or target.stat().st_size != item["size"]:
            raise ValueError("unprovisioned store: " + item["path"])
    # ORACLE7_ROOT is the complete root view: small source/data plus store mounts.
    head = config.data_root / PH / "self_loop/admitted/HEAD_MANIFEST.json"
    if not head.is_file() or not (config.data_root / "wander-train").is_dir():
        raise ValueError("data root must include the complete Oracle7 root view")


def import_launcher(config):
    """Import the real launcher, without main(), CLI, setup(), or Workbench."""
    state = config.workspace / "oracle-state"
    for name, value in {
        "ORACLE7_ROOT": config.data_root,
        "ORACLE7_STATE": state,
        "ORACLE7_WORKBENCH_LOCAL": config.workspace / "workbench-local",
        "SPECBUILD_HOME": config.workspace / "specbuild",
    }.items():
        if name != "ORACLE7_ROOT":
            Path(value).mkdir(parents=True, exist_ok=True)
        os.environ[name] = str(value)
    # Relative writes by upstream land in this workspace, never in source/data.
    os.chdir(config.workspace)
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("appliance_oracle7", config.runtime / "oracle7.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    # Upstream setup ignores ORACLE7_ROOT and mutates HERE/root. Split deployment
    # needs this explicit replacement; keep Engine and load/chat unchanged.
    module.setup = lambda: preflight(config)
    return module


def _worker(connection, config):
    engine = None
    try:
        preflight(config)
        engine = import_launcher(config).Engine()
        operations = engine._ex.submit(Operations, engine, config).result()
        summary = {state: sum(item["availability"] == state for item in operations.items.values())
                   for state in ("live_direct", "text_only", "unavailable")}
        connection.send_bytes(encode({"ready": True, "tip": engine.tip, "operations": summary}))
        while True:
            request = json.loads(connection.recv_bytes(config.max_request_bytes + 4096))
            if request.get("stop"):
                break
            try:
                action = request.get("_action", "query")
                if action == "query":
                    reply = engine.chat(request["text"], session_id=request["conversation_id"])
                elif action == "invoke":
                    reply = engine._ex.submit(operations.invoke, request["operation_id"], request["arguments"], request["conversation_id"]).result()
                elif action == "discover":
                    reply = engine._ex.submit(operations.discover, **request["parameters"]).result()
                else:
                    raise OperationError("unknown_action", 400)
                if not isinstance(reply, dict):
                    raise TypeError("implementation did not return an object")
                result = {"outcome": "completed", "reply": reply}
                if action == "invoke":
                    result["operation_id"] = request["operation_id"]
                # Encode incrementally: cap transport bytes without dropping fields.
                chunks, size = [], 0
                for chunk in json.JSONEncoder(ensure_ascii=False, allow_nan=False, separators=(",", ":")).iterencode(result):
                    part = chunk.encode("utf-8")
                    size += len(part)
                    if size > config.max_reply_bytes:
                        break
                    chunks.append(part)
                if size > config.max_reply_bytes:
                    payload = encode(failure("reply_too_large", execution_completed=True,
                                             state_may_have_changed=True))
                else:
                    payload = b"".join(chunks)
            except OperationError as error:
                payload = encode(failure(error.code, http_status=error.status, **error.details))
            except Exception as error:
                # Errors may follow a session write. Do not turn them into refusal.
                payload = encode(failure("runtime_error", error_type=type(error).__name__,
                                         state_may_have_changed=True))
            connection.send_bytes(payload)
    except (EOFError, BrokenPipeError):
        pass
    except BaseException as error:
        try:
            connection.send_bytes(encode(failure("startup_error", error_type=type(error).__name__)))
        except (OSError, EOFError):
            pass
    finally:
        if engine is not None:
            engine._ex.shutdown(wait=True, cancel_futures=True)
        connection.close()


class EngineProcess:
    @property
    def available(self):
        return self._available and self.process.is_alive()

    @available.setter
    def available(self, value):
        self._available = value

    def __init__(self, config):
        self.config = config
        self.available = False
        # spawn keeps upstream globals and SQLite thread ownership in one child.
        context = multiprocessing.get_context("spawn")
        self.connection, child = context.Pipe()
        self.process = context.Process(target=_worker, args=(child, config), name="oracle-appliance")
        self.process.start()
        child.close()
        try:
            if not self.connection.poll(config.startup_timeout):
                raise RuntimeError("engine startup timeout")
            ready = json.loads(self.connection.recv_bytes(config.max_reply_bytes))
            if not ready.get("ready"):
                raise RuntimeError(str(ready))
            self.tip = ready["tip"]
            self.operations = ready.get("operations", {})
            self.available = True
        except BaseException:
            self.close()
            raise

    def query(self, request):
        if not self.available:
            return failure("backend_unavailable", state_may_have_changed=False)
        try:
            self.connection.send_bytes(encode(request))
            if not self.connection.poll(self.config.query_timeout):
                self.available = False
                self.close()
                return failure("query_timeout", state_may_have_changed=True)
            return json.loads(self.connection.recv_bytes(self.config.max_reply_bytes))
        except (OSError, EOFError, ValueError):
            self.available = False
            self.close()
            return failure("worker_lost", state_may_have_changed=True)

    def close(self):
        self.available = False
        if self.process.is_alive():
            try:
                self.connection.send_bytes(b'{"stop":true}')
            except (OSError, EOFError):
                pass
            self.process.join(self.config.shutdown_timeout)
        if self.process.is_alive():
            self.process.terminate()  # only the child this object created
            self.process.join(self.config.shutdown_timeout)
        if self.process.is_alive():
            self.process.kill()
            self.process.join()
        self.connection.close()


class Service:
    def __init__(self, config, backend_factory=EngineProcess):
        validate_paths(config)
        self.deployment = deployment_identity(config)
        self.config = config
        config.workspace.mkdir(mode=0o700, parents=True, exist_ok=True)
        self.lock_file = (config.workspace / "adapter.lock").open("a")
        try:
            fcntl.flock(self.lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            self.lock_file.close()
            raise RuntimeError("workspace already has an appliance process") from None
        self.gate = threading.Lock()
        self.stopping = False
        self.db = sqlite3.connect(config.workspace / "requests.sqlite3", check_same_thread=False)
        self.db.execute("PRAGMA synchronous=FULL")
        self.db.execute("CREATE TABLE IF NOT EXISTS requests (id TEXT PRIMARY KEY, body BLOB NOT NULL, result BLOB)")
        columns = {row[1] for row in self.db.execute("PRAGMA table_info(requests)")}
        if "method" not in columns:
            self.db.execute("ALTER TABLE requests ADD COLUMN method TEXT NOT NULL DEFAULT 'POST'")
        if "path" not in columns:
            self.db.execute("ALTER TABLE requests ADD COLUMN path TEXT NOT NULL DEFAULT '/query'")
        # Existing v1 records are exactly POST /query, so migration retains their identity.
        # A crash may have changed the conversation before journaling its result.
        self.db.execute("UPDATE requests SET result=? WHERE result IS NULL",
                        (encode(failure("interrupted", state_may_have_changed=True)),))
        self.db.commit()
        try:
            self.backend = backend_factory(config)
        except BaseException:
            self.db.close()
            self.lock_file.close()
            raise

    def capabilities(self):
        return {"protocol": "oracle-appliance-v1", "backend": "Oracle7.Engine.chat",
                "source_revision": self.config.source_revision, "tip": self.backend.tip,
                "deployment": self.deployment,
                "operation_discovery": {"protocol": "oracle-operations-v1", "list": "/operations", "detail": "/operations/{operation_id}",
                                        "invoke": "/invoke", "counts": getattr(self.backend, "operations", {})},
                "evidence": "upstream reply preserved; upstream labels are not Mini authority",
                "deployment_content_hashes_checked_by_adapter": False,
                "scope": "one host-assigned workspace per process", "query_queue": 0,
                "limits": {"request_bytes": self.config.max_request_bytes,
                           "reply_bytes": self.config.max_reply_bytes,
                           "retained_requests": self.config.max_requests,
                           "query_seconds": self.config.query_timeout,
                           "operation_schema_limits": "Provider ceilings; entire invocation envelope must fit request_bytes."}}

    def query(self, raw):
        return self.request(raw, "/query")

    def invoke(self, raw):
        return self.request(raw, "/invoke")

    def discover(self, parameters):
        if not self.gate.acquire(blocking=False):
            return 429, failure("busy", retryable=True)
        try:
            if self.stopping or not self.backend.available:
                return 503, failure("backend_unavailable")
            result = self.backend.query({"_action": "discover", "parameters": parameters})
            return (200, result["reply"]) if result.get("outcome") == "completed" else (self.status(result), result)
        finally:
            self.gate.release()

    def request(self, raw, path, method="POST"):
        if method != "POST" or path not in ("/query", "/invoke"):
            return 405, failure("unsupported_method_or_route")
        if len(raw) > self.config.max_request_bytes:
            return 413, failure("request_too_large")
        try:
            # Duplicate keys and non-finite JSON are rejected, not reinterpreted.
            def pairs(items):
                result = {}
                for key, value in items:
                    if key in result:
                        raise ValueError("duplicate key")
                    result[key] = value
                return result
            request = json.loads(raw.decode("utf-8"), object_pairs_hook=pairs,
                                 parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
            fields = {"request_id", "conversation_id", "text"} if path == "/query" else {"request_id", "conversation_id", "operation_id", "arguments"}
            if not isinstance(request, dict) or set(request) != fields:
                raise ValueError()
            for name in ("request_id", "conversation_id"):
                if not isinstance(request[name], str) or not IDENTIFIER.fullmatch(request[name]):
                    raise ValueError()
            if path == "/query":
                if not isinstance(request["text"], str) or not request["text"].strip():
                    raise ValueError()
            elif not isinstance(request["operation_id"], str) or not OPERATION_ID.fullmatch(request["operation_id"]) or not isinstance(request["arguments"], dict):
                raise ValueError()
            # Reject escaped lone surrogates anywhere in structured arguments too.
            encode(request)
        except (ValueError, UnicodeError, RecursionError):
            return 400, failure("invalid_request")
        if not self.gate.acquire(blocking=False):
            return 429, failure("busy", retryable=True)
        executed = False
        try:
            previous = self.db.execute("SELECT body,result,method,path FROM requests WHERE id=?", (request["request_id"],)).fetchone()
            if previous:
                if previous[0] != raw or previous[2:] != (method, path):
                    return 409, failure("request_id_conflict")
                if previous[1] is not None and len(previous[1]) > self.config.max_reply_bytes:
                    return 502, failure("reply_too_large", execution_completed=True,
                                        retained_in_journal=True, state_may_have_changed=True)
                result = json.loads(previous[1]) if previous[1] is not None else failure("interrupted", state_may_have_changed=True)
                return self.status(result), result
            if self.stopping or not self.backend.available:
                return 503, failure("backend_unavailable", retryable=False)
            if self.db.execute("SELECT count(*) FROM requests").fetchone()[0] >= self.config.max_requests:
                return 507, failure("request_journal_full")
            self.db.execute("INSERT INTO requests (id,body,result,method,path) VALUES (?,?,NULL,?,?)", (request["request_id"], raw, method, path))
            self.db.commit()
            try:
                executed = True
                result = self.backend.query(dict(request, _action="query" if path == "/query" else "invoke"))
                payload = encode(result)
                if len(payload) > self.config.max_reply_bytes:
                    result = failure("reply_too_large", execution_completed=True, state_may_have_changed=True)
                    payload = encode(result)
            except Exception:
                result = failure("runtime_error", state_may_have_changed=True)
                payload = encode(result)
            self.db.execute("UPDATE requests SET result=? WHERE id=?", (payload, request["request_id"]))
            self.db.commit()
            return self.status(result), result
        except sqlite3.Error:
            self.stopping = True
            return 507, failure("journal_error", state_may_have_changed=executed)
        finally:
            self.gate.release()

    @staticmethod
    def status(result):
        if result["outcome"] == "completed":
            return 200  # includes deliberate Oracle7 withheld replies
        return result.get("http_status", 504 if result.get("error") == "query_timeout" else 502)

    def close(self):
        self.stopping = True
        # Current query has its own deadline; preserve its journal before exit.
        with self.gate:
            self.backend.close()
            self.db.close()
            self.lock_file.close()


class Server(ThreadingHTTPServer):
    daemon_threads = False
    block_on_close = True
    request_queue_size = 16

    def __init__(self, address, service, ingress_timeout=5.0, tenant_pool=False):
        self.service = service
        self.tenant_pool = tenant_pool
        self.ingress_timeout = ingress_timeout
        self.slots = threading.BoundedSemaphore(16)
        self.ingress_lock = threading.Lock()
        self.ingress = {}
        self.closing = False
        super().__init__(address, Handler)

    @staticmethod
    def stop_socket(request):
        try:
            request.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass

    def finish_ingress(self, request, expired=False):
        # Removing the timer and admitting the backend turn are one decision:
        # if deadline/shutdown won, a just-completed body must not execute.
        with self.ingress_lock:
            timer = self.ingress.pop(request, None)
            if timer is None:
                return False
            timer.cancel()
        if expired:
            self.stop_socket(request)
            return False
        return True

    def process_request(self, request, address):
        if not self.slots.acquire(blocking=False):
            request.close()  # hard cap on slow connections, no unbounded threads
            return
        timer = threading.Timer(self.ingress_timeout, self.finish_ingress, args=(request, True))
        timer.daemon = True
        with self.ingress_lock:
            if self.closing:
                request.close()
                self.slots.release()
                return
            self.ingress[request] = timer
        timer.start()  # absolute deadline includes all headers and the whole body
        try:
            super().process_request(request, address)
        except BaseException:
            self.finish_ingress(request, expired=True)
            self.slots.release()
            raise

    def process_request_thread(self, request, address):
        try:
            super().process_request_thread(request, address)
        finally:
            self.finish_ingress(request)
            self.slots.release()

    def server_close(self):
        self.service.stopping = True
        with self.ingress_lock:
            self.closing = True
            pending = list(self.ingress.items())
            self.ingress.clear()
        for request, timer in pending:
            timer.cancel()
            self.stop_socket(request)
        # Completed ingress has no timer. Its backend turn keeps its own deadline
        # and may finish/journal/respond normally while these threads drain.
        super().server_close()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def setup(self):
        super().setup()
        self.connection.settimeout(self.server.ingress_timeout)

    def handle(self):
        try:
            super().handle()
        except OSError:
            pass  # deadline/shutdown may close an in-progress header/body read

    def log_message(self, *_):
        pass  # no prompts or evidence in HTTP logs

    def respond(self, status, result):
        payload = encode(result)
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError, socket.timeout):
            pass  # retry exact request bytes to recover the journaled response

    def private_request(self):
        # Trusted host transport only; reject browser cross-origin entry points.
        if self.headers.get("Origin") or self.headers.get("Sec-Fetch-Site"):
            self.respond(403, failure("browser_request_rejected"))
            return False
        host = self.headers.get("Host", "")
        if host not in {"127.0.0.1", f"127.0.0.1:{self.server.server_port}",
                        "localhost", f"localhost:{self.server.server_port}"}:
            self.respond(400, failure("invalid_host"))
            return False
        return True

    def tenant(self):
        """Only the private Mini bridge supplies this identity, never an app body.

        This header is routing metadata, not authentication. The deployment must
        isolate loopback ingress from clients, including other tenant processes.
        """
        values = self.headers.get_all(TENANT_HEADER, [])
        if self.server.tenant_pool:
            if len(values) != 1 or not TENANT_KEY.fullmatch(values[0]):
                self.respond(400, failure("host_tenant_required"))
                return False, None
            return True, values[0]
        if values:
            self.respond(400, failure("tenant_pool_disabled"))
            return False, None
        return True, None

    def do_GET(self):
        if not self.server.finish_ingress(self.connection):
            return
        if not self.private_request():
            return
        service = self.server.service
        if self.path == "/health":
            if self.server.tenant_pool:
                health = service.health()
            else:
                health = {"ready": service.backend.available and not service.stopping,
                          "busy": service.gate.locked()}
            self.respond(200 if health["ready"] else 503, health)
            return
        valid, tenant = self.tenant()
        if not valid:
            return
        if self.path == "/capabilities":
            self.respond(*(service.capabilities(tenant) if self.server.tenant_pool
                           else (200, service.capabilities())))
        elif self.path == "/operations" or self.path.startswith(("/operations?", "/operations/")):
            try:
                url = urlsplit(self.path)
                if url.path.startswith("/operations/"):
                    operation_id = url.path[len("/operations/"):]
                    if not OPERATION_ID.fullmatch(operation_id) or url.query:
                        raise ValueError()
                    parameters = {"operation_id": operation_id}
                else:
                    values = parse_qs(url.query, keep_blank_values=True, strict_parsing=True, max_num_fields=4)
                    if set(values) - {"offset", "limit", "q", "availability"} or any(len(v) != 1 for v in values.values()):
                        raise ValueError()
                    offset, limit = values.get("offset", ["0"])[0], values.get("limit", ["10"])[0]
                    if not re.fullmatch(r"[0-9]{1,9}", offset) or not re.fullmatch(r"[0-9]{1,2}", limit):
                        raise ValueError()
                    parameters = {"offset": int(offset), "limit": int(limit), "q": values.get("q", [""])[0],
                                  "availability": values.get("availability", [None])[0]}
                    if not 1 <= parameters["limit"] <= 50 or len(parameters["q"].encode("utf-8")) > 256 or parameters["availability"] not in (None, "live_direct", "text_only", "unavailable"):
                        raise ValueError()
                self.respond(*(service.discover(tenant, parameters) if self.server.tenant_pool
                               else service.discover(parameters)))
            except (ValueError, UnicodeError):
                self.respond(400, failure("invalid_discovery_request"))
        else:
            self.respond(404, failure("not_found"))

    def do_POST(self):
        if not self.private_request():
            return
        valid, tenant = self.tenant()
        if not valid:
            return
        if self.path not in ("/query", "/invoke"):
            self.respond(404, failure("not_found"))
            return
        lengths = self.headers.get_all("Content-Length", [])
        if self.headers.get("Transfer-Encoding") or len(lengths) != 1 or not re.fullmatch(r"[0-9]+", lengths[0]):
            self.respond(400, failure("invalid_length"))
            return
        if self.headers.get_content_type() != "application/json":
            self.respond(415, failure("json_required"))
            return
        length = int(lengths[0]) if len(lengths[0]) < 20 else self.server.service.config.max_request_bytes + 1
        if length > self.server.service.config.max_request_bytes:
            self.respond(413, failure("request_too_large"))
            return
        try:
            body = self.rfile.read(length)
        except (socket.timeout, ConnectionResetError):
            self.respond(408, failure("body_timeout"))
            return
        if len(body) != length:
            self.respond(400, failure("incomplete_body"))
            return
        if self.server.finish_ingress(self.connection):
            service = self.server.service
            self.respond(*(service.request(tenant, body, self.path) if self.server.tenant_pool
                           else service.request(body, self.path)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--data-root", type=Path, required=True)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--source-revision", default=REVISION)
    parser.add_argument("--port", type=int, default=7070)
    parser.add_argument("--max-request-bytes", type=int, default=16384)
    parser.add_argument("--max-reply-bytes", type=int, default=2097152)
    parser.add_argument("--max-requests", type=int, default=10000)
    parser.add_argument("--query-timeout", type=float, default=120)
    parser.add_argument("--startup-timeout", type=float, default=120)
    parser.add_argument("--shutdown-timeout", type=float, default=5)
    parser.add_argument("--check-import", action="store_true", help="import real launcher only; does not construct Engine or verify stores")
    parser.add_argument("--tenant-pool", action="store_true", help="route private host tenant identities to a bounded worker pool")
    parser.add_argument("--max-resident", type=int, default=2)
    parser.add_argument("--max-tenants", type=int, default=128)
    parser.add_argument("--idle-seconds", type=float, default=300)
    args = parser.parse_args()
    config = Config(**{k: v.resolve() if isinstance(v, Path) else v for k, v in vars(args).items()
                       if k not in {"port", "check_import", "tenant_pool", "max_resident", "max_tenants", "idle_seconds"}})
    if not 1 <= args.max_resident <= min(64, args.max_tenants) or args.max_tenants > 10000:
        parser.error("require 1 <= max-resident <= 64 and max-resident <= max-tenants <= 10000")
    if not math.isfinite(args.idle_seconds) or args.idle_seconds <= 0:
        parser.error("idle-seconds must be positive and finite")
    if any(not math.isfinite(getattr(config, key)) or getattr(config, key) < 1 for key in ("max_request_bytes", "max_reply_bytes", "max_requests", "query_timeout", "startup_timeout", "shutdown_timeout")):
        parser.error("limits must be positive")
    if config.max_reply_bytes < 1024:
        parser.error("max-reply-bytes must be at least 1024")
    try:
        validate_paths(config)
    except ValueError as error:
        parser.error(str(error))
    config.workspace.mkdir(mode=0o700, parents=True, exist_ok=True)
    if args.check_import:
        module = import_launcher(config)
        print(json.dumps({"launcher_imported": True, "engine_class_present": hasattr(module, "Engine"),
                          "engine_constructed": False, "stores_checked": False,
                          "workbench_cli_imported": "cli" in sys.modules}))
        return
    # Set before spawn; setting it inside worker would not fix Python's hash seed.
    os.environ.update(PYTHONHASHSEED="0", PYTHONIOENCODING="utf-8")
    if args.tenant_pool:
        from tenant_pool import TenantPool
        service = TenantPool(config, max_resident=args.max_resident,
                             max_tenants=args.max_tenants, idle_seconds=args.idle_seconds)
    else:
        service = Service(config)
    server = None
    try:
        server = Server(("127.0.0.1", args.port), service, tenant_pool=args.tenant_pool)
        def stop(*_):
            service.stopping = True
            threading.Thread(target=server.shutdown, daemon=True).start()
        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        print(json.dumps({"listening": f"http://127.0.0.1:{server.server_port}", "protocol": "oracle-appliance-v1"}), flush=True)
        server.serve_forever(poll_interval=0.2)
    finally:
        if server is not None:
            server.server_close()
        service.close()


if __name__ == "__main__":
    main()
