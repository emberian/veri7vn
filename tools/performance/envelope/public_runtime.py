#!/usr/bin/env python3
"""Bounded installed public-client measurements. Execution requires a steward slot.

No builds, synthetic service, cache eviction, or changes to the selected package.
First response includes startup: RuntimeMain currently has no ready notification.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import queue
import signal
import subprocess
import sys
import threading
import time

CASES = (
    ('sum', 'the sum of -2 and 3', '<p>The exact sum of -2 and 3 is 1.</p>'),
    ('product', 'the product of 6 and 7', '<p>The exact product of 6 and 7 is 42.</p>'),
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def footprint(state):
    files = [p for p in state.rglob('*') if p.is_file()]
    return {'files': len(files), 'logical_bytes': sum(p.stat().st_size for p in files),
            'scope': 'workspace logical file sizes; not physical writes, fsync latency or allocated blocks'}


def consume(stream, destination, lines=None):
    try:
        for line in iter(stream.readline, b''):
            destination.write(line)
            destination.flush()
            if lines is not None:
                lines.put((time.monotonic_ns(), line))
    finally:
        if lines is not None:
            lines.put((time.monotonic_ns(), None))


def sample_tree(pid):
    """Read-only process-tree RSS snapshot. Shared pages may be counted repeatedly."""
    result = subprocess.run(['ps', '-axo', 'pid=,ppid=,rss='], capture_output=True, timeout=2, check=True)
    rows = [tuple(map(int, line.split())) for line in result.stdout.splitlines()]
    owned = {pid}
    while True:
        expanded = owned | {p for p, parent, _ in rows if parent in owned}
        if expanded == owned:
            break
        owned = expanded
    return sum(rss * 1024 for p, _, rss in rows if p in owned)


# A session leader remains alive until group cleanup, even after the client exits.
# Its unreaped PID pins the group identity; no signal targets a recycled group ID.
GUARDIAN = """
import os, signal, subprocess, sys
signal.signal(signal.SIGTERM, lambda *_: None)
os.write(int(sys.argv[1]), b'R')
child = subprocess.Popen(sys.argv[2:])
code = child.wait()
os.write(int(sys.argv[1]), (str(code) + '\\n').encode())
while True:
    signal.pause()
"""


def pin_installation(output, generation):
    facade = output/'installation'
    facade.mkdir()
    (facade/'current').symlink_to(generation, target_is_directory=True)
    return facade


def run(command, state, output, index, repeats, timeout):
    events = queue.Queue()
    started = time.monotonic_ns()
    status_read, status_write = os.pipe()
    try:
        process = subprocess.Popen([sys.executable, '-c', GUARDIAN, str(status_write), *command],
                                   cwd=state, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, start_new_session=True, pass_fds=(status_write,))
    except BaseException:
        os.close(status_read)
        raise
    finally:
        os.close(status_write)
    statuses = queue.Queue()
    guardian_ready = threading.Event()
    child_exit = []

    def child_status():
        with os.fdopen(status_read, 'rb') as stream:
            if stream.read(1) != b'R':
                statuses.put(b'')
                return
            guardian_ready.set()
            status = stream.readline()
            child_exit.append(status)
            statuses.put(status)
    rss = []
    errors = []
    stop = threading.Event()

    def sampler():
        while not stop.is_set():
            try:
                rss.append(sample_tree(process.pid))
            except (OSError, ValueError, subprocess.SubprocessError) as problem:
                errors.append(type(problem).__name__)
            stop.wait(.25)

    records = []
    with (output / f'process-{index}.stdout').open('wb') as stdout, (output / f'process-{index}.stderr').open('wb') as stderr:
        threads = [threading.Thread(target=consume, args=(process.stdout, stdout, events)),
                   threading.Thread(target=consume, args=(process.stderr, stderr)),
                   threading.Thread(target=sampler), threading.Thread(target=child_status)]
        for thread in threads:
            thread.daemon = True
        for thread in threads:
            thread.start()
        try:
            if not guardian_ready.wait(5):
                raise RuntimeError('process guardian readiness deadline')
            for number in range(repeats):
                name, question, expected = CASES[number % len(CASES)]
                sent = time.monotonic_ns()
                process.stdin.write((question + '\n').encode())
                process.stdin.flush()
                deadline = time.monotonic() + timeout
                while True:
                    if child_exit and (not child_exit[0] or int(child_exit[0]) != 0):
                        raise RuntimeError('public client exited before licensed output: ' + repr(child_exit[0]))
                    try:
                        received, line = events.get(timeout=min(.1, max(.001, deadline-time.monotonic())))
                    except queue.Empty as problem:
                        if time.monotonic() >= deadline:
                            raise TimeoutError('expected licensed output deadline') from problem
                        continue
                    if line is None:
                        raise RuntimeError('public client closed before expected licensed output')
                    if line.rstrip(b'\r\n') == expected.encode():
                        break
                    if time.monotonic() >= deadline:
                        raise TimeoutError('expected licensed output deadline')
                records.append({'case': name, 'ordinal': number, 'input_bytes': len(question.encode()),
                    'output_bytes': len(expected.encode()), 'send_ns': sent, 'observed_ns': received,
                    'wall_ms': (received-sent)/1e6, 'oracle': 'exact fixed licensed HTML',
                    'scope': 'startup-inclusive-first-response' if number == 0 else 'warm-process-request',
                    'includes': 'native authority/evidence/durable commit/render/protocol; internal attribution unavailable'})
            eof = time.monotonic_ns()
            process.stdin.close()
            try:
                status = statuses.get(timeout=timeout)
            except queue.Empty as problem:
                raise TimeoutError('public client exit deadline') from problem
            if not status:
                raise RuntimeError('process guardian exited without child status')
            code = int(status)
            if code:
                raise RuntimeError(f'public client exit {code}')
            return {'index': index, 'returncode': code, 'samples': records,
                    'elapsed_ms': (time.monotonic_ns()-started)/1e6,
                    'shutdown_after_eof_ms': (time.monotonic_ns()-eof)/1e6,
                    'sampled_tree_peak_rss_bytes': max(rss) if rss else None,
                    'rss_sample_count': len(rss), 'rss_sampling_errors': sorted(set(errors)),
                    'rss_scope': '250ms process-tree sum; includes shared pages repeatedly; transient peaks may be missed',
                    'workspace_after': footprint(state)}
        finally:
            stop.set()
            # poll() is intentionally not used before signaling: the live/unreaped
            # guardian owns this session/group until the final bounded wait.
            if process.returncode is None:
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                    time.sleep(.2)
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait(timeout=5)
            deadline = time.monotonic() + 3
            for thread in threads:
                thread.join(timeout=max(0, deadline-time.monotonic()))
            if any(thread.is_alive() for thread in threads):
                raise RuntimeError('owned output drain exceeded bounded cleanup; escaped descendant may retain pipe')



def launch_partition(stderr_path, first_sample, generation):
    """Partition one response using serial cross-process monotonic boundaries."""
    prefix = 'VERI7VN_LAUNCH_PHASE '
    phases = [json.loads(line[len(prefix):]) for line in stderr_path.read_text().splitlines() if line.startswith(prefix)]
    verifies = [phase for phase in phases if phase.get('phase') == 'full-artifact-verification']
    handoffs = [phase for phase in phases if phase.get('phase') == 'runtime-exec-handoff']
    if len(verifies) != 1 or len(handoffs) != 1:
        raise ValueError('profiled launch needs one full verifier and one exec handoff')
    verify, handoff = verifies[0], handoffs[0]
    if verify.get('status') != 'passed' or verify.get('generation') != generation:
        raise ValueError('profiled verifier did not accept captured generation')
    boundaries = [first_sample['send_ns'], verify['start_ns'], verify['end_ns'], handoff['at_ns'], first_sample['observed_ns']]
    if boundaries != sorted(boundaries):
        raise ValueError('nonmonotonic launch profile')
    return {'phases': phases, 'serial_wall_ms': dict(zip(
        ('send_to_verify_start', 'full_verification', 'verify_end_to_exec', 'exec_to_first_output'),
        ((b-a)/1e6 for a, b in zip(boundaries, boundaries[1:])))),
        'scope': 'same-run disjoint send-to-first-output partition; exec_to_first_output is not isolated Java or native startup'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('installation', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--steward-slot', required=True, help='Recorded slot identity; obtain before execution')
    parser.add_argument('--profile-launch', action='store_true', help='Time real stage verification and exec handoff on stderr without bypassing checks')
    parser.add_argument('--repeats', type=int, default=4)
    parser.add_argument('--timeout', type=float, default=150)
    args = parser.parse_args()
    if not 2 <= args.repeats <= 20 or not 1 <= args.timeout <= 180:
        parser.error('bounded repeats 2..20 and timeout 1..180 required')
    installation = args.installation.resolve(strict=True)
    generation = (installation/'current').resolve(strict=True)
    manifest = generation/'manifest.json'
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    state = output/'workspace'
    state.mkdir()
    stage_launcher = Path(__file__).resolve().parents[2]/'deploy'/'stage.py'
    launcher = Path(__file__).with_name('profile_launch.py').resolve() if args.profile_launch else stage_launcher
    facade = pin_installation(output, generation)
    command = [sys.executable, str(launcher), 'launch', str(facade), '--state', str(state)]
    report = {'format': 'veri7vn.public-runtime-envelope/1', 'status': 'running',
              'generation': generation.name, 'manifest_sha256': digest(manifest),
              'harness_sha256': digest(Path(__file__)), 'launcher_sha256': digest(launcher), 'stage_source_sha256': digest(stage_launcher),
              'launch_profile': args.profile_launch,
              'command': command, 'steward_slot': args.steward_slot,
              'host': {'system': platform.platform(), 'architecture': platform.machine(), 'cpu_count': os.cpu_count()},
              'cache_state': {'process': 'fresh then reused; second process restores nonempty workspace',
                              'filesystem': 'uncontrolled, no eviction', 'heap': 'installed prebuilt generation', 'indexes': 'not exercised'},
              'scope': 'two fixed arithmetic cases through actual installed public client; no family-wide acceptance',
              'unavailable': ['separate startup readiness', 'interpretation/admission/execution/evidence/render/commit spans',
                              'CPU/allocations/GC', 'physical durable I/O', 'Linux evidence', 'representative source/search/growth cases'],
              'runs': []}
    try:
        for index in range(2):
            if (facade/'current').resolve() != generation:
                raise RuntimeError('selected generation changed')
            measured = run(command, state, output, index, args.repeats, args.timeout)
            if args.profile_launch:
                measured['launch_partition'] = launch_partition(output/f'process-{index}.stderr', measured['samples'][0], generation.name)
            report['runs'].append(measured)
            if (facade/'current').resolve() != generation or digest(manifest) != report['manifest_sha256']:
                raise RuntimeError('generation changed during run')
            (output/'result.json').write_text(json.dumps(report, indent=2)+'\n')
        report['status'] = 'passed'
    except Exception as problem:
        report['status'] = 'failed'
        report['failure'] = str(problem)
        raise
    finally:
        (output/'result.json').write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__':
    main()
