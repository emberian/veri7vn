# The word-problem organ, verified

This folder carries Oracle7's head word-problem organ
(`upstream/root/wander-train/word_problems_v1.py`, reached through head fold
w488, its reply pluralised by fold w490) as one verified program. The organ
reads a single-step textbook word problem -- "What is 17% of 2,400?", "How
many seconds are there in 3.5 hours?" -- by matching one of nine stored
schemas (simple interest, unit price, total cost, sale price, percent of a
total, percent of, motion, unit conversion, rectangle/circle/cone/cylinder/
sphere measures). A schema fires only when every quantity it needs was read
off the text with the right type and the question asks for what the formula
produces; if none fires, or two fire, the organ abstains and the head says
it cannot verify the turn. This narrowness is the organ's own: story-shaped
and multi-step problems ("9 inches more than the width", "106 calories for
8 ounces") are exactly what it declines, which is why `narrow_v1` pushes
them away from the specialists and to the head.

Here the organ is one typed request list. Every quantity is an exact
fraction; every unit has an exact factor in the organ's own base units
(length in metres, mass in grams, volume in litres, time in hours); every
value, decline and printed reply comes from one HOL function.

- The nine formulas, the exactly-one-schema rule, the rounding rules and the
  reply text are written in Isabelle/HOL, with proofs (`Wordprob.thy`).
- The program that answers is that HOL function. Isabelle turns it into
  Standard ML and the MLton compiler that ships inside Isabelle turns that
  into one standalone binary (`var/wordprob/bin/wordprob`). No Isabelle
  process runs when questions are answered.
- The binary speaks the [answerer contract](../../../docs/contracts/answerer.md)
  and answers with the head's own path for this organ,
  `organ:math>word:<schema>`.

## What is proved and what is trusted

| Part | File | Status |
|---|---|---|
| Unit tables (49 factors), geometry pi, w490's 27 plural units | `Wordprob.thy` | HOL constants, transcribed and checked by `tables_check.py` |
| Requests, values, declines, rounding, `%g`/money rendering, reply | `Wordprob.thy` | HOL, proved; exported to SML |
| Export, self test, oracle check | `Wordprob_Export.thy` | HOL; the build fails if a listed theorem depends on an oracle or the self test fails |
| Table transcription check | `tables_check.py` | a Python check of the HOL text against the organ file; not a proof |
| Reading numbers, units and trigger words out of English, and flagging a minus sign in front of a numeral | `recognizer.sml` (regex matcher: `../commons/commons.sml`) | **untrusted**, hand-ported from the organ |
| Rounding, `%g` digit layout (`pow10`, `round_at`, `round_sig`, `render_dec`, `show_int`) | `../commons/Commons_Num.thy` | HOL, proved once for every family (session `Veri7vn_Commons`) |
| JSON framing | `main.sml` | **untrusted** |
| Isabelle code generator, MLton | toolchain | trusted |

Every value is computed **exactly** in rational arithmetic. A theorem per
schema gives its defining equation (`percent_of_value`,
`simple_interest_value`, `convert_value`: a conversion times the target
factor equals the amount times the source factor, and so on). The printed
number is tied to the formula by `stated6_sound`/`stated4_sound`: the
printed decimal is within half a unit in the last significant digit of the
exact value, plus the decimal-places rounding the organ applies first
(`round_dec_error`), and an exact decimal tie rounds up (`round_tie_up` for reals, `round_dec_tie_up` for the organ's `round(v, n)`, `money_round_tie_up` for cents).
`reply_answered_iff` is the exactly-one-schema rule: the reply is an answer
exactly when one schema fired and its formula divides by nothing zero;
`response_template` is fold w488's reply body.

**Stated deviation, money ties.** House rule: decimal ties round up, and
`money_round_tie_up` says so. We keep it rather than adopting half-even,
because the organ's own result on a tie is a property of the binary double
(0.125 is exact, so Python takes the even neighbour; 11.175 is a double just
below the tie and Python takes the lower one), and no one rule reproduces
both. The only probe that differs is `What is 12.5% of $1?` (`$0.13` here,
`$0.12` from the organ); `money_tie_example` proves our side. No core-panel
item is a money tie.

**Negative givens.** The organ reads `-60 km` as 60 km and answers 30 km/h;
the head's precision guard `P7_negative_given` withholds those items. We
decline too, and say why in `Wordprob.thy`: every request carries unsigned
rationals, and a signed distance or radius has no reading in these schemas.
`negative_given_declines` is the kernel half; the recognizer's flag for a
minus sign is untrusted and checked by `score_core.py`.

Two things are deliberately NOT modelled, both float artefacts of the
Python organ, stated in the theory text: binary floating-point rounding
(the organ prints `0.30000000000000004`-style neighbours on exact decimal
ties sometimes; the kernel states exact rationals and rounds ties up), and
`math.isfinite` (an exact rational is always finite). The one tie this
costs on the probe set: `What is 12.5% of $1?` is exactly 1/8, the organ's
`{:,.2f}` rounds the tie to even and prints `$0.12`, the kernel's money
path rounds up and prints `$0.13` (probe wp:78; no core-panel item is a
money tie). One residual fidelity gap: when the printed value's unit is an
abbreviation ("min", "kg"), fold w490 pluralises the first number-unit
pair in the STEPS rather than the value; the kernel pluralises the value.
Every core-panel and probe shape prints the value first with a spelled-out
unit, so the two agree there.

## Run it

    tools/dev/remote-build persvati src/extract/wordprob Veri7vn_Wordprob -d src/extract/commons --expect 'VERI7VN_WORDPROB PASS'
    python3 src/extract/wordprob/tables_check.py
    src/extract/wordprob/build.sh          # MLton: var/wordprob/bin/wordprob
    PYTHONDONTWRITEBYTECODE=1 python3 src/extract/wordprob/score_core.py --allow-assurance-text-change   # all 924 core questions
    python3 src/extract/wordprob/score.py var/scout/probes/all87.jsonl --ref head

`--ref head` compares against the shipped head's own replies (one run of
lane A's `tools/parity/answerers/oracle7.py`, state under `var/scout/`),
`--ref organ` against the organ module imported read-only. The 24
core-panel word items (`upstream/workbench/data/core_panel.json`, paths
`organ:math>word:*`) are items 0..23 of `var/scout/probes/all87.jsonl`.

Composition now distinguishes no recognized schema from a checked refusal.
An empty request list returns `provenance.taken=false`, so another organ may
try. A nonempty request list which the kernel declines (negative given,
ambiguous schemas, or impossible formula) returns `taken=true` and its named
word-problem decline path. The dispatcher preserves that refusal instead of
letting a later organ replace it with an answer.

Replies now end after the formula steps. The inherited sentence claiming
that the question's quantities, units and requested goal had been checked
was removed: those readings come from the untrusted recognizer. The scorer
keeps the original recorded replies and separately counts this exact suffix
removal; `--allow-assurance-text-change` permits only that stated difference.
