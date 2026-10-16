#!/usr/bin/env python3
"""Packaged veri7vn as an answerer (docs/contracts/answerer.md).

  veri7vn_packaged.py <generation-dir> [--state DIR]

Each question runs `<generation>/bin/veri7vn launch --state DIR --surface workbench -- run "<q>"` (about 18 s a call).
"Status: accepted_exact" with result content is answered (the HTML is reduced to text); the
"Native interpretation requires attention: <reason>" failure is withheld with path veri7vn:<reason>; anything else is
withheld with path veri7vn:status:<status> or veri7vn:exit:<code>. The state dir (default var/parity/veri7vn-state)
must lie outside the package; it is reused across calls (it is about 0.5 GB once populated)."""
from __future__ import annotations

import argparse
import html
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def parse(out, code):
    m = re.search(r"Native interpretation requires attention:\s*([\w\-]+)", out)
    if m:
        return {"status": "withheld", "response": "", "path": "veri7vn:%s" % m.group(1)}
    st = re.search(r"^Status:\s*(\S+)", out, re.M)
    req = re.search(r"^Request\s+(\d+)", out, re.M)
    prov = {"request": int(req.group(1))} if req else {}
    if st and st.group(1) == "accepted_exact":
        body = out[st.end():]
        paras = re.findall(r"<p>(.*?)</p>", body, re.S)
        text = " ".join(html.unescape(re.sub(r"<[^>]+>", "", p)).strip() for p in paras) if paras else ""
        if text:
            return {"status": "answered", "response": text, "path": "veri7vn:accepted_exact", "provenance": prov}
        return {"status": "withheld", "response": "", "path": "veri7vn:accepted_exact:no_content", "provenance": prov}
    if st:
        return {"status": "withheld", "response": "", "path": "veri7vn:status:%s" % st.group(1), "provenance": prov}
    return {"status": "withheld", "response": "", "path": "veri7vn:exit:%d" % code,
            "provenance": {"tail": out.strip().splitlines()[-1][:300] if out.strip() else ""}}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("generation")
    ap.add_argument("--state", default=str(REPO / "var" / "parity" / "veri7vn-state"))
    ap.add_argument("--timeout", type=float, default=240.0)
    a = ap.parse_args()
    gen = Path(a.generation).resolve()
    exe = gen / "bin" / "veri7vn"
    state = Path(a.state).resolve()
    if gen in state.parents or state == gen:
        ap.error("--state must lie outside the package")
    for line in sys.stdin:
        if not line.strip():
            continue
        req = json.loads(line)
        try:
            p = subprocess.run([str(exe), "launch", "--state", str(state), "--surface", "workbench", "--", "run", str(req.get("q", ""))],
                               capture_output=True, text=True, timeout=a.timeout)
            out = parse(p.stdout + "\n" + p.stderr, p.returncode)
        except subprocess.TimeoutExpired:
            out = {"error": "veri7vn run timed out after %ss" % a.timeout, "response": "", "path": "veri7vn:timeout"}
        out["id"] = req.get("id")
        sys.stdout.write(json.dumps(out, ensure_ascii=False) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
