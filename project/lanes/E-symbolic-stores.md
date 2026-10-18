# Stores: exact numeric serving roles

Owner: Codex `/root/symbolic/stores`, 18 October 2026. This follows the committed
[D serving/reference packet](D-symbolic-stores.md). The external CLI, reply kinds,
HOL kernel, database fetcher and warehouse state protocol are unchanged. The
consumer is the standalone Stores executable and the dispatcher/package wrapper.

## Concrete repair

The D binary answered “How much protein is in 1e3 g of raw chayote?” with 0.82 g:
its numeric pattern failed, food matching discarded the exponent text, and the
request silently became the default 100 g. The E binary answers 8.20 g for the
requested 1,000 g. D's earlier scientific-notation probes happened to withhold
for sized apples; its report now states that narrower observation and this fault.

Cooking now uses `ExactNumeric.mask` and only consumes rational values issued by
that scanner. It assigns every issued token to a mass, household or count role;
there is no second numeric substring parser. Any unclaimed token rejects the
request. Marker-looking text is checked against the issued table before trying
role candidates, including case variants. Numeric or non-ASCII text left in the
food phrase also withholds instead of disappearing into a default serving.

| Request fragment | Actual E result |
|---|---|
| protein in `1e3 g` raw chayote | 8.20 g |
| protein in `.5 g` raw chayote | 0.00 g after two-decimal display rounding |
| protein in `1 1 / 2 kg` raw chayote | 12.30 g |
| carbohydrate in `+2.5 small` Granny Smith apples | 49.00 g |
| carbohydrate in `1,000 small` Granny Smith apples | 19,598.40 g |
| carbohydrate in `1 1.5/3 small` Granny Smith apples | 29.40 g |
| negative quantity, `1 000`, malformed exponent or grouping | Withheld |
| `qnum0q`, two independent quantities, Unicode `½`, or trailing `^3` | Withheld |

Single numeric tokens support the shared reader's signed decimals, scientific
notation and scalar ratios. Serving quantities must be nonnegative. A two-token
mixed quantity is deliberately an integer plus a proper nonnegative slash
fraction; `1 3/2`, `1.5 1/2` and two unrelated numbers are rejected. Zero is
allowed. Number words remain a finite explicit dictionary. Mixed-fraction display
text is retained separately from its exact value.

This is a lexical/semantic adapter improvement, not a new proof of English.
USDA decimals still enter through the existing untrusted row adapter. Numeric
food attributes such as percentages, multiple ingredient quantities, unsupported
Unicode food names and Unicode fraction glyphs are outside this one-quantity
interface. The broad leftover-text rejection is deliberate and may withhold a
valid question; it must not be described as multilingual food interpretation.

## Proof and native binding

No theory or generated export changed in E. The current managed proof receipt is
`var/stores/remote-attempts/20261018T071519Z-320bfa7ee00a/receipt.json`: 44 scanned
theorems, zero oracles. Its meaningful guarantees remain:

* If the nutrition kernel answers, the displayed amount agrees within
  `max(w/20,15/100)` with every value in its finite supplied `possible_values`.
* For an answered counted serving, the selected stored label matches the explicit
  size/form, and the gram amount equals the quantity times that portion weight.
* For an answer needing portions, supplied group IDs are distinct, their set
  equals the supplied food-alternative ID set, and the selected group equals the
  selected portion rows. Supplied weights must be positive.
* Warehouse confirmation consumes a pending proposal in the same session and
  places that proposal's exact order. External file isolation is not proved.

These statements bind the actual generated kernel called by E. They do not prove
that fetching omitted no foods/portions, that the source rows are correct, that
English was interpreted correctly, or that `nq_complete` is true. No new theorem
is claimed for `ExactNumeric` or the role adapter.

The actual precompile input snapshot is
`var/stores/native-attempts/20261018T075855Z-7c2fe939b12b/compile-inputs.json`.
The common native helper copied every application MLB input, checked the current
proof dependencies and verified the generated export before compiling. It reports
`current_proofs_match: true`, no proof differences, compiler exit zero.

| Artifact | SHA-256 |
|---|---|
| E Darwin `var/stores/roles/bound` | `d3ec781d13e370b5a0d849f6fe1d2942394477fbf148aad53f605401d6450661` |
| Stores recognizer | `94d543e14e027f07b97ad9eedb2f3eba2d16241e1c48b774920cf076f3ab02e4` |
| Shared numeric input | `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d` |
| Unchanged generated Stores export | `53feba7fb5c28c43e8287fca44c017015f6f14c24cd6e3a058df53259a5d621d` |

The Darwin binary is 637,320 bytes. The shared numeric source belongs to its
separate owner; E only adds it to Stores' actual MLB. Linux and actual consumer receipts are appended below. Historical C/D artifacts
remain available for comparisons and are not rewritten as E.

## Measured results

The final bound executable was scored by every shipped specialist's own scorer.
Right includes correct refusals. All rows have zero wrong and zero false yes.

| Exact specialist ID | Dev right/items | Held-out right/items |
|---|---:|---:|
| cooking | 200/202 | 214/218 |
| cooking-v2 | 207/210 | 205/210 |
| cooking-v3 | 190/192 | 223/228 |
| cooking-v3-r2 | 190/192 | 223/228 |
| warehouse | 199/199 | 199/199 |
| warehouse-r2 | 199/199 | 199/199 |

Total: **2,448/2,476**, 28 valid withholds. Cooking alone: **1,652/1,680**.
Receipt: `var/stores/roles/bound-shipped.json`. These shipped generators mostly use
simple amounts and therefore do not measure the repaired numeric-language cases.

Two newly sampled cooking seeds compare D and E using unchanged generators and
scorers. Seed 18122 was first generated after E source freeze. Every D/E pair has
identical scores and zero wrong/false yes. These are new sampled foods, not an
independent language generator.

| ID | Seed 18121 dev; held-out | Seed 18122 dev; held-out |
|---|---|---|
| cooking | 198/202; 211/218 | 202/207; 208/213 |
| cooking-v2 | 198/203; 211/217 | 201/204; 213/216 |
| cooking-v3 | 215/220; 194/200 | 230/231; 180/189 |
| cooking-v3-r2 | 215/220; 194/200 | 229/231; 180/189 |

Totals: **1,636/1,680** and **1,643/1,680**. Receipts under
`var/stores/roles/{before,final}18121/` and `{before,final}18122/`. The first E run
used the semantically identical candidate before final comment cleanup; the
second used the final bound binary.

The independent arithmetic matrix reads immutable USDA rows directly and uses
Python Decimal, not generated kernel arithmetic or food matching. It spans 18
quantity spellings, whole/part servings, nutrients, mass/household roles, malformed
inputs, forged markers and unclaimed quantities. Final bound E passes **918/918**;
captured D passes **480/918**, with **58 incorrect assertions** among its failures.
Most other D failures are unsupported-format withholds. These are authored
regressions, not substitute shipped-panel scores. Receipts:
`var/stores/roles/bound-checks.json` and `baseline-checks.json`.

All 20 earlier quantity probes and executable state tests pass on bound E:
preview leaves existing bytes unchanged, confirmation commits once, sessions
remain isolated, explicit unknown items preserve references without asserting
them, and failed persistence withholds without corrupting state/cache. Inherited
table checks pass: 38 patterns, eight inline patterns, 13 nutrients, 13 mass and
eight measure names, five sensor kinds/suffixes and six word tables.

Warm p50 round trips in this scoped run were 0.44–0.54 ms cooking and
1.52–1.84 ms warehouse. Three cold trials were 92–115 ms cooking and 43–61 ms
warehouse. These exceed the 20 ms cold target. No speedup is claimed from E.
Independent parent probes also passed: `2.75e2 g` raw chayote gives 2.26 g
protein, `2 3/4 kg` gives 22.55 g, and `2e-1/4e-1 kg` gives 4.10 g;
multiple alternative masses and negative mass withhold. Receipt:
`var/symbolic/stores-e-independent.json`.

Standalone panel scoring and these checks do not establish all six head-composition
criteria; actual dispatcher/package checks are separate evidence.

## Six-specialist frontier

Every ID was invoked independently on the final binary; receipt
`var/stores/roles/specialist-review.json` holds 12 cooking role probes and eight
warehouse conversation probes. D's separate per-version ownership review remains
applicable because E does not change those pre-narrowing rules.

| Exact ID | Behavior examined and remaining frontier |
|---|---|
| cooking | Scientific mass 8.20, mixed mass 12.30, extra quantity withheld. Broad narrative/physics ownership inherited from D; no multi-ingredient composition or numeric food-attribute roles. |
| cooking-v2 | Same three numeric-role results, with its narrative narrowing retained. Source-model ambiguities and absent nutrients remain; this is not an independent data model. |
| cooking-v3 | Same numeric results plus all 918 authored arithmetic probes. Better framing does not resolve omitted preparation/portion choices. Numeric attributes need explicit roles before accepting them. |
| cooking-v3-r2 | Same three numeric results; separate physics exclusion and narrative boundary retained. Seed 18122 withholds one additional valid item compared with v3, so the IDs are not interchangeable. |
| warehouse | Count 107 → explicit unknown widgets withheld → prior location A5-05 → omitted count 107. Quantity parsing for orders remains the inherited integer grammar, not E's exact serving-role adapter. |
| warehouse-r2 | Same four-turn reference results plus persistence/preview/confirmation tests. Unknown long-query narrowing retained; concurrent external writers and broader order-number grammar remain outside this packet. |

A preview-only frontier probe (`var/stores/roles/order-frontier.json`) found a
concrete inherited warehouse fault: “Reorder 2 M4 valve and 3 blue gaskets”
proposes **two blue gaskets**. The integer quantity and fuzzy item match can bind
to different parts of a multi-item request. “Reorder 0 M4 valve” proposes zero;
grouped/scientific/signed/decimal order amounts fall through to a stock answer
instead of preserving the requested order intent. No probe committed an order.
These are open producer limitations, not cured by E cooking-number support.

The next useful algorithm is an explicit warehouse order-quantity role: scan an
issued exact value, require a positive integral count, bind the entire quantity
and explicit item phrase, and reject leftovers before creating any pending order.
It should preserve item identifiers such as M4 and distinguish numeric item names
from quantities. Test the pending/confirm transaction and previews, not merely
one answer. A subsequent cooking extension can assign numeric food attributes
(e.g. percentages) their own semantic roles instead of discarding them. Neither
extension is claimed implemented here.

## Remaining nutrition questions

The seven cooking-v3 valid-panel withholds are intentional data/model boundaries,
not missed simple numeric tokens. The same seven apply to r2:

| Exact question | Why E withholds |
|---|---|
| Can you give me the fat content of a cup of degermed cornmeal? | Supplied food/household interpretations disagree. |
| Can you give me the potassium content of a cup of golden raisin? | Supplied food/household interpretations disagree. |
| Could you give me the sodium level of a cup of wheat low cracker? | Supplied food/household interpretations disagree. |
| Would you tell me the calcium value for a cup of added pasta? | Supplied food/household interpretations disagree. |
| Would you tell me the carbohydrates value for a cup of jackfruit? | Supplied food/household interpretations disagree. |
| Can you show me how much sugar is in 100 g of pumpkin flower? | Selected USDA pumpkin-flower entry has no sugar value. |
| Can you show me how much fiber is in 100 g of pink grapefruit juice? | Selected USDA pink-grapefruit-juice entry has no fiber value. |

A specified preparation and gram weight can resolve some ambiguity. Missing
nutrients are not imputed merely to match a panel expectation.

## Changed files

* `src/extract/stores/recognizer.sml`: issued numeric values, explicit quantity
  roles, complete consumption and safe default boundary.
* `src/extract/stores/build.sh`: include shared `numeric.sml` in actual MLB.
* `src/extract/stores/counts_check.py`: independent 918-case regression matrix.
* `src/extract/stores/probes.json`: leading-dot mass is now supported rather than
  deliberately withheld; exact tiny result rounds to zero.
* `src/extract/stores/README.md`: numeric contract, limits and report link.
* `project/lanes/D-symbolic-stores.md`: correct prior scientific-format boundary.
* `project/lanes/E-symbolic-stores.md`: this report.

## Linux closure and package capture

The immutable E Linux compile completed under the hbox global managed lock and
8 GiB memory bound, using the unchanged passed HOL export and a copied runtime
including `numeric.sml`. Actual Linux tests pass 918/918 plus the 20 probes and
state-failure/preview/reference checks. All **2,476** shipped replies equal the
final bound Darwin replies after removing only `specialist_ms`.

* Binary: `var/stores/stores-roles-d3a39ac7fb/stores-linux`.
* SHA-256: `73573634c652ecb04fc9590fb578ac0b5ad0d9b341bc4ffc1f91f3aed0dff185`.
* Size: **1,560,136 bytes**, still above the 1 MB target.
* Deployment receipt: `var/linux/receipt-stores-hbox-stores-roles-d3a39ac7fb.json`.
* Frozen runtime/MLB/config, generated export and actual replies live beside the
  binary; the copied Linux arithmetic record is `linux-counts-check.json`.
* Package owner validated the full E native input graph at
  `var/C-runtime-package/bound-prepared/20261018T075855Z-7c2fe939b12b/stores`.
  It explicitly distinguishes the D recipe from E's additional numeric input.

No fresh Isabelle session was run for unchanged theories. Compilation and checks
took 252.89 seconds including the managed queue interval; this is not a compiler
performance benchmark. The deployment receipt carries actual frozen source
hashes and links the original proof receipt, rather than relabeling a D binary.

## Actual dispatcher composition

Current `tools/dispatch/dispatch.py`, with isolated artifact links, front order,
Stores selected and an explicit cooking-v3 pin, passes **8/8** E cases. Scientific
mass 8.20, leading-dot mass 0.00, positive signed count 49.00, mixed count 29.40
and grouped count 19,598.40 all answer through the specialist stage alone.
Negative quantity, forged marker and unclaimed second quantity all withhold
through that stage without a fallback answer. The latter are parser-error
withholds, not newly proved kernel declines. Other readers/documents/routes were
disabled for this scoped test; this is not a full-fleet claim.

Receipt `var/stores/roles/consumer-composition.json` records the exact command,
requests, replies and bound E binary hash. The historical D dispatcher receipts
are not relabeled as E. Runtime/package separately own the relocated package
acceptance gate.
