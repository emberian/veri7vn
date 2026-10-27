#!/usr/bin/env python3
"""Untrusted analytical model, not an Oracle worker or production scheduler.

Models sequential fresh-conversation requests and exact durable retries. No
Engine, process, socket, corpus or tenant workspace is opened. The two measured
latencies are calibration inputs from the installed v5 receipt, not a forecast
or qualification of the newer hosted build. TTL, concurrency, request failures,
variable service times and shutdown cost are deliberately excluded.
"""
from collections import OrderedDict
import argparse
import json


def run(trace, cap, startup_seconds, query_seconds):
    residents = OrderedDict()
    seen = set()
    cold = warm = evictions = returns = peak = replays = 0
    for tenant, retained in trace:
        if retained:
            replays += 1
            continue  # pool's journal-first fast path does not acquire a worker
        if tenant in residents:
            warm += 1
            residents.move_to_end(tenant)
        else:
            cold += 1
            returns += tenant in seen
            if len(residents) == cap:
                residents.popitem(last=False)
                evictions += 1
            residents[tenant] = None
            seen.add(tenant)
        peak = max(peak, len(residents))
        assert len(residents) <= cap
    requests = len(trace)
    assert cold + warm + replays == requests
    return dict(requests=requests, cold_starts=cold, warm_calls=warm,
                durable_replays=replays, evictions=evictions,
                returns_to_evicted_tenant=returns, peak_residents=peak,
                estimated_sequential_engine_seconds=round(
                    cold * startup_seconds + (cold + warm) * query_seconds, 6))


def scenarios(tenants, turns):
    names = range(tenants)
    interleaved = [(name, False) for _ in range(turns) for name in names]
    burst = [(name, False) for name in names for _ in range(turns)]
    return dict(interleaved_fresh_conversations=interleaved,
                grouped_fresh_conversations=burst,
                exact_completed_retries=[(name, True) for name, _ in interleaved])


def check_model():
    cases = scenarios(32, 4)
    for cap in (1, 2):
        interleaved = run(cases['interleaved_fresh_conversations'], cap, 12.424, .351)
        grouped = run(cases['grouped_fresh_conversations'], cap, 12.424, .351)
        retries = run(cases['exact_completed_retries'], cap, 12.424, .351)
        assert interleaved['cold_starts'] == 128 and interleaved['warm_calls'] == 0
        assert interleaved['returns_to_evicted_tenant'] == 96
        assert grouped['cold_starts'] == 32 and grouped['warm_calls'] == 96
        assert retries['cold_starts'] == 0 and retries['peak_residents'] == 0
        assert retries['durable_replays'] == 128
    assert run(cases['interleaved_fresh_conversations'], 32, 1, 1)['cold_starts'] == 32
    assert run([(0, False), (0, False)], 1, 1, 1)['warm_calls'] == 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tenants', type=int, default=32)
    parser.add_argument('--turns', type=int, default=4)
    parser.add_argument('--caps', type=int, nargs='+', default=[1, 2])
    parser.add_argument('--startup-seconds', type=float, default=12.424)
    parser.add_argument('--query-seconds', type=float, default=.351)
    args = parser.parse_args()
    if not (1 <= args.tenants <= 128 and 1 <= args.turns <= 1000
            and all(1 <= cap <= 64 for cap in args.caps)
            and 0 <= args.startup_seconds <= 3600 and 0 <= args.query_seconds <= 3600):
        parser.error('inputs exceed bounded model limits')
    check_model()
    print(json.dumps(dict(
        kind='analytical_model_not_live_measurement', model_checks='passed',
        assumptions='Sequential fresh conversations; no idle TTL, concurrency, failures or shutdown cost. Exact completed retries already exist in a durable journal.',
        parameters=vars(args),
        results={name: {str(cap): run(trace, cap, args.startup_seconds, args.query_seconds)
                       for cap in args.caps}
                 for name, trace in scenarios(args.tenants, args.turns).items()}), indent=2))


if __name__ == '__main__':
    main()
