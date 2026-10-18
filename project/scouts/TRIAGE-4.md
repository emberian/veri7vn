# Triage 4: verification log (lane T4, 2026-10-17)

Three scout branches read: `precision-guards`, `word-problems`,
`document-route`, all head routes. Scratch under `var/triage/t4/` (one `git
archive` per branch). No scout worktree edited (two of its data files were
copied out, read-only). The Oracle7 head was not run. Outcomes and new lanes
are in [`project/swarm/WAVE5.md`](../swarm/WAVE5.md).

| Scout | Verified | Merged | Follow-up |
|---|---|---|---|
| precision-guards | rebuilt fresh; binary 114/114 against the panel's recorded paths; three guards read against their folds | yes, `7c861ab`, README and report corrected | W5-15 (no false withholds; proof without `eval`) |
| word-problems | rebuilt fresh; binary byte-identical; 24/24 core items; kernel equals the organ on all 924 core questions | yes, `93e8aa1` | W5-16 (port onto commons) |
| document-route | rebuilt fresh; 30-item measure re-run; theorems read; store schemas read | yes, `0db9328` | W5-17 (all 231 core items, compute gateway) |

## Rebuilds (fresh, from `git archive` of each branch)

Each remote tree name (`t4-<branch>`) was new to the host, so nothing cached
was reused; every log shows `Building ...` then `Finished ...`.

```
var/triage/t4/t4-precision-guards$ tools/dev/remote-build hbox src/extract/guards Veri7vn_Guards --expect 'VERI7VN_GUARDS PASS'
  -> exit 0; VERI7VN_GUARDS PASS theorems=42 oracles=0     (Veri7vn_Guards 0:30 elapsed)
var/triage/t4/t4-word-problems$ tools/dev/remote-build persvati src/extract/wordprob Veri7vn_Wordprob --expect 'VERI7VN_WORDPROB PASS'
  -> exit 0; VERI7VN_WORDPROB PASS theorems=28 oracles=0   (Base 0:04, Veri7vn_Wordprob 0:28)
var/triage/t4/t4-document-route$ tools/dev/remote-build hbox src/isabelle/document Veri7vn_Document --expect 'VERI7VN_DOCUMENT PASS'
  -> exit 0; VERI7VN_DOCUMENT PASS theorems=31 oracles=0   (0:08)
```

MLton binaries built from those exports with each branch's `build.sh`:
guards 430,552 bytes, `--selftest` prints `self_test=true`; wordprob 383,128
bytes, sha256 `02fa18f1...`, equal to the scout's; document 199,848 bytes.

**Does `by eval` leave an oracle?** A two-lemma session on persvati
(`var/triage/t4/t4-evalcheck`, `T4_Evalcheck`): the same goal proved `by
eval` and `by simp`; `Thm_Deps.all_oracles` gives 1 and 0. So any theorem
proved `by eval` depends on the code generator as an oracle.

## precision-guards

**Theorem count.** The marker's 42 are: 23 `fire_*` theorems, each proved
by `simp add: firesL_def` (they restate the definition table); 6 structural
(`order_distinct` x3, `modelled_distinct`, `catalogue_len`,
`modelled_codes_in_catalogue`); `decision_iff` and `decision_needs_answer`
x2, the first-firing characterization; and 10 meaning theorems, of which
`G3_date_premise_means/tolerated`, `P2_never_on_a_fresh_number`,
`givens_are_not_fresh`, `G6_letter_outside_units`,
`S1_means_not_a_resolved_human` say more than the definition. 0 oracles is
true of these 42. `vectors_pin` and `vectors_count` (in
`Guards_Vectors.thy`, which imports the export theory, so the scan cannot
see them) are `by eval`: they carry the oracle. The report's "no oracles in
the session" is wrong for them; the README said "proved by `eval`" and now
says what that means.

**Three guards against the Python** (`upstream/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/`):

| Guard | Python | Kernel | Verdict |
|---|---|---|---|
| G3_date_premise | w532 `premise_years`: link the asked item, collect years from `DATE_PROPS`, None if no years or `min-5 <= year <= max+2`; checked after G1 and G2, on any route | `fires_G3dp`: answered, `premise = Some (_, y, Ys)`, `Ys != []`, not `lmin Ys - 5 <= y <= lmax Ys + 2`; linking and years are driver inputs | matches |
| P2_no_number | w511 `guard`: `asks_number and not rest and not <number word in resp>`, `rest` = reply numbers not within `1e-9*max(abs(g),1)` of a given | `answered & asks_number_v4 & rest nums_q nums_resp = [] & ~numword_resp`, `close` the exact-rational form of the tolerance | matches (float `1e-9` versus exact 1/10^9 differs only at the tolerance edge) |
| G6_units_not_variables | w533 `_c533_one`: path starts `organ:math`, `unit_symbolic`: letters of the stated value nonempty, `ALGEBRA` absent from q, letters subset of the unit tokens' letters | `answered & pfx "organ:math" & value_letters != [] & no_algebra_q & set value_letters <= set unit_letters` | matches |

P4_lookup_for_compute also read: `givens and asks_number and
path.startswith(RETRIEVAL)` with the same seven prefixes; matches.

Inside w511 the Python checks five rules the kernel does not model
(P7_over_24h_a_day, P7_direction, P7_zero_volume, P9_math_by_lookup,
P3_unit_dimension) between P7_private and P4. `decision_iff` is
first-firing among modelled rules only; the README's "Honest limits"
paragraph says this.

**The 114 items.** `core_panel.json` has 114 items whose path starts
`precision_guard:`, 20 distinct codes, exactly the 20 the kernel models. The
binary over the branch's `inputs114.jsonl`, compared to the panel's recorded
status and full path (not to the scout's fixtures): **114 / 114 identical**.
The replies in `inputs114.jsonl` are synthesized so that the real guards
fire; this shows agreement on firing inputs only. The non-firing side is
W5-15.

## word-problems

**Coverage.** `core_panel.json` has 24 items routed `organ:math>word:*` (12
`percent_of`, 12 `convert`). The binary over all 924 core questions answers
50. The 24: status and path 24/24 equal to the panel, response text 24/24
equal to the scout's recorded head replies (`head_replies_fresh.jsonl`, read
in place). The other 26 the head sends elsewhere:

| Head's recorded path | Items | Example |
|---|---|---|
| `precision_guard:P7_negative_given` (withheld) | 9 | "A car travels -60 km in 2 hours. What is its average speed?": kernel answers 30 km/h |
| `precision_guard:Q1_english_as_algebra` (withheld) | 6 | "What is the area of a circle with radius 3 m?": kernel answers 28.2743 square units |
| `network>core_math` (answered) | 6 | "A cyclist rides at 18 km/h for 2.5 hours..." |
| `op:unit_convert` (answered) | 5 | "How many hours are in 6 weeks?" |

The organ module (`word_problems_v1.answer`, imported read-only with
`PYTHONDONTWRITEBYTECODE=1`) gives the same answer-or-decline on all 924 and
the same schema on all 50; it reads -60 as 60 too. The kernel is faithful to
the organ, sign-drop included; the head's P7 guard is what catches it.

**Who carries the work.** The recognizer: it decides the schema, reads the
numbers and units, and decides to decline (`reply_answered_iff` only says
"answered iff exactly one request and it is not a decline"). The kernel
computes the value exactly and prints it; its proved content is the rounding
bounds (`round_at_error`, `round_sig_sound`, `stated6_sound`,
`stated4_sound`, `round_dec_error`). 16 of the 28 scanned theorems are
`*_value` restatements of `wvalue` by `simp`. The three `by eval` lemmas
(`pow10_4_real` etc.) do not reach the scanned theorems (the scan reports
none), but should be `simp`.

## document-route

**Theorems.** Read all 18: they are real characterizations of `decide`, not
tautologies (e.g. `explain_tier_precedence`: an Explain answer comes from the
first tier with hits, after tiers with none; `weak_answer_needs_check_or_definition`:
a weak-route answer needs `checked` or `definitional_release`;
`unverified_reply_shape`: an unverified passage is withheld and cites
nothing). They are a decision table over flags the untrusted fetch sets
(anchor, checked, subject_defines, covered, disambiguates, turn class).
`checked` is always False today. `clarify_shape` and the `*_iff` theorems
are close to their definitions.

**Measure re-run.** Branch binary from the fresh export; `measure.py` with
the scout's two sample files copied into the scratch tree and `upstream`
linked: `items 30  status 27  path 25  text exact 18 first-line 7 prefix 0
differs 5`, misses #75, #80, #83, #92, #99, as reported. The route is chosen
from the question (`fetch.evidence`), not from the recorded path. The 30 are
a sample of 231 core items on these paths (104 `act:clarify`, 41
`arb:definitional`, 26 `corpus_query:property_of`, 25
`unverified:factoid:*`, 20 `factoid:`, 10 `organ:converse`, 4
`unverified:corpus`, 1 `verified:weak`).

**Store schemas** (`wikipedia_specialist.sqlite3` under m13e7 bench and
m13e8, opened with sqlite): tables `metadata`, `article` (the nine columns
named), `title_alias`, `page_sentence`, FTS5 `source_rows(claim_id, fact,
fact_sha256, page_id, sentence_ordinal)`, schema
`oracle-stage5m13b-wikipedia-sqlite-v3`: confirmed. The report's counts
are the `metadata` rows (articles 291,964 / 6,339,707; claims 3,051,662 /
20,529,863); the tables hold more: `article` 294,144 / 6,341,887,
`page_sentence` 3,162,926 / 20,641,127. The `rel` column is in m13e8's
`edges.sqlite` (`edge(src, dst, claim_id, term, rel)`), not in the FTS
table; edge counts (max rowid) 1,424,396 and 11,690,108 confirmed.

**A write under `upstream/`, mine.** My first schema read opened the two
stores with `mode=ro`. Both are in WAL mode and already had `-wal` (0 bytes,
dated 17 Oct 20:30, before this triage) and `-shm` files; a read-only open
rewrites `-shm`, and `find upstream -newer var/triage/t4/.stamp` lists the
two `-shm` files (32 KB each). The database files and the `-wal` files are
unchanged. Later reads used `immutable=1`, which touches nothing. The
re-run `measure.py` opens the stores through upstream's own
`DBpediaQuery` and touches the same `-shm` files. Use `immutable=1` for
read-only work on these stores.

## Claims not verified

- precision-guards: `replay.py` against the real Python guard functions
  (the 114/114 ground truth); `tables_check.py` (48 checks); the catalogue's
  87 codes against a fresh AST extraction; the w517 re-run explanation.
- word-problems: the 87-probe numbers beyond the 24 core items (67/67, 66/67
  text), the 75-item organ text comparison, `tables_check.py`.
- document-route: the head replies (from the scout's one head run, not
  re-run); the Explain tiers (no `capability:*` item on the panel); the
  five presentation passes' behaviour beyond the 30 items.

## What scouts got wrong

- precision-guards: "no oracles in the session" is false for
  `vectors_pin`/`vectors_count` (`by eval`, outside the scan). The
  commit message of `71588e3` says 41 theorems; the marker says 42 (fine
  at the tip).
- word-problems: proposes a shared exact-decimal library that
  `src/extract/commons/` already is; does not say the binary answers 26 core
  questions the head routes elsewhere, 9 of them with a dropped minus sign.
- document-route: store sizes are the `metadata` table's, not the tables';
  the `rel` column is placed in the store list though it lives in
  `edges.sqlite`. The measure depends on sample files outside git.
