# Exact-label ConceptNet observations

`conceptnet-edge-exact/1` reads the retained original `upstream/root/fable-content/oracle-m-series-2026-08-15/m13e5_conceptnet_build_a_v1/conceptnet_specialist.sqlite3` edge table through shared SqliteObservation source-row/2. Preserve all8 cells(rel,start,start_pos,end,end_pos,weight,surface_text,dataset), NULL/duplicates/UTF-8/observed binary64 bits and explicit ordering. Ordinals identify this observation, not SQLite rowids/concepts.

`observeChainView(source,via,target)` uses typed text/DNF selection for proposed IsA first hop or incoming target assertions, default45-row prefix. Canonical Report.selectionPolicy—including SQL/parameters/order/bounds—must become the manifest selection. This tests a candidate view, not all corpus paths.

Native exact-byte dictionary indices have a checked inverse but no persistent source identity. `ConceptNetQuery nv ne source target` consumes the common acquired association. Optional `Veri7vn_ConceptNet_Acquisition` retains original versioned bytes, matched manifest, actual observation and independent path meaning. Cached row/payload dimensions supply precharge before decoding/dictionary/sort; the charged worker rechecks graph bounds.

Finite confidence is represented exactly as signed integer×2^-1074, including subnormals/signed zero; NaN/infinity reject, integer magnitudes cap128bytes. Edges use **unit hop cost**, not confidence as additive cost. Per start: confidence-descending/start/end/ordinal order, first8 rows, then minimum confidence1. Target requires≥30 incoming IsA assertions in this view regardless of confidence. Search depth≤3/expansions≤400 plus work/materialization guards. These heuristics neither resolve senses nor certify global shortest/absence.

`concept_render_reply` pairs unchanged raw rows with escaped plain `Source row:` captions retaining labels/POS/dataset/surface text; exact confidence remains structured. Positive paths retain dictionary, original rows, graph witness and observed completeness. Zero-hop has no citations. Unknown/degree/finite-view Unreachable become scoped `ConceptInconclusive`. Exact labels deliberately replace upstream whitespace/case/plural heuristics; a future resolver must retain choices. Real `robin→bird→meat` illustrates sense crossing, not world IsA or licensed transitivity.

## Qualification

`tests/sources/conceptnet/check.scala` compares257 ordered original rows/all cells/REAL bits/incomplete footer to independent JDBC framing, and45 selected rows to a prepared-query oracle. It writes ignored wire/selection artifacts. After the steward's Scala check, generate the native oracle:

```sh
python3 tests/sources/conceptnet/original_fixture.py \
  tests/sources/conceptnet/ConceptNet_Original_Fixture.thy
```

`Veri7vn_ConceptNet_Tests` checks numerical edge cases/schema rejection/duplicate lineage and actual /2 materialization against that oracle before graph execution. Qualification of pure profile, common acquisition/native producer, C02/serializer, lifecycle/recovery and installed resident delivery remain separate. Original corpus exists; pending integration is not missing data. NL, reverse/non-IsA, neighborhoods, legacy rendering and lexical proposals remain open scope.
