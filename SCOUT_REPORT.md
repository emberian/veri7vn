# Scout report: word-problems (head organ `word_problems_v1.py`)

Branch `scout/word-problems`, 2026-10-17. The kernel is
`src/extract/wordprob/` (Wordprob.thy 751 lines, 32 lemmas/theorems,
0 sorry/oops/axioms; recognizer.sml, regex.sml, main.sml untrusted;
tables_check.py; score.py; build.sh).

## 1. What I built

One typed request list over exact rationals for the organ's nine schemas
(percent-of, percent-of-total, convert, simple interest, unit price, total
cost, sale price [off and pct], motion [distance and speed], geometry
[rect area/perimeter, circle area/circumference, cone, cylinder, sphere]),
the exactly-one-schema abstention rule, the organ's rounding/money/`%g`
printing, and fold w488's reply text with w490's pluralisation — all as one
HOL function `reply_of`, exported to SML, compiled with MLton behind a
hand-ported untrusted recognizer that only reads numbers, units and trigger
words off the text. The binary speaks the answerer contract
(`organ:math>word:<schema>` paths, the head's own).

Run it:

    tools/dev/remote-build hbox src/extract/wordprob Veri7vn_Wordprob --expect 'VERI7VN_WORDPROB PASS'
    python3 src/extract/wordprob/tables_check.py     # 49 unit factors + 2 pi + 27 plurals vs the organ file
    src/extract/wordprob/build.sh                    # MLton -> var/wordprob/bin/wordprob (383 KB)
    python3 src/extract/wordprob/score.py var/scout/probes/all87.jsonl --ref head

## 2. What works, with numbers

References: the shipped head (lane A's `tools/parity/answerers/oracle7.py`,
one process, `ORACLE7_STATE` under `var/scout/o7state`, tip
`oracle_release_runtime_w540`; I re-ran it today and it reproduced the
earlier replies 87/87), and the organ module imported read-only.

- **Core panel** (`upstream/workbench/data/core_panel.json`, the 24
  `organ:math>word:*` items = 12 percent_of + 12 convert):
  **24/24 identical status + path + response text** to the head.
- **87-probe set** (24 core + 63 hand probes over all nine schemas,
  declensions, and near-miss shapes): 67 items the head routes to the word
  organ — **67/67 identical status+path, 66/67 identical text**. The one
  text diff is `What is 12.5% of $1?` = exactly 1/8: the organ's
  `{:,.2f}` float rounds the tie to even (`$0.12`), the kernel's money
  path rounds ties up (`$0.13`). No core-panel item is a money tie.
- **Organ parity** (module run directly, no head): 75 items answered by the
  organ, **75/75 identical status+path, 0 over-fires** (we never answer
  when the organ declines). Text 45/75, and every one of the 30 text diffs
  I inspected is score.py's crude reply reconstruction (no w490
  pluralisation, no money format, same tie) — against the real head, whose
  pipeline includes w490, all of these but the tie match. `extra12`
  adversarial probes: 7/7 word items identical text.
- **Speed**: 87 replies in ~16 ms (≈0.2 ms/item); the harness's 4 GB limit
  is not approached (383 KB binary, no heap growth: stateless loop).
- In-build self-test (evaluated by the code generator inside the session):
  12 full reply strings + abstention + ambiguity + unit tables, printed as
  `VERI7VN_WORDPROB PASS theorems=28 oracles=0`.

What does not work / is out of the organ by design: story-shaped and
multi-step items (the MULTISTEP guard: "more than", "left", "twice", ...),
relational quantities ("9 inches more than the width"), rates written
"miles per minute" (the organ only sees a rate when the unit has a slash)
— the organ itself declines these and `narrow_v1` pushes them away; the
kernel declines identically (0 over-fires above).

## 3. Build receipts

    tools/dev/remote-build hbox src/extract/wordprob Veri7vn_Wordprob --expect 'VERI7VN_WORDPROB PASS'
    -> remote-build: hbox Veri7vn_Wordprob exit 0; exports in
       var/wordprob/export-remote/Veri7vn_Wordprob/
    -> log line: VERI7VN_WORDPROB PASS theorems=28 oracles=0

(twice: after the motion_speed fix and after the half_rat export; same
receipt both times). Final MLton binary sha256
`02fa18f1989ab780bcf32f6d35464c0c84e4b8ed2849f558cfd60f2f284a5ed1`
(the binary the numbers above were scored with).

## 4. What I learned that was not obvious

- **The organ's motion-speed keeps the distance unit**: value is
  `miles / hours` (150/2.5 = 60), NOT converted to base units. My first
  kernel converted (96560.64 m/h). The organ converts only in `s_convert`.
- **The numeral is regex group 2** (`m.group(2)`), group 1 being the
  optional `$` — an easy porting trap; reading group 1 crashes on any text
  without `$`.
- **Python's tie behaviour is the only real semantic divergence**: money
  `{:,.2f}` and `round(x, n)` are round-half-even on the DOUBLE's exact
  decimal expansion. On binary-exact ties (k/8 at cent level) that is
  plain half-even; on other ties it is float noise the exact-rational
  kernel cannot and should not reproduce. 1 case in 87.
- **Head routing ≠ organ answering**: 8 probe items the organ answers are
  routed by the head to `op:unit_convert` (a *later-declared* fold that
  wins) or blocked by `precision_guard`. An organ kernel can never reach
  head parity on those without modelling the head's fold order — that is
  head-lane work, not organ work.
- **Isabelle2026-RC1 datatype selectors need `(name: ty)`**, not
  `(name :: ty)` (the latter parses as a mixfix annotation with a cryptic
  "keyword infix expected"). This single syntax error had blocked every
  prior build attempt on this branch; the proof repairs shipped earlier
  were real but unreachable behind it.
- **MLton + generated code**: HOL n-tuples export as nested pairs
  (`(a, (b, c))`); `foo'` exports as `fooa`; `#field` selectors on values
  whose type flows through a `List.filter`-style lambda fail to resolve —
  annotate the lambda's argument type or pattern-match.
- **Worktree pitfalls**: `python3 -I` strips the venv (numpy) needed by
  the head answerer — use `.venv/bin/python` with
  `PYTHONDONTWRITEBYTECODE=1`, and `PARITY_UPSTREAM` must point at the
  main checkout's `upstream/` (worktrees have none).

## 5. Dependencies for excellence

- **A shared exact-decimal session**: round_dec/round_sig/render_dec/
  stated6 machinery is restated here from lane G's quantity family. One
  shared session (with the tie rule as a parameter) would deduplicate the
  hardest proofs. Owner: whoever lands the second consumer (this scout
  proves the pattern copies; a lane should extract).
- **The head's fold order** (`op:unit_convert` precedence, precision_guard
  blocks, narrow_v1 pushes) for head-level routing parity. Owner: the
  head/exam lane (lane A context), not the organ kernel.
- **The tie decision**: whether the money path should round half-even (to
  match the organ on binary-exact ties) or stay half-up (the provably
  sound choice). One lemma re-proof either way. Owner: the polish lane.
- **w490's STEPS pluralisation for abbreviated units** ("min", "kg"): the
  kernel pluralises the value, the head pluralises the first number-unit
  pair in STEPS. No core/probe shape hits it. Owner: polish lane.

## 6. Proposed follow-up lanes

1. **wordprob polish and lock** (S, sonnet): adopt the family into
   `src/extract/` behind the shared pattern; add the half-even money tie
   rule (or document half-up as a stated deviation, one lemma either way);
   fix w490 STEPS pluralisation for abbreviations; wire score.py's two
   references into the family's handoff. Done when: 87-probe head parity
   67/67 text (or 66/67 with the tie written down as a stated deviation
   with the panel number showing 0 core items affected), core 24/24 held.
2. **Shared exact-decimal library** (M, opus): extract the decimal/
   significant-digit machinery from quantity + wordprob into one session
   `src/extract/decimals/` with the proofs once and the tie rule
   parameterised. Done when: both families rebuild green remotely with
   their self-tests passing and the generated render code paths
   byte-identical to today's.
3. **Recognizer differential fuzz** (M, sonnet): generate question shapes
   (units x numerals x phrasings x case x U+2212 minus) and diff the
   binary against the imported organ module status+path. Done when: 0
   status+path diffs over the fuzz corpus and every text diff classified
   (tie / w490 / _fmt artefact).
4. **Head word-organ composition** (L, opus): model the head folds around
   w488 (routing precedence, guards, w490 as a separate pass) so the
   verified organ can sit inside the packaged head. Done when: the 87-probe
   set scores 87/87 status+path+text at HEAD level (today: 67 organ-level
   + 8 organ-answered-but-routed-elsewhere + 12 both-declined).

## 7. Honest status

- All 28 exported theorems proved; the build checks `Thm_Deps.all_oracles`
  is empty and fails otherwise. No `sorry`, `oops`, `skip_proof`, axioms.
- The self-test runs inside the session (generator-evaluated), not in the
  shipped binary.
- Untrusted by construction (and marked so in file headers): recognizer
  .sml, regex.sml, main.sml (JSON framing), tables_check.py (a Python
  transcription check of the HOL tables against the organ file — the
  organ's Python tables are the spec, transcribed; equality to them is
  checked, not proved).
- Float artefacts not modelled: the tie case above, and `math.isfinite`
  (an exact rational is always finite). Both named in the theory text and
  the family README.
- `head_replies_fresh.jsonl` regenerated by me today (87/87 identical to
  the earlier session's file); scoring numbers above are against the fresh
  file. The organ reference imports
  `upstream/root/wander-train/word_problems_v1.py` read-only.
- Not done: parity harness per-specialist runs (there is no word
  specialist; the organ is head-side, so the head comparison above is the
  board that exists for it).
