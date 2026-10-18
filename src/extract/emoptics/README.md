# Electrical circuits and optics

One Isabelle/HOL kernel serves nine specialist IDs: electrical, electronics,
electronics-r2, wiring, optics, optics-v2, optics-v3, optics-v5 and optics-v5-r2.
It supplies exact rational electrical and lens calculations, and checked
numerical enclosures for wire geometry and refraction. Each optical wrapper
uses the same corrected interpretation of incident and transmitted media.

The kernel supports inverse lens calculations and explicit unit
handling. Image, object and focal distances are returned in centimetres. The
input must state each length's unit. Magnification is dimensionless; lens power
uses diopters. The reciprocal lens equation applies to ideal thin lenses with
signed distances. An object at a nonzero focal distance has no finite image;
an image at a nonzero focal distance corresponds to an object at infinity.
Zero distances and a zero reciprocal sum for focal length are declined.

English recognition and JSON framing remain untrusted. Once a typed request
has been selected, HOL supplies its arithmetic, decline decision and response.
For an approximate result, the stated decimal lies within one part in a
thousand plus 1e-9 of the real-number model. Total internal reflection is only
asserted when the enclosure establishes it; an unresolved critical boundary is
declined. This is a guarantee about the selected model and input, not a proof
that the English question was read correctly or that a real apparatus is ideal.

Circuit operations own their inputs. Series and parallel networks require a
nonempty list of positive resistors and can return equivalent resistance,
source current or total power. A signed supply produces signed current;
zero supply produces zero current and power. RC requires positive resistance
and capacitance. Redundant scalar V/I/R/power inputs must describe the same
ideal circuit.

The LED sizing model uses explicitly selected supply voltage, forward voltage
and forward current; it requires positive forward voltage/current and supply
above that voltage. Divider output uses the selected top and bottom resistors
and prints their values. Explicit connection roles take precedence; otherwise
R1/R2 use the conventional top/bottom interpretation, and unlabeled lists use
the listed top-then-bottom order. Circuit numbers are bound to shared exact
numeric tokens, preserving fractions, signs, scientific notation and SI case.

The optical wave model keeps the source and target media distinct. It computes
frequency, target-medium wavelength and photon energy from exact unit-bearing
measurements. Supplied wavelength/frequency/index triples must satisfy
n*f*wavelength=c; a supplied source index remains checked even for frequency-only
photon energy. Named media use fixed nominal indices, not dispersion curves.
Without a medium qualifier, the reader selects the conventional vacuum model.

Photon frequency and wavelength must be positive. Refractive-index calculations
use the explicitly supported n >= 1 domain. Surface-relative angles are converted
to normal-relative degrees in HOL; accepted incidence is 0 <= theta < 90 degrees.
Radian angles, grazing incidence and multi-interface paths currently withhold.
Their mathematical availability is distinct from the current solver's coverage.
Questions about wiring safety or code compliance are declined.

The resistor reader expands explicitly counted identical components, up to 128
resistor operands. Stated totals must agree with the component groups. Unknown
counts, larger lists and grouped topologies withhold; 128 is a reader resource
limit rather than a physical law.

`Emoptics.thy` states the equations and their properties. `Emoptics_Num.thy`
provides checked enclosures. `Emoptics_Export.thy` exports Standard ML and scans
all named emoptics-family facts for oracles before its build-time self test.
The unused full-exhaustive and narrowing Quickcheck generators are disabled
because their auxiliary equations depend on an oracle. Code extraction and
the complete family scan remain enabled.
The self test is not exported as an eagerly evaluated runtime value.
`tables_check.py` independently compares the fixed tables with the shipped
organs. It is a transcription check, not a theorem.

Build with the designated remote driver, then compile the exact successful
export with bundled MLton:

```sh
tools/dev/remote-build persvati src/extract/emoptics Veri7vn_Emoptics \
  -d src/extract/commons --expect 'VERI7VN_EMOPTICS PASS'
GENERATED_SML=/absolute/path/to/successful/export/emoptics.ML sh src/extract/emoptics/build.sh
python3 -B src/extract/emoptics/tables_check.py
python3 -B tools/parity/harness.py \
  --answerer 'var/emoptics/bin/emoptics --specialist {id}' \
  --specialist electrical,electronics,electronics-r2,wiring,optics,optics-v2,optics-v3,optics-v5,optics-v5-r2 \
  --split both --out var/c-physical-emoptics/parity
python3 -B src/extract/emoptics/check_probes.py var/emoptics/bin/emoptics
```

The build script freezes the actual compiler inputs through `native-compile`,
requires a matching successful managed proof receipt, and publishes the binary
atomically. Its consumed-input record is `var/emoptics/build/compile-inputs.json`.

The answerer takes JSON lines containing `id` and `q`; optional
`--specialist ID` pins one specialist. Without it, the family routes the question
in a fixed order. `capabilities.json` declares the inverse-lens additions to
the shared dispatcher/package contract. Static theorem names in response
metadata are references, not per-question proof certificates.

See [the current lane report](../../../project/lanes/C-physical-emoptics.md) for
build status, measured results and limits. The earlier S04 report is a useful
baseline: optics and optics-v2 had 13 confident wrong held-out answers. The
current report records the passed proof, bound native compiler inputs, all-right
shipped panels and untouched fresh evaluation, plus the incomplete standalone
six-criterion admission check. The [next model-contract report](../../../project/lanes/C-physical-emoptics-next.md)
records semantic counterexamples beyond those panels.

`beyond_score.py` measures shipped panels and fresh seeded versions of the
shipped generators. Wiring has no shipped generator. `probes.json` records
source-derived expected values and boundary cases; their author also wrote the
parser, so they are not independent blind language tests. The generators keep
the original author's templates and blind spots. These checks support the
reported domain numbers; they do not establish every head-composition criterion.

The accepted D circuit packet is described in the next model-contract report.
`check_circuits.py` separates safe-refusal assertions from capability counts;
`circuit_fresh.py` generates exact equation/role cases with a supplied seed.
The D report records its passed proof, bound native inputs, full shipped
panels, reserved evaluations and independent consumer checks. Four computable
probe extensions still withhold and are counted separately from safe assertions.


The [E optical report](../../../project/lanes/E-physical-emoptics.md) records the
current medium/angle and counted-resistor packet. `check_optical_model.py` and
`optical_fresh.py` exercise its physical values and source roles; safe-refusal
assertions remain separate from capability counts. `circuit_count_probes.json`
exercises complete component multiplicity through the existing list model.
