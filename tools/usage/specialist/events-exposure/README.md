# Events and exposure

This consumer fits probabilities from supplied successes and trial totals, or
rates from supplied counts and exposure. A failure probability stays between
zero and one. A Poisson expected count uses the supplied exposure explicitly;
it does not confuse ten device-hours with ten independent devices.

The request names the independent sampling unit, explains grouping, and declares
the model assumptions. These remain caller assertions. Complete source records
do not establish random sampling, independence or a correct probability model.

## Use

Against an already built statistics CLI:

```sh
python3 -B tools/usage/events_exposure.py \
  native/oracle-statistics/examples/glm-binomial.json \
  --native /absolute/path/to/oracle-statistics --summary
python3 -B tools/usage/events_exposure.py \
  native/oracle-statistics/examples/glm-poisson.json \
  --native /absolute/path/to/oracle-statistics
```

Against a host exposing the optional statistics provider:

```sh
python3 -B tools/usage/events_exposure.py \
  native/oracle-statistics/examples/glm-poisson.json \
  --base http://127.0.0.1:8000 --tenant events-exposure --summary
```

Tenant labels and pure-call envelopes use the existing shared host client.
Omit `--summary` to retain the complete request, fit diagnostics, certificates,
conditional intervals, and independent client certificate replay. Nothing is
installed as an Oracle7 natural-language organ or admitted to Mini.

The operation is `statistics.events_exposure`. The typed Rust entry point is
`oracle_statistics::glm::fit(&GlmInput, &Limits, &dyn WorkControl)`.
`family` selects `grouped_binomial_logit` or `poisson_log`; `method` must explicitly
be `maximum_likelihood`. There is no automatic Firth, ridge, count transform,
family change or variance correction.

For binomial rows, supply integer `successes` and positive integer `trials` with
successes no greater than trials. Each row describes trials sharing the same
conditional success probability and predictors. Counts are sampling totals,
never precision or loss weights. Poisson rows instead supply nonnegative integer
`counts`, positive `exposures`, and one `exposure_unit`. Exposure enters as a
fixed log offset. Predictions require a new exposure for Poisson; binomial
predictions may include a trial total to obtain expected successes.

`uncertainty` is explicitly `none` or `model_based_wald`. Where available, the
latter returns normal Wald coefficient intervals and conditional mean intervals
by transforming link endpoints. It uses model-based inverse information and
fixes dispersion at one. It supplies no interval for an individual future count.
Overdispersion, zero inflation, repeated devices, selection, optional stopping
and causal conclusions require separate justification or a different model.

## What makes a returned estimate acceptable

The solver uses stable log probabilities and log exposure, column scaling,
sequential thin SVD Newton/IRLS subproblems, and bounded step halving. It forms
neither an unscaled normal-equation inverse nor a log(count+1) regression.
Both the information-scaled score norm and Newton decrement must be small.
A small step or exhausted iteration limit cannot declare convergence.

Numerical convergence still does not show that an ordinary finite maximum exists.
A second boundary checks exact rational witnesses against the original supplied
binary64 values, interpreted as dyadic rationals. It uses no sign tolerance.
The numerical solver only proposes these witnesses. The Rust checker and the
independent Python consumer/adapter replay positivity, balance and exact rank.
They check count/trial/exposure support before drawing a conclusion.

An accepted `finite_mle_converged` result requires both numerical convergence and
a finite-existence witness. The witness establishes existence and exact
identifiability for this likelihood; it does not prove the numerical coefficients
are its optimum or establish statistical assumptions. `separation_certified`
requires an exact strictly improving recession direction. Other outcomes include
`rank_deficient`, `design_ill_conditioned`, `not_converged`, and
`no_finite_mle_established`. Missing a witness is inconclusive, never evidence of
separation or physical infeasibility. Nonaccepted results retain the last
coefficient candidate and fitted-row diagnostics, while withholding new-row
predictions and inference.

Wald inference can remain unavailable even for an accepted fit when information
is poorly conditioned or outside numerical range. Exposure or a link may produce
means too small for floating-point display; the result flags boundary values and
refuses unrepresentable prediction values/intervals. A displayed zero is not an
exact probability claim. The likelihood/deviance calculation uses stable link
values. `log_likelihood_kernel` omits binomial-combination or Poisson-factorial
constants. Pearson and leverage outputs are diagnostics, not calibrated tests
that validate the model.

## Exact witness reasoning for review

These are mathematical arguments for the handwritten checker, not newly proved
Isabelle theorems.

Let X include the requested intercept and original predictor values. In a
binomial row, include +x when successes are positive and -x when failures are
positive. Call the resulting signed rows Z. A finite-existence witness consists
of strictly positive rational weights with Z-transpose times weights equal to
zero, plus an exactly nonsingular p-row basis. Any direction with all signed
row products nonnegative must then make every product zero; full rank forces
the direction to be zero. Thus there is no nonzero likelihood recession direction
and the strictly concave log likelihood has a unique finite maximizer. This
covers overlap among independent Bernoulli rows without requiring mixed outcomes
at every identical design point.

For Poisson, a possible recession direction has x*d=0 on positive-count rows
and x*d<=0 on zero-count rows. A finite-existence witness balances original rows
with strictly positive weights on zero-count rows and unrestricted weights on
positive-count rows, again with an exact full-rank basis. Taking the inner
product with such a direction forces every zero-count row product to be zero;
full rank then forces d=0. This handles finite models whose positive-count
subset alone lacks full rank. In particular, all-zero counts with an intercept
have an improving intercept direction, but all-zero counts without an intercept
need not: the supplied design determines that question.

The finite-witness proposer starts from binomial support score weights or
Poisson fitted-mean-minus-count weights, corrects their small balance residual
exactly on an independent subset, then independently replays the witness. The
separator proposer rounds a numerical direction, projects it into the exact
required equality space, then replays every original inequality and requires a
strict improvement. Rounding and projection never decide acceptance on their own.

Public replay functions are `verify_finiteness_certificate` and
`verify_separation_certificate`. Certificates contain bounded rational strings;
`basis_rows` indexes the signed-row order described above for binomial and the
original row order for Poisson. Exact operations have bit and work caps. Resource
exhaustion returns an error, not a mathematical conclusion.

The implementation uses existing pinned faer 0.24.4 and statrs 0.18.0. The only
added dependencies are the already-used workspace `num-rational` and
`num-traits`; there is no new statistical or optimization framework. Caps are
256 rows, 16 parameters, 128 predictions, 100 iterations, 32 halvings, one billion
counts/trials per row, 4096-bit rationals and 400,000 exact arithmetic checks.
Total work uses the parent statistics limit and charges repeated SVDs, exact
arithmetic, prediction, diagnostic/leverage work, retained-request assembly and
publication. SVD/quantile calls are not internally interruptible; checkpoints
surround them. Log exposure must lie within [-500,500]. Limits can be lowered,
not raised, through the parent `Limits`.

## Evidence and scoped central checks

No builds, tests, panel runs or performance measurements were performed by the
implementation lane. There are **no new panel numbers**. The source received
independent mathematical review; its findings about final work accounting and
client support premises were repaired, with focused regression cases authored.

The central runner can execute:

```sh
cargo test --manifest-path native/Cargo.toml -p oracle-statistics --test glm_contract
python3 -B -m unittest tools.oracle_components.test_native_statistics
python3 -B tools/usage/specialist/events-exposure/test_consumer.py
python3 -B tools/usage/specialist/events-exposure/score.py --native /absolute/path/to/oracle-statistics
python3 -B tools/usage/specialist/events-exposure/score.py --base http://127.0.0.1:8000
```

The 27-case panel includes grouped versus expanded Bernoulli equivalence,
analytic intercept and saturated slope fits, an independently solved cubic-score
overlap case, exposure-unit changes, Poisson overlap with an insufficient
positive-count subset, complete/quasi separation, zero-count geometry, extreme
exposure, rank aliasing, exhausted iteration allowance and invalid support.
Expected covariance comes from analytic information matrices; interval endpoints
use an independently specified normal quantile. Client tests include negative
counts, zero exposure and an exact noninteger balance broken by one binary64 ULP.
These structured-case counts are separate from Oracle7's six admission criteria
and make no empirical coverage claim.

The unchanged shipped controls remain `statistics`, `statistics-v2` and
`statistics-v3`, scored by their own scorers. This operation adds a new supplied
workflow; it does not replace their descriptive statistics or counting tasks.

Sources read locally: the statistics scout, Kosmidis–Firth's
[Jeffreys-prior penalty, finiteness and shrinkage](https://arxiv.org/abs/1812.01938)
introduction and section 2.2, and Friedman–Hastie–Tibshirani's
[Regularization Paths for Generalized Linear Models via Coordinate Descent](https://www.jstatsoft.org/article/view/v033i01)
logistic Newton/IRLS section. Firth finiteness is a property of a different,
explicitly penalized estimator; it is not borrowed to justify ordinary MLE here.
The paper's Wald caveat is one reason no finite-sample interval guarantee is made.
