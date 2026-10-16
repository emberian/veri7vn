# Source storage requirements

`storage-samples.json` records bounded read-only SQLite/JSONL inspection: at most 257 rows/lines per source, two FTS samples, UTF-8 SQLite encodings. Unordered samples establish examples/lower bounds, not extrema, absence or population completeness.

| Representation pressure | Actual evidence | Required consumer |
|---|---|---|
| REAL | ConceptNet edge.weight; nutrition amounts/portion grams; warehouse readings/ranges; m30 admitted_fact.score; 29 floating quantities/39 integer event times among 215 typed_records | Preserve observed binary64 bits separately from native numeric order/arithmetic and rendered decimals. Scores remain empirical. |
| Large text | Wiktionary glosses 877 bytes; textbook text 2349/solution2194/maths1038/instruction330; recipe2484; joke645; m30 gate_calibration.blob **TEXT**64353; FTS fact315 | Versioned lengths/counts, semantic row boundaries across chunks; no column-name coercion. |
| Large/signed integers | Entity IDs358–23982; foods167512–167768; warehouse deltas include189 negatives, sampled range−15..281 | Exact signed magnitude interpretation; 8-bit scalar is insufficient. |
| Duplicate rows | 42/257 Wiktionary forms, one ConceptNet edge and one nutrition portion repeat | Ordered bag/row identity; distinct/entity aggregation is an explicit query. |
| NULL | Textbook optional cells, relation fact.lit; source_derivations target IDs include130 strings/43 nulls among215 | Missing key, null, empty text, unavailable source and query failure stay distinct. |
| FTS5 | source_rows(claim_id,fact,fact_sha256,page_id,sentence_ordinal,unicode61); ordinal observed as str while page_sentence ordinal is INTEGER | Retain rowid links/dynamic classes; MATCH/bm25/tokenization/collation need native support or pinned engine observation. Shadow tables are machinery. |
| Unicode/structured data | Entity labels/URLs, corpus text, nested quantity/time/conditions and provenance JSON pointers/hashes | Original UTF-8 bytes plus declared decoding/schema relation; no global whitespace/case normalization. |

Actual consumers explain the distinctions: `oracle_release_conceptnet.py:80–83` orders weight DESC/start/end then LIMIT; `organ_nutrition_v1.py:57,127,148,158,169,176` selects food/portions and computes per100×grams/100; SiteOrgan applies snapshot time/freshness/ranges. Binary64 capture alone proves none of those algorithms. SQLite/driver observation is also distinct from on-disk representation.

Many tables reach LIMIT257, disproving a universal255-row bound. No sampled >255-column row establishes a universal width limit. Preserve complete captured source/table/schema/snapshot/selection association while exposing legitimate bounded output: ConceptNet caps, one gloss, SQL fetch21/display20, ranked candidate regions. Neither full input capture nor one successful prefix licenses global ranking, uniqueness or absence.

The standalone JSONL compiler deliberately normalizes surfaces, sorts semantic/provenance identities and rejects duplicate provenance claim IDs; general SQLite import instead preserves bags. Source, domain/math, relation/graph and connector consumers must qualify these separate policies. Original v2 relation/name/linking data remains unavailable; v1 samples do not reconstruct it.
