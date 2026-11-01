# Optical medium, angle and counted-resistor packet

Ready for integration, Codex, 18 October 2026. The managed proof and bound native
compile passed. All 1,253 shipped questions remain right in specialist and family
modes, with zero wrong answers, false yes answers or valid withholdings. Reserved
optical seed 157901 is 96/96 in all five optical wrappers and family mode;
reserved shipped-generator offset 157903 is 1,150/1,150. Recognition and native
inputs are frozen. Parent/runtime composition is recorded below as it completes.
No successor work is running; drain ends after integration/capture.

The preceding D circuit packet was integrated in `3d44920` and captured before
this packet reopened its source files. Its binary remains the comparison baseline.

## What works

A wavelength belongs to its source medium. The new optical request carries
source and target indices separately and returns frequency, target wavelength
or photon energy. Frequency-only inputs retain an explicitly supplied source
index as a domain-bearing input. Redundant wavelength/frequency/index inputs
must be exactly consistent. Unit conversions and surface-to-normal angle
conversion occur in HOL. The reader binds original exact measurements and unit
spans through shared ExactNumeric and MeasuredInput.

The model assumes a monochromatic wave in a stationary transparent medium,
with a phase index supplied at that frequency and currently at least one.
Named media use fixed nominal indices, not dispersion curves. In the absence of
a medium qualifier, recognition selects the conventional vacuum model. An
explicit unknown medium needs an index for wavelength conversion; frequency-only
photon energy needs no unspecified index.

Surface-relative incident degrees become `90 - angle` in HOL. The answer states
its refracted angle relative to the normal. Existing direction handling is
preserved, including reversed source/target wording. Repeated boundary
statements must agree with their incident/transmitted roles; actual intermediate
interfaces are retained and currently withhold rather than being dropped.

The circuit reader expands complete identical-component counts into the existing
checked resistor-list model. It supports series/parallel equivalent resistance,
source current and total power. Numeral counts bind issued exact tokens; spelled
cardinals remain untrusted grammar. A declared total must equal the expanded
component count. The reader accepts at most 128 operands. That is a resource
limit, not physical impossibility. Unparsed counts and grouped topologies withhold.

## Actual proved statements and consumer connection

`Emoptics_Optical_Model.thy` imports only `Emoptics_Num`, keeping imports acyclic.
An accepted wave has positive speed, frequency, wavelength and photon energy,
and target index at least one. Its returned values satisfy:

- `n_target * speed = c`, `frequency * wavelength = speed`, and `energy = h * frequency`.
- Consequently `n_target * frequency * wavelength = c` and `energy * n_target * wavelength = h * c`.
- A supplied frequency is preserved. A supplied wavelength has a positive value
  and source index at least one, and satisfies `n_source * frequency * wavelength_source = c`.
- Redundant inputs satisfy that exact equation; an inconsistent triple declines.
- With the same input at two target indices, frequency and energy agree and
  `n1 * wavelength1 = n2 * wavelength2`.

The actual `kernel (O_Wave ...) = Exact ...` theorem connects the returned scalar
to this accepted wave. Wavelength replies satisfy the target-index equation;
photon-energy replies in eV satisfy `returned_eV * echarge = planck * frequency`.
These are conditional statements about the body-owned typed request, not claims
that the English reader selected it correctly.

For surface incidence the checked conversion proves
`sin(normal_angle) = cos(surface_angle)`. The actual approximate Snell consumer
then obeys `n_source * cos(surface_angle) = n_target * sin(refracted_normal_angle)`
for its real model; the existing enclosure and printed-error guarantees remain.
The angle domain is normal degrees in [0,90), equivalently surface degrees in
(0,90]. Count expansion reuses the existing nonempty positive-resistor network
claims, including reciprocal parallel resistance and current/power conservation.
No circuit theorem or physical representation was weakened for the reader repair.

## Bound proof and executable

Final proof: `var/emoptics/remote-attempts/20261018T102606Z-79dbda223c7d/receipt.json`.
Actual session Finished in 2m11s; driver build phase 2m20s. The durable marker is
`VERI7VN_EMOPTICS PASS theorems=78 scanned=19840 oracles=0`.
The 78 selected physical/consumer roots are distinct from the 19,840 authored
and generated family facts scanned. The complete scan remains enabled; unused
oracle-bearing Quickcheck generators remain disabled, as in the preceding packet.

Export SHA256: `75f962668eaf0a2c964ada5c98c45efd115ca63bb283559b68b9ab0f2a3eebd4`.
Native manifest: `var/emoptics/native-attempts/20261018T103622Z-10104f8230b7/compile-inputs.json`.
Usable binary: `var/emoptics/bin/emoptics`; immutable copy is beside that manifest.
Binary SHA256: `f11b87eebca5e9135065082689c794e1c01f088a161e248e0c769b5aeae0e85e`.
The manifest records the actual compiler graph, confirms current proof closure
matches the passed snapshot, and consumes numeric
`2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`
and MeasuredInput
`11f703525511191a6e075930191903841d65d158544075845c0142bfc32e2cb7`.

Size is 1,019,352 bytes. Five process-start-to-first-answer measurements were
97.97, 5.60, 5.90, 5.54 and 5.34 ms (median 5.60 ms); the first launch was slower.
The following shipped counts apply separately to specialist and family modes.
Every row has zero wrong, false yes and valid withheld.

| Specialist | Right / total | Specialist p50 ms | Family p50 ms |
|---|---:|---:|---:|
| electrical | 48 / 48 | 2.35 | 2.34 |
| electronics | 222 / 222 | 0.26 | 0.65 |
| electronics-r2 | 222 / 222 | 0.25 | 0.65 |
| wiring | 87 / 87 | 3.87 | 4.08 |
| optics | 131 / 131 | 0.21 | 0.34 |
| optics-v2 | 134 / 134 | 0.23 | 0.39 |
| optics-v3 | 131 / 131 | 0.24 | 0.40 |
| optics-v5 | 139 / 139 | 0.24 | 0.34 |
| optics-v5-r2 | 139 / 139 | 0.27 | 0.38 |

## Exact before/after evaluation

Baseline is accepted D binary
`d6ace3cf7cfc9489cd62cc46c19ac02e1595ca33c80bc5b03746e99efebf96f1`.
Counts below are per route; repeating questions through wrappers does not make
them independent examples. Right includes correct refusals of genuinely invalid
or underdetermined requests. Safe-refusal assertions are separate: a computable
request outside the reader/model counts as valid withheld.

| Set | D right / wrong / false yes / valid withheld | E right / wrong / false yes / valid withheld |
|---|---:|---:|
| 41 authored optical probes, each optical wrapper and family | 11 / 18 / 8 / 4 | 35 / 0 / 0 / 6 |
| 19 authored count probes, both circuit wrappers and family | 1 / 11 / 6 / 1 | 16 / 0 / 0 / 3 |
| 96 seen development optical questions, seed 149171 | 3 / 69 / 0 / 24 | 96 / 0 / 0 / 0 |
| 96 untouched optical questions, seed 157901 | 2 / 70 / 0 / 24 | 96 / 0 / 0 / 0 |

All 41 optical and 19 count safety/model assertions pass on the final native.
The original 36 D circuit assertions remain 36/36 (32 right plus 4 valid withheld
per route). Table transcription checks pass 28/28. The old 38 source probes are
37 right, zero wrong/false yes and one valid-withheld regression, detailed below.
The previous 41-point AWG challenge is retained as D evidence, not rerun or
represented as a new E measurement.

The optical probes derive values from OpenStax's
[refraction equations](https://openstax.org/books/university-physics-volume-3/pages/1-3-refraction)
and [photon-energy relation](https://openstax.org/books/university-physics-volume-3/pages/6-2-photoelectric-effect).
Count probes use its [series/parallel circuit equations](https://openstax.org/books/university-physics-volume-2/pages/10-2-resistors-in-series-and-parallel).
Their author also wrote recognition: these are independent physical equations,
not blind language validation. `optical_fresh.py` uses exact Fraction equations;
reserved seed 157901 was first generated after native development checks passed.
The shipped-template offset 157903 likewise remained unused until parser freeze.
No parser change followed either reserved evaluation. Shipped generators retain
their original template limitations; wiring has no shipped fresh generator.

Receipts under `var/c-physical-emoptics/`:
`optical-e-shipped.json`, `optical-e-probes-final.json`,
`optical-e-final-baseline.json`, `circuit-count-e-before.json`,
`circuit-count-e-final.json`, `circuit-e-preserved.json`,
`optical-e-development-final.json`, `optical-e-untouched-{before,final}.json`,
`optical-e-beyond-final/results.json`, and `optical-e-preserved-probes.json`.
The exact named-file and receipt map is `e-final-ready.json` in that directory.

## Remaining capability and consumer boundaries

Six authored optical cases are computable but withheld: index below one,
grazing incidence, radian incidence, two parallel-interface paths (including an
intermediate TIR barrier), and requested surface-relative output. Three count
cases are computable but outside this reader: 129 components and the two
“repeated 3/three times” wordings. Unknown source media, conflicting indices,
contradictory measurements/counts and unspecified interface orientations are
separate underdetermined or invalid cases.

Parent's independent check passes 10/14 safe/model assertions across 14 route
attempts. Capability is 6 right and 8 valid withheld, zero wrong/false yes, in
`var/c-physical-integration/emoptics-E-independent.json`. Four valid withholdings
are the requested surface-output and billion-resistor cases (each twice); the
remaining four come from these two new grammar limits, each repeated through two routes:

- “Light has wavelength 720 nm in a medium with refractive index 1.2. What is its
  wavelength in a medium of index 1.8?” Explicit source/target label syntax works;
  this implicit two-medium wording remains unrecognized.
- “Light travels from air of index 1 into glass of index 1.5 at an angle of
  60 degrees to the surface. What is the refracted angle?” Combining a known
  medium name with its explicit index is not yet unified as one source role.

The preserved-probe regression is “Inside index 1.5, light at 52 degrees goes
from index 1.5 to index 1.0. What is the angle of refraction?” Its three index
mentions safely withhold; the repeated-boundary reader supports the checked
four-mention descriptions but not this shorter restatement. This is a disclosed
loss of capability, not an incorrect confident answer. Drain preserves these
frontiers rather than retuning after the reserved evaluation.

The full nine-ID frontier remains in `C-physical-emoptics-next.md`: electrical
line/phase power and transformer inverse roles; wiring power-factor and loop
length roles; additional circuit inverse operations; and the optical extensions
above. Panel parity does not close those semantics.

## Build history and resume boundary

The standalone model revision passed earlier as
`20261018T085853Z-cbcfd59a65fb` (8 selected roots, 415 scanned facts, zero oracles).
It is historical evidence, not the final consumer proof. The first full build
`20261018T100453Z-2248eb11685b` failed on two local proof simplifications; the
pre-input classification lemma and unfolded let expression repaired them.
`20261018T101701Z-0f8256c594c2` then actually Finished and exported code, but its
console PASS was absent from retained logs. The accepted final attempt exports
the same assertion marker durably after the unchanged complete scan/self-test.
No failed receipt supplied the published native.

No new public answer kind is introduced. Runtime must consume this exact native
manifest and its static capability sidecar. Root owns integration and commits;
this lane changes no shared numeric/measurement source, registry or tools.
