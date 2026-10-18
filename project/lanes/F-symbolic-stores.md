# Stores: one warehouse order means one quantity and item

Owner: Codex `/root/symbolic/stores`, 18 October 2026. This follows committed
E `4b84d7b`; its captured binaries and comparison receipts remain unchanged.
The final native, Linux and scoped consumer results are recorded below.

## Counterexample and interpretation

The previous executable interpreted “Reorder 2 M4 valve and 3 blue gaskets” as
an order for **two blue gaskets**. Its integer pattern read the first number,
while its item search preferred the longer item name anywhere in the suffix.
“Reorder -2 M4 valve”, a grouped/scientific quantity or a decimal quantity could
instead fall through to an ordinary stock reply, changing the remembered item.
Preview-only evidence is at `var/stores/roles/order-frontier.json`.

The new recognizer owns the complete order request. It reads a leading exact
numeric token, requires a positive integral value, then matches the entire item
phrase to one supplied normalized item name. Numeric item codes such as M4 stay
inside that item phrase; they are not harvested as quantities. Singular/plural
normalization remains available. Supported number words use the existing finite
dictionary. A prior item can supply an explicit pronoun, not an unknown noun.

One request can propose one item. Multiple items, alternatives, conditions and
uninterpreted text refuse rather than selecting part of the request. A leading
“yes” or “no” does not bypass that refusal when the same message contains an
unsupported order instruction. A further actual preview probe found that “yes, but only 3 M4 valves” could
confirm the old seven-valve proposal. Confirmation/cancellation now requires a
complete supported phrase, with optional ordinary politeness. “yes please” and
“confirm the order” confirm; “no thanks” cancels. Modified or conflicting
confirmations refuse and preserve the pending proposal. Recognized low-stock-list questions retain their
read-only meaning.

`order_clarify` is a new declared warehouse refusal kind. Its response asks for
one known item and a positive whole-number quantity and states that no order was
changed. The family capability sidecar declares it for `warehouse` and
`warehouse-r2`; explicit re-order/restock context can preserve the refusal when
unpinned. Plain “order” alone is not a blanket new cross-domain context.

The driver now avoids persistence when the complete kernel state is unchanged
and no order was emitted. Thus a refused order cannot create a fresh state file,
rewrite existing pending state or merely update a reference through stock-read
fallback. Preview still never persists. A later plain confirmation can consume
the untouched prior proposal once.

## Proof boundary

The new theorem `invalid_order_preserves_state` states exactly:

```
sstep s (I_read R_invalid_order) ev =
  (if ev_complete ev then SO_order_clarify else SO_incomplete, s)
```

It applies to every prior state, including a pending proposal, and both complete
and incomplete evidence. The typed invalid request cannot issue an order or
change the pending proposal/reference. `sreply SO_order_clarify` produces the
new withheld reply. The exported `state_changed s t` is exactly `s ≠ t`; the
untrusted driver uses that result to skip unnecessary `state_put` calls.

This is not a proof that English quantity/item binding is correct. Exact numeric
recognition, positivity/integrality checks, item-name normalization and lookup
remain untrusted. The source-name table is assumed accurate and sufficiently
complete. Its existing normalization/deduplication adapter is not a database
uniqueness proof. Neither the theorem nor the unchanged confirmation theorem
proves external file isolation; one serialized owner must own a state file.

The first 45-theorem proof passed, but actual native compilation rejected a
code-generated binder named `before`, an SML infix identifier. The source
parameters were renamed to `s` and `t`; generated code was not patched. The
second immutable proof/export and its consumed native artifact are recorded in
the final appendix.

## Measurement policy

`orders_check.py` uses isolated temporary state files and immutable source item
IDs. Positive requests must propose and then commit the exact expected item and
quantity; repeated or other-session confirmation must not append another order.
Refusal cases run with no state and with an existing pending proposal, in both
preview and committed modes. State bytes must stay unchanged. A rejected new
proposal followed by plain “yes” must commit the old seven-valve proposal.

A passing refusal assertion is not answered capability. Meaningful unsupported
requests (for example a multi-item order, a condition or unsupported number word)
are reported as withheld-valid. Malformed/nonpositive inputs and conflicting
instructions are separate policy checks. The authored policy matrix does not
replace shipped specialist scorers.

The E report's earlier mixed total was corrected without rerunning: among 882
independently calculated numeric questions, E had 882 answered-correct/0 wrong/
0 withheld, while D had 447 answered-correct/55 wrong/380 withheld. The other
36 were policy/ambiguity checks. D's additional three policy-divergent answers
were not all numeric errors: `1 3/2` interpreted as 2.5 is coherent, though E's
chosen mixed-fraction grammar withholds it.

## Files and consumers

The packet owns `Stores.thy`, `Stores_Export.thy`, `recognizer.sml`, `main.sml`,
new `orders_check.py`, new `capabilities.json`, the Stores README, this report,
and the E report's metric wording correction. Shared numeric source and runtime
implementation are unchanged. Consumers are the standalone executable, the
private preview/commit dispatcher and the relocated package wrapper.

## Final bound native and measured results

The current passed proof receipt is
`var/stores/remote-attempts/20261018T082752Z-8c5a397fcf00/receipt.json`:
**45 theorems, zero oracles**, with a native-compilable export. Its source and
export hashes are checked by the common precompile snapshot helper.

* Final Darwin binary: `var/stores/orders/bound`, SHA-256
  `08d3ac3e4a5a5a4bbaa753b841417a031ce886b1bf5bb3e41130febf6133b4b5`.
* Darwin size: **652,232 bytes**.
* Actual native-input manifest:
  `var/stores/native-attempts/20261018T083535Z-263e56cb0363/compile-inputs.json`.
* Generated export: `4923a2fb898a9e4bc8997501e83277d3ed3b8b0b3cc315857b40a59a52335e6f`.
* Recognizer: `7e658204f28f05e3ea679bd379c7101e683123f03c181f18685b2a770ccd937a`.
* Driver: `87cd42ca4144b56f7999792820c2e821817ec26ab3891874f3763e29c55ceaa2`.
* Shared numeric input remains `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.

The authored transaction matrix passes **204/204 recorded request-policy
observations**, plus the confirmation/state assertions surrounding them:
**20 supported orders answered correctly and committed exactly**, **96
explicitly classified withheld-valid observations**, and **88 other refusal-policy
observations**. Of the latter, eight repeat the unsupported spelling `M4,valve`;
if that punctuation is read as the intended single item, those are also
withheld-valid (104 total), not correct answers. They receive no answered-capability
credit. The other 80 exercise malformed/nonpositive or conflicting inputs.
Zero tested requests assert a wrong result or a false yes. Repeated observations
exercise absent/pending state and preview/commit modes; they are not 204 distinct
user questions. Receipt: `var/stores/orders/bound-checks.json`.

A separate source-name sweep asks a positive-count proposal for each of the
**400 supplied warehouse item names**, using varying counts from one to 19.
All **400/400** preview replies propose the exact requested name/count, with zero
wrong proposals, zero withheld-valid and no state file created. The expectations
come directly from immutable SQLite rows, not the recognizer. This checks the
new complete-name matcher across the supplied inventory, not source completeness
or the correctness of real-world stock. Receipt:
`var/stores/orders/all-item-proposals.json`.

Existing 20 quantity probes and executable state tests pass on the final binary.
Inherited table checks pass. The arithmetic/cooking reader did not change in F;
eight current cooking smoke probes (scientific mass and counted serving under
all four cooking IDs) pass. The 918-case cooking matrix and fresh cooking
sampling were not repeatedly rerun for this warehouse-only interpretation change.

The changed specialists' own shipped scorers give:

| Exact ID | Dev right/items | Held-out right/items | Wrong | False yes |
|---|---:|---:|---:|---:|
| warehouse | 199/199 | 199/199 | 0 | 0 |
| warehouse-r2 | 199/199 | 199/199 | 0 | 0 |

Total **796/796**, unchanged. These panels contain stock/sensor questions and
one low-stock-list question but no actual reorder/confirmation scenarios; their
green scores do not establish the new transaction capability. Receipt:
`var/stores/orders/shipped-warehouse.json`. The scorer ran on the initial F native;
the final confirmation refinement has identical saved replies on all 2,476
shipped questions, including these 796. That comparison uses the two immutable
Linux-stage Darwin reply captures, not a second broad scoring run. The exact
comparison is recorded in `var/stores/orders/shipped-final-reply-comparison.json`.

For the unchanged cooking IDs, E's last shipped measurements remain:
`cooking` 200/202 dev and 214/218 held-out; `cooking-v2` 207/210 and 205/210;
`cooking-v3` and `cooking-v3-r2` each 190/192 and 223/228. All have zero wrong/false
yes. F's eight current smoke probes do not replace those historical scored
measurements with a claim that all six were rescored.

## Specialist review and remaining scope

| Exact ID | F review |
|---|---|
| cooking | Unchanged role parser; current scientific/chayote and counted/apple smoke both pass. Numeric food attributes remain unsupported. |
| cooking-v2 | Same two current cooking smoke probes; its narrative narrowing remains unchanged. No new nutrition-data capability claimed. |
| cooking-v3 | Same two current cooking smoke probes; E's seven specific panel withholds remain documented, not imputed away. |
| cooking-v3-r2 | Same two current cooking smoke probes; separate physics/narrative boundary remains unchanged. |
| warehouse | Complete quantity/item binding and complete confirmation; 102 recorded transaction observations, all state checks pass, 398/398 shipped. |
| warehouse-r2 | Same transaction matrix independently invoked, including complete-name unknown refusal; 102 observations and 398/398 shipped. Existing long-query narrowing is unchanged except the explicit new order refusal. |

Order requests support one item and a positive integral exact quantity, including
finite number words. Unsupported number words, item aliases that do not match a
complete supplied name, multiple items, conditional requests and edits such as
“yes, but only three” withhold. A useful later extension would model an explicit
replacement of a pending quantity/item as a new proposal requiring fresh
confirmation. Multi-item orders need a typed list proposal and atomic whole-list
confirmation; they must not be implemented by selecting one substring.

The changed proof guarantees state preservation for the invalid-order constructor;
it does not prove that all ordinary-language conditionals or negations are read
correctly. Positive-integral order validation remains an adapter check. External
item completeness, persistent-store integrity and sole-writer serialization
remain assumptions. Cold-start and Linux binary-size goals are still outstanding.

## Actual dispatcher transaction

The runtime deputy's current default-dialogue dispatcher passes **12/12** scoped
cases against final `08d3ac3e…`; receipt `var/converse/stores-final.json`, reproduced
by `tools/dialogue/check_stores.py --binary var/stores/orders/bound`.

A pinned stock read followed by a seven-valve proposal establishes meaningful
state. Multi-item, negative, unknown-item and modified-confirmation requests
produce terminal `order_clarify`; both evaluation and final refusal leave the
entire pending state byte-identical and append no ledger entry. Subsequent plain
“yes” orders the original seven valves once; repeated “yes” adds no order.
Unpinned unknown-order refusal is terminal, and an unpinned valid proposal is
truthfully withheld in preview; neither creates a state file. This uses actual
consumer arbitration/guards and dialogue, not a mock of the producer.

## Final Linux closure

Final Linux binary `var/stores/stores-orders-6378254b18/stores-linux` has SHA-256
`1c63368b82ab6467426265ec5962dcd9bf0d4362a05a66419c39838563c146e8` and size
**1,582,808 bytes**, still above the 1 MB target. Receipt:
`var/linux/receipt-stores-hbox-stores-orders-6378254b18.json`.

It was compiled from the copied final runtime and passed 45-theorem export under
the hbox global managed lock and 8 GiB bound. All recorded source hashes still
match the final checkout. Actual Linux execution passes the 204 order observations
and the 20 earlier quantity/state probes. All **2,476** shipped replies equal
final Darwin `08d3ac3e…` after removing only specialist timing. The copied Linux
order-test record is `linux-orders-check.json` beside the binary.

The earlier native `81c4eb5…` and Linux stage `stores-orders-6f9365fdbf` predate the
modified-confirmation repair. They remain historical evidence and are not this
packet's delivery artifacts. The final native manifest freezes its actual input
graph; the final Linux receipt binds the new immutable runtime, verified export,
sidecar and exact binary rather than relabeling that earlier build.

Package owner validated the seven actual final compiler inputs and frozen fetch
at `var/C-runtime-package/bound-prepared/20261018T083535Z-263e56cb0363/stores`.
This capture is the **next candidate**, not a claim that the selected E delivery
was already replaced. Root integration controls promotion; E remains selected
until that step. The final matching F Linux receipt is available for the same
candidate cohort.
