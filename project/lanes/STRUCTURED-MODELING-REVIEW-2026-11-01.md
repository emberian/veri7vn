# Structured modeling source review

Reviewer: Astra modeling review lane. Base: `ab82d0b`; reviewed the shared-tree
implementation supplied by `sol_structured_modeling`. No blocking source finding
remains in the reviewed ownership and delivery path. This is a source review,
not an execution receipt or specialist admission.

**Specialist panel numbers: none from this review.** No builds, tests, host
requests or original examiner runs were performed. The original negative
admission and its defective composed-control gold remain as recorded in
[MODELING-ADMISSION-2026-10-31.md](MODELING-ADMISSION-2026-10-31.md).

## What was checked

- `modeling.rs` takes only the exact `Model supplied data: ` prefix. Both service
  turn paths call it before reader, organ and Engine dispatch. Malformed owned
  input, unsupported operation, unavailable provider and numerical refusal
  terminate there; none permits a generic mean or documentation fallback.
- The byte limit precedes JSON parsing. Strict JSON decoding rejects duplicate
  keys. Complete rows, bounded predictions, nonblank assumptions, units,
  sampling/grouping declarations, family-specific support and exposure are
  required. The additional declaration-schema check protects optional solver,
  confidence and precision fields before `Pure::invoke_checked`, whose caller
  contract requires that check.
- Computation uses the existing typed statistics provider and the query's shared
  execution context. GLM results retain their diagnostics and exact certificates;
  the existing typed checker checks the supplied input and replays certificates.
  Calibration delivery additionally binds operation, direction, uncertainty,
  assumptions, requested values and units, matching the Python client's checks.
  Numeric request binding uses the provider's floating-point values rather than
  requiring identical JSON number spelling.
- The outer ordinary and covered query scopes retain `CheckedPureReply` until
  bounded encoding and journal completion finish. The intermediate `Value` is
  delivery data; it is not decoded back into a domain result. This preserves
  the typed owner's lifetime while keeping the existing query wire contract.
- Following root's architectural correction, the final reply extends that
  checked projection in place. It carries the numerical result once, preserves
  provider authority, classification, runtime identity and refusal reason, and
  adds the separate `modeling_reason` plus a short human response. There is no
  nested `checked_reply` copy and no JSON result embedded in response text.
  The unchanged service callbacks still retain the typed owner across encoding
  and commit and decide context transitions from the preserved `status`.
- Covered native answers clear the old anchor and reconcile selection because
  a model result has no admitted scalar/entity anchor. Semantic refusals retain
  the old context. Encoding precedes core commit, so an oversized result cannot
  publish the candidate's cleared context. Both existing retry journals remain
  on the delivery path.
- `readonly-v1` explicitly refuses the unsupported context transition without
  launching an Engine. Ordinary conversations with an existing Engine binding
  likewise refuse before computing; fresh ordinary conversations can answer,
  with discovery explicitly saying the result is not projected into later
  Engine context.
- Shared deadline, cancellation and work exhaustion remain operational errors.
  Result-less numerical/resource/check failures are not counted as completed
  semantic refusals. Invalid-input details and typed model refusals remain
  semantic outcomes. Missing statistics is HTTP503, without generic fallback.
  Discovery names the prefix, operations, earlier route order and context limits.

Review feedback fixed during authoring: check bytes before parsing; apply the
existing declaration schema to optional fields (negative solver iterations were
a concrete counterexample); preserve calibration request binding; distinguish
deadline/cancellation/budget failures. These were reviewed in the resulting
source, not merely accepted from the author's report.

No theorem statements changed. The consumer is the host's `/query` endpoint;
this connects the already available `/invoke` computations to explicit textual
ownership. It proves neither statistical assumptions nor a new formal theorem.

## Fresh qualification source

Also read `tools/usage/specialist/modeling/composed/panel.json` and `qualify.py`
at root's request. This tests the new owner composition, not a replacement run
of the spent original heldout admission. Standalone exclusion controls are
separate from composed identity and arithmetic controls. The identity control
requires core provenance; the ordinary mean has independent gold 7.

The mathematical gold inspected is sound: exact calibration lines in each
split; symmetric four-row residuals giving mean interval radii `1/sqrt(3)` and
`2/sqrt(3)` at confidence 0.5 with two residual degrees of freedom; observation
interval radii `sqrt(5/3)` and twice that; aggregate binomial probabilities
`2/3` and `1/2`; Poisson rates 2 and 1.5; and two-parameter binomial predictions
equal to each supplied group's observed fraction. The harness checks the new
owner's actual nested result fields and independently replays GLM certificates
through the Python rational checker. It checks status, quantity, units and
request binding rather than treating every refusal as correct.

Two nonblocking fixture improvements were applied and checked before freeze:
Poisson-specific assumptions replace inherited binomial wording, and the
byte-limit case pads otherwise valid JSON with whitespace so it cannot pass
solely by triggering the separate label-length refusal. Execution and numerical
qualification remain the central runner's work.

The follow-up single-result scorer reads `reply.result` directly. It checks
provider refusal reasons (`calibration_unavailable` or the expected separation
status), retains the independent analytic and rational-certificate checks, and
checks answered classification/runtime identity separately from the added
conversational reason. Questions and mathematical gold were unchanged by this
wire-shape correction. No blocking source issue remains in that correction.

## Enclosing admission and replay follow-up

The native conversation request-byte cap applies to the entire encoded query
before the modeling owner runs. A larger host HTTP cap does not override it.
The oversized fixture can therefore receive an uncommitted HTTP413 rather than
the owner's HTTP200 invalid-input refusal. Keeping the existing admission and
identity policy is correct; a smaller hashed replacement identity solely to
force this test through admission would introduce an unnecessary new policy.

The corrected runner recognizes that boundary only for the named oversized
invalid fixture, with an explicit release limit and an actual encoded request
larger than that limit. It requires `conversation_limit`, `outcome:error`,
`state_may_have_changed:false`, and no reply/result. These cases are counted as
transport boundaries separately from semantic correctness. Identical retries
of them are described as potentially recomputed errors, not durable replay.

Acknowledged-only restart replay validates all original records before making
HTTP calls. Only previously correct HTTP200 completed replies are replayed;
only the checked uncommitted size-boundary failures may be excluded. The new
receipt records the original receipt digest and the exclusions' prior status,
and cannot overwrite its source receipt. This preserves the original 51/53
qualification record rather than turning it retroactively into 53/53.

The ordinary-mean prose fallback now accepts sentence punctuation while requiring
a complete numeric response or explicit mean claims. Every captured mean claim
must match gold; incidental sums cannot supply the answer. A present structured
value must itself be correct and cannot be overridden by prose. Full-token
checking rejects continuations such as `70`, `7.5`, `7e1`, `7/2` and `7,000`.
The final frozen version captures the whole nonwhitespace token and permits
at most one trailing sentence punctuation mark (`.`, `,`, `;`, `!`, or `?`).
These checks address the concrete false positives found during source review.
The final boundary/replay and mean-token changes are source-cleared.

Also inspected the later borrowed-declaration accessor: it selects the same
configured profile and operation declaration without cloning all declarations.
The opaque-binding test repair now creates a dispatched conversation before
binding it and asserts that the binding exists. Neither change weakens the
production ownership policy. No execution was performed by this reviewer.

## Reviewed source identity

Production-source SHA256 at review close:

- `native/oracle-host/src/modeling.rs`:
  `59c2ad92f8b2b1c8090c3e7667b2a859b744d3d570d54c490701e358f5e16ef2`
- `native/oracle-host/src/pure.rs`:
  `3750cf0a805b51d189727499f66b924eaf3614b35f2e6d3a91b5376c6766d668`
- `native/oracle-host/src/service.rs`:
  `0f45c1ef4f4b7a7873e2399c7257502f31f2e1ba0e03327e02c88dfe2d00d428`
- Fresh qualification scorer `tools/usage/specialist/modeling/composed/qualify.py`:
  `d06cdf79ed30b4d74b7b7177b8d6274ceb87cbd54aadca078ad7a3e6b818ed60`

Authored tests were read, not run. This lane changed only this review report.
