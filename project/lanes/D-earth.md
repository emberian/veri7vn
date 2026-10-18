# D-earth: Ocean physical inputs and group velocity

Status: checked kernel, selected native, official panels and exact composed
consumer checks pass. Actual compiler inputs are immutably captured at
`var/C-runtime-package/bound-prepared/20261018T081639Z-a5c43993f5ec/earth`.
Source and native remain frozen pending root integration. The earlier C artifact remains independently
captured and committed in `5327e3c`; this is a separate next-cohort candidate.

The old reader silently changed sonar -2 seconds into +2 and answered depth 1500m.
It also returned phase speed when asked for group velocity. Ocean now preserves
full signed quantities through the shared exact lexer, rejects physically
infeasible scalar inputs, and computes a distinct group-speed request.

## Specialist model ledger

These rows record actual boundary probes, not complete domain coverage. Initial
raw replies are in `var/earth/d-domain/ledger-probes.json`.

| Specialist | Model boundary exercised | Actual result | Next concrete work |
|---|---|---|---|
| geography | Latitudes must lie in [-90,90]. | 95°N now produces impossible; composed dispatcher retains it. | Study longitude normalization and coincident/antipodal conditioning without reducing interval precision. |
| geology | A remaining fraction cannot be negative. | -25% is silently read as +25%, answered age 11460 y. | Shared exact numeric lexer; bind accepted fraction to full signed source token and retain existing kernel range guard. |
| seismology | Supplied coefficients retain their sign. | b=-1 is treated as absent, yielding underspecified. | Preserve typed signed Gutenberg–Richter coefficients; distinguish mathematically defined model from plausible calibrated parameters. |
| hydrology | Runoff fraction C is in [0,1] under the simple precipitation-partition model. | C=1.5 becomes 1 and answers 0.5556 m3/s. | Consume complete number; add kernel coefficient feasibility and conservation bound Q<=i*A (with units). |
| ocean | Physical scalar inputs retain signs; group and phase velocity differ. | D now rejects -2 seconds and nonpositive sound speed; ten-second group velocity is 7.807 m/s, phase is 15.61 m/s. | Checked feasibility and dispersion-derivative laws; capillary group waves remain unsupported. |
| meteorology | RH must be positive and <=100 for dew-point inversion. | -50% produces impossible. | Check empirical model applicability separately from algebraic poles; high/low RH proof does not establish calibration range. |
| greenhouse | A daily light integration duration lies within a day. | 30h/day gives DLI54 without qualification. | Bound daily duration to [0,24], positive duration for PPFD inversion; preserve zero-light case and bind DLI/PPFD inversion. |
| greenhouse-r2 | Same daily duration semantics as greenhouse. | Same DLI54 response. | Shared kernel repair, both specialist consumers. |


A further seismology case reads magnitude 10 as 1, returning 100000/year instead
of 0.0001/year for a=6,b=1; `var/earth/d-domain/magnitude-gap.json`. That full-token
repair remains outstanding. No other Earth reader is silently claimed fixed by
Ocean's shared-lexer adoption.

## Changes and checked laws

Changed `Earth_Ocean.thy`, `Earth_Export.thy`, `recognizer.sml`, `build.sh`,
`capabilities.json`, `beyond-probes.json`, and `README.md`. The build script uses
the common immutable-input helper and now consumes `commons/numeric.sml`.

The typed feasible domain is explicit:

- Sonar time >=0 and sound speed >0.
- Pressure depth >=0 and density >0.
- Shallow-water speed depth >=0; travel depth >0 and distance >=0.
- Deep-water phase speed, group speed and wavelength period >0.

Successful kernel values imply those constraints; impossible refusal occurs
exactly outside them. A successful sonar value is nonnegative and twice it equals
speed times elapsed echo time. For two successful pressure requests with the same
density and absolute/gauge choice, pressure difference times 1000 equals rho*g
 times the depth difference. Successful shallow-wave travel obeys time*3600*
sqrt(g*depth)=distance_km*1000 and carries positive-depth/nonnegative-distance
premises from the actual kernel.

The new `ODeepGroupSpeed` computes g*T/(4*pi), emits `deep_group_speed`, and is
selected before generic speed wording. For positive wave number k,
omega(k)=sqrt(g*k) has derivative g/(2*omega(k)). A successful group-speed output
is that derivative whenever the physical period relation omega(k)*T=2*pi holds.
A second kernel-bound law says twice a successful group speed equals the
successful phase speed for the same period. All eight new laws enter the oracle
scan. This is a gravity-wave deep-water model with g=9.81m/s2; it does not model
capillary/surface-tension waves, which the reader leaves unsupported.

The untrusted reader handles exact decimals, fractions, scientific notation,
Unicode signs and hyphenated period adjectives. Every masked number must resolve
through the shared lexer's actual table. Malformed and forged numeric markers
cannot become a trusted quantity. Unit/role recognition and physical model
selection remain untrusted.

## Exact checked candidate

Passed proof: `var/earth/remote-attempts/20261018T080936Z-0c7db09e8ddf/receipt.json`,
persvati exit 0, marker found, source stable and fresh exports published.
Assertion export: `VERI7VN_EARTH PASS theorems=124 oracles=0`. Earlier failed
attempts were repaired using explicit conditional splits, sign arithmetic,
function extensionality and field cancellation; no failed export was consumed
and no heavier theory imports were added.

- Generated SML SHA256: `a6b6822aca71433f6a883243732187a789338d1aa77d8991137d0061220b8f57`.
- Native `var/earth/bin/earth`: `8f064d55a3953b4af0e80e80bcb21633c40ff1369a78ad919b9b0b9039904ce2`, 931320 bytes.
- Immutable compiler-input manifest: `var/earth/native-attempts/20261018T081639Z-a5c43993f5ec/compile-inputs.json`.
- Consumed shared numeric SHA256: `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.

The helper captured actual generated SML, family regex, numeric lexer,
recognizer/main and rewritten MLB, checked export provenance and rechecked inputs
after compilation.

## Measured results and capability limits

| Official-scored panel | Right / total | Wrong | False yes | Valid withheld |
|---|---:|---:|---:|---:|
| All eight shipped specialists | 554/554 |0|0|0|
| Fresh offset 8701 |350/350|0|0|0|
| Reserved offset 13701 |348/348|0|0|0|
| Actual Ocean family harness |46/46|0|0|0|

Offsets were generated after the selected compile. Hydrology and meteorology
have no shipped generator source, so their shipped panels are covered with no
fresh-panel claim. The family harness remains INCOMPLETE because head/core/self
admission checks were not run; this is not full six-criterion completion.

Authored policy assertions pass 50/50. Those are not fifty answered capabilities:
21 answerable model cases are answered correctly; two valid queries remain
withheld (ISA beyond its modeled layer and capillary group waves). Thus the
answerable/unsupported capability slice is 21/23 with two withheld-valid cases.
The remaining policy cases comprise 22 impossible inputs, 2 malformed inputs and 3
missing-required-input requests. Classification is explicit in
`var/earth/d-domain/probe-classification.json`; official scorer labels are unchanged.

Shipped p50 milliseconds: geography 0.105, geology 15.789, seismology 18.628,
hydrology 0.121, ocean 1.920, meteorology 0.190, greenhouse 10.897,
greenhouse-r2 11.171. Cold median 3.87ms. Four unchanged specialist medians remain
above 5ms; their interval precision has not been lowered.

Five actual CLI-composed checks pass on the exact selected hash in
`var/C-runtime-consumers/earth-D-final.json`: negative sonar time/speed are
terminal impossible, group 10s is 7.807 under the new accepted kind, phase 10s is
15.61 (sentence 15.613), and zero-depth travel is terminal impossible. These are
next-cohort checks, not automatic replacement of the captured C delivery.

Panel receipts: `var/earth/d-final/report.json`, `var/earth/d-parity/`,
`var/earth/d-domain/native.log`, and `var/earth/d-domain/final.log`.
