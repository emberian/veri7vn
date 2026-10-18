# Mechanics: supplied gravity and explicit model conditions

Ready and frozen for root integration. The new native is
`bd4012b913766a9fcd25c918fabb47f819353321a67cf2091691d6220e4fb672`.
The actual compiler-input manifest is
`var/mechanics/native-attempts/20261018T104545Z-f11dc9553f17/compile-inputs.json`.
Final managed proof `20261018T103739Z-4f76d5174bac` actually Finished in 117 seconds,
published its checked export and durable assertion marker: 78 roots, zero oracles.
The current source, proof closure, generated code and native inputs match.

## What changes

The previous captured native answers a 2 kg mass lifted 3 m on Mars using Earth
gravity (58.84 J instead of 22.26 J), and also ignores an explicit 1.6 m/s²
(expected 9.6 J). The new request carries named or supplied constant gravity
through potential energy and reuses the existing gravity-aware weight, free-fall
and pendulum models. Source mass, length and gravity units are converted by HOL
functions. Explicit gravity supports m/s², ft/s² and standard g; source values
are never silently replaced by Earth gravity. Zero gravity gives zero potential
energy or weight; a finite free-fall time still needs positive gravity.

The reader binds complete numerical fields and rejects incompatible gravity or
length units, extra unresolved numerical inputs, multiple supplied gravities and
recognized unsupported physical conditions. Explicit supplied gravity takes
precedence over the named surface table. It records missing information or a
model limit instead of asserting the simpler answer. The reader remains
untrusted: spans here refer to masked reader text, not original-user provenance.

The new accepted-answer statements say:

- Potential energy equals mass × supplied gravity × signed height change, with
  nonnegative mass and gravity magnitude.
- Accepted unit-bearing replies equal the independently stated mass,
  acceleration and length scale factors.
- Accepted changes at heights h, k and h+k add exactly.
- For a drop from rest at positive constant gravity and nonnegative height,
  that potential-energy change equals the kinetic energy of the independently
  modelled impact speed.
- The explicit model-limit request cannot produce an answered reply.

The consumer constructs `PhPEAt` for these potential-energy requests and uses
`gravity_si`, `mass_kg` and `length_m`; the existing `BdWeight`, `BdFall`,
`BdImpact` and `BdPendulum` consume the same parsed gravity. Legacy constructor
signatures are retained for other consumers. The family sidecar declares the
new model-limit refusal and the additional existing operation kinds exposed by
these wrappers.

## Evidence

All nine shipped panels pass under their own scorers in both pinned and family
modes, 1,264/1,264 each: physics 246, physics-r2 246, physics-r3 246,
mechanisms 118, mechanisms-v2 118, bodies-v2 76, sports 38, fleet 108 and fluids-r2
68. Wrong, false yes and valid withheld are all zero on these shipped panels.
The four modified wrappers' fresh shipped-template offset 2026102807 also
preserves physics 246, physics-r2 246, physics-r3 246 and bodies-v2 76, all right.
The immutable previous native had those same shipped/fresh counts; the inherited
panels did not expose the supplied-gravity defects.

The separate 31-question authored challenge is reported as capability counts,
not just successful refusal assertions:

| Mode | Before right / wrong / false yes / valid withheld | Final right / wrong / false yes / valid withheld |
|---|---:|---:|
| physics | 3 / 14 / 7 / 7 | 24 / 0 / 0 / 7 |
| physics-r2 | 3 / 14 / 7 / 7 | 24 / 0 / 0 / 7 |
| physics-r3 | 3 / 14 / 7 / 7 | 24 / 0 / 0 / 7 |
| bodies-v2 | 10 / 1 / 0 / 20 | 24 / 0 / 0 / 7 |
| family | 4 / 12 / 7 / 8 | 24 / 0 / 0 / 7 |

All 155 safety assertions pass. Correct rejection of contradictory dimensions
or invalid magnitude domains counts as right; computable unsupported models
remain valid withheld. The reserved seed 2026102907 independently varies mass
in grams, signed height in centimetres and gravity in feet/second²: all 40 cases
pass in each of the five modes, 200/200, versus 200 valid withholdings previously.
No production source tuning followed that evaluation.

Six actual full-default dispatcher controls pass: Mars potential energy,
explicit lunar-like gravity, converted weight, incompatible gravity-unit
refusal, supplied-gravity impact speed and relativistic-model refusal. This is
working-tree composition with all stages enabled; it does not replace a fixed
package selection.

Key receipts under `var/c-physical-mechanics-gravity/`:
`final-shipped.json`, `final-fresh/summary.json`, `final-policy.json`,
`baseline-policy-counted.json`, `final-untouched.json`, `baseline-untouched.json`,
`final-default.json` and `final-binding.json`. Baseline shipped/fresh receipts
are `before-shipped/summary.json` and `before-fresh/summary.json`.
The earlier interpreter prototype is explicitly untrusted and is not used as
production evidence.

The native is 791,480 bytes. Per-specialist warm p50 is 0.10–2.28 ms on this run.
The five cold measurements were 144.14, 6.00, 5.49, 6.34 and 5.85 ms; the first
cold result is retained, not discarded.

## Boundaries and drain state

This is a constant-gravity, near-surface model. Lowering described only by a
positive magnitude remains withheld; an explicit signed height is supported.
Variable fields, drag, nonzero initial fall velocity and relativistic requests
are recognized model limits, not silently replaced. Arbitrary English condition
interpretation is not proved. The existing pendulum assumes small swings.
Mechanism efficiency models and other algorithms are outside this packet.

Proof history is retained: f328 failed an order conversion in the unit theorem;
0c83 failed because simplification expanded the square-root expression before
using the existing square identity. Both are fixed in the passed final source.
Queued superseded snapshot 83a0 was cancelled before proof and is not evidence.
No jobs or successor work remain. Only root integration and immutable capture
are pending.
