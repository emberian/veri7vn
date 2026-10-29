# Supplied statistical linear models

This optional Rust provider fits a supplied linear design and reports what can
be inferred under a declared error model. It adds ordinary and weighted linear
regression, coefficient uncertainty, conditional-mean prediction, and influence
diagnostics. It uses floating-point arithmetic. It has no Isabelle theorem,
specialist-panel score, natural-language adapter, or Mini registration yet.

The interface does more than return a successful fit: rank deficiency leaves
coefficients unidentified, saturated fits have no noise estimate, and a nearly
perfect fit can be numerical rounding. Those cases retain useful fit information
and explicitly withhold inference. A small p-value never establishes causation,
the truth of a model, or the probability that a null hypothesis is true.

## Consumer and coverage gap

Read-only inspection on 2026-10-29 found that the shipped
`statistics/organ_stats_v1.py` supplies means, medians, modes, ranges, sample and
population dispersion, supplied z-scores, counting, and binomial probabilities.
`statistics-v2` repairs argument ordering, binomial parsing and exact mean/median
display. `statistics-v3` expands dataset phrasing. None supplies regression,
coefficient covariance, model diagnostics or prediction intervals. This provider
adds that separate capability; it does not replace those descriptive or exact
counting operations.

`oracle-science::linear` already returns a numerical least-squares candidate,
rank, conditioning and equation residuals. It deliberately supplies no statistical
uncertainty. This crate's concrete consumer is supplied calibration or scientific
measurement data: for example, force against displacement, with an explicit
intercept, design, weights, units and error assumptions. A statistics adapter can
pass such data to `statistics.linear_regression`; a scientific consumer can use
the same operation after deciding which observations and error model are valid.
No prose parser makes those choices here.

## Interface

The typed entry point is `regress(&RegressionInput, &Limits, &AtomicBool)`.
`call(json, limits, cancel)` returns JSON; `catalog()` describes the operation
and limits. The CLI accepts one request on stdin, prints one JSON reply, and
exits. `--catalog` prints the catalog. Errors use `invalid_input`, `invalid_json`,
`resource_limit`, `cancelled` or `numerical_failure`; the CLI exits 2 on errors.

After root integrates the package into the workspace, central validation uses:

```sh
cargo test -p oracle-statistics
cargo run -p oracle-statistics -- --catalog
cargo run -p oracle-statistics < oracle-statistics/examples/calibration.json
cargo run -p oracle-statistics < oracle-statistics/examples/weighted-hc3.json
```

Those commands run from `native/`, on the project's designated build host under
root's resource controls. This lane authored tests and did not run Cargo.

Requests use the provider envelope:

```json
{
  "operation": "statistics.linear_regression",
  "arguments": {
    "features": [[-1], [0], [1]],
    "response": [0, -1, 4],
    "intercept": true,
    "covariance": "classical_normal_errors",
    "model": {
      "description": "Prespecified force calibration",
      "predictor_names": ["position"],
      "predictor_units": ["m"],
      "response_unit": "N",
      "assumptions": ["Fixed positions; correct linear conditional mean; independent Gaussian errors of equal unknown variance"]
    },
    "predictions": [{"features": [0], "observation_relative_precision": 1}]
  }
}
```

`intercept` and `covariance` are required decisions. An intercept is added before
supplied features. An intercept-only fit accepts empty feature rows. Predictor
names must be unique, including the reserved generated name `(intercept)` when
used. Names and unit labels are retained assertions; no unit parser checks them.
Coefficient units are response units divided by the corresponding predictor
unit, with response units for an intercept. The model requires a description,
response unit, one name/unit per supplied feature and at least one assumption.
Unknown JSON fields and nonfinite numbers are rejected.

Optional `relative_precisions` has one positive finite entry per observation.
Missing weights mean all ones. These are fixed loss weights; they are neither
frequency counts nor survey weights. Zero-weight omission, grouped correlation,
estimated-weight uncertainty, missing data, variable selection, regularization,
GLMs, time series, Bayesian posteriors and automatic feature construction are
outside this contract. Under HC3 the field still names loss weights, with no
claim that they equal true inverse variances.

`confidence_level` defaults to 0.95 and is limited to `[0.5,0.999]`.
`rank_relative` defaults to `1e-12` and is limited to `[f64::EPSILON,0.01]`.
No numerical tolerance is a statistical confidence level.

## Fit, rank and numerical checks

Let `X` include the requested intercept, `y` be the response, and `w` be the
supplied positive weights. The objective is `sum(w_i * (y_i-X_i*beta)^2)`.
First divide all weights by their maximum, then multiply each row and response
by the square root of that normalized weight. Global design and response scales
limit range loss. No per-column or additional row equilibration changes the
declared objective or the minimum-norm coordinates.

A thin faer SVD computes the fit. Singular values at or below
`rank_relative * largest_singular_value` are discarded. Rank is numerical and
coordinate-dependent, not a proof of algebraic rank. In a deficient model the
reported candidate is the minimum-norm representative of the truncated design
in the supplied parameter coordinates. Its individual coefficients are not
identified; inference and new-row predictions are withheld. The provider does
not yet check whether a particular contrast or new row remains estimable.

Residuals are `y-X*beta`, recomputed from the returned coefficients and original
supplied rows. Compensated sums and hypotenuse norms reduce avoidable roundoff.
The independent stationarity diagnostic uses the scaled design and residuals;
inference is withheld above `1e-10`. Inference also requires full column rank,
positive residual degrees of freedom `n-p`, a residual norm above the rounding
floor, and a design condition number at most `1e8`. A returned fit can remain
useful when one of those inference policies fails; explicit reason strings
explain the absence. SVD nonconvergence is a numerical error, never success.

The rounding floor is `64 * EPSILON * max(||b_scaled||,1) * sqrt(n)`.
The condition cap and this floor are conservative service policies, not rigorous
forward-error bounds. Underflow/overflow during checked products, restoration
of units, residuals, covariance or intervals produces a numerical refusal.
The operation does not promise useful output for every finite `f64` input.

## What the uncertainty means

`classical_normal_errors` requires a correct conditional linear mean, fixed
design/weights, and independent Gaussian errors with
`Var(error_i | X) = sigma^2 / w_i`. These assumptions are caller assertions.
With `W` the normalized diagonal weights, estimate
`s^2 = sum(W_ii * e_i^2)/(n-p)`. The covariance is
`s^2 * (X' W X)^-1`. Coefficient tests and pointwise confidence intervals use
Student's t with `n-p` degrees of freedom. This is the usual finite-sample
statistical result under the stated model, computed numerically here.

`hc3_asymptotic` instead permits arbitrary conditional error variances, retaining
a correct linear mean, fixed weights and independent observations. Let
`Z = sqrt(W) X`, `u = sqrt(W) e`, `B = Z^+`, and
`h_i = diag(Z Z^+)_i`. Its covariance is

```text
B * diag((u_i/(1-h_i))^2) * B'
```

This is the HC3 sandwich on the transformed weighted problem. Equivalently,
in original rows it is

```text
(X' W X)^-1 * [sum_i W_ii^2 * X_i' X_i * e_i^2/(1-h_i)^2] * (X' W X)^-1
```

The implementation builds covariance factors from SVD vectors rather than
forming a normal-equation inverse. HC3 needs positive `1-h_i`; when any gap is
at most `1e-10`, its inference is unavailable. HC3 coefficient tests and intervals
use asymptotic normal Wald tails, not finite-sample Student-t coverage. They can
be unreliable in small samples or under high leverage. No sample-size threshold
can establish regularity from the observed rows alone. HC3 does not handle
cluster, repeated-measurement or time-series dependence.

Multiplying every input weight by the same positive constant leaves the fit,
leverage, both covariance choices and all intervals unchanged. Classical
individual-observation intervals remain invariant when the new observation's
precision receives the same rescaling. `input_precision_scale` records the
removed maximum. `residual_std_at_unit_normalized_precision` uses the normalized
precision scale; it is a common noise-scale estimate only under the classical
model, and a descriptive residual scale under HC3.

All intervals are pointwise for a prespecified model. There is no correction for
multiple comparisons, feature selection, optional stopping or publication bias.
P-values are two-sided tests of each coefficient against zero under the chosen
reference distribution. Tail calculations are approximate floating-point values
and can underflow to zero; zero is not an exact impossibility claim.

## Predictions and influence

For full column rank, supplied prediction rows get fitted means. When inference
is available they also get the mean standard error and a pointwise mean interval,
using `sqrt(x_new' Cov(beta) x_new)`. Extrapolation, covariate shift and whether
a new row has physical meaning are not assessed.

Only the classical model can supply an individual-observation interval. The
caller must provide `observation_relative_precision` on the same scale as the
training weights, and assert a new independent Gaussian observation from the
same model. The variance adds `s^2 / w_new_normalized` to mean variance. Omitting
new precision requests only the mean interval. HC3 requests with new-observation
precision are rejected: a robust coefficient covariance alone does not estimate
new-observation noise.

Each training row reports leverage and residual. Where meaningful it also
reports the internally standardized residual, Cook's distance and the analytic
leave-one-out residual. The first two use the classical WLS residual scale even
when HC3 covariance is selected; they are influence diagnostics, not calibrated
outlier probabilities. The formulas are:

```text
t_i = sqrt(W_ii)*e_i / (s*sqrt(1-h_i))
D_i = t_i^2 * h_i / (p*(1-h_i))
leave_one_out_residual_i = e_i/(1-h_i)
```

Leverage close to one suppresses the affected diagnostics; rank deficiency
suppresses them throughout. These values do not validate linearity, independence,
normality or homoskedasticity. There is no automatic data deletion or refitting.

## Resource policy and validation

Fixed caps are 512 observations, 64 parameters including an intercept,
128 prediction rows, 1 MiB request JSON, an admission estimate of
`n*p*p <= 2,097,152`, and 32 MiB faer SVD scratch. Operator `Limits` may lower
but cannot raise these caps. Every dimension is admitted before matrix/covariance
allocation. Matrices, vectors, JSON and output also consume bounded memory;
the scratch cap is not a process RSS cap. Labels are at most 1,024 bytes each
and model assumptions number at most 16. `faer` explicitly receives `Par::Seq`,
even if another dependency enables its parallel features. This crate creates
no workers, RNG, global model, per-tenant pool, or global thread setting.

Cancellation is cooperative around SVD and distribution quantile calls and in
outer loops. Those library calls are not interruptible. Hard deadlines and fair
global admission belong to an owning host or contained process. The CLI has no
cancellation protocol. No latency, memory benchmark or fairness measurement is
claimed by the fixed caps.

Authored tests independently derive coefficients, classical covariance, HC3,
leverage, standardized residuals, Cook's distance, leave-one-out residuals and
prediction variance. A one-degree-of-freedom example checks Student-t tails and
quantiles through independent Cauchy arctangent/tangent formulas. Other cases
cover weighted intercept models, global precision scaling, predictor/response
unit scaling, row order, rank deficiency, unit leverage, saturation, roundoff
fits, poor conditioning, no intercept, zero design, JSON dispatch, malformed
input, bounds, cancellation and extreme weight range. These tests were authored
but not run in the lane; root owns central validation. There are no new theorem
statements and no shipped-panel numbers yet.

## Crate choice and sources

Official sources were inspected on 2026-10-29. `faer` 0.24.4 is already used by
`oracle-science`; this crate pins the same version with only `std,linalg` and
explicit sequential SVD. `statrs` 0.18.0 supplies Student-t/normal quantiles and
survival functions, with default `nalgebra` and `rand` features disabled. Both
are MIT licensed. These are small deterministic calls; no numerical optimizer
or stochastic sampler is required by this closed-form fit. The pinned version
was checked against its source; `statrs` latest currently names 0.19.1, with
different features and a higher MSRV. This lane does not assume that an upgrade
is free or necessary.

Sources: [faer SVD API](https://docs.rs/faer/0.24.4/faer/linalg/svd/fn.svd.html),
[statrs 0.18 package/features](https://github.com/statrs-dev/statrs/blob/v0.18.0/Cargo.toml),
[Student-t source](https://github.com/statrs-dev/statrs/blob/v0.18.0/src/distribution/students_t.rs),
and [normal source](https://github.com/statrs-dev/statrs/blob/v0.18.0/src/distribution/normal.rs).

The wider modeling candidates remain useful for different work:

| Crate | Primary source inspected | Decision for this operation |
| --- | --- | --- |
| `linfa-linear` 0.8.0 | [LinearRegression API](https://docs.rs/linfa-linear/0.8.0/linfa_linear/struct.LinearRegression.html) | Provides supervised OLS fitting/prediction; adopting its dataset/array contract does not supply this provider's rank, conditional inference and resource semantics. Reuse existing faer instead. |
| `argmin` 0.11.0 | [Executor API](https://docs.rs/argmin/0.11.0/argmin/core/struct.Executor.html) | Appropriate for a future iterative likelihood/GLM provider with convergence evidence. No optimizer needed for SVD regression. |
| `rv` 0.19.2 | [Probabilistic modeling docs](https://docs.rs/rv/0.19.2/rv/) | Distribution traits and conjugate probabilistic models deserve a separate Bayesian operation with explicit priors/posteriors. Not needed for t/normal tails. The latest 0.20.1 docs build currently fails, per its official package page. |

This is an optional provider, not a conclusion that linear regression exhausts
statistical modeling. Promotion needs root workspace/PyO3/host integration,
actual consumer routing, central numerical tests, packaging/resource measurements,
and the affected specialists' own scorers. Repeated SVD admission/scaling code
across science and statistics may later deserve an internal shared numerical
module after both consumers establish the interface they actually need.
