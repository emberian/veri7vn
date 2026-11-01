# Runtime continuation, 18 October 2026

In progress. This report covers the shared contract and coordination; the
dispatch, package and route reports contain their own execution receipts.

## What changed

`src/extract/families.json` now names explicit roles and unique specialist
ownership. Earth and finance add the missing 13 IDs: 144 specialist IDs are
owned by 21 specialist family entries, including variants. Fusion, guards,
word problems, document and relations have separate stage roles. Mathematics
now has a registered stage adapter and a freshly checked executable. These are
not interchangeable request protocols. A registry entry does not certify the
age or correctness of an executable.

`tools/runtime_contract.py` validates that registry and family-owned
`capabilities.json` files. Dispatch and organ packaging consume one acceptance
overlay: explicit answer kinds, in-domain refusal kinds and context-pattern
alternatives. Upstream manifests remain untouched. Unknown fields,
cross-family specialist claims, malformed regexes and duplicate ownership
are rejected. The overlay preserves the original manifest's other rules.

Five inherited manifests (decay, fluids, fluids-r2, springs and fuels) encoded
word boundaries as literal backspace characters. The shared loader repairs
only those five inspected original patterns, without writing upstream or
normalizing other escapes. Five actual composed domain refusals now stop at
the specialist stage; their receipt is
`var/C-runtime-consumers/context-repair.json`. Other missing subject vocabulary
still belongs to each family's explicit context additions.

Capability evidence is labelled as a declaration. It is not turned into a
claim that a theorem was checked for this particular question. The answerer
contract now explains this and removes the obsolete revision-2 launcher as a
current runtime command.

## A concrete computation explanation

Finance emits a packet from its actual discount-and-tax request and
kernel result. The shared Python consumer independently checks the rational
inputs, successive discount factors, tax multiplication, cents rounding and
the final stated amount. It retains the actual packet and records which
checks ran. An inconsistent packet produces a decisive withheld reply,
keeping its original operation kind so a manifest cannot turn the rejection
into accidental fallthrough.

This independent Python check is explicitly unverified. It checks typed
arithmetic and the final amount, not English recognition, the meaning of the
model, or every sentence in the response. The producer's HOL checker and its
theorem belong to the finance kernel. Its exported checker is true exactly when
`kernel (R_DiscountTax b discounts tax) = Exact K_discount_tax value`: it checks
nonnegative price and tax, each discount between 0 and 100, and the exact
product of discount factors followed by tax. The actual producer runs this
checker on the request and result it serializes. Alternate tax-base, tax-amount
and savings requests do not currently emit this replay packet.

## Checks so far

- `python3 -B tools/test_runtime_contract.py`: 13 tests pass. Tests cover
  ownership, schema and regex rejection, preserving original acceptance,
  changing packet inputs/results/output while leaving its `accepted` flag
  true, stacked discounts with a half-cent boundary, malformed present
  evidence, absence of evidence, bounded numeric notation and unambiguous
  final-money formatting.
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
- The final finance native executable (`079c948a…51b4c`), built from the
  checked 64-theorem/zero-oracle export, passes four actual dispatcher probes:
  two discount-and-tax answers with consistent packets, a tax-amount answer
  without a packet, and a negative-tax refusal. Five changes to its actual
  inputs/result/value/text/checker flag are rejected. Receipt:
  `var/C-runtime-consumers/finance-evidence-final.json`.
- The same final finance executable in a relocated package passes four
  targeted checks through Oracle7's actual loader. Its actual $64.80 reply
  survives; changing its value to $65 while retaining `accepted: true` yields
  a non-None withheld reply. Receipt:
  `var/C-runtime-package/finance-final-native/consumer-check.json`. This is a
  scoped consumer check, not an additional panel score.
- `python3 -B tools/dispatch/test_fusion_lifecycle.py`: three real-process
  checks pass. The fusion adapter reaps its own kernel after EOF, an uncaught
  request exception and SIGTERM, including a child that ignores termination.
  It never kills processes by a name pattern.

## Integration still open

Finish current-source package receipts, including Linux computing. Stores
asset relocation and current Mac/Linux reply identity are checked: the selected
cooking-v3 and warehouse panels score 811/818 right, zero wrong/false yes, on
both platforms, with all 818 status/response pairs identical. Their 7 remaining
misses are not claimed repaired by relocation. Current Linux refresh staging
now binds unchanged proof dependencies and exports to the exact final runtime
compiler inputs; new remote submissions remain held while older builds drain. Do not silently relabel historical Linux receipts as fresh.
The dispatcher now previews effectful warehouse requests, selects and guards
the preview, then commits the original request once using its private state.
Tests show that losing or guard-blocked previews do not write and that a
confirmed order commits once. A commit error is not retried. The unmodified
Oracle7 multi-organ host has no selection/commit callback; generated warehouse
wrappers therefore default to previews with truthful refusals of effects.
An explicit sequential owner can enable effects. Actual Combo tests cover
speculative fan-out, counterfactuals, repeat calls and concurrent calls without
state writes. Cooking remains usable independently.
Route adapters preserve the difference between not recognizing a question and
refusing a recognized request. The final mathematics packet has a completed
41-statement/zero-oracle proof build, 28 independent recognizer boundary cases
and seven actual composed checks. All 93 recorded head cases retain their
status and path; 52 retain exact text and 41 differ only by removing an
unsupported assurance sentence. This recorded comparison is not mathematical
correctness coverage. The typed linear-equation and integer-root laws, source
receipts and limits are in `C-runtime-routes.md`.

The current word-problem wording packet is also built: 24 recorded cases keep
their status/path and lose only the unearned assurance suffix; 12 negative-given
checks withhold. Further investigation found real mixed-unit and unsupported
unit errors absent from that panel. The next route packet is implementing typed
unit normalization and removing inherited echo refusals when an actual typed
equation already establishes the requested solution. Current panel parity is
not a reason to retain those defects.

No Isabelle theorem was introduced by the shared Python contract. It is
untrusted runtime glue. No entire-fleet or live-head score is claimed here.
