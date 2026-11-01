# Lane W5-16: word-problem kernel onto commons

Plain version: the word-problem organ's kernel no longer carries its own
copy of the rounding and number-printing code; it uses the shared session
`Veri7vn_Commons`. The three lemmas that Isabelle recorded as "trusted by
evaluation" are now proved by ordinary simplification. The rule for money
ties is written as a theorem. Questions that give a negative number ("A car
travels -60 km in 2 hours") are now declined instead of answered with the sign
dropped.

## Receipt

    tools/dev/remote-build persvati src/extract/wordprob Veri7vn_Wordprob -d src/extract/commons --expect 'VERI7VN_WORDPROB PASS'
    -> exit 0, fresh build on persvati
    -> VERI7VN_WORDPROB PASS theorems=37 oracles=0

The marker is the last command of `Wordprob_Export.thy` (after the oracle scan
and the self test). `tables_check.py` now also fails if a lemma or theorem of
either theory is missing from the scan list, if `by eval`/`by normalization`
appears, or if the marker is not in the last ML block.

Binary: `src/extract/wordprob/build.sh` -> `var/wordprob/bin/wordprob`, 399,848
bytes (was 383 KB), sha256
`661a12b92c93a257ce85c372fd3437d846ba38bb9e814cb5e03c61573f4e5f7d`; generated
SML sha256 `44e872daf8baba37226a6c9f78360279411720e7cf5bafa0003259d6fd1e2bbd`.

## Numbers (`PYTHONDONTWRITEBYTECODE=1 python3 src/extract/wordprob/score_core.py`)

| Check | Result |
|---|---|
| core questions | 924 |
| organ (`word_problems_v1.answer`, imported read-only) answers | 50 |
| binary answers | 41 |
| answer-or-decline agreement with the organ | 915/924; the 9 differences are exactly the 9 negative-given items, each declined by the binary |
| schema disagreement where both answer | 0 |
| the 24 core word items | 24/24 status + path equal to `core_panel.json`, 24/24 response text equal to the recorded head reply |
| `precision_guard:P7_negative_given` items in the panel | 12 (9 the organ answered, 3 it declined); binary withheld on 12/12, as the panel recorded |
| answered questions with a minus sign before a numeral | 0 |

So "924/924" holds as: 915 identical to the organ, and the 9 others are the
items the head also withholds; against the head's recorded status every one of
the 924 that the binary answers or declines on a word path matches.

## Theorem statements, verbatim (new or changed)

    theorem round_dec_tie_up:
      assumes "v * of_nat (10 ^ n) = of_int k + 1 / 2"
      shows "round_dec n v = of_int (k + 1) / of_nat (10 ^ n)"

    theorem money_round_tie_up:
      assumes "wlab r = STR ''$''" and "wvalue r * 100 = of_int k + 1 / 2"
      shows "rounded None r = of_int (k + 1) / 100"

    theorem money_tie_example:
      "rounded None (PercentOf True (25 / 2) 1) = 13 / 100"

    theorem negative_given_declines:
      "neg ==> ~ answered (reply_checked neg x) /\ schema (reply_checked neg x) = STR ''negative_given''"

    theorem unsigned_given_unchanged:
      "~ neg ==> reply_checked neg x = reply_of x"

    theorem checked_answered_iff:
      "answered (reply_checked neg (rnd, rs)) <-> ~ neg /\ (EX r. rs = [r] /\ ~ wdecline r)"

    lemma pow10_4_real: "(10::real) ^ 4 = 10000" by simp   (and _5_, _6_)

`round_tie_up`, `round_at_error`, `round_sig_sound` now come from
`Commons_Num.thy`. (The HOL source uses the Isabelle symbols for the
connectives; ASCII above.)

## Decisions

- Money tie: kept round-half-up, written as `money_round_tie_up` and in the
  README as a stated deviation. One probe differs ("12.5% of $1": `$0.13` here,
  `$0.12` from the organ, whose double is an exact tie and Python rounds ties
  to even); no core item is a money tie. Half-even would match that probe but
  not the float-noise ties (11.175), so no rule matches the organ everywhere.
- Negative given: DECLINE, not carry the sign. Every request holds unsigned
  rationals; a negative distance, time or radius has no reading in these nine
  schemas; the head already withholds these items (`P7_negative_given`), so
  declining agrees with the panel's recorded status. Carrying the sign would
  mean answering -30 km/h, which no panel records. The check is a recognizer
  flag (untrusted: a minus sign directly before a numeral, at text start or
  after a space, bracket or dollar sign) passed to the kernel's `reply_checked`;
  the theorems prove the kernel never answers when it is set. Completeness of
  the flag is tested, not proved (0 leaks over 924 questions).

## Found on the way

`substMinus` in `recognizer.sml` (U+2212 to hyphen) built its result reversed:
any question containing U+2212 was scrambled before the quantity reader saw
it. Fixed (`rev`). No core question contains U+2212, so no number moved.

## Untrusted parts and remaining

- Untrusted: `recognizer.sml`, `main.sml`, `commons.sml`, the negative flag.
- Not done: the 87-probe head comparison (`score.py`) was not re-run; it needs
  the scout's recorded head replies under the scout worktree. The 3 `P7`
  panel items the organ declines are unaffected.
- Not done (out of scope): the head's fold order around w488 (parked in
  triage 4).

## Changed files

`src/extract/wordprob/{ROOT, base/Wordprob_Base.thy, Wordprob.thy,
Wordprob_Export.thy, build.sh, main.sml, recognizer.sml, tables_check.py,
score_core.py, README.md}`; `regex.sml` removed (commons.sml replaces it).
Nothing outside this directory and this file.
