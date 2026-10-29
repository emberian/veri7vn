#!/usr/bin/env python3
"""Answerer (docs/contracts/answerer.md) for a running oracle-host: JSON lines in, HTTP POST /query out.

  oracle_host.py --url http://127.0.0.1:PORT [--tenant HEX64] [--run TAG] [--timeout S]

Each request line {id, q, session} becomes one /query turn. The request_id is a hash of (run tag, id, question),
so re-asking the same item in the same run replays the host's journalled reply instead of asking again; the
conversation_id is a hash of the session. The tenant header is a fixed routing key for the run, not
authentication. The reply carries the host's own status, response, path, value and kind, and its provenance,
which lists every route the host asked (provenance.host.candidates). provenance.head is removed: the host only
asks the Engine when no deeper-first route took the question, so head-alone counts would be partial.

Untrusted shim by construction: it neither scores nor changes any reply, and writes nothing anywhere."""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
import urllib.error
import urllib.request


def key(prefix, *parts):
    return prefix + hashlib.sha256("\0".join(parts).encode("utf-8")).hexdigest()[:40]


def post(url, tenant, body, timeout):
    request = urllib.request.Request(url + "/query", data=json.dumps(body).encode("utf-8"), method="POST",
                                     headers={"Content-Type": "application/json", "X-Mini-Oracle-Tenant": tenant})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b"{}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", required=True)
    ap.add_argument("--tenant", default="a" * 64)
    ap.add_argument("--run", default="default")
    ap.add_argument("--timeout", type=float, default=900.0)
    a = ap.parse_args()
    for line in sys.stdin:
        if not line.strip():
            continue
        item = json.loads(line)
        rid, q, session = item.get("id"), str(item.get("q", "")), str(item.get("session", "default"))
        body = {"request_id": key("r", a.run, str(rid), q), "conversation_id": key("c", a.run, session), "text": q}
        out = None
        for attempt in range(60):
            try:
                status, result = post(a.url, a.tenant, body, a.timeout)
            except (OSError, ValueError) as error:
                out = {"error": "%s: %s" % (type(error).__name__, error), "response": "", "path": ""}
                break
            if status == 429 and result.get("retryable"):
                time.sleep(min(30, 1 + attempt))
                continue
            if status == 200 and result.get("outcome") == "completed":
                reply = result["reply"]
                out = {k: reply[k] for k in ("status", "response", "path", "value", "kind", "references") if k in reply}
                provenance = dict(reply.get("provenance") or {})
                provenance.pop("head", None)
                out["provenance"] = provenance
            else:
                out = {"error": "host %s %s" % (status, result.get("error")), "response": "", "path": "",
                       "provenance": {"host_failure": result}}
            break
        if out is None:
            out = {"error": "host busy after retries", "response": "", "path": ""}
        out["id"] = rid
        sys.stdout.write(json.dumps(out, ensure_ascii=False) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
