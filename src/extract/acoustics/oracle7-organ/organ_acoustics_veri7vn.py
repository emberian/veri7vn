#!/usr/bin/env python3
"""organ_acoustics_veri7vn - Oracle7's acoustics specialist answered by veri7vn's extracted binary.

The binary (built from a verified Isabelle/HOL kernel, see veri7vn src/extract/acoustics) is started once per
process and spoken to over the answerer contract: one JSON line per question in, one JSON line per reply out.
Each answer() call is piped through it and the reply mapped to Oracle7's organ shape
{kind, status, response, value}; a question the binary does not take returns None, as the shipped organ does.

The binary is found at $VERI7VN_ACOUSTICS_BIN, else bin/acoustics beside this file, else
var/acoustics/bin/acoustics in the veri7vn checkout this file lives in."""
from __future__ import annotations

import json
import os
import subprocess
import threading
from pathlib import Path

HERE = Path(__file__).resolve().parent


def binary_path():
    env = os.environ.get("VERI7VN_ACOUSTICS_BIN")
    if env:
        return Path(env)
    local = HERE / "bin" / "acoustics"
    if local.exists():
        return local
    for parent in HERE.parents:
        cand = parent / "var" / "acoustics" / "bin" / "acoustics"
        if cand.exists():
            return cand
    raise FileNotFoundError("veri7vn acoustics binary not found; set VERI7VN_ACOUSTICS_BIN")


class AcousticsVeri7vnOrgan:
    def __init__(self, binary=None):
        self.binary = str(binary or binary_path())
        self.proc = None
        self.lock = threading.Lock()
        self.n = 0

    def _start(self):
        self.proc = subprocess.Popen([self.binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     stderr=subprocess.DEVNULL, text=True, encoding="utf-8", bufsize=1)

    def _ask(self, text, session_id):
        with self.lock:
            for attempt in (0, 1):                      # one restart if the binary died
                if self.proc is None or self.proc.poll() is not None:
                    self._start()
                self.n += 1
                try:
                    self.proc.stdin.write(json.dumps({"id": str(self.n), "q": text, "session": session_id}) + "\n")
                    self.proc.stdin.flush()
                    line = self.proc.stdout.readline()
                except (BrokenPipeError, OSError):
                    line = ""
                if line:
                    return json.loads(line)
                self.proc = None
            return None

    def answer(self, text, session_id="default"):
        rep = self._ask(str(text or ""), str(session_id))
        if not rep or "error" in rep or not (rep.get("provenance") or {}).get("taken", True):
            return None
        return {"kind": rep.get("kind"), "status": rep.get("status", "withheld"),
                "response": rep.get("response", ""), "value": rep.get("value")}

    def close(self):
        if self.proc is not None and self.proc.poll() is None:
            self.proc.stdin.close()
            self.proc.wait(timeout=5)
