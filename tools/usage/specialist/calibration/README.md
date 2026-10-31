# Supplied calibration

Fit a line to supplied measurements, carry the unit labels, and ask for a fitted
mean, a future observation, or an algebraic inverse point. The numerical operation
uses the existing SVD regression and retains its complete fit, diagnostics,
assumptions and reasons for absent uncertainty. This is a conditional association
on supplied rows. The input does not establish random sampling, independent
errors, causation, physical units or source completeness.

`forward_mean` takes x and returns the fitted conditional response.
`forward_observation` also requires an explicit new-observation relative precision
on the training scale. Its interval includes new noise only under the classical
Gaussian error model. HC3 retains a mean point but refuses the observation
interval: its coefficient covariance supplies no new-noise model.
`inverse_point` takes a response and algebraically inverts the fitted y-on-x
line. It is not x-on-y regression, an unbiased inverse estimator, a correction
for measurement error, or an errors-in-variables model. Inverse intervals are
refused. There is no transformation or conversion behind unit labels.

The request explicitly selects `point_only` or `pointwise_interval`. A value may
be returned while its requested interval is absent; read `unavailable_reasons`.
If every value is refused, the structured adapter returns `withheld` and retains
the diagnostic fit. Degenerate or poorly conditioned designs refuse all
calibration points. Near-zero numerical slopes refuse inverse points. A flag
marks x values outside the observed range; it does not validate extrapolation.

## Run the consumer

From the repository root, against an already built host exposing the optional
statistics provider:

```sh
python3 -B tools/usage/calibration.py \
  native/oracle-statistics/examples/calibration-forward.json \
  --base http://127.0.0.1:8000 --tenant calibration
```

The numerical CLI accepts the same arguments inside
`{"operation":"statistics.calibration","arguments": ...}`. The typed Rust entry
point is `oracle_statistics::calibrate(&CalibrationInput, &Limits, &dyn WorkControl)`.
The host uses its ordinary pure-operation admission and execution budgets.

The separate extracted comparison uses an existing geostats executable:

```sh
python3 -B tools/usage/calibration.py \
  native/oracle-statistics/examples/calibration-extracted.json \
  --geostats /absolute/path/to/geostats
```

This path admits bounded integer pairs and forward fitted points only. It
constructs complete questions for the existing recognizer and preserves each
raw kernel reply. `GeoStats_Paired.line_fit` internally uses exact rationals;
the existing reply renders coefficients and predictions to four decimal places.
The consumer therefore calls its displayed fields `rounded_*`. Its Python
framing, question recognizer, selected executable and provenance declarations
are untrusted. There is no new typed exact protocol or new extraction receipt.

The existing theorem statements have this scope: if `line_fit ps = Some(a,b)`,
then both the residual sum and the x-weighted residual sum are zero. For every
rational competing line `(c,d)`, its SSE equals the returned line's SSE plus
`sum((c-a+(d-b)*x)^2)`, and hence cannot be smaller. They apply to the admitted
rational one-predictor fit with intercept, not to the floating-point SVD,
intervals, inverse estimator, recognizer, rounding accuracy or world data.

## Validation for the central runner

No checks were executed by the implementation lane. There are **no new panel
numbers**. `panel.json` has 16 numerical requests and 3 extracted comparison
requests, including analytic uncertainty, inverse-direction distinctions,
constant/ill-conditioned x, zero slope, unit labels and unsupported requests.

The central runner can run only the affected tests:

```sh
cargo test --manifest-path native/Cargo.toml -p oracle-statistics --test calibration
python3 -B -m unittest tools.oracle_components.test_native_statistics
python3 -B tools/usage/specialist/calibration/test_consumer.py
python3 -B tools/usage/specialist/calibration/score.py --native /absolute/path/to/oracle-statistics
python3 -B tools/usage/specialist/calibration/score.py --base http://127.0.0.1:8000
python3 -B tools/usage/specialist/calibration/score.py --geostats /absolute/path/to/geostats
```

Keep native and hosted numerical reports separate, and keep the rounded extracted
comparison separate from both. `score.py` checks independently specified answers;
the classical interval case derives its quantile from the Cauchy tangent formula
and its covariance from orthogonal residuals. It reports correct refusals as
right and also counts all refusals under withheld. These are structured consumer
cases, **not** Oracle7's six admission criteria or a claim of interval coverage.

The affected shipped control panels are `statistics`, `statistics-v2`, and
`statistics-v3`. No shipped recognizer or organ is modified. Their six-criterion
scores remain the completion metric for those specialists. After integration,
run the existing parity harness against the unchanged geostats answerer and its
three scoped panels, preserve dev and heldout counts separately, and compare to
the pinned baseline. For example (substitute the pinned executable path):

```sh
python3 -B -m tools.parity.harness \
  --answerer '/absolute/path/to/geostats' \
  --specialist statistics,statistics-v2,statistics-v3 --split both \
  --out var/sol-wave-20261031/calibration/shipped-controls
```

This consumer is not installed as a natural-language Workbench organ and does
not replace descriptive statistics or exact counting. No shipped-panel gain,
Workbench admission, Mini promotion, new theorem, build receipt or performance
number is claimed by these authored files.
