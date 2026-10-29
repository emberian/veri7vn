"""Untrusted shared process boundary for operator-admitted native providers.

One fixed global slot cap serves host-assigned tenants, with immediate admission
and no work queue. execute()/catalog() use the host's existing bounded scheduler
threads; this pool creates no Python threads. It supplies no authentication,
filesystem/network sandbox or Mini admission. Operator runtime profiles add
native durable state/replay; pure providers retain correlation-only IDs.

Wall deadlines/cancellation cover nonblocking I/O and native execution. Process
creation, signaling, reaping and filesystem I/O remain OS operations, not hard
real-time guarantees. Only owned process groups are signaled, before reaping.
"""
from __future__ import annotations

from dataclasses import dataclass
import copy
import hashlib
import importlib.machinery
import json
import math
import os
from pathlib import Path
import re
import selectors
import signal
import stat
import subprocess
import sys
import tempfile
import threading
import time

from native_runtime import RuntimeProfile, DEFAULT_CORE_LIMITS, OUTER_ID
from native_worker import PROFILES, SAFE_REQUEST_FAILURES, REQUEST_ERROR_DETAIL_BYTES, decode, encode


IDENTIFIER = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,159}\Z")
POLL_SECONDS = 0.01


class NativePoolError(Exception):
    def __init__(self, code, detail=None, *, request_code=None):
        self.code, self.detail = code, detail
        self.request_code = request_code
        super().__init__(code)


@dataclass(frozen=True)
class NativeProvider:
    """Operator configuration only; never construct from an operation request."""
    id: str
    extension: Path
    sha256: str
    profile: str
    runtime: RuntimeProfile | None = None


@dataclass(frozen=True)
class NativeLimits:
    workers: int = 2
    registry_entries: int = 16
    extension_bytes: int = 128 * 1024 * 1024
    request_bytes: int = 1024 * 1024
    reply_bytes: int = 2 * 1024 * 1024
    stderr_bytes: int = 16384
    timeout_seconds: float = 5.0
    startup_seconds: float = 10.0
    shutdown_seconds: float = 2.0
    cpu_seconds: int | None = 30
    memory_bytes: int | None = 2 * 1024 * 1024 * 1024
    file_descriptors: int = 64


@dataclass(frozen=True)
class NativeReply:
    reply: dict
    admission: dict
    containment: dict


@dataclass
class _Slot:
    busy: bool = False
    poisoned: bool = False
    worker: object = None


class _Worker:
    def __init__(self, admitted, limits):
        self.admitted, self.limits = admitted, limits
        self.process = None
        self.stderr_count = 0
        self.containment = None

    def command(self):
        settings = {key: getattr(self.limits, key) for key in
                    ("request_bytes", "reply_bytes", "cpu_seconds", "memory_bytes", "file_descriptors")}
        runtime = self.admitted.get("runtime")
        self.profiles = [p for p in self.admitted["artifact"]["profiles"] if p != "runtime" or runtime is not None]
        settings["file_size_bytes"] = 0 if runtime is None else runtime.state_file_bytes
        command = [sys.executable, "-I", "-B", str(Path(__file__).with_name("native_worker.py")),
                "--extension", str(self.admitted["snapshot"]), "--sha256", self.admitted["sha256"],
                "--profiles", json.dumps(self.profiles),
                "--limits", json.dumps(settings, separators=(",", ":"))]
        if runtime is not None:
            command.extend(["--runtime-config", str(self.admitted["runtime_snapshot"])])
        return command

    def start(self, checkpoint, deadline):
        checkpoint(deadline)
        try:
            self.process = subprocess.Popen(self.command(), stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                            stderr=subprocess.PIPE, bufsize=0, close_fds=True,
                                            start_new_session=True, cwd="/", env={
                                                "OMP_NUM_THREADS": "1", "OPENBLAS_NUM_THREADS": "1", "MKL_NUM_THREADS": "1"})
            for stream in (self.process.stdin, self.process.stdout, self.process.stderr):
                os.set_blocking(stream.fileno(), False)
        except OSError as error:
            raise NativePoolError("native_start_failed") from error
        ready = self.exchange(None, checkpoint, deadline)
        if ready.get("ready") is False:
            kind = ready.get("error_type")
            raise NativePoolError("native_start_failed", kind[:128] if isinstance(kind, str) else None)
        expected_keys = {"ready", "profiles", "extension_sha256", "containment"}
        if self.admitted.get("runtime") is not None:
            expected_keys.add("resource_identity")
        if (not isinstance(ready, dict) or ready.get("ready") is not True
                or set(ready) != expected_keys
                or ready["profiles"] != getattr(self, "profiles", self.admitted["artifact"]["profiles"])
                or ready.get("resource_identity") != self.admitted.get("resource_identity")
                or ready["extension_sha256"] != self.admitted["sha256"]
                or not isinstance(ready["containment"], dict)):
            raise NativePoolError("native_start_failed")
        self.containment = ready["containment"]

    def exchange(self, payload, checkpoint, deadline):
        """Incremental nonblocking write/read; no thread can block on a pipe."""
        pending = memoryview(payload or b"")
        received = bytearray()
        result = None
        with selectors.DefaultSelector() as selector:
            selector.register(self.process.stdout, selectors.EVENT_READ, "stdout")
            selector.register(self.process.stderr, selectors.EVENT_READ, "stderr")
            if pending:
                selector.register(self.process.stdin, selectors.EVENT_WRITE, "stdin")
            while True:
                checkpoint(deadline)
                for key, _ in selector.select(min(POLL_SECONDS, max(0, deadline - time.monotonic()))):
                    try:
                        if key.data == "stdin":
                            count = os.write(key.fd, pending[:65536])
                            if count == 0:
                                raise NativePoolError("worker_input_closed")
                            pending = pending[count:]
                            if not pending:
                                selector.unregister(key.fileobj)
                        else:
                            data = os.read(key.fd, 65536)
                            if key.data == "stderr":
                                if not data:
                                    selector.unregister(key.fileobj)
                                self.stderr_count += len(data)
                                if self.stderr_count > self.limits.stderr_bytes:
                                    raise NativePoolError("worker_stderr_limit")
                            else:
                                if not data:
                                    raise NativePoolError("worker_eof")
                                if result is not None or len(received) + len(data) > self.limits.reply_bytes:
                                    raise NativePoolError("worker_reply_limit" if result is None else "worker_protocol_error")
                                received.extend(data)
                                if b"\n" in received:
                                    if not received.endswith(b"\n") or received.count(b"\n") != 1:
                                        raise NativePoolError("worker_protocol_error")
                                    try:
                                        result = decode(received)
                                        if not isinstance(result, dict):
                                            raise ValueError("worker reply is not an object")
                                    except (ValueError, UnicodeError, RecursionError) as error:
                                        raise NativePoolError("worker_protocol_error") from error
                    except (BlockingIOError, InterruptedError):
                        continue
                    except (BrokenPipeError, OSError) as error:
                        raise NativePoolError("worker_io_error") from error
                if result is not None and not pending:
                    checkpoint(deadline)
                    return result

    def close(self):
        if self.process is None:
            return
        process = self.process
        # Do not poll()/wait() before this signal: an unreaped leader's PID
        # cannot be recycled into an unrelated process group's identity.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        except PermissionError as error:
            if sys.platform != "darwin":
                raise NativePoolError("worker_cleanup_uncertain") from error
            # Darwin killpg1 excludes SZOMB members and returns EPERM if it
            # finds no signalable member. See Apple's xnu/bsd/kern/kern_sig.c,
            # killpg1's pgrp_iterate filter. For our same-credential pure
            # workers, allow this only when the exact owned leader can be
            # reaped below; a live denied leader still times out/poisons.
            # Crucially, the group signal was attempted BEFORE this wait and
            # there will be NO signal to its potentially recycled ID afterward.
        except OSError as error:
            raise NativePoolError("worker_cleanup_uncertain") from error
        try:
            process.wait(timeout=self.limits.shutdown_seconds)
        except (subprocess.TimeoutExpired, OSError) as error:
            raise NativePoolError("worker_cleanup_uncertain") from error
        # wait() has reaped the leader. Never signal this PID/group again even
        # if closing a local pipe handle reports an error.
        self.process = None
        for stream in (process.stdin, process.stdout, process.stderr):
            try:
                stream.close()
            except OSError:
                pass


class NativePool:
    """Fixed shared workers; no tenant processes, pending queue or I/O threads.

    Each leased call uses one caller thread and at most three child pipes plus
    one selector FD. At most limits.workers calls/startups can be admitted.
    The operator must share this single pool across its tenant scheduler.
    Pure feature code and its interpreter/dependencies must be trusted: process
    limits do not make arbitrary native machine code safe to execute.
    Use a context manager or call close() before releasing the owning host.
    """
    _worker_class = _Worker

    def __init__(self, providers, limits=NativeLimits()):
        if os.name != "posix":
            raise ValueError("native process boundary requires POSIX")
        if signal.getsignal(signal.SIGCHLD) == signal.SIG_IGN:
            raise ValueError("native pool needs ownership of unreaped children; SIGCHLD cannot be ignored")
        for name in ("workers", "registry_entries", "extension_bytes", "request_bytes", "reply_bytes", "stderr_bytes", "file_descriptors"):
            if type(getattr(limits, name)) is not int or getattr(limits, name) <= 0:
                raise ValueError("invalid native limit: " + name)
        if limits.workers > 64 or limits.registry_entries > 128 or limits.reply_bytes < 1024 or limits.file_descriptors < 16:
            raise ValueError("invalid native pool limits")
        for name in ("timeout_seconds", "startup_seconds", "shutdown_seconds"):
            value = getattr(limits, name)
            if type(value) not in (int, float) or not math.isfinite(value) or value <= 0:
                raise ValueError("invalid native duration: " + name)
        for name in ("cpu_seconds", "memory_bytes"):
            value = getattr(limits, name)
            if value is not None and (type(value) is not int or value <= 0):
                raise ValueError("invalid native resource limit: " + name)
        if not isinstance(providers, (list, tuple)) or len(providers) > limits.registry_entries:
            raise ValueError("native provider registry exceeds bound")
        self.limits = limits
        self.condition = threading.Condition()
        self.stopping = threading.Event()
        self.closing = self.closed = False
        self.slots = [_Slot() for _ in range(limits.workers)]
        self.tenants = set()
        self.sequence = 0
        self.registry = {}
        self.artifacts = {}
        self.snapshots = tempfile.TemporaryDirectory(prefix="oracle-native-pool-")
        try:
            for provider in providers:
                if (not isinstance(provider, NativeProvider) or not isinstance(provider.id, str)
                        or not IDENTIFIER.fullmatch(provider.id) or provider.id in self.registry
                        or not isinstance(provider.profile, str) or provider.profile not in PROFILES):
                    raise ValueError("invalid or duplicate native provider")
                if provider.profile == "runtime":
                    if not isinstance(provider.runtime, RuntimeProfile):
                        raise ValueError("runtime provider requires operator RuntimeProfile")
                    runtime = RuntimeProfile.from_dict(provider.runtime.to_dict())
                    if runtime.declaration.get("runtime_artifact_sha256") != provider.sha256:
                        raise ValueError("operator release/extension mismatch")
                    core = {**DEFAULT_CORE_LIMITS, **runtime.core_limits}
                    # Exact native JSON is carried as one escaped JSON string.
                    # At most one extra escape byte per original byte, plus
                    # bounded host metadata/receipts at each transport layer.
                    if 2 * core["result_bytes"] + 16384 > limits.reply_bytes:
                        raise ValueError("runtime result_bytes cannot fit reply_bytes with exact JSON framing")
                elif provider.runtime is not None:
                    raise ValueError("runtime resources require runtime profile")
                else:
                    runtime = None
                admitted = self._admit(provider)
                if runtime is not None:
                    admitted["runtime"] = runtime
                    admitted["resource_identity"] = runtime.identity
                    runtime_path = Path(self.snapshots.name) / ("runtime-" + runtime.identity + ".json")
                    if not runtime_path.exists():
                        runtime_path.write_text(json.dumps(runtime.to_dict(), ensure_ascii=False, allow_nan=False), encoding="utf-8")
                        runtime_path.chmod(0o400)
                    admitted["runtime_snapshot"] = runtime_path
                self.registry[provider.id] = admitted
            for artifact in self.artifacts.values():
                artifact["profiles"] = sorted(artifact["profiles"])
        except BaseException:
            self.snapshots.cleanup()
            raise

    def _admit(self, provider):
        path = Path(provider.extension)
        if (not path.is_absolute() or not str(path).endswith(tuple(importlib.machinery.EXTENSION_SUFFIXES))
                or not isinstance(provider.sha256, str) or not re.fullmatch(r"[0-9a-f]{64}", provider.sha256)):
            raise ValueError("native extension requires an absolute binary path and lowercase SHA-256")
        if provider.sha256 in self.artifacts:
            artifact = self.artifacts[provider.sha256]
            artifact["profiles"].add(provider.profile)
            return {"id": provider.id, "profile": provider.profile, "sha256": provider.sha256,
                    "extension_bytes": artifact["extension_bytes"], "snapshot": artifact["snapshot"],
                    "artifact": artifact}
        directory = Path(self.snapshots.name) / provider.sha256
        directory.mkdir(mode=0o700)
        suffix = next(s for s in importlib.machinery.EXTENSION_SUFFIXES if str(path).endswith(s))
        snapshot = directory / ("oracle_native" + suffix)
        digest, count = hashlib.sha256(), 0
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(fd, "rb") as source, snapshot.open("xb") as target:
            if not stat.S_ISREG(os.fstat(source.fileno()).st_mode):
                raise ValueError("native extension is not a regular file")
            while True:
                block = source.read(65536)
                if not block:
                    break
                count += len(block)
                if count > self.limits.extension_bytes:
                    raise ValueError("native extension exceeds byte limit")
                digest.update(block)
                target.write(block)
        if count == 0 or digest.hexdigest() != provider.sha256:
            raise ValueError("native extension hash mismatch or empty file")
        snapshot.chmod(0o400)
        artifact = {"snapshot": snapshot, "extension_bytes": count, "profiles": {provider.profile}}
        self.artifacts[provider.sha256] = artifact
        return {"id": provider.id, "profile": provider.profile, "sha256": provider.sha256,
                "extension_bytes": count, "snapshot": snapshot, "artifact": artifact}

    def _checkpoint(self, deadline, cancellation):
        if self.stopping.is_set():
            raise NativePoolError("pool_stopping")
        if cancellation is not None and cancellation.is_set():
            raise NativePoolError("cancelled")
        if time.monotonic() >= deadline:
            raise NativePoolError("deadline_exceeded")

    def execute(self, tenant, provider_id, request, *, cancellation=None, deadline=None, host_context=None):
        """Run supplied provider data. Tenant/provider identity is host assigned."""
        if not isinstance(request, dict):
            raise ValueError("native request must be an object")
        # These are not provider data or authority-bearing transport options.
        if set(request).intersection({"module", "path", "extension", "extension_path", "extension_sha256", "authority", "profile", "backend"}):
            raise ValueError("native requests cannot configure execution authority")
        return self._execute(tenant, provider_id, "call", request, cancellation, deadline, host_context)

    def catalog(self, tenant, provider_id, *, cancellation=None, deadline=None):
        return self._execute(tenant, provider_id, "catalog", {}, cancellation, deadline)

    def _execute(self, tenant, provider_id, action, request, cancellation, deadline, host_context=None):
        if not isinstance(tenant, str) or not IDENTIFIER.fullmatch(tenant):
            raise ValueError("host tenant identity is invalid")
        if not isinstance(provider_id, str) or provider_id not in self.registry:
            raise ValueError("native provider is not registered")
        runtime = self.registry[provider_id].get("runtime")
        if runtime is not None and action == "call":
            if (not isinstance(host_context, dict) or set(host_context) != {"tenant", "request_id", "conversation_id"}
                    or host_context.get("tenant") != tenant
                    or any(not isinstance(host_context.get(k), str) or not OUTER_ID.fullmatch(host_context[k])
                           for k in ("request_id", "conversation_id"))):
                raise ValueError("runtime call requires canonical outer host context")
            host_context = dict(host_context)
        elif host_context is not None:
            raise ValueError("host runtime context requires runtime invocation")
        if cancellation is not None and not isinstance(cancellation, threading.Event):
            raise ValueError("cancellation must be a host threading.Event")
        now = time.monotonic()
        if deadline is not None and (type(deadline) not in (int, float) or not math.isfinite(deadline)):
            raise ValueError("deadline must be a finite monotonic time")
        deadline = min(now + self.limits.timeout_seconds, deadline if deadline is not None else math.inf)
        check = lambda stop: self._checkpoint(stop, cancellation)
        check(deadline)
        # Incremental serialization bounds host allocations for supplied JSON.
        try:
            raw = encode(request, self.limits.request_bytes + 1)[:-1]
            normalized = decode(raw)
        except (ValueError, TypeError, UnicodeError, RecursionError) as error:
            raise ValueError("native request is invalid or exceeds byte limit") from error
        with self.condition:
            check(deadline)
            if tenant in self.tenants:
                raise NativePoolError("tenant_busy")
            available = [entry for entry in self.slots if not entry.busy and not entry.poisoned]
            slot = next((entry for entry in available if entry.worker is not None
                         and self._compatible(entry.worker.admitted, self.registry[provider_id])),
                        available[0] if available else None)
            if slot is None:
                raise NativePoolError("pool_unavailable" if all(s.poisoned for s in self.slots) else "pool_busy")
            slot.busy = True
            self.tenants.add(tenant)
            self.sequence += 1
            sequence = self.sequence
        reusable = False
        try:
            admitted = self.registry[provider_id]
            if slot.worker is not None and not self._compatible(slot.worker.admitted, admitted):
                self._retire(slot)
            if slot.worker is None:
                # Store ownership before spawning; even startup/FD setup errors
                # are cleaned up through the same reserved slot.
                slot.worker = self._worker_class(admitted, self.limits)
                slot.worker.start(check, min(deadline, time.monotonic() + self.limits.startup_seconds))
            document = {"id": sequence, "profile": admitted["profile"], "action": action, "payload": normalized}
            if runtime is not None and action == "call":
                document["host_context"] = host_context
            frame = encode(document, self.limits.request_bytes + 1024)
            result = slot.worker.exchange(frame, check, deadline)
            if (type(result.get("id")) is not int or result["id"] != sequence
                    or result.get("outcome") not in ("completed", "request_refused", "refused", "error")):
                raise NativePoolError("worker_protocol_error")
            if result["outcome"] == "request_refused":
                # Validate the typed boundary independently. No worker-provided
                # reusable flag, generic ValueError or catalog action grants it.
                if (set(result) != {"id", "outcome", "error", "code", "detail"}
                        or action != "call" or admitted["profile"] not in SAFE_REQUEST_FAILURES
                        or result["error"] != "native_refused" or not isinstance(result["code"], str)
                        or result["code"] not in SAFE_REQUEST_FAILURES[admitted["profile"]]
                        or not isinstance(result["detail"], str)):
                    raise NativePoolError("worker_protocol_error")
                try:
                    detail_bytes = len(result["detail"].encode("utf-8"))
                except UnicodeError as error:
                    raise NativePoolError("worker_protocol_error") from error
                if detail_bytes > REQUEST_ERROR_DETAIL_BYTES:
                    raise NativePoolError("worker_protocol_error")
                reusable = True
                raise NativePoolError("native_refused", result["detail"], request_code=result["code"])
            if result["outcome"] != "completed":
                if (set(result) - {"id", "outcome", "error", "detail"}
                        or not isinstance(result.get("error"), str) or len(result["error"]) > 80
                        or ("detail" in result and (not isinstance(result["detail"], str) or len(result["detail"]) > 512))):
                    raise NativePoolError("worker_protocol_error")
                raise NativePoolError(result["error"], result.get("detail"))
            if set(result) != {"id", "outcome", "reply"} or not isinstance(result["reply"], dict):
                raise NativePoolError("worker_protocol_error")
            reusable = True
            return NativeReply(result["reply"], self._receipt(admitted), copy.deepcopy(slot.worker.containment))
        finally:
            try:
                if not reusable:
                    self._retire(slot)
            finally:
                with self.condition:
                    slot.busy = False
                    self.tenants.remove(tenant)
                    self.condition.notify_all()

    def _retire(self, slot):
        if slot.worker is not None:
            try:
                slot.worker.close()
            except BaseException:
                slot.poisoned = True  # uncertain ownership continues to consume its slot
                raise
            slot.worker = None
        slot.poisoned = False

    @staticmethod
    def _compatible(resident, requested):
        return (resident["sha256"] == requested["sha256"]
                and (requested.get("runtime") is None
                     or resident.get("resource_identity") == requested.get("resource_identity")))

    @staticmethod
    def _receipt(admitted):
        return {key: value for key, value in admitted.items() if key not in ("snapshot", "artifact", "runtime", "runtime_snapshot")}

    def admissions(self):
        return [self._receipt(value) for value in self.registry.values()]

    def health(self):
        with self.condition:
            return {"ready": not self.stopping.is_set(), "workers": len(self.slots),
                    "busy": sum(slot.busy for slot in self.slots),
                    "resident": sum(slot.worker is not None for slot in self.slots),
                    "poisoned": sum(slot.poisoned for slot in self.slots),
                    "queue": 0, "threads_created": 0}

    def close(self):
        """Cancel active calls, reap owned workers, then remove private snapshots.

        If cleanup cannot establish ownership release, keep its poisoned slot
        and snapshots. A subsequent close() may retry; no replacement is born.
        """
        with self.condition:
            self.condition.wait_for(lambda: not self.closing)
            if self.closed:
                return
            self.closing = True
            self.stopping.set()
            self.condition.wait_for(lambda: not any(slot.busy for slot in self.slots))
        errors = []
        try:
            for slot in self.slots:
                try:
                    self._retire(slot)
                except Exception as error:
                    errors.append(error)
            if errors:
                raise NativePoolError("pool_cleanup_uncertain") from errors[0]
            self.snapshots.cleanup()
            self.closed = True
        finally:
            with self.condition:
                self.closing = False
                self.condition.notify_all()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()
