"""Linux process memory observations; PSS attributes shared resident pages once.

This is a measurement utility, not tenant authentication or admission evidence.
"""
from __future__ import annotations
import os
from pathlib import Path
import re


def read_rollup(pid: int, proc: Path = Path('/proc')) -> dict:
    text = (proc / str(pid) / 'smaps_rollup').read_text()
    wanted = {'Rss', 'Pss', 'Pss_Anon', 'Pss_File', 'Pss_Shmem', 'Shared_Clean',
              'Shared_Dirty', 'Private_Clean', 'Private_Dirty', 'Swap', 'SwapPss'}
    result = {}
    for line in text.splitlines():
        key, sep, tail = line.partition(':')
        if sep and key in wanted:
            parts = tail.split()
            if len(parts) != 2 or parts[1] != 'kB':
                raise ValueError(f'invalid smaps field {key}')
            result[key + '_kib'] = int(parts[0])
    if not {'Rss_kib', 'Pss_kib', 'Private_Clean_kib', 'Private_Dirty_kib',
            'Shared_Clean_kib', 'Shared_Dirty_kib'} <= result.keys():
        raise ValueError('incomplete smaps rollup')
    result['private_kib'] = result['Private_Clean_kib'] + result['Private_Dirty_kib']
    result['shared_kib'] = result['Shared_Clean_kib'] + result['Shared_Dirty_kib']
    return result


def descendants(pid: int, proc: Path = Path('/proc')) -> list[int]:
    """Inspect recorded process descendants; tolerate children exiting during sampling."""
    seen, pending = set(), [pid]
    while pending:
        current = pending.pop()
        if current in seen:
            continue
        seen.add(current)
        task = proc / str(current) / 'task'
        try:
            threads = list(task.iterdir())
        except (FileNotFoundError, ProcessLookupError):
            continue
        for thread in threads:
            try:
                pending.extend(int(v) for v in (thread / 'children').read_text().split())
            except (FileNotFoundError, ProcessLookupError):
                continue
    return sorted(seen)


def sample(pids: list[int], proc: Path = Path('/proc')) -> dict:
    rows, vanished = {}, []
    for pid in sorted(set(pids)):
        try:
            rows[str(pid)] = read_rollup(pid, proc)
        except (FileNotFoundError, ProcessLookupError):
            vanished.append(pid)
    keys = ('Rss_kib', 'Pss_kib', 'private_kib', 'shared_kib', 'Swap_kib')
    return {'processes': rows, 'vanished': vanished,
            'totals_kib': {key: sum(row.get(key, 0) for row in rows.values()) for key in keys}}


def cgroup(pid: int, proc: Path = Path('/proc'), mount: Path = Path('/sys/fs/cgroup')) -> dict | None:
    """Read cgroup-v2 current/peak and stat when the process has a visible cgroup."""
    try:
        rows = (proc / str(pid) / 'cgroup').read_text().splitlines()
        relative = next(line[3:] for line in rows if line.startswith('0::'))
        root = mount.resolve()
        directory = (root / relative.lstrip('/')).resolve()
        if directory != root and root not in directory.parents:
            return None
        result = {'path': relative}
        for name in ('memory.current', 'memory.peak', 'memory.max'):
            try:
                value = (directory / name).read_text().strip()
                result[name] = int(value) if value.isdigit() else value
            except (FileNotFoundError, ProcessLookupError):
                pass
        try:
            stats = {}
            for row in (directory / 'memory.stat').read_text().splitlines():
                key, value = row.split()
                if key in ('anon', 'file', 'shmem', 'slab', 'kernel'):
                    stats[key] = int(value)
            result['memory.stat'] = stats
        except (FileNotFoundError, ProcessLookupError):
            pass
        return result
    except (FileNotFoundError, ProcessLookupError, StopIteration):
        return None


def process_identity(pid: int, proc: Path = Path('/proc')) -> tuple[int, bytes]:
    """Bind a PID to kernel start ticks and argv; parsing survives spaces in comm."""
    raw = (proc / str(pid) / 'stat').read_bytes()
    end = raw.rfind(b')')
    if end < 0:
        raise ValueError('invalid process stat')
    fields = raw[end + 1:].split()
    if len(fields) < 20:
        raise ValueError('short process stat')
    ticks = int(fields[19])  # field 22; fields starts at field 3
    argv = (proc / str(pid) / 'cmdline').read_bytes()
    return ticks, argv


def is_adapter_identity(identity: tuple[int, bytes], script: str = '/opt/oracle/adapter/serve.py') -> bool:
    """Select Python's script argument, not a wrapper or -c/-m child payload.

    Selection is only for recorded descendants; signal_if_same must still bind
    a later signal to this exact start time and argv.
    """
    argv = identity[1].split(b'\0')
    if not argv or re.fullmatch(rb'python(?:[0-9]+(?:\.[0-9]+)*)?', argv[0].rsplit(b'/', 1)[-1]) is None:
        return False
    index = 1
    while index < len(argv) and argv[index] in (b'-B', b'-u', b'-E', b'-I', b'-s', b'-S', b'-O', b'-OO'):
        index += 1
    return index < len(argv) and argv[index] == os.fsencode(script)


def is_engine_worker_identity(identity: tuple[int, bytes]) -> bool:
    """Recognize Python multiprocessing spawn, accounting for interpreter flags."""
    argv = identity[1].split(b'\0')
    if not argv or re.fullmatch(rb'python(?:[0-9]+(?:\.[0-9]+)*)?', argv[0].rsplit(b'/', 1)[-1]) is None:
        return False
    index = 1
    while index < len(argv) and argv[index] in (b'-B', b'-u', b'-E', b'-I', b'-s', b'-S', b'-O', b'-OO'):
        index += 1
    return index + 1 < len(argv) and argv[index] == b'-c' and b'from multiprocessing.spawn import spawn_main' in argv[index + 1]


def signal_if_same(pid: int, identity: tuple[int, bytes], sig: int, *,
                   proc: Path = Path('/proc'), killer=os.kill) -> bool:
    try:
        if process_identity(pid, proc) != identity:
            return False
        killer(pid, sig)
        return True
    except (FileNotFoundError, ProcessLookupError):
        return False


def identity_still_running(pid: int, identity: tuple[int, bytes], proc: Path = Path('/proc')) -> bool:
    """A matching zombie has exited; reuse or disappearance is not our process."""
    try:
        stat = (proc / str(pid) / 'stat').read_bytes()
        end = stat.rfind(b')')
        if end < 0: raise ValueError('invalid process stat')
        fields = stat[end + 1:].split()
        if len(fields) < 20: raise ValueError('short process stat')
        return int(fields[19]) == identity[0] and fields[0] != b'Z'
    except (FileNotFoundError, ProcessLookupError):
        return False
