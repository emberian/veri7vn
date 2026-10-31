# Quality inspection and benchmark success while results arrive

Supply the complete ordered scores observed so far, their fixed bounds, and the
error budget allocated to this metric. The consumer reports an interval for a
single common conditional mean. You may inspect the interval after every result
and stop when it settles your prespecified decision. No sample-size commitment
is needed. A wide interval means more information is needed; an empty interval
means the procedure has excluded every common mean, not that it identified drift.

IID sampling is sufficient. More generally, every result must have the same
expected value given all prior results. Correlated measurements need that actual
conditional-mean property; writing an assumption in a request does not establish
it. A changing model, grader, population, outcome-dependent omissions, changing
bounds, or selected benchmark cases can break the contract. The interval does not
predict an individual future result. Completeness of supplied rows does not
establish representative sampling or causation.

For several models or inspection metrics, declare error allocations whose sum
fits the intended family budget. Two streams at alpha 0.025 give family error at
most 0.05 by a union bound. This operation checks one stream's numeric allocation;
it cannot verify other streams, prevent restarting until a favorable result, or
recover a selected population's mean.

## Actual hosted consumer

After root integrates the new statistics operation into the ordinary native host:

```sh
python3 -B tools/usage/sequential_monitor.py \
  native/oracle-statistics/examples/sequential-quality.json \
  --base http://127.0.0.1:8000 --tenant inspection
```

Use `sequential-benchmark.json` for bounded scores and two-metric allocation.
The command requires the real hosted operation; it has no Python numerical
fallback. Until root's integration and validation, these are candidate workflows,
not evidence of a live deployment or scored specialist.

The Rust API is `sequential::replay(&SequentialInput, &Limits, &dyn WorkControl)`.
`step(&SequentialState, expected_position, next_observation, ...)` imports and
replays raw state once, then returns a new state atomically. Rejected calls
leave the input unchanged. Replaying identical supplied data gives identical
state/history; steps with a stale expected position are rejected. Serialized
state contains the original ordered data and config, never trusted cached capital.
This is not authenticated storage or durable exactly-once processing. Pure replay
is idempotent; an external host persisting appends must own retry identity. No
states are merged. Existing row/work limits bound each replay (default 512 rows).

For repeated appends in one native owner, `SequentialMonitor::new` creates a
private invariant-carrying state and `append` performs constant numerical work
(64 charged units), plus amortized vector growth. `SequentialMonitor::import`
validates and replays untrusted raw state once. There is no deserializer or mutable
field access for the cached accumulator. Appends retain exactly the same outward
arithmetic/order as full replay. Borrowed `history`, `latest` and `config` avoid
copying; `export_state` explicitly copies the bounded raw sequence. `into_result`
moves the owned sequence/history into the response. The hosted pure replay
operation keeps its existing complete-input contract; no new registry is created.
Unknown serialized fields cannot introduce a forged cached accumulator. Editing
otherwise valid raw observations describes a different supplied experiment;
this API cannot authenticate their real-world origin.

## What the calculation does

Normalize each observation into [0,1] using the declared bounds. Before observing
result t, choose lambda_t = 2^-floor(log2(t)/2), depending only on its position.
For candidate mean m, the two log capitals are

    L_plus(t,m)  = sum lambda_i (X_i - m) - sum lambda_i^2 / 8
    L_minus(t,m) = sum lambda_i (m - X_i) - sum lambda_i^2 / 8.

Hoeffding's conditional exponential inequality makes each exponentiated capital
a nonnegative supermartingale when m is the true common conditional mean. Ville's
inequality bounds the probability that either process ever reaches 2/alpha by
alpha. Thus excluding candidates beyond log(2/alpha) at any prefix is valid even
under optional stopping. The returned running intersection preserves this claim.
The theorem concerns the stochastic model and exact mathematical construction;
this Rust implementation is handwritten and has no extracted numerical proof.

We deliberately use the larger threshold ceil(log2(2/alpha)), since ln(2)<1.
This costs width but eliminates transcendental rounding in all rejection decisions.
Dyadic weights/penalties are exact binary values. Basic arithmetic uses adjacent
binary64 values to enclose each operation, including normalization, sums, linear
interval inversion and conversion to original units. Endpoints round outward.
No grid search can miss means between grid points; no iteration/root tolerance is
hidden. Lower log-capital bounds cannot overstate evidence under the stated IEEE
arithmetic model. Empty intersections remain empty. There is no exponentiation,
underflowing capital product or overflowing evidence multiplier.

The method/version and error allocation are frozen within a replay state.
Caller-provided descriptions remain assertions. Changing an input config creates
a different supplied experiment; no registry pretends it can detect that change.
This simple conservative process is less statistically efficient than the
variance-adaptive betting constructions in the cited paper.

## Refutation checks and measurement

`native/oracle-statistics/tests/sequential_contract.rs` independently enumerates
short Bernoulli sequences with integer capital arithmetic, accumulates the
probability of ever excluding each true mean, and checks every prefix. It also
checks analytic constant streams, affine bounds, step/replay identity, stale
positions, atomic rejection, cancellation and resource caps. The optional
`--enumerate 10` consumer mode compares actual hosted replies with exact Python
fractions and an adversary stopping at first exclusion. It requires many real
host calls and is intended for central validation, not routine invocation.

Coverage checks must count ever-exclusion, rather than only exclusion at the last
sample. A current-outcome-dependent rate is explicitly outside this construction:
choosing the sign after seeing a fair coin makes every signed increment +1/2 and
can force a false rejection. The API admits no caller-supplied rates. Likewise,
a high-to-low deterministic stream illustrates why drift invalidates inference;
it is not an alternative valid population model for these intervals.

Central validation should report replay/append latency at 16, 128 and 512 rows,
request/result sizes, host cancellation, and memory on the designated host.
No tests/builds were run by the implementation lane. No specialist-panel numbers
yet. The shipped descriptive statistics panels do not measure this consumer.

Source read: Waudby-Smith and Ramdas, *Estimating means of bounded random variables
by betting* (2024), §3.1 equations (8)--(12), and §2 conditional-mean setup:
https://arxiv.org/abs/2010.09686. Local primary text retained in paperbin; no papers
are copied into this repository.

The separate 26-case supplied consumer panel is `panel.json`. Its `score.py`
compares every interval with an independent exact-rational inversion and checks
outward enclosure, useful width, ordered-state binding, and deliberate admission
failures. Run against `--native /absolute/path/to/oracle-statistics` or `--base`
with the real host. It reports right/wrong/withheld/false-yes counts for these
manufactured cases only. This panel has not yet been executed by this lane.

The exact-rational edge regressions include ordinary decimal-looking f64 bounds,
negative bounds and cancellation, a large same-sign offset over a narrow range,
a one-ULP interval, an eight-subnormal-unit width, tiny negative values and a
large finite width. Both interval endpoints and reported log-capital lower bounds
are checked against exact binary64-as-rational arithmetic at every Rust prefix.
The consumer scorer independently uses Python Fraction endpoints. A one-subnormal
width is deliberately refused because its outward denominator includes zero;
an overflowing declared width is also refused. These are explicit numeric domain
limits, not silent narrower intervals. No new execution receipt is claimed.

The host reports native admission failures as HTTP 200 completed envelopes with
`status=withheld`, `reason=native_request_refused`, and a native diagnostic in
`detail`. Such a resultless reply satisfies a deliberately invalid panel case
only when its diagnostic matches the expected input-error family (or the explicit
sequential row-cap resource refusal). Every valid case still requires a complete
result and exact-rational checks. Execution failures, cancellation, shared-budget
exhaustion, malformed native replies and unavailable operations cannot satisfy a
rejection case. Reports retain structured refusals and HTTP 400/422 diagnostics.
