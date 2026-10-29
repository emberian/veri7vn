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

Root added this package to the workspace/lockfile and optional Python exposure
in checkpoint `b648130`; its hbox check passed all 19 initial science tests and
the combined PyO3 heat/spring examples. Further Python/provider integration
must preserve model declarations and every outcome.
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

## Domain consumer: steady thermal networks

The second increment adds `science.thermal_network` through the same optional
JSON catalog/dispatch and a typed `thermal::thermal_network` API. The consumer
constructs the matrix itself from named nodes, signed applied heat in W,
strictly positive passive conductances in W/K, and optional fixed absolute
boundary temperatures in K. It solves free-node temperature intervals around
a declared reference. The reference is a coordinate choice, never an extra
boundary condition. Existing matrix/fit operations retain their interfaces.

Changed files in this increment:

- `native/oracle-science/src/thermal.rs`: typed network input and result,
  validation, connected components, free-node Laplacian construction, expected
  rank from topology, existing serial SVD candidate generation, original-node
  power evidence and explicit outcomes.
- `native/oracle-science/src/lib.rs`: new operation dispatch and catalog entry.
- `native/oracle-science/tests/thermal.rs`: 17 authored domain cases.
- `native/oracle-science/examples/thermal-network.json`: two coupled heated
  nodes and an ideal reservoir, with known temperatures and heat flows.
- `native/oracle-science/THERMAL.md`, `README.md`: model, actual example,
  temperature/heat sign conventions, outcome meanings and integration limits.
- This lane report. No dependency or root-owned file changed in this increment.

The equations are `q_ij = G_ij*(T_i-T_j)` and, at each free node,
`sum_j q_ij = applied_heat_w`. Fixed nodes are ideal reservoirs whose additional
exchange is computed as `outgoing_link_heat_w - applied_heat_w`. Their exchange
is not an independently measured quantity or a finite heater-capacity check.
There are no transient storage, radiation, advection or active heat-pump
equations. The caller must justify any fixed-conductance approximation and
completeness of sources and paths. A concrete thermo/HVAC consumer now exists,
while prose routing, material/property inference and shipped-specialist
admission remain outside this increment.

For connected positive-conductance networks, each floating component supplies
one additive temperature freedom; grounded components have full free-node rank
in exact arithmetic. The implementation checks expected rank against the
numerical SVD result and exposes a numerical-rank refusal when they differ.
This is mathematical reasoning supporting the adapter, not a theorem about its
Rust implementation. No theorem statement or formal assurance claim was added.

Accepted grounded nodes expose absolute temperatures. Floating nodes expose
only candidate offsets and differences, with absolute temperature fields absent.
The consumer distinguishes solved, underdetermined, inconsistent, numerically
unresolved and below-absolute-zero candidate outcomes. Diagnostic candidates
remain labelled and are not promoted to accepted temperatures on a refusal.
Duplicate node definitions, duplicate unordered links, unknown endpoints,
self-links and zero/negative/nonfinite conductances are rejected. Deliberate
parallel conductances must be combined explicitly; a missing link is omitted.

Every result retains component grounding/source balance, each original link's
heat flow, each node's power residual/tolerance, ideal-reservoir exchanges,
global external heat balance and internal-link cancellation. It repeats the
model/tolerances, maps linear rows/columns to node IDs, and retains the original
linear diagnostics. Grounded link evidence uses reconstructed candidate
temperatures and original fixed temperatures, so a pathological reference
cannot hide a lost boundary temperature behind a small transformed residual.
Original-node acceptance adds the declared absolute W tolerance (default
`1e-8`) to the existing relative policy; this avoids false contradiction from
roundoff at zero-source equilibrium. It does not turn residuals into model truth.

Network inputs are capped at 128 total nodes and 1024 links. Existing JSON,
work, scratch and cancellation boundaries still apply; topology work respects
the operator's work limit too. No new threads or worker pools are created.

### Domain validation receipt

Root reported a central hbox `cargo test` result of **19 initial science tests
and 17 thermal tests passing**, within its combined 54-case science/incremental
run. No build or test process was started by this lane. The 17 thermal cases
include the exact two-free-node example, a four-free-node chain, positive and
negative sources, floating balanced and unbalanced networks, a disconnected
island, an isolated free node, all-fixed reservoirs, two different reservoirs,
reference changes, equal-temperature equilibrium, a pathological-reference
power failure, below-zero candidates, numerical rank loss, conflicting inputs,
conductance validation, JSON dispatch, cancellation and size caps. Formatting
completed successfully.

For the example, `a=b=310 K`; the free nodes send 20 W and 10 W to the 300 K
reservoir, which exchanges -30 W. The larger 2 W/K chain with 20 W at its
far end has temperatures `[300,310,320,330,340] K` and 20 W through every link.
These analytical expectations are authored independently of the solver.

The final output-only `model`, `tolerances`, and `linear_unknown_node_ids`
metadata fields were added just before root took integration ownership and
were called out to root for inclusion in its final build. No algorithm changes
followed root's passing thermal receipt. No specialist-panel numbers, Mini-live
registration, production limit measurements or deployment claims were added.
