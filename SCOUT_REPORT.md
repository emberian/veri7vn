# Scout rel-census: the 161 relation specialists are one lane

One verified decision theory (RelationOrganV2/RelationOrganV2G, ported statement-for-statement)
plus per-specialist manifest tables answers for all 161 `rel-*` organs. The ceiling of the
shipped store is 17162/18976 items (90.4%); the ceiling's shape predicts the scores exactly.
Answer: **yes, one lane** — proven by scoring three readers with different property mixes off
one binary, one of them item-for-item identical to the dedicated rel-novels reader build.

## 1. What I built and how to run it

- `tools/rel-census/census.py` — read-only census over `relations_v1.sqlite3` + all 161
  manifests + panels; emits `var/rel-census/census.json` and the committed table
  `docs/coverage/rel-ceiling.md` (per-specialist panel, absent properties, ceiling, shipped
  verdict, domain-fallback flag).
  `python3 -I -B tools/rel-census/census.py`
- `src/isabelle/relorgan/` — the shared decision (`Relation_Organ.thy`: reader walk, pattern
  fallback, pronoun guard), fixtures (`Relation_Organ_Test.thy`), code export
  (`Relation_Organ_Export.thy`, prints `VERI7VN_RELORGAN code sha1=<sha1>`).
  `/Users/ember/dev/o7vn/tools/dev/remote-build persvati src/isabelle/relorgan Veri7vn_RelOrgan --expect 'VERI7VN_RELORGAN'`
- `tools/rel-census/build_decide_organ.sh` + `decide_main.sml` — MLton binary of the exported
  decision + untrusted JSON-lines I/O; `var/relorgan/decide-organ`. The script prints the
  export SHA-1 and fails if the gen file is missing (fetch it:
  `scp persvati:veri7vn-builds/rel-census/var/relorgan/gen/Relation_Organ_Code.ML var/relorgan/gen/`).
- `tools/rel-census/organ_answerer.py` — the specialist-as-data glue: manifest → one turn per
  question (reader regex matches, linker candidates, store rows, inverse holders, pattern
  features), decision by the binary, reply rendering. UNTRUSTED by construction (docstring
  says what it assumes); the decision is the verified part.
- Scoring:
  `PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream python3 -I -B tools/parity/harness.py --answerer "python3 -I -B tools/rel-census/organ_answerer.py --specialist {id}" --specialist rel-actors,rel-novels,rel-tvseries-v2 --split both --out var/scout/parity`
  (needs the norm index at
  `/Users/ember/dev/o7vn/var/scout-wt/rel-novels/var/rel-novels/norm_index.sqlite3`, 1.6 GB —
  see §4).

## 2. What works, with numbers

Build receipt (the gate): `remote-build: persvati Veri7vn_RelOrgan exit 0`, marker
`VERI7VN_RELORGAN PASS`, `VERI7VN_RELORGAN code sha1=87f71969edf1f29ec73c3fa8e8fc970260d06aef`;
`build_decide_organ.sh` compiled the binary from exactly that sha1. No `sorry`/`oops` anywhere.

Panels (shipped scorer, both splits, `var/scout/parity/`; p50 latency 7–8 ms/item, no
answerer restarts, stderr empty):

| reader | mix | right | wrong | false-yes | withheld | of which absent-prop | census ceiling | shipped (v2, absent store) |
|---|---|---|---|---|---|---|---|---|
| rel-actors | 8 readers, 1 pattern, nothing absent | **166**/192 (dev 70, heldout 96) | 0 | 0 | 26 | 0 (all P19 declines) | 192 | 167 |
| rel-novels | 5 readers, 19 patterns, P144 absent | **84**/120 (dev 41, heldout 43) | 0 | 0 | 36 | 24 = every P144 item | 96 | 104 |
| rel-tvseries-v2 | guard class (V2G), 6 readers, P144/P580/P582 absent | **66**/144 (33+33) | 0 | 0 | 78 | 72 = every absent-prop item | 72 | 116 [1 wrong] |

- The census predicts the absent-property withholds **exactly** (24/24 and 72/72). The gap
  from ceiling is entirely present-prop declines: rel-novels 12, rel-actors 26 (all P19
  place-of-birth), rel-tvseries-v2 6.
- rel-novels vs the dedicated reader scout (branch scout/rel-novels): **120/120 items
  identical** in status and value — the shared decision reproduces the single-organ build.
- The harness verdict says INCOMPLETE for all three: its bar is the shipped verdict, which was
  computed over `relations_v2.sqlite3` + `names_v1.sqlite3`, neither of which shipped; for the
  absent-property items that bar is unreachable on v1 by the census's construction (shipped
  beats the v1 ceiling by 758 items store-wide, all on absent properties). DOMAIN / FALSE YES /
  LANE / SELF / BUDGET are "not measured" without `--lane-answerer`; the measured parts are
  clean everywhere.
- What does not work: nothing crashed, but the inverse direction is exercised by **no shipped
  panel item at all** (all 18976 are forward) — `inv_read` is verified and fixture-tested only.

## 3. What I learned that was not obvious

- **The pattern stage must not re-apply the dominance cut.** My first theorem statement
  claimed `agree P (select_dom (pat_cands t))`; the kernel refused it. The shipped
  `relation_spec_v1.analyse()` already applies dominance and cuts to three; `answer()` reads
  that list directly. Re-collapsing the cut list can fire where the shipped code does not
  (subset max is smaller), letting a single candidate answer where the shipped organ demands
  agreement — a safety-negative divergence the proof failure caught before any binary existed.
  Definition kept faithful; statement fixed.
- **A failed `by` masks the rest of its lemma.** Isabelle skips to the lemma's end, so each
  build reveals one error layer per round trip (6 builds to green). Budget for that.
- Simp mechanics that cost round trips: premises chained in `A ⟶ ¬B` form cannot reduce an
  `if A ∧ B then …` guard — `split: if_splits` fixes it; equations trapped inside conjunction
  premises need `metis`; `(simp; force)` succeeds whether or not simp closes everything, where
  `apply … by force+` errors "No subgoals!"; `f(2,2,1)` indexing is invalid on a
  conjunction-fact (it indexes fact lists, not conjuncts).
- **52 of 161 organ domains are in neither shipped domains file** — as dropped, those organs
  die on a KeyError and answer nothing; each manifest's own `domain.roots`/`occupations`
  recovers them (census uses the fallback; scoring confirms it works).
- **The pattern stage secretly needs `entity_linker_v1.label` → `names_v1.sqlite3`** (missing).
  The rel-novels reader never hit it (reader stage only); any pattern-stage port must patch
  `L2.label` (I map it to store labels).
- Isabelle→MLton export shapes: triples export as nested pairs `(a,(b,c))`; datatype
  constructors take ONE tuple; `.ML` must be copied to `.sml` and an MLB root written for
  multi-file MLton.
- The pronoun guard ports as a per-turn flag: capitalised "You" is a title reference (kept),
  lowercase "you" a pronoun subject (silenced) — only 2 of 161 specialists are V2G, so this
  path is scored by rel-tvseries-v2 alone.

## 4. Dependencies for excellence

- **The norm index is shared infrastructure living in a scout's worktree.** Root should own it
  (`var/linker/norm_index.sqlite3` + the builder) — every relation reader needs it; my
  answerer points at the rel-novels copy by absolute path.
- The linker stand-in ranks by (in-domain, primary title, fact count); the release ranked by
  sitelink counts in the never-shipped `names_v1`. The present-prop declines (44 across three
  readers) are the visible cost; how many a better stand-in closes is unknown.
- The 52 manifest-fallback domains are unverified against any real release domains file.
- `--lane-answerer` runs (LANE/SELF/BUDGET) were not done; they need the composed-answerer
  shape, not the bare organ.

## 5. Proposed follow-up lanes

1. **The 161 as one lane** (L, opus — data pipeline with a frozen pattern): land
   `src/isabelle/relorgan/` + `organ_answerer.py`, generate per-specialist tables from
   manifests, score all 161 panels. Done = Σright/Σpanel reported per specialist, 0 wrong,
   0 false-yes, and every withhold accounted as census-absent or linker-named. Prototype here
   scored 3/161 at 0 wrong; the census table is the worklist and the scoreboard.
2. **Shared linker index** (S, sonnet): move `build_norm_index.py` + the 1.6 GB index to a
   root-owned path, parameterise answerers on it. Done = organ_answerer's default NORM points
   there and the rel-novels worktree path is gone from the tree.
3. **Linker accounting** (M, opus): classify all present-prop declines across the 161
   (store-row disagreement vs sense confusion vs domain-miss), then decide whether a smarter
   stand-in ranking is worth it. Done = per-specialist decline table with a cause column, and
   rel-actors ≥ 167 or a named reason it cannot close.
4. **Inverse-reader fixtures from the store** (S, sonnet): no panel exercises `Inv`; mine
   real inverse rows into `Relation_Organ_Test.thy` fixtures (e.g. "the capital of …" P36) so
   the verified inverse path is kernel-checked against real data. Done = ≥3 fixtures green in
   the session build.

## 6. Honest status

- No `sorry`, `oops` or new axioms in any theory; every lemma in
  `Relation_Organ.thy` is closed. Main theorems: `organ_answer_means` (an Answered means ≤3
  in-domain, fetch-complete candidates all naming one stored value, or a unique in-domain
  inverse holder, never restating, never past-tense on a time-variant property),
  `organ_withheld_means` (a Withheld names the phrasing and in-domain entity whose read
  failed), `pattern_answer_single_property` (pattern answers only on a uniquely named
  property), `guard_drops_silences`, plus the walk inversions/append lemmas.
- Untrusted, named: the recognizer (shipped regexes), the linker stand-in, the store fetch and
  domain closure, the SML JSON I/O, reply rendering, and `census.py` (its "ceiling" is data,
  not a theorem). The theorems say nothing about store truth or linker intent — that split is
  documented in the theory header.
- Two deliberate, safety-positive divergences from the shipped organ, both marked in the
  theory header: an incomplete fetch never answers (shipped has no completeness notion), and
  the pronoun guard is a flag, not a second class.
- Not run: 158 of 161 specialists unscored by me; no `--lane-answerer`; inverse direction
  unexercised by any panel.
