# Lazy catalog source integration — 27 October 2026

The production adapter source now defers Operations construction until the first
discovery or new direct invocation. `/query`, capabilities, and retained request
replays do not construct it. This applies the measured optimization from
`U6-startup-profile.md`: its scratch run deferred 8.86 seconds and 43.7 MiB of
worker private memory. Those remain prototype measurements; this new production
source has not yet been run with the actual Engine or packaged into a candidate.
Immutable V6 and the in-flight Mini acceptance journey are unchanged.

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

The next consumer is root's reviewed new candidate. Actual Engine and Mini
qualification are pending; no new Engine, build, package, signing, or deployment
was launched in this source-integration step. Discovery-first agents and direct
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
