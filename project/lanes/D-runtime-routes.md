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

## Measured word problems

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

The implementation connects dimension validity, arithmetic, and displayed
values in one exported `measured_reply` entry point. It also proves a
speed/distance inverse and base-unit conservation. The two obsolete
unit-erasing motion/geometry recognizers were removed, so a missed rephrasing
cannot silently fall back to their unchecked unit assumptions. Output forms
such as `m2` and `m^2` retain their requested degree; conflicting or unsupported
powers refuse. Only a recognized legacy schema gets a decisive numeric-syntax
refusal, preserving unrelated factual questions' fallthrough.


## Guard-policy boundaries

The inherited G6 binary falsely refused a correct typed motion response
`[ev:derived] 432000 km.` for 60 km/s sustained for two hours. Its existing
predicate treats any letters drawn from input unit names as symbolic
variables, across every `organ:math` route. Reproduction:
`var/wordprob/g6-baseline.json`. The new predicate applies only to
`organ:math>evaluate`; `G6_preserves_word_quantities` establishes that routes
beginning `organ:math>word:` cannot trigger it. A fabricated symbolic `7m`
response on the evaluator route remains covered. Proof attempt:
`var/guards/remote-attempts/20261018T073036Z-ce18c223f5d8` (passed).

Independent final-consumer probing exposed a separate inherited P2 defect:
a cylinder with radius 0 cm and height 2 m was correctly computed as zero,
then withheld when the question explicitly requested cubic meters. The old
predicate discarded every response number equal (within tolerance) to any
given. Earlier zero probes lacked the wording that activates P2, so they did
not exercise this condition. The repaired P2 tests numeric presence instead.
Its statements establish: firing implies no recognized numeric values and no
recognized number word; any numeric value prevents P2; a number word prevents
P2. These are feature-policy guarantees, not proof that a present number is
correct. G5's separate assignment-echo check remains active. No route or
provenance exemption was added. Baseline independent receipt:
`var/C-runtime-consumers/routes-D-independent.json`.

G3s is another feature heuristic: its statement establishes that a qualifier
phrase is absent, not that the answer is semantically incorrect. The Facts
owner found correct painter/author rows suppressed when the response said
only “It is by ...”. Their repair includes the actual matched row subject,
which both makes the answer self-contained and satisfies the qualifier
check. No G3s predicate or proof change is part of this lane.


## Final validation and immutable inputs

- Wordprob proof: persvati `20261018T072740Z-941f1b187ce5`, 49 theorem checks,
  zero oracles, 32 seconds for the target session. Actual log contains
  Wordprob_Units and Wordprob_Export completion plus Finished target. Current
  ROOT/theory files match the snapshot. Export SHA-256:
  `f120d993c83de022e4e9b0b10ee48b6ddd94c5fad2814c9a50f377489f5a7ffa`.
- Final Guards P2+G6 proof: persvati `20261018T075102Z-107afe12d0c8`,
  50 theorem checks, zero oracles, 122 seconds target session. Actual Finished
  completion, uncancelled build-exit sentinel, and matching source snapshot.
  Export SHA-256:
  `736b288377920032be97e62e43a653c7ce7b2aefbd69a8c78c6e3026569dc2c3`.
  This supersedes the G6-only proof `20261018T073036Z-ce18c223f5d8`.
- All three build scripts now use `tools/dev/native-compile`, preserving
  their flat MLB recipes. The helper freezes actual consumed SML, validates
  the successful current-proof export, and records the compiler and binary.
- Current Math native receipt:
  `var/mathorgan/native-attempts/20261018T073637Z-aadc6c3858a0/compile-inputs.json`;
  binary `df1dfdc1f76069aea404a57643b1402e784adacc3ec575b9b0b2e52aa13dadec`.
  This supersedes the earlier echo binary hash above without changing its
  source or proof export.
- Current Wordprob native receipt:
  `var/wordprob/native-attempts/20261018T074410Z-ed0e4c5d462a/compile-inputs.json`;
  binary `b51543bcaed2d99edd9c47b757c90a31463600ad7f15782c03f5f542787b04c9`.
  It captures shared ExactNumeric
  `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.
- Final Guards native receipt:
  `var/guards/native-attempts/20261018T075842Z-259942c39ebe/compile-inputs.json`;
  binary `e6be5295292e5861ce9ae9089dcefca0aeb3dd8e0778933fe64658fed0005ad0`.
  The recognizer is unchanged; the helper binds the new P2+G6 proof export.
- `test_units.py`: 3 methods pass, comprising 18 supported inputs and 16
  refusals, plus 12 actual guard-composition cases: motion, conversion,
  coincident values, explicit-output-unit zero geometry and zero-duration
  distance, actual nonnumeric refusal, spelled/numeric zero, retained G5
  assignment echo, and the symbolic evaluator negative control. Zero length and zero elapsed time for distance give zero; zero
  elapsed time for speed refuses. Tiny areas, mixed units, scientific/fractional
  numbers, negative inputs, forged numeric masks, and requested output powers
  are covered.
- `tools/dispatch/test_routes.py`: all 8 methods pass after the new Guards
  build, including all 114 historical synthetic guard inputs.
- Initial unit-aware dispatcher with chemistry selected, reader/document disabled:
  **16/16** expected status/value results, with actual final guard silence on
  every answered result. This includes the seven original unit failures,
  conversion, two equation forms, an incidental derivative assignment,
  zero length/rate/distance duration, zero speed duration, and a correct
  measured value coinciding with an input number.
  Receipt: `var/wordprob/units-final-dispatch.json`.
- Final combined P2/Fusion dispatcher probe with the same selected
  configuration: **7/7** valid values reach the consumer with actual guard
  silence (zero cylinder volume, zero rectangle area, zero-duration distance,
  coincident 2 km, 604 cm perimeter, 216 km/hour, 360 m). The first P2-only
  run was 5/7 because the then-current Fusion binary intercepted two zero
  inputs. After the Fusion owner's repair, the same questions all pass;
  numeric expectations compare exact values across string/JSON-number output
  forms. Receipt: `var/wordprob/p2-final-dispatch.json`, including all four
  current route/network binary hashes.
- Standalone repaired seven-case replies:
  `var/wordprob/semantic-boundary-repaired.json`.
- The retained 924-question reference comparison reports 46 answers versus
  the old binary's 41 and the original organ's 50. The five additions are
  rectangle perimeters, independently checked **5/5** at values 22, 28, 38,
  42, and 48 (`var/wordprob/units-core-gains.json`). Nine negative-given
  refusals remain; no negative given is answered. Twelve both-answered
  geometry/motion cases deliberately use the new unit-aware schema paths.
  All 24 core word items retain status/path and only the already documented
  assurance-suffix deletion; all 12 P7 items remain withheld. The unchanged
  old-parity scorer exits 1 for these explicit additions/schema changes;
  `var/wordprob/units-core-score.txt` records them. No shipped specialist-panel
  completion or new whole-head parity claim is made.

Remaining finite limits: no general multi-step word solver, no arbitrary
English parser, no true-pi interval bound, and no cubic-length-to-litre output
bridge. Legacy non-measured schemas still refuse numeric notations outside
their decimal binding grammar rather than truncating them. English role
selection and route recognition remain untrusted.

Changed files after the committed echo packet: `src/extract/mathorgan/{build.sh,README.md}`;
`src/extract/guards/{Guards.thy,Guards_Export.thy,build.sh,README.md}`;
`src/extract/wordprob/{ROOT,Wordprob_Units.thy,Wordprob_Export.thy,build.sh,
recognizer.sml,measured.sml,main.sml,test_units.py,README.md}`; this report.
No changes to Wordprob.thy's existing mathematics, no axiom or oracle, and no
commit made by this lane.
