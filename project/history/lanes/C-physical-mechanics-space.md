# Mechanics and space continuation — 18 October 2026

Owner: Codex physical/mechanics_space. No new answer kinds. This packet fixes interpretation and connects existing verified calculations to the questions they were intended to answer. It does not add theorem counts.

## Status

Space is ready from a fresh proved export and final compiled binary, including material-phase and case-sensitive SI force-unit boundary fixes. Mechanics also has a fresh proved export and final binary: all 1,264 shipped cases and both fresh seeds pass. See receipt/performance section below.

## What changed

- Mechanics recognizes direct torque on a lever before the generic two-arm lever branch. Explicit effort/load-arm questions keep their existing meaning.
- Astronomy versions share grammatical subject/reference selection. “Earth years” no longer hides the named planet; “Earth’s year” retains Earth as subject.
- Spacecraft recognizes initial mass before “total mass”, specific-impulse conversion requests, and force stated as an engine rating for burn time.
- Space family selection distinguishes numerical satellite calculations from NASA table properties. A satellite lacking altitude keeps its refusal. Explicit surface escape calculations use the orbital model; an explicitly NASA property request uses its table cell.
- NASA kg-equivalent weight cannot answer a force-in-newtons request. Liquid mercury cannot be interpreted as the planet.
- The exact verified reply consumed by space narrowing is carried with its candidate and emitted if selected. This avoids recomputing interval arithmetic. Candidate records capture replies before another recognizer runs; no result cache persists across turns.
- Both HOL self tests still execute at build time but are not exported as eager runtime constants. Mechanics gains the remote-export build path; both build scripts accept GENERATED_SML and preserve other export directories. Numeric precisions remain mechanics53 / space80 bits.

## Shipped panels

Each cell is right / wrong / false yes / withheld-on-valid. Correct refusals count as right. These are pinned-specialist results, using each shipped scorer. The original organ is measured on the same panels, not inferred from a historical verdict.

| Specialist / split | Original organ | Kernel before | Kernel after |
|---|---:|---:|---:|
| physics dev | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| physics heldout | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| physics-r2 dev | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| physics-r2 heldout | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| physics-r3 dev | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| physics-r3 heldout | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| mechanisms dev | 54/0/0/0 | 54/0/0/0 | 54/0/0/0 |
| mechanisms heldout | 57/0/0/7 | 57/0/0/7 | 64/0/0/0 |
| mechanisms-v2 dev | 63/0/0/0 | 63/0/0/0 | 63/0/0/0 |
| mechanisms-v2 heldout | 55/0/0/0 | 55/0/0/0 | 55/0/0/0 |
| bodies-v2 dev | 38/0/0/0 | 38/0/0/0 | 38/0/0/0 |
| bodies-v2 heldout | 38/0/0/0 | 38/0/0/0 | 38/0/0/0 |
| sports dev | 19/0/0/0 | 19/0/0/0 | 19/0/0/0 |
| sports heldout | 19/0/0/0 | 19/0/0/0 | 19/0/0/0 |
| fleet dev | 54/0/0/0 | 54/0/0/0 | 54/0/0/0 |
| fleet heldout | 54/0/0/0 | 54/0/0/0 | 54/0/0/0 |
| fluids-r2 dev | 34/0/0/0 | 34/0/0/0 | 34/0/0/0 |
| fluids-r2 heldout | 34/0/0/0 | 34/0/0/0 | 34/0/0/0 |
| orbits dev | 35/0/0/0 | 35/0/0/0 | 35/0/0/0 |
| orbits heldout | 35/0/0/0 | 35/0/0/0 | 35/0/0/0 |
| planetary dev | 18/0/0/0 | 18/0/0/0 | 18/0/0/0 |
| planetary heldout | 18/0/0/0 | 18/0/0/0 | 18/0/0/0 |
| spacecraft dev | 21/0/0/0 | 21/0/0/0 | 21/0/0/0 |
| spacecraft heldout | 14/0/0/7 | 14/0/0/7 | 21/0/0/0 |
| spacecomms dev | 32/0/0/0 | 32/0/0/0 | 32/0/0/0 |
| spacecomms heldout | 36/0/0/0 | 36/0/0/0 | 36/0/0/0 |
| astronomy dev | 60/0/0/0 | 60/0/0/0 | 60/0/0/0 |
| astronomy heldout | 68/13/0/0 | 68/13/0/0 | 81/0/0/0 |
| astronomy-v2 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v2 heldout | 130/8/0/0 | 130/8/0/0 | 138/0/0/0 |
| astronomy-v3 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v3 heldout | 137/0/0/1 | 137/0/0/1 | 138/0/0/0 |
| astronomy-v3-r2 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v3-r2 heldout | 137/0/0/1 | 137/0/0/1 | 138/0/0/0 |

## Fresh generator panels

The generator code and expected-answer calculations are shipped by Oracle7. Offsets change the generator’s random seed only; wording/templates retain that author’s blind spots. Seed20261019 was the development sample. Seed20261029 was generated before edits, left unread, and scored only after the recognizer was frozen. No subsequent semantic tuning used that evaluation. The physical deputy then supplied one additional, independent wording (Earth’s year in days). After adding it, the four astronomy wrappers were frozen again and evaluated with a third untouched offset, 20261031; that final evaluation is recorded below. All generated questions and replies are under var/c-physical-mechanics-space.

No generator is shipped for fleet, orbits, or spacecomms in this checkout; these have shipped-panel and authored-probe results, not a fabricated fresh-generator score.

| Specialist / seed / split | Original organ | Kernel before | Kernel after |
|---|---:|---:|---:|
| physics 20261019 dev | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| physics 20261019 heldout | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| physics-r2 20261019 dev | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| physics-r2 20261019 heldout | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| physics-r3 20261019 dev | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| physics-r3 20261019 heldout | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| mechanisms 20261019 dev | 59/0/0/0 | 59/0/0/0 | 59/0/0/0 |
| mechanisms 20261019 heldout | 58/0/0/5 | 58/0/0/5 | 63/0/0/0 |
| mechanisms-v2 20261019 dev | 59/0/0/0 | 59/0/0/0 | 59/0/0/0 |
| mechanisms-v2 20261019 heldout | 62/0/0/0 | 62/0/0/0 | 62/0/0/0 |
| bodies-v2 20261019 dev | 38/0/0/0 | 38/0/0/0 | 38/0/0/0 |
| bodies-v2 20261019 heldout | 38/0/0/0 | 38/0/0/0 | 38/0/0/0 |
| sports 20261019 dev | 19/0/0/0 | 19/0/0/0 | 19/0/0/0 |
| sports 20261019 heldout | 19/0/0/0 | 19/0/0/0 | 19/0/0/0 |
| fluids-r2 20261019 dev | 34/0/0/0 | 34/0/0/0 | 34/0/0/0 |
| fluids-r2 20261019 heldout | 34/0/0/0 | 34/0/0/0 | 34/0/0/0 |
| planetary 20261019 dev | 18/0/0/0 | 18/0/0/0 | 18/0/0/0 |
| planetary 20261019 heldout | 18/0/0/0 | 18/0/0/0 | 18/0/0/0 |
| spacecraft 20261019 dev | 21/0/0/0 | 21/0/0/0 | 21/0/0/0 |
| spacecraft 20261019 heldout | 14/0/0/7 | 14/0/0/7 | 21/0/0/0 |
| astronomy 20261019 dev | 63/0/0/0 | 63/0/0/0 | 63/0/0/0 |
| astronomy 20261019 heldout | 67/11/0/0 | 67/11/0/0 | 78/0/0/0 |
| astronomy-v2 20261019 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v2 20261019 heldout | 130/8/0/0 | 130/8/0/0 | 138/0/0/0 |
| astronomy-v3 20261019 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v3 20261019 heldout | 137/0/0/1 | 137/0/0/1 | 138/0/0/0 |
| astronomy-v3-r2 20261019 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v3-r2 20261019 heldout | 137/0/0/1 | 137/0/0/1 | 138/0/0/0 |
| physics 20261029 dev | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| physics 20261029 heldout | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| physics-r2 20261029 dev | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| physics-r2 20261029 heldout | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| physics-r3 20261029 dev | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| physics-r3 20261029 heldout | 123/0/0/0 | 123/0/0/0 | 123/0/0/0 |
| mechanisms 20261029 dev | 62/0/0/0 | 62/0/0/0 | 62/0/0/0 |
| mechanisms 20261029 heldout | 52/0/0/6 | 52/0/0/6 | 58/0/0/0 |
| mechanisms-v2 20261029 dev | 60/0/0/0 | 60/0/0/0 | 60/0/0/0 |
| mechanisms-v2 20261029 heldout | 57/0/0/0 | 57/0/0/0 | 57/0/0/0 |
| bodies-v2 20261029 dev | 38/0/0/0 | 38/0/0/0 | 38/0/0/0 |
| bodies-v2 20261029 heldout | 38/0/0/0 | 38/0/0/0 | 38/0/0/0 |
| sports 20261029 dev | 19/0/0/0 | 19/0/0/0 | 19/0/0/0 |
| sports 20261029 heldout | 19/0/0/0 | 19/0/0/0 | 19/0/0/0 |
| fluids-r2 20261029 dev | 34/0/0/0 | 34/0/0/0 | 34/0/0/0 |
| fluids-r2 20261029 heldout | 34/0/0/0 | 34/0/0/0 | 34/0/0/0 |
| planetary 20261029 dev | 18/0/0/0 | 18/0/0/0 | 18/0/0/0 |
| planetary 20261029 heldout | 18/0/0/0 | 18/0/0/0 | 18/0/0/0 |
| spacecraft 20261029 dev | 21/0/0/0 | 21/0/0/0 | 21/0/0/0 |
| spacecraft 20261029 heldout | 14/0/0/7 | 14/0/0/7 | 21/0/0/0 |
| astronomy 20261029 dev | 63/0/0/0 | 63/0/0/0 | 63/0/0/0 |
| astronomy 20261029 heldout | 68/10/0/0 | 68/10/0/0 | 78/0/0/0 |
| astronomy-v2 20261029 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v2 20261029 heldout | 130/8/0/0 | 130/8/0/0 | 138/0/0/0 |
| astronomy-v3 20261029 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v3 20261029 heldout | 137/0/0/1 | 137/0/0/1 | 138/0/0/0 |
| astronomy-v3-r2 20261029 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v3-r2 20261029 heldout | 137/0/0/1 | 137/0/0/1 | 138/0/0/0 |

### Post-year-wording untouched astronomy evaluation

Offset 20261031, after the deputy’s additional wording. Same count order: right / wrong / false yes / withheld-on-valid.

| Specialist / split | Original organ | Kernel before | Kernel final |
|---|---:|---:|---:|
| astronomy dev | 59/0/0/0 | 59/0/0/0 | 59/0/0/0 |
| astronomy heldout | 70/12/0/0 | 70/12/0/0 | 82/0/0/0 |
| astronomy-v2 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v2 heldout | 130/8/0/0 | 130/8/0/0 | 138/0/0/0 |
| astronomy-v3 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v3 heldout | 137/0/0/1 | 137/0/0/1 | 138/0/0/0 |
| astronomy-v3-r2 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v3-r2 heldout | 137/0/0/1 | 137/0/0/1 | 138/0/0/0 |

The 21st space probe comes from the deputy. Six later material-phase probes extend a second deputy finding; five further probes exercise SI force notation and a lower-case label; the original 20-probe before/after comparison remains a separate fixed set.

### Final untouched astronomy evaluation after material-phase fix

An independent cross-family consumer check found that solid mercury could still receive the planet’s bulk density after liquid mercury had been excluded. The material boundary now covers solid/metallic/molten/gaseous/vaporous mercury and mercury gas/vapour/metal, without broadly excluding a planet’s solid surface. After this final recognizer freeze, offset 20261103 was generated and evaluated untouched. A later source review found the standalone SI symbol N gap; that follow-up is recorded below.

| Specialist / split | Original organ | Kernel before | Kernel final |
|---|---:|---:|---:|
| astronomy dev | 63/0/0/0 | 63/0/0/0 | 63/0/0/0 |
| astronomy heldout | 68/10/0/0 | 68/10/0/0 | 78/0/0/0 |
| astronomy-v2 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v2 heldout | 130/8/0/0 | 130/8/0/0 | 138/0/0/0 |
| astronomy-v3 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v3 heldout | 137/0/0/1 | 137/0/0/1 | 138/0/0/0 |
| astronomy-v3-r2 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v3-r2 heldout | 137/0/0/1 | 137/0/0/1 | 138/0/0/0 |

### Final untouched astronomy evaluation after SI-symbol fix

Review after the initial Space commit found that “in N” still received kg-equivalent weight even though “in newtons” was rejected. The follow-up explicitly recognizes original-case N, kN, mN and MN as force symbols. Lowercase n remains a possible label, not a silently recased unit. Four refusal probes and a lower-case label control pass. The HOL model and export are unchanged; only the recognizer, probes and this report changed. Offset 20261111 was generated after this parser freeze and was untouched by tuning.

| Specialist / split | Original organ | Kernel before | Kernel final |
|---|---:|---:|---:|
| astronomy dev | 61/0/0/0 | 61/0/0/0 | 61/0/0/0 |
| astronomy heldout | 68/12/0/0 | 68/12/0/0 | 80/0/0/0 |
| astronomy-v2 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v2 heldout | 130/8/0/0 | 130/8/0/0 | 138/0/0/0 |
| astronomy-v3 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v3 heldout | 137/0/0/1 | 137/0/0/1 | 138/0/0/0 |
| astronomy-v3-r2 dev | 138/0/0/0 | 138/0/0/0 | 138/0/0/0 |
| astronomy-v3-r2 heldout | 137/0/0/1 | 137/0/0/1 | 138/0/0/0 |

## Authored probes and composition

Mechanics has 20 and space has 32 committed probes with expected values and sources in beyond_probes.json. They use independent formula calculations but share the recognizer author’s linguistic assumptions. The checker tests both pinned specialist and family mode. Result: mechanics final binary 20/20 and space final binary 32/32 in both modes. Before: mechanics17/20 pinned and20/20 family; space 10/20 pinned (3wrong,3falseyes,4withheld) and 13/20 family (3falseyes,4withheld).

Physical deputy independently checked a96-case cross-family sample through the revised dispatcher:96/96 after these fixes, including the missing-altitude spacecraft question and mercury-fluid / force-newtons boundaries. Receipts: var/c-physical-integration/warm-candidates.json and var/c-physical-integration/space-final-consumer.json. The final eight composed smokes cover missing-altitude refusal, the 1484 N crate, mercury-fluid pressure, planetary Mercury density, Earth’s year, liquid density and solid/molten mercury refusals; all pass.

Family mode does not have the same admissible domain as each individual specialist: two planetary-panel “off” questions (“surface gravity of Jupiter” and “Mars from the Sun”) are valid astronomy questions. The full-family scorer therefore counts one false yes per planetary split, while each pinned planetary score is clean. This scope difference is disclosed, not removed by making useful astronomy answers disappear. All other current shipped family rows have zero wrong/false yes.

## Assurance statements carried through unchanged

The existing W6 fixes already discharged the requested A1 relationships; this packet preserves them and changes no mathematical models. Representative actual statements:

```isabelle
kinetic_energy_momentum:
  kernel (PhKE (Some m) (Some v)) = Exact c e ⟹
  kernel (PhMomentum (Some m) (Some v)) = Exact c' p ⟹
  2 * e * m = p ^ 2

drop_energy_conserved:
  0 ≤ h ⟹ kernel (PhPE (Some m) (Some h)) = Exact c e ⟹
  rl m * phys (PhImpact h) ^ 2 / 2 = (rl e :: real)

stopping_is_reaction_plus_braking:
  kernel (FvStopping (Some v) (Some mu) (Some rt)) = Exact c s ⟹
  kernel (FvBraking (Some v) (Some mu)) = Exact c' b ⟹
  s = spd v * rt + b

exhaust_mass_flow_agree:
  kernel (SExhaust i) = Exact k ve ⟹
  kernel (SMassFlow F fu (Ve_isp i)) = Exact k' mdot ⟹
  mdot * ve = F * forcef fu
```

`hohmann_dv_vis_viva` states that, for positive transfer radii, nonnegative circular speeds satisfying v₁²r₁=μ and v₂²r₂=μ, and nonnegative transfer speeds satisfying each vis-viva equation with semimajor axis(r₁+r₂)/2, the kernel’s real model equals |vₜ₁−v₁|+|v₂−vₜ₂|. `hohmann_dv_stated` additionally connects the rounded result to that value through the interval bound. These assumptions describe an ideal two-body model, not real trajectory certification.

Recognition, JSON framing, rendering and table transcription checks remain untrusted. Theorems establish equations over typed inputs; they do not establish that arbitrary English is correctly interpreted or every nonphysical input is rejected. The reply reuse is untrusted SML control flow, tested through the chosen consumers. Static theorem names in reply provenance are not a per-answer proof trace.

## Source receipts and performance

Space: `var/space/remote-attempts/20261018T063134Z-56f5af0e7d71/receipt.json`
is passed, marker `VERI7VN_SPACE PASS theorems=104 oracles=0` in the complete
session log. Export SHA256:
`3c154be40ca7ca8ed8fe1ee3315bad1b721725f8c8d17714fdf50b720887e8ae`.
Final binary `var/space/bin/space` SHA256:
`357f5c288af269d097e1a1646af1c84af2ec09f1b7c0e31727e2849fee2abbee`.
The snapshot's HOL source matches the final theory; subsequent recognizer-only
changes were compiled against that export and checked on all shipped panels,
the previously reserved evaluation, and the authored probes. The later existing-kind wording patch and material-phase boundary fix only rebuilt the SML recognizer. Each received a further untouched evaluation.

Space binary is 708,200 bytes (the initial timing build was 708,200 bytes). Five final process-start-to-first-reply samples were
4.33, 3.75, 3.73, 3.28, 3.18 ms, median 3.73 ms, compared
with median 177.07 ms before. The very first launch of the first rebuilt binary
was 98.31 ms; it is disclosed rather than excluded from the record. These
measurements do not prove that every cold start is below 20 ms.
Pinned p50 round trips: orbits 9.51 ms,
spacecraft 9.65 ms, planetary
0.28 ms. Other IDs are below 0.2 ms.
Orbits and spacecraft remain above the BEYOND target of one tenth of their
50 ms manifest budgets; that target is not claimed complete. The scoped
before/after JSON reports contain every per-specialist timing. The 53-bit
path-loss failure recorded in S02 is why the existing 80-bit precision was
preserved. A useful next optimization is a proved low-precision attempt with
checked 80-bit fallback, not an unchecked global precision cut.

Final space shipped totals: pinned 1,185/1,185 right, zero wrong, false yes or
valid withholds. Family mode 1,183/1,185 right, zero wrong/valid withholds and
two false yes from the explicitly disclosed planetary-only scope checks.

Mechanics fresh receipt passed at
`var/mechanics/remote-attempts/20261018T063133Z-b5102054dc4c/receipt.json`,
with `VERI7VN_MECHANICS PASS theorems=67 oracles=0` (110.5 s session).
Export SHA256: `d867f6daed616e3f434d14589df87bf9a5b123a0ef76c78f2c4ee4c4bab27dd0`.
Final `var/mechanics/bin/mechanics` is 639,480 bytes, SHA256
`0af31339422601f34d79ff40b4d32b4799dff259f63906de69a852d89499eb63`.
The pinned and family shipped panels each give 1,264/1,264 right, zero wrong,
false yes or valid withholds. Final reserved seed 20261029 is clean for all
eight specialists with generators; fleet has none. All 20 sourced probes
pass in each mode. Exact results: `mechanics-final.json`,
`mechanics-probes-final.json`, and `sealed-mechanics-final/summary.json`
under `var/c-physical-mechanics-space`.

Mechanics startup-to-first-reply samples were 295.67, 4.46, 4.14, 4.06,
4.07 ms (median 4.14 ms), versus the old median about 30 ms. The first launch
of the rebuilt binary is disclosed; repeated process launches do not prove
a universal cold-start bound. Pinned p50 round trips range 0.096–0.191 ms
apart from bodies-v2 at 1.97 ms, meeting one-tenth of its 50 ms manifest
budget. The binary shrank from 655,928 to 639,480 bytes. These runtime
measurements are macOS; the successful proof build is Linux. Runtime owns
the separate packaged Linux reply comparison.

This packet's source is frozen for root's commit and runtime capture. The
next dimensional/domain work is tracked separately in
`project/lanes/C-physical-mechanics-space-next.md`; its counterexamples do
not alter the measured first-packet panel claims.

## Reproduction

```sh
python3 -B src/extract/mechanics/beyond_check.py --family mechanics --shipped --out var/c-physical-mechanics-space/shipped-mechanics
python3 -B src/extract/mechanics/beyond_check.py --family space --shipped --out var/c-physical-mechanics-space/shipped-space
python3 -B src/extract/mechanics/beyond_check.py --family mechanics --seed 20261029 --out var/c-physical-mechanics-space/sealed-mechanics
python3 -B src/extract/mechanics/beyond_check.py --family space --seed 20261029 --out var/c-physical-mechanics-space/sealed-space
python3 -B src/extract/mechanics/check_probes.py --family mechanics --binary var/mechanics/bin/mechanics --out var/c-physical-mechanics-space/mechanics-probes-final.json
python3 -B src/extract/mechanics/check_probes.py --family space --binary var/space/bin/space --out var/c-physical-mechanics-space/space-probes-final.json
```

Only the individual family directories and this report changed. No upstream writes, no shared tooling edits, no new agents or commits from this lane.
