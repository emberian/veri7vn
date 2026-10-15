# Sibling-source stress audit of the proposed core

2026-10-15. Design review, not a migration commitment or a completed algorithm audit.

The open native HOL architecture can express all six families inspected. I found
no reason to replace that architecture or make a universal capability datatype.
I did find consequential distinctions that should be settled before concrete
result, execution and artifact interfaces harden. The largest is that **the kind
and scope of a claim are independent of the assurance route used to accept it**.
A correctly computed forecast, classifier output or finite-model decision is a
useful accepted result without thereby proving the forecast, classification or
physical-world decision correct.

This review compares the current architecture, C01–C05 revision 0, and PO-01–10.
Those obligations remain open. Recommendations below are proposed requirements,
not new theorems or implementations. The six siblings remain compatibility
investigations and future family candidates, as specified in
[the coverage ledger](../coverage/README.md#related-distributions). Nothing here
adds their product implementations to the adopted Oracle7 migration scope.

## Evidence and limits

The repository revisions come from
[distribution-recheck.json](../../audit/results/distribution-recheck.json).
Selected small Python source files were read directly from those revisions;
no sibling code, models, evaluations, remote commands or builds were executed.
README performance and completion figures were not independently reproduced.
References below use pinned source, and distinguish implementation from comments
and README claims.

| Sibling | Pinned revision | Source examined for architectural stress |
|---|---|---|
| infrastructure | `74456ba7db9172f5822433308943647ecd67cdf0` | `agent.py`: forecasts, empirical gates, observation/retention loop, action planning and execution |
| trafficcop | `08a9f1e70b8e78d9078b4bd9f308b99b9800bcb0` | `trafficcop/model.py`: detectors, priorities, preconditions, choices, evidence-derived/default scores |
| deepspace | `3538060dbb55f287d060820f7b7c42fe3487632d` | `deepspace/fdir.py`, `selfmaint.py`: finite simulation, response ranking, rule generation/admission and state |
| vision | `271c1832780c25980253fd4816f8e812b064325c` | `vision/exemplar.py`, `screen.py`; declaration-level inspection of `chartqa.py` |
| artist | `df155c6a96626f9d3bc4146c9d4a516a0b8a2ba8` | `artist/core.py`: layout, sprite rendering, self-checks |
| chameleon | `cac0c3bccff793b63a0907e8ef3f679fa75f6a14` | `packages/core/chameleon_core/{metafold_service,verification_jobs,repository_artifact}.py`: durable orchestration, leases, completion and artifact binding |

The strongest stress cases are concrete behavior, not promotional labels such as
“verified binding”, “worst case”, or “self-verified”. Conversely, Chameleon's source
already makes useful distinctions between verified capture, ready package and
untested behavior. We should preserve that discipline rather than treating every
sibling as making the same kind of claim.

## Ranked findings and minimal changes

### 1. Settle claim scope independently of assurance before fixing C03 result types

**Priority: interface decision now.** C02 correctly says empirical tests and model
scores are not additional proof routes. C03 correctly requires the exact licensed
claim, but “Empirical candidates remain proposals ... never silently placed in
that variant” can be misread as excluding empirical-domain functionality from
`Accepted` altogether. That would unnecessarily prevent a formal implementation
from returning a classifier decision, observed test report, or computed forecast.

Concrete evidence:

- Trafficcop's `decide` filters some choices by named preconditions, then selects
  the first option serving the first detected obligation in a fixed priority
  order. With no receipts it assigns `0.9` to a selected choice, or `0.6` to its
  evidence-gathering fallback. The remainder is distributed over the other
  options, including those removed from the live candidate list. These are
  algorithm outputs, not established probabilities that the choice is correct.
  The result even labels its basis “no receipts: structural binding only”.
  [Implementation, lines 161–213](https://huggingface.co/psiloceyeben/oracle7-trafficcop/blob/08a9f1e70b8e78d9078b4bd9f308b99b9800bcb0/trafficcop/model.py#L161)
- Vision's exemplar method computes similarities, exponential vote weights,
  normalized vote shares and a top-two margin. That supports a claim about the
  declared classifier applied to the supplied vectors. It does not establish
  calibrated class probabilities or the real class of the image. This particular
  module returns the margin; despite its introductory comment, it does not itself
  apply an abstention threshold.
  [Implementation, lines 18–37](https://huggingface.co/psiloceyeben/oracle7-vision/blob/271c1832780c25980253fd4816f8e812b064325c/vision/exemplar.py#L18)
- Infrastructure admits forecast methods when at least 30 scored errors meet a
  mean-absolute-error threshold against its naive comparator. Proving this gate
  was computed correctly licenses a statement about that recorded cohort and
  gate. It does not prove future forecast accuracy.
  [Implementation, lines 414–434](https://huggingface.co/psiloceyeben/oracle7-infrastructure/blob/74456ba7db9172f5822433308943647ecd67cdf0/agent.py#L414)

**Minimal requirement:** keep C02's three routes; make the exact native claim
contract carry its modality and scope, with capability-specific types and
predicates rather than a mandatory closed enum of all kinds of knowledge. A
presentation view may distinguish source observation, computed prediction,
classifier decision, bounded-model result, measured test outcome and mathematical
consequence. Those labels themselves confer no authority. A proof or refined
execution must license the actual scoped claim. “The classifier returned cat”
must not silently become “the image contains a cat”; “these tests passed” must
not become unrestricted behavioral equivalence.

Expose the meaning of a numerical score: normalized vote share, historical rate,
heuristic confidence, utility, or a probability under a stated model. Missing
calibration is not repaired by putting the value into a field called probability.
Calibration, if claimed, has a population/model and evidence contract of its own.

**PO connection:** PO-01 must preserve the intended kind of question; PO-03 must
connect the actual computation to its scoped specification; PO-04 must prevent
claim strengthening by the emitter. PO-05 prevents a policy score from granting
acceptance. None requires an “empirical proof” route.

**Refuting check:** accept a correctly computed, explicitly scoped forecast through
an admitted implementation; reject a renderer or consumer that turns it into a
guaranteed future observation. Do the analogous test for the exemplar vote and an
observed test pass. Useful scoped results should remain expressible without
installing empirical observations as world axioms.

### 2. Give decisions explicit feasible sets, objectives and model scope

**Priority: semantics decision now; domain machinery only when adopted.**
Proof obligations, domain obligations, feasibility and preference are distinct.
Trafficcop's “obligations” are application priorities such as evidence and repair,
not Isabelle proof obligations. Its inspected decision function implements a
priority-and-order policy, not a general optimal planner. Its selected option can
be justified as that policy's output without claiming it maximizes an unstated
notion of user benefit.

DeepSpace provides a sharper stress case. `score_future` applies a response and
simulates a fixed horizon, accumulating weighted temperature, pointing, battery,
power-deficit and latent-fault penalties. `decide` forms candidates from a union
of responses for the active hypotheses, computes the maximum score across those
hypotheses, rounds to two decimals, and sorts by score and action cost. The result
receipt retains only the first five alternatives.
[Objective, lines 227–259](https://huggingface.co/psiloceyeben/oracle7-deepspace/blob/3538060dbb55f287d060820f7b7c42fe3487632d/deepspace/fdir.py#L227)
[Search, lines 290–313](https://huggingface.co/psiloceyeben/oracle7-deepspace/blob/3538060dbb55f287d060820f7b7c42fe3487632d/deepspace/fdir.py#L290)

`twin_from_telemetry` constructs a seeded, perturbed model for a hypothesis. The
finite maximum above is not a supremum over every physically possible parameter
value, telemetry error or future disturbance. “Worst case” must retain its actual
finite domain. A proof of finite-horizon simulation or finite-set optimality does
not alone establish a continuous-time safety invariant.
[Model construction, lines 163–204](https://huggingface.co/psiloceyeben/oracle7-deepspace/blob/3538060dbb55f287d060820f7b7c42fe3487632d/deepspace/fdir.py#L163)

There is also a concrete optimization-preservation concern. The learned-rule
branch returns its bound action and marks every fresh fact handled before the
slow branch's candidate/applicability logic. The slow branch marks an individual
fact handled only if the chosen response is admissible for that fact, or records
an expiring wait. The fast rule needs its own applicability and state-transition
obligations; it is not justified merely by resembling previous slow-path answers.
[Fast and slow branches, lines 283–313](https://huggingface.co/psiloceyeben/oracle7-deepspace/blob/3538060dbb55f287d060820f7b7c42fe3487632d/deepspace/fdir.py#L283)
The self-maintenance gate compares successful/harmful cases and twin-run counts
over a finite test suite. That is useful development evidence, not a universal
refinement proof for a learned rule.
[Gate, lines 85–100](https://huggingface.co/psiloceyeben/oracle7-deepspace/blob/3538060dbb55f287d060820f7b7c42fe3487632d/deepspace/selfmaint.py#L85)

**Minimal requirement:** a decision capability declares its feasible-set meaning,
objective/order, candidate/model domain, horizon, numerical semantics, tie policy
and fallback/abstention behavior. These belong in the native family contract,
with dependencies retained by C04. Distinguish “feasible recommendation”, “chosen
by this policy”, “best of evaluated candidates” and “optimal over the complete
declared domain”. A short explanatory list of alternatives is not the whole
certificate for the last claim. Search can remain heuristic while its selected
claim receives exact licensing.

Reserve room for sampled uncertainty, interval uncertainty, stochastic kernels
and hybrid dynamics as different future family specifications. Do not imply that
a single finite simulator handles them all. A continuous or hybrid safety claim
would additionally need a model relation, discretization/enclosure obligations,
disturbance assumptions and an actual runtime enforcement story. These are not
requirements to import HOL-Analysis or implement control theory now.

**PO connection:** PO-02 covers feasibility and context; PO-06 covers search
pruning and preserved observations; PO-07 covers fast-rule replacement, rounding
and numerical lowering; PO-08 covers admitted rule growth; PO-09 covers candidate
and objective dependencies; PO-10 covers handled/waiting state transitions.

**Refuting checks:** change a guard while keeping the learned rule's fact-kind
signature; introduce a previously absent better candidate; change only a score
tie or rounding boundary. None may preserve a claim stronger than the resulting
contract permits. Reject promotion of a sampled-model maximum to a robust
physical-world bound.

### 3. Represent output artifacts and property-specific lifecycle claims

**Priority: interface decision now.** C01 describes package files and C03 permits
capability-specific result codecs, but neither by itself determines the lifetime
and authority of a newly generated image, captured site or executable bundle.
The core should not assume an answer is a small scalar or term serialization.

Artist renders cited source sprites through recoloring, resizing and composition,
then checks a mixture of metadata and pixels. Counts are computed from the
`placed` records' class fields. Relations use placement-box centers. Color checks
inspect image pixels under masks supplied by those records. The comment claiming
to remeasure every clause from rendered pixels overstates what this function
actually checks.
[Render, lines 188–206](https://huggingface.co/psiloceyeben/oracle7-artist/blob/df155c6a96626f9d3bc4146c9d4a516a0b8a2ba8/artist/core.py#L188)
[Checks, lines 230–250](https://huggingface.co/psiloceyeben/oracle7-artist/blob/df155c6a96626f9d3bc4146c9d4a516a0b8a2ba8/artist/core.py#L230)
Its README explicitly reports a gap between its own checks and an independent
perceptual judge. That is a reported evaluation finding, not one rerun here.
[README](https://huggingface.co/psiloceyeben/oracle7-artist/blob/df155c6a96626f9d3bc4146c9d4a516a0b8a2ba8/README.md)

Chameleon already supplies a useful counterexample to a single `verified` bit.
Repository capture refuses evidence purporting to establish tested behavior;
its manifest distinguishes capture `VERIFIED`, package `READY`, and behavior
`UNTESTED`, and states what was not reconstructed. Its completion path checks
source/contract/overlay/dependency bindings and the actual downloaded bundle hash.
[Capture checks, lines 15–49](https://huggingface.co/psiloceyeben/oracle7-chameleon/blob/cac0c3bccff793b63a0907e8ef3f679fa75f6a14/packages/core/chameleon_core/repository_artifact.py#L15)
[Lifecycle, lines 115–133](https://huggingface.co/psiloceyeben/oracle7-chameleon/blob/cac0c3bccff793b63a0907e8ef3f679fa75f6a14/packages/core/chameleon_core/repository_artifact.py#L115)
[Completion binding, lines 425–440](https://huggingface.co/psiloceyeben/oracle7-chameleon/blob/cac0c3bccff793b63a0907e8ef3f679fa75f6a14/packages/core/chameleon_core/metafold_service.py#L425)
Those are implemented checks, not a formal proof of unrestricted application
behavior. A passing finite behavior contract retains its test scope.

**Minimal requirement:** allow typed artifact results whose identity is bound to
the actual bytes or declared stream, format/representation and generating
operation. Specify staged publication, ownership/access, dependency closure,
retention and unavailable-content behavior. A mutable pathname or author-supplied
digest is not by itself an accepted identity. Large bodies need not be copied
through theorem messages or JSON.

Keep property claims separate: source acquisition, construction/layout, measured
pixel property, perceptual classification, packaging completeness and tested
behavior are different predicates. A construction certificate must bind the
render trace and inputs to the output bytes. A hash preserves identity under its
stated assumptions; it does not prove the corresponding renderer correct or the
depicted object recognizable. Consumers must request the properties they need.

**PO connection:** PO-03 links artifact construction to executed operations;
PO-04 licenses property claims; PO-07 binds transformed/compiled artifacts to
their definitions; PO-09 tracks closure and reuse; PO-10 governs publication and
resource lifetime.

**Refuting checks:** replace an image while retaining its placement record;
replace a packaged dependency without changing the top-level source; substitute
an old bundle at a mutable URL; render “behavior verified” for capture-only
evidence. Each must fail the relevant claim association.

### 4. Make stream/window/retention semantics explicit without rebuilding a theory per tick

**Priority: reserve the semantic seam now; implement with an adopted stream family.**
C04 already correctly distinguishes immutable generations from mutable observed
state and wall, monotonic and event time. It already allows observation sequences
rather than pretending independent reads form an atomic snapshot. This finding
refines that foundation, not a claim that temporal state was forgotten.

Infrastructure's main loop repeatedly senses sources, stores observations and
events, scores due forecasts and performs maintenance. Its retention policy
reduces old raw samples to ten-minute means, deletes raw and aggregate data by age,
and may delete additional oldest data when a storage cap is exceeded.
[Loop, lines 537–568](https://huggingface.co/psiloceyeben/oracle7-infrastructure/blob/74456ba7db9172f5822433308943647ecd67cdf0/agent.py#L537)
[Retention, lines 519–533](https://huggingface.co/psiloceyeben/oracle7-infrastructure/blob/74456ba7db9172f5822433308943647ecd67cdf0/agent.py#L519)
A missing historical observation after this process is not evidence that the
event did not occur. Ten-minute means cannot answer an exact historical maximum
query. A long-lived monitor is also not simply a finite request that inevitably
ends as a timeout.

**Minimal requirement:** let a long-lived computation have an execution lifetime
and produce separately scoped, accepted updates. A family using streams declares
ordering, window boundaries, event/processing time, late-arrival policy and
coverage/completeness conditions. If a watermark is used, its meaning must come
from the source protocol or an explicit assumption. Retention/downsampling is a
state transformation with a stated observation relation, not an invisible cache
optimization.

Keep code/theory generation separate from successive data/observation versions;
C04's whole-snapshot baseline need not mean copying the whole store or rebuilding
an Isabelle theory each tick. Logical persistence, historical replayability and
physical availability of old evidence are distinct. Deleting data must not make
a prior scoped result claim current, and a retained digest does not make deleted
data replayable.

**PO connection:** PO-02 covers temporal applicability, PO-03 stateful operation
semantics, PO-09 incremental/recompute agreement and coverage-aware reuse, and
PO-10 lifetime, retention and cancellation.

**Refuting checks:** deliver a late sample across a window boundary; downsample
then request a maximum; expire a waited-on fault and change its context; exhaust
storage during a running monitor. Results must preserve their declared coverage,
time and observation semantics.

### 5. Separate action authorization, external outcome and later observation

**Priority: make the reserved C05 boundary explicit before implementing effects.**
C05 already requires current precondition checks at commit and explicitly reserves
retry, idempotency, partial failure and rollback semantics. The sibling evidence
shows why these cannot be represented solely by a request's `Failed` or `Cancelled`
terminal status.

Infrastructure's inspected `execute` path checks the stored approval status, runs
the command, and marks the action executed without checking the subprocess return
code or re-evaluating the textual precondition in that path. A later verifier
looks for selected observed effects. These are several distinct events: approved,
dispatched, command returned, postcondition observed and effect attributed.
Observation after a command does not by itself prove the command caused it.
[Execution, lines 678–693](https://huggingface.co/psiloceyeben/oracle7-infrastructure/blob/74456ba7db9172f5822433308943647ecd67cdf0/agent.py#L678)
[Effect verification, lines 486–507](https://huggingface.co/psiloceyeben/oracle7-infrastructure/blob/74456ba7db9172f5822433308943647ecd67cdf0/agent.py#L486)
The README describes broader autonomy gates; this source finding concerns the
inspected execution path and does not establish every deployment's policy.

Chameleon's orchestration records pending intent before dispatch and uses stable
step identities. Its verification jobs use claims with tokens and deadlines;
expired running claims become interrupted, and stale completion is rejected.
Dependency and completion binding check the matching job and content identities.
These are useful operational precedents, not a proof that external actions are
exactly once or that timing out stops a remote process.
[Intent and dispatch, lines 96–131](https://huggingface.co/psiloceyeben/oracle7-chameleon/blob/cac0c3bccff793b63a0907e8ef3f679fa75f6a14/packages/core/chameleon_core/metafold_service.py#L96)
[Claims, lines 218–249](https://huggingface.co/psiloceyeben/oracle7-chameleon/blob/cac0c3bccff793b63a0907e8ef3f679fa75f6a14/packages/core/chameleon_core/verification_jobs.py#L218)
[Completion, lines 301–330](https://huggingface.co/psiloceyeben/oracle7-chameleon/blob/cac0c3bccff793b63a0907e8ef3f679fa75f6a14/packages/core/chameleon_core/verification_jobs.py#L301)

**Minimal requirement:** separate request lifecycle from effect lifecycle, with
room for an unknown external outcome. An executor contract specifies durable
intent, idempotency/fencing where available, authority and precondition checks,
dispatch acknowledgement, result observation, reconciliation and any permitted
compensation. Do not promise exactly-once effects generically. Cancellation must
prevent new authority or accepted-answer publication without deleting evidence
of already dispatched effects; a trusted supervisor may still need to record a
late observed outcome for reconciliation. That record is not a late worker
granting itself permission to commit.

**PO connection:** PO-03 includes actual failure/effect behavior; PO-05 preserves
the proposal/authority separation; PO-09 tracks state/time assumptions; PO-10
must cover executor crash/restart and visibility, not only a pure transition
model. This is largely a concrete elaboration of existing C05 requirements.

**Refuting checks:** crash after dispatch but before acknowledgement; let a lease
expire while the worker is alive; cancel after an external action took effect;
replay a stale completion after a new job owns the work. The system must preserve
the actual known/unknown outcome without granting unauthorized new effects.

### 6. Preserve arrays, numerical relations and geometry as first-class family semantics

**Priority: avoid a representation trap now; optimize adopted kernels later.**
The architecture already admits specialized languages and representations. Keep
that promise when choosing the first implementation types: a scalar arithmetic
DAG or untyped native-call escape hatch is not a sufficient execution model for
the sibling numeric and image families.

Vision's neighbour search performs a batched matrix product, partitions and sorts
top candidates, and returns float32 similarity arrays; weighted voting uses
exponentiation and indexed accumulation. Exact results can depend on ties,
rounding, accumulation order and the input/store representation. An approximate
nearest-neighbour index would change the contract unless its permitted error or
retrieval guarantee is stated and checked.
[Numeric implementation, lines 12–37](https://huggingface.co/psiloceyeben/oracle7-vision/blob/271c1832780c25980253fd4816f8e812b064325c/vision/exemplar.py#L12)
Artist combines coordinates, masks, color conversion, resizing and composition;
construction claims must use the actual representation and transformation rules.
Vision's screen grounder additionally produces a click point from recognized
tokens. Its word-level threshold is not a global confidence guarantee: the
inspected function can return a positive partial match. A point proposed for an
image version is not authority to click a changed screen.
[Grounding, lines 89–119](https://huggingface.co/psiloceyeben/oracle7-vision/blob/271c1832780c25980253fd4816f8e812b064325c/vision/screen.py#L89)

**Minimal requirement:** family representation relations must cover typed bulk
data, shape, numeric domain and relevant layout/encoding conventions. Image and
geometry codecs must include coordinate frame, dimensions and transformation
history where needed. An optimized attachment states whether it preserves exact
bits, a mathematical value, a certified error enclosure, a ranking, or another
explicit observation relation. Those are different contracts. Large buffers and
fast array kernels should not require scalar theorem traffic per element, but
their admitted execution bridge cannot just assume the kernel implements its
reference definition.

**PO connection:** PO-02 covers shapes and domains; PO-03 representation and
primitive refinement; PO-07 backend/numeric transformations; PO-09 input/store
and coordinate-frame identities; PO-10 resource bounds and any resulting action.

**Refuting checks:** a tie straddling the top-k boundary; different floating-point
accumulation order that flips a classification; stale screen dimensions after
OCR; a substituted image buffer with the old certificate. Choose the appropriate
observation relation before declaring the optimization correct.

## Implications for the current architecture

The existing ten obligations cover these families without adding an eleventh
generic obligation. Their concrete children must mention the relevant behaviors;
an opaque native adapter plus a scoped disclaimer does not discharge PO-03 or
PO-07 for an adopted capability. The shared core should offer composition and
authority boundaries while native family developments supply the meaning of
probability, utility, dynamics, geometry and artifact properties.

The minimal preimplementation decisions are therefore:

1. Clarify C03 so useful scoped computed/observed results can be accepted through
   C02, while empirical success never grants a new proof route or stronger claim.
2. Reserve explicit family contracts for decision objectives/model scope and
   typed bulk/artifact results; do not freeze all results into scalar facts.
3. Make stream lifetime and effect lifetime distinct from a single request's
   terminal state, retaining C04's environment/observation separation and C05's
   authoritative executor boundary.
4. Add the refuting cases above to the owning obligations when those interfaces
   become concrete. These are contract-level tests, not a request to implement
   all six siblings now.

No evidence from these sources establishes a ready-made comprehensive verified
system to import. They do supply valuable existing capability patterns, clear
examples of what must not be conflated, and several good operational mechanisms
to preserve in an author-friendly successor.
