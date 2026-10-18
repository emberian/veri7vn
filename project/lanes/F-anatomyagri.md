# Anatomy/agriculture F: supplied amounts and fertilizer scope

F repairs reachable signed and malformed macro/fertilizer inputs and adds
explicit total/per-acre fertilizer mass balance. A negative 10 g protein no longer
becomes positive 10 g, nor does1.2.3 silently become1.2 or2.3. Positive rational and
scientific macro quantities work, and explicit zero gives zero calories.

A 10-10-10 grade supplying20 lb N/acre over5 acres requires1000 lb total product;
supplying20 lb total N over5 acres requires200 lb total product or40 lb/acre. The
kernel now represents those scopes separately. A200 lb/acre product rate over
5 acres contains100 lb total N, while200 lb total product over5 acres contains4 lb
N/acre. Reader roles preserve the whole quantity and do not discard a sign.

## Results

The final official shipped score is 156/156 in both specialist and family modes,
zero wrong/false yes/withheld-valid. Development 10181001 and10182003 and final
untouched 10188029 each score 156/156. All source-table comparisons pass.

| Same authored questions | Policy assertions passing | Capability right / wrong / false yes / withheld-valid / unassessed |
|---|---:|---:|
| F |99/99|79 /0 /0 /20 /0|
| Frozen E |71/99|53 /7 /12 /25 /2|
| Shipped organ |26/99|23 /18 /15 /28 /15|

The 20 valid unsupported cases include the 17 explicit E model exclusions and
three fertilizer requests needing elemental-P, elemental-K or hectare
semantics. Unsupported refusals are counted withheld-valid. Some developmental
or unit questions have no scalar reference in the probe; an old answered reply
is therefore unassessed, not invented as correct or wrong. These authored
questions are same-author tests, not an independent held-out language panel.

Final native size and startup samples are in shipped-delivery.json. The
previous wording artifact scored 152/156 because the shipped scorer does not
extract a number after “supplies”; all four numeric values were correct. The
final renderer says “contains”, a natural mass-content description. Its fresh
proof/native receipts supersede that artifact. Historical diagnostics and
receipts remain available.

## Binding statements

The proof scans 67 theorems with zero oracles, up from 62 in E. New statements:

- Successful supplied-component calorie sum requires all four amounts
  nonnegative and equals 4p+4c+9f+7a. An explicit all-zero request returns 0.
- The supplied-component calculation is additive: combining two nonnegative
  component vectors gives the sum of their component energy totals.
- Successful fertilizer-need output implies valid grade, amount and scope,
  positive selected grade fraction, nonnegative output, and
  output × selected-percent/100 = scope-converted nutrient amount.
- Successful fertilizer-content output implies valid domains, output between
  zero and scope-converted product amount, and
  output × 100 = scope-converted product amount × selected-percent.
- For positive area, multiplying a rate by area and then dividing by that area
  returns the original rate.

Legacy fertilizer value and round-trip statements now retain physical-domain
conditions. Grade columns denote N, P2O5 and K2O; they are not elemental P/K.
The Atwater constants define a supplied-component approximation, not a claim
about every food. English model selection, exact-token role assignment,
observations and JSON framing remain untrusted.

## Exact artifacts and changed paths

Passed proof: `var/anatomyagri/f-next/checkout/var/anatomyagri/remote-attempts/20261018T091931Z-26bb07d5a4eb/receipt.json`.
Native binding: `var/anatomyagri/f-next/checkout/var/anatomyagri/native-attempts/20261018T092154Z-7772f02b4bb5/compile-inputs.json`.
Binary SHA: `4e86159a7aeacc0002e36b10447b1666b4ebc262dcbbd7fff49d6f62888950a2`.
Shared exact numeric SHA: `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.
The shared native helper binds actual copied compiler inputs and full theory
closure. The isolated checkout records its passed E base and exact owned
overlays. It does not claim F was compiled from live E source.

An initial proof attempt hit its 16 GiB memory cap while expanding overlapping
request/reason text patterns. Reason-first case dispatch removes that blow-up
without increasing the resource cap. A subsequent proof needed one explicit
nonnegative-product step; the final passed receipt includes the repair.

Changed canonical candidates under src/extract/anatomyagri are AnatomyAgri.thy,
AnatomyAgri_Export.thy, recognizer.sml, capabilities.json, probes.json, README.md
and semantic-gaps.md, plus this report. Frozen E is unchanged until root releases
promotion. `var/anatomyagri/f-next/transfer.json` binds each staged path to its
E baseline and candidate hash; `var/anatomyagri/f-delivery/ready.json` is the
staged packet. Final evaluation receipts are probes-delivery.json,
shipped-delivery.json, probes-e-final-baseline.json and the f-delivery fresh
panel files. The specialist/family CLI consumes the generated model. Runtime
composition passes all eight exact final unit/domain cases, including total
versus per-acre text, negative-domain refusals, fractional macros and explicit
zero. `var/C-runtime-consumers/staged-F-anatomy.json` binds the final binary
and staged declaration through the actual shared Dispatcher. Remaining per-ID limits stay in semantic-gaps.md.
