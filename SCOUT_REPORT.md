# Scout report: math-organ

Target: a verified kernel for Oracle7's head mathematics route on the core
panel — `organ:math` 24 items, `op:` 17, `algebra:solved` 6, and the 46
`precision_guard` declines on math routes (40 on `organ:math>evaluate`, 6 on
`algebra:solved`): 93 items in all.

**Result: 93/93 parity with the original head.** The binary's status, path and
exact response text are identical to Oracle7's own replies on every one of the
93 items, measured against a fresh run of the original head (not just the
panel's recorded statuses — the head was run again on all 93 questions and
agreed with the panel 93/93 itself, so the ground truth is doubly pinned).

## What I built and how to run it

- `src/extract/mathorgan/Math.thy` (1,430 lines) — the HOL kernel: exact
  rationals, two unit families, terminating-decimal detection and rendering,
  6-significant-digit rendering, integer sqrt by binary search AND Newton's
  method (proved equal), Euclid with trace, the request/outcome kernel
  (percent, convert, sqrt, gcd/lcm, linear solve, expression eval), seven
  named declines, seven precision guards (P7, G6, G5, Q1/R1/R6 as one rule
  with three names, and the algebra echo via the kernel's own D_echo), reply
  text per route, and a self test pinning all 47 answered panel values, the
  guard decisions, and one reply text per route. No `sorry`, no axioms, no
  oracles (checked at build time: 41 theorems, 0 oracles).
- `src/extract/mathorgan/Math_Export.thy` + `ROOT` — session
  `Veri7vn_MathOrgan`, export of `reply_of` and constructors, the oracle-free
  check and the self-test assertion at build time.
- `src/extract/mathorgan/recognizer.sml` (UNTRUSTED) — hand ports of the
  question-reading layers: w55's algebra host (scan-outward-from-'='
  extraction, like-term-folding linear reader in x), the op specs'
  integer_sqrt/gcd_lcm/unit_convert (triggers, parses, and the decisive
  `_TO_BASE` stem table), the word schemas s_percent_of/s_convert with the
  word-unit tables, the evaluate organ's math-token classifier
  (`_is_math_word`, including the 2-3-letter glue rule that separates the Q1
  shapes from the R6 shape), and the guard folds' question-side conditions in
  the chain's precedence order (P7 → Q1 → R1 → R6 → G6 → G5), plus the G4
  thousands-separator strip.
- `src/extract/mathorgan/main.sml` (UNTRUSTED) — the answerer-contract driver
  (JSONL on stdin/stdout, lane D's JSON reader; all content from the kernel).
- `src/extract/mathorgan/build.sh` — MLton build from the remote export.
- `tools/dev/math-diff` — the scorer: runs the answerer over the 93 items and
  diffs status+path+response against the recorded head replies.

Commands (from this worktree root):

    tools/dev/remote-build hbox src/extract/mathorgan Veri7vn_MathOrgan --expect 'VERI7VN_MATHORGAN PASS'
    sh src/extract/mathorgan/build.sh            # -> var/mathorgan/bin/mathorgan
    python3 tools/dev/math-diff --answerer var/mathorgan/bin/mathorgan

(The head replies it diffs against were produced once by
`var/mathorgan/panel/run_head.py`, which runs `upstream/oracle7.py` on the 93
items; `var/` is gitignored, so the replies live in this worktree's var and
the recipe is in the report.)

## Build receipts

- `remote-build persvati Veri7vn_MathOrgan exit 0; VERI7VN_MATHORGAN PASS
  theorems=41 oracles=0` (also green on hbox earlier in the session at
  theorems=40, before the Q1/R1/R6 guards).
- MLton: `var/mathorgan/bin/mathorgan`, 403 KB, ~4 MB RSS, 93 replies in
  10 ms wall including process start. Harness memory cap is 4 GB; no risk.

## What works, with numbers

`math-diff`: **match 93 / 93**, zero wrong, zero not-taken:

| route | items | ok |
|---|---|---|
| organ:math>word:percent_of | 12 | 12 |
| organ:math>word:convert | 12 | 12 |
| op:unit_convert | 5 | 5 |
| op:integer_sqrt | 6 | 6 |
| op:gcd_lcm | 6 | 6 |
| algebra:solved | 6 | 6 |
| precision_guard:P7_negative_given\|organ:math>evaluate | 6 | 6 |
| precision_guard:Q1_english_as_algebra\|organ:math>evaluate | 11 | 11 |
| precision_guard:R1_english_as_algebra\|organ:math>evaluate | 6 | 6 |
| precision_guard:R6_math_on_english\|organ:math>evaluate | 1 | 1 |
| precision_guard:G6_units_not_variables\|organ:math>evaluate | 10 | 10 |
| precision_guard:G5_echo\|organ:math>evaluate | 6 | 6 |
| precision_guard:G5_echo\|algebra:solved | 6 | 6 |

"ok" means status, path AND full response text equal the head's reply byte
for byte (including the `[ev:derived] …` word-organ texts, the estimate
traces and take-6 step traces of the op replies, and the two Euclid items
whose trace is long enough that the closing sentence is truncated by take-6).

The original head itself: median 3.6 s per question (SymPy import), 93/93
agreement with the panel's recorded statuses and paths.

### Known divergences OFF the panel (spot-checked)

- `Solve for x: 2x + 2x = 8.` — both solve x=2, but the step text differs
  (mine folds to `read it as 4x = 8`; the head reads `2*x + 2*x = 8`). The
  recognizer folds like terms; the head's step text quotes the sides verbatim.
- `Solve for x: x + 1 = x + 2.` — the head ANSWERS "No value of x satisfies
  it" (and "Every value of x satisfies it" for identities); my kernel declines
  both as D_zero_slope with the honest out-of-fragment text. The kernel's
  zero-slope decline conflates two cases the head reports as answers.
- `What is 3/8 + 1/4?` — the head's fraction_arith op answers; not in this
  prototype's scope (no panel item; a small kernel extension).
- Perfect-square questions (`is 1764 a perfect square`) are supported by the
  kernel (want flag, `reply_sqrt_perfect`) and the recognizer's trigger, but
  have no panel item; untested against the head.

## What I learned that was not obvious

1. **The 93 items are decided by five independent code paths that never meet
   in one file**: the w55 algebra host (early, w55!), the op specs host
   (w59-era), the w488 word-problem fold (late), the w4xx evaluate organ, and
   the guard folds (w511-w533). Reproducing the route means reproducing the
   PRIORITY: algebra before ops before word schemas, guards wrapping all.
   Two "How many …" templates split by a regex detail: `how many U are in N U2`
   (op, if both words are the op's short stems) vs `how many U are there in N
   U2` (word organ, because "there" breaks the op's pattern) vs
   `how many grams are in N kilograms` (word organ, because "kilograms" is
   not an op stem — only "kg" is).
2. **The unit word in the word-organ reply is the question's own word**
   ("3500 milligrams") while the step text inside uses the canonical table
   key ("3.5 gram = 3.5 x 1 / 0.001 milligram"). The value word and the step
   word come from different tables. This is why the kernel's WordConv carries
   a "question's word" literal.
3. **Which guard fires is decided by micro-features**: P7's unit list has no
   "cm", so `side -5 cm` falls through P7 to R6; Q1 excludes questions
   containing `/` (so `m/s` and `kg/m3` questions fall to R1/G6); Q1/R1 need
   ≥3 content words (so `perimeter of a rectangle 7 m by 4 m` — only 2 —
   falls to G6); R1 needs the reply's read-span to contain letters, which the
   evaluate organ's 2-3-letter glue rule decides ("5 m/s" reads as letters,
   "5 cm" at sentence end does not). I ported that classifier rather than
   guess; it is what makes R1 vs R6 come out right.
4. **The derivative items are algebra items**: w55 extracts `x = 2` from
   "the derivative of 4x^3 at x = 2" by scanning outward from '=' over math
   chars, solves it, and then the G5 echo guard withholds the answer because
   the question itself states x = 2. The kernel models this exactly:
   `Ask (SolveLin 1 0 0 2 [2])` declines D_echo, and the reply layer reports
   it as `precision_guard:G5_echo|algebra:solved` (solve_echo_iff proves the
   decline condition). This path was mislabelled `algebra:out_of_fragment`
   before this session — a fix worth keeping.
5. **Take-6 truncation is load-bearing on op replies**: gcd(96,156) has a
   7-step Euclid trace; the head prints six steps and silently drops the
   closing "no remainder left…" sentence. The kernel's `trace_lit` (take 6)
   reproduces this.
6. **The core panel has no expected answers, only q/status/path** — so
   "measuring against Oracle7's own answers" means re-running the head. It
   takes ~3.6 s per question (SymPy), ~6 min for 93; worth knowing when a
   lane wants to extend the ground truth.
7. SML/code-gen gotchas that cost an hour: Isabelle's exported `int` is a
   wrapper (`Int_of_integer of IntInf.int`) and `nat` needs
   `nat_of_integer` — constructor arguments must be converted; `String.index`
   does not exist in the Basis; SML list patterns use `[a, b]` not `[a; b]`
   (that's OCaml); and a missing closing `"` on a `fun` clause swallows the
   next clause's opening quote and reports the error three clauses later.

## Dependencies for excellence

- **Nothing hard is missing.** The kernel is self-contained (exact rationals,
  no oracles, no Approximation). The one structural debt: the recognizer
  duplicates the op unit table and the word unit tables by hand
  (`opUnits`, `convUnitOf`) — the kernel's `mfactor` tables and the organ's
  `_TO_BASE`/`TIME`/`MASS` overlap but are not identical (the op table has
  length/volume stems the kernel does not). A `tables_check.py` in lane G's
  style, pinning the recognizer's lists against the organ files, would close
  the copy drift; someone owning `src/extract/commons/` should host it.
- The harness cannot score the head math route (`--specialist` needs a
  specialist panel; organ:math items exist in no specialist panel). The
  parity harness owners (whoever owns `tools/parity/`) could add a
  core-panel-fragment mode: `--core 'organ:math|op:|algebra'` that scores
  against recorded head replies. Until then, `tools/dev/math-diff` is the
  scorer; it lives with this family.

## Proposed follow-up lanes

1. **Lane: algebra degenerate cases as answers** (S, sonnet). Teach the
   kernel the head's two zero-slope outcomes: identity (`every value of x
   satisfies it`, answered) and contradiction (`no value of x satisfies it`,
   answered), as new answer shapes beside D_zero_slope, with soundness
   theorems (substitution gives the constant difference both ways). Done
   when: the three off-panel solve shapes above match the head's replies,
   and math-diff is still 93/93. Consumer: this family's recognizer.
2. **Lane: fraction arithmetic op** (S, sonnet). `_frac_parse`/`_frac_fn`/
   `_frac_ref` (cross-multiplication) as a `FracArith` request over the
   kernel's rationals; recognizer pattern `N/D op N/D`. Done when:
   "What is 3/8 + 1/4?" matches the head's reply exactly, and the self test
   pins it. Consumer: this family.
3. **Lane: word-organ reply steps verbatim** (M, sonnet). The word organ's
   step text quotes the equation sides as read (`2*x + 2*x = 8`), so the
   kernel's `solve_head`/`lin_text` should carry the recognizer's side terms
   (a `lin list` instead of folded a,b) to render verbatim while the kernel
   still computes on the folded form. Done when: `2x + 2x = 8` matches the
   head's full reply text, and the 93 hold.
4. **Lane: math-diff into the parity harness** (S, opus — tooling, with a
   design decision). A `--core <path-filter>` mode scoring against recorded
   head replies (head run once, replies checked in as data or re-run). Done
   when: `harness.py --core 'organ:math|op:|algebra' --answerer …` prints the
   same 93/93. Owner: parity tooling.
5. **Lane: tables_check for the math family** (S, sonnet). Pin the
   recognizer's `opUnits`/`convUnitOf` lists and the kernel's mfactor table
   against `_TO_BASE` and the word organ's tables, lane-G style. Done when:
   the check runs in CI and fails on a one-factor drift.

## Honest status

- All 41 theorems proved, no `sorry`, no oracles (build-time check).
- The recognizer, driver and regex engine are untrusted by construction and
  say so in their headers; every value, decline, reply text and path comes
  from the kernel.
- 93/93 parity is against a fresh head run recorded in this worktree's
  `var/mathorgan/panel/head_replies.jsonl` (var/ is gitignored; the runner
  script is `var/mathorgan/panel/run_head.py`, reproduced in the repo as
  part of this report's recipe). The head itself agreed with the panel
  93/93 on status+path, so the ground truth is not self-referential.
- Not measured: behaviour on adversarial or non-English inputs beyond the
  spot checks; the `want=perfect` sqrt path and the fraction op against the
  live head; long-run memory (single process, streaming, ~4 MB).
