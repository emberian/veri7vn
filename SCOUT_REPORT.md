# Scout report: precision-guards — Oracle7's precision guards as verified declines

Branch `scout/precision-guards` (worktree `var/scout-wt/precision-guards`).
Everything below was run; nothing is claimed that was not.

## 1. What I built

`src/extract/guards/` — the `precision_guard:*` decline decision of Oracle7's
core panel with an Isabelle spine, in the family-kernel shape:

| File | What it is |
|---|---|
| `Guards_Catalogue.thy` | GENERATED: the full inventory — 87 guard codes over 14 folds (w510-w540) with chain positions, extracted from the Python sources' AST by `extract_catalogue.py` (`catalogue.json` is the same data as JSON) |
| `Guards.thy` | the kernel: a `feats` record (per-fold feature bundles, each field commented with the Python it mirrors), `firesL :: layer ⇒ gcode ⇒ feats ⇒ bool` (one equation per modelled guard, quoted from its fold's source), `decision`/`decision_auto` (the chain: first guard that fires wins, per stratum), a fire-exactly-on-the-rule theorem per guard, meaning theorems for the guards with mathematics in them, and the catalogue tie-ins |
| `Guards_Export.thy` | `export_code` of the kernel to SML, bit-level bridges (`mk_char`/`digits_of`/`mk_str`/`str_digits`/`mk_premise`) for the recognizer, a `self_test` of hand-built vectors, an oracle check over all 42 theorems, and the `VERI7VN_GUARDS PASS` marker as an explicit export (RC1 session logs can come back empty — fusion's fix) |
| `Guards_Vectors.thy` | GENERATED: one `feats` literal per recorded item, `vectors_pin` proves by `eval` that the kernel's `decision_auto` on exactly the recognizer's vectors returns exactly the recorded verdict, 114 times |
| `recognizer.sml` | UNTRUSTED: the regex-shaped half — every feature computed from raw (question, route, reply), mirroring the Python pattern by pattern (source in comments); hand-coded scanners where the Python is case-sensitive (`[A-Z]` classes cannot be expressed by the shared `Regex`, which lower-cases pattern literals) |
| `main.sml` | UNTRUSTED driver: JSON in/out, `--selftest`, `--dump-feats` (feeds `gen_vectors.py`) |
| `replay.py` + `gt_import.py` | ground truth: imports the REAL Python guard functions read-only from `upstream/`, synthesizes the minimal organ reply per recorded item, checks the recorded code reproduces; `--emit-inputs` writes the binary's stdin (`inputs114.jsonl`), including the relstore facts (S1's person resolution, G3's premise dates) as recognizer-side inputs |
| `panel114.json` / `fixtures114.json` | the 114 recorded items (question, status, guard, route) from `upstream/workbench/data/core_panel.json`, and the ground-truth replay output (with the layer that emitted each code) |
| `tables_check.py` | 48 checks: the committed catalogue vs a fresh AST extraction, the modelled codes vs the catalogue, the panel rows vs the model |
| `build.sh`, `regex.sml` | MLton build (430 KB binary), lane D's regex engine |

How to run (from the worktree root):

    tools/dev/remote-build hbox src/extract/guards Veri7vn_Guards --expect 'VERI7VN_GUARDS PASS'
    /Users/ember/dev/o7vn/.venv/bin/python -I src/extract/guards/tables_check.py
    sh src/extract/guards/build.sh
    /Users/ember/dev/o7vn/.venv/bin/python -I src/extract/guards/replay.py --emit-inputs
    python3 src/extract/guards/gen_vectors.py      # after a binary rebuild; then rebuild the session
    var/guards/bin/guards --selftest
    var/guards/bin/guards < src/extract/guards/inputs114.jsonl

## 2. What works, with numbers

- **Build green with marker** (receipt in §7): 42 theorems, 0 oracles, exit 0.
- **Ground truth**: the real Python guard functions reproduce all **114 / 114**
  recorded guard codes on the synthesized replies (`replay.py`), across three
  strata (94 head, 19 family, 1 deep — specialists enter the chain above the
  deep guards and are seen by fewer layers).
- **Binary**: the MLton binary (430 KB, 3.8 ms cold, 0.27 ms/item warm)
  reproduces **114 / 114 recorded codes AND 114 / 114 fold layers** through
  recognizer → exported kernel.
- **Pinned in the session**: `vectors_pin` (`by eval`) — the kernel's verdict
  on the recognizer's exact feature vector equals the recorded verdict for
  all 114 items.
- **tables_check**: PASS, 48 checks.

What does not work / is not there:

- The other **67 catalogue codes are not modelled** (w519, w521, w531, w539,
  w540 entirely; the unmodelled rules of the modelled folds). On the 114
  items none of them fires before a modelled one — that is checked by the
  ground-truth replay, not proved.
- The kernel never sees raw text or the store: the recognizer computes the
  features; the S1 person answer and the G3 premise dates are inputs supplied
  by the driver (sqlite reads in `replay.py`). The kernel is verified GIVEN
  the features.
- The recorded panel items carry no organ reply — the replay synthesizes
  minimal replies. The decision logic is exercised; the organ pipeline that
  produced replies is out of scope.

## 3. What I learned (not obvious from the code or docs)

- **w517 re-runs w516's guard with the gate forced open.** `guard9` calls
  `guard8_any` = w516's `guard` with `factual := True`, for questions w516's
  own `factual` rejects but w517's `factual2` accepts (trivia without "?",
  generic-you). So the AST catalogue UNDERCOUNTS w517: it can emit any w516
  code under the weaker gate. The panel's single `R2_dump_for_slot_question`
  item arrives exactly this way ("Name the author of The Waste Land", no
  question mark, `arb:explain_simply` route). `tables_check.py` encodes this
  exception; the catalogue itself is one fold short of the truth.
- **The chain is a stack, not a list**: a reply from a family fold above the
  deep guards is seen only by w532/w533-own/w534 (+w539/w540); every other
  reply by all layers. The recorded data forces three strata (head/family/
  deep); `decision_auto` implements the replay's policy (specialist routes
  tried as family first, then deep).
- **The two stem lengths differ**: w510's `_covered` matches a 5-character
  stem; w513's Q3 and w514's R5 match `group(1)[:6]`. The kernel needed both
  `covered` and `covered6`. Python's `_specifics` returns lowercased,
  apostrophe-stripped dedup keys, so the recognizer must too.
- **The shared Regex engine cannot express a case-sensitive class** (it
  lower-cases pattern literals for the re.I convention). Four features are
  therefore hand-coded scanners over raw text: w510's specifics word walk and
  of-phrases, w514's R5 shape (whose `(?i:in )` inline flag makes only SOME
  prefixes case-insensitive — a subtle mix), w533's unit tokens. SML comment
  syntax eats `)*` in quoted regex prose — cost me one build cycle.
- **w532's `premise_years` unpacks the label from the linker's third tuple
  slot**, which in the drop's linker face is the empty description — the G3
  withhold message names an empty work. Harmless for the decision (label is
  message-only), and my `premise_raw` copies the same unpacking to stay
  faithful to the ground truth.
- **The panel's G5 echo items split into two shapes** (fraction echo for
  "3/8 as a decimal", equation echo for "the derivative of 4x^3 at x = 2"),
  and only the question-STATED given counts as an echo ("Solve 49/x = 7" →
  x = 7 is an answer, not an echo — the fold's own precheck comment).

## 4. Regex-shaped vs semantic (the brief's question)

Which guards are recognizer-only (regex features the kernel merely conjoins)
and which carry kernel-provable mathematics:

| Guard | Shape |
|---|---|
| P7_negative_given, P7_private, G2_private_state (×2), G7_word_sense, R2_dump (×2), S1_person_not_human, G3s_qualifier_dropped, P1_declines_in_words | **regex-shaped**: pattern hits and route prefixes; the kernel adds only the conjunction |
| G3_evidence_misses_question | regex-shaped per term (5-stem coverage) but the kernel does the counting: ≥ 2 specifics and NONE covered (∃/∀ over the term list) |
| Q1/R1_english_as_algebra, Q3/R5_subject_missing, R6_math_on_english | regex-shaped features + kernel word-list filtering (stop words) and length thresholds |
| G5_echo | mixed: the value extraction and norm-contains are recognizer work; the two echo SHAPES are kernel-disjoined |
| G1_sign_kept | two regex features; the kernel's contribution is the signed-negation structure (a negative given in the question that the reply drops) |
| P2_no_number, P4_lookup_for_compute | **semantic**: exact-rational tolerance `|v−g| ≤ max(|g|,1)/10^9`; the kernel proves `rest` keeps fresh numbers, a given is never fresh, a fresh number in the reply blocks P2 |
| G3_date_premise | **semantic**: the asked year against [min−5, max+2] of the recorded dates; kernel proves the interval characterization and tolerance immunity |
| G6_units_not_variables | **semantic**: letter-set inclusion `set(value) ⊆ set(units)`; kernel proves subset + the nonemptiness side condition |
| the decision itself | **semantic**: first-firing-in-chain-order (`decision_iff`), never fires on an unanswered reply, all modelled codes real |

## 5. Dependencies for excellence

- **A shared recognizer library** (owner: whoever lands the next family).
  `regex.sml` is now copied verbatim in acoustics, quantity, discrete and
  guards; the hand-coded case-sensitive scanners here (word walks, proper
  phrases) will recur in any text-facing family. A `Recognizer toolkit`
  theory-neutral SML lib with tests would stop the drift.
- **The relstore read** (owner: relation-reader lane F or a small shared
  shim). S1 and G3 need two sqlite queries; today `replay.py` supplies them.
  The verified relation reader (lane F) is the right home: the guards become
  queries on fetched rows with coverage premises.
- **The real organ replies** (owner: root). The panel does not ship them;
  synthesized minimal replies were enough to pin the decisions, but replaying
  the guards against the true head's replies needs the head pipeline (out of
  scope for a scout).
- **math-organ scout reconciliation** (owner: whoever follows up). Branch
  `scout/math-organ` has an UNBUILT draft modelling P7/G5/G6; this kernel
  models them independently and is green. Decide which idioms survive.

## 6. Proposed follow-up lanes

1. **Guards to catalogue completeness** (M, sonnet). Model the remaining 67
  codes (w519, w521, w531, w539, w540, and the unmodelled rules of modelled
  folds) in the same shape; done when `catalogue_len = length modelled_codes`
  and the tables_check exception for w517's re-run disappears into a proper
  re-run layer. Number that proves it: modelled codes = 87, panel replay
  unchanged.
2. **Negative-panel guard testing** (M, opus). The 810 core-panel items that
  do NOT end in a guard: run the binary over each with the recorded route and
  a reply reconstructed from the answer text, expecting NO guard to fire.
  This is the false-withhold side the 114 items cannot show. Number: 0 false
  firings on the negative set.
3. **Verified relstore premises** (M, fable-adjacent; owner with lane F).
   Lift S1's is_human and G3's date rows into the verified relation reader so
   `human`/`premise` become kernel-side queries with coverage premises
   instead of driver inputs. Number: guards binary answers the S1/G3 items
   from (question, route, reply) alone, replay unchanged.
4. **Guards behind the real head** (L, opus). Feed the binary the actual
   organ replies of a full head run (the fusion harness already drives the
   head); the guards then run as a drop-in checker on live traffic. Number:
   verdicts identical to the shipped chain on N live turns, N ≥ 500.
5. **Recognizer toolkit** (S, sonnet). Extract `regex.sml` + the
  case-sensitive scanners into one tested library (see §5). Number: the four
  families build against the single copy, tests green.

## 7. Honest status

- **No `sorry`, no oracles** in the session (`Thm_Deps.all_oracles` empty over
  all 42 checked theorems; the marker asserts it).
- **Untrusted, named**: `recognizer.sml`, `main.sml`, `regex.sml` (lane D's,
  copied), the relstore reads in `replay.py` (`FakeRS`/`FakeEL`/`FakeRV`),
  `gen_vectors.py`'s literals (from the recognizer's dump). The kernel is
  verified given the features; the features are not.
- **Generated files** (`Guards_Catalogue.thy`, `Guards_Vectors.thy`,
  `fixtures114.json`, `inputs114.jsonl`) are committed for review; each
  names its generator.
- The prior session left a partial draft; this session rebuilt the theory
  proofs, extended the kernel (covered6, the w517 layer, the bridges),
  finished the recognizer, and produced all the numbers above.

**Build receipt** (latest of several equivalent runs):

    $ tools/dev/remote-build hbox src/extract/guards Veri7vn_Guards --expect 'VERI7VN_GUARDS PASS'
    remote-build: hbox Veri7vn_Guards exit 0; exports in .../var/guards/export-remote/Veri7vn_Guards/
    $ grep -m1 'VERI7VN_GUARDS PASS' var/guards/remote-build.log
    VERI7VN_GUARDS PASS theorems=42 oracles=0

(Alternated hbox and persvati throughout; both hosts green.)

## Changed files (handoff)

`src/extract/guards/` in full (added): `ROOT`, `Guards_Catalogue.thy`,
`Guards.thy`, `Guards_Export.thy`, `Guards_Vectors.thy`, `catalogue.json`,
`extract_catalogue.py`, `tables_check.py`, `gen_vectors.py`, `recognizer.sml`,
`regex.sml`, `main.sml`, `build.sh`, `replay.py`, `gt_import.py`,
`panel114.json`, `fixtures114.json`, `inputs114.jsonl`, `README.md`.
`SCOUT_REPORT.md` at the worktree root. Nothing under `upstream/` or the main
checkout was touched; no other paths in this worktree were modified.

Key theorem statements (read them, don't trust the names):

- `fire_*` (22): `firesL L c F ⟷ <the fold's documented condition>` per
  modelled guard (e.g. `fire_G3_date_premise`, `fire_R2_dump_w517`).
- `G3_date_premise_means/tolerated`, `P2_means_rest_empty`,
  `P2_never_on_a_fresh_number`, `givens_are_not_fresh`, `G6_means_subset`,
  `G6_letter_outside_units`, `S1_means_not_a_resolved_human`,
  `G3s_means_uncovered`.
- `decision_iff` (first-firing characterization), `decision_needs_answer`,
  `modelled_codes_in_catalogue`, `vectors_pin`, `vectors_count`.

Consumer: any follow-up lane in §6; the fusion harness if it wants a guard
checker.
