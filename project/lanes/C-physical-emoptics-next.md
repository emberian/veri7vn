# Electrical and optical model contracts: D circuit packet

Ready for integration, Codex 18 October 2026. The C packet was integrated at
`e3db8f0` and its final native inputs captured before D edits began. The D
circuit proof, immutable native compile, shipped panels, reserved evaluations
and independent consumer checks now pass. Source inputs are frozen for root
integration; this lane made no commits.

The accepted D binary is `var/emoptics/bin/emoptics`, SHA256
`d6ace3cf7cfc9489cd62cc46c19ac02e1595ca33c80bc5b03746e99efebf96f1`.
It keeps all 1,253 shipped panel items right in both specialist and family
modes (zero wrong, false yes or valid withheld). On the 36 authored circuit
cases, each mode has 32 right, zero wrong, zero false yes and four valid
withheld. All 36 safe/model assertions pass; that assertion count does not
turn the four computable extensions into capability successes.

The untouched custom seed 137059 reaches 128/128 in electronics,
electronics-r2 and family modes. The captured C binary on the same questions
has 35 right, 60 wrong, 4 false yes and 29 valid withheld in each mode.
Untouched shipped-generator offset 139021 has 1,173/1,173 right for both C
and D; it confirms preservation but does not measure the new role semantics.
The original 38 source probes pass, AWG 0–40 passes 41/41, and nine independent
full-dispatch circuit consumer checks pass.

These results do not constitute a fresh six-criterion admission verdict: the
standalone harness still lacks complete head/core/lane comparison inputs.
Nor do they close the remaining electrical, wiring and optical model errors.
The four original circuit counterexamples are fixed; nine wrong answers and
one computable withheld case in the original fourteen-case frontier remain
outside this packet.

## All nine specialists: examined status

| Specialist | D status and remaining frontier |
|---|---|
| electrical | Unchanged. Line versus phase voltage/current roles and complete transformer inverses remain open. |
| electronics | Fixed LED supply/forward inversion and network current/power target selection. LED-current inverse, ideal shorts and active negative-resistance models remain unsupported. |
| electronics-r2 | Same shared circuit improvements; named and physically connected divider roles override list order. Divider power/current inverses remain unsupported. |
| wiring | Unchanged. Specified power factor, its full numeric range, single-phase AC and total-loop versus one-way length remain open. |
| optics | Unchanged. Explicit-medium wavelength/frequency relations still need a coherent medium model. |
| optics-v2 | Unchanged. Surface-angle versus normal-angle interpretation remains open. |
| optics-v3 | Unchanged. Multiple interfaces require geometry and intermediate transmission checks. |
| optics-v5 | Unchanged. In-medium wavelength to frequency remains open. |
| optics-v5-r2 | Unchanged. In-medium wavelength to photon energy remains open. |

## Preserved counterexample baseline

The original twelve-case capture exercised all nine specialist IDs and found
eleven wrong answers plus one computable withheld. A two-case network-target
extension brought the baseline to thirteen wrong answers and one computable
withheld. Those are historical baseline results, not the current D circuit
results. They were deliberately adversarial questions authored after reading
the code, not an independent statistical sample.

Runtime receipts `var/c-physical-emoptics/semantic-next-runtime.json` and
`next-circuit-target-runtime.json` invoke actual dispatcher acceptance and
arbitration (`Dispatcher.organs_stage`), without fusion fallback. The captured
old binary SHA was `68a6ff498c7c2e467aeae8af7c656825e9d2615f0d34bc9e2bf0668d6e5deed7`.
Immediately before D, the parent independently captured the four circuit
failures on C's final `4be9f6d3...909a9` binary in
`var/c-physical-integration/circuit-d-before.json`. D resolves those failures.
The following table preserves the original examination, with circuit rows
explicitly marked fixed:

| Specialist | Baseline examined behavior | Captured counterexample | Correct model result |
|---|---|---|---|
| electrical | Ideal three-phase power treats every supplied voltage as line voltage. Transformer current only recognizes the forward winding direction. | Wye phase voltage 230 V, line current 10 A, PF 0.8 gives 3.187 kW. Primary 800 turns, secondary 200 turns, secondary current 12 A is withheld when primary current is requested. | 5.52 kW; primary current 3 A under ideal transformer assumptions. |
| electronics (fixed in D) | Baseline LED inputs become an unordered voltage pair; `max-min` silently exchanges supply and forward voltage. Ohm, passive resistance and RC guard coverage are in the first packet. | LED forward voltage 2 V, supply 1.8 V, current 20 mA produces a 10-ohm resistor recommendation. | Decline: the stated supply cannot sustain the requested forward drop in the assumed series circuit. |
| electronics-r2 (fixed in D) | Baseline divider inputs are positional even when the question explicitly names R1 and R2. Shares the same LED/circuit kernel as electronics. | R2=3 kohms to ground, R1=1 kohm from a 12 V supply gives 3 V. | 9 V. |
| wiring | Single-phase power ignores a stated PF; three-phase PF recognition truncates 1.2 to 1 and typed guard lacks the upper bound. Wire length always means one-way length. | 1000 W, 100 V, PF 0.5 gives 10 A; three-phase 10 kW, 400 V, PF 1.2 gives 14.43 A; total loop length 100 m, 12 AWG copper, 10 A gives 10.42 V drop. | 20 A; decline impossible PF magnitude; about 5.211 V drop in the fixed 20 C model. |
| optics | Medium-aware refraction exists, but frequency/wavelength/photon branches still assume vacuum even with an explicit medium. | 200 THz in index 1.5 gives wavelength 1.499e-6 m. | 9.99308e-7 m. |
| optics-v2 | Angle numbers always mean angles to the normal, even when marked to the surface. | Index 1 to 1.5, 30 degrees to the surface gives 19.47 degrees refraction. | 35.2644 degrees to the normal. |
| optics-v3 | Multiple interfaces collapse to the first and final indices without a geometric premise. | Index 1 through 1.5 into 2 at 30 degrees gives a final angle of 14.48 degrees. | Decline without interface orientations; that result requires parallel interface normals and successful transmission through each boundary. |
| optics-v5 | Explicit in-medium wavelength is treated as vacuum wavelength. | Wavelength 600 nm in index 1.5 gives frequency 4.997e14 Hz. | 3.33103e14 Hz. |
| optics-v5-r2 | Explicit in-medium wavelength is treated as vacuum wavelength for photon energy. | Wavelength 600 nm in index 1.5 gives 2.066 eV. | About 1.37760 eV from E=hf and f=c/(n lambda). |

The five optical wrappers share one corrected first-packet parser. These rows
name where each counterexample was exercised, not five independent models.
Likewise the two electronics wrappers share arithmetic and recognition.

A second two-case extension exposes a different circuit composition error.
Asking the current through 10-ohm and 20-ohm series resistors across 12 V
returned 30 ohms instead of 0.4 A. Asking the source current for two 10-ohm
parallel resistors across 12 V returned 5 ohms instead of 2.4 A. Both incorrect
target selections survived baseline dispatch acceptance and arbitration; D
now computes the requested current/power from equivalent resistance. Receipts are
`var/c-physical-emoptics/next-circuit-target.json` and
`next-circuit-target-runtime.json`. Across the two captures, the examination
has fourteen cases: thirteen incorrect answers and one computable withheld.

## Original implementation priorities and laws

D resolves the circuit role/body/target portion of items 1 and 3. The AC, wire,
optical and transformer parts remain open. The list is retained to connect
the examined counterexamples to their intended models.

1. Preserve roles before performing arithmetic. Use explicit supply/forward
   voltage and named divider branches, and carry line/phase roles and
   connection topology into a typed AC request. A stated but invalid PF must
   not become an absent PF or a numeric prefix. Fully consume its number and
   apply the same physical domain check in the kernel.
2. Express balanced AC power once as `P = 3 V_phase I_phase pf`, together with
   wye `V_line^2 = 3 V_phase^2`, `I_line = I_phase`, and delta
   `V_line = V_phase`, `I_line^2 = 3 I_phase^2` for nonnegative magnitudes.
   Single-phase power is `P = V I pf`. Inverse calculations should follow
   these equations, including nonzero divisor and `0 < pf <= 1` assumptions
   for positive-load magnitude calculations. Regeneration and signed power
   need their own stated model rather than accidental acceptance.
3. Bind LED resistance to `R I = V_supply - V_forward`, with positive current
   and supply above forward voltage. Bind a divider to
   `V_out (R_top + R_bottom) = V_in R_bottom`; its passive bound
   `0 <= V_out <= V_in` requires positive resistors and nonnegative input.
   Neither law alone proves the English roles: preserve and expose those
   roles in the request and test reversed textual order. If all V/I/R facts
   are supplied, check their consistency rather than silently choosing two.
   Recognize the requested quantity before selecting a network formula:
   current and total power across a supplied series/parallel network need
   typed operations that compose its equivalent resistance with `V = I R`
   and `P = V I`, including positive resistance and denominator guards.
   Resistance-only requests retain their existing result. Merely moving
   parser branches would leave this missing operation undefined.
4. Make wire path length explicit. A two-wire one-way run has twice the
   stated conductor length; a stated total loop already contains the return.
   Prove `drop = I rho length_total / area`. Balanced three-phase geometry
   needs its separate model. The current constant is a 20 C resistance model;
   an explicit other temperature must be supported with a sourced coefficient
   or declined, not ignored.
5. Unify optical speed, frequency, wavelength and photon energy for a stated
   nondispersive medium: `n v = c`, `f lambda = v`, `E = h f`, with positive
   inputs and the family's declared index range. This removes three vacuum
   shortcuts together. Named-medium table entries have wavelength-dependent
   physical limits that should be stated; a named material without a supported
   index must continue to decline.
6. Carry angle frame and interface count. Convert a surface angle alpha into
   normal angle `90-alpha` inside the typed model and prove the corresponding
   sine/cosine relation. A chain of explicitly parallel boundaries can
   telescope Snell's law only when each intermediate transmission is valid;
   otherwise require boundary orientation. Never erase extra interfaces to
   fit a two-medium request.
7. Complete ideal transformer inverses coherently from
   `V_s N_p = V_p N_s`, `I_p N_p = I_s N_s`, and conservation of ideal power.
   Positive turns and role-aware current/voltage recognition are prerequisites.

First-packet lens work already supplies explicit unit normalization, object
and focal inverses, zero guards and a roundtrip law. The next examination
should additionally distinguish linguistic real/virtual image roles and the
chosen signed-distance convention. This is a model-contract issue, not a
reason to reject ordinary signed distances.

## Next verification boundary

Capture published and candidate runtime behavior before editing each path.
Prepare varied role/order/unit cases separately from an untouched evaluation
set. Verify a shared operation across every wrapper that exposes it, then
through dispatch and the package. Keep shipped panel numbers in the primary
lane report and report these semantic probes separately; do not replace the
completion metric or conceal their counterexamples behind panel totals.

No next-packet proof claim is established by this design record. The accepted
first packet is bound to passed proof `20261018T073153Z-5cfb0fd53cae` and native
compile `20261018T075712Z-2fdba43036b0`. Its report distinguishes the earlier
failed oracle scan and diagnostic export from the accepted repaired proof.

Scalar role recognition in the next packet should bind values issued by the
shared `ExactNumeric.mask` API, rather than extracting a second numeric grammar
from normalized text. This preserves malformed-run boundaries and avoids
reading digits from unit notation. A cross-lane review found that a literal
`QNUM0Q` could collide with generated `qnum0q` after the recognizer lowercased
its text. A standalone scratch reproduction confirmed the collision. The
shared owner repaired freshness against case-folded original text and reports
88 focused checks plus 8 root checks passing; no shared source was edited by this lane. The
corrected numeric source SHA256 is
`2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.

## Accepted D circuit implementation

The circuit request now has a single body. The old Boolean and duplicate outer
resistor bag are removed; resistor checks inspect the operands actually used
by each body, including the inferred resistance when computing R from V/I.
A network body carries Series/Parallel, its resistor list and a target:
equivalent resistance, source current, or total power. Zero supply is valid;
signed supply gives signed current and nonnegative passive dissipation.

LED requests carry supply, forward drop and forward current explicitly. Their
selected model is a forward-biased, constant-drop diode with positive forward
voltage/current and supply above the drop. Divider physical top/bottom/ground
roles override names and textual order. Only when no physical role is stated
do conventional R1/R2 labels determine top/bottom; wholly unlabeled lists keep
the documented top-then-bottom convention. Output prints selected Rtop/Rbottom
values. A grounded R1 is therefore the bottom resistor, not an invalid circuit.
Conflicting actual connection roles decline.

All supported circuit quantities now resolve tokens issued by ExactNumeric.mask.
They preserve exact fractions, scientific notation, negative values and SI
prefix case. They do not reparse numeric substrings or treat unit exponents
as scalar quantities. The shared numeric source enters the native compiler
input graph. Circuit output kinds are unchanged; the sidecar adds only static
circuit model assumptions to the two electronics specialists.

The 36 authored cases in `circuit_probes.json` separate assertions from
capability scoring. Four computable extensions (a zero-ohm parallel short,
an active negative-resistance network, LED current from given resistance,
and divider total power) are expected safe refusals under the
chosen passive model, but count as valid withheld in the capability totals.
Malformed or conflicting data and missing topology are separately invalid or
underdetermined. `check_circuits.py` checks the shipped response-text scorer
and the requested output kind across both wrappers and family routing.
`circuit_fresh.py` uses independent Fraction equations and original generated
question combinations; its author also wrote the recognizer. Development seed
127081 is seen and passes 128/128 in each mode (C baseline 41 right, 60 wrong,
2 false yes, 25 withheld). Seeds 137059 (custom) and 139021 (shipped generator)
were materialized after final parser freeze and passed without source edits.

Current proof work: D1 `20261018T080858Z-163756bec1dc` failed on a variable named
`top` resolving to Isabelle's lattice constant. D2
`20261018T081739Z-040225140b43` checked farther, exposing an uninstantiated
reciprocal function plus a nonexistent fact and unavailable nonlinear tactic.
D3 `20261018T082718Z-7cd6190960e4` uses explicit reciprocal instantiation,
`zero_le_square`, and multiplication order laws for signed divider bounds.
D3 reached one remaining signed-power proof issue: a repeated introduction
step wrongly split the already nonnegative square into nonnegative-current
subgoals. D4 `20261018T083124Z-8c669c5381dc` supplies the square and positive
resistance facts directly. D4 passed: `VERI7VN_EMOPTICS PASS theorems=66 scanned=18375 oracles=0`.
The 66 selected claim roots are distinct from broad generated-family facts.
Bound native compilation and runtime checks passed as recorded below.
The prior C binary remains captured unchanged. Target checks also prevent LED
current questions from returning a sizing resistor or divider-power questions
from returning output voltage; those computable inverses remain capability
withholds. Capacitors are not silently omitted from resistor-only networks. Scratch type/request checks preceded the accepted native run; no scratch
adapter or manually edited kernel is used in the published binary.

The remaining electrical, wiring and optical rows above are still open.

## What the D proof actually establishes

- An exact circuit answer implies strictly positive resistance for every
  resistor actually owned by that operation. `R_resistor` is declined exactly
  when one of those body-owned resistances is nonpositive. No caller-supplied
  coverage bag or Boolean is needed.
- An accepted network has a nonempty positive-resistor list and strictly
  positive equivalent resistance. Its accepted source current satisfies
  `I * Req = Vs`. Accepted power/current outputs for the same network satisfy
  `P = Vs * I = I * I * Req` and `P >= 0`, including negative or zero supply.
- An accepted LED sizing answer satisfies `R * I = Vs - Vf`, with `R > 0`,
  `I > 0`, `Vf > 0`, and `Vs > Vf`. Roles are explicit typed operands; the
  theorem does not certify the English recognition.
- An accepted divider output satisfies
  `Vout * (Rtop + Rbottom) = Vin * Rbottom` and lies between
  `min(0,Vin)` and `max(0,Vin)`. Positive resistor domains follow from the
  accepted request itself, while signed input is preserved.
- Existing series-sum, parallel-reciprocal, parallel-branch bound, Ohm, RC,
  power, optical and numerical-error claims remain in the checked closure.
  Scalar redundant values are guarded by the applicable ideal equations;
  inconsistent V/I/R/power data decline instead of silently discarding givens.

English role selection, JSON framing, response-text parsing and the evaluators
remain untrusted. The sidecar's circuit evidence is explicitly a static model
catalogue, not a certificate of the interpretation of each reply.

## D receipts, measurements and integration files

Proof attempt: `var/emoptics/remote-attempts/20261018T083124Z-8c669c5381dc/receipt.json`.
Source digest: `c919f964e32d5199964b5646858390f4082f53728b2e8fceed941539e97f7532`.
Exact exported SML SHA256:
`edb238573f6d1ede9a41bb1dfa3b2e93112e735f9b353b7902f48c0db86e2cf1`.
Actual consumed-input manifest:
`var/emoptics/native-attempts/20261018T083702Z-bdb5929a3232/compile-inputs.json`,
also published at `var/emoptics/build/compile-inputs.json`.
The manifest binds the passed proof, frozen compiler inputs, compiler and
published binary; source/proof hashes and the binary were checked for matches.
It includes the actual consumed numeric.sml SHA256
`2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.
Recognizer SHA256:
`d623902098cdb1f93623b066ebd2b1c3ac460599907ce034e17c2065a6f55202`.
Binary SHA256:
`d6ace3cf7cfc9489cd62cc46c19ac02e1595ca33c80bc5b03746e99efebf96f1`.
Size: 834,712 bytes, versus 776,952 for captured C final3.
Cold startup: 5.881, 5.657, 6.129, 6.132, 5.860 ms.

| Specialist | Shipped dev right/wrong/FY/valid-withheld | Shipped held-out | D p50 RTT ms |
|---|---|---|---:|
| electrical | 24/0/0/0 | 24/0/0/0 | 2.230 |
| electronics | 111/0/0/0 | 111/0/0/0 | 0.162 |
| electronics-r2 | 111/0/0/0 | 111/0/0/0 | 0.165 |
| wiring | 42/0/0/0 | 45/0/0/0 | 3.723 |
| optics | 70/0/0/0 | 61/0/0/0 | 0.168 |
| optics-v2 | 68/0/0/0 | 66/0/0/0 | 0.193 |
| optics-v3 | 64/0/0/0 | 67/0/0/0 | 0.166 |
| optics-v5 | 74/0/0/0 | 65/0/0/0 | 0.174 |
| optics-v5-r2 | 74/0/0/0 | 65/0/0/0 | 0.177 |

Fresh shipped-generator totals per specialist (all right in both captured C
and D, zero wrong/FY/valid withheld): electrical 48, electronics 222,
electronics-r2 222, optics 131, optics-v2 138, optics-v3 136, optics-v5 138,
optics-v5-r2 138. Wiring has no generator and is not included in 1,173.
The custom 128-case untouched total is independently repeated for electronics,
electronics-r2 and family mode; these are repeated routes, not 384 unique
questions. Authored cases similarly have 36 unique questions repeated in
three modes. Their per-mode C baseline is 15 right, 12 wrong, 5 false yes,
4 valid withheld; D is 32 right, zero wrong/FY, 4 valid withheld.

Receipts under `var/c-physical-emoptics/`:
`score-d1.json`, `circuits-d-before-final.json`, `circuits-d-after1.json`,
`circuits-d-development-before.json`, `circuits-d-development-after1.json`,
`circuits-d-untouched-before.json`, `circuits-d-untouched-after.json`,
`d-untouched-before/results.json`, `d-untouched/results.json`, `probes-d1.json`,
`awg-d1.json`, `tables-d1.log`.
Independent full physical-dispatch receipt:
`var/c-physical-integration/circuit-d-final-consumer.json` (9/9).
It covers the four baseline wrong answers, signed current/power, zero supply,
a physically grounded R1, and inconsistent V/I/R. Its actual binary and
compiler/proof closure hashes match the accepted D packet.

Root should integrate only these named D paths (no lane commits):

- `src/extract/emoptics/Emoptics.thy`
- `src/extract/emoptics/Emoptics_Export.thy`
- `src/extract/emoptics/recognizer.sml`
- `src/extract/emoptics/build.sh`
- `src/extract/emoptics/README.md`
- `src/extract/emoptics/capabilities.json`
- `src/extract/emoptics/check_circuits.py`
- `src/extract/emoptics/circuit_fresh.py`
- `src/extract/emoptics/circuit_probes.json`
- `project/lanes/C-physical-emoptics-next.md`

Current source and native inputs remain frozen until root integration and
runtime capture. The next useful scope is the explicit-medium optical
frequency/wavelength/energy model and angle-frame semantics; the outstanding
AC, wiring and unsupported circuit inverses remain visible above.
