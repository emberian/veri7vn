#!/usr/bin/env python3
"""Observe one actual pinned installed shell invocation; steward slot required.

JVM nanosecond spans remain in their own clock domain. Receipt timestamps are
observer times and include transport/scheduling delay; they are not JVM entry.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import queue
import signal
import subprocess
import threading
import time
import sys

from public_runtime import GUARDIAN

PREFIX = 'VERI7VN_LAUNCH_PHASE '


def observe(command, cwd, output, timeout, environment):
    started = time.monotonic_ns()
    read_fd, write_fd = os.pipe()
    try:
        process = subprocess.Popen([sys.executable, '-c', GUARDIAN, str(write_fd), *command],
            cwd=cwd, env=environment, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, start_new_session=True, pass_fds=(write_fd,))
    except BaseException:
        os.close(read_fd)
        raise
    finally:
        os.close(write_fd)
    ready = threading.Event()
    status_queue = queue.Queue()
    markers, reader_errors, first_output = [], [], []

    def status_reader():
        with os.fdopen(read_fd, 'rb') as stream:
            if stream.read(1) != b'R':
                status_queue.put(b'')
                return
            ready.set()
            status_queue.put(stream.readline())

    def stdout_reader(destination):
        try:
            while True:
                chunk = process.stdout.read1(65536)
                if not chunk:
                    break
                if not first_output:
                    first_output.append(time.monotonic_ns())
                destination.write(chunk)
                destination.flush()
        except Exception as problem:
            reader_errors.append(type(problem).__name__)

    def stderr_reader(destination):
        try:
            for line in iter(process.stderr.readline, b''):
                observed = time.monotonic_ns()
                destination.write(line)
                destination.flush()
                if line.startswith(PREFIX.encode()):
                    try:
                        marker = json.loads(line[len(PREFIX):])
                        if not isinstance(marker, dict):
                            raise ValueError('phase marker must be an object')
                        markers.append({'observer_receipt_ns': observed, 'jvm_or_shell_marker': marker})
                    except (ValueError, UnicodeError):
                        reader_errors.append('invalid_phase_marker')
        except Exception as problem:
            reader_errors.append(type(problem).__name__)

    with (output/'stdout.log').open('wb') as stdout, (output/'stderr.log').open('wb') as stderr:
        threads = [threading.Thread(target=status_reader, daemon=True),
                   threading.Thread(target=stdout_reader, args=(stdout,), daemon=True),
                   threading.Thread(target=stderr_reader, args=(stderr,), daemon=True)]
        for thread in threads:
            thread.start()
        try:
            if not ready.wait(5):
                raise RuntimeError('guardian readiness deadline')
            try:
                status = status_queue.get(timeout=timeout)
            except queue.Empty as problem:
                raise TimeoutError('installed client exit deadline') from problem
            exited = time.monotonic_ns()
            if not status:
                raise RuntimeError('guardian lost child exit status')
            result = {'returncode': int(status), 'observer_start_ns': started,
                      'observer_exit_receipt_ns': exited, 'wall_ms': (exited-started)/1e6,
                      'first_stdout_observed_ns': first_output[0] if first_output else None,
                      'clock_domains': {'observer': 'Python monotonic_ns',
                         'marker': 'producer-defined JVM System.nanoTime or shell event; raw epochs must not be mixed with observer clock'},
                      'scope': 'whole pinned installed shell invocation including verification and application; guardian overhead not isolated'}
        finally:
            # The unreaped guardian reserves the owned group ID after client exit.
            try:
                os.killpg(process.pid, signal.SIGTERM)
                time.sleep(.2)
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)
            deadline = time.monotonic()+3
            for thread in threads:
                thread.join(timeout=max(0, deadline-time.monotonic()))
            if any(thread.is_alive() for thread in threads):
                raise RuntimeError('bounded owned output drain exceeded')
        if reader_errors:
            raise RuntimeError('output reader errors: '+','.join(reader_errors))
        result['first_stdout_observed_ns'] = first_output[0] if first_output else None
        result['phase_observations'] = markers
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('generation', type=Path)
    parser.add_argument('--state', required=True, type=Path)
    parser.add_argument('--surface', required=True, choices=('source', 'workbench'))
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--steward-slot', required=True)
    parser.add_argument('--timeout', type=float, default=180)
    parser.add_argument('--expect-stdout-sha256', help='Exact source output oracle; lowercase SHA256')
    parser.add_argument('--expect-line', help='Exact complete output line oracle, such as fixed licensed HTML')
    argv = sys.argv[1:]
    split = argv.index('--') if '--' in argv else len(argv)
    tail = argv[split+1:] if split < len(argv) else []
    args = parser.parse_args(argv[:split])
    if args.expect_stdout_sha256 and (len(args.expect_stdout_sha256) != 64 or any(c not in '0123456789abcdef' for c in args.expect_stdout_sha256)):
        parser.error('expected stdout digest must be lowercase SHA256')
    if not 1 <= args.timeout <= 240:
        parser.error('timeout must be 1..240 seconds')
    generation = args.generation.resolve(strict=True)
    raw = (generation/'manifest.json').read_bytes()
    identity = hashlib.sha256(raw).hexdigest()
    if identity != generation.name:
        parser.error('generation must be the exact content-addressed package root')
    state = args.state.resolve()
    if state == generation.parent or generation.parent in state.parents:
        parser.error('state must be outside immutable generation directory')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    state.mkdir(parents=True, exist_ok=True)
    shell = generation/'bin/veri7vn'
    command = [str(shell), 'launch', '--state', str(state), '--surface', args.surface, '--', *tail]
    environment = dict(os.environ, VERI7VN_LAUNCH_PROFILE='1')
    record = {'format': 'veri7vn.installed-launch-observation/1', 'generation': identity,
              'shell_sha256': hashlib.sha256(shell.read_bytes()).hexdigest(),
              'harness_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'guardian_source_sha256': hashlib.sha256(Path(__file__).with_name('public_runtime.py').read_bytes()).hexdigest(),
              'steward_slot': args.steward_slot, 'command': command, 'status': 'running',
              'workload': {'surface': args.surface, 'arguments': tail},
              'cache_state': 'filesystem uncontrolled; fresh temporary settings home remains actual shell policy',
              'interpretation': 'no latency or correctness success inferred from a phase marker alone'}
    try:
        record['observation'] = observe(command, output, output, args.timeout, environment)
        stdout = (output/'stdout.log').read_bytes()
        oracle = (not args.expect_stdout_sha256 or hashlib.sha256(stdout).hexdigest() == args.expect_stdout_sha256) and (not args.expect_line or args.expect_line.encode() in stdout.splitlines())
        record['oracle'] = {'passed': oracle if args.expect_stdout_sha256 or args.expect_line else None, 'scope': 'exact stdout digest or complete line when supplied; otherwise process exit only'}
        record['phase_instrumentation'] = 'observed' if record['observation']['phase_observations'] else 'unavailable; installed shell may not forward profiling flag'
        record['status'] = 'completed' if record['observation']['returncode'] == 0 and oracle else 'failed'
    except Exception as problem:
        record['status'] = 'failed'
        record['failure'] = str(problem)
        raise
    finally:
        record['logs'] = [{'name': p.name, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest(), 'bytes': p.stat().st_size}
                          for p in (output/'stdout.log', output/'stderr.log') if p.exists()]
        (output/'result.json').write_text(json.dumps(record, indent=2)+'\n')
    if record['status'] != 'completed':
        raise SystemExit(1)


if __name__ == '__main__':
    main()
