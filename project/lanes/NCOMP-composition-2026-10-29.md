# Exact learned fragment and outer composition

Owner: native_composition deputy; 2026-10-29. Root integrates and runs checks.

## What changed

The real native language reader now proposes programs assembled from learned
fragment regions and learned outer questions, alongside its existing whole
question programs. A relation-and-concept fragment can feed a count question;
two fragments can feed an intersection or any other admitted outer skeleton.
The same native compiler checks operation types and dependency rebasing. The
same execution, answer agreement, answer-form veto and evidence-selection rules
handle whole and composed alternatives together.

`composition::match_composed` accepts the leased SQLite connection, normalized
question, separate fragment and outer lexical spans, level, release policy,
existing `MatchLimits`, request budget, and a nonempty-fragment callback. It
returns `Vec<grammar::MatchedProgram>`. The integrated callback compiles typed
entity-producing fragments and runs every entity stage under the language
execution guard before admitting them. In particular an empty fragment cannot
answer a count question with zero. Unsupported or malformed fragments cause an
explicit error rather than silently eliminating a possible reading.

The matcher now starts with complete learned outer questions. X edges are
bounded lexical-boundary holes, not locally enumerated fragment readings. Only
regions used by a complete outer template become memoized fragment subproblems.
Each region is parsed once with its exact requested endpoint; unrelated local
endpoints never spend the completed-binding limit. Outer readings whose holes
lack a fragment parse are removed before data execution. The remaining demanded
fragment programs share viability checks, and joins enumerate only their admitted
alternatives under explicit bounds. Unused local fragments never execute or
invoke the typed compiler.
The matcher walks the existing template B-tree by prefix. It starts only at
lexical fragment boundaries, shares the mutable search path, and stores each
syntactic region/program once. It does not enumerate span powersets. Prefix work,
complete bindings, steps, retained matches and materialized bytes are bounded;
exhaustion fails rather than returning a truncated answer. Equivalent fragment
programs share their viability check across regions. Fragment witnesses retain
region offsets, exact template, support and expanded program in each composed
reading's serialized template metadata.

## Source contract and limits

The implementation follows pinned
`var/runtime-architecture-20261028/source/workbench/swarm/reader_v7.py`:
`fragments` requires lexical first and last items, allows internal literal glue,
and limits regions to `MAX_FRAG_W = 30`; `read7` splices X fragments into outer
skeletons and executes all alternatives. Source `found` uses different lexical
rules for fragments and outers; the consumer asks the existing native lexicon
for `compositional=true`, plural inference, and separate outer candidates.

This is the exact-key fragment/outer family only. Content fallback, segment
chains, nested fragments, analogy, clause/date wrappers and additional stores
remain. A matching learned key is an interpretation hypothesis, not a proof of
English meaning or source completeness. Positive fixture relations and concept
memberships are independently enumerated in the new contract; no dataset gold
answer was treated as independent truth.

`reader::COVERAGE` is now `whole_and_exact_fragment_outer_v1`.
`composition::COVERAGE` is `exact_fragment_outer_v1`. Existing image table format
and operation identifier `reader.whole` remain: the image already contains these
learned families. No durable session/profile schema changed. Admitted runtime
artifact identity must change with executable code as usual.

## Changed files and checks

- `native/oracle-core/src/composition.rs`: new bounded recognizer.
- `native/oracle-core/src/reader.rs`: real pure/Runtime consumer integration.
- `native/oracle-core/src/lib.rs`: public module export.
- `native/oracle-core/tests/composition_contract.rs`: twelve contract cases (ten public-reader cases and two direct demand/chart cases).
- This lane record.

Rustfmt ran successfully. Root's initial central build compiled; after fixing
fixture relation keys (`predicate`, not `relation`), all eight original composition
contracts, ten existing reader contracts and five release contracts passed.
Root's real 40-question run nevertheless regressed from 17 correct / 23 unknown /
0 wrong / 0 errors to 14 correct / 21 unknown / 0 wrong / 5 errors, with median
latency around 130 ms versus 2.4 ms. Four errors exhausted fuel and one compiled
an unsupported local fragment. Eager viability checks executed fragments with no
complete outer consumer. The demand-driven revision above repairs that mechanism;
its first central rerun passed all eleven then-current composition checks, ten
reader checks and Clippy. Real questions improved to 16 correct / 23 unknown /
0 wrong / 1 error, median 14.9 ms. The remaining failure was a local syntactic
fragment-binding limit on case 200, a population-qualifier question; local parses
still ran before knowing which regions the outer reader required. The current
outer-first region chart repairs that remaining mechanism and awaits central
rerun. Limits were not raised. No build, test, benchmark, commit or panel
scoring was run by this deputy, per root's centralized resource instruction. No theorem was
added and there are no new specialist-panel numbers.

Central checks from `native/`:

```
cargo test -p oracle-runtime-core --test composition_contract
cargo test -p oracle-runtime-core --test reader_contract
cargo test -p oracle-runtime-core --test runtime_release_contract
```

The existing `reader_contract` coverage assertion must use the new coverage
constant. New cases cover relation/filter composition, all-alternative ambiguity,
empty-fragment count refusal, whole/composed disagreement, unmatched outer
wording, answer-form veto, two-X intersection dependency rebasing, hard
search exhaustion, unused unsupported-fragment isolation, consumed unsupported
fragment refusal, and direct proof-by-callback that no unconsumed fragment executes
and identical consumed programs execute once. A further direct chart regression
supplies 450 irrelevant local lexical alternatives under a two-binding bound:
without an outer consumer it performs no fragment work; adding an outer question
that needs only Bob parses/executes Bob once and yields an actual What program. Central execution results and representative real-image
language deltas are pending. The consumer is already connected through
`Image::read_whole` and `Runtime::read_whole`; no separate demo entrypoint exists.

## Shared execution repair after composition4

The newly rebuilt composition4 extension still returned 16 correct, 23 unknown,
zero wrong and one fuel error on the same 40 questions (median 10.95 ms,
p95 160.7 ms). No claim of improved coverage follows from those results.

A read-only inspection of the immutable hbox reader image localized case 200.
Its outer search visits only 21/29 states at levels 0/1, with 37/85 prefix probes;
only two regions are demanded at each level. Lexical and parse SQL work is under
roughly 12,000 VM instructions. The expensive region is an administrative entity
filtered by its FIPS attribute. The level-1 learned fragment keys admit hundreds
of distinct FilterStr predicates over the same 548 source attribute statements.
Full-program memoization repeatedly materialized FindAll, read/decoded that same
column and compared the same source values against new literals. Parser pruning
cannot remove those real alternatives without changing meaning.

The current authored repair adds a request-scoped `query::LanguageWorkspace`.
It gives every complete typed node and its canonical dependency identities a
stable scratch slot. Identical stages share IDs, relation witnesses, attribute
positions and qualifiers across whole/composed candidates and both lexical
levels. Empty stages share too; each candidate still applies its own all-stage
emptiness policy, including unused branches and the Count exception. The cache
never crosses a worker lease, image, previous selection or reader request.

Attribute filters additionally share a typed source column for each canonical
parent stage and key. Each statement is decoded once. Exact string equality uses
a request-local value index, retaining every matching statement and qualifier;
other predicates use the same exact typed comparisons. Source rows are not
coalesced into an invented uniqueness claim. Typed arithmetic, units and temporal
precision retain their existing semantics. Aggregate cache rows and bytes,
including columns, index keys and stage metadata, are bounded by existing
materialization limits. No limit was increased. The lease's unconditional cleanup
removes all temporary rows even after an error or cancellation.

Additional changed file: `native/oracle-core/src/query.rs`. `reader.rs` now shares
one workspace across all fragment viability checks and complete question
execution. The old independent language evaluator remains a test-only comparison
surface. Four new unit contracts in `query::language_guard_contract` cover stage
identity despite local-index rebasing, exact evidence preservation, cached empty
stages versus Count/dead branches, aggregate bounds plus lease cleanup, and 500
string predicates sharing a 100-statement column within 500,000 fuel.

Central scoped command for those authored contracts:

```
cargo test -p oracle-runtime-core --lib language_guard_contract
```

Run alongside the twelve composition contracts, existing reader/release
contracts, Clippy, and the rebuilt same-40 reader comparison. Rustfmt succeeded;
this shared-execution revision has not been built or tested by the deputy.

Terra's review caught a string-index mismatch before qualification: structured
string equality uses Unicode lowercasing, whereas the initial cache used raw
text keys. `value.rs` now supplies the same `string_equality_key` helper to both
the comparator and column index. Literal trimming remains in literal parsing;
source whitespace remains significant. A fifth new unit contract compares full
cached and uncached results, including statement positions and qualifiers, for
mixed ASCII case, Turkish dotted I (including its expanded lowercase spelling),
accented Latin, Greek, significant source whitespace, missing values, and both
explicit/inferred string kind. Lowercase-key storage bytes are included in the
aggregate cache accounting. No central check has run on this correction yet.

## Final centralized checkpoint

The integrated shared-execution revision passes nine core language-guard checks,
twelve composition contracts, ten existing reader contracts and five runtime
release contracts. Combined Clippy passes. These are root's centralized results;
the earlier failed runs above remain part of the engineering history.

The paired, predeclared 100-question comparison uses identical cases, image and
limits. Current language execution returns 36 correct, zero wrong, four refused,
60 unknown and zero errors; retained whole-only execution returns 35 correct,
zero wrong, four refused, 61 unknown and zero errors. The original 40-question
prefix is restored to 17 correct, 23 unknown and zero errors. Median latency is
10.0 ms versus 2.08 ms; p95 is 30.7 ms versus 20.1 ms. This is one additional
correct answer with a measured latency cost, not general reader parity.

The gained answer, source case 10205, was independently checked against every
relevant Matt Lucas education, public-university and University of Bristol
qualifier candidate. Exact retained results, scope and artifact identities are
in [language/chemistry reader evidence](../../native/evidence/2026-10-29-language-chemistry-reader.json)
and [central domain validation](../../native/evidence/2026-10-29-language-chemistry-domains-validation.json).
No new theorem or specialist-panel score is claimed. The real Image/Runtime
language consumer is integrated; segment/nested/fallback/analogy and clause/date
coverage remain outstanding.
