# Finite conversation routes without an Engine

31 October 2026. Sol source lane. No specialist panel numbers. No Engine, build,
or test run in this lane. The reference rows below came from bounded, read-only
SQL against the actual retained public stores. They are data fixtures, not a
proof of either store or of full Oracle7 parity.

## The two source snapshots disagree

| Subject and property | U8 `relations_v2` complete object set | Native reader image v3 complete object set |
| --- | --- | --- |
| William Shakespeare, Q692, birthplace P19 | Q189288, Stratford-upon-Avon | Q189288, Stratford-upon-Avon |
| Walt Whitman, Q81438, birthplace P19 | Q18438, Long Island; Q3461211, West Hills | Q18438, Long Island |

U8 receipt: `97286fb824bb102a24ac9e7458fc8d8426212ad0bff2b585bd00d6e0462d00a5`.
Its relation store declares SHA-256
`7df5c620982634e7ed6ff097f7d9082605cc879e9ee938d36d6a14af11cc4095`.
The native image receipt declares SHA-256
`8fcb1db9a08e234179f66ea9e032d2633b38cdcb902f4c95d1ba2c2d49c842f4`.
The exporter checks receipt bytes and store size. It does not silently claim to
have rehashed these large stores; observed full-store hashes are null unless
explicitly requested.

A native-image answer about Whitman is an answer from that image. It cannot also
claim U8's unique-answer behavior. A U8 projection containing both birthplace
edges must refuse to choose one. Missing edges in one dataset are not evidence
that the other dataset's extra edge is false.

`wd:Q692` is William Shakespeare, not Walt Whitman. Names never establish an ID.
The native image uses `Q692`; the U8 projection uses `wd:Q692`. Their conversion
requires the deployment's explicit Wikidata namespace declaration. Arbitrary
image IDs must not acquire a `wd:` prefix by string manipulation.

## Remove scaffolding, retain the delivered-state boundary

The existing finite adapter never calls arbitrary `eng.chat`. Its full Engine
startup exists to construct an object with cache dictionaries, import source
modules, borrow `chat_context_v2._STATES`, and locate the public receipt. None
of those are required by the finite route meanings below.

A native profile should own a typed native answer-context extension and use the
existing core candidate/commit boundary. It should not manufacture an
`OracleAdapter` snapshot or silently migrate an unknown legacy Python session.
The admitted image/source identity, tenant, session, revision and request binding
remain part of the core transaction. Candidate evaluation is speculative. Only
the winner changes state, and exact response bytes commit with that state.

The approved first native owner is `native_conversation_context` version 1,
operation `context.native`. Its anchor is Empty, Entity referring to the exact
current singleton selection, or Quantity carrying a rational string, unit and
NumericOrigin. It does not duplicate IDs, labels or person metadata. It retains
provider source and immediate-parent derivation metadata. Provider observation is
a host-only API, not an authority-bearing JSON observation supplied by a caller.

This native profile deliberately does not reproduce Python's answer/subject/topic
role priority. The source compatibility contract below records that extra
behavior so it cannot accidentally be advertised as implemented. The native owner
also makes no claim to import or consume Python PendingInterpretation. Native
reader selection remains separate: a quantity or acknowledgement must not
accidentally become a new entity selection.

## Route contracts

| Route | Whole input admitted by the current bounded adapter | Required public data | Delivered transition |
| --- | --- | --- | --- |
| Acknowledgement | `ok`, `okay`, `got it`, `thanks`, `thank you`, case-insensitive, optional final `.` or `!`, surrounding whitespace | None | Preserve entities, quantity, scalar, pending interpretation and reader selection. |
| Topic prefix | `new topic:`, `switching topics:`, `change of topic:`, case-insensitive at the start | None | Propose empty entity/quantity context before the remaining route. Install the reset only if that route wins successfully; refusal preserves the entire prior state. |
| Quantity scale | `Multiply/Divide that/this/it by <nonnegative decimal>`, optional final `?`, `.`, `!`; current adapter permits initial capital or lowercase verb | None | Multiply/divide the retained quantity, retain its unit, clear dimensionless scalar, consume pending interpretation only upon delivered success. Division by zero is a semantic refusal preserving prior state. |
| Quantity cost | `What does that/this cost at $<nonnegative decimal> per <alphabetic unit>?` | None | Same exact-case unit symbol, or the explicitly admitted J-to-kWh conversion factor 1/3600000. Result unit is `$`; clear dimensionless scalar; successful delivery consumes pending interpretation. |
| Person birthplace | Direct question after typed resolution: `Where was <retained person label> born?` | Complete P19 objects for the retained subject ID, object labels; source-bound person metadata | Exactly one object and a label produces a typed answer. Zero/multiple objects refuse while preserving prior state. |
| Author | `Who wrote <name>?` | Complete name candidate policy, complete P50 objects, labels/classes | This requires an additional name-linker closure. Do not call it implemented merely because retained-ID birthplace works. |
| Scalar arithmetic | w29 admitted grammar plus the adapter's complete lexical coverage guard | No factual store | Keep the parsed value and declared precision origin, write dimensionless scalar and quantity, clear entity roles/solved/material; successful delivery consumes pending interpretation. |
| Physics | `What is the <quantity> when the <given> is <number> <unit> ...?`, through `grow60.read` | Immutable admitted parts, units, formula programs | Read all admitted plans for the same quantity/dimensions; every usable plan must agree under the source tolerance. Preserve output unit and approximation origin. |

The table records the current finite compatibility profile, not all natural
language accepted by Oracle7. A new native grammar may deliberately accept a
smaller whole-input subset; declare that boundary and refuse the rest. It must
not accept leftover punctuation or words accidentally discarded by a tokenizer.

For person pronouns, the actual `chat_context_v2._person` precedence is answer,
then subject, then topic, choosing the first person. After birthplace delivery,
the selected answer may be a place while the subject remains the person. Repeated
`Where was he born?` must therefore use the retained person role. A raw graph
`Previous` selection is insufficient if that selection now names the birthplace.
Execute the graph plan against an explicitly derived transient person selection,
without committing that speculative replacement, or expose a checked explicit-ID
query seam. Never relink the person's label to recover identity.

For first native coverage, execute an explicitly admitted whole entity-follow-up
form against the approved current singleton Entity anchor, using `Relate` with
predicate `place of birth`, direction `forward`, and `UniqueName`. No native
name-linking fallback is needed. If the accepted wording includes a person
pronoun, it does not by itself establish person metadata. After a place becomes
the current anchor, the new native owner cannot promise Python's repeated-person
continuation; refuse unsupported forms or document the narrower selection-based
meaning. Retaining Python subject roles would require a separate approved owner
extension, not hidden parallel state.

## Exact relation-store closure

U8's store query should be bounded by the explicit subject/property scope, not
by an arbitrary row limit:

```sql
SELECT p,o,lit FROM fact INDEXED BY fact_sp
WHERE s=? AND p=? ORDER BY o,lit;
SELECT label,enwiki FROM entity WHERE qid=?;
SELECT o,lit FROM fact INDEXED BY fact_sp
WHERE s=? AND p=31 ORDER BY o,lit;
```

The source adapter uses nonzero object IDs and deduplicates their set. Literal
rows are still exported so their presence is explicit. Labels use `label`, then
`enwiki` if the label is empty. Source person metadata is direct P31=Q5, not a
name guess or an unrestricted subclass inference. The current P50 adapter
hardcodes the answer as a person; a native replacement should obtain real class
metadata and identify that as an intentional correction, rather than claim
that assumption as a theorem.

On the native image, use complete rows for `(subject, predicate, direction)`;
retain qualifiers in evidence even when the object set deduplicates them.
`UniqueName` can distinguish absent, ambiguous and unique within the admitted
image. A finite imported U8 fixture must declare that it contains complete rows
only for its enumerated scopes. It must not impersonate a complete U8 store.

Highest-leverage direct data implementation: retained-ID P19 over the already
admitted native image, with the complete U8 projection as an independent
source-difference control. This removes generic Engine, names linker, runtime
fold loading and background reader-cache compilation from the entity journey.
Pure quantity/acknowledgement routes remove those dependencies as well.

## Precision, pending state and refusal

The adapter formerly compared cost units after lowercasing, which incorrectly
identified mJ and MJ. This was a handwritten adapter defect, not an upstream
source rule to preserve. The repaired adapter admits exact-case identity and
only the explicit J-to-kWh cross-unit pair. A mismatch returns semantic withheld
and preserves prior state. This changes the helper digest and therefore its
source pin: old helper-bound snapshots cannot silently import into the repaired
helper. The source U8 receipt remains unchanged.

Native exact rational calculation can be exact over retained decimal tokens while
the original measurement remains rounded. Preserve `python_float` or
`displayed_decimal` limitations from the input; do not relabel those quantities
as exact source facts. State provenance should distinguish the operation's
exactness from the source quantity's precision. An acknowledgement or unchanged
restore preserves the origin. A unit-bearing result never populates the
legacy dimensionless scalar slot.

The Python compatibility adapter currently computes scale/cost with `Fraction`
then casts to a Python float and declares that origin. A native rational kernel
will differ at rounding boundaries. Record the deliberate new profile semantics
and compare typed values, units and origin, rather than promise identical Python
float bits or response formatting.

The following pending-state rules describe the existing Python compatibility
profile, not a claim made by the new native owner. Pending interpretations are a
separate owner. Acknowledgement and every semantic refusal preserve them. Successful projected answers and successful scale/cost/
scalar/entity routes consume them. Native evaluation must not consume Python
pending state just because it considered a candidate. Unknown legacy pending
coverage requires reset or a declared unsupported continuation, not empty state.

Known bounded no-answer branches produce semantic `withheld`, preserve the whole
prior context, and still commit a refusal revision. Source/pin mismatch, corrupt
rows, malformed values, resource failure and unknown provider status remain
operational errors. They must not be converted into a benign semantic refusal.

## Physics and scalar breakpoints

`grow60.read` supplies quantity names, seven-dimensional SI keys and converted
values. Its planner has depth three, uses each given exactly once, and prevents a
part ID from appearing twice in a plan. `run_plan` scales each input to its
part's units, runs the formula, scales output back to SI and rejects nonfinite
values. `ask` accepts all usable plans only if they agree within
`1e-6 * max(abs(first), 1e-300)`. Decline kinds are exactly `form`, `no_part`,
`no_value`, `disagree`; the thin `voice10.Physics.ask` wrapper drops those kinds.

The concrete admitted fixture formula `solved-kinetic-energy-2` consumes
mechanical energy J and potential energy J; its program computes their
difference. It does not consume mass and speed. A native verified subtraction
kernel bound to that exact formula manifest is a useful first physics closure.
Do not dynamically execute all Python programs merely to claim a native kernel.
Full planner parity additionally requires the admitted unit vocabulary,
matching rules, all alternative plans, scale factors and tolerance semantics.

w29's tokenizer discards unmatched punctuation. The adapter's no-gap lexical
guard is necessary: `2 + 2%` must not silently become `2 + 2`. Its exponent bounds
and recursive grammar are additional resource/semantic premises. Native exact
arithmetic should be named as its own supported kernel, not as a claim that every
w29 floating-point answer is preserved.

## Reference artifacts and checks

`tools/appliance/tests/export_relation_closure.py` imports only the Python standard
library. It opens SQLite with `mode=ro&immutable=1`, accepts explicit positive
numeric subject IDs and P19/P50, exports complete scoped rows, and never imports
Oracle7 or executes formula programs.

`tools/appliance/tests/relation_closure_u8_native_v1.json` is the exported
Shakespeare/Whitman P19 comparison. It includes actual labels and direct P31 rows,
both source identities, explicit coverage scopes and uncomputed full-store-hash
markers. It is not a fabricated Hamlet relation. A manufactured native Hamlet
fixture, if used, remains labeled separately from these observed source rows.

Reproduce the bounded read-only export from this checkout:

```sh
python3 -B tools/appliance/tests/export_relation_closure.py \
  --checkout var/appliance-20261029/candidate-u8 --qid 692 --qid 81438 \
  --native-image var/data-20261029/reader-image-v3.sqlite \
  --native-receipt var/data-20261029/reader-image-v3-receipt.json \
  --out tools/appliance/tests/relation_closure_u8_native_v1.json
```

No tests, Engine runs or builds were performed for this contract. Consumers are
the native context owner, the host candidate dispatcher, source admission and
the central validator. Required checks are scoped positive/ambiguous/absent
source rows; repeated person follow-up after a place answer; topic/refusal and
pending preservation; unit/origin preservation; exact response replay and
restart; and source identity mismatch before dispatch.
