# Local source import

`LocalSnapshot.scala` reads explicitly supplied inert regular files, rejects leaf symlinks and enforces bytes while reading. It executes no SQL/connector, samples no undeclared clock and performs no restore acquisition/forgotten-locator lookup. Candidate bytes/manifest are defensive copies; deterministic identities locate staging data, not authority.

Manifest fields: source/version, schema/encoding/recipe, selection/query, optional license/provenance, qualifiers/rank/units/references/loss; event/receipt/poll clocks with basis/origin; sequence/config/calibration/quality; measured/simulated/unknown origin; retention. Unknown remains None. Receipt changes cannot freshen the original event.

## Native codecs

The generated decoder is the product parser; Scala supplies original bytes. Shared Codegen ensures one compact nat/int/char carrier, not casts between separately reflected copies.

| Format | Layout/limits | Meaning |
|---|---|---|
| source-row/1 | [83,49,full,columns,rows], row-major cells; unsigned-byte counts/lengths≤255; default65536-byte acquisition | Compact supported shape; full means supplied materialization, not external coverage |
| source-row/2 | Framed incremental stream; u32 lengths/columns, u64 final row count, explicit budgets/footer | Large cells/rows/chunks retaining order/classes and partial data |
| Cells |0 NULL;1 sign+magnitude;2 TEXT bytes;3 BLOB bytes; D37 tag4 exactly8 REAL-bit bytes | Signed arbitrary integers, original representation/encoding and exact observed binary64; no silent coercion |

Integer leading zeros/negative zero remain representation-distinct despite equal integer_meaning. row_index_count counts distinct **representations**, not SQLite numeric DISTINCT. REAL retains signed zero/infinity/NaN observations without granting real arithmetic/order; driver observation is not on-disk byte identity.

Compact decode rejects malformed/version/truncated/trailing data atomically. `decode_encode_cell/row/rows`, snapshot_codec_roundtrip and wire_codec_roundtrip prove supported inverse laws. consume_prefix traverses only requested prefixes; base256 magnitude fold avoids repeated scans. Generic cell/rows/snapshot_data_valid separates semantic shape from v1 ceilings, with wellformed-implies-valid lemmas. Source_Import_Profile declares source_batch/representation/shape/law; declaration alone is not admission.

Framed stream_feed_acc consumes bytes once, reverses each accumulated cell once and retains emitted row order/classes/duplicates. Invalid/missing footer leaves an explicit partial prefix. Native targets cover chunk composition, accumulator/spec refinement, row shape and indexed contiguous byte/EOF coverage. Whole-versus257-byte-chunk tests use64353-byte text,4096 NULL rows and REAL bits, partial footer and trailing bytes. Qualification remains pending; see [storage requirements](../coverage/classification/storage-preservation.md).

## Acquisition and metadata

attach_batch combines actual batch with original unit-valued observation/assertion templates, retaining event/config/schema/clock and rank/unit/reference/loss/applicability. row_segments retains source observations; row_view requires schema/width/validity and separately exposes declared completeness. Missing/rejected/partial observations cannot become complete.

source_acquisition_requirement fixes request/attempt/binding/key/schema/encoding/version/origin/config/quality/calibration/recipe/selection/retention/bounds. manifest_matches checks association and Missing payload template. AnyVersion claims no requested version; ExactKnownVersion requires exact Some-version bytes and rejects unknown/different version. Observed version always survives.

Source_Metadata_Codec parses actual Scala manifestRecord/2 with bounded UTF-8 framing, canonical decimal clocks/sequence, known clock/origin tags, options/vectors and full consumption. construct_source_manifest obtains reserved request/attempt/binding/retention IDs from the native requirement, not authored JSON. Parsed private flag/hash remain separate retention/data inputs. Scala rejects malformed surrogates. Metadata native inverse/constructor qualification remains pending.

D48 uses acquire_native_versioned/versioned_source_represents for compact versus framed originals. The protected source gate must bind actual native batch/manifest/raw owners and immutable requirement to the same confirmed attempt. Required publication spine:

`StageIntent → durable ack → ClaimAndStart/current handoff → acquire → Reconcile Confirmed → native association → StageObservation → durable ack`.

Only the generated Owner authorizes publication; retirement denies pending/derived results. Hashes/profile IDs/confirmation alone cannot supply native correspondence. Common acquisition/leaf structure is specified in [observer interface](source-observer-interface.md).

## Host producers and ownership

SqliteObservation.observeLocal is an inert local JDBC observer: dynamic typeof, TEXT-as-BLOB extraction, exact signed integer/observed REAL/TEXT/BLOB/NULL, explicit ordered duplicates and engine/driver/schema/encoding/SQL report. UTF-8 database encoding is required. Optional synthetic rowid validates an unshadowed alias; WITHOUT ROWID/shadowing cannot invent identity. Cursor EOF means complete selected query result; bounds yield partial footer. SQL/I/O failure can leave malformed partial output. Engine CPU/SQL correctness and cancellation remain separate obligations.

ChunkedSnapshot captures ordered spans/digest/manifest/EOF through an owned sink; concurrent files need not be atomic snapshots. ChunkOutput registers expected locators before I/O, poisons failed completion and closes complete only on explicit success. Abort/close preserve incomplete reconciliation data. ManagedChunkObjects binds actual ManagedSources.Stage/readback. No producer issues attempts or commits heads.

Candidate release clears retained byte/manifest/profile/context roots; managed native/host closures additionally drain workers, copies, handles, registry/private contexts, pending queues and caches. Uncontrolled exports are outside erasure. Receipt-only repolls retain original history; source+sequence conflicts retain both reports, including missing/rejected readings.

## Evidence and limits

Scala acquisition/chunk/metadata regressions passed95fcfdd61e543422/169b7c36e58f4cb19d2920e40ffd4736. Native importer/version checks passeda45e137bfff0ed36/653b3f2afb6d49c28c2c26b370702685. Neither qualifies the metadata/stream/gate composition.

Queued JDBC checks cover258 rows,64353 UTF-8 bytes,257-byte chunks, exact first5 typed rows, REAL0.1 bits, negative integer, NULL and empty/nonempty TEXT/BLOB, rowid and bounded prefix. Managed-stage budget failure retains four chunks plus fifth intended locator before abort/Forget/stale-read denial. Storage Forget is not installed native Forget.

Availability: audit/results/availability.json records14 materialized assets. Original relations_v2.sqlite3/names_v1.sqlite3/linking_src/{labels,aliases}.tsv remain unavailable; available v1 is not v2. Replacement sources require explicit version/license/schema/coverage/loss records. Chunk/metadata/native observer correspondence, authenticated publication and installed lifecycle remain acceptance gates.
