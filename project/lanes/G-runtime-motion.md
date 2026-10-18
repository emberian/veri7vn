# Multi-leg average speed

This packet extends the word-problem route to two to eight explicit journey
legs, or two rates with an explicit equal-times/equal-distances statement.
It computes total scalar path length divided by total elapsed time. It does
not compute displacement velocity, infer equal weights from two rates, or
accept arbitrary prose around an extracted pair of numbers.

Each leg retains its own units and one of three forms: distance plus duration,
rate plus duration, or distance plus positive rate. A stopped interval has
zero distance and positive duration, and therefore lowers the trip average.
A zero-duration leg is allowed only when it contributes zero distance without
an undefined division. Distance divided by zero speed is never admitted, even
when distance is also zero. The complete journey needs positive total duration.

The reader uses the existing ExactNumeric module. Complete finite clauses,
including the requested speed unit, must match. Unsupported units, malformed
numerals, missing leg quantities, trailing qualifications, more than eight
legs and unspecified weighting refuse. Single-leg measured questions retain
the existing route. Recognition remains untrusted.

The HOL model normalizes lengths to metres and durations to hours and reuses
the existing measured Speed computation and six-significant-digit renderer.
The proved connected statements establish:

- Valid journey inputs yield a valid measured Speed request.
- The displayed-unit speed, converted back to metres/hour and multiplied by
  total elapsed hours, equals total distance in metres.
- A reply answers exactly when the typed journey is valid and its numeric
  rendering succeeds; zero total time cannot answer.
- The reply states the selected rendering; with no explicit decimal rounding,
  its error is at most absolute model value / 200000.
- Explicit equal times give the arithmetic mean; any common nonzero duration
  gives the same result as the canonical duration.
- Explicit equal positive distances with positive rates give the harmonic
  mean; changing the common nonzero length preserves that result.
- Stopped intervals contribute zero distance and their full elapsed duration.

These statements concern the typed scalar journey. They do not prove English
interpretation, physical measurement quality, or a per-answer certificate. The
runtime still labels recognition untrusted; the theorem inventory is static.

Baseline: eight selected journey questions are withheld by the previously
captured Wordprob native and return None from the upstream word-problem adapter.
The record is `var/wordprob/multileg/baseline.json`. This is a capability probe,
not a new shipped-specialist panel score. No whole-head suite was run.

Final checks:

- Managed proof `var/wordprob/remote-attempts/20261018T090819Z-d9762cfdc06d`
  passed on persvati, actual Motion/Export completion and Finished target in
  29 seconds. The marker reports 60 statements and zero oracles. Two earlier
  attempts failed on proof tactics; no theorem premise was weakened to pass.
- Generated export SHA-256:
  `474c4de4f976eb4dbaf616ef55ce824091eec07a04bae8285ac02ee5f3bd218e`.
- Immutable native manifest:
  `var/wordprob/native-attempts/20261018T091142Z-6a00a65989eb/compile-inputs.json`.
  Binary SHA-256:
  `612d81b4feaf8f6ab8bdc070d714b13b02c6d4e34efa4f8ee9bfa08c2a61f8ff`.
- Five new test methods pass: 20 independently expected values, eight invalid
  typed journeys, 17 malformed/ambiguous/extra-input refusals, retained single-leg
  routing, and all 20 answers through the actual precision guards. The existing
  three measured-unit methods also pass.
- The actual dispatcher passes **24/24** selected outcomes: all 20 answers and
  four decisive refusals. `var/wordprob/multileg/final-dispatch.json` records
  the question, reply, stages and all Math/Wordprob/Fusion/Guards binary hashes.
  Every successful new answer is from `Wordprob.journey_reply`, path
  `organ:math>word:motion_legs`, with no precision-guard veto.

No jobs remain. Sources/native are frozen for root review and capture. There
is no new Linux compilation or specialist-panel score in this packet.

Owned files: `src/extract/wordprob/{Wordprob_Motion.thy,Wordprob_Export.thy,ROOT,
motion.sml,main.sml,build.sh,test_motion.py,README.md}` and this report. Frozen
Math closed-expression source and the shared route adapter are unchanged.
