"""Measure launching an already-built heap; no builds or global settings."""
import json
import os
from pathlib import Path
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parent
env = dict(os.environ, USER_HOME=str(ROOT / "state"))
command = [
    "/Applications/Isabelle2026-RC1.app/bin/isabelle", "ML_process",
    "-d", str(ROOT), "-l", "Native_Execution_Probe", "-o", "threads=2",
    "-e", 'writeln ("HEAP_READY " ^ Session.get_name ()); Time.sleep (Time.fromSeconds 1);',
]
started = time.monotonic()
process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, text=True)
ready_ms = None
output = []
samples = []

def sample_memory():
    while process.poll() is None:
        listing = subprocess.run(["ps", "-axo", "pid=,ppid=,rss="],
                                 capture_output=True, text=True, check=True)
        rows = [tuple(map(int, row.split())) for row in listing.stdout.splitlines()]
        children = {process.pid}
        changed = True
        while changed:
            changed = False
            for pid, ppid, _ in rows:
                if ppid in children and pid not in children:
                    children.add(pid)
                    changed = True
        sizes = [rss for pid, _, rss in rows if pid in children]
        samples.append(dict(elapsed_ms=(time.monotonic()-started)*1000,
                            rss_kib=sum(sizes), processes=len(sizes)))
        time.sleep(0.1)

sampler = threading.Thread(target=sample_memory)
sampler.start()
for line in process.stdout:
    output.append(line)
    if line.startswith("HEAP_READY"):
        ready_ms = (time.monotonic() - started) * 1000
returncode = process.wait()
sampler.join()
result = dict(command=command, startup_to_ready_ms=ready_ms,
              process_elapsed_ms=(time.monotonic() - started) * 1000,
              returncode=returncode, output="".join(output),
              peak_sampled_process_tree_rss_kib=max(x["rss_kib"] for x in samples),
              memory_samples=samples,
              notes="100ms process-tree RSS samples; shared pages may be counted multiple times; warm filesystem cache; includes command launcher/JVM/ML; holds ML alive 1s after ready")
(ROOT / "startup.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
raise SystemExit(returncode)
