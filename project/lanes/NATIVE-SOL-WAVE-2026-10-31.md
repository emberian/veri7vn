# Native performance and consumers — Sol wave, 31 October 2026

Ember authorized Sol follow-up to the Astra foundation, with architecture,
specialist consumers and measurement progressing together. Baseline foundation
is `f0dfad7`; its pre-foundation comparison is `01b0fbd`. The
[research synthesis](../scouts/native-2026-10-31/README.md) supplies source findings
and literature. Mini work is outside scope.

## Ownership and execution

Root integrates, reviews interfaces, owns workspace manifests and commits/pushes.
Implementation workers own named paths, may design and implement within them,
and author focused tests/consumer cases. No worktrees, upstream writes, builds,
test execution, commits or deputy spawning by implementation workers. Coordinate
shared interfaces before editing a consumer owned by another lane. Scratch belongs
under `var/sol-wave-20261031/`; papers and credentials remain outside commits.

The performance lane is the sole authorized build/measurement runner initially.
It compares immutable source snapshots, not a changing worktree. Use warm artifacts,
bounded jobs and existing build hosts; serialize expensive work. Root grants the
later integrated validation window. No unfiltered suites or invented speed claims.

## Work packages

- Measurement: release host comparisons, typed/wire costs, whole-process memory,
  concurrent tenant latency and cancellation. Explain regressions and confounders.
- Reader representation: share result/evidence ownership while preserving every
  interpretation's form checks, source evidence and external compatibility.
- Memory accounting: explicit shared reservations for retained request data, with
  concrete reader consumers and no claim to bound untracked foreign allocations.
- Host scheduling: bounded reusable invocation workers with supervisor-owned
  shutdown, live-work permits, explicit no-queue/backpressure behavior and replay.
- Calibration: usable supplied-data numerical/exact calibration consumer, stated
  assumptions, existing extracted assurance where actually admitted, independent cases.
- Thermal scenarios: reuse admitted network structure/factorization for bounded
  load scenarios and sensitivities; check original-node power balances.
- Sequence collections: immutable supplied sequences, batched exact fragment
  search, both-strand original coordinates, bounded paging and honest completeness.
- Exact feasibility: rational certificates closing the positive-balance search
  gap, then a bounded supplied-blend consumer; resource exhaustion is not infeasibility.
- Reader data: inspect and repair plural/alias training/export in owned tools;
  prepare code-only/data-only/combined frozen comparisons without editing upstream.
- Integration: consistent typed host calls, discovery, Python interfaces, runnable
  consumers and concise catalogs across new operations.

New consumer panels and independent truth cases accompany each capability.
Shipped panels remain comparison controls; passing a library fixture does not
establish a completed specialist. No new Isabelle claim without actual theory and
admitted extraction. Final independent Astra review follows integration.

## Status

First-wave source checkpoint: the four typed operations now answer through the
actual HTTP host under default memory limits and through the all-provider PyO3
extension. Focused core, host and domain checks pass. Independent Astra source
reviews have no remaining blockers after repairs. This is not final qualification:
new workflow panels, the four-cell reader experiment and final-wave performance
comparison remain in progress under the central validation lane.

Real HTTP use exposed excessive thermal scratch reservation, now computed from
actual matrix dimensions. It also exposed invalid tenant/envelope defaults in the
example clients; the surface lane is repairing their shared transport helper.
Neither failed transport attempts nor library fixtures count as panel results.

The completed pre-foundation/foundation performance comparison is in
`native/docs/PERFORMANCE.md`. All 28 HTTP semantic pairs agree; typed science
allocation counts fell, while HTTP timings were masked by listener polling and
startup slowed. The first-wave readiness correction needs its own final measured
comparison. Whole-process memory is reported separately from Rust allocations.

`sol_wave_validation` owns execution and an immutable source snapshot plus hashed
corrective overlays. After panels and reader learning, `sol_measurement` will
compare retained final binaries and prepared-consumer reuse. Wider new modules
are tracked separately in `NATIVE-SOL-EXPANSION-2026-10-31.md`.

Reader data sources and fixed cohort provenance are documented in
`tools/reader_audit/README.md`. New operation truth cases live under
`tools/usage/specialist/{calibration,thermal-scenarios,sequence-collection,exact-blend}`.
The three extracted calibration comparisons passed, distinguishing rational
internal least-squares assurance from four-decimal display and untrusted recognition.
