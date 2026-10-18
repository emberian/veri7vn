# Electrical and optical model contracts: next packet

Codex, 18 October 2026. Owned by the emoptics lane. This is the examination
record for the next implementation packet; it does not change the frozen
first-packet arithmetic or recognizer. Every one of the nine specialists was
examined against its actual parser and model. A complete shipped panel is not
complete semantic coverage.

## What currently reaches users

Twelve additional questions exercise all nine specialist IDs. The intermediate
warm candidate gives eleven confident incorrect answers and withholds one
computable transformer inverse. The currently published binary gives the same
results through the actual dispatch specialist acceptance and arbitration
stage. These questions are outside the earlier shipped/fresh-generator panels.
They are deliberately adversarial cases authored after reading the code, not
an independent statistical sample.

Runtime capture: `var/c-physical-emoptics/semantic-next-runtime.json`, produced
by `capture_runtime_next.py` in the same scratch directory. This invokes
`Dispatcher.organs_stage`, with the family and specialist pinned; it does not
invoke fusion fallback or other routes. The published binary SHA256 was
`68a6ff498c7c2e467aeae8af7c656825e9d2615f0d34bc9e2bf0668d6e5deed7`.
Direct candidate capture: `semantic-next.json`; executable questions and
independent arithmetic expectations: `semantic_next.py` in that directory.
The candidate predates the accepted first-packet export; these cases exercise
paths that the first packet has not changed.

| Specialist | Examined behavior and current limit | Captured counterexample | Correct model result |
|---|---|---|---|
| electrical | Ideal three-phase power treats every supplied voltage as line voltage. Transformer current only recognizes the forward winding direction. | Wye phase voltage 230 V, line current 10 A, PF 0.8 gives 3.187 kW. Primary 800 turns, secondary 200 turns, secondary current 12 A is withheld when primary current is requested. | 5.52 kW; primary current 3 A under ideal transformer assumptions. |
| electronics | LED inputs become an unordered voltage pair; `max-min` silently exchanges supply and forward voltage. Ohm, passive resistance and RC guard coverage are in the first packet. | LED forward voltage 2 V, supply 1.8 V, current 20 mA produces a 10-ohm resistor recommendation. | Decline: the stated supply cannot sustain the requested forward drop in the assumed series circuit. |
| electronics-r2 | Divider inputs are positional even when the question explicitly names R1 and R2. Shares the same LED/circuit kernel as electronics. | R2=3 kohms to ground, R1=1 kohm from a 12 V supply gives 3 V. | 9 V. |
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
returns 30 ohms instead of 0.4 A. Asking the source current for two 10-ohm
parallel resistors across 12 V returns 5 ohms instead of 2.4 A. Both incorrect
target selections survive dispatch acceptance and arbitration. Receipts are
`var/c-physical-emoptics/next-circuit-target.json` and
`next-circuit-target-runtime.json`. Across the two captures, the examination
has fourteen cases: thirteen incorrect answers and one computable withheld.

## Implementation priority and laws to bind the answer

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
