#!/usr/bin/env python3
"""Bounded Scry HTTP research client; credentials stay in this process.

Examples:
  .venv/bin/python tools/research_scry.py context
  .venv/bin/python tools/research_scry.py schema --relation arxiv.papers
  .venv/bin/python tools/research_scry.py query --sql-file query.sql --output var/research/scry/run.json

Contract: https://scry.io/docs/sql-over-https and /docs/errors.
No automatic retries. Query budget defaults to 10 million nanodollars ($0.01
raw machine burden); this is the documented exposure limit, not a price quote.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request

BASE = "https://api.scry.io"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError("Scry redirects are disabled to protect credentials")


def request(kind: str, *, relation=None, sql=None, budget=10_000_000, seconds=30):
    if kind not in {"context", "schema", "query"}:
        raise ValueError("unsupported route")
    if not 1 <= seconds <= 120 or not 1 <= budget <= 100_000_000:
        raise ValueError("request exceeds local time/exposure guard")
    key = Path.home().joinpath(".scry-key").read_text().strip()
    if not key or "\n" in key or "\r" in key:
        raise ValueError("Scry credential must be one nonempty line")
    headers = {"Accept": "application/json"}
    if kind != "context":
        headers["Authorization"] = "Bearer " + key
    url = BASE + "/v1/scry/" + kind
    data = None
    if kind == "context":
        url += "?mode=agent"
    elif kind == "schema" and relation:
        url += "?" + urllib.parse.urlencode({"relation": relation})
    elif kind == "query":
        limits = re.findall(r"\bLIMIT\s+(\d+)\b", sql or "", re.I)
        if not limits or any(not 1 <= int(n) <= 1000 for n in limits):
            raise ValueError("SQL must include a literal LIMIT <= 1000")
        if len(sql) > 20_000:
            raise ValueError("SQL exceeds local 20 KB guard")
        if not re.match(r"\s*(SELECT|WITH)\b", sql, re.I):
            raise ValueError("only SELECT/WITH queries are permitted")
        data = sql.encode()
        headers.update({"Content-Type": "text/plain", "x-scry-budget": str(budget),
                        "x-scry-max-multiplier": "1",
                        "x-scry-max-seconds": str(seconds),
                        "idempotency-key": "veri7vn-research-" + hashlib.sha256(data).hexdigest()})
    ctx = ssl.create_default_context()
    # Homebrew's standard CA bundle, where present; never disable verification.
    ca = Path("/opt/homebrew/etc/openssl@3/cert.pem")
    if ca.exists():
        ctx.load_verify_locations(str(ca))
    opener = urllib.request.build_opener(NoRedirect(), urllib.request.HTTPSHandler(context=ctx))
    req = urllib.request.Request(url, data=data, headers=headers)
    try:
        with opener.open(req, timeout=seconds + 20) as response:
            raw = response.read(20_000_001)
    except urllib.error.HTTPError as exc:
        raw = exc.read(100_000)
    except Exception as exc:
        raise RuntimeError(str(exc).replace(key, "[REDACTED]")) from None
    if len(raw) > 20_000_000:
        raise RuntimeError("response exceeds local 20 MB guard")
    return json.loads(raw.decode().replace(key, "[REDACTED]"))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("kind", choices=["context", "schema", "query"])
    p.add_argument("--relation")
    p.add_argument("--sql-file", type=Path)
    p.add_argument("--output", type=Path)
    p.add_argument("--budget", type=int, default=10_000_000)
    p.add_argument("--seconds", type=int, default=30)
    a = p.parse_args()
    try:
        result = request(a.kind, relation=a.relation,
                         sql=a.sql_file.read_text() if a.sql_file else None,
                         budget=a.budget, seconds=a.seconds)
    except Exception as exc:
        print(f"Scry request failed: {exc}", file=sys.stderr)
        return 1
    rendered = json.dumps(result, indent=2, ensure_ascii=False) + "\n"
    if a.output:
        a.output.parent.mkdir(parents=True, exist_ok=True)
        a.output.write_text(rendered)
        print(json.dumps({"saved": str(a.output), "bytes": len(rendered),
                          "error": result.get("error") if isinstance(result, dict) else None}))
    else:
        print(rendered)
    return int(isinstance(result, dict) and "error" in result)


if __name__ == "__main__":
    raise SystemExit(main())
