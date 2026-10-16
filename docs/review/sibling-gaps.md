# Sibling-source stress audit of the proposed core

The six siblings are compatibility/design investigations under D18, not additional committed migrations. Selected pinned source was inspected; no sibling models, evaluations, commands or builds were run. Source behavior and README performance/completion claims are separate evidence.

## Evidence and limits

| Sibling / pinned revision | Inspected source and architectural pressure |
|---|---|
| infrastructure `74456ba7db9172f5822433308943647ecd67cdf0` | `agent.py`: forecast scoring, observations, retention, planning/execution |
| trafficcop `08a9f1e70b8e78d9078b4bd9f308b99b9800bcb0` | `trafficcop/model.py`: guards, priorities, evidence/default scores |
| deepspace `3538060dbb55f287d060820f7b7c42fe3487632d` | `deepspace/fdir.py`, `selfmaint.py`: finite simulation/response choice, rule growth |
| chameleon `cac0c3bccff793b63a0907e8ef3f679fa75f6a14` | `packages/core/chameleon_core/{metafold_service,verification_jobs,repository_artifact}.py`: intent, leases, bundle binding |
| vision `271c1832780c25980253fd4816f8e812b064325c` | `vision/exemplar.py`, `screen.py`, declaration-level `chartqa.py`: scores/recognition |
| artist `df155c6a96626f9d3bc4146c9d4a516a0b8a2ba8` | `artist/core.py`: placement/rendering and property-specific checks |

[Distribution inventory](../../audit/results/distribution-recheck.json) binds revisions. The [coverage ledger](../coverage/README.md) controls scope expansion.

## Ranked findings and minimal changes

### 1. Settle claim scope independently of assurance before fixing C03 result types

Trafficcop `model.py:161–213` chooses under preconditions/priorities and assigns default 0.9/0.6 scores without receipts, including score mass for excluded alternatives. Vision `exemplar.py:18–37` computes normalized similarity votes/margin, not calibrated class probabilities; that module does not enforce its advertised abstention threshold. Infrastructure `agent.py:414–434` admits forecasts against a recorded error cohort, not future-world accuracy.

C02's three assurance routes stay unchanged. C03 must license the precise classifier/forecast/test/model claim without strengthening it to real-world truth. Explicit score meaning—vote share, historical rate, heuristic, utility or model probability—survives display. Test that accepted forecast computation cannot render a guaranteed future observation. PO-01/03/04/05.

### 2. Give decisions explicit feasible sets, objectives and model scope

Trafficcop's application “obligations” are priorities, not proof obligations. DeepSpace ranks responses through finite-horizon simulation; seeded scenarios and candidate responses do not cover every physical possibility. Rule growth must retain model, guards, objective, candidate domain, horizon, numerical/tie policy and evidence dependencies.

Distinguish feasible choice, finite-set optimum, robust bound and empirical policy. A positive witness cannot establish absence of better candidates. Refute reuse by changing a guard, adding a better candidate or crossing a rounding/tie boundary. PO-02/03/04/06/08/09/10.

### 3. Represent output artifacts and property-specific lifecycle claims

Artist `core.py:188–206,230–250` renders sprites; counts use placement records, relations use box centers, colors inspect selected pixels. These are different predicates, not universal pixel/perceptual verification. Chameleon `repository_artifact.py:15–49,115–133` distinguishes capture VERIFIED, package READY and behavior UNTESTED; completion checks actual dependency/bundle identities.

Bind each artifact's bytes/stream, format, generating operation, inputs and claimed property to staged publication/access/retention. A hash preserves identity, not renderer correctness or recognizability. Test image replacement with unchanged placement records, dependency substitution and capture-only evidence labeled behavior-verified. PO-03/04/07/09/10; TB-05.

### 4. Make stream/window/retention semantics explicit without rebuilding a theory per tick

Infrastructure `agent.py:519–568` downsamples old samples into ten-minute means and prunes by age/capacity. Missing retained history is not absence of an event; means cannot recover an exact maximum. Long-lived jobs produce scoped updates under an owned execution lifetime.

Declare event/processing clocks, ordering, windows, late arrivals, source coverage/watermarks and retention observation relations. Keep code generations separate from observation versions. Test late-window events, maximum after downsampling, expired faults and storage pressure. Digest retention cannot make erased evidence replayable. PO-02/03/09/10.

### 5. Separate action authorization, external outcome and later observation

Infrastructure `agent.py:678–693` checks stored approval and runs a command without checking its return code or reevaluating the textual precondition there; later effect observation is separate and does not prove causation. Chameleon records intent and stable step identities, uses expiring claims and rejects stale completion.

Use durable intent, current authority, coupled claim/start, actual target/attempt and explicit reconciliation/idempotency contracts. Approved, handed off, returned, observed and attributed are distinct states. Crash/timeout can leave an unknown external outcome. Test late completion after lease expiry, revocation before handoff and retry without executor-supported reconciliation. PO-10; TB-03/04.

### 6. Preserve arrays, numerical relations and geometry as first-class family semantics

Vision/Artist require arrays, coordinate systems, masks and transforms; forecasts and simulations need explicit numerical/error relations. Layout metadata, rendered pixels, OCR output and perceptual meaning require separate bridges. Preserve shape/order/frame, bounds, approximation and backend identity through codecs and composition. Test a correct metadata result attached to wrong pixels and a transform that changes the claimed geometric property. PO-02/03/04/07; TB-02/05.

## Implications for the current architecture

Open native profiles plus finite typed kernels can express these families without a universal value type. Adopt the claim/artifact/effect distinctions in core contracts now. A future sibling migration needs its own pinned inventory, scope, native meanings/bridges, executable consumers and performance evidence; this audit supplies none of those completion claims.
