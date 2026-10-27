#!/usr/bin/env python3
"""Untrusted operator experiment runner for real OracleEngine; no proof/admission authority.

Only its new output workspace and shared advisory slot files are writable inputs.
The runtime is treated as a read-only input; no launcher is imported here.
"""
import argparse
import base64
import contextlib
import fcntl
import json
import math
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_RUNTIME = ROOT / "var/appliance-20261026/candidate"
SLOTS = ROOT / "var/usage-20261026/slots"
IDENTIFIER = re.compile(r"[A-Za-z0-9_-]{1,80}\Z")
MAX_REQUEST = 16384
MAX_REPLY = 2097152


def encode(value):
    return json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode("utf-8")


def unique_pairs(items):
    result = {}
    for key, value in items:
        if key in result:
            raise ValueError("duplicate JSON key: " + key)
        result[key] = value
    return result


def validate_cases(cases):
    if not isinstance(cases, list) or not 1 <= len(cases) <= 30:
        raise ValueError("cases must be an array of 1..30 objects")
    checked = []
    for case in cases:
        if not isinstance(case, dict) or set(case) != {"id", "conversation_id", "text"}:
            raise ValueError("each case needs exactly id, conversation_id, text")
        for key in ("id", "conversation_id"):
            if not isinstance(case[key], str) or not IDENTIFIER.fullmatch(case[key]):
                raise ValueError(key + " must contain 1..80 ASCII letters, digits, underscores or hyphens")
        if not isinstance(case["text"], str) or not case["text"].strip():
            raise ValueError("text must be a nonempty string")
        raw = encode({"request_id": case["id"], "conversation_id": case["conversation_id"], "text": case["text"]})
        if len(raw) > MAX_REQUEST:
            raise ValueError("encoded request exceeds 16 KiB")
        checked.append((case, raw))
    # Repeated IDs are intentional: experiments can test replay/conflict behavior.
    return checked


@contextlib.contextmanager
def engine_slot(directory=SLOTS, wait_seconds=1800):
    """Three host-wide advisory leases. Never unlink a lock file."""
    directory.mkdir(parents=True, mode=0o700, exist_ok=True)
    deadline = time.monotonic() + wait_seconds
    next_notice = 0
    held = None
    try:
        while held is None:
            for number in range(3):
                stream = (directory / f"{number}.lock").open("a+b")
                try:
                    fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    stream.close()
                else:
                    held = stream
                    break
            if held is not None:
                break
            now = time.monotonic()
            if now >= deadline:
                raise TimeoutError("engine slot wait deadline")
            if now >= next_notice:
                print("Waiting for one of three Oracle engine slots...", flush=True)
                next_notice = now + 15
            time.sleep(min(0.25, deadline-now))
        yield held
    finally:
        if held is not None:
            # Closing releases our copy; an inherited adapter lease remains until
            # that process exits, including if the runner itself is killed.
            held.close()


def stop_owned(child, grace=12):
    """Stop only the child/private process group created by this invocation."""
    if child.poll() is None:
        child.terminate()
    try:
        child.wait(timeout=grace)
    except subprocess.TimeoutExpired:
        os.killpg(child.pid, signal.SIGKILL)
        child.wait(timeout=5)
    try:
        os.killpg(child.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    deadline = time.monotonic() + 2
    while time.monotonic() < deadline:
        try:
            os.killpg(child.pid, 0)
        except ProcessLookupError:
            return
        time.sleep(0.05)
    try:
        os.killpg(child.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def http(port, method, path, raw=b"", timeout=40):
    """One HTTP/1.0 exchange with absolute wall-clock and byte bounds."""
    deadline = time.monotonic() + timeout
    with socket.create_connection(("127.0.0.1", port), timeout=timeout) as connection:
        def remaining():
            value = deadline-time.monotonic()
            if value <= 0:
                raise TimeoutError("HTTP deadline; delivery may be uncertain")
            connection.settimeout(value)
        header = (f"{method} {path} HTTP/1.0\r\nHost: 127.0.0.1:{port}\r\n"
                  f"Content-Type: application/json\r\nContent-Length: {len(raw)}\r\nConnection: close\r\n\r\n").encode()
        remaining()
        connection.sendall(header + raw)
        data = bytearray()
        while b"\r\n\r\n" not in data:
            if len(data) >= 16384:
                raise ValueError("HTTP headers exceed 16 KiB")
            remaining()
            chunk = connection.recv(1024)
            if not chunk:
                raise ValueError("incomplete HTTP headers")
            data.extend(chunk)
        head, body = bytes(data).split(b"\r\n\r\n", 1)
        if len(head)+4 > 16384:
            raise ValueError("HTTP headers exceed 16 KiB")
        lines = head.decode("ascii").split("\r\n")
        status = int(lines[0].split(" ", 2)[1])
        headers = {}
        for line in lines[1:]:
            name, value = line.split(":", 1)
            name = name.lower()
            if name in headers:
                raise ValueError("duplicate HTTP header")
            headers[name] = value.strip()
        if "transfer-encoding" in headers:
            raise ValueError("transfer encoding unsupported")
        length = int(headers["content-length"])
        if not 0 <= length <= MAX_REPLY or len(body) > length:
            raise ValueError("response size invalid; evidence not truncated")
        body = bytearray(body)
        while len(body) < length:
            remaining()
            chunk = connection.recv(min(65536, length-len(body)))
            if not chunk:
                raise ValueError("incomplete HTTP body; evidence not truncated")
            body.extend(chunk)
        return status, bytes(body)


def run(cases, out, runtime, query_timeout=30, startup_timeout=120):
    out, runtime = out.resolve(), runtime.resolve()
    if out == runtime or runtime in out.parents or out in runtime.parents:
        raise ValueError("output/workspace and read-only runtime must be disjoint")
    upstream = (ROOT / "upstream").resolve()
    if out == upstream or upstream in out.parents:
        raise ValueError("output must not be inside upstream")
    out.mkdir(mode=0o700, parents=True, exist_ok=False)
    (out / "cases.json").write_bytes(encode([case for case, _ in cases]))
    summary = {"scope": "real OracleEngine experiments, not specialist panel scores or Mini admission",
               "runtime": str(runtime), "workspace": str(out / "workspace"), "cases": len(cases),
               "query_timeout": query_timeout, "startup_timeout": startup_timeout,
               "completed": 0, "not_run": 0, "transport_errors": 0, "http_errors": 0}
    next_case, reason, child = 0, None, None
    began = time.monotonic()
    with (out / "results.jsonl").open("w") as results, (out / "adapter.log").open("wb") as log:
        def record(value):
            results.write(encode(value).decode() + "\n")
            results.flush()
        try:
            with engine_slot() as lease:
                try:
                    with socket.socket() as reservation:
                        reservation.bind(("127.0.0.1", 0))
                        port = reservation.getsockname()[1]
                    command = [sys.executable, "-B", str(ROOT / "tools/appliance/serve.py"),
                               "--runtime", str(runtime), "--data-root", str(runtime / "root"),
                               "--workspace", str(out / "workspace"), "--port", str(port),
                               "--query-timeout", str(query_timeout), "--startup-timeout", str(startup_timeout)]
                    child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                             start_new_session=True, close_fds=True, pass_fds=(lease.fileno(),),
                                             env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
                    summary["adapter_pid"] = child.pid
                    deadline = time.monotonic()+startup_timeout+5
                    while True:
                        if child.poll() is not None:
                            raise RuntimeError(f"adapter exited {child.returncode}; see adapter.log")
                        try:
                            status, body = http(port, "GET", "/health", timeout=min(1, max(.01, deadline-time.monotonic())))
                            if status == 200:
                                summary["health"] = json.loads(body)
                                break
                        except (OSError, ValueError):
                            pass
                        if time.monotonic() >= deadline:
                            raise TimeoutError("adapter startup deadline")
                        time.sleep(.1)
                    status, body = http(port, "GET", "/capabilities", timeout=2)
                    summary["capabilities_http_status"] = status
                    summary["capabilities"] = json.loads(body)
                    for index, (case, raw) in enumerate(cases):
                        started = time.monotonic()
                        item = {"index": index, **case, "request_bytes": len(raw)}
                        next_case = index + 1
                        try:
                            status, body = http(port, "POST", "/query", raw, query_timeout+12)
                            item.update(http_status=status, latency_seconds=round(time.monotonic()-started, 6),
                                        response_bytes=len(body), response_body_base64=base64.b64encode(body).decode())
                            try:
                                decoded = json.loads(body)
                            except (ValueError, UnicodeError):
                                decoded = None
                            item.update(state="response", response=decoded)
                            if status >= 400:
                                summary["http_errors"] += 1
                            summary["completed"] += 1
                            record(item)
                            print(f"{index+1}/{len(cases)} {case['id']}: HTTP {status}", flush=True)
                            if status in (502, 503, 504, 507) or (isinstance(decoded, dict) and decoded.get("error") in ("backend_unavailable", "worker_lost", "query_timeout")):
                                reason = f"fatal backend response HTTP {status}"
                                break
                        except (OSError, ValueError) as error:
                            reason = f"{type(error).__name__}: {error}"
                            item.update(state="transport_error", http_status=None, latency_seconds=round(time.monotonic()-started, 6),
                                        error=reason, state_may_have_changed=True)
                            summary["transport_errors"] += 1
                            record(item)
                            break
                finally:
                    if child is not None:
                        stop_owned(child)
                        summary["adapter_returncode"] = child.returncode
        except BaseException as error:
            reason = f"{type(error).__name__}: {error}"
        finally:
            for index in range(next_case, len(cases)):
                record({"index": index, **cases[index][0], "state": "not_run", "http_status": None,
                        "reason": reason or "batch interrupted"})
                summary["not_run"] += 1
            summary.update(stop_reason=reason, elapsed_seconds=round(time.monotonic()-began, 3),
                           finished=reason is None and next_case == len(cases))
            (out / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2)+"\n")
    return 0 if summary["finished"] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cases", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True, help="new private output directory")
    parser.add_argument("--runtime", type=Path, default=DEFAULT_RUNTIME)
    parser.add_argument("--query-timeout", type=float, default=30)
    parser.add_argument("--startup-timeout", type=float, default=120)
    args = parser.parse_args()
    try:
        if args.cases.stat().st_size > 1024 * 1024:
            raise ValueError("cases file exceeds 1 MiB")
        cases = validate_cases(json.loads(args.cases.read_text(), object_pairs_hook=unique_pairs))
        for value in (args.query_timeout, args.startup_timeout):
            if not math.isfinite(value) or not 1 <= value <= 300:
                raise ValueError("timeouts must be between 1 and 300 seconds")
    except (OSError, ValueError, UnicodeError) as error:
        parser.error(str(error))
    def interrupted(signum, _):
        raise InterruptedError(f"received signal {signum}")
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    return run(cases, args.out, args.runtime, args.query_timeout, args.startup_timeout)


if __name__ == "__main__":
    raise SystemExit(main())
