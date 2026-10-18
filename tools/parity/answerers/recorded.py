#!/usr/bin/env python3
"""Replays a recorded dialogue run through the answerer contract (docs/contracts/answerer.md). UNTRUSTED test fixture.

  recorded.py <script.json> <run.json>

It keeps session state the way a real dialogue answerer must: each session id has a turn counter, and a request is
answered with the next recorded reply of that dialogue only if its question matches the script's next turn. A question
out of order, or a session that is not one of the script's, is withheld with path "recorded:mismatch". It never runs
Oracle7. Session ids are mapped to dialogues in order of first appearance."""
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import dialogue  # noqa: E402


def main():
    script = dialogue.load_script(sys.argv[1])
    run = dialogue.load_run(sys.argv[2])
    by = {(i["d"], i["t"]): i for i in run["items"]}
    sessions = {}                                   # session id -> [dialogue index, next turn]
    for line in sys.stdin:
        req = json.loads(line)
        sid = req.get("session")
        if sid not in sessions:
            sessions[sid] = [len(sessions), 0]
        d, t = sessions[sid]
        out = {"id": req["id"], "status": "withheld", "response": "", "path": "recorded:mismatch"}
        if d < len(script) and t < len(script[d]) and script[d][t]["q"] == req["q"]:
            i = by[(d, t)]
            out = {"id": req["id"], "status": i["status"], "response": i["reply"], "path": i.get("path", "")}
            sessions[sid][1] += 1
        print(json.dumps(out, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
