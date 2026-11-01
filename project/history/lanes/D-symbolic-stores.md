# Stores: explicit counted servings

Owner: Codex `/root/symbolic/stores`, 18 October 2026. This builds on the committed
[C packet](C-symbolic-stores.md). It changes cooking interpretation and finite
portion coverage, and repairs an actual warehouse conversation bug found during
consumer integration. The external CLI is unchanged.

## What now works

Previously, “carbohydrate in 2 Granny Smith apples” silently selected the USDA
medium weight and answered 45.46 g. “Two small Granny Smith apples” failed food
matching because “two small” remained part of the food name. The new executable
carries quantity, size and form separately into the kernel:

| Request | New result |
|---|---|
| 2 Granny Smith apples | Clarify the serving |
| two small Granny Smith apples | 39.20 g carbohydrate |
| two medium Granny Smith apples | 45.46 g carbohydrate |
| two large Granny Smith apples | 56.07 g carbohydrate |
| half a small Granny Smith apple | 9.80 g carbohydrate |
| two raw chayotes | 18.31 g carbohydrate |
| two large raw chayotes | Withhold: no matching size weight |

These use USDA rows 168203 and 170402, not fitted constants. Counts support
small, medium, large, extra small, extra large and jumbo; slices, strips and
pieces have distinct interpretations. Explicit sizes only use matching labels.
The recognizer removes number words and serving modifiers before food matching.
Fractions with spaces around the slash are normalized before recognition.

An unsized count checks every eligible supplied per-item weight. It may answer
when all those readings agree within the existing display tolerance; it does
not necessarily clarify every unsized count. Its preferred row is only a
representative after that agreement check. Unsupported labels safely withhold.
Plain bananas still have lexical alternatives including banana peppers and
chips; this work does not claim to resolve that food-name ambiguity.

The consumer test also found that after discussing M4 valves, “purple widgets
count?” inherited the valve reference and answered 107. The old recognizer used
the prior item for almost any short stock/location question. Now only genuine
omitted-object phrases such as “count?” inherit the item; pronoun references
still work. The same-session regression verifies M4 count 107, unknown widgets
withheld without changing state bytes, “Where is it?” returning A5-05, then
“count?” returning 107. This is an English-interface repair; the unchanged HOL
state machine cannot prove that a parser chose the intended object.

Adversarial numeral checks then exposed two concrete parser faults: Unicode
“−2 small apples” became positive two, and “2,000 small apples” matched the
suffix “000” and answered zero. Unicode minus now goes through the existing
negative-quantity rejection, and quantity matches cannot begin inside another
numeric token. Ordinary decimals and deliberate mixed fractions remain supported.
The tested leading-dot, scientific-notation and grouped-numeral cases withheld;
they were not supported formats. This was only a conservative lexical check.
The subsequent E role matrix found that scientific notation with raw chayote
could still fall back to the default 100 g, because food matching dropped the
unrecognized single-letter exponent text: `1e3 g` answered 0.82 g protein
instead of 8.20 g. The captured D artifact retains this known limitation. The
shared issued-token follow-on removes that fallback; D's shipped-panel scores
do not measure this counterexample.

## What the proof says

`nutrient_portion_groups` assumes `nkernel e = NAnswer g p v pl` and
`needs_portions (nq_amount e)`. It concludes all three of:

* The food IDs in `nq_other_portions` are distinct.
* Their set equals the food-ID set in `nq_near`.
* If `nq_hit e = Some fd`, looking up that food in `nq_other_portions` returns
  exactly `nq_portions e`.

The executable guard additionally requires every supplied portion weight to
be positive. Self-tests reject missing groups, duplicate groups and a selected
group inconsistent with the selected portion rows.

The revised `nutrient_count_portion` assumes the amount is
`A_count q nt w0 sz form` and the kernel answers. It concludes there is a stored
selected portion `(l,w)`, its label satisfies `count_matches sz form l`, the
answer uses `g = q*w`, and its preference key is no worse than any other
eligible selected-food portion. Selection cannot ignore an explicit size/form.

`nutrient_serving_alternatives` says that an answer's displayed value differs
from each `w` in `possible_values e` by at most `max(w/20,15/100)`. Previously a
count contributed only its preferred weight. Now every eligible supplied count
weight contributes a value, just as every matching household measure does.

These are finite-input guarantees. Exactly one group per supplied alternative
does **not** prove each group contains every database row, that every relevant
food was fetched, or that a group with no matching portion permits an invented
weight. Empty groups contribute no possible values. `nq_complete` remains an
untrusted fetch assertion, as do English interpretation and source-data accuracy.

The managed hbox proof passed on its first attempt, with 44 scanned theorems and
zero oracles. Receipt:
`var/stores/remote-attempts/20261018T071519Z-320bfa7ee00a/receipt.json`.

## Review by specialist

Each ID was invoked separately in `var/stores/counts/specialist-review.json`.
All cooking variants share the same USDA source model and now share the polite
and content-frame normalization; this does not make their ownership boundaries
identical. The 394-case arithmetic matrix runs on cooking-v3, while the separate
per-ID review tests six serving/normalization examples and two boundary examples.

| Exact specialist ID | Concrete behavior examined and remaining boundary |
|---|---|
| `cooking` | Unsized apples clarify; small/large return 39.20/56.07; polite half-small returns 9.80; word-count chayote returns 18.31; unsupported large chayote withholds. Legacy broad boundary still takes the tested physics and three-sentence narrative as unknown_food; it does not answer them. |
| `cooking-v2` | The same six serving cases pass through its normalized recognizer. Its narrative gate declines the tested three-sentence request with taken=false. The physics wording remains an owned unknown_food refusal. Broader narrative language was not independently exhaustively evaluated. |
| `cooking-v3` | The same six cases pass, including “Could you please tell me the carbohydrate content of half a small Granny Smith apple?”; its content/polite normalization is exercised explicitly. It shares v2's tested narrative decline and broad physics refusal, and carries the full 394-case matrix. |
| `cooking-v3-r2` | The same six serving cases pass. Both the three-sentence narrative and kinetic-energy request return taken=false, exercising its extra physics/domain boundary. No claim that all food/physics ambiguities are resolved. |
| `warehouse` | Separately tested stock 107 → explicit unknown widgets withheld with unchanged state → pronoun location A5-05 → bare count 107. A long unknown-item phrase stays an owned unknown_item refusal. This repairs the actual prior-reference counterexample; English object resolution remains untrusted. |
| `warehouse-r2` | The same state/pronoun/ellipsis sequence passes. Unlike warehouse, the tested long unknown-item phrase returns taken=false. The full preview/commit/failure fixture also runs through this ID. That fixture does not establish arbitrary concurrent shared-state safety. |

Actual dispatcher composition passes the four count probes: unsized apples
remain a terminal clarification, while small/large apples and chayotes answer
39.20/56.07/18.31 with only the specialist stage. The final reference sequence
also passes through the actual guards: unknown widgets remain a terminal refusal
with the entire state file unchanged, then the pronoun still resolves correctly.
Two additional malformed-numeral requests (Unicode minus and comma grouping)
withhold without a fallback answer, giving six cooking composition probes.
Receipts: `var/dispatch/stores-counts-composition.json` and
`var/dispatch/stores-unknown-reference.json`, both final bound Darwin hash c23f3dd5….

## Measured results

The actual shipped cooking panels retain the C scores; numbers are right / wrong
/ false yes. Remaining valid cases are withheld or clarified.

| Specialist | Dev | Held-out |
|---|---:|---:|
| cooking | 200 / 0 / 0 of 202 | 214 / 0 / 0 of 218 |
| cooking-v2 | 207 / 0 / 0 of 210 | 205 / 0 / 0 of 210 |
| cooking-v3 | 190 / 0 / 0 of 192 | 223 / 0 / 0 of 228 |
| cooking-v3-r2 | 190 / 0 / 0 of 192 | 223 / 0 / 0 of 228 |

Total: 1,652 right of 1,680; zero wrong and zero false yes, 28 valid withholds.
The panels contain no counted-serving coverage sufficient to measure this new
capability; an unchanged panel score is regression evidence, not a count gain.
The repaired warehouse recognizer was scored separately: warehouse and
warehouse-r2 each remain 199 / 199 on dev and held-out, zero wrong/false yes.
All six panels therefore total 2,448 / 2,476, as in C.

Fresh generator seeds, same C and D results:

| Seed | Specialist | Dev right / n | Held-out right / n |
|---|---|---:|---:|
| 18111 | cooking | 221 / 223 | 195 / 197 |
| 18111 | cooking-v2 | 215 / 218 | 199 / 202 |
| 18111 | cooking-v3, each r2 | 233 / 234 | 184 / 186 |
| 18112 | cooking | 195 / 198 | 220 / 222 |
| 18112 | cooking-v2 | 217 / 222 | 193 / 198 |
| 18112 | cooking-v3, each r2 | 212 / 215 | 203 / 205 |
| 18113 | cooking | 210 / 218 | 197 / 202 |
| 18113 | cooking-v2 | 212 / 213 | 196 / 207 |
| 18113 | cooking-v3, each r2 | 205 / 212 | 202 / 208 |

Seed 18111 totals 1,664 / 1,680; seed 18112 totals 1,655 / 1,680. All have zero
wrong and zero false yes. Seed 18112 was first generated and inspected after
the count implementation froze; the subsequent independent reference/numeral
repairs were not tuned on it. These are the original generators with different seeds,
not independent language authorship. Saved results are under
`var/stores/counts/{before,current}{18111,18112}/` and `current-shipped/`.
After all reference/numeral repairs, untouched seed 18113 was generated and
scored: both C and final D have 1,629 / 1,680, zero wrong/false yes and 51 valid
withholds. Its results are in `before18113/` and `final18113/`. The final shipped
cooking rerun is `final-shipped/` and retains exactly the table above.

`counts_check.py` independently reads exact immutable USDA rows and calculates
expected values with Python Decimal and explicit source portion labels. Its 394
cases cover sizes, counts, proper/mixed fractions, slices/strips, clarification,
missing sizes and malformed quantities: D passes 394 / 394 with zero incorrect
assertions. C passes 56 / 394 and makes 41 incorrect assertions. The rest of C's
failures are withheld/clarified rather than the requested result. These cases
were authored alongside the recognizer and are not an external held-out corpus.
Carrot part-form arithmetic probes ask carbohydrate only; other nutrients can
legitimately clarify baby versus regular carrots.

The original 20 quantity probes, persistence failure probes, preview isolation,
exactly-once confirmation and live preview/committer state checks pass unchanged.
The original pattern/table comparison also passes.

## Source and artifacts

Changed files: `src/extract/stores/Stores.thy`, `Stores_Export.thy`,
`recognizer.sml`, `verify.py`, new `counts_check.py`, `build.sh`, `README.md`, and this report.
No source files outside this lane were edited. No new external reply kinds.

SHA-256 values at the implementation freeze:

| Input or artifact | SHA-256 |
|---|---|
| Stores.thy | `749384146b72b12556b58c09b7c9a13498bbeaaf88baa68a56bfbd5af352179b` |
| Stores_Export.thy | `cfe782873842841b69624148a9d0881266233187318a81f442319e548cfd32f1` |
| recognizer.sml | `6871cd10689d6b161177cc105ba121fe852d84a9a74b48bdde0f89d9b76e50f8` |
| Generated SML | `53feba7fb5c28c43e8287fca44c017015f6f14c24cd6e3a058df53259a5d621d` |
| Darwin executable | `c23f3dd5b675cd7f656de255cfbc32212ac956fc29773d3c3a6d5745e03012bc` |

The D Darwin artifact is `var/stores/counts/bound`, 617,048 bytes. C compile
inputs remain in `var/stores/stores-codex-9316b86385/` for immutable packaging.
Root integrated the producer changes in `64fb502`.

The final Darwin compile uses the common `tools/dev/native-compile` helper.
Its actual pre-compile frozen-input receipt is
`var/stores/native-attempts/20261018T073627Z-b3de6599917b/compile-inputs.json`;
this is not a retrospective manifest. It binds all actual MLB source inputs,
the generated export and the live passed proof receipt. `build.sh` now uses the
same helper for future builds. The bound executable passes all 394 targeted and
20 original/state checks and produces identical replies for all 2,476 shipped
requests compared with the earlier same-source candidate after removing timing.

Linux compiled the immutable final runtime/export under the normal managed lock
and 8 GiB cap. Its binary is
`var/stores/stores-counts-aed8de60f3/stores-linux`, 1,461,752 bytes, SHA-256
`52aac86783b1af623dc262de658f7289ff90c4a86669038b41f14b1dec7362fb`.
Receipt: `var/linux/receipt-stores-hbox-stores-counts-aed8de60f3.json`.
The 394 targeted checks and all original/state tests pass on Linux. All 2,476
shipped-panel replies equal the final bound Darwin replies after removing only
`specialist_ms`. The receipt keeps the original candidate comparison and adds
the directly checked `bound_macos` binding; it does not invent a prior compile
manifest. Frozen runtime and theory hashes were checked against the live source
before handoff. The Linux size target remains unmet.

The existing cold-start and Linux size targets remain unmet. This work does not
claim independent food-ontology correctness or completion of the six composition
criteria; its consumer is the cooking family inside the existing dispatcher and
relocatable package contract.
