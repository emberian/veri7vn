#!/usr/bin/env python3
"""UNTRUSTED recording shim. Runs lane A's answerer (tools/parity/answerers/oracle7.py, the shipped head w540) unchanged,
except that each reply also carries the engine's own provenance under provenance.engine. The precision guards keep the
organ reply they withheld there (provenance.withheld_path / withheld_response), which lane A's answerer drops; the
guards replay needs it. Same protocol, same state redirection, same environment as lane A's answerer.

  PYTHONHASHSEED=0 PYTHONDONTWRITEBYTECODE=1 .venv/bin/python head_record.py --state var/guards/head/state < req > out
"""
import importlib.util
import os
import sys
from pathlib import Path

if os.environ.get("PYTHONHASHSEED") != "0" or os.environ.get("PYTHONDONTWRITEBYTECODE") != "1":
    os.environ.update(PYTHONHASHSEED="0", PYTHONIOENCODING="utf-8", PYTHONDONTWRITEBYTECODE="1")
    os.execv(sys.executable, [sys.executable, os.path.abspath(__file__)] + sys.argv[1:])
sys.dont_write_bytecode = True

REPO = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("laneA_oracle7", REPO / "tools" / "parity" / "answerers" / "oracle7.py")
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)
_orig = A.answer


def answer(eng, sp, fillable, q, sess, alone):
    box = {}

    class Recorded:
        tip = eng.tip

        def chat(self, text, session_id="default"):
            box["r"] = eng.chat(text, session_id=session_id)
            return box["r"]

    out = _orig(Recorded(), sp, fillable, q, sess, alone)
    r = box.get("r")
    if isinstance(r, dict):
        out.setdefault("provenance", {})["engine"] = r.get("provenance")
    return out


A.answer = answer
if __name__ == "__main__":
    A.main()
