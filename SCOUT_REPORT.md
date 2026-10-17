# Scout report: math-organ (first report — state of the inherited draft)

Target: a verified kernel for Oracle7's head mathematics route on the core
panel — `organ:math` 24 items, `op:` 17, `algebra:solved` 6, and the
`precision_guard` declines that sit on math routes (40 on
`organ:math>evaluate` + 6 on `algebra:solved`; the brief's 114 counts all
guards panel-wide, most of which belong to other organs).

## What the inherited draft is

`src/extract/mathorgan/Math.thy` (1,062 lines, committed as-is at d11b3d3
before any edit of mine) is one theory, session-less and unbuilt. It contains:

- An exact-rational expression language (`expr`, `ev`, `vars`) with a
  reading-independence theorem.
- Two unit families (time: second..year; mass: milligram..pound) with exact
  factors transcribed from the word-problem organ's tables.
- Terminating-decimal detection (`dec_expansion`, sound theorem) and exact
  rendering (`render_rat`, `render_point`), plus a 6-significant-digit
  formatter (`render_g6`) that is pinned only by the self test, not proved.
- Integer square root by binary search (`isqrt`, interval + uniqueness +
  square theorems) and Newton's iteration (`newton`, `newton_last`) with
  `newton_last_isqrt`: the organ's two independent methods provably agree.
- Euclid's algorithm with trace (`euc_res`, `euc_trace`), tied to Isabelle's
  `gcd`.
- A request/outcome kernel: `PercentOf`, `Convert`, `Sqrt`, `GcdLcm`,
  `SolveLin`, `EvalExpr`; six named declines; per-kind soundness theorems.
- Three precision guards as boolean features (P7 negative-given, G6
  units-not-variables, G5 echo) with fire-exactly-on-rule theorems and short
  justification theorems.
- Reply text per route (`reply_of`), with panel-pinned layout strings, and a
  `self_test` of 47 answered kernel calls + guard decisions + reply texts.

## What it does not have (why it cannot build yet)

Found by reading, before any build attempt:

1. **Parse error**: line 256 `(Python's \<open>%g\<open>` — two cartouche
   opens where a close was meant. Depth from there to EOF is +2, so the whole
   back half of the file is nested commentary and the file cannot parse.
2. **Undefined constant**: `want_perfect` (line 824, in the `Sqrt` reply) is
   used but never defined. Ground truth: `oracle_operator_specs_v2._sqrt_parse`
   sets `want = 'perfect'` when the question says "perfect square" — it is a
   property of the question, not of `n`, so `Sqrt` needs a recognizer-supplied
   flag. (The panel's six sqrt items are all plain root questions.)
3. **`self_test` is never asserted**: the comment promises a build-time check
   in a `Math_Export` theory that does not exist. No ROOT, no export code, no
   oracle check — the lane-G scaffolding (ROOT, `*_Export.thy`, build.sh,
   recognizer.sml, main.sml) is entirely missing.

## Coverage vs the panel (draft claims, unverified)

Answered routes the self test pins: 12 percent-of, 12 word:convert, 5
op:unit_convert, 6 integer_sqrt, 6 gcd_lcm, 6 algebra:solved — the 47 answered
math items. Declines modelled: D_echo covers the 6 `algebra:solved`-route
guard declines; guards P7 (6), G6 (10), G5 (6) cover 22 of the 40
`organ:math>evaluate` declines. Not modelled: Q1_english_as_algebra (11),
R1_english_as_algebra (6), R6_math_on_english (1) — 18 items where the head
withholds because the "maths" is a physics/geometry formula on English words.

## Plan from here

Fix the two build blockers, add ROOT + Math_Export (anatomyagri pattern:
single HOL session, exact rationals, no Approximation base), assert
`self_test` at build time, prove an oracle-free theorem list, build on
persvati, MLton a binary, write the untrusted recognizer, and measure on the
87 math panel items against Oracle7's own answers.
