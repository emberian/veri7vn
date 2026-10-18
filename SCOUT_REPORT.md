# Scout report: rel-linker — reconstructing `names_v1.sqlite3`

## What I built

**`tools/linker/build_names.py`** reconstructs Oracle7's missing entity-linking index
`relstore/names_v1.sqlite3` from shipped data only, **schema-identical to the original**
(`name(norm, qid, links, alias)` + `label(qid, label, links)`), so the original consumers —
`entity_linker_v1/v2`, `exact_router_v1`, `relation_spec_v1/v2` — run **unmodified** against it.
Plus a `meta` table (never queried by shipped code) recording sources and the proxy formula.

Inputs (all read-only under `upstream/`), output and caches:

| artifact | what |
|---|---|
| `var/linker/names_v1.sqlite3` | the index: **12,059,027 name rows, 10,350,193 labels, 1.25 GB**, builds in ~5 min |
| `var/linker/deg.sqlite3`, `wiki_sent.sqlite3` | staged fact-degree / article-sentence caches (150 + 387 MB) |
| `var/linker/o7root/` | a scratch `ORACLE7_ROOT`: symlinks to the shipped relstore files + the rebuilt `names_v1.sqlite3` + a **merged `relation_domains_v2.json`** (see below) |
| `tools/linker/eval_panel.py` | linking accuracy on the core panel's 204 `organ:relation` items |
| `tools/linker/eval_specialists.py` | drives all 161 shipped rel-* organs on their own panels, scores with the shipped scorer |

Run: `python3 tools/linker/build_names.py --weights 0,14,8 --primary 1.5` (stages cache; `--calibrate`
prints anchor entities). Evaluate: `python3 tools/linker/eval_panel.py [--dump]`,
`python3 tools/linker/eval_specialists.py [--per-specialist]` (both set `ORACLE7_ROOT` themselves).

## What each field is, and what could not be reconstructed

- **labels** — `relations_v1.sqlite3 entity(qid,label,enwiki)` where `enwiki` is not null:
  10,350,193 rows, matching the linkers' documented "10.36M items with an English Wikipedia
  article". Faithful population.
- **aliases** — **no Wikidata aliases shipped, anywhere.** `m13e8`'s `title_alias` is 1:1
  normalized-title→page (not redirects); the DBpedia builds' `en*` pages are 5-sentence abstracts.
  Substitute: the entity's own **enwiki title** when it normalises differently from the label
  (1,711,495 rows, `alias=1`), e.g. title "United States" for label "United States of America".
  The original had ~14M names; this build has 12.06M — **the ~1.9M-row alias gap is the one
  reconstruction gap in the name table itself**, and it is measurable (see wrong answers).
- **links** (sitelink counts) — **no sitelink counts shipped.** Substitute, after measurement:
  `max(1, round(14·ln(1+indeg) + 8·ln(1+outdeg)))` from the fact table (indeg = times the qid is
  a fact object, outdeg = as subject), ×1.5 when `norm(enwiki) == norm(label)` — the **Wikipedia
  primary-topic signal** (the novel "Lord Jim" carries that title exactly; the 1965 film is
  "Lord Jim (1965 film)"). Article sentence counts were tried and **rejected**: every article
  corpus in fable-content is simplewiki or DBpedia abstracts (uniformly short, useless as fame).
  Scale anchors: US 237, Norway 187, Einstein 105, Diane Lane 86, stub homonyms 6–14 — the same
  order of magnitude as language-edition counts, which matters because `entity_linker_v2` compares
  `links < 30` and the router multiplies by `DOMINANCE=10`.

**A second missing dependency found and filled:** the shipped `relation_domains_v2.json` covers
125 domains but 52 of the 161 specialists need entries it lacks (rel-racketsports, rel-biathletes,
rel-youtubers, …), which makes those organs answer **nothing** (their `in_domain` raises and the
organ turns it into silence). All 161 specialists' manifests carry their own domain definition
(`roots`/`occupations`), so `var/linker/o7root/relstore/relation_domains_v2.json` merges the
shipped v2 entries with manifest-derived ones (177 entries). The file the release actually ran
with was never exported.

## What works — numbers

**Counterfactual first:** with `names_v1` absent, rel-actors answers 0/20 panel questions — every
one of the 161 rel-* organs is fully silent, and so is the core's `exact_router_v1` route. This
build revives them.

### Core panel relation items (204, `upstream/workbench/data/core_panel.json`)

Gold subject QIDs derived mechanically: 97 from sealed-history citations
(`typed relations: wd:Q… P… wd:Q…`, direction-aware: fwd→subject, inv→object), 91 by
argument + path-property + published answer against the store, 16 hand-resolved (each
store-verified, listed in the eval). The ORIGINAL `entity_linker_v2.link()` ran against the
rebuilt index:

- **top-1: 196/204 = 96.1%** (91.7% without the primary-topic boost)
- **top-3: 200/204 = 98.0%**, no-span 0

The 4 remaining top-3 misses: "Les Fleurs du mal" (span cut to "Les Fleurs"), "Il trovatore"
(span cut to "Il"), "Davy lamp"→"Davy", "The Way of All Flesh" (film senses) — the first three
are `entity_linker_v2`'s own span scoring and would misbehave with the original index too; the
last is the alias gap.

### All 161 rel-* specialists on their own shipped panels (18,976 items)

Shipped organs + shipped scorer, unmodified, against the rebuilt index and merged domains:

- **right 16,261 (85.7%) · silent 2,704 (14.2%) · wrong 11 (0.1%) · false-yes 0**
- **slot link top-1 18,299/18,969 = 96.5%, top-6 99.6%** (the names_v1 interface itself)
- shipped verdicts on the same panels: 94.4% right — and the gap is **not linking**:
  of the 2,704 silent items, **1,814 (67%) ask for a fact the shipped `relations_v1` store does
  not contain** (e.g. rel-rivers' P403 "mouth of watercourse" is absent for Birs, which has only
  7 facts total). The panels' `expect` values were generated from the never-shipped
  `relations_v2.sqlite3`. With those items excluded the reconstruction would read 95.3% ≥ shipped
  parity; the remaining 935 silences (~5%) are rank-not-top-3 (readers try only the top 3 of 6
  candidates), P279-chain gaps in the v1 store, and designed declines.
- organ latency: warm p50 0.08 ms (shipped verdict p50 6.41 ms).
- the 11 wrong answers are all same-named works ("Score", "Infinite", "Two of Us", "Hyperion")
  where the intended sense lost the rank — the visible cost of the missing aliases.

### Exact router (the core's mined-pattern route)

Runs against the rebuilt index: "Who directed Inception?"→Christopher Nolan,
"Who wrote the novel Fight Club?"→Chuck Palahniuk (the novel's Q-id, not the film's),
"What instrument did Ravi Shankar play?"→sitar. "Which horse won the 2018 Kentucky Derby?"
links the race correctly but the P1346 winner fact is absent from the store — store gap again.

## What I learned that was not obvious

1. **The core panel's own route does not use names_v1.** The tritree's LINK step links through
   the Wikipedia reader's article index and `RelStore.entity(title)` (an exact enwiki-title
   lookup, shipped). names_v1's consumers are the 161 specialist readers
   (`relation_spec_v2.slot_candidates` — the hot path), the mined patterns
   (`relation_spec_v1.analyse`), and `exact_router_v1`. The panel eval above is therefore a proxy
   measurement at exactly the interface names_v1 serves.
2. **`relations_v2.sqlite3` is as missing as names_v1, and it hurts more.** `exact_router_v1`
   hardcodes it; only v1 shipped (v1 answers the same schema, so symlinking works mechanically),
   but v1 has ~48M facts where the panels presume richer coverage — 1,814 panel items are
   unanswerable from shipped data, whichever linker you build.
3. **The entity table's enwiki-bearing subset IS the original label population** (10.35M ≈ the
   documented 10.36M) — the extra 1.4M rows without articles were excluded, matching the original.
4. **Fact-degree beats article length as a fame proxy on this drop**, because every shipped
   article corpus is simplewiki/DBpedia stubs; indeg separates real entities from same-named
   derivatives (novel Lord Jim 34 vs films 25/30 — with the primary-topic boost it ranks first),
   and outdeg rescues people (rarely fact objects: Einstein indeg 118).
5. **`--weights 0,14,8` (degree only) is the shipped-data optimum**; adding sentence counts made
   linking *worse* (DBpedia abstract length anti-correlates with fame for the head entities).

## Dependencies for excellence

- **Wikidata aliases** (the real fix for the 11 wrong answers and rank losses): not on disk;
  needs a Wikidata labels/aliases dump (QLever or wikidata-json) — a download decision for root.
- **`relations_v2.sqlite3`** (or its source dump): 1,814 panel answers are blocked on it. Also a
  root data decision; nothing in the drop reconstructs it.
- **The release's real `relation_domains_v2.json`** with all 161 domains — my merged file is a
  reconstruction from manifests; the original may differ in `exclude_props` refinements.
- Owner: whoever lands the rel-readers lane should take build_names.py as-is; the evaluator can
  double as their gate.

## Proposed follow-up lanes

1. **Wire the relation route into the parity harness** (S, sonnet) — an answerer binary/script
   around `exact_router_v1` + `relation_forms_v2` over the rebuilt names, scored on the core
   panel's 204 items end-to-end. Done = panel relation items right/withheld/false-yes reported by
   `tools/parity/harness.py`, no wrong answers introduced vs today's core.
2. **names_v1 polish** (M, sonnet/opus) — mine extra alias rows from shipped data only
   (m13e8 normalized_title↔title variants, DBpedia disambiguation patterns), re-tune the degree
   weights on the dev halves of the specialist panels. Done = slot top-1 ≥ 98%, wrong ≤ 5 on the
   same 18,976 items.
3. **relations store reconstruction** (L, opus) — a data pipeline rebuilding the typed relation
   store from a fresh Wikidata dump with v1's schema (entity/fact/fact_sp/fact_po), sized by the
   1,814 known-missing panel facts. Done = specialist panels ≥ 94% right (shipped parity) with
   the current linker unchanged.
4. **Reader top-3 study** (S, opus) — the readers try 3 of slot_candidates' 6; measure whether
   rank-4..6 candidates that are in-domain would flip silences to answers without adding wrongs
   (a one-line change in `relation_spec_v2.answer`, but it is shipped behaviour — needs the
   panels' say-so). Done = per-specialist deltas on both splits, wrong ≤ 11 held.

## Honest status

- No proofs involved (data/tool lane); nothing here touches HOL/Isabelle.
- Untrusted parts, named: `build_names.py` is reconstruction glue (upstream is read-only, opened
  `immutable`); the `links` column is a **documented proxy**, not sitelink counts — any consumer
  reading raw `links` values (only `entity_linker_v2`'s `< 30` and the dominance rule do) gets
  proxy values calibrated to the original's scale, not the original's numbers.
- Everything reported above was run (commands in the tools' docstrings); the 16 manual golds are
  individually store-verified and marked in `eval_panel.py`.
- Files written this session: `tools/linker/*`, `var/linker/*` (1.8 GB incl. caches),
  `SCOUT_REPORT.md`. Nothing under `upstream/` was written; no stash, no resets.
