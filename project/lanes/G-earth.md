# G-earth: exact seismology quantities

Status: isolated candidate over checked Earth F. Live Earth D and all ready
predecessor packets are unchanged. Scoped proof, native, official panels and
actual staged dispatcher checks now pass.

Actual F-native counterexamples show that comparing magnitudes -1 and +1 gives
an energy ratio of 1, instead of 1000. Fractions and multi-digit magnitudes also
misread or withhold. Nonpositive seismic moments are silently dropped before
reaching the existing physical guard. The raw 41-probe baseline is retained in
`var/earth/g-seismo-exact/f-baseline.json`; F passes 15/41 policy assertions.

The candidate removes the legacy unsigned seismology number parser. All branches
use the shared exact numeric lexer and issued-marker lookup. Compact M6/M4 labels
are separated before lexing, while M0= remains the moment label. Scientific
mantissa-times-ten notation binds three issued tokens, requires base ten and an
integer exponent, and uses the shared numeric parser and its resource limits to
construct the scale. No second literal grammar is introduced.

Magnitude is signed and dimensionless; a negative magnitude is valid. Seismic
moment must be positive and is supplied in N m. The existing 100-bit moment
magnitude computation and four-significant-figure rendering remain unchanged.
The scalar moment unit cannot be a rate or product dimension. More than two
magnitude operands, multiple moment sources and unsupported units are withheld.
A question mixing energy and amplitude asks which quantity is intended.

Three new scanned facts connect actual outputs: both energy and amplitude kernel
outputs are invariant under adding the same magnitude offset to both operands;
and a moment-magnitude Value exists exactly when the supplied moment is positive.
The ratio remains the declared larger-to-smaller comparison, using the absolute
magnitude difference. No directional quotient extension is claimed here.

The 41 authored cases contain 28 modeled answers, 5 impossible moments,
5 valid unsupported requests, 1 valid ambiguous target and 2 malformed inputs.
The valid answer slice is 28/34, not 41 answered cases. Numeric expectations are
rounded to the existing four-significant-figure policy before comparison; raw
scientific expectations are retained in each row.

Passed managed attempt: persvati `20261018T095120Z-8176dd8f21b7`. Its exact passed F base,
owned overlay and live frozen hashes are in `var/earth/g-seismo-exact/staging.json`.


## Checked candidate

Managed proof passed first attempt with
`VERI7VN_EARTH PASS theorems=134 oracles=0`. The exported computation is unchanged
from F; its SHA256 remains
`aa6ba5e85d3853460b6b5c3c09320233006426a4318e05922f2b77bc7fe52a34`.
This packet adds proof statements and repairs the reader, not the ratio formula.

Initial native eb2cf60b passed 35/41 new policies. Six scientific-notation requests
exposed the shared lexer's deliberate exclusion of digits immediately following a
caret (normally a structural unit exponent). The local source-notation adapter
now separates caret punctuation before shared lexing, and scalar moment unit
boundaries reject caret dimensions. No literal grammar, shared file or proof
changed. Initial receipts and panels remain under `initial-*` names.

Final native SHA256:
`8d97d208abe8948433778d97c2e7220735415b3857430b2e8ccca668154fc90a`,
930424 bytes. Actual compiler manifest:
`var/earth/g-seismo-exact/stage/var/earth/native-attempts/20261018T095450Z-ce4aa2760a2f/compile-inputs.json`.
It binds the passed export, final reader/main, regex and exact numeric input
2f313c77. The shared compiler lock is recorded; live metadata is preserved.

| Official scorer panel | Right | Wrong / false yes | Valid withheld |
|---|---:|---:|---:|
| All Earth shipped | 554 / 554 | 0 / 0 | 0 |
| Fresh offset 38701 | 340 / 340 | 0 / 0 | 0 |
| Reserved offset 43701 | 352 / 352 | 0 / 0 | 0 |
| Seismology shipped | 68 / 68 | 0 / 0 | 0 |
| Seismology fresh | 68 / 68 | 0 / 0 | 0 |
| Seismology reserved | 68 / 68 | 0 / 0 | 0 |

Hydrology and meteorology still lack fresh generators. Separate official
seismology parity also scores 68/68; admission remains INCOMPLETE because
head/core/self and the full six criteria were not measured.

Final G policies pass 41/41, versus F's 15/41. The valid model capability slice is
28/34; the five valid unsupported requests and one mixed target remain withheld.
All 29 E policies, all 15 F exponent-boundary answers and the original 50 Earth
policies pass. Shipped seismology p50 is 9.114 ms, cold median 4.312 ms; fractional
interval work still prevents a claim of full-specialist latency below 5 ms.
Evidence is under `var/earth/g-seismo-exact/panels/report.json`, `g-probes.json`,
`e-regression.json`, `f-regression.json`, and `parity/`.

Actual Dispatcher checks pass 10/10 in
`var/C-runtime-consumers/staged-G-earth.json`, including signed/fractional/large
magnitudes, compact M0/M-2, negative-magnitude moment 39810000, scientific moment
magnitude 4.134, terminal zero-moment impossibility and mixed-target clarification.
The independent consumer uses the existing four-significant-figure expected
renderings and retains unrounded scientific expectations in its receipt.
This explicitly staged configuration changes no live family or selected delivery.
Exact promotion sources, proof and native are listed in
`var/earth/g-seismo-exact/ready.json`; root release and package capture remain.
