# Bounded local source import

The local acquisition adapter is `src/sources/import/LocalSnapshot.scala`. It reads
only explicitly provided inert regular files, rejects a symlink at the input leaf,
and checks a byte bound while reading. It neither executes SQLite nor contacts a
connector. Inputs and clocks are declared; a recorded receipt is not a new wall
clock reading. It does not rerun acquisition during restore or look up forgotten
locators. The returned immutable candidate is private staging data, not authority
or a newly published source snapshot.

Each candidate retains original bytes, payload identity and deterministic manifest
identity. The manifest retains source/version, acquisition, selection/query policy,
schema/encoding/recipe, optional license and provenance, qualifiers, rank, units,
references and known loss. Unknown fields remain `None`. Acquisition records event,
receipt and poll clock bases/origins separately, sequence/configuration/calibration,
quality policy and measured/simulated/unknown origin. Payload bytes and manifest
bytes are defensively copied; a receipt change changes the manifest identity but
cannot refresh the recorded event. Retention propagates to derived candidate data;
the host must retain/revoke it under the existing managed-source policy.

## Native row family and binary format

`Veri7vn_Source_Import.Source_Row_Import` is the source-row/1 native family. It
contains typed SQL NULL, signed arbitrary-size integer magnitude bytes, text bytes
and blob bytes. Text encoding and schema are retained in the source manifest;
these bytes are not silently normalized or reparsed. SQL REAL and other unsupported
storage classes require a separate versioned codec; there is no coercion here.
Integer byte representation can retain leading zeroes/negative zero while its
native integer interpretation is exact. Blob/text/NULL remain distinct.

Wire layout is `[83,49,full,columns,rows]` followed by row-major cells. Header counts
and payload lengths are unsigned bytes; at most 255 rows, 255 columns and 255 bytes
per cell are supported. Cells are tag 0 (NULL), tag 1 followed by sign 0/1 and
length+big-endian magnitude bytes, tag 2 followed by length+text bytes, or tag 3
followed by length+blob bytes. The default acquisition/bulk bound is 65536 bytes.
These are declared supported shapes, not a limit silently applied to arbitrary
SQL queries. Larger corpora need chunked import with checked chunk coverage, an
open consumer obligation. A full header describes this supplied materialization;
it never proves complete coverage of an external query or of the world.

The generated native decoder is the actual parser: Scala passes original bulk
bytes and does not implement a competing product parser. Native `decode_cell`,
`decode_cells`, `decode_rows`, `decode_snapshot` and `decode_wire` reject malformed,
unknown-version, truncated and trailing input. A malformed candidate retains raw
bytes for diagnosis but publishes no recovered prefix; corrected input can be
prepared independently. No partially installed snapshot is made visible.

`decode_encode_cell`, `decode_encode_row`, `decode_encode_rows`,
`snapshot_codec_roundtrip` and `wire_codec_roundtrip` state exact inverse laws for
the supported wellformed input shapes. `code_reflect Native_Source_Import` generates
the callable decoder from those native definitions. `Veri7vn_Source_Row_Codec`
implements the shared typed bulk signature with that generated module, bounded
before decode and by row count after decode. `Source_Import_Profile` declares the
actual `source_batch` carrier, decoder representation, shape and exact native codec
law in the shared registry. Declaration does not admit or activate the codec.

The native `row_index` consumes the actual decoded row population.
`decoded_population_coverage` is coverage of exactly `set (ordered_rows s)`, and
`row_index_count` counts its distinct selected rows. Order and duplicate rows stay
in `ordered_rows`; this index theorem makes no larger-source coverage claim.

## Observation and publication

`decode_observed` preserves event/configuration while assigning Valid decoded rows
or an explicit rejected reading. Native ingestion keys source identity+sequence.
An exact repoll differing only in receipt time is Duplicate and retains original
history; a different report under the same key is Conflicting and retains both.
New rejected or missing readings remain observations and remain in event-window
populations. Deduplication does not choose a winner or erase contradictory data.

Authoritative source publication must follow the existing native attempt spine:
StageIntent -> durable acknowledgement -> ClaimAndStart/current-authority handoff
-> acquisition -> Reconcile Confirmed -> native decoded snapshot/claim association
-> StageObservation -> durable acknowledgement. Source binding ID and snapshot ID
are distinct; the claim retains both, the matching request-owned confirmed attempt,
and actual native evidence. Retirement during pending acquisition prevents later
publication; revoke/forget also prevents use of retained dependent material.
The importer does not call `commitNative`, fabricate evidence, or introduce another
store policy. Host61/authority61 own that integration. A gate-owned output
continuation is still needed when acquisition determines a previously unknown
snapshot/claim; reopening a request is not a substitute for attempt ownership.

Current staging/gate consumers must import the reviewed generated codec context
or regenerate decoder and consuming row operations together. Separately compiled
lookalike datatypes cannot be cast into this carrier. Raw bytes, native decoded
batch, manifest/schema/configuration and snapshot identity must be associated by
the native source gate. This bridge and actual authorized publication remain open;
the family profile or a payload hash cannot replace them.

## Existing assets and unavailable originals

Existing availability evidence is `audit/results/availability.json` and the source
coverage audit. Fourteen materialized database assets are known; this task does not
rehash multigigabyte files or relabel v1 schemas as v2. Original
`relations_v2.sqlite3`, `names_v1.sqlite3`, `linking_src/labels.tsv` and
`linking_src/aliases.tsv` remain unavailable. The adapter exposes explicit
unavailable dispositions. No replacement corpus was fetched, and neither original
bit identity nor complete relation/name compatibility is claimed. Adoption of a
replacement requires its own source/version/license/schema/coverage disposition.

`Veri7vn_Source_Import_Candidates` is an opaque native proposal constructor: it
creates the exact family profile privately, invokes only the generated decoder,
and retains immutable raw bytes together with the actual typed decoded batch.
A different decoder/profile instance or generation cannot retrieve that batch.
It takes no arbitrary decoder/evidence callback and grants no publication token.
The remaining gate must bind this real proposal to the actual manifest/native
observation and matching source attempt; a caller-supplied hash or ID cannot mint
that association.

`Source_Row_Observation.thy` defines the concrete future output carrier
`source_batch source_assertion observation`; it does not cast rows into the existing
integer-observation family. `attach_batch` combines a unit-valued observation
metadata template and unit-valued assertion provenance with the actual batch.
All source/event/configuration fields and rank/units/references/loss/applicability
survive. `row_segments` retains each original qualified observation alongside its
batch. `row_population` is a row projection, while guarded `row_view` retains the
whole original population, requires the expected schema and column width and
wellformed batches, and exposes declared materialization separately. Missing,
rejected and partial batches prevent that materialization flag from becoming true.
It still conveys no external-world coverage. Row query/count/window plan integration
is owned by the plans and staged-execution lanes against this concrete carrier.

Native immutable `source_acquisition_requirement` fixes request/attempt/source
binding, source key, schema/configuration, recipe/selection, calibration/quality,
retention policy identity and bounds. `native_source_manifest` retains optional
source version/license/provenance, the full observation/assertion templates, poll
clock and policy fields. `manifest_matches` checks the required association and
requires a Missing payload template. `acquire_native` uses the real bounded decoder
and constructs the qualified output. `acquisition_result_sound` states its exact
byte/shape/metadata association; `acquisition_keeps_request_attempt_source` retains
the request-owned IDs. The native gate must associate those actual objects with
the host's confirmed input/attempt and immutable reserved requirement. Caller fields
or confirmation alone cannot supply that evidence. Scala manifest serialization
and the service's native object association still require their concrete transport
bridge; no correspondence is claimed merely because the records have similar names.

Forget cleanup is an owner closure, not just deletion of a locator. Scala candidate
`release()` clears its raw/manifest arrays and drops bytes, hashes and manifest
roots; stale access fails. Native candidate `release` drops raw/batch/profile/context
roots, and `release_decoder` drops its profile/generation roots. These calls make
no authority decision; only the existing authorized host closure invokes them.
It must also drain in-flight work, drop returned copies, typed runtime handles,
registry objects, private contexts, pending queues and managed indices/caches.
Previously exported/uncontrolled copies are outside that guarantee. No private
acquisition batch is installed in shared TheoryData by this adapter.

The importer inherits shared `Veri7vn_Codegen` before `code_reflect`, preserving
exact HOL nat/int meaning with the same compact target-integer representation as
its consuming finite bundle. Numeric code setup changes invalidate executable pins;
separately compiled unary and compact carriers cannot be cast together.

The payload decoder uses proved `consume_prefix`, traversing only the requested
prefix once rather than repeatedly measuring the entire remaining snapshot.
Byte validation is bounded to that prefix. Integer magnitude uses an accumulating
base-256 fold. Native manifest `source_encoding` is retained and must match the
immutable requirement's `required_encoding`; text bytes cannot silently acquire
a different encoding label.

Structural row equality is exact representation equality. Leading-zero integer
magnitudes and negative zero preserve distinct raw representations even when
`integer_meaning` agrees; `integer_representations_are_not_numeric_distinct`
exercises this distinction. `row_index_count` is consequently distinct native-row
representation count, not a proof of SQLite numeric DISTINCT. A numeric equality
query must use its declared native numeric interpretation/equivalence relation.

D37 adds `Cell_RealBits` with exactly eight unsigned bytes and wire tag 4. The
bytes represent the observed IEEE binary64 encoding, including signed zero,
infinity and NaN bit patterns; no conversion to integer/text or mathematical-real
arithmetic is licensed. This preserves values after the declared extraction
profile. SQLite or its driver may normalize values, map NaN to NULL, or otherwise
change representation before observation; this codec does not prove preservation
of SQLite on-disk bytes. Source schema/encoding and extraction recipe must retain
that distinction. Actual shipped REAL, long-text and duplicate-row evidence is in
`docs/coverage/classification/storage-preservation.md`. Native REAL arithmetic/order
refinement remains a required domain obligation; lack of that operation cannot
exclude all REAL source data or silently turn it into an integer query result.

The generic native predicates `cell_data_valid`, `rows_data_valid`, and
`snapshot_data_valid` describe data shape without the v1 wire ceilings.
`cell_wellformed_implies_data_valid`, `rows_wellformed_implies_data_valid`, and
`snapshot_wellformed_implies_data_valid` connect the bounded decoder domain to
that shape. Row views consume generic validity; decoder/profile budgets remain
separate. These new migration proofs are awaiting the current scoped check.

`ChunkedSnapshot.capture` is a whole-byte-stream acquisition adapter over an
already owned object sink. It records ordered byte spans, a streaming payload
digest, exact manifest encoding, and observed EOF. Budget, interruption and I/O
failure produce an incomplete candidate with retained expected locators for
host reconciliation; they never set complete. The whole captured byte stream
need not be an atomic view of a concurrently modified file. Storage ownership
and native publication remain host/gate obligations. The deterministic Scala
fixture uses a 64,353-byte value, 4,096 duplicate lines and 257-byte chunks;
its first run remains pending.

The separate `Veri7vn_Source_Stream_Tests` child session exercises the native
source-row/2 incremental semantic decoder and byte index. Lengths and columns
are unsigned 32-bit words; the final declared row count is an unsigned 64-bit
word. Explicit resource limits replace the earlier 255-byte/row format limits.
The executable entry `stream_feed_acc` consumes each byte once, accumulates
cell bytes in reverse, and reverses each completed payload once. Emitted rows
retain their dynamic cell class and order, including NULL, duplicate rows and
exact observed REAL bits. A missing or invalid footer does not erase previously
emitted rows; those rows are partial data and cannot license full-source claims.

Current child theorem targets establish chunk composition, accumulator
refinement, emitted row shape, and exact indexed byte-position coverage under
its explicit EOF/contiguity premises. The child runtime fixture compares whole
input with 257-byte chunks for a 64,353-byte text value, 4,096 duplicate NULL rows
and REAL bits, then rejects a partial footer and trailing bytes. These drafts
are not yet checked or admitted. The whole source row-index closure, accepted
native acquisition association, managed host composition, and actual gate and
plan consumers remain required before PO09/source publication can close.

The separate `Veri7vn_Source_Metadata` child now contains the actual bounded
manifestRecord/2 parser, `decode_source_metadata_wire`, and
`construct_source_manifest`. It parses the Scala acquisition record rather than
accepting an independently supplied typed manifest. UTF-8 fields retain their
exact octets in HOL's eight-bit string carrier; normalization and semantic text
interpretation are separate operations. The parser checks UTF-8 scalar framing,
canonical signed decimal clock values, nonnegative sequence identities, known
clock-basis tags, origin tags including Unknown, options, vector/field bounds,
and complete consumption. Scala encoding now rejects malformed surrogate input.
Request, attempt, binding and retention-policy IDs come solely from the reserved
native requirement. The parsed private-retention flag remains separate input to
the owning retention closure, and an optional payload hash remains source data.

The constructor's field equations retain source/schema/configuration, all three
clock roles, rank/units/references/import loss, encoding and unknown provenance.
A shared binary fixture is compared with actual Scala serialization and parsed
by the generated native decoder, including a multibyte UTF-8 qualifier and a
negative event tick. The Scala acquisition, chunk and metadata serialization regressions passed in
immutable attempt `95fcfdd61e543422/169b7c36e58f4cb19d2920e40ffd4736`. The native
metadata parser and constructor still await a successful child-session check;
its initial diagnostic exposed a slow nested-case elaboration, now replaced by
an explicitly typed parser-bind helper, followed by a record field-order repair.
A general byte codec inverse is not yet proved. The final kernel must compile these definitions with its actual
source carriers, then bind the decoded record and protected acquired raw input
into the same private ticket; a manifest hash does not supply that association.

Version-specific acquisition requirements are explicit:
`AnyVersion` makes no requested-version assertion, while `ExactKnownVersion v`
requires the observed optional version to be `Some v` with exact UTF-8 byte
identity. Neither source names nor unknown provenance supply a version. A known
version request rejects both an unknown observed version and a different known
version. Construction always retains the actual observed version even when the
request uses `AnyVersion`. The sealed declaration and execution consume the
same requirement. The source-import parent and native importer regressions,
including the unknown/mismatching-version cases, passed in immutable attempt
`a45e137bfff0ed36/653b3f2afb6d49c28c2c26b370702685`; the metadata child did not pass
in that attempt. These checks do not establish the final production gate linkage.

`SqliteObservation.observeLocal` is the initial inert local JDBC observation
adapter. It emits source-row/2 from actual dynamic `typeof` classes, retaining
NULL, exact signed integers, observed binary64 bits, UTF-8 TEXT octets and BLOBs.
Its extraction SQL explicitly casts TEXT to BLOB for byte extraction, records
engine/driver/encoding/schema/SQL, and preserves ordered duplicates. Optional
synthetic native rowid acquisition validates an unshadowed SQLite rowid alias;
WITHOUT ROWID and shadowed cases cannot silently invent identity. This initial
extraction profile explicitly requires the observed database encoding UTF-8.

Cell and row materialization, row count and encoded-byte bounds produce a
partial footer; cursor EOF produces a complete *query-result observation* footer.
These output bounds are not a claim about the external SQLite engine's CPU work
or formal SQL correctness. SQL or I/O failure can leave a partial/malformed stream
whose emitted prefix and managed ownership must be retained by the caller.
Connection cancellation and managed chunk-output composition remain host
integration obligations. The deterministic JDBC fixture is ready but not yet
compiled: it covers 258 rows, a 64,353-byte TEXT value, dynamic REAL/integer/NULL/
BLOB/TEXT, synthetic rowid, a bounded prefix and duplicate NULL rows. No original
corpus query or full scan has run. This adapter has not been admitted or wired
to native-authorized source publication.

The next Scala check strengthens that JDBC fixture with independently constructed
exact source-row/2 bytes for the first five ordered rows: negative integer,
observed 0.1 binary64 bits, NULL, nonempty BLOB, empty TEXT and empty BLOB. The
long field now contains 64,353 UTF-8 bytes including multibyte characters, and
its expected bytes are compared across 257-byte chunk boundaries. The earlier
JDBC pass established extraction/framing behavior, not these exact payload checks.

`ChunkedSnapshot.ChunkOutput` is a bounded output producer shared by file capture
and direct JDBC output. It registers each expected chunk before storage I/O;
failed sink writes poison completion, while `abort` and ordinary `close` retain
an incomplete candidate. Only explicit successful producer completion closes the
produced wire capture. `ManagedChunkObjects` adapts an already-owned actual
`ManagedSources.Stage`, with identity and readback checks. Neither component
starts an attempt, commits a source head, or produces native publication authority.
The new real-store fixture forces a stage budget failure after four stored chunks,
retains the fifth intended locator, then exercises abort, storage Forget, stale
read denial and candidate release. These producer and managed-composition changes
await their Scala check. Storage Forget alone does not complete native Forget.
