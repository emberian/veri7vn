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

Series, parallel and RC calculations require positive resistance; RC also
requires positive capacitance.
Photon frequency and wavelength must be positive. Refractive-index calculations
use the explicitly supported n >= 1 domain and incidence 0 <= theta < 90 degrees.
Questions about wiring safety or code compliance are declined.

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
