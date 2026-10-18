#!/usr/bin/env python3
"""UNTRUSTED live integration probe scorer; never a replacement for shipped panels."""
import json
import selectors
import statistics
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]


def main():
    probes = json.loads((HERE / "frontdoor_probes.json").read_text())
    start = time.perf_counter()
    process = subprocess.Popen([sys.executable, "-I", "-B", str(HERE / "frontdoor.py")],
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    rows = []
    try:
        cases = [(q, answer) for q, answer in probes["positive"]] + [(q, None) for q in probes["negative"]]
        for i, (q, answer) in enumerate(cases):
            t0 = time.perf_counter()
            process.stdin.write(json.dumps({"id": i, "q": q, "session": "probe-%d" % i}) + "\n")
            process.stdin.flush()
            if not selector.select(10):
                raise RuntimeError("frontdoor did not answer within 10 seconds")
            out = json.loads(process.stdout.readline())
            ms = 1000 * (time.perf_counter() - t0)
            passed = not out.get("error") and out["id"] == i and (
                out["status"] != "answered" if answer is None else
                out["status"] == "answered" and out.get("value") == answer and out["provenance"]["taken"])
            rows.append({"q": q, "expected": answer, "passed": passed, "elapsed_ms": ms, "reply": out})
        process.stdin.close()
        process.wait(timeout=5)
    finally:
        selector.close()
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
    result = {"positive_right": sum(r["passed"] for r in rows if r["expected"] is not None),
              "positive_n": len(probes["positive"]),
              "negative_abstained": sum(r["passed"] for r in rows if r["expected"] is None),
              "negative_n": len(probes["negative"]),
              "errors": sum(bool(r["reply"].get("error")) for r in rows),
              "first_reply_ms": rows[0]["elapsed_ms"],
              "warm_p50_ms": statistics.median(r["elapsed_ms"] for r in rows[1:]),
              "elapsed_ms": 1000 * (time.perf_counter() - start), "items": rows}
    dest = REPO / "var/relations/codex-frontdoor-probes.json"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "items"}))
    if not all(r["passed"] for r in rows):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
