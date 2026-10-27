# U6 startup profile — 27 October 2026

These measurements support deferring direct-operation catalog construction for
query-only tenants. A scratch prototype reached readiness in 10.84 seconds and
answered the real arithmetic query before loading the catalog. The first
discovery later paid 8.87 seconds. This moves an independent cost off the query
path; it does not remove the cost for agents that discover operations first.

This profile did not change a shipping adapter or immutable candidate. A later
production-source implementation and its actual Engine qualification are now
recorded in `U6-lazy-catalog.md`; candidate packaging and hosted qualification
are separate. There are no specialist
panel numbers or new theorem statements in this lane. The consumer is the next
bounded appliance integration batch, not the deployed V6 package.

## Measurements

All three runs used Linux Python 3.12, one leased Engine, read-only runtime and
shared-data mounts, an owned scratch workspace, and the same U6-v2 candidate.
Host caches were left alone. The host had eight CPUs and other work running;
these are sequential observations, not a controlled latency benchmark.

| Measurement | A: coarse eager | B: detailed eager | C: detailed lazy |
|---|---:|---:|---:|
| Readiness wall time | 28.789 s | 22.481 s | 10.843 s |
| Engine construction wall / CPU | 12.549 / 9.359 s | 12.512 / 9.245 s | 10.164 / 8.960 s |
| Catalog construction wall / CPU | 15.873 / 4.398 s | 8.763 / 4.694 s | 8.860 / 3.938 s, after first query |
| Process-tree PSS at readiness | 471,260 KiB | 471,754 KiB | 425,186 KiB |
| Process-tree private memory at readiness | 459,312 KiB | 459,784 KiB | 413,220 KiB |
| Full startup compile-call elapsed time | 2.863 s | 2.772 s | 1.165 s before catalog; 2.445 s including later catalog |

The lazy worker immediately before/after catalog initialization consumed
394,176 / 438,896 KiB private memory: **44,720 KiB (43.7 MiB)** added by the
catalog, with 3.773 user CPU seconds and 0.165 system CPU seconds. Its PSS moved
from 399,020 to 443,740 KiB. Across the actual before/after query snapshots the
process tree moved from 431,048 to 478,810 KiB PSS; that includes direct-call and
subsequent-query effects as well as catalog construction. Lazy loading saves
roughly 45 MiB per query-only worker here, not hundreds of MiB.

The detailed eager run identified `_specialists` as 8.465 seconds wall / 4.455
thread CPU, including `_registered` at 1.634 / 1.592 seconds. Metadata JSON reads
took 1.198 seconds over 652 calls; provider extensions took only 0.227 seconds.
The stages overlap. Registration reparses source from the actual runtime MRO;
specialist construction then imports each registered implementation, reads
manifests and example panels, and prepares the callable catalog. These are real
load checks; replacing them with a static list would change availability claims.

The compile counter disproves the initial guess that source compilation alone
explains the long startup. Its 2.86 seconds in A is about 10% of that run's wall
time. No pyc experiment or post-construction fork was performed.

Host effects are visible. A's load moved 7.96 to 8.27 and I/O pressure `some`
avg10 moved 2.19% to 14.21%. B's load moved 9.07 to 10.29, CPU pressure avg10
4.82% to 32.99%. C's load moved 6.75 to 7.03, CPU pressure 0.41% to 1.25%, and
I/O pressure 15.62% to 18.31%. CPU ticks, cgroup CPU totals and pressure, faults
and per-process I/O are retained in the receipts. Consequently the 11.64-second
B-to-C readiness difference must not all be attributed to the code change.
The independent 8.86-second deferred stage in C is the stronger evidence.

## Behavior and cleanup

All three real Engine queries answered `6 × 7 = 42`. Their complete 277-byte
responses, including provenance and latency, were identical, SHA256
`7792dcb88aa55a86385d918df648f2e6c6da7be4fd2535ab66b1c56e480b62e8`.
Every exact retry matched. C additionally passed all of:

- Capabilities showed `counts: null` with explicit deferred initialization.
- Discovery initialized and returned actual live `core.query`.
- Direct `specialist.meteorology-v2.f2c` with `temperature_f: 32` returned
  `result: 0`, `unit: degC`, and its exact retry matched.
- A fresh arithmetic request after catalog construction produced the identical
  complete response; its exact retry also matched.

C has seven recorded passing checks. Three narrow instrumentation tests pass:
unchanged ordinary query/worker AST, refusal to overwrite an output directory,
and explicit lazy metadata with unchanged EngineProcess query implementation.
These are transport/instrumentation checks, not a comprehensive semantic suite.

All three owned adapter PIDs (2637816, 2660170, 2686456) stopped, wrapper exit 0,
and their workers exited through the normal shutdown. Runtime size/mtime
inventory and receipt identity stayed unchanged. Read-only mounts prevented
runtime/data writes. The profile did not rehash the full corpus.

## Evidence and handoff

Linux base runtime: `/build/lanes/oracle-tenancy-measure/u6-v2-runtime`.
APPLIANCE receipt SHA256:
`65d0391ee109d7f2873391d7f71cb0991d806b922f73c932764169e3cab90dd8`.
Source adapter SHA256:
`0719e0af97fd29474d518bab7cfe84af49798b46ba2fbae46b66fe40fe740ca9`.
Scratch lazy adapter SHA256:
`52f97af5ba75dd64558e01b07b5eb0f2f3c6dd9d0851c00cf6ff6c5433a01352`.

Full Linux receipts/logs/replies are under
`/build/lanes/oracle-startup-profile/{phase-a,phase-b-detailed,phase-c-lazy}/`.
Local retained receipts and responses are under `var/startup-profile/`:

| Local receipt | SHA256 |
|---|---|
| phase-a-receipt.json | 28e33e45be63e7553142c0a525541af01a2929aac4b4a66c27ec6d336a83b6e4 |
| phase-b-receipt.json | 7137a0f6c8fa44d50691aa237530c7ddaa1fdd07b5068304b1cfb8f85990999c |
| phase-c-receipt.json | 3918b8ed015eb80e1279f06066d0cc44d4cdc1339a663af2b964ee9d547040ec |

Changed tracked-source candidates: `tools/usage/startup-profile/instrument.py`,
`run.py`, `test_instrument.py`, `README.md`, and this report. After the successful
run, the runner was tightened to exit nonzero if recorded checks, shutdown or
immutability fail; the already-retained run had all of those passing. No further
Engine was launched for that reporting-only exit check.

The subsequent production-source implementation initializes Operations once on
its existing owner thread and makes deferred/ready/failed catalog states
explicit in capabilities. Its report records the journal, concurrency, failure,
count-update and replay tests, and the later actual Engine qualification.
The prototype itself deliberately keeps counts unknown even after initialization,
so its capabilities shape is not the production implementation. In particular,
`core.query` sent through direct invocation still pays catalog initialization;
agents using discovery first see no query-only latency benefit. Avoid presenting
this as a solution to all tenant churn or seamless conversation persistence.
