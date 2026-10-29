# Native candidate agreement and narrowing guards

Owner: native_arbitration, 28 October 2026. Specialist-panel numbers: **none**.
There are **no new theorem statements or proof claims**. This is handwritten
Rust that root must integrate and qualify.

Changed files:

- `native/oracle-core/src/admission.rs`
- `native/oracle-core/tests/admission_contract.rs`
- `project/lanes/NA-admission.md`

The module accepts an explicitly ordered group of route observations. It keeps
the first displayed answer only after every answering member agrees. Different
answers remain inspectable and produce disagreement. A recognized refusal,
including a recognized ambiguous reading, ends the group. A missing organ,
failed organ, cancelled organ or exhausted organ budget is an operational
observation, separate from a semantic refusal. Required failures block an
answer; optional failures remain in the record and allow the other answering
organs to agree. With no answers, failures remain an unavailable result.

Only `NoReading` allows another group to try. Disagreement, accepted refusal,
guard veto and unavailable results do not authorize an unchecked fallback.
When the host already has a parent reply, retaining that reply on optional
organ failure is a separate decision from asking another answerer.

Evidence classes and references are claims supplied by producers. They do not
rank candidates, establish coverage, or prove a response. Identical claims
within one response are deduplicated, with a duplicate count retained. Input
bounds count duplicates before removal. Conflicting replies cannot win by
repeating references or claiming a stronger evidence class.

Text keys follow w574's trim-and-lowercase rule. Exact numeric keys use the
value lane's `ExactNumber` and an explicit canonical unit identity. They never
pass through a float. Optional relative agreement implements Fusion's pairwise
formula, `abs(a-b) <= tolerance * max(abs(a), abs(b), floor)`, with exact
rationals, `0 <= tolerance < 1`, and a nonnegative floor. It scans extrema once
rather than comparing every pair. The test includes the 100 / 100.4 / 100.8
anchor-order counterexample and checks the extrema rule against an independent
pairwise scan across negative, positive and floor-dominated examples.

Guards run after agreement and see a shared reference to the selected answer.
They can keep, veto or report unavailability; they cannot write another
answer, alter its display, delete a conflicting candidate, or trigger a second
arbitration. A veto stops later guards. Non-answers pass through without any
guard call. The built-in dimension guard checks typed dimensions. Its explicit
unknown-dimension policy either passes an unknown reading or withholds it; it
does not invent a dimension from an unread unit power. Native guard code must
cooperate with `Budget`; this is not a sandbox for arbitrary callbacks.

The input pass bounds routes, bytes and evidence claims and checks the shared
budget. Every registered route must report exactly once, in registered order.
Missing, extra, duplicate and reordered reports cannot yield a partial answer.
Guard identities, counts and result text share the decision's byte bound.
Numeric accounting includes the retained source literal as well as its rational
payload. Relative mode rechecks every numeric literal against its scalar bounds,
including an interior value that never becomes a minimum or maximum.

## Source semantics and consumer plan

The read-only source inspected was
`var/runtime-architecture-20261028/source/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/`,
in particular w480, w550, w572, w573, w574 and `runtime_refusal_guard.py`.
Also read `src/extract/fusion/Fusion.thy`, its README,
`src/isabelle/routing/Fold_Cascade.thy`,
`src/isabelle/specialists/Arbitration.thy`, `tools/dispatch/dispatch.py` and
`docs/contracts/answerer.md`.

Root owns `lib.rs`, Cargo changes and the actual consumer wiring. The API is
`admission::arbitrate(policy, ordered_reports, budget)`, then
`admission::apply_guards(decision, guards, budget)`. `AdmissionDecision` exposes
read-only outcome, report, answer and guard-record accessors.

`AgreementMode::Relative` holds one boxed `RelativeAgreement` configuration.
The allocation happens when a reusable policy is constructed; reports and
numeric values are not individually boxed by admission. Exact policies therefore
do not carry the unused relative policy's two rational values and scalar limits.

1. **w574's air/physics/facts group is the direct consumer.** Keep w572's parent
   eligibility gate and the request recognition/formatting in the adapter.
   Construct the ordered optional route list `air`, `physics`, `facts`. Preserve
   `_one`'s question and reading checks. Use the organ's `key` or `answer` as a
   text key and its already formatted response/path as the candidate. Map
   absent/loading organs and exceptions to operational observations. Return the
   selected native index or format the full disagreement record, without
   assigning evidence-based priority. This is the all-answer agreement seam;
   the Rust code does not migrate the parent language interpreter or all organs.
2. **Accepted refusals need explicit classification.** w574's `_one` drops all
   non-answers; this module does not infer which of those were deliberate. The
   adapter must retain an established parent terminal refusal and use
   `RouteOutcome::Refusal` only after the producer's operation/domain acceptance
   rule accepts that refusal. `taken = false` is unread. An unavailable check is
   never an invalid premise. w573's multiple candidate names alone do not mean
   a semantic ambiguity; its connective relation test remains a separate guard.
3. **Post-selection native guards can consume the same decision.** The
   dimension guard's input must come from complete typed readings, preserving
   w574's unread-power exception. Other validated native checkers can implement
   `NarrowingGuard`. `Fold_Cascade`'s preservation properties motivated the API;
   no theorem connects this Rust implementation to that HOL model.
4. **Fusion may use relative agreement after its own search completes.** The
   caller must first establish the complete shallowest plan set, dimensions and
   operation validity. This module does not search, check use of givens, prove
   completeness, or infer a floor from response prose. It intentionally uses
   pairwise agreement, not Oracle's order-sensitive anchor comparison.
5. **Do not replace the specialist arbitration binary with this group rule.**
   `Dispatcher.arbitrate` and `Arbitration.thy` rank by dependence, assumptions,
   wording and context and have their own checked-refusal tie behavior. That is
   a different operation, not evidence-class priority. Likewise w480's
   dialogue/math/relation replacement conditions require named route policies
   with their actual preconditions. No historical fold number or route-family
   string has been turned into a magic integer priority here.

The integrated native reader separately compares exact rendered answer strings
with a `BTreeSet`, preserving its own empty-answer and ambiguity semantics. It
should retain that rule: admission's w574 text comparison trims and lowercases
keys, which would change the reader's meaning. A new `agree_exact` helper that
merely wraps equality would not integrate admission's route/refusal/guard
contract and would add indirection without removing an algorithm. The actual
w574 route-group consumer remains unported at this checkpoint.

## Checks and remaining work

Ran `rustfmt --edition 2021 native/oracle-core/src/admission.rs
native/oracle-core/tests/admission_contract.rs`: exit 0. This confirms parsing
for formatting, not compilation. Inspected the resulting source and added 15
contract tests covering disagreement, refusal, ambiguity, operational failures,
duplicates, typed values, relative agreement, guards and bounds.

Per root's resource instruction, **no build or test was run by this lane**.
Root reported the centralized run passed all 15 `admission_contract` tests.
Root's subsequent Clippy check identified the large agreement enum; this lane
boxed the once-per-policy relative configuration, without running more checks.
Root must compile and qualify that layout change in the centralized batch. The
new module is not yet a migration of the 403-class runtime chain. Shipping
consumer wiring, a stable serialized adapter and specialist-panel qualification
remain root integration work. These tests cannot establish English parsing,
source truth, coverage, or formal correctness.
