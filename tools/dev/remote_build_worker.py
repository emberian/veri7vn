#!/usr/bin/env python3
"""Remote half of remote-build. One lock and one writable cache per host.

The first invocation copies warm heaps, never links writable databases to old
state. All jobs use a transient systemd service, so timeout/stop kills the whole
owned cgroup, including detached Isabelle workers. No process-pattern killing.
"""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import sys
import time

GIB = 1024 ** 3
MIN_DISK = 20 * GIB
MEMORY_CAP = 16 * GIB


def atomic_json(path, value):
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(value, indent=2) + "\n")
    os.replace(temp, path)


def active_heap_writers():
    writers = {}
    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit():
            continue
        try:
            words = (proc / "cmdline").read_bytes().split(b"\0")
            if not words or Path(os.fsdecode(words[0])).name != "poly":
                continue
            args = b" ".join(words).decode(errors="replace")
            match = re.search(r'ML_Heap.save_child "([^"]+)"', args)
            if match:
                writers[proc.name] = match.group(1)
        except (OSError, ProcessLookupError):
            continue
    return writers


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def seed_state(managed, result):
    state = managed / "user-state"
    marker = state / "seed.json"
    if marker.exists():
        result["seed"] = json.loads(marker.read_text())
        return state
    legacy = Path.home() / "tools/isabelle-rc1/user-state/.isabelle/Isabelle2026-RC1/heaps"
    before = active_heap_writers()
    excluded = {Path(path).name for path in before.values()}
    if "HOL" in excluded:
        # The installed HOL heap must load its matching installed Pure parent.
        # A legacy user Pure can force an unnecessary full HOL rebuild.
        excluded.add("Pure")
    # A global host lock, held by our caller, protects initialization as well.
    pending = managed / ("seed-" + result["attempt"])
    target = pending / ".isabelle/Isabelle2026-RC1/heaps"
    files = [p for p in legacy.rglob("*") if p.is_file() and not p.is_symlink()
             and p.name.split(".")[0] not in excluded
             and not p.name.endswith(("-wal", "-shm", "-journal"))]
    size = sum(p.stat().st_size for p in files)
    if shutil.disk_usage(managed).free < MIN_DISK + size:
        raise RuntimeError(f"need 20 GiB disk reserve plus {size} bytes for one warm-cache copy")
    inventory = {}
    for source in files:
        relative = source.relative_to(legacy)
        dest = target / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        if source.suffix == ".db":
            # Read-only SQLite backup gives a consistent database; no writable links.
            with sqlite3.connect(source.as_uri() + "?mode=ro", uri=True) as src:
                with sqlite3.connect(dest) as dst:
                    src.backup(dst)
        else:
            stamp = source.stat()
            shutil.copy2(source, dest)
            if source.stat().st_mtime_ns != stamp.st_mtime_ns or source.stat().st_size != stamp.st_size:
                raise RuntimeError("warm heap changed during copy: " + str(source))
        inventory[str(relative)] = {"bytes": dest.stat().st_size, "sha256": digest(dest)}
    after = active_heap_writers()
    if set(after.values()) - set(before.values()):
        raise RuntimeError("new unmanaged writer appeared during warm-cache snapshot; retry after inspection")
    seed = {"source": str(legacy), "bytes": size, "excluded_writers": before, "excluded_sessions": sorted(excluded),
            "files": inventory, "created": time.time(), "method": "independent copies; SQLite backup"}
    atomic_json(pending / "seed.json", seed)
    # Only rename our complete cache into the permanent managed path.
    pending.rename(state)
    result["seed"] = seed
    return state


def resources(managed):
    free = shutil.disk_usage(managed).free
    if free < MIN_DISK:
        raise RuntimeError("disk free is below 20 GiB reserve; stop writing and report")
    values = subprocess.check_output(["systemctl", "--user", "show", "swarm.slice",
                                      "-p", "MemoryMax", "-p", "MemoryCurrent"], text=True)
    props = dict(line.split("=", 1) for line in values.splitlines() if "=" in line)
    cap = props.get("MemoryMax", "infinity")
    if cap == "infinity":
        raise RuntimeError("swarm.slice has no enforced memory limit")
    current = int(props["MemoryCurrent"])
    available = next(int(line.split()[1]) * 1024 for line in Path("/proc/meminfo").read_text().splitlines()
                     if line.startswith("MemAvailable:"))
    if int(cap) - current < MEMORY_CAP + 2 * GIB or available < MEMORY_CAP + 2 * GIB:
        return None
    return {"disk_free": free, "slice_cap": int(cap), "slice_current": current,
            "memory_available": available, "job_cap": MEMORY_CAP}


def main():
    attempt = Path.cwd()
    config = json.loads((attempt / "config.json").read_text())
    managed = attempt.parent.parent
    results = attempt / "results"
    results.mkdir(exist_ok=True)
    result = {"attempt": config["attempt"], "session": config["session"], "exit_code": 1,
              "source_digest": config["source_digest"], "started": time.time()}
    unit = "veri7vn-build-" + config["attempt"].lower()
    log = (results / "build.log").open("w")
    service_started = False
    try:
        lock = (managed / "build.lock").open("a")
        deadline = time.monotonic() + config["queue_timeout"]
        while True:
            if (attempt / "cancel").exists():
                raise RuntimeError("cancelled while queued")
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise RuntimeError("host build queue timeout")
                time.sleep(2)
        while True:
            check = resources(managed)
            if check is not None:
                result["resources"] = check
                break
            if (attempt / "cancel").exists() or time.monotonic() >= deadline:
                raise RuntimeError("memory wait cancelled or timed out")
            time.sleep(3)
        state = seed_state(managed, result)
        if (attempt / "cancel").exists():
            raise RuntimeError("cancelled before build start")
        result["user_state"] = str(state)
        result["unmanaged_writers"] = active_heap_writers()
        isabelle = Path.home() / "tools/isabelle-rc1/Isabelle2026-RC1/bin/isabelle"
        env = os.environ | {"USER_HOME": str(state)}
        dirs = ["-d", config["session_dir"]]
        for directory in config["extra"]:
            dirs += ["-d", directory]
        # Transient service ownership is exact and persists if SSH disappears.
        # RuntimeMaxSec and KillMode bound detached workers as well as the launcher.
        command = ["systemd-run", "--user", "--wait", "--pipe", "--collect", "--quiet",
                   "--unit=" + unit, "--slice=swarm.slice", "--working-directory=" + str(attempt),
                   "--setenv=USER_HOME=" + str(state), "--setenv=PATH=" + os.environ["PATH"],
                   "-p", "MemoryMax=" + str(MEMORY_CAP), "-p", "MemorySwapMax=0",
                   "-p", "RuntimeMaxSec=" + str(config["timeout"]), "-p", "TimeoutStopSec=30",
                   "-p", "KillMode=control-group", "-p", "CPUWeight=50", "-p", "Nice=15",
                   "-p", "OOMScoreAdjust=0", sys.executable, str(attempt / "worker.py"),
                   "--run-build", str(isabelle), "build", "-v", "-b", *dirs,
                   "-j", "1", "-o", "threads=2", config["session"]]
        result["command"] = command
        result["unit"] = unit
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=env)
        service_started = True
        while process.poll() is None:
            if (attempt / "cancel").exists():
                subprocess.run(["systemctl", "--user", "stop", unit], stdout=log, stderr=log, timeout=45)
                result["cancelled"] = True
            time.sleep(1)
        result["launcher_exit"] = process.returncode
        completed = results / "build-exit.json"
        result["build_completed"] = completed.exists()
        result["build_exit"] = json.loads(completed.read_text())["exit_code"] if completed.exists() else 1
        result["cancelled"] = result.get("cancelled", False) or (attempt / "cancel").exists()
        if result["cancelled"]:
            result["build_exit"] = 1
        # Keep the host lock until diagnostics and export finish: build_log/export
        # read session databases that another build could otherwise replace.
        stored = results / "session.log"
        with stored.open("w") as f:
            logged = subprocess.run([str(isabelle), "build_log", "-v", config["session"]],
                                    env=env, stdout=f, stderr=subprocess.STDOUT, timeout=120)
        result["log_exit"] = logged.returncode
        export = results / "export" / config["session"]
        export.mkdir(parents=True)
        if result["build_exit"] or config.get("no_exports", False):
            result["export_exit"] = 0
            result["exports_skipped"] = True
        else:
            exported = subprocess.run([str(isabelle), "export", "-n", *dirs, "-O", str(export),
                                       "-x", "*:code/**", "-x", "*:veri7vn/assertions/**", config["session"]],
                                      env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120)
            result["export_exit"] = exported.returncode
        log.flush()
        marker = config["expect"]
        bodies = [stored.read_text(errors="replace"), (results / "build.log").read_text(errors="replace")]
        bodies += [p.read_text(errors="replace") for p in export.rglob("*") if p.is_file()]
        result["marker_found"] = not marker or any(marker in body for body in bodies)
        result["cancelled"] = result["cancelled"] or (attempt / "cancel").exists()
        result["exit_code"] = (1 if result["cancelled"] else
                               result["build_exit"] or process.returncode or result["export_exit"] or
                               (0 if result["marker_found"] else 1))
        if not result["marker_found"]:
            print("remote-build: marker not found: " + marker, file=log)
    except Exception as exc:
        result["error"] = str(exc)
        print("remote-build: " + str(exc), file=log)
    finally:
        if service_started:
            # Exact service we created, never a process pattern or someone else's job.
            try:
                stopped = subprocess.run(["systemctl", "--user", "stop", unit],
                                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                         text=True, timeout=45)
                result["stop_exit"] = stopped.returncode
                diagnostic = getattr(stopped, "stdout", "") or ""
                if stopped.returncode and "not loaded" not in diagnostic:
                    result["cleanup_error"] = diagnostic
                    result["exit_code"] = 1
                    print(diagnostic, file=log)
            except Exception as exc:
                result["cleanup_error"] = str(exc)
                result["exit_code"] = 1
        if (attempt / "cancel").exists():
            result["cancelled"] = True
            result["exit_code"] = 1
        result["finished"] = time.time()
        log.close()
        atomic_json(attempt / "result.json", result)
        if "lock" in locals():
            lock.close()


if __name__ == "__main__":
    if sys.argv[1:2] == ["--run-build"]:
        # This completion evidence is written *inside* the owned service, after
        # Isabelle actually returns. systemd-run can return zero when an explicit
        # stop killed the service, so its own return code is not build evidence.
        build = subprocess.run(sys.argv[2:])
        atomic_json(Path.cwd() / "results/build-exit.json",
                    {"exit_code": build.returncode, "finished": time.time()})
        sys.exit(build.returncode)
    main()
