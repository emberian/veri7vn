# Lane F: verified relation reader (handoff, 2026-10-16)

## What exists

Oracle7's exact relation router (`upstream/root/wander-train/exact_router_v1.py`) is lifted as a HOL decision over
fetched evidence, exported to SML, compiled with Isabelle's MLton, and wrapped by an untrusted Python fetch that
speaks the answerer contract.

| Path | Role |
|---|---|
| `src/isabelle/reader/Relation_Reader.thy` | types, `decide_on` / `decide` / `decide_admitted`, theorems, the admitted table as a HOL constant |
| `src/isabelle/reader/Relation_Reader_Export.thy` | `export_code ... in SML`; also writes `var/reader/gen/Relation_Reader_Code.ML` and prints its SHA-1 |
| `src/isabelle/reader/Relation_Reader_Test.thy` | eight store-derived fixtures proved by `auto` from the definitions; prints `VERI7VN_READER PASS` |
| `tools/reader/decide_main.sml`, `build_decide.sh` | hand-rolled JSON I/O around the exported code; MLton build of `var/reader/bin/decide` |
| `tools/reader/answerer.py`, `link.py`, `fetch.py` | untrusted glue (contract front end, linker port, sqlite fetch) |
| `tools/reader/measure.py` | Oracle7 head vs reader over the core-panel relation items |

Session: `Veri7vn_Reader = HOL`, imports `Main` only. No `sorry`/`oops`/axioms; fixtures use the simplifier, not
`eval`/`normalization`. Receipt (passed, inputs stable, marker `VERI7VN_READER PASS`):
`var/native-scaffold/sessions/c6ca8004c6d2ecb4/attempts/f5d1f82d35a444458e53178a2ebc2032/receipt.json`.
The same build log prints `VERI7VN_READER code sha1=0d325be6993caf3ff5832185787369742b20dfef`, which is the SHA-1 of
`var/reader/gen/Relation_Reader_Code.ML` that `var/reader/bin/decide` was compiled from (binary sha1 f60480e0f788...).

## The decision

`question_features` carries what regexes compute (polar, hidden_hop, subject_ok, past, head_key, content_words,
question_words, value_words). `candidate = (qid, links, rows :: (natural × rel_value) list, complete)`,
`rel_value = Entity natural | Literal String.literal | Blank` (`value` is an Isar keyword; ids are `natural`, Main's
IntInf-backed nat, so the export is not unary). `decide f ps cs = decide_on f ps (select cs)`, where `select` keeps the
first three candidates, or only the first when its `links` is at least 10 × max(1, others) (exact_router's DOMINANCE).
`decide_on` refuses in shipped order: Polar, NoCandidate, HiddenHop, NotSubject, NoPattern / ConflictingPatterns
(the matching patterns must name exactly one property), PastQualifier (time-variant property + past qualifier),
IncompleteEvidence (any candidate not `complete`), NoValue, BlankNode, MultiValued, Disagreement, RestatesQuestion;
otherwise `Answer v`. `decide_admitted` fixes `ps` to `admitted_patterns_v4`, the 35 rows of
`router_patterns_v4.json`; at start the answerer asks the binary for its table and refuses to run if it differs
from the JSON.

## Theorem statements (verbatim from Relation_Reader.thy)

```
theorem answer_unique_agreement:
  assumes "decide_on f ps cs = Answer v" and "route f ps = Some P"
  shows "∀c∈set cs. ∀(p', ob)∈set (rows c). p' = P ⟶ ob = v"

theorem answer_requires_coverage:
  "decide_on f ps cs = Answer v ⟹ ∀c∈set cs. complete c"

theorem answer_not_blank: "decide_on f ps cs ≠ Answer Blank"

theorem answer_witnessed:
  "decide_on f ps cs = Answer v ⟹
    ∃P. route f ps = Some P ∧ (∃c∈set cs. (P, v) ∈ set (rows c))"

theorem answer_not_restating:
  "decide_on f ps cs = Answer v ⟹ ¬ restates f v"

theorem polar_refused: "decide_on f ps cs = Refuse Polar ⟷ polar f"

theorem no_candidate_refused:
  "decide_on f ps cs = Refuse NoCandidate ⟷ ¬ polar f ∧ cs = []"

theorem hop_refused:
  "decide_on f ps cs = Refuse HiddenHop ⟷ ¬ polar f ∧ cs ≠ [] ∧ hidden_hop f"

theorem no_pattern_refused:
  "decide_on f ps cs = Refuse NoPattern ⟷
    ¬ polar f ∧ cs ≠ [] ∧ ¬ hidden_hop f ∧ subject_ok f ∧ matched_props f ps = []"

theorem conflicting_patterns_refused:
  "decide_on f ps cs = Refuse ConflictingPatterns ⟷
    ¬ polar f ∧ cs ≠ [] ∧ ¬ hidden_hop f ∧ subject_ok f ∧ 2 ≤ length (matched_props f ps)"

theorem incomplete_refusal_names_a_gap:
  "decide_on f ps cs = Refuse IncompleteEvidence ⟹ ∃c∈set cs. ¬ complete c"

theorem agreeing_candidates_keep_answer:
  assumes ans: "decide_on f ps cs = Answer v" and r: "route f ps = Some P"
    and sub: "set cs ⊆ set cs'"
    and cov: "∀c∈set cs'. complete c"
    and agree: "∀c∈set cs'. ∀(p', ob)∈set (rows c). p' = P ⟶ ob = v"
  shows "decide_on f ps cs' = Answer v"

corollary more_candidates_never_flip_answer:
  assumes "decide_on f ps cs = Answer v" "route f ps = Some P" "complete c"
    "∀(p', ob)∈set (rows c). p' = P ⟶ ob = v"
  shows "decide_on f ps (cs @ [c]) = Answer v"

theorem disagreeing_candidate_refuses:
  assumes ans: "decide_on f ps cs = Answer v" and r: "route f ps = Some P"
    and sub: "set cs ⊆ set cs'" and c: "c ∈ set cs'" and row: "(P, ob) ∈ set (rows c)" and ne: "ob ≠ v"
  shows "∃reason. decide_on f ps cs' = Refuse reason"

theorem evidence_refusal_monotone:
  assumes ref: "decide_on f ps cs = Refuse r"
    and rs: "r ∈ {IncompleteEvidence, BlankNode, MultiValued, Disagreement}"
    and sub: "set cs ⊆ set cs'"
  shows "∃r'. decide_on f ps cs' = Refuse r'"

lemma select_cases:
  "select cs = take 3 cs ∨ (select cs = take 1 cs ∧ dominated (take 3 cs))"

corollary decide_answer_unique_agreement:
  "decide f ps cs = Answer v ⟹ route f ps = Some P ⟹
    ∀c∈set (select cs). ∀(p', ob)∈set (rows c). p' = P ⟶ ob = v"

corollary decide_answer_requires_coverage:
  "decide f ps cs = Answer v ⟹ ∀c∈set (select cs). complete c"

corollary decide_answer_not_blank: "decide f ps cs ≠ Answer Blank"

lemma route_admitted_in_table:
  "route f admitted_patterns_v4 = Some P ⟹ P ∈ set admitted_properties"

lemma admitted_table_size:
  "length admitted_patterns_v4 = 35 ∧ length admitted_properties = 17"
```

`decide_on` is a total HOL function, so determinism is by construction; no separate vacuous lemma was added.
Assurance, plainly: an Answer means every candidate the decision saw (after `select`) has only that value for the
routed property, among rows the fetch declared complete, and the value is witnessed by a stored row. Nothing here
says the store is right, that the linker found the right entities, or that `select` dropped only wrong senses.

## Deliberate differences from exact_router_v1

- Blank nodes refuse (`BlankNode`). The shipped code drops blank values and can still answer from the others.
- Agreement is by value identity (Q-id or literal), not by display label: two different entities with the same
  label refuse here, where the shipped code answers.
- Unlabelled entity values are kept (rendered `Q<id>`); the shipped code drops them.
- The exact_router docstring says 32 patterns / 13 properties; the shipped `router_patterns_v4.json` has 35 / 17
  (matching w524's docstring). The HOL table is the JSON.

## Untrusted assumptions (answerer.py header lists them)

1. Question features come from exact_router_v1's own regexes and functions (imported read-only, no bytecode written).
2. The linker is a port: entity_linker_v2's span rules, but candidates come from `entity.enwiki` (exact title, or
   `title (disambiguator)`), ranked primary title first, then by the subject's fact count. Sitelink counts and the
   alias index (`names_v1.sqlite3`) are not in the drop.
3. `fetch.py` reads `fact(s=qid, p IN admitted properties)` with no LIMIT and only then sets `complete=True`;
   completeness is relative to the v1 snapshot, not to Wikidata or to v2.
4. value_words and rendering (labels, `exact_router_v1._show` for dates) are computed in Python.
5. The JSON layer in `decide_main.sml` is not verified.

## Measurement (tools/reader/measure.py; files under var/reader/)

Items: core-panel entries whose path contains `organ:relation` or starts with `general_reader:` (205, all
`organ:relation`, none `general_reader:`), the panel's 11 `exact_router` items as their own group, and 8 probes.
Oracle7's text came from the head run today (`var/reader/head_answers.jsonl`). Agreement means the reader's
value (normalized) appears in the head's reply. 224 items in 2.1 s through the answerer.

| Group | Items | Reader answered | Agrees with Oracle7 text | Refusals |
|---|---|---|---|---|
| organ:relation | 205 | 60 | 60 / 60 | NoPattern 130, Disagreement 9, NoCandidate 3, NoValue 1, RestatesQuestion 1, HiddenHop 1 |
| exact_router (panel) | 11 | 4 | 0 / 4: the head **withholds** all 11 today | NoValue 5, Disagreement 2 |
| probes | 8 | 1 (Malaysia: Kuala Lumpur, agrees) | 1 / 1 | MultiValued 4, HiddenHop 2, Polar 1 |

- No wrong answers: every reader answer that the head also answered matches it. The four exact_router answers
  (Wild Strawberries: Ingmar Bergman; Andrei Rublev: Andrei Tarkovsky; Tokyo Story: Yasujirō Ozu; Lawrence of
  Arabia: David Lean) are correct, with the property the panel recorded (P57), but cannot be text-compared because
  this drop's head no longer reaches exact_router (it needs `names_v1.sqlite3` and `relations_v2.sqlite3`; its
  exception handler falls back silently).
- 130 NoPattern: the organ:relation route reads question forms ("who wrote", "currency of", "who painted",
  "continent") that the 35 admitted patterns do not cover. This reader is the exact router, not the relation organ.
- Disagreement 9 (+2): the linker offers several senses (The Magic Flute opera vs. films, Metropolis 1927 vs. 2001)
  with different values; without sitelink counts nothing dominates, so the rule refuses instead of picking.
- Multi-valued probes refuse as intended: South Africa (3 capitals), Bolivia, The Matrix (2 directors), Carmen.
  "Is Paris the capital of France?" refuses Polar; "the province of Ontario" and "the film that won ..." refuse
  HiddenHop.

## What the missing relations_v2.sqlite3 costs

- v1 holds **zero** facts for 4 of the 17 admitted properties: P59 (constellation), P1346 (winner), P466 (occupant),
  P208 (executive body). 7 of 35 patterns can never answer here; the panel's 4 constellation items refuse NoValue.
- general_reader_v1 reads a `prop_src` table that v1 lacks, so it cannot run at all on v1.
- w524's docstring: v2 = v1 + 27.7M facts over 2,456 more properties. `complete` is therefore relative to v1;
  an absent row is never turned into a negative answer (NoValue is a refusal).
- The missing `names_v1.sqlite3` (linker index) costs aliases and the sitelink prior; that is what turns the
  shipped DOMINANCE rule into Disagreement refusals above.

## Incident note

My first head run (`measure.py head`, sessions `laneF-panel:*`) set ORACLE7_STATE but still wrote the self_loop
files under `upstream/root/fable-content/.../self_loop/` (root's note). `measure.py head` now calls lane A's
`redirect_self_loop()` (tools/parity/answerers/oracle7.py, 4b1521c) into `var/reader/self_loop`. It was not re-run.
Nothing upstream was reverted by me.

## Reproduce

```sh
python3 tools/dev/check-native --session Veri7vn_Reader --session-root src/isabelle/reader \
  --expect 'VERI7VN_READER PASS' --timeout 300
sh tools/reader/build_decide.sh
PYTHONHASHSEED=0 ORACLE7_STATE=var/reader/state .venv/bin/python tools/reader/measure.py head
.venv/bin/python tools/reader/measure.py run && .venv/bin/python tools/reader/measure.py report
```

## Remaining work

- Lane A's `tools/parity/harness.py` now exists; this measurement used the lane's own driver.
- Add admitted patterns for the organ:relation forms (P50 "who wrote", P38, P170, P30, ...) only via the same
  admission rule (>= 90% on both md5 halves): the HOL side needs no change, the table is a parameter.
- A better popularity prior from the v1 store (e.g. inbound fact counts via `fact_po`) would cut the Disagreement
  refusals; it is linker work and stays untrusted.
