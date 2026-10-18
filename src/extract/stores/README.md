# Food amounts and warehouse questions

One program serves `cooking`, `cooking-v2`, `cooking-v3`, `cooking-v3-r2`,
`warehouse` and `warehouse-r2`. Cooking reads the shipped USDA nutrition table.
Warehouse reads one site's stock and sensors, and remembers proposals that
require a later confirmation. The databases are opened immutable and never
changed; warehouse conversations live in a separate writable JSON file.

Cooking handles polite questions, nutrient-content questions, masses, household
measures and whole or fractional quantities. Before answering, the kernel checks
that its displayed amount agrees with every supplied plausible food and serving
within 5% or 0.15 absolute. This matters when foods have similar amounts per 100 g
but different cup weights: an unspecified cup of jackfruit now needs clarification.
A weight in grams often resolves that uncertainty.

Counted foods carry an explicit size and form. Two small Granny Smith apples
and two large ones use different USDA weights; an unspecified pair clarifies
when the possible sizes disagree. Slices, strips and pieces cannot silently
use a whole-food weight. Number words and fractions work for counts too. Numeric serving amounts use the
shared exact-number reader: leading-dot decimals, scientific notation, correctly
grouped thousands and explicit plus signs work for mass, household and count
roles. A mixed fraction deliberately combines a nonnegative integer with a
proper slash fraction. Every numeric token must belong to that single quantity;
negative amounts, malformed numerals, forged markers, extra quantities and
uninterpreted numeric food attributes withhold. A failed numeric role cannot
fall back to the default 100 g. Unsupported non-ASCII food text also withholds.

The exact arithmetic, serving checks, reply construction, warehouse freshness
and stock calculations, and confirmation state machine are exported from HOL.
English matching, SQLite fetching, file persistence, timestamps and JSON remain
untrusted. The fetcher's completeness flags are assumptions: checking supplied
rows cannot prove that none were omitted. The kernel now requires exactly one
portion group for each supplied food alternative, positive supplied weights,
and equality between the selected group's rows and the selected portion rows.
It cannot establish that a group contains every database row, or that the food
alternatives cover every possible interpretation. Those remain external premises.

For warehouse, the HOL state machine requires a pending proposal in the same
session before confirmation can place its exact order, and consumes that proposal.
This does not prove atomicity or isolation of an external shared state file.
Use one state file per serialized owner. Runtime wrappers do not retry stateful
requests automatically.
Pronouns and omitted-object questions can reuse the previous item; an explicit
unknown item cannot silently become that previous item.
An order binds one positive whole-number quantity to one complete item name or
explicit pronoun. Scientific, grouped and rational spellings work when their
exact value is a positive integer. Unsupported orders, including multi-item or
conditional requests, return `order_clarify` and preserve all pending/reference
state. They cannot fall through to a stock lookup. No state file is written when
the kernel state is unchanged and no order was emitted.

## Build and run

```sh
python3 tools/dev/remote-build persvati src/extract/stores Veri7vn_Stores \
  -d src/extract/commons --expect 'VERI7VN_STORES PASS theorems=45 oracles=0'
sh src/extract/stores/build.sh
python3 -B src/extract/stores/tables_check.py
python3 -B src/extract/stores/verify.py
python3 -B src/extract/stores/counts_check.py --binary var/stores/bin/stores \
  --out var/stores/counts-check.json --require-pass
printf '%s\n' '{"id":"1","q":"How much protein is in 1/2 kg of raw chayote?"}' \
  | var/stores/bin/stores --specialist cooking-v3
```

The build script finds a successful remote receipt matching the current Stores
theories and ROOT, checks its export hash, and compiles that export with the
current driver. It keeps previous artifacts and refuses a stale proof export.
The native binary and its receipt stay under `var/stores/`.

Runtime paths can all be supplied explicitly:

```sh
stores --specialist warehouse-r2 --fetch /package/stores/fetch.py \
  --nutrition /package/stores/nutrition_v1.sqlite3 \
  --site /package/stores/site_fresh.sqlite3 --state /writable/session.json
```

`--state` is a **file**, not a directory. Repository defaults remain available
for development. The Python child runs with `-I -B`.

`--preview` evaluates warehouse replies without saving any proposed state or
order. Unpinned family mode defaults to preview; pinned warehouse mode commits
unless preview is requested. `--commit` is an explicit override. Every taken
warehouse reply identifies its preview status in provenance. The dispatcher
must not present a previewed order as placed. A serialized owner may select a
preview through arbitration and guards, then commit that exact request once
using its sole committing child and private state file. Speculative Oracle7
Combo wrappers default to preview; explicit effectful mode requires a caller
that guarantees this ownership. Unrecognized questions, narrowed-away
questions and `off_site` replies fall through before persistence. Failed reads
or writes withhold with an error; the shim updates its cache only after a
successful file replacement.

## Results on 18 October 2026

Standalone shipped-panel scores are right/wrong/false yes. Right includes
correct refusals; the remainder is valid questions withheld or clarified.

| Specialist | Dev | Held-out |
|---|---:|---:|
| cooking |200/0/0 of202|214/0/0 of218|
| cooking-v2 |207/0/0 of210|205/0/0 of210|
| cooking-v3 |190/0/0 of192|223/0/0 of228|
| cooking-v3-r2 |190/0/0 of192|223/0/0 of228|
| warehouse |199/0/0 of199|199/0/0 of199|
| warehouse-r2 |199/0/0 of199|199/0/0 of199|

Two fresh cooking seeds also have zero wrong and zero false yes; the second
was first evaluated after the nutrition implementation froze. Some previously
correct cup answers now clarify because the question does not specify which
household preparation it means. Missing USDA values are still not estimated.
The 20 implementation-authored probes and executable persistence checks pass.

The F Darwin binary is 652,232 bytes; the F Linux binary is 1,582,808 bytes and
still exceeds the 1 MB goal. All 2,476 shipped-panel replies match across these
platforms after removing timing. Earlier measured steady p50 is 0.41–0.48ms cooking and
1.18–1.37ms warehouse. Cold first replies are about 79 ms and 33 ms respectively,
so the 20ms cold-start target remains unmet. These standalone results do not
claim completion of all six head-composition criteria.

The [initial lane report](../../../project/lanes/C-symbolic-stores.md) contains
exact theorem statements, both fresh-seed comparisons, receipts, known limits
and package/dispatcher integration results.
The [counted-serving follow-up](../../../project/lanes/D-symbolic-stores.md)
records explicit sizes, finite portion-group validation, the warehouse reference
repair, and their measured results.

The [exact quantity-role follow-up](../../../project/lanes/E-symbolic-stores.md)
records shared numeric-token consumption, the repaired scientific-notation
default-serving fault, final artifact bindings and independently calculated probes.

The [whole-order follow-up](../../../project/lanes/F-symbolic-stores.md) records
quantity/item binding, unchanged-state refusals, transaction tests and its limits.
