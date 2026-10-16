#!/usr/bin/env python3
"""Summarize one observed installed invocation without mixing clock domains."""
import argparse
import hashlib
import json
from pathlib import Path


def summarize(record):
    observation = record['observation']
    rows = observation.get('phase_observations', [])
    phases = [row['jvm_or_shell_marker'] for row in rows]
    spans = []
    for phase in phases:
        if phase.get('event') == 'span':
            if phase.get('clock') != 'jvm-nano-local':
                raise ValueError('unknown span clock')
            start, end = phase['start_ns'], phase['end_ns']
            if type(start) is not int or type(end) is not int or end < start:
                raise ValueError('invalid JVM span')
            spans.append({'phase': phase['phase'], 'wall_ms': (end-start)/1e6,
                          'status': phase.get('status'),
                          'gc_count_delta': phase.get('gc_count_delta'),
                          'gc_count_supported': phase.get('gc_count_supported'),
                          'gc_time_supported': phase.get('gc_time_supported'),
                          'gc_support_scope': phase.get('gc_support_scope'),
                          'gc_time_ms_delta': phase.get('gc_time_ms_delta'),
                          'heap_used_bytes_before': phase.get('heap_used_bytes_before', phase.get('live_bytes_before')),
                          'heap_used_bytes_after': phase.get('heap_used_bytes_after', phase.get('live_bytes_after'))})

    def one(name):
        values = [phase for phase in phases if phase.get('phase') == name]
        if len(values) > 1:
            raise ValueError('duplicate fixed phase: '+name)
        return values[0] if values else None

    def instant_gap(first, last):
        a, b = one(first), one(last)
        if not a or not b:
            return None
        if a.get('clock') != 'jvm-nano-local' or b.get('clock') != 'jvm-nano-local' or b['at_ns'] < a['at_ns']:
            raise ValueError('invalid same-JVM instant gap')
        return (b['at_ns']-a['at_ns'])/1e6

    def receipt_gap(first, last):
        a = [row['observer_receipt_ns'] for row in rows if row['jvm_or_shell_marker'].get('phase') == first]
        b = [row['observer_receipt_ns'] for row in rows if row['jvm_or_shell_marker'].get('phase') == last]
        if not a or not b:
            return None
        if len(a) != 1 or len(b) != 1 or b[0] < a[0]:
            raise ValueError('invalid marker receipt order')
        return (b[0]-a[0])/1e6

    aggregate, inventory = one('verify-artifact-hash-aggregate'), one('verify-inventory')
    inventory_nonhash = None
    if aggregate and inventory:
        duration = inventory['end_ns']-inventory['start_ns']
        hashed = aggregate['elapsed_ns']
        if hashed < 0 or duration < hashed:
            raise ValueError('hash aggregate exceeds owning inventory span')
        inventory_nonhash = (duration-hashed)/1e6
    return {'format': 'veri7vn.installed-launch-summary/1',
            'generation': record['generation'], 'record_status': record['status'],
            'oracle': record.get('oracle'), 'observer_total_wall_ms': observation['wall_ms'],
            'jvm_spans': spans,
            'hash_aggregate': aggregate,
            'inventory_nonhash_wall_ms': inventory_nonhash,
            'same_jvm_instant_gaps_ms': {
                'main_to_shutdown': instant_gap('jvm-main-entry', 'jvm-shutdown-observed'),
                'main_to_dispatch': instant_gap('jvm-main-entry', 'dispatch-start'),
                'dispatch_to_shutdown': instant_gap('dispatch-start', 'jvm-shutdown-observed')},
            'observed_marker_receipt_gaps_ms': {
                'shell_entry_to_before_java': receipt_gap('shell-entry', 'shell-before-java'),
                'shell_before_java_to_main_entry': receipt_gap('shell-before-java', 'jvm-main-entry')},
            'limitations': ['JVM local spans and observer receipt gaps use distinct clocks; raw epochs never mixed',
                'nested spans and GC deltas overlap; do not sum all rows',
                'used heap includes unreclaimed objects; not true live memory',
                'receipt gaps include marker generation, pipe delivery and scheduling',
                'dispatch-to-shutdown is not proof of completed app close; native main may call System.exit',
                'hash wall includes read/SHA/format/open/close; not pure disk I/O',
                'absence of a phase is unavailable, not zero; GC availability follows producer flags']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('record', type=Path)
    args = parser.parse_args()
    record = json.loads(args.record.read_text())
    result = summarize(record)
    result['source_record_sha256'] = hashlib.sha256(args.record.read_bytes()).hexdigest()
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
