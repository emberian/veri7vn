# Targeted composition cases over independently checked source rows

Owner: native_segment_reader. Consumer:
`native/tests/qualify_composition_cases.py`, run centrally against the retained
old and new native artifacts. This is a targeted demonstration, not a fleet or
specialist-panel score. No new theorem statements or panel numbers.

## Predeclared scope

Authored files:

- `native/tests/qualify_composition_cases.py`: independent read-only source
  verification and two fresh-process reader comparisons.
- `native/tests/composition_cases_targeted_20261029.json`: 16 fixed questions,
  expected entity IDs/answers, source constraints, learned wording prerequisites,
  primary canonical template absences and selection limits.
- This report.

No production reader, existing control, deployment or delivery files changed.
No native code, native calls, builds, tests or benchmarks ran in this lane.
Python syntax was parsed with `ast.parse`, the cohort JSON was parsed, and named
whitespace checks passed. Read-only SQL source inspection is described below.
The original predeclared cohort is frozen; the failed central result is recorded below.

## How the questions were selected

The immutable image is
`8fcb1db9a08e234179f66ea9e032d2633b38cdcb902f4c95d1ba2c2d49c842f4`,
bound to KB source
`04da7408320c5cb7023c44372cce32846d56d369d8865d2e61a18c3956661a7c`.
Inspection used SQLite `mode=ro&immutable=1` and `PRAGMA query_only=ON` on the
existing hbox image. No image or large data copy was made.

Before any native observations, source queries enumerated cities with an
observed official website, positive integral population, city membership and
a university location/headquarters edge. The first three distinct city IDs in
SQLite text order are Saskatoon (`Q10566`), Belfast (`Q10686`) and Cardiff
(`Q10690`). Their least observed populations are 222189, 333871 and 346100.
Bristol (`Q23154`, population 442500) is an explicitly hand-selected familiar
anchor, added for a six-person count/ambiguity pair and a second relation.

All four website values uniquely identify their city among the image's
entities. The population values and their dates/qualifiers are retained as
source evidence by the script. The questions ask for a recorded value; these
are not claims that the populations or websites are current.

The source's learned exact rows include concept and website/population segment
units, nested `C1 located in X1`, `C1 headquartered in X1` and `C1 born in X1`
fragments, plus `which X1` and `how many X1` outer forms. The combined primary
literal-key and generic attribute-slot whole/fragment wording in the cohort
has zero rows. That is a finite-table observation, not proof that all possible
lexical readings are absent. Only the actual old/new comparison can establish
which questions become answerable.

The 16 questions include one existing single-filter control; new combinations
and reversed filter order; nested relations over exact and segment-built inner
fragments; source counts; two ambiguous single-answer requests; and four empty
cases. The empty cases deliberately change a population by one, mix a website
and population from different cities, or select a relation with no stored
university target. They are retained alongside the positive cases.

## Independent expected answers

The source check uses entity/parent/attribute/forward-edge tables directly,
without importing the native module or reading a validation gold answer.
Recursive SQL computes concept membership. Strings compare exactly; the only
numeric constraints are exact integral quantities with unit `1`. Each result
is checked against the full predeclared entity-ID list, then unique entity names
or nonempty counts are derived from those rows.

The source witnesses independently yield:

- Saskatoon location: University of Saskatchewan (`Q1514848`).
- Belfast location: Queen's University Belfast (`Q877925`).
- Bristol headquarters: University of Bristol (`Q459506`).
- Cardiff headquarters: Cardiff University (`Q1035745`) and University of Wales
  (`Q1072029`), hence count 2 or a decline for a single-university request.
- Bristol birthplace: six distinct human IDs, hence count 6 or a decline for a
  single-human request. The rows name Stephen Merchant, Tom Hollander, Robert
  Wyatt, Michael Redgrave, Andy Williams and Cary Grant.

A separate bounded read-only inspection checked all 16 source-ID expectations,
all required learned wording and all declared primary template absences before
native execution: every expected ID list matched, no required wording was
missing, and no declared absent template had rows.

Every uniqueness, count and empty selection here quantifies over **all rows of
this pinned finite image**. That explicit coverage premise is part of the
cohort. It does not say the outside world is complete. An empty fragment asks
the reader to decline; it does not authorize a universal zero answer.

## Central recipe and retained outputs

The cohort pins old code `6cc653b`, artifact
`8324a59da075d16a7d3c7c07bb7fe85690479c65e1baf416741d5373b010e8b0`,
and new code `2fda9fe`, artifact
`499e9e46484e2e48760def00f1acd24ebcf3d5e63d445e9f72ce39e52a9c8858`.
Both use the same image and unchanged two-worker, one-second, ten-million-fuel
settings. The parent verifies independent source truth before starting either
native child. Each child verifies its actual extension bytes and opens a fresh
Runtime state directory. No program or expected answer is sent to the reader;
it receives the question alone.

```sh
python3 -B native/tests/qualify_composition_cases.py \
  --image /tank/lanes/o7-native-20261028/data/reader-image-v3.sqlite \
  --control-extension /tank/lanes/o7-native-20261028/binding-performance-20261029/oracle_native.so \
  --candidate-extension /tank/lanes/o7-native-20261028/binding-segment-stream31-release-20261029/oracle_native.so \
  --work /tank/lanes/o7-native-20261028/qualification-targeted-composition-20261029
```

Outputs retain the predeclared cohort and independent SQL queries/source
witnesses, every old/new observation and error, artifact identities,
interpretation families and program hashes. Positive misses remain misses;
operational errors never count as an expected decline. Wrong answers and errors
produce a failing exit code. One fixed-order control/new process pair supplies
descriptive timings only, with no matched performance claim.

## Cost question for later profiling

The source-wide cost of admitting additional language families is real. Prior
qualification found hundreds of syntactic base variants in a single real
question before semantic checks discarded most of them. Delayed nesting and
streaming ownership fixed the request failures, but they do not remove the
need to consider distinct learned interpretations.

A concrete next profile could count exact template lookups versus distinct
`(family, level, template)` keys, and base-program checks versus distinct shared
semantic stages on this fixed cohort. The current matcher can look up the same
learned rows again under different lexical bindings. A bounded request-local
row cache might avoid that repeated source work, with complete streaming when
full. That is a hypothesis to measure, not a production change or permission
to remove alternatives, elect a support winner or stop after a direct answer.

## Original frozen-cohort result

The [retained targeted receipt](../../native/evidence/2026-10-29-targeted-composition.json) records exit 1 and `qualified: false`. The original script SHA-256 is `d87b77c5f19d0e01de7ceb8258eb69ea562ff889ee4cd53175bed17f76d56195`; the original cohort SHA-256 is `388810fd2d99c1f25e2e53b0e906e21669915c7836a8fd1524967d755862b853`. Questions, expected facts, artifacts and bounds have not changed after observing results.

All 16 independent source expectations and learned-wording requirements passed before native execution. The old artifact produced ten unanswered positives and six expected declines. The new artifact produced one correct answer, seven unanswered positives with `answer_form`, four expected declines and four operational `composition bytes` errors. Neither artifact returned a wrong answer. The intended single-filter control also declined on both versions; its expected source fact remains unchanged.

The one actual answer gain is `nested_human_count_bristol`: the new reader returns 6 for the six independently enumerated human subjects born in the uniquely anchored city. Its readings report both exact segments and single nesting. This is one finite-source capability example, not qualification of the failed cohort or a broader gain claim.

The four operational errors are:

- `nested_headquarters_city_website_population_bristol`.
- `nested_university_count_cardiff`.
- `ambiguous_university_selection_cardiff`.
- `empty_parent_headquarters_saskatoon`.

Those errors remain errors, including the ambiguous/empty cases; they are not credited as expected declines. The complete observations and independent SQL evidence are retained in `var/composition-cases-20261029/`.

## Diagnosis boundary

Read-only source inspection verifies a reason for the form refusals. The exact learned outer template `which X1` contains a `Count` skeleton with support 2. Because `Count` has no hidden literal, the pinned source trust policy admits that replicated skeleton alongside the much more common `What` skeletons. The form rows permit entity answers for `which` and `which city`. The native result therefore contains both `1` and `Saskatoon` for the single-city case and vetoes the complete reading set, as Reader7's form rule requires. The same baseline refusal occurs in the old artifact. The other unique-entity misses similarly retain both `1` and the independently expected entity name. Reconstructing the Count programs from the source facts, without executing them, matches both retained successful-program hashes for the Saskatoon baseline: exact-fragment order `cd6e72edbc2591351c92ecacd643029b2cc34b4f02fdd43f4fef81d805ad36f2` and segment order `36c9ae673be15d55082762bb20207965ac86215c93a9cb52a68bc67ca25aaadd`.

This is learned source-admission conflict, not evidence that the native veto should be disabled. Removing the count reading to elect a preferred name would hide disagreement. A source repair would need independent review of the training examples and an explicit admissibility premise; the cohort does not supply authority to hand-edit a winning template.

The byte-error mechanism is not yet established. All four failures involve `headquartered in`; read-only lexicon inspection shows that `headquartered` introduces an `R` alias at level 1, unlike the inspected `located in` wording. That can open generic learned-template paths, but neither this correlation nor the short failure times establishes which owner consumes the byte envelope. A scoped follow-up should identify the failing phase and retained owners on these four unchanged cases before changing representation. Root subsequently authorized a temporary, bounded phase/retained-owner diagnostic for exactly the four unchanged failures. It separates outer syntax, region syntax, base validation and region resolution, while tracking net fragment/unit/recipe/cache reservations. No permanent production remedy, limit, expected fact or question has changed; central diagnostic execution is pending.


## Completed storage diagnosis

The [four-case diagnostic](../../native/evidence/2026-10-29-composition-byte-diagnosis.json)
completed before handoff. Every failure occurs in region syntax, before semantic
admission. Fragment storage plus active deduplication keys accounts for about
1,951,000 bytes, roughly 93% of the unchanged 2 MiB envelope; units account for
about 130,000 bytes. One cached base region contains 1,290 flat fragments.
Transient walker storage is zero and nested recipes account for 332 bytes.
These are logical accounting totals, not RSS measurements.

The proposed remedy is shared exact step/program storage and thin region records,
with flattening only at existing evaluator/output boundaries. It has not been
implemented. The dirty Rust files still contain temporary diagnostic errors;
remove that instrumentation before qualifying a production candidate. Preserve
all interpretations, child-region witnesses, bounds and original cohort facts.
