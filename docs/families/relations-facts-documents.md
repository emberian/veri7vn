# Native relations, ordered facts and quotations

This initial family slice implements native HOL kernels, concrete versioned source
fixtures and regression statements. It does not yet have a deployed admitted service
operation. The native statements require steward compilation before they count as
checked evidence. No generated receipt is treated as a theorem or a world fact.

## Interfaces and evidence scope

`Relation_Query` uses open typed `(entity, property, value) relation_row` records.
`relation_values` filters a pinned finite snapshot, retaining identity and
collapsing duplicate values before `classify` distinguishes absent, unique and
multiple values. `subject_bucket` is an index seam: `indexed_lookup_refinement`
states equality with the unindexed query. `query_relation` separately represents
source dependency failure, incomplete snapshot, failed guard, missing entity,
ambiguous entity and a relation result. A caller must establish the snapshot
closure and recognition/domain guard; passing `True` is not evidence of either.
`observed_relation_rows` consumes the shared `observation` type, retaining the
important distinction between successful source observations and world adoption.
These kernels do not construct an adoption premise.

`Ordered_Facts` returns the original first matching rule, including its typed
value, sentence and source reference. Recognition supplies explicit required and
excluded features and the shared upstream boundary order (narrative, gate, block,
question). The fact selector proves membership/applicability and first-match
precedence. It does not claim that input feature assertions prove arbitrary regex
recognition. `Literature_Facts` implements three source-backed representative
rules: Moby-Dick narrator, Ahab's ship and Pride and Prejudice authorship. Its
overlap case selects the narrator before the ship; a bare title cannot become an
authorship question. Original sentences survive independently of typed values.

`Document_Quotation` extracts half-open byte spans from a retained revision.
It rejects invalid bounds, non-byte inputs and expired documents. Result fields
retain original document identity, revision, route, date and optional authorship.
`quotation_exact_bytes` states literal slice preservation; no normalization,
command execution, entailment or source adoption occurs. The command-shaped
fixture preserves repeated spaces and newline, and unknown author remains unknown.
Historical answer scope must be supplied by the eventual typed document importer;
route/date fields alone do not prove an answer current or universally true.

## Source-backed checks

- `tests/families/facts-documents/check_source_instances.py`: six canonical
  source-regex recognition/guard/ordered-overlap cases in the actual upstream
  literature-v2 store. This check executes upstream Python as an oracle; Python
  is not part of native execution.
- `tests/families/relations/check_v1_fixture.py`: read-only query of the retained
  `relations_v1.sqlite3` verifies exactly Q170583/P50/Q36322 and author identity.
  `Novel_Relations` contains that observation as a finite typed fixture.
- Native sessions: `Veri7vn_Relations`, `Veri7vn_Facts`, `Veri7vn_Documents`, all
  dependent on `Veri7vn_Source_Semantics`. Use only the shared build steward.

## Remaining owned behavior and consumers

The available v1 fixture is not the missing deployed v2 relation snapshot. Full
per-reader parity still requires ordered handwritten/mined recognition, dropped
reader scoped decline, domain/role typing, dominance linking, convergence across
several entity candidates, inverse query limit-eight boundary, joins, temporal
and restatement guards, display projection and source-scale measurements. The
initial ambiguous-entity result is deliberately stricter than upstream's
convergent-answer path and must not be reported as parity for that path.

The typed feature kernel needs a checked lossless interpretation producer; it is
not an implementation of Python regular expressions. Three literature instances
do not migrate every FactsOrgan store or its boundary variants. Retrieval ranking,
corpus completeness, multipart outcomes, private-source lease checking and full
historical answer metadata remain work.

Assembly reports the current service gate supports only the fixed mathematics
operation and admitted kernel descriptors. Production integration requires this
family's opaque instance/operation/prepared/output objects, registered native
operation carrier, executable pin, accepted implementation contract, shared
registry codecs, modeled positive cost, request/output association and managed
release. A fixed typed adapter must enter through the existing private Tickets
factory under the one resident Owner. No competing registry, callback gateway or
publication API is introduced here. Source coverage belongs in native result and
requirement qualifiers, independently of assurance route. This extension is outside
the current first service compiler batch and remains an explicit dependency.

## Source-row adapter follow-on

`relations/import/Relation_Source_Import.thy` consumes the existing shared
`source_batch`, not a second binary codec. Its four-column schema preserves SQL
NULL/type distinctions and exact literal bytes; entity/property magnitude cells
become arbitrary precision natural IDs. It rejects an entire batch on any malformed
row. `decoded_rows_preserve_length` and
`malformed_row_rejects_whole_batch` make that behavior explicit.
`query_relation_batch` derives materialization completeness from the actual shared
snapshot. The source owner must still license that snapshot's population/selection
scope. `incomplete_batch_never_unique` prevents a partial input from manufacturing
a unique answer. This additional session is queued separately from the original
three-session kernel feedback; it is not included in their evidence.

## Native feedback log

First steward attempt (`7869cf096baeb427`, attempt
`f8f47c3554dc4162918172cc9d4f68d3`) stopped at theory loading: the three short
`Source_Provenance` imports were interpreted as local file paths. They now use
`Veri7vn_Source_Semantics.Source_Provenance`. No theorem was checked in that
attempt. The original three sessions are refrozen for the coordinated retry.

The coordinated Capability6 attempt (`07b124775a6a4e938a7b92351a474e53`)
compiled **Veri7vn_Documents successfully in 8 seconds**. This checks
`quotation_exact_bytes`, `quote_span_length`, expiry rejection and the literal
command/unknown-author/bounds examples against the shared native source parent.
The overall job was interrupted for an unrelated effects-order simplifier;
Facts and Relations had not started, so it supplies no evidence for them.

The follow-up attempt (`776599a83800952d`, attempt
`740b382bf49a43ff99bd0642ee8aabc9`) compiled **Veri7vn_Facts successfully in
8 seconds**. The original ordered-rule soundness/precedence, boundary guard,
selected-rule origin and representative literature proofs now have native evidence.
Relations reached two proof failures: eliminating a unique classifier result and
extracting a source witness from `map_filter`. Explicit singleton-classification
and payload/list induction proofs replace the failing automation; a narrow retry
is pending. These repairs do not change the query or observation contracts.

The producer continuation adds `acquire_and_query_relation` and
`acquired_relation_refinement` in the family adapter. The output contains the
actual qualified batch observation alongside the tagged relation result. The
statement retains `manifest_matches`, well-formed decoded snapshot, exact encoded
bytes, original `attach_batch` observation and evaluation of that same batch.
These statements await the adapter's first compilation.

The source owner's clarification is material: `complete_materialization` is
source-declared observation data. It does not itself establish world coverage or
that a selected source population is exhaustive. Native absence/uniqueness may be
reported relative to the selected, declared-complete snapshot only; a stronger
source/world interpretation requires the exact retained coverage/adoption premise.
The closed shared SourceAdmission/RI extension owns the managed raw/native output
association, dependency IDs and lifetime. The family bridge supplies no alternative
issuer or raw-batch capability.

Root approved the first closed operation as **structured snapshot query**, with
`structured_relation_request = SnapshotRelationQuery entities property`.
`run_structured_relation_query` consumes that explicit native request and an actual
retained batch. `structured_relation_snapshot_meaning` states the exact schema,
decoded-snapshot, incomplete, absent, unique/multiple and ambiguity outcomes.
`acquired_structured_relation_refinement` retains acquisition provenance and that
meaning together. These new adapter statements are pending their first build.
Linkage owns the existing shared RI/kernel/private source-gate extension and uses
this same request carrier. This operation makes no natural-language/domain claim.

A future relation reader must associate original input, reader identity, exact
alias/entity candidates and native subclass/domain evidence with this same
structured request. It then consumes the same retained snapshot query result.
Missing v2 data and unimplemented linker/domain proofs remain required work; a
frontend boolean or profile label cannot discharge them. No parallel query API is
needed to add that interpretation license.

The narrow Relations attempt (`1b2f4ba0d06662c5`, attempt
`1180c32098684ea988d6ca8298775606`) failed in 18 seconds on the reserved Isar
fact label `values` in the explicit singleton proof. It is renamed
`selected_values`. No algorithm or theorem statement changed; the narrow retry
remains steward controlled.

The shared consumer source is now implemented by linkage and co-reviewed:
`source_relation_snapshot_judgment` in
`src/isabelle/admission/source/Veri7vn_Source_Admission.thy` retains the matching
manifest, well-formed same encoded batch, exact qualified observation and structured
snapshot meaning. RI retains the evaluator, acquisition and incomplete-result
contract basis. The private association captures the same source/manifest owners,
dependencies and revocable result roots, and uses the distinct
`QualifiedRelationSnapshotQuery` operation. **This integration source remains
uncompiled; no deployed family/service consumer pass is claimed.**

**Veri7vn_Relations now passes** in the narrow attempt
`501699bc988243229d1330c68c7bbadf` (session 9 seconds; Relation_Query 2.296
seconds, Novel_Relations 0.077 seconds). Exact receipt/log and compiled parent
source bodies are archived in `tests/families/relations/evidence/`.
All three initial family kernel sessions now have individual native passes.
The import adapter and shared source/RI/worker consumer are still uncompiled;
their presence in broad input hashes is not execution evidence.

Language owns the first representative source question consumer in its existing
native source front: whole `who wrote TITLE?`, versioned reader key 50 and exact
source-label candidates produce the same `SnapshotRelationQuery`. Real fixture
labels Q170583/Pride and Prejudice and Q36322/Jane Austen are retained v1 records.
No shared family resolver or complete v2 alias index currently exists. Authored
ambiguity bindings are explicitly test fixtures. A bare logical response does not
own source data; actual emission must retain the existing acquired observation,
configuration/selection and private source owners. In particular, the novel
fixture's absent P577 is absence from its selected finite rows, not absence from
the complete Q170583 source population or the v1 corpus.
