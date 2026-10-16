#!/usr/bin/env python3
"""measure - lane F driver: Oracle7's recorded relation answers vs the veri7vn reader.

  measure.py head  [--out var/reader/head_answers.jsonl]   run the Oracle7 head over the selected items, keep its text
  measure.py run   [--out var/reader/reader_answers.jsonl] run tools/reader/answerer.py over the same items
  measure.py report                                         compare the two files and print the counts

Items: every core-panel item whose recorded path contains organ:relation or starts with general_reader: (the
"relation" group), plus the panel's exact_router items as a separate group, plus PROBES (held-out-style, chosen
because the store holds several values for the asked property). Read-only against upstream/."""
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PANEL = REPO / "upstream/workbench/data/core_panel.json"
VAR = REPO / "var/reader"
PROBES = ["What is the capital of South Africa?", "What is the capital of Bolivia?", "What is the capital of Malaysia?",
          "Who directed The Matrix?", "Who composed the opera Carmen?", "Is Paris the capital of France?",
          "Who directed the film that won Best Picture in 1998?", "What is the capital of the province of Ontario?"]


def items():
    panel = json.load(open(PANEL))["items"]
    out = []
    for i, it in enumerate(panel):
        p = it.get("path") or ""
        if "organ:relation" in p or p.startswith("general_reader:"):
            out.append({"id": "panel:%d" % i, "group": "relation", "q": it["q"], "o7_path": p, "o7_status": it["status"]})
        elif p.startswith("exact_router"):
            out.append({"id": "panel:%d" % i, "group": "exact_router", "q": it["q"], "o7_path": p, "o7_status": it["status"]})
    out += [{"id": "probe:%d" % i, "group": "probe", "q": q, "o7_path": None, "o7_status": None} for i, q in enumerate(PROBES)]
    return out


def head(out):
    os.environ.setdefault("ORACLE7_STATE", str(VAR / "state"))
    assert os.environ.get("PYTHONHASHSEED") == "0", "run with PYTHONHASHSEED=0"
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(REPO / "upstream"))
    import oracle7
    t0 = time.time()
    eng = oracle7.Engine()
    # lane A's redirect (tools/parity/answerers/oracle7.py, commit 4b1521c): the head's self_loop folds write next
    # to the admitted modules inside upstream/ regardless of ORACLE7_STATE; point those globals into var/reader/.
    sys.path.insert(0, str(REPO / "tools/parity/answerers"))
    import importlib.util
    spec = importlib.util.spec_from_file_location("laneA_oracle7", REPO / "tools/parity/answerers/oracle7.py")
    laneA = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(laneA)
    print("redirected:", laneA.redirect_self_loop(VAR / "self_loop"), file=sys.stderr)
    print("head cold start %.1fs" % (time.time() - t0), file=sys.stderr)
    with open(out, "w") as f:
        for it in items():
            t = time.time()
            r = eng.chat(it["q"], "laneF-" + it["id"])
            f.write(json.dumps({"id": it["id"], "q": it["q"], "status": r.get("status"), "path": r.get("path"),
                                "response": r.get("response"), "ms": round(1000 * (time.time() - t))}) + "\n")
            f.flush()


def run(out):
    its = items()
    p = subprocess.Popen([sys.executable, str(REPO / "tools/reader/answerer.py")], stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, text=True)
    t0 = time.time()
    with open(out, "w") as f:
        for it in its:
            p.stdin.write(json.dumps({"id": it["id"], "q": it["q"], "session": "laneF-" + it["id"]}) + "\n")
            p.stdin.flush()
            r = json.loads(p.stdout.readline())
            f.write(json.dumps(dict(r, q=it["q"])) + "\n")
    p.stdin.close()
    p.wait()
    print("reader: %d items in %.1fs" % (len(its), time.time() - t0), file=sys.stderr)


def norm(s):
    import unicodedata
    s = unicodedata.normalize("NFKD", str(s)).encode("ascii", "ignore").decode("ascii")
    return " ".join(re.sub(r"[^a-z0-9 ]+", " ", s.lower()).split())


def report(head_f, reader_f):
    its = {it["id"]: it for it in items()}
    H = {json.loads(l)["id"]: json.loads(l) for l in open(head_f)}
    R = {json.loads(l)["id"]: json.loads(l) for l in open(reader_f)}
    from collections import Counter
    for g in ("relation", "exact_router", "probe"):
        ids = [i for i in its if its[i]["group"] == g]
        refuse, ans, same, diff = Counter(), 0, 0, []
        for i in ids:
            r = R[i]
            if r["status"] != "answered":
                refuse[(r.get("provenance") or {}).get("refusal", r.get("error", "?"))] += 1
                continue
            ans += 1
            h = H.get(i) or {}
            v = norm(r.get("value") or "")
            if h.get("status") == "answered" and v and v in norm(h.get("response") or ""):
                same += 1
            else:
                diff.append((i, r["q"], r.get("value"), (h.get("response") or "")[:120], h.get("status")))
        print("== %s: %d items; reader answered %d, refused %d; answer text agrees with Oracle7 head %d/%d"
              % (g, len(ids), ans, sum(refuse.values()), same, ans))
        print("   refusals:", dict(refuse.most_common()))
        for d in diff:
            print("   DIFF", d)
    hs = Counter((H[i]["status"], its[i]["o7_status"]) for i in H if its[i]["group"] != "probe")
    print("head now vs panel status:", dict(hs))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"
    if cmd == "head":
        head(sys.argv[2] if len(sys.argv) > 2 else str(VAR / "head_answers.jsonl"))
    elif cmd == "run":
        run(sys.argv[2] if len(sys.argv) > 2 else str(VAR / "reader_answers.jsonl"))
    else:
        report(str(VAR / "head_answers.jsonl"), str(VAR / "reader_answers.jsonl"))
