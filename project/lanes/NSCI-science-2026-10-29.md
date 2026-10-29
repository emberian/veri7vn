# NSCI — supplied scientific linear models, 2026-10-29

Owner: Codex scientific-provider lane. Owned paths: `native/oracle-science/**`
and this report. No root workspace, lockfile, binding, upstream or family files
were edited. No agents, commits, or builds were started by this lane.

## Specialist-panel numbers

None yet. This is an experimental supplied-matrix provider, not a completed
specialist, a Mini-live operation or a formally verified replacement. No change
to the shipped panel scoreboard is claimed.

## What was added

- `native/oracle-science/Cargo.toml`: optional `oracle-science` package with
  pinned faer `=0.24.4`, default features off, `std,linalg`; shared serde,
  serde_json (with `raw_value`) and thiserror. faer is MIT licensed. Official SVD API, feature
  flags, explicit serial execution and scratch API were read on 2026-10-29.
- `src/lib.rs`: typed supplied matrices, model/unit/normalization declarations,
  relative rank and residual policies, structured JSON dispatch, operation
  catalog, serial thin SVD, recomputed original-row residuals, rank/nullity,
  condition diagnostics, fit stationarity diagnostics and cooperative
  cancellation. Fixed dimension/work/scratch/JSON limits may only be lowered.
- `src/main.rs`: bounded one-request JSON CLI, catalog mode and structured
  errors. Numeric inconsistency remains a result with the fit candidate.
- `tests/contracts.rs`: 17 authored numerical and policy tests; two additional
  numerical unit tests in the library cover compensated cancellation and
  stable norms.
- `README.md`, `examples/heat-balance.json`, `examples/spring-fit.json`: concrete
  consumers, result semantics, analytical expected values and the service and
  assurance boundary.

## Operations and claims

`science.solve_linear` distinguishes numerically consistent unique and
underdetermined systems from candidates failing the declared residual policy.
`science.least_squares` returns an explicitly named truncated-SVD fit and
separately reports consistency and coefficient identifiability. Nonzero
singular directions below the rank cutoff are deliberately dropped, so a
refused solve is not an exact inconsistency certificate. Minimum norm depends
on the caller's supplied variable coordinates.

Diagnostics include the spectrum of globally scaled A, cutoff, numerical rank,
nullity, retained/full-column condition numbers, original-row residuals,
componentwise backward error, scaled residual norm, and the scaled
normal-equation gradient. Unit labels and physical assumptions are retained
caller assertions. Residuals assess the supplied equations, not the truth or
completeness of a physical model. No statistical confidence claims are made.

No theorem statements were added. All computation here is untrusted numerical
code. No `sorry`, `oops`, `skip_proof` or new axiom was introduced.

## Consumers and integration requirements

Inspected actual family contracts: `src/extract/energy/Calorimetry.thy`,
`Thermo.thy`, `src/extract/mechanics/Mechanics.thy`,
`src/extract/chemistry/Chemistry.thy`, and
`src/extract/geostats/GeoStats_Stats.thy`, plus shipped energy-v3,
physics-r3 and chemistry-v3 recognizers. Existing kernels have formula and
descriptive-statistics operations. Coupled thermal balances, linear equilibrium,
linear concentration estimates and finite-design parameter fits are useful
extensions once a consumer constructs and validates the matrix.

Root must add this package to the workspace and lockfile, then build/test on
hbox under its two-job resource policy. Python/provider catalog exposure is a
root integration choice; it must preserve model declarations and every outcome.
No automatic natural-language parser or replacement of exact family arithmetic
is included. A family adapter must handle units, sign conventions, independent
constraints, physical inequalities and refusal/rendering behavior, and run the
specialist's own panel and independent physical examples.

The implementation caps 512 rows, 128 columns, work estimate 8,388,608, 1 MiB
JSON, and 32 MiB SVD scratch. SVD explicitly uses `Par::Seq`, even if another
dependency later enables Rayon. It creates no worker pool. Cancellation is
checked around the noninterruptible SVD, so a hard deadline still needs the
host's owned process containment and admission. These limits have not been
qualified as multitenant latency or fairness guarantees.

## Checks and remaining questions

`rustfmt --edition 2021` succeeded on both Rust sources and integration tests;
both example JSON files parsed. Root's first hbox contract run reported 16
passing and one failing test: structured decoding encountered Serde's buffered
number representation with the workspace `arbitrary_precision` setting. The
fix retains raw argument bytes through dispatch and decodes the selected typed
input directly. The workspace exact-number setting remains intact. Root's
central rerun is pending; no local build was run. Planned focused check:
`cargo test -p oracle-science` (17 integration tests plus two unit tests),
followed by the two supplied CLI examples and a structured
oversized/malformed-input error. Independent analytical values:
thermal offsets `[10,10]` K and spring fit `[5/6,3/2]` with residuals
`[-1/6,1/3,-1/6]` N.

Validation must answer whether the selected tolerances and caps are useful
for the first consumer, what the faer dependency adds to build/artifact/RSS
cost, and how cancellation behaves under the host's shared admission. A later
consumer may need scaled variables or weighted rows, but those transformations
must be explicit because they change rank, minimum norm or the fit objective.

## Root integration receipt

The RawValue repair passed all 17 contracts and two numerical unit tests on hbox. Heat-balance and spring-fit examples also passed through the combined PyO3 extension. No specialist-panel or hosted deployment claim.

See [central validation](../../native/evidence/2026-10-29-validation.json).
