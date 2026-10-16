# Shipped source-storage preservation pressure

Targeted read-only inspection on 2026-10-15: SQLite schemas and at most 257 rows per
table, two FTS source_rows samples, and at most 257 lines from each of two actual
JSONL files. The metadata-only observations are in `storage-samples.json`.
No giant corpus was rehashed, no broad suite/build ran, and no source prose was
copied into the report. These are source examples and lower bounds, not full
population/absence/maximum claims. SQLite observation order without ORDER BY is
not promised stable across rebuilds. All inspected SQLite encodings report UTF-8.

## Priority 1 — Actual REAL values and their reader meaning

| Materialized source | Fields / observed bounded values | Actual consumer pressure |
|---|---|---|
| `root/.../m13e5_conceptnet_build_a_v1/conceptnet_specialist.sqlite3` | edge.weight declared REAL; 257 observed Python floats | oracle_release_conceptnet.py:80–83 orders weight DESC,start,end then LIMIT; preserving raw bits alone does not establish ranking/numeric comparison semantics |
| `root/specialists/cooking/nutrition_v1.sqlite3` and cooking-v3-r2 copy | nut.amount REAL including 5.88,1.2,2.12; portions.grams REAL | organ_nutrition_v1.py:57 scans allfoods;127 reads amount/unit,148/169 chooses portion;158/176 computes per100*grams/100. Float/rational/unit/approximation profile is required |
| `root/specialists/warehouse/site_fresh.sqlite3` and warehouse-r2 copy | readings.value REAL including 19.7,20.7,22.8; sensors.lo/hi REAL | SiteOrgan compares physical ranges/freshness and aggregates stock deltas. REAL observation differs from admitted real-number computation; source times and snapshot meta.now also survive |
| `root/.../m30_admitted_closure_v1.sqlite3` | admitted_fact.score REAL including 0.885157,1.157536,0.929036 | Score/ranking data is empirical/model evidence, not truth authority; preserve score meaning and source lineage separately |
| `root/wander-train/oracle_relational_v3/data/m10/typed_records.jsonl` | 215 records observed, 29 quantity.value fields are floats, 39 event_time_epoch_ms fields are ints | Structured quantity/unit and temporal payload must survive; no flattening everything into surface text |

A CellNull/Integer/Text/Blob codec cannot preserve these row representations by
silently coercing REAL into integer or text. Source lane's proposed observed
binary64-bits carrier can preserve the driver observation, but does not itself
prove native numerical arithmetic/order/threshold or SQLite-query refinement.
SQLite driver observations, mathematical quantity meaning and rendered decimal
are three distinct relations. Unsupported numeric predicates cannot become a
source-global false/absence claim.

## Priority 2 — Real sizes exceed byte-sized lengths/counts

Within only the first257 rows, observed UTF-8 text lengths include:

- Wiktionary entry.glosses_json: 877 bytes.
- textbook item.text: 2349; solution: 2194; maths: 1038; instruction: 330.
- recipe.text: 2484; joke.text: 645.
- m30 gate_calibration.blob is **TEXT**, 64353 bytes, not a SQLite BLOB.
- Wikipedia FTS source_rows.fact: 315 bytes in the m13e8 sample.

Many tables yielded 257 rows under LIMIT 257, proving a 255-row total bound is
insufficient even without scanning complete corpora. A stream/chunk wrapper must
preserve unbounded logical cell and row boundaries, including boundaries crossing
transport chunks; byte streaming alone is not a semantic row decoder. Original
cell types must survive: a field named blob is not automatically CellBlob.
There was no observed >255-column row in this bounded sample; no universal width
bound follows from this inspection.

Integers also exceed 255: sampled entity.qid ranges 358–23982; foods.fdc_id
167512–167768. Warehouse stock_events.delta sample has 189 negative values, minimum
-15 and maximum 281. Preserve signed integers and large identifiers without using
an 8-bit scalar carrier; magnitude-byte encoding needs its own canonical/decoding
relation. These are bounded sample ranges, not database extrema.

## Priority 3 — Multiplicity, NULL, row identity and source typing

Actual duplicate entire rows occur in the sampled shipped tables:

- Wiktionary forms: 42 repeats among 257 rows.
- ConceptNet edge: 1 repeat among 257.
- Nutrition portions: 1 repeat among 257.

Many more repeated leading keys are meaningful one-to-many relations: WordNet
relation.subject_id, page_sentence.page_id, nut.fdc_id, portions.fdc_id and
relation fact.s. A map keyed by first column or set of whole rows loses behavior.
Preserve ordered rows/bags and explicit row/source identity. DISTINCT/count by
entity is a separate query operation with a declared population and equivalence.

Textbook optional problem/solution/instruction cells actually contain SQL NULL;
relation fact.lit sample is NULL. Source_derivations.jsonl target_qid has 130
strings and 43 explicit JSON nulls in 215 records. Missing JSON key, explicit null,
empty string, unavailable source and query failure remain distinct.

Wikipedia `source_rows` is an FTS5 virtual table:
`(claim_id,fact,fact_sha256,page_id,sentence_ordinal,tokenize='unicode61')`.
The inspected FTS sentence_ordinal values come back as Python **str**, while
page_sentence.sentence_ordinal is INTEGER. The rowid links used by source readers
must survive export; casting by column name is not a representation proof.
FTS internal shadow tables are engine machinery, not extra independent source
claims. A plain typed row import does not reproduce unicode61 tokenization,
MATCH/bm25 or collation behavior; those require a supported native fragment or
an explicitly pinned engine-observation boundary.

Actual Unicode text appears in entity.label/enwiki, Wikipedia title/URL/fact,
Wiktionary glosses/forms, and textbook/recipe content. Preserve original UTF-8
bytes and a declared decoding relation; byte count differs from character count.
No ASCII/lowercase/whitespace normalization is justified globally. Bytes retained
in CellText are not automatically a native Unicode-aware query implementation.

## Priority 4 — Complete input versus scoped output

The sampler is deliberately incomplete. It cannot justify absent facts, global
uniqueness, exact counts or ranking over an entire corpus. Whole-source captured
stream/chunk correspondence must connect exact source/table/schema/snapshot,
selection policy and all decoded rows to the native collection. Importing only
these examples would establish fixture behavior rather than shipped migration.

Existing readers legitimately use bounded output: ConceptNet orders then LIMIT;
Wiktionary reads one selected gloss; SQL specialist displays 20 after fetching 21;
corpus/FTS readers rank bounded candidate regions. Preserve that behavior as an
explicit query/prefix/selection scope. Full input capture is not identical to
full query coverage, and bounded successful output is not complete-source proof.

JSONL typed_records contains nested quantity/temporal objects and competency/
condition lists; source_derivations carries provenance hashes, JSON pointers,
revision integers and nullable target IDs. Their imported meaning needs a schema
adapter/refinement, not only line-byte preservation. The standalone corpus
compiler currently normalizes semantic surfaces, sorts by semantic/provenance
identity and rejects duplicate provenance-addressed claim IDs; that intentional
identity policy differs from general SQLite bag preservation.

Source/import, domain/math, relation/graph and stateful connector owners retain
actual semantic and runtime bridge obligations. A portable tiny codec, structural
row count, snapshot hash or metadata result cannot substitute for these reader
consumers. Original v2 relation/name/linking snapshots remain unavailable; this
inspection of v1 and other stores does not claim missing-source reconstruction.
