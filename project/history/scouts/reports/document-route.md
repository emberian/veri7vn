# Scout report: document-route

Branch `scout/document-route`, commits `f94ce0e` + `06987ec`. Target: Oracle7's
document route — `organ:converse`, `unverified:factoid:fts|page`,
`corpus_query:property_of`, `arb:definitional`, `act:clarify` — as one verified
decision over untrusted fetched evidence, measured against the recorded head
(tip `w540`) on 30 core-panel items of exactly those paths.

## 1. What I built

A HOL kernel of the route's *decision*, an untrusted fetch that builds its
evidence with the organs' own shipped code, and an MLton binary that speaks the
answerer contract.

- `src/isabelle/document/Document_Route.thy` (511 lines) — the kernel. Records
  `claim`/`pool`/`evidence`; datatypes `turn` (Explain cue_kind | Weak
  weak_route | Statement | Fallback) and `outcome` (Answer | UnverifiedPassage
  | Declined | Clarify); `decide`, the path/status/response/citation renders.
- `src/isabelle/document/Document_Route_Export.thy` — six computed
  statement-checks (st1–st6), an oracle scan (`Thm_Deps.all_oracles` must be
  empty over the 18 named theorems), the marker
  `VERI7VN_DOCUMENT PASS theorems=31 oracles=0` (31 is the antiquotation's
  flattened conclusion count), and the SML export including
  `natural_of_integer`/`integer_of_natural` so the driver can build evidence.
- `tools/document/fetch.py` (untrusted) — builds evidence with upstream's own
  code imported read-only: runtime b's `property_of` rule and
  `DBpediaQuery` over the m13e7 bench store, w420's `_f420_try` over both
  stores with a synthetic declined parent, `organ_converse_v1.answer()` for
  the statement move, w420's own WHQ/SELF_Q/OWNED_FORMS/`_numbers` gates, and
  the chain's five presentation passes (`w516.present`, `w517.present2`,
  `w518.present3`, `w519.present3b`, `w520.present4`) run verbatim over the
  kernel's rendered reply.
- `tools/document/document_main.sml` + `build.sh` — MLton binary
  `var/document/bin/document` (200 KB): JSON-lines evidence in, reply out;
  self-test gate from the exported `self_test`.
- `tools/document/answerer.py`, `tools/document/measure.py` — the answerer
  contract and the 30-item comparator (path comparison strips the later folds'
  decorations and names them).

Run:

    /Users/ember/dev/o7vn/tools/dev/remote-build hbox src/isabelle/document \
      Veri7vn_Document --expect 'VERI7VN_DOCUMENT PASS'
    bash tools/document/build.sh
    PYTHONDONTWRITEBYTECODE=1 PYTHONHASHSEED=0 /Users/ember/dev/o7vn/.venv/bin/python \
      tools/document/measure.py        # 30-item comparison, writes measure.json

**Build receipt** (current tree, after the `natural`-tier change):
`remote-build: hbox Veri7vn_Document exit 0`, log line 239
`VERI7VN_DOCUMENT PASS theorems=31 oracles=0`; export regenerated 2026-10-17
21:23 EDT; binary built from that export at 21:23:41. (`rb18`–`rb20` in
`var/document/` are the same-content builds on persvati/hbox; the marker line
is identical across hosts.)

## 2. What works — numbers

30 core-panel items covering every target path (6 statement, 5 fts, 5 page,
3 corpus-answered-empty, 2 unverified-corpus, 1 precision-guard corpus, 4
arb:definitional, 4 clarify), head replies recorded once, one process, tip
w540; my side one process, stores opened once:

| measure | match |
|---|---|
| status | **27/30** |
| path (decorations stripped, named) | **25/30** |
| response text exact | **18/30** |
| + first line exact (head appends a vessel-receipt paragraph) | **25/30** |
| latency p50 / max per item | 1.0 ms / 64 ms |

The 18 exact include all 5 `unverified:factoid:*` quotes and 4 of 6 statement
replies byte-identical to the head, citations included.

The 5 remaining text differs are two named ceiling classes:

- **#83** `precision_guard:P4_lookup_for_compute|corpus_query` — the head's
  guard replaces an asserted corpus answer to a compute-shaped question
  ("What is the volume of a cube with side 4 cm?") with the w517 withhold
  text; my kernel shows the passage unverified (checked=False always).
- **#75, #80, #92, #99** `arb:definitional` — on the core panel this path is
  *arithmetic-dominated*: "What is 9 cubed?", "2 to the power 12", "15 pounds
  in kilograms", "12!/10!". The head routes them to the math organ and
  withholds ("I compute exactly or not at all"); my cascade finds no document
  answer and the terminal clarifies. Status differs on the three non-question
  forms (#80/92/99: my clarification vs head withheld), path on all four.

Status mismatches are exactly #80/92/99; path mismatches those plus #75/#83.

## 3. What I learned that was not obvious

- **The factoid gate is subtler than its regex.** w420's `chat` admits
  GUARD_Q shapes and bare `?` into the function, but the factoid attempt
  itself fires only for `WHQ.match` questions (`if not is_wh: return res`).
  "Tell me the capital of Chile" therefore never reaches `_f420_try` and falls
  to the converse organ — modelling the entrance regex instead of the
  is_wh condition sent #360 down the wrong route.
- **The reply text is produced by a five-pass presentation stack**
  (w516–w520), each fold adding rules ("empty labels left inside brackets by
  stripped pronunciations", year-range dashes, truncation marks). The passes
  are module-level functions, importable, and documented never to change what
  is asserted — so the verified kernel can render and the organs' own
  presentation can polish, without trusting it with the decision. Two of the
  five passes exist only for store debris ("( ; pre-reform Russian: ; )").
- **verified_retrieval's law is exactly check-or-definition.** A weak-route
  sentence is asserted only if the cube's own chain answers, or the sentence
  yields exactly one candidate of the asked type that passes the cube CHECK;
  otherwise the passage is shown quoted and the reply is withheld. On this
  sample every head weak-route reply was downgraded to `unverified:` or
  guarded — the head released no unchecked assertion on these paths. The cube
  CHECK is the one engine piece not ported; `checked` is therefore always
  False and my kernel is *stricter* than the head by construction.
- **arb:definitional on the core panel is not a document route.** All four
  sample items are unit conversions or arithmetic whose end state is a math
  refusal. The document kernel needs a compute-shape classifier *before* the
  document cascade, ending in a withheld (not clarified) terminal — the
  clarify text ("I didn't fully parse that") is false for "What is 9 cubed?".
- **The converse organ's "statement" is not page lookup.** It answers a noun
  phrase with the *topic's own defining sentence* ("The country in which the
  city of Lyon lies" → the Lyon page's first sentence; "The inventor of the
  Braille alphabet" → the *inventor* page). Both head and my organ call pick
  the same page and claim id — the citation `[enwiki_…]` matches byte-for-byte.
- **Store shape** (both builds, schema `oracle-stage5m13b-wikipedia-sqlite-v3`):
  `article(page_id, title, normalized_title, canonical_url, raw_record_sha256,
  abstract_sha256, categories_json, sentence_count, admitted_sentence_count)`,
  `title_alias(normalized_title → page_id)`, `page_sentence(page_id,
  sentence_ordinal → source_rowid)`, FTS5 `source_rows(claim_id, fact,
  fact_sha256, page_id, sentence_ordinal)`, `metadata`. Scales — m13e7 (bench,
  DBpedia+OpenStax): 292k articles / 3.05M claims / 1.42M edges; m13e8 (deep,
  enwiki+DBpedia): 6.34M articles / 20.5M claims / 11.7M edges (adds a `rel`
  column). m13e8's admitted sentences already have foreign-script parentheticals
  emptied ("( ; )"), which is why the presentation passes exist.
- **The aa fold's tiers are 3-deep, verb-conditioned for `when`.**
  CAUSE/PROCESS_TIERS are specific→broad regex lists; when-questions select
  tiers by the *asked verb* (a flat order regressed "When did WWII start?").
  The kernel's `tiers : natural list` + `first_tier` models both; the fetch
  computes each claim's tier with the organs' own regexes (not yet exercised
  by the core-panel sample — no `capability:*` items are on it).
- **@{thms} flattens `and`-conclusion theorems**: 18 named theorems print as
  31 conclusion-statements in the marker. A Pure-local micro-session
  (`var/document/thmcount/`) confirmed single-`and`-chains stay one fact; the
  count in the receipt is the flattened one.

## 4. Dependencies for excellence

- **The cube CHECK port** (owner: a lane; engine
  `oracle_cube_reader_v1_4.py` + `verified_retrieval_v1.py`): earns
  `verified:weak|` answers and fixes #83's class together with the
  precision guard (`w516.guard`, also importable). Without it the kernel is
  sound but over-strict.
- **A compute-shape classifier + withheld terminal** for arb:definitional
  items (owner: this lane's successor; the math organ's refusal text lives in
  the w-chain).
- **Presentation passes as a shared import** (owner: whoever lands the first
  text-parity lane): the five `present*` functions are the only text-hygiene
  layer; every future route lane should call them rather than reimplement.
- **`capability:*` panel items** to exercise the tiered pick: the core panel
  has none; the engines' own benchmarks (`wander-train` test sets) are the
  place to score the Explain route.

## 5. Proposed follow-up lanes

1. **Cube-check lane** (M, opus): port the reasoning cube's frame/link/bind/
   CHECK as untrusted evidence flags (or verified, if the relation reader
   already did it — reuse lane F's `src/isabelle/reader/`), wire `checked`
   through the kernel's Weak branch, add the precision guard as a fetch rule.
   Done when: the 30-item sample scores 30/30 status and ≥29/30 path, and
   `verified:weak|` appears on at least one previously-unverified item the
   head also verifies.
2. **Compute-gateway lane** (S, sonnet): classify compute-shaped turns
   (digits/operators/unit words) before the document cascade; end them in a
   withheld decline with the math organ's refusal text, not the clarify
   terminal. Done when #75/80/92/99 match the head's status and path.
3. **Explain-route scoring lane** (M, sonnet): build the aa/y cue evidence
   (CAUSE/PROCESS/VERB tiers) over the m13e8 store and score the kernel's
   Explain branch on the engines' own cause/process/when benchmark sets
   (measured: what the aa fold was admitted on). Done when the tiered pick's
   answers match the aa fold's own picks on ≥90% of that set with the anchor
   law intact.
4. **Statement-route generalisation** (S, opus): the converse organ's full
   move set (request/ack/definition variants, WordNet `noun_senses` paths)
   over more than noun-phrase statements. Done when the 6/6 statement parity
   holds on a 30-statement extension sample drawn from the same panels.

## 6. Honest status

- No `sorry`, no `oops`, no `skip_proof`, no new axioms: the export theory's
  ML block fails the build if any of the 18 named theorems carries an oracle
  (`Thm_Deps.all_oracles`), and the marker asserts `oracles=0`. All theorem
  statements are non-vacuous implications/iffs over `decide`; st1–st6 are
  computed checks of the rendered texts, evaluated by the code generator and
  re-evaluated by the binary's self-test at start-up.
- Untrusted, by construction: the turn classification (which route a question
  takes), the store reads, the regexes, `checked` (always False — the cube is
  not ported), the presentation passes, and the JSON I/O in
  `document_main.sml`. The kernel decides only on the flags and claim lists
  fetch provides; every theorem says only what an answer means about that
  evidence.
- Nothing under `upstream/` was written (state redirected to
  `var/document/diag-state`, `PYTHONDONTWRITEBYTECODE=1` everywhere).
- Not run: the full parity harness on a specialist panel (scout scope was the
  30-item comparison the brief names); `capability:*` paths are unexercised
  beyond the kernel's own st1 check.

## Triage 4 corrections (2026-10-17)

- Rebuilt fresh on hbox from a `git archive` of the branch:
  `VERI7VN_DOCUMENT PASS theorems=31 oracles=0` (18 named theorems; the
  count is flattened conjunctions, as the report says). The 30-item measure,
  re-run with a binary built from that export: status 27/30, path 25/30, text
  18 exact plus 7 first-line; the same five misses (#75, #80, #83, #92, #99).
- The theorems are not vacuous, but they are a decision table over flags the
  untrusted fetch sets: `anchor_present`, `checked`, `subject_defines`,
  `covered`, `disambiguates` and the turn class. `checked` is always False, so
  the weak-route `Answer` branch is reached only through
  `definitional_release`. What the kernel guarantees is that an answer cites
  only claims the fetch admitted, at the first matching tier, and that an
  unchecked passage is never asserted.
- The measure needs `var/scout/document-route/items.jsonl` and
  `head_replies.jsonl` (not in git; the head replies came from one head run
  by the scout). The 30 items are a sample of 231 core-panel items on these
  paths (104 `act:clarify`, 41 `arb:definitional`, 26
  `corpus_query:property_of`, 25 `unverified:factoid:*`, 20 `factoid:`, 10
  `organ:converse`, 4 `unverified:corpus`, 1 `verified:weak`).
- Store schema (read with sqlite): confirmed as written for both
  `wikipedia_specialist.sqlite3` files. The counts quoted (292k / 3.05M,
  6.34M / 20.5M) are the `metadata` table's; the tables hold more rows
  (m13e7: 294,144 articles, 3,162,926 page_sentence rows; m13e8: 6,341,887
  and 20,641,127). The `rel` column is in m13e8's `edges.sqlite`, not in the
  FTS table; edge counts 1,424,396 and 11,690,108 confirmed.
