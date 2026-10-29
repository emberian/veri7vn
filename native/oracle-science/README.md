# Scientific linear and thermal models

This optional provider solves small, dense systems of supplied linear equations
and fits supplied observations. It can support coupled heat or force balances,
concentration estimates from linear measurements, and fitted scientific
parameters. It does not infer equations from prose or decide whether the
equations describe the world. It is experimental floating-point Rust, with no
Isabelle theorem, Mini registration, or specialist-panel score yet.

`science.thermal_network` is a concrete domain consumer: give it nodes, signed
heat inputs, passive conductances and fixed boundary temperatures. It constructs
the balance equations and reports temperatures, edge heat flow and each node's
power balance. See [the thermal model and examples](THERMAL.md).

The current family consumers inspected were `energy/Calorimetry.thy` and
`energy/Thermo.thy`, `mechanics/Mechanics.thy`, `chemistry/Chemistry.thy`, and
`geostats/GeoStats_Stats.thy` under `src/extract/`. Those kernels have useful
formula and descriptive-statistics operations. This provider adds a distinct
supplied-matrix operation rather than replacing their exact computations.

## Calling it

The typed library exports `linear(input, operation, limits, cancel)` and
`call(json, limits, cancel)`. `call` consumes the structured JSON request below.
The binary reads one request from stdin, writes one JSON reply, and exits.
`--catalog` lists the operations and resource policy. Errors have structured
codes; the binary exits with status 2 on an error. A numerical inconsistency is
a result with diagnostics, not a transport error.

After root adds the package to the workspace and builds it:

```sh
cargo run -p oracle-science -- --catalog
cargo run -p oracle-science < oracle-science/examples/heat-balance.json
cargo run -p oracle-science < oracle-science/examples/spring-fit.json
cargo run -p oracle-science < oracle-science/examples/thermal-network.json
```

Run those commands from `native/`. On this project builds run centrally on the
designated build host; these commands describe the interface, not permission
to start an additional local build.

For example, two steady thermal nodes with conductances in W/K and heat inputs
in W give `3*T1 - T2 = 20`, `-T1 + 2*T2 = 10`:

```json
{
  "operation": "science.solve_linear",
  "arguments": {
    "matrix": [[3, -1], [-1, 2]],
    "rhs": [20, 10],
    "model": {
      "description": "two steady thermal nodes relative to a fixed reference",
      "variable_units": ["K interval", "K interval"],
      "row_units": ["W", "W"],
      "normalization": "both balance rows are expressed in watts",
      "assumptions": ["steady state; fixed linear conductances; no unmodeled heat sources"]
    }
  }
}
```

The analytic answer is `[10, 10]`. The numerical reply retains the caller's
model declaration, the candidate, rank, condition diagnostics, and the residual
of each original row.

Use `science.least_squares` for parameter estimation. For example, fitting
`force = offset + stiffness*displacement` at displacements `[0,1,2]` m with
observed forces `[1,2,4]` N gives the least-squares coefficients
`[5/6 N, 3/2 N/m]`. The nonzero force residuals are `[-1/6,1/3,-1/6]` N.
That result is a fit; requesting `science.solve_linear` for the same rows
reports `inconsistent_within_tolerance` and retains the fit candidate for
inspection. No noise distribution, standard error, confidence interval or
causal interpretation is supplied.

## Meaning of the result

Both operations compute a thin singular value decomposition (SVD), discarding
singular values at or below `rank_relative * largest_singular_value`.
The default rank tolerance is `1e-12`. The candidate is the pseudoinverse
result of that truncated model, without forming normal equations or an
explicit matrix inverse. Rank is numerical and depends on the supplied
coordinates and cutoff. It is not an exact algebraic-rank proof.

`science.solve_linear` distinguishes:

- `consistent_unique_within_tolerance`: every variable direction survives the
  rank policy, and the returned candidate passes the residual policy.
- `consistent_underdetermined_within_tolerance`: the candidate passes the
  residual policy, but there are unidentifiable directions. The candidate is
  the minimum-norm representative in the supplied variable coordinates of the
  truncated model, not a unique inference.
- `inconsistent_within_tolerance`: this candidate fails the residual policy.
  In particular a singular direction deliberately dropped by the rank policy
  can cause this outcome even when the original exact equations have a
  solution. This is not an exact inconsistency certificate.

`science.least_squares` labels its candidate as a fit and separately reports
whether the equations agree within the residual policy. The outcome states
whether the coefficients are unique within the rank policy or underdetermined.
A rank-truncated fit minimizes over the retained singular subspace; it need
not minimize the objective over every direction of the original matrix.

For each row the residual is recomputed as `r[i] = sum(A[i][j]*x[j])-b[i]`
using the original supplied matrix and the returned candidate, independently
of the SVD factors. Componentwise backward error is
`max_i |r[i]| / (sum_j |A[i][j]*x[j]| + |b[i]|)`; an all-zero row has error zero.
The default acceptance tolerance is `1e-10`. This expresses how well a
candidate fits the supplied equations under small componentwise relative
perturbations; it is not the relative error of the unknowns. Ill conditioning
can amplify small input changes despite a tiny backward error.

The reply includes individual residuals, each row's backward error, the
residual norm divided by the original largest RHS magnitude (or 1 for zero
RHS), and `A_scaled^T * (residual/rhs_scale)` for inspecting fit stationarity.
Norms use a stable hypotenuse accumulation, and sums use compensated summation.
These are floating-point diagnostics, not rigorous bounds. The condition
number is absent when any variable direction is discarded. The retained
subspace condition number is separate, and is absent for rank zero.

## Units and model boundary

Every variable and every equation requires a unit label. Use `"1"` for
dimensionless values. Each coefficient `A[i][j]` must have dimensions
`row_units[i]/variable_units[j]`. These labels and assumptions are caller
assertions; no dimensional parser checks them. Absolute temperatures must be
converted to the declared reference/interval model before a linear balance.
The existing family unit conversions and physical guards remain needed.

The caller must state the row normalization and weighting. Squaring residuals
with incomparable units has no physical meaning. For weighted least squares,
the caller supplies already weighted rows and RHS, retaining the weighting
decision in `model.normalization`. Weights normally multiply rows by their
square roots. The provider performs only global matrix and RHS scaling to
limit overflow. It never silently equilibrates rows, which would change the
objective, or columns, which would change the minimum-norm coordinates.

Energy consumers can construct several simultaneous steady balances after
unit conversion. Mechanics can supply linear equilibrium constraints with
declared loads and sign conventions. Chemistry can fit concentrations from
supplied linear response coefficients; this is not integer reaction balancing
or a claim of nonnegative concentrations. Statistics can fit a finite design
matrix after selecting variables, weights and a model. Any physical inequality
or conservation completeness premise requires the consumer's own checks.

## Resource and failure policy

Fixed caps are 512 equations, 128 unknowns, 1 MiB JSON, an admission work
estimate of `m*n*min(m,n) <= 8,388,608`, and at most 32 MiB of faer SVD scratch.
Matrices and output also consume memory; the scratch cap is not a total RSS
limit. Operator `Limits` can lower but cannot raise these caps. faer 0.24.4
is pinned with default features disabled and only `std,linalg` enabled. The
low-level SVD receives `Par::Seq` explicitly, so another crate enabling Rayon
does not change this operation's threading. There is no per-tenant worker pool
and no mutation of faer's process-global parallelism.

Cancellation is cooperative before and after SVD and between outer loops.
SVD is not interruptible, so hard deadlines require an owned, killable process
and global admission in the serving host. The CLI has no cancellation protocol;
its owner can stop that process. These caps are an initial service policy,
not measured latency or fairness evidence.

Malformed shape, nonfinite inputs, missing declarations, and relative
tolerances outside `[f64::EPSILON,0.01]` are rejected. Global normalization
underflow, unrepresentable candidates, overflow in residual computations,
or products rounded all the way to zero are numerical failures. This policy
conservatively refuses some systems that could be solved with other scaling
or higher precision. It does not promise accurate answers for every finite
f64 input or a rigorous forward-error estimate.

## Validation and promotion

The authored tests cover analytic heat balance and spring fitting, inconsistent
duplicates, rank deficiency, wide and zero systems, bad column scaling, global
scaling, row permutation, weighting, malformed/nonfinite input, cancellation,
lowered limits and range failures. Unit tests also exercise cancellation of
large opposite terms and overflow-resistant norms. Run only this package's
tests centrally (`cargo test -p oracle-science`). This lane does not run builds.

No theorem statements were added, and no shipped specialist panels have run
through this provider. Promotion needs an actual family adapter that constructs
the declared matrix and handles every result, independent physical examples,
and that specialist's own scorer. Benchmark decoding, SVD, residual checks,
memory and cancellation under shared admission before choosing a live limit.

API and feature choices were checked against the official
[faer documentation](https://docs.rs/faer/0.24.4/faer/),
[SVD API](https://docs.rs/faer/0.24.4/faer/linalg/svd/fn.svd.html), and
[feature list](https://docs.rs/crate/faer/0.24.4/features) on 2026-10-29.
faer is MIT licensed; its dependency tree and deployment cost still need the
root's central build and packaging review.
