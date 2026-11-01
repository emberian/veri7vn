# G-climate: signed material geometry and typed units

Status: scoped proof, immutable diagnostic native, official carbon-material
panels and authored boundary probes pass in an isolated checkout. Live Climate F
and Earth D remain frozen for root integration. G has not been promoted into the
live family or selected delivery; the actual dispatcher also passes the seven staged consumer checks. This
report does not replace the earlier packets' evidence.

Actual F-native counterexamples show that the material reader interprets .5m² as
5m², 1/2m² as 2m², and .335nm as 335nm. Negative area and thickness lose their signs.
A width can become a thickness, an area rate can become an area, and an explicit
bilayer can receive the monolayer mass result. Raw baseline replies and the exact
native hash are in `var/climate/g-material/f-baseline-final.json`.

The candidate uses the shared exact numeric lexer and finite kernel-owned unit
types: nm/angstrom/µm for thickness, and m²/cm²/mm²/µm² for area. The reader assigns
a unit tag; arithmetic conversion occurs in HOL. Negative physical geometry is
impossible. Zero remains the degenerate zero-area or zero-thickness model.

Layer questions bind one explicit thickness value, not a width. Mass questions
bind one area and the declared single-layer model. Rate dimensions, ambiguous
multiple areas/thickness values, and explicit multilayer requests produce a typed
underspecified decline; the carbonmat sidecar will accept that existing kind.
Malformed and forged numeric markers cannot become quantities. Unicode micro
unit spellings, squared-unit spellings, exact fractions and scientific notation
are supported by the candidate. Nanotube integer-index parsing is unchanged.

Thirteen checked scan facts include:

- Impossible geometry occurs exactly for negative input area or thickness.
- An actual successful layer result has nonnegative input/output and satisfies
  layers times interlayer spacing = normalized thickness.
- Successful mass approximation carries nonnegative area and physical mass.
- Each area factor equals the square of its length factor.
- Three equivalent area-unit requests and two equivalent length-unit requests
  produce identical actual kernel outputs, including their guards.
- The physical mass model is additive in area; the three actual rendered masses
  for x, y and x+y satisfy a combined error bound from their own decimal places.
- The explicit unsupported geometry request is terminal underspecified.

The mass constant is unchanged: two carbon atoms of molar mass 12.011 g/mol per
hexagonal cell, lattice constant 0.246 nm, Avogadro constant 6.02214076e23. The new
probe oracle evaluates that atomic-cell expression independently instead of
copying the kernel's simplified areal coefficient. Layer estimates continue to
use 0.335 nm interlayer spacing; this is an ideal geometric estimate, not a model of
relaxation, edges, defects or finite-stack boundary spacing.

There are 50 authored policies: 24 answered model cases, 8 impossible geometries,
12 valid unsupported cases, one valid precision refusal and 5 malformed inputs. The answerable/unsupported
capability slice is 24/37; a policy pass must not be reported as 50 answered cases.
The prior F native passes 9/50 policy assertions. These are authored boundary
probes, not official completion numbers.

Prepared source: `Climate.thy`, `Climate_Export.thy`, `recognizer.sml`, `main.sml`
and `capabilities.json` under the scratch directory. `prepare.py` records base
hashes and modifies no live source. The isolated stage uses the passed F source snapshot and a recorded six-file
owned overlay (`staging-retry.json`). First attempt e9eaf0ddd849 failed only a
proof application that needed normalization of `of_int 3`; retry 4dba3f16ccb5
passed with the unchanged nonnegativity statement and the explicit product fact.

Promotion awaits the root integration release; composed checks have passed in
an explicit test configuration.
Scoped proof and diagnostic native testing may proceed in this isolated stage,
with the common compiler helper and its receipt checks intact.

The existing four-decimal milligram rendering is unchanged. Ordinary microscopic
areas can therefore round to zero; these new unit conversions do not establish
useful relative precision at that scale. The probes test equivalent physical
areas across units. Adaptive small-mass rendering remains a separate numerical
capability gap, rather than a claimed benefit of the unit extension.


## Checked diagnostic candidate

- Managed proof: hbox `20261018T090332Z-4dba3f16ccb5`, normal export,
  `VERI7VN_CLIMATE PASS theorems=120 oracles=0`.
- Proof receipt: `var/climate/g-material/stage/var/climate/remote-attempts/20261018T090332Z-4dba3f16ccb5/receipt.json`.
- Generated SML SHA256: `142b248bc4dcd3f1dbe97f26bae0c6c3cc586febd8703c438e06815a976b4976`.
- Diagnostic native SHA256: `1b7e4df2709285faf5b0a9a7c0d515d7d9392f7e777e7cc2e8e9d678174f6843`, 678824 bytes.
- Actual compiler manifest: `var/climate/g-material/stage/var/climate/native-attempts/20261018T090837Z-360560e6c0e7/compile-inputs.json`.

The common helper was copied unchanged into the isolated checkout and invoked
with the exact managed receipt and explicit proof snapshot. Its output and all
metadata remain under that checkout. The actual reader includes post-capture
unit-suffix guards; those are recorded in `reader-after-proof-capture.json` and
bound by the compiler manifest. They changed no proof source. Shared numeric
input is the frozen `2f313c77...` version.

| Official scorer panel | Right | Wrong / false yes | Valid withheld |
|---|---:|---:|---:|
| All-family shipped | 283 / 306 | 0 / 0 | 23 |
| All-family fresh offset 40701 | 282 / 305 | 0 / 0 | 23 |
| All-family reserved offset 45701 | 285 / 309 | 0 / 0 | 24 |
| Carbonmat shipped | 34 / 34 | 0 / 0 | 0 |
| Carbonmat fresh offset 40701 | 34 / 34 | 0 / 0 | 0 |
| Carbonmat reserved offset 45701 | 34 / 34 | 0 / 0 | 0 |

The family withholds are the approved F partial-cooling information boundary;
G changes no cooling code. The separate official carbonmat parity harness also
scores 34/34, but admission remains INCOMPLETE: head/core/self and all six
completion criteria were not measured by this scoped run.

New material policy assertions pass 49/50, versus 9/50 on the retained F native.
The answer capability slice is 24/37: all 24 modeled requests are answered and
12 valid unsupported requests and one valid precision-limited request are withheld. Eight impossible and five malformed
inputs are separate policy cases. Existing family policy assertions remain
204/204. These are not extra official panel answers.

Shipped p50 milliseconds: carboncapture 0.117, airquality 0.149, climate 2.444,
carbonmat 0.094, coldchain 0.116, coldchain-v2 0.119. Cold median 3.004 ms.

Evidence: `var/climate/g-material/panels/report.json`, `g-final-probes.json`, and
`parity/`. Next: root F integration release, exact owned-source promotion,
common-helper validation of the promoted closure, immutable runtime capture. The passed managed export is reusable only if that
exact promoted proof closure matches; no second HOL build is assumed necessary.


Independent runtime validation: `var/C-runtime-consumers/staged-G-climate.json`
records 7/7 actual Dispatcher checks with the staged sidecar injected into a test
configuration. Fractional area gives 0.3806 mg, negative area is terminal
impossible, the three thickness/unit/role cases each give one layer, and bilayer
mass plus area-times-time are terminal underspecified. The receipt binds native,
sidecar, checker and dispatcher hashes. This does not modify live F or selected
delivery; production promotion and immutable capture remain outstanding.


Final sidecar-only correction: mass of a 1e20 m² sheet is a valid model request
that the existing interval renderer cannot state tightly enough. Its actual
`imprecise` refusal is now declared terminal for carbonmat, alongside impossible
and underspecified. The previous sidecar is retained as
`capabilities-before-imprecise.json`; neither proof nor native changed. Final
native policies are 50/50. The eighth composed probe is recorded in
`runtime-probes-final.json`; the revised sidecar passes the actual Dispatcher precision case, terminal at
specs. Receipt: `var/C-runtime-consumers/staged-G-climate-precision.json`, binding
unchanged native 1b7e4df2 and sidecar d0918713. The earlier seven-case receipt is
preserved under its exact earlier sidecar; this revision only adds a decline kind.
