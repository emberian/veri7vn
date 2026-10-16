# ConceptNet source adapter

`conceptnet-edge-exact/1` observes the locally retained original ConceptNet
specialist SQLite `edge` table through the existing `SqliteObservation` /2
stream producer. It retains all eight original cells (`rel`, `start`,
`start_pos`, `end`, `end_pos`, `weight`, `surface_text`, `dataset`), including
NULLs, duplicate rows, original UTF8 bytes and observed binary64 confidence bits.
The source-row importer remains the only production parser. Extraction uses an
explicit full-row SQL ordering; row ordinals identify the retained observation,
not SQLite rowids or globally meaningful concept IDs. A bounded prefix retains
its incomplete footer and exact extraction policy.

`observeChainView(source, via, target)` acquires a proposal-selected view through
the importer's typed text/DNF predicates: IsA rows matching the proposed first
hop, or incoming assertions at the target. Its default prefix bound is 45 rows.
The returned canonical `Report.selectionPolicy` must become the manifest selection;
it retains exact SQL, parameter values, ordering and configured bounds. This is
an evidence view for a candidate path, not discovery of every corpus chain.

The native profile builds an exact byte-label dictionary from the original rows.
Dictionary numbers are internal positions with a checked inverse association;
they are not source evidence or persistent identities. The fixed sibling
`ConceptNetQuery nv ne source target` consumes the same acquired source carrier
as the other closed source requests. Its source-kernel integration must retain
the source owner, original wire version, observation/adoption conditions and
lifetime. Neither this pure adapter nor a Scala report creates native authority.

The optional `Veri7vn_ConceptNet_Acquisition` proof leaf consumes the whole common
source association. Its refinement retains the original versioned bytes, matched
manifest and the same attached observation, alongside the independent ConceptNet
path meaning. Cached row and payload dimensions equal the worker's dimensions;
`associated_concept_budget` therefore charges without traversing source rows.
This leaf creates no new acquisition or authority. Its fixed native producer,
C02 admission, lifecycle/recovery consumer and bounded public serializer still
require qualification by the source owner.

Confidence is an exact signed integer scaled by `2^1074`: all finite binary64
values have an exact representation, including subnormals and signed zero.
NaN and infinities reject the profile. Integer confidence has the same exact
scale, subject to a declared 128-byte integer magnitude bound. Graph edges have
unit hop costs. Confidence never becomes an additive shortest-path cost.

The current query observes a bounded IsA path, using confidence-descending,
start/end lexical ordering with ordinal ties, eight candidate rows per start,
and minimum confidence one **after** the eight-row cap. It retains duplicate
assertions. The target must have at least thirty incoming IsA assertions in this
observed view, independently of confidence. This is a category heuristic, not
proof of sense consistency. Search has depth three, up to four hundred expansions,
and the existing graph work/materialization guards; a conservative charge computed only from retained row/cell dimensions precedes
decoding, dictionary construction and sorting. The pure entry point rejects
over-budget inputs before projection; the charged worker then uses the actual
graph guard. Work units do not establish CPU-time or memory isolation.

`concept_render_reply` projects explicit `Source row:` captions with exact labels,
part-of-speech cells, dataset and surface text, paired with each unchanged raw row.
These byte strings are plain source data for the existing escaped text emitter;
they cannot be interpreted as HTML or replace native source/adoption conditions.
Numeric confidence remains in its exact structured cell rather than an invented
decimal rendering.

Every positive path retains its exact dictionary, original source rows, checked
graph result and observed completeness flag. Zero-hop paths cannot produce source citations. Native lineage lemmas connect graph
row keys to the original eight-cell rows and retained confidence/relation. Other
graph results remain `ConceptInconclusive`, including finite-view `Unreachable`.
Unknown labels and degree rejection are scoped profile dispositions, never claims
of corpus absence. Materializing every row of a selected query does not establish
coverage of the full ConceptNet corpus. Per-node truncation also prevents global
shortest-path or absence claims.

The upstream adapter strips case/whitespace and heuristically removes a plural
`s`. This profile deliberately requires exact labels instead. A future lexical
resolver must retain its alternatives and explicit choice; it cannot equate labels
by silently normalizing them. Same-label sense crossing remains possible. The
actual original corpus contains `robin -> bird -> meat`; the regression deliberately
preserves this as a source-chain observation. It cannot assert that a robin is meat.
IsA transitivity and world truth require separate declared model/adoption conditions.

## Checks

`tests/sources/conceptnet/check.scala` compares 257 ordered original corpus rows
against an independent JDBC framing oracle, including every one of the eight
cells, exact REAL bits and the incomplete /2 footer. It also compares the actual
45-row proposal-selected view against an independent prepared JDBC query and
writes the producer wire plus selection policy to ignored local test artifacts.
The corpus is read locally;
no service is contacted.

Run the Scala check through the shared build steward first, then generate the
transient original-corpus oracle fixture before building the native test session:

```sh
python3 tests/sources/conceptnet/original_fixture.py \
  tests/sources/conceptnet/ConceptNet_Original_Fixture.thy
```

`Veri7vn_ConceptNet_Tests` checks binary64 one/subnormal/negative zero/nonfinite
behavior, numeric-schema rejection, synthetic duplicate source-path lineage and
the actual adapter-produced wire through native /2 materialization, equality to
the independent original-corpus row oracle, and generated native graph execution. The
generated corpus fixture is ignored rather than committed. Build and source-kernel
consumer qualification are reported separately; compiling this pure profile alone
does not establish admitted resident-service linkage.

This first profile covers exact-label bounded IsA path observations. The original
adapter's natural-language question routes, reverse/non-IsA retrieval,
neighborhood summaries, legacy surface rendering and lexical-resolution proposals
remain separate consumers; their behavior is not established by this path profile.
The original corpus is available at
`upstream/root/fable-content/oracle-m-series-2026-08-15/m13e5_conceptnet_build_a_v1/conceptnet_specialist.sqlite3`; absence of a
resident integration or a pending build is not reported as missing corpus data.
