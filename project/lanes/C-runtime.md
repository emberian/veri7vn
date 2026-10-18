# Runtime continuation, 18 October 2026

In progress. This report covers the shared contract and coordination; the
dispatch, package and route reports contain their own execution receipts.

## What changed

`src/extract/families.json` now names explicit roles and unique specialist
ownership. Earth and finance add the missing 13 IDs: 144 specialist IDs are
owned by 21 specialist family entries, including variants. Fusion, guards,
word problems, document and relations have separate stage roles. Mathematics
has a stage adapter but is awaiting its final build before registration. These are
not interchangeable request protocols. A registry entry does not certify the
age or correctness of an executable.

`tools/runtime_contract.py` validates that registry and family-owned
`capabilities.json` files. Dispatch and organ packaging consume one acceptance
overlay: explicit answer kinds, in-domain refusal kinds and context-pattern
alternatives. Upstream manifests remain untouched. Unknown fields,
cross-family specialist claims, malformed regexes and duplicate ownership
are rejected. The overlay preserves the original manifest's other rules.

Capability evidence is labelled as a declaration. It is not turned into a
claim that a theorem was checked for this particular question. The answerer
contract now explains this and removes the obsolete revision-2 launcher as a
current runtime command.

## A concrete computation explanation

Finance is adding a packet from its actual discount-and-tax request and
kernel result. The shared Python consumer independently checks the rational
inputs, successive discount factors, tax multiplication, cents rounding and
the final stated amount. It retains the actual packet and records which
checks ran. An inconsistent packet produces a decisive withheld reply,
keeping its original operation kind so a manifest cannot turn the rejection
into accidental fallthrough.

This independent Python check is explicitly unverified. It checks typed
arithmetic and the final amount, not English recognition, the meaning of the
model, or every sentence in the response. The producer's HOL checker and its
theorem are finance's responsibility. No build or end-to-end packet success
is claimed here until that producer is rebuilt and tested.

## Checks so far

- `python3 -B tools/test_runtime_contract.py`: 11 tests pass. Tests cover
  ownership, schema and regex rejection, preserving original acceptance,
  changing packet inputs/results/output while leaving its `accepted` flag
  true, stacked discounts with a half-cent boundary, malformed present
  evidence, and absence of evidence.
- All 144 shipped specialist acceptance objects load with the current
  family overlays. This is a contract check, not a panel score.
- Dispatch reports held-out chemistry-v3 281/281 right and retail 51/51
  right, zero wrong/false yes, through the actual acceptance and arbitration
  path with reader/document/extra routes disabled. The six exam criteria
  remain incomplete for that run; see `C-runtime-dispatch.md`.
- Package reports a scoped warm-binary comparison of 620/620 right over
  chemistry-v3, retail and geography dev/held-out panels through manifest
  acceptance. It does not establish that those binaries match current
  concurrently changing source; see `C-runtime-package.md`.
- A relocated generated wrapper with a real fixture executable retains a
  consistent computation packet and turns a changed final value into a
  non-None withheld reply through Oracle7's actual loader. This tests the
  consumer boundary; the fixture is not the rebuilt finance producer.
- `python3 -B tools/dispatch/test_fusion_lifecycle.py`: three real-process
  checks pass. The fusion adapter reaps its own kernel after EOF, an uncaught
  request exception and SIGTERM, including a child that ignores termination.
  It never kills processes by a name pattern.

## Integration still open

Finish and check the finance packet through dispatch and relocated packages.
Finish current-source package receipts, including Linux computing and stores
asset relocation. Do not silently relabel historical Linux receipts as fresh.
The dispatcher now previews effectful warehouse requests, selects and guards
the preview, then commits the original request once using its private state.
Tests show that losing or guard-blocked previews do not write and that a
confirmed order commits once. A commit error is not retried. The unmodified
Oracle7 multi-organ host has no selection/commit callback; generated warehouse
wrappers therefore default to previews with truthful refusals of effects.
An explicit sequential owner can enable effects. Actual Combo tests cover
speculative fan-out, counterfactuals, repeat calls and concurrent calls without
state writes. Cooking remains usable independently.
New route adapters must preserve
the difference between not recognizing a question and refusing a recognized
request. Math's 93/93 recorded panel exposed signed/noninteger parsing defects
on additional probes; the corrected recognizer passed 23 further boundary
probes before initial registry activation. Source review then found unconditional
claims about a second check and a rendering defect in two-sided equations;
its owner is correcting those and rebuilding before final completion. The
math registry entry is held out of the stable core commit until that source
and its final build land together.

No Isabelle theorem was introduced by the shared Python contract. It is
untrusted runtime glue. No entire-fleet or live-head score is claimed here.
