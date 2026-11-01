# Lazy catalog source integration — 27 October 2026

The production adapter source now defers Operations construction until the first
discovery or new direct invocation. `/query`, capabilities, and retained request
replays do not construct it. This applies the measured optimization from
`U6-startup-profile.md`: its scratch run deferred 8.86 seconds and 43.7 MiB of
worker private memory. The production source has now passed one bounded actual
Engine qualification in an explicitly labeled scratch overlay, described below.
Immutable V6 and its Mini acceptance journey are unchanged.

There are no new theorem statements or specialist panel numbers. This is an
untrusted adapter lifecycle change, not Mini authority or a correctness claim
about the specialists.

## API and failure decision

`operation_discovery` keeps the existing protocol and route fields. Its `counts`
is now nullable, and `state` is one of `deferred`, `ready`, or `failed`.
Capabilities reports the last confirmed state without queueing a worker call.
Counts become the actual three availability totals only after construction
completes. During construction they remain unknown, and the existing health
busy flag shows that a request owns the service gate.

Construction runs on the Engine executor's existing owning thread. No background
job or additional queue was added. A constructor exception returns HTTP 503
`catalog_initialization_failed`, with `operation_executed: false`,
`state_may_have_changed: true` and `retryable: false`. The child then exits and
the parent closes its owned process handle. Partial initialization may have
changed globals or state, so subsequent new calls do not reuse that runtime.
Capabilities retains the failed state, unknown counts, and typed error. Exact
retained results, including the failed invocation itself, still replay. A new
worker starts deferred, but replaying an old journal entry never initializes it.

Timeout/loss before the parent receives a completed catalog state is recorded as
`catalog_state_unknown_after_timeout` or
`catalog_state_unknown_after_worker_loss`. The public error remains the existing
query-timeout/worker-loss error. This avoids claiming that the catalog failed
when it might have completed before the following operation timed out. Once
the catalog is ready, ordinary invocation exceptions keep the existing behavior
and do not retroactively mark construction failed.

A separate private pipe envelope carries `{catalog, result}`. Only that
adapter-owned layer is removed. The entire result, including every upstream
reply key named `catalog`, `result`, or anything else, is retained. The existing
journal schema, route/body identity, HTTP result envelope, and public reply
byte limit are unchanged. The pipe allows an additional bounded 4 KiB for
metadata; catalog metadata is validated below 1 KiB.

## Checks and boundaries

Commands use `python3 -m unittest discover -s tests/appliance -p FILE -v`:

| File | Result | Evidence scope |
|---|---|---|
| test_lazy_catalog.py | 9 passed | Real spawned transport with deliberately fake Engine/organ |
| test_service.py | 19 passed | Existing fake-backend/process, journal and HTTP contracts |
| test_operations.py | 9 passed, 1 skipped | Direct registry and shared-conversation fixture; optional SymPy absent |
| test_component_composition.py | 11 passed, 1 skipped | Actual supplied-data components through service fixture; Pillow/NumPy visual case unavailable locally |

The nine new tests cover query-only deferred state; discovery-first and
invoke-first initialization once; executor thread ownership; whole reply and
journal preservation; legacy journal migration; retained replay after restart;
terminal constructor failure; concurrent busy rejection without a queue;
timeout and abrupt worker loss; ordinary post-initialization call failure; and
exact-boundary public replies with the extra private metadata. All test-owned
children stop during cleanup. `git diff --check` passes.

The next consumer is root's reviewed new candidate. Mini qualification of this
change remains pending. No build, package, signing, or deployment was launched
by this lane. Discovery-first agents and direct
`core.query` still pay catalog initialization. Tenant eviction/restart behavior
is unchanged and does not gain seamless conversation persistence.

Changed files and frozen hashes:

- `tools/appliance/serve.py`:
  `1152526eed823e0c2740961115605f5df63a45b865e8303eb2dc4dca3d98da5f`
- `tools/appliance/README.md`:
  `62244bf82e3f9d0752c5099af4f8be807e5496adf6b57f93192517559ea29b23`
- `tests/appliance/test_lazy_catalog.py`:
  `6ae7e97fb593f4342e087f33884da400188b0e53a1b980ccefa3d639afb060a9`
- This report.

## Actual production-source Engine qualification

One leased run on dregg-build used the immutable U6-v2 runtime and data with a
new read-only scratch adapter. Only the reviewed `serve.py` and README changed;
`QUALIFICATION.json` records every adapter file hash and explicitly identifies
uninstrumented production source in a non-deployed overlay. No phase markers or
runtime monkeypatches were used. The host load was about 10 on eight CPUs, so
this remains a bounded observation rather than a controlled performance claim.

- Readiness: **10.817 seconds**; first real query: **0.518 seconds**.
- After the query, capabilities remained `deferred`, with `counts: null`.
- First real discovery: **8.383 seconds**; capabilities then reported `ready`,
  with **351 live direct, 1 text-only, 9 unavailable** entries.
- Real `specialist.meteorology-v2.f2c(temperature_f=32)` returned 0 degrees C.
- All nine behavioral checks passed, including every exact retry and a fresh
  arithmetic request after initialization. Complete replies again matched all
  earlier runs' SHA256
  `7792dcb88aa55a86385d918df648f2e6c6da7be4fd2535ab66b1c56e480b62e8`.
- Process-tree PSS: 425,201 KiB ready; 431,065 KiB after query; 479,587 KiB after
  discovery/direct/fresh-query. Accessible runtime size/mtime inventory and
  base receipt identity remained unchanged; mounts were read-only.

The initial qualification runner **misidentified the bwrap wrapper as the
adapter** because the wrapper argv also contained the script path. Its claim
`owned_adapter_stopped: true` only established wrapper exit (-15), not child
cleanup. That original receipt remains intact. A separate cleanup correction
validated the recorded actual adapter 2752027/start ticks 5186157, resource
tracker 2752058/5186188, and Engine 2752061/5186190 against their exact argv and
original process group 2752025. It then signaled only the adapter after another
identity check. All three original Python processes exited. This was a harness
selection defect, not an Engine behavior failure; no additional Engine run was
performed to repair the tooling.

Linux evidence:
`/build/lanes/oracle-startup-profile/phase-d-production-source/` contains the
original receipt, full replies/log, and `cleanup-correction.json`.
Local copies: `var/startup-profile/phase-d-*`.
Original receipt SHA256:
`dd490a7315a4a9fdad2bbaa8811f0ab14037d762c66784bc8a7d417fe79794de`.
Cleanup correction SHA256:
`3d39cb328895514abb6c6b7f9a5c3d14ebea8f4f736ae9b1a207938fe3526ab7`.
The production-source qualification mode is in
`tools/usage/startup-profile/run.py`; it checks lifecycle/counts without
mislabeling the overlay as a signed candidate or an instrumented prototype.

The corrected runner uses a shared `is_adapter_identity` helper from
`tools/usage/tenancy/linux_memory.py`, selecting the Python script position and
rejecting bwrap and Python `-c`/`-m` children. The regression in
`test_linux_memory.py` passes; all **7 utility tests pass**. The runner now
records descendant start times/argv, verifies the original tree stopped, and
requires wrapper exit 0. The original phase-D receipt would fail these stronger
checks, as intended; the separate cleanup correction establishes its eventual
cleanup. No Engine was restarted solely to retest harness cleanup tooling.
