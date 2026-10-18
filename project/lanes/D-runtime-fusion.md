# Whole numeric inputs and zero magnitudes in Fusion

Owner: Codex runtime/dispatch. Root transferred `tools/fusion/answerer.py`,
`numeric.py`, `test_numeric.py`, `test_validity.py`, and `src/extract/fusion/`.

## Observed defect and repair

After the physical specialists correctly declined `Convert 1/0 m to cm.`, the
network reader recovered the denominator suffix as a new given, `0 m`. Its
kernel then rejected every zero physical quantity, yielding the false
explanation that zero metres was not physical. The actual pre-change reply is
in `var/c-physical-integration/issued-numeral-consumer.json`.

The reader now identifies exact numeric spans before recognizing roles. Its
decimal/fraction syntax, sign conventions, grouping rules, resource limits,
and whole-malformed-run behavior follow the shared ExactNumeric adapter.
Python spans use character offsets; SML spans use byte offsets. Fusion retains
the complete `2 x 10^3` notation as an explicit extension. Slash-unit rates do
not become empty numeric denominators. A zero numeric denominator stays
malformed, and its suffix is never reconsidered as an amount. Role regexes
consume only issued markers and resolve values through the marker table.

Malformed and unread numerals now stop before the planner. Previously the
model's validity result was rendered before unread numbers were checked, so
a partial question could produce a misleading domain refusal.
The typed wire reader also requires whole integer components and a positive
canonical denominator; SML's prefix-accepting integer conversion cannot turn
`1oops/2` into a rational. Kernel errors stay explicit errors at the consumer.
The renderer also stopped rounding to a fixed decimal place before significant-
digit formatting: a 1e-6 W lamp over two hours now says 2e-9 kWh, matching its
exact kernel value. Results that overflow or underflow the numeric output field
are withheld; their exact kernel result remains in provenance.
The final combined check exposed a unit-reading error too: `60 km/hour` was
read as `60 km`. Supported speed aliases now bind the complete rate; unsupported
slash/per rates cannot be shortened to their numerator unit, including in the
requested output unit. These unit interpretations remain untrusted Python.

## Model laws and build status

The changed HOL model admits zero magnitudes and uses the closed interval
[0, 1] for duty. Planetary mass and radius ratios stay strictly positive.
Negative scalar magnitudes remain outside the planner's model; rendering no
longer calls them physically impossible. Temperature and money retain their
existing interpretations. This does not establish that every physical quantity
must be nonnegative or that the untrusted reader attached the correct role.

Seven added laws are in the export's oracle scan:

- `zero_magnitude_admitted`: amount zero is admitted at every dimension unless
  its role is planetary mass or radius.
- `zero_body_rejected`: zero planetary mass/radius receives the body-domain
  refusal.
- `duty_outside_closed_interval`: duty refusal occurs exactly for duty below
  zero or above one.
- `nonnegative_duty_admitted`: every duty from zero through one is admitted.
- `zero_power_product`: core arithmetic multiplies zero power by any duration
  to produce zero energy.
- `zero_time_denominator`: a distance divided by zero time is refused by core
  arithmetic.
- `nonpositive_goal_factor_no_finish`: a zero or negative target-unit factor
  cannot finish a plan. HOL's total division at zero cannot create an answer
  from an invalid unit conversion factor.

**Proof and native build passed:** selected-source attempt
`20261018T075609Z-b1077ecf93a1` on persvati reports
`VERI7VN_FUSION PASS theorems=39 oracles=0`. Initial
attempt `20261018T073445Z-a4c91d64184e` checked the seven new laws, then failed
because the existing single-conversion law lacked the newly required positive
unit-factor premise. That law now explicitly assumes `0 < fct`. Retry
`20261018T074737Z-86c0336f6c9b` passed Fusion itself but captured an unfinished
Climate definition that failed to typecheck. The third attempt uses the first
attempt's retained complete dependencies plus final Fusion source, copied into
`var/fusion/proof-source-final`; `selection.json` records source digests and every
overlay change. It claims those selected dependency versions, not the live
dependency checkout. The shared immutable native compiler consumed that exact
export using explicit retained-proof mode. Its manifest records nine theory/
export files that differ from the current Climate, Energy, Quantity and Space
trees; none of those subsequent changes is claimed by this Fusion build.

Published binary SHA-256:
`872d16219dbe988abc684bd283100b046d27e2e89a0f756369d2c782103f3940`
(404,216 bytes). Generated export SHA-256:
`cabd7ca977fbbe2de19703e367d82876caece1ef448c8f1c02c7ebfbc6dcd7f1`.
Native binding: `var/fusion/native-attempts/20261018T080302Z-2013be571a37/compile-inputs.json`.
The build script preserves old exports and accepts an explicit proof receipt;
retained dependencies additionally require `PROOF_SNAPSHOT=1`.

## Observed checks

- Twelve focused parser/rendering tests pass, including the shared ExactNumeric literals,
  final fraction whitespace forms, malformed whole runs, marker collision,
  structural digits, slash-unit rates, bounded resources, complete rate units,
  role bindings and rendering range.
- **40 actual checks pass** against the published binary: nine reader/rendering
  cases, eleven typed model cases, five malformed wire rationals, four English
  zero-energy/cost questions, four specialist/network cases and seven combined
  route cases. Malformed `1/0`, exponents, grouping, repeated signs and unread
  quantities never become partial planner givens. Zero products and duty answer
  zero; zero divisors and nonpositive conversion factors produce no answer.
  Receipt: `var/fusion/d-validity.json`, with before/after binary and consumer
  source hashes.
- The seven combined cases run actual specialist dispatch, Fusion, Wordprob and
  precision guards. Zero cylinder volume reaches Wordprob; zero rectangle area,
  zero-duration distance and zero-distance travel time answer through Fusion.
  Zero-duration speed is refused by Wordprob; positive-distance travel time at
  zero speed falls through to refusal. That last case has no detailed reason
  text yet. The tiny nonzero energy answer remains 2e-9 kWh through the guards.
- Three actual process-lifecycle tests pass; numeric integration does not leave
  a kernel alive on EOF, exception or SIGTERM.
- **114 recorded network questions executed:** 101 answers retain identical
  text and plans, one still needs an unconnected geometry operation, and twelve
  domain refusals use the corrected model-specific wording. No wrong answer or
  false answer was observed. Receipt: `var/fusion/d-network114.json`.

There are **no new specialist shipped-panel scores** in this packet; the 114
items are a scoped recorded network comparison. No full head was run. Reproduce
the finite model and consumer checks with:

```sh
python3 -B tools/fusion/test_numeric.py
python3 -B tools/fusion/test_validity.py --binary var/fusion/bin/fusion
```

Changed files: `tools/fusion/{answerer,numeric,test_numeric,test_validity}.py`,
`src/extract/fusion/{Fusion.thy,Fusion_Export.thy,main.sml,build.sh,README.md}`,
and this report. Root owns integration; all ten files are ready for review.

Any future Fusion package must include `numeric.py` beside `answerer.py`.
The current specialist archive deliberately excludes Fusion, so it has no
asset-copy path to amend. Recognition, source tables, physical-model selection
and rendering remain untrusted premises.
