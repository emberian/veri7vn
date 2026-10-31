# Expansion mathematical review — 31 October 2026

Astra independent source review of exact optimization, events/exposure GLMs and
sequential monitoring. **No tests/builds run, no new specialist-panel numbers,
and no new theorem receipt.** Findings below concern actual source and authored
tests, not successful execution. Only this report is owned by the review lane.

## Findings and repair status

1. **P2: independent Python GLM replay omitted distribution-support premises.**
   `tools/usage/events_exposure.py::cone` checked design shape but did not admit
   counts, trials or exposure before `replay_finiteness` asserted finite ordinary
   MLE existence. Concrete counterexample: Poisson family, intercept-only row,
   `counts=[-1]`, `exposures=[1]`, weights `["0"]`, basis `[0]`. Its unrestricted
   weight balances and its basis is nonsingular, so the Python checker accepts.
   But the supplied likelihood is `-eta-exp(eta)` and has no finite maximizer.
   Zero exposure with a positive count is another inadmissible model. Native
   `glm::admit` correctly rejects these; this is the separate consumer checker's
   advertised independent replay boundary. Requested repair: independently admit
   integer count/trial support, positive bounded exposure and family-specific
   fields before replay; add negative-count/zero-exposure/binomial-support tests.
   Sent to calibration owner and root. **Resolved in final source review:** both
   the usage client and adapter replay now admit integer support, count limits,
   exposure positivity/range and forbidden cross-family fields before producing
   a cone. `validate_result` invokes this gate even without a certificate. The
   concrete negative-count and zero-exposure examples now fail admission.
   Inspected authored `IndependentReplay` tests in
   `tools/usage/specialist/events-exposure/test_consumer.py` and the adapter's
   `test_replay_requires_valid_sampling_support`: they cover the counterexample,
   boolean/fraction counts, forbidden family fields and exposure range/support.

2. **P2: final GLM diagnostics escaped cooperative accounting.** The original
   post-prediction observation loop computes leverage with up to n*p*p arithmetic
   and performs retained-result construction without `budget.pay` or a final
   checkpoint. `inverse_factors` also performed uncharged work. Consequently the
   reported total omitted work and publication could follow a newly exhausted or
   cancelled context. Owner reports adding charges to inverse factors, each row's
   diagnostics, retained copies and a final publication checkpoint. **Resolved
   in final source review:** actual code charges inverse factors and each
   observation/leverage row, charges before retained-result construction, then
   checkpoints before return and includes that charge in diagnostics. Tests
   remain central-runner work.

3. **Sequential numerical boundary tests need to exercise their claim.** Existing
   complete Bernoulli-path tests are meaningful, but exact [0,1] quarters and
   [10,12] endpoints mostly avoid difficult normalization/physical conversion.
   Requested exact Fraction enclosure tests for actual noninteger binary64
   values, adjacent endpoints, subnormal widths, negative bounds and large
   same-sign offsets. Also requested validation/checkpoint before `step` clones
   a caller-owned configuration: its original ordering copied unrestricted label
   data before the validation that would reject it. **Configuration-copy ordering
   resolved:** the revised raw-state import validates before cloning, and import,
   batch replay and raw step checkpoint before validation/copying. Raw step also
   validates the new observation before replaying old history. **Arithmetic edge
   test additions source-reviewed:** the new BigRational test converts actual
   binary64 values exactly, independently computes weighted sums/penalties and
   running intersections, and compares every returned endpoint and both lower
   log-capital bounds. Eight families cover decimal-looking numbers, cancellation,
   negative bounds, large offset/narrow width, eight-subnormal-unit width, one-ULP
   width, tiny negative bounds and large finite width. One-subnormal denominator
   refusal and cancelled large-label import/step are explicit regressions.
   The consumer panel now has 26 authored cases; its Fraction scorer checks exact
   enclosure before a separate ULP/range-width tightness tolerance. None was
   executed by this review lane.

## Exact simplex: signs, original rows and bounded outcomes

Read `native/oracle-reasoning/src/lp_optimize.rs`, the existing exact certificate
checker, `lp_optimize_contract.rs` and the supplied resource-allocation consumer.
The new proposer handles unrestricted original variables as x=x+−x− with
nonnegative split coordinates, signed slack rows and artificial basics when the
original bound is negative. Phase one minimizes the sum of artificials. The
stored row transformation is relative to signed original equalities.

The multiplier conversion is correct: if pi is the transformed equality dual,
the original <= multiplier is y_i=−sign_i*pi_i. At a positive phase-one optimum
this gives y>=0, A^T y=0 and b^T y<0. At phase-two optimum it gives y>=0,
A^T y=−c and c^T x=−b^T y. With no positive leaving-column coefficient, the
constructed ray has entering coordinate one and basic coordinates equal to the
negative entering column; it is replayed as Ad<=0, c^T d<0 with a feasible base.
These match minimization rather than accidentally reversing a maximization dual.

Zero artificial basics are pivoted out, or their redundant rows removed, before
phase two. Bland entering/leaving rules are present. Crucially, success is not
decided by tableau metadata: the separate exact checker substitutes the returned
point/multipliers/ray into the original rows. Search and replay share the local
arithmetic allowance and host control. Pivot, bit, work and tableau-cell limits
produce unknown without a certificate. The feasibility-only operation remains
separate; this operation requires an objective.

The tests contain independent mathematical oracles, not just solver/checker
self-agreement: 2-D boundary-intersection enumeration, literal optimum 4 for the
small mixed-resource problem, the classical degenerate cycling instance, free
lineality, contradictory zero rows, fractional fixed boundaries, wrong primal
points, changed objectives and a ray lacking a feasible base. Original-row replay
alone would not test proposal completeness; the independent objective comparisons
and bounded unknown tests address different questions. The resource consumer
negates profit for minimization, checks all original rational certificates and
keeps fractional batch allocation distinct from integer planning or real-world
availability. No demonstrated false-answer defect found in the Rust proposer.

## GLM finite existence and separation

Read `glm.rs`, native contract tests and the Python exact replay/client. For
binomial rows the cone includes +x for any observed success and −x for any
observed failure. Strictly positive weights on **every** cone row, exact zero
weighted sum and an independent p-row basis exclude all nonconstant recession
directions. The recession certificate requires every signed dot >=0 and one >0.
Interior binomial rows contribute both signs and therefore force equality.
This is the right geometry for complete and quasi separation.

Poisson requires a different cone. Along a likelihood recession direction,
positive-count rows must have x*d=0; zero-count rows have x*d<=0, with one strict
negative dot for genuine improvement. The implemented finite certificate uses
strictly positive weights on zero-count rows and unrestricted weights on positive
count rows. Dotting its exact balance with a recession direction forces all zero
row dots to vanish; full design rank then forces d=0. Positive finite exposures
change offsets, but not these recession conditions. This justifies both the
otherwise surprising all-zero/no-intercept finite example x=(-1,+1), and the
nonexistent all-zero/intercept MLE. The positive-count subset need not itself
span the design; the authored (0,1,0) count example correctly tests this.

This reasoning agrees with the exponential-family recession boundary described
in [Geyer's notes, sections 6–7](https://www.stat.umn.edu/geyer/8054/notes/expfam.html).
The certificate proves existence and identifiability under the admitted family
support, not numerical convergence, likelihood optimality to a stated tolerance,
model correctness or large-sample calibration. Rust separately requires small
scaled score and Newton decrement before `finite_mle_converged`; a missing finite
witness is inconclusive, not separation. Separation requires an exact witness.

Exact replay uses the original f64 design interpreted as dyadic rationals, not
the rounded column-normalized design used by IRLS. Witness proposal repairs
approximate balance exactly, then checks positivity, balance and original rank.
Rounding the proposed separating vector cannot itself decide status. Requested
a one-ULP mutation test on a noninteger design to directly test this important
boundary; the author added it and this review inspected the actual test. The
existing saturated binomial coefficients/covariance and intercept
Poisson rate/information formulas are independent analytic truth cases; expanded
Bernoulli grouping and exposure rescaling add meaningful invariants. Wald
intervals remain model-based asymptotic conditional-mean intervals, not intervals
for a future count. Native support validation is sound in the reviewed source;
the independent Python support omission is recorded above.

## Sequential monitoring: optional stopping and arithmetic

The source implements the predictable Hoeffding construction, not repeated
fixed-time testing. With z in [0,1], predictable positive dyadic lambda_t,
S=sum(lambda*z), W=sum(lambda), V=sum(lambda²/8), each signed log-capital is
±(S−mW)−V. Inverting the two tests gives [(S−B−V)/W,(S+B+V)/W]. Its running
intersection is valid under a fixed common conditional mean. The chosen schedule
depends only on position, so it is predictable. It is deliberately less adaptive
than the paper's more elaborate methods.

The relevant primary statement is Proposition 1 and equations (8)–(12) of
[Waudby-Smith and Ramdas](https://rss.org.uk/RSS/media/File-library/Events/Discussion%20meetings/Estimating-means-of-bounded-random-variables-by-betting.pdf).
The code replaces ln(2/alpha) with ceil(log2(2/alpha)); since 2/alpha>1, this is a
conservative upper threshold. Repeated exact doubling computes it without a
transcendental rounding assumption. Each tail's alpha/2 allocation and arbitrary
stopping interpretation are consistent. This does not validate retrospectively
chosen bounds, edited history, selected outcomes or unallocated extra metrics.

Source inspection finds the interval operations conservative for admitted finite
inputs: width admission keeps its lower enclosure strictly positive, normalized
observations are clamped to known [0,1], division examines all four endpoint
quotients, sums expand outward, and physical-unit conversion expands again.
lambda²/8 is exact for the capped dyadic schedule. The interval intersection is
performed before physical conversion. Returned log-capital values are lower
bounds; they are not silently treated as exact e-values. No specific false
exclusion arithmetic counterexample found in this pass. The newly authored edge
tests described above directly exercise this handwritten arithmetic boundary;
their execution remains central-runner work.

The Rust finite-path test enumerates all 12-step Bernoulli paths at three means
and checks ever-exclusion against an independent integer capital oracle. This
tests stopping, not only fixed-time marginal intervals. The Python panel uses
Fraction arithmetic and rejects vacuous intervals when the reference narrows.
Neither establishes all-distribution coverage by testing; that rests on the
stated mathematical construction and premises. Replayable state is explicitly
unauthenticated data. The revised `SequentialMonitor` retains a private
accumulator with no `Deserialize`; imported raw history must replay. Its append
checks position, bounds and limits, charges work, computes a candidate, then
commits atomically. A live monitor and an expected position are not an
authenticated experiment registry or retry protocol. Snapshot export is
explicitly linear; it does not repeat the statistical computation.

## Outstanding evidence

The two concrete GLM findings and sequential import copy ordering are repaired
and source-verified. The requested sequential outward-arithmetic edge tests and
26-case Fraction panel have received final source review. No blocking source
finding or demonstrated mathematical false-answer defect remains. Central
executor runs focused contracts,
actual host consumers and their authored panels. All execution and panel scores
remain outstanding from this lane's perspective. Source review does not replace
the shipped specialists' own six-criterion completion metric.
