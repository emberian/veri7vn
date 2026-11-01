# NBIOSTAT host integration — 29 October 2026

Owner: Sol host integration lane. Consumer: the optional `oracle_native`
extension and standalone private-loopback operation service. No Mini consumer
or specialist routing change is claimed. Specialist panel numbers: none yet.
No new theorem statements, Isabelle proof, axiom or verification claim.

## What changed

- `native/Cargo.toml`: workspace members only; added the two domain crates.
- `native/oracle-python/Cargo.toml`: optional `bio` and `statistics` features
  and dependencies. Default extension features remain unchanged.
- `native/oracle-python/src/providers.rs`: conditional `bio_call`,
  `bio_catalog`, `statistics_call`, `statistics_catalog` exports. Calls release
  the GIL, use fixed native default limits and map native errors to ValueError.
- `tools/appliance/native_worker.py`: two fixed host-selected profiles.
- `tools/appliance/native_service.py`: bind each profile to its domain adapter;
  preserve `computation_only` on native refusal replies.
- `tools/oracle_components/native_bio.py`: bounded structural declaration for
  `bio.align_pairwise`, fixed JSON dispatch and conservative result checks.
- `tools/oracle_components/native_statistics.py`: declaration for the actual
  ID `statistics.linear_regression`; retain fit diagnostics, conditional
  inference and explicit inference-unavailable reasons separately.
- `tools/oracle_components/test_native_bio.py`,
  `tools/oracle_components/test_native_statistics.py`: manufactured-catalog
  dispatch, schema and malformed-output tests, explicitly not native evidence.
- `tests/appliance/test_native_domain_service.py`: service dispatch/refusal
  contracts and opt-in real extension CLI journey across restart, discovery,
  analytic results, negative native admission and same-request recomputation;
  actual snapshot and same-worker reuse checks across both domains.
- `native/tests/test_python_domains.py`: real optional exports, alignment
  modes/ambiguity/scoring checks and negative admission; analytic regression
  mean/standard error/Student-t critical value, retained fit without inference,
  invalid weights/shapes/options. Explicit default-build absence mode.
- `native/docs/BIO-STATISTICS.md`: callable examples, operator setup, limits,
  ambiguity/coordinate/scoring rules, statistical assumptions, unavailable
  capabilities, inference and hosting constraints.

No changes to the frozen domain algorithms, Cargo.lock, admitted-runtime
registry, reader/runtime/query work, existing chemistry service tests or
shared README/tracker/MIGRATION. The existing single NativePool already groups
artifacts by hash and serves all profiles for that artifact in the same
worker; this lane adds no pool, tenant worker or scheduler.

## Interfaces and behavior

`bio.align_pairwise` uses `{operation, arguments}`. `statistics.linear_regression`
uses the same envelope. The service's outer request remains exactly
`{request_id, conversation_id, operation_id, arguments}`. No argument can pick
extension code, profile or authority. A missing compiled profile fails service
startup. Unsupported operations are absent from discovery and return 404.

Bio request scoring and dimensions are validated by native admission before
alignment allocation; structural scalar bounds also appear in discovery.
An admitted alignment reply must carry matching candidate/replayed/optimal
scores and valid coordinates. This does not establish biological significance.

Statistics returns answered computations for a conditional-inference fit, a
fit without inference, or a rank-deficient candidate, each classified distinctly.
The native result retains `inference=null` and its reasons when inference is
withheld. A numerical fit never acquires a causal or unconditional uncertainty
claim. A native input refusal instead follows the shared HTTP withheld protocol.

## Checks and remaining work

The central validator resolved Cargo.lock, built and tested on hbox with two
Cargo jobs, and recorded the final results in the
[validation receipt](../../native/evidence/2026-10-29-language-chemistry-domains-validation.json).
No builds, tests, dependency downloads or commits were run by this host lane.

| Focused check | Final result |
| --- | --- |
| Native bio alignment contracts | 10 passed |
| Native statistics regression contracts | 14 passed |
| Combined all-target Clippy with `-D warnings` | Passed for core, reasoning, bio, statistics and Python with all five optional features |
| Actual combined-extension PyO3 domain suite | 6 passed |
| Manufactured bio adapter contracts | 4 passed |
| Manufactured statistics adapter contracts | 4 passed |
| New domain service suite with actual extension | 5 passed, 0 skipped |
| Existing standalone service suite with actual extension | 10 passed |
| Default-extension optional-export absence check | 1 passed; 5 domain calculations intentionally skipped |

The combined extension enabled `reasoning,science,incremental,bio,statistics`.
The actual-domain and standalone checks used the immutable release artifact
whose SHA-256 is
`8c838fe3f2764446f26b5a65c622fd79072f73e710756e2e597df1c1b0d36538`.
The default-extension check confirmed that all four bio/statistics exports
were absent. The receipt links the source manifest and log hashes.

The new service checks exercised real CLI discovery, invocation and restart;
analytic alignment and regression answers; invalid-input refusal followed by
valid-call recovery; and one immutable snapshot with the same worker PID
reused across successful calls to both profiles. The first HTTP run passed
4/5 because its fixture incorrectly expected a worker to remain resident
after native refusal. The corrected test passed in the final 5/5 run and now
checks retirement and recovery explicitly. Production behavior did not change.

These are bounded executable contracts, not specialist panel scores or
Isabelle proofs. No new panel numbers or theorem statements are available.
Expected native input refusals still retire a healthy worker under the shared
pool protocol; a future typed expected-failure protocol could avoid that
restart cost while preserving retirement for faults and timeouts. This lane
does not change that protocol. Biological significance, external genome lookup,
causal inference and verification of statistical assumptions remain outside
these providers' scope.
