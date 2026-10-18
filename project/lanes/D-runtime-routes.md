# Unit-aware word problems and requested equation solutions

Owner: Codex runtime/routes, 2026-10-18. Work follows the initial route/math
packet and word-problem wording repair; this lane makes no commits.

## Equation requests

The recognizer now requires a complete finite equation-solving request. It
captures both sides from that request, including prefix or suffix “for x”.
It no longer extracts an incidental assignment from a derivative question.
For a recognized request it sends `SolveLin a b c d []`: the existing
`solve_linear_sound` and `solve_linear_complete` establish the unique root
when `a != c`, without the inherited veto for a number already in the input.
The HOL kernel and its theorem statements are unchanged.

The actual reply guard has the same complete-request exception to its G5
assignment feature. Recognition is still untrusted. A derivative question
answered merely by repeating its evaluation point still fires G5.

Changed files: `src/extract/mathorgan/recognizer.sml`,
`src/extract/guards/recognizer.sml`, `tools/dispatch/test_routes.py`.
The separate unit-aware packet below is not part of this recognizer-only
change. Prefix/suffix request tests pass.

Validation: 8 route test methods pass, including 8 complete equation forms
through the actual guard, the incidental-derivative negative control, and
114/114 historical synthetic guard inputs. All 7 math boundary test methods
(28 cases) also pass. Final native hashes: math
`9772428e32644d925343b23b2409a4705c4371d0cca72bd3018cc6aceee8591f`; guards
`d2d6017c01c912139b19d839fb7c87a3cfcb2869c24e71e387ec37fc51669207`.

The recorded 93-question math comparison now has 87 matching status/path
pairs; six derivative questions are intentionally unrecognized instead of
being misread as linear equations and subsequently vetoed. They remain
withheld. The other answer differences are the 41 previously documented
assurance-suffix removals. This is not a new specialist-panel completion
claim. Comparison receipt: `var/mathorgan/echo-panel.json`.

## Measured word problems (in progress)

Seven independent baseline probes exposed lost or ignored units: rectangle
and cylinder mixed lengths, geometry with a non-length unit, requested area
and speed units, a non-length rate numerator, and seconds in a rate whose
old implementation silently assumed hours. Exact questions and original
responses are saved in `var/wordprob/semantic-boundary-baseline.json`.

`Wordprob_Units.thy` keeps source and output units in typed requests. Its
geometry value is the shape formula on metre-scaled inputs divided by the
output length scale raised to the shape's degree. Distance and speed retain
both numerator and denominator units. Wrong dimensions, negative physical
inputs, and zero speed duration are refused by the kernel. The English
adapter uses the shared `ExactNumeric` masks, resolves each marker through
the returned table, and never computes the answer itself.

The geometry model uses the existing explicitly selected rational pi value:
157/50, or the rational value of the old IEEE-double constant. The unit
conservation and scale laws concern that model; they are not error bounds
against true pi. Output rounding uses six significant digits directly,
without the old preliminary rounding to six decimal places. The new
`measured_precision` theorem bounds numeric display error against the exact
rational model value, subject to obtaining a rendered digit pair.

The draft connects dimension validity, arithmetic, and displayed values in
one exported `measured_reply` entry point. It also states a speed/distance
inverse and base-unit conservation. Proof build and native tests are still
pending; none of these draft claims count as completed panel evidence yet.


## Guard-policy boundaries

The current G6 binary falsely refuses a correct typed motion response
`[ev:derived] 432000 km.` for 60 km/s sustained for two hours. Its existing
predicate treats any letters drawn from input unit names as symbolic
variables, across every `organ:math` route. Reproduction:
`var/wordprob/g6-baseline.json`. The proposed predicate applies only to
`organ:math>evaluate`; `G6_preserves_word_quantities` establishes that routes
beginning `organ:math>word:` cannot trigger it. A fabricated symbolic `7m`
response on the evaluator route remains covered. Proof attempt:
`var/guards/remote-attempts/20261018T073036Z-ce18c223f5d8` (pending).

G3s is another feature heuristic: its statement establishes that a qualifier
phrase is absent, not that the answer is semantically incorrect. The Facts
owner found correct painter/author rows suppressed when the response said
only “It is by ...”. Their repair includes the actual matched row subject,
which both makes the answer self-contained and satisfies the qualifier
check. No G3s predicate or proof change is part of this lane.
