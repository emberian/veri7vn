# Prepared thermal operator review — 31 October 2026

Astra source-only review of the existing `PreparedThermalNetwork` improvement by
sol_thermal. The central runner sol_expansion_validation owns execution after
freeze. This lane changes only this note; no builds, tests, panels or commits.
There are no shipped-panel numbers or completion claims.

Baseline: preparation retains dense SVD factors, but each solve clones the whole
network and repeats topology traversal, operator assembly and original-node
acceptance through `thermal_with_solver`. The existing scenario workflow consumes
full original-node evidence and independently recomputes powers and derivative
balances. Its identities cover complete ordered base input, including loads,
boundary values and numerical policy; they are not topology-only cache keys.

Review targets for the refactor:

- Immutable endpoint/component/free-node topology and spatial operator; changing
  loads or existing fixed-temperature values changes only RHS and evidence.
- Boundary-membership, conductance, node ordering and numerical-rank policy remain
  preparation invariants. No cross-model factor reuse through a loose identity.
- Reused candidates still undergo absolute-temperature reconstruction, original
  link/node balance checks, below-zero refusal and reservoir accounting.
- Per-solve local limits, shared fuel/cancellation and context-aware result
  reservations survive reuse. Public access cannot detach buffers from owners.
- The existing batch, host and workflow consumer use the compiled route; tests
  compare numerical/evidence results with the prior independently assembled path.

## Source inspection during implementation

`compile_thermal` separates validated endpoints/components/free-node indices and
the reduced Laplacian from the scenario values. `build_rhs` preserves the old
edge order and reference-offset arithmetic, admits complete finite value vectors
and refuses changes to boundary membership. `evaluate_candidate` is shared by
fresh and prepared solves and retains original-node absolute-temperature/power
acceptance, component sums, reservoir evidence and below-zero outcomes.

The prepared owner retains compiled structure and SVD. Its solve path rebuilds
only value vectors and evidence. The new context-aware `PreparedThermalSolve`
keeps payload and guard private and exposes immutable references; serialization
borrows the owner. The old raw-result API remains explicitly caller-owned.
Per-solve admission retains row/column bounds and now estimates actual quadratic
solve/evidence work rather than charging a fresh cubic factorization.

Identities are separated appropriately: the historical full preparation-input
hash remains for batch compatibility; operator identity binds ordered nodes,
boundary membership, links/conductances and numerical policy; template identity
also binds declarations/reference/power policy while clearing base RHS values;
single-solve request identity binds that template and the full supplied scenario.
None of the retained invariant fields is publicly mutable.

The author repaired both review follow-ups: the README now states that preparation
validates base quantities without solving the unrequested baseline, and sensitivity
evaluation uses the retained endpoint indices. The final README wording was also
corrected and reread: fresh-factorization comparison shares compilation and
candidate acceptance, while closed-form chain truth and Python original-node
replay provide independent checks.

## Final source result

No numerical, factor-invalidation or result-reservation defect was identified in
the supplied freeze. The existing batch calls the retained solve, so the live
host/workflow consumer gains the compiled route without a new parallel API.
The raw WorkControl API remains caller-owned; the context-aware single-solve owner
retains its own guard independently of the prepared model's lifetime.

Eight new authored tests cover closed-form chain truth plus fresh factorization
comparison, changed boundary values, identity dependencies, current-scenario
binding, quadratic work with no new SVD scratch, stricter local caps, separate
model/result lifetimes, cancellation, below-zero candidate refusal, caller edits,
and deferring huge finite unrequested base loads. Existing sensitivity tests and
the Python original-node/derivative replay remain relevant. These are inspected
test sources, not passing receipts.

Source SHA256 values checked against the author's freeze:

- `thermal.rs`: `6bece4d7332480cd0344c2808ce98649f23e3b4fed9068104c9c002bc81a00d9`
- `thermal_scenarios.rs`: `772e601a573946145664f1a1962a1f84907d982edd8c36eec2f0da6037f45d27`
- `tests/prepared_thermal.rs`: `211b750c2f894d9dec85a4fe782ef465276da64f7f8d631c357cfbc8407f8e06`

Central execution must cover the existing fresh thermal tests, including
floating/mixed/rank/refusal behavior, existing scenario/sensitivity tests, the new
prepared tests and the actual host consumer panel. No speedup, new theorem or
shipped-panel score is claimed. This lane changed only this review note.
