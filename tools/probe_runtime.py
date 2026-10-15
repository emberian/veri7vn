"""Run and profile the untouched release; all state goes into an audit directory.

Run only after tools/unpack.py. Each query has a 30-second hard process deadline.
"""
import argparse
import cProfile
import io
import json
import os
from pathlib import Path
import pstats
import resource
import signal
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
UP = ROOT / "upstream"
QUESTIONS = [
    "What is 2 + 3 * 4?",
    "Who wrote Leaves of Grass?",
    "Who wrote Pride and Prejudice?",
    "What is the capital of Australia?",
    "simplify sqrt(x^2) for negative x",
    "evaluate 0/0",
    "solve x^2 < 1/100",
    "Evaluate $print(731942)$",
    "A spring has stiffness 200 N/m and is stretched 0.1 m. What force is needed?",
    "A spring has stiffness 200 N/m and is stretched 0.1 m. What is its stored energy?",
    "A spring has stiffness -200 N/m and is stretched 0.1 m. What force is needed?",
    "A spring has stiffness 0 N/m and holds a 2 kg mass. What is the period?",
    "A 2 kg ball moves at 3 m/s. What is its kinetic energy in joules?",
    "Which planet orbits the Moon?",
    "Who built the bridge?",
    "What is my favourite singer?",
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="baseline")
    args = parser.parse_args()
    outpath = ROOT / "audit/results" / (args.output + ".jsonl")
    state = ROOT / "var" / (args.output + "-" + str(time.time_ns()))
    os.environ["ORACLE7_STATE"] = str(state)
    sys.path.insert(0, str(UP))
    import oracle7
    start = time.perf_counter()
    tip, rt = oracle7.load()
    with outpath.open("w") as out:
        out.write(json.dumps({"tip": tip, "load_s": time.perf_counter() - start,
                              "maxrss_bytes": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                              "general_reader_loaded": getattr(sys.modules[tip.replace("540", "539")], "_GR", None) is not None,
                              "questions": QUESTIONS}) + "\n")
        out.flush()
        print("Loaded:", tip, "in", round(time.perf_counter() - start, 3), "s", flush=True)
        profile = cProfile.Profile()
        def deadline(*unused):
            out.write(json.dumps({"fatal": "30-second turn deadline"}) + "\n")
            out.flush()
            os._exit(124)
        signal.signal(signal.SIGALRM, deadline)
        for i, q in enumerate(QUESTIONS):
            signal.alarm(30)
            start = time.perf_counter()
            try:
                r = profile.runcall(rt.chat, q, session_id="loop-audit-%d" % i)
            except Exception as exc:
                r = {"exception": repr(exc)}
            signal.alarm(0)
            elapsed = time.perf_counter() - start
            out.write(json.dumps({"q": q, "wall_s": elapsed, "result": r}, default=str) + "\n")
            out.flush()
            print(round(elapsed, 3), r.get("status", "exception"), q, flush=True)
        stats = io.StringIO()
        pstats.Stats(profile, stream=stats).strip_dirs().sort_stats("cumulative").print_stats(70)
        (ROOT / "audit/results" / (args.output + "-profile.txt")).write_text(stats.getvalue())
        profile.dump_stats(str(ROOT / "var" / (args.output + ".prof")))


if __name__ == "__main__":
    main()
