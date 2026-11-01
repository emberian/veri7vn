# Electrical and optics capability completion

Ready for integration, Codex 18 October 2026. Source and compiler inputs are
frozen pending root integration. This lane owns `src/extract/emoptics/` and the
two emoptics lane reports; it made no commits.

The accepted proof and final2 bound native binary pass all 1,253 shipped panel items
in both specialist and family modes, with zero wrong answers, zero false yes,
and zero valid answers withheld. The preserved baseline had 1,196 right,
13 wrong and 44 valid withheld. The then-untouched final2 generator offset 104729
passes 1,157/1,157, against baseline 1,100 right, 13 wrong and 44 valid withheld.
The original 33 source-derived probes pass. Parent final2 consumer checks pass
8/8 and its interaction sample passes 96/96 in fleet and pinned configurations.
Root subsequently found an inverse-lens possessive phrasing withheld. Final3
repairs optional the/its target grammar and passes 38 source-derived probes
and 40 target-role variants across all five optical wrappers. Offset 104729
is untouched evidence for final2, not a fresh evaluation of final3. Final3
also passes all 674 affected optical panel items in specialist and family
modes, zero wrong/FY/valid withheld, and parent composition passes 11/11. Its role
as prior-candidate evidence is preserved rather than relabeled after tuning.

These are panel and sampled consumer results, not complete model coverage.
The standalone six-criterion parity harness says INCOMPLETE: DOMAIN,
FALSE YES, LANE, SELF and BUDGET comparisons are unmeasured without the
required head/core/lane inputs. It records all panel items correct but cannot
award the overall admission verdict. Separately measured latency is below the
50 ms specialist budget. Fourteen semantic counterexamples outside these
panels remain documented in `C-physical-emoptics-next.md`.

## Shipped and fresh measurements

The earlier S04 report accurately recorded six wrong held-out optics answers
and seven wrong optics-v2 answers. The later blanket zero-wrong handoff did
not. They were wrong choices of incident and transmitted medium, not scorer
errors or floating-point ties.

Counts below use right / wrong / false yes / valid withheld. Correct refusals
count as right; the withheld column means missed valid questions, not every
protocol response with status withheld. All final dev items are right.

| Specialist | Dev count | Baseline held-out | Final held-out | Final p50 RTT ms |
|---|---:|---|---|---:|
| electrical | 24 | 22/0/0/2 | 24/0/0/0 | 2.472 |
| electronics | 111 | 111/0/0/0 | 111/0/0/0 | 0.096 |
| electronics-r2 | 111 | 111/0/0/0 | 111/0/0/0 | 0.098 |
| wiring | 42 | 45/0/0/0 | 45/0/0/0 | 4.301 |
| optics | 70 | 55/6/0/0 | 61/0/0/0 | 0.178 |
| optics-v2 | 68 | 59/7/0/0 | 66/0/0/0 | 0.183 |
| optics-v3 | 64 | 53/0/0/14 | 67/0/0/0 | 0.183 |
| optics-v5 | 74 | 51/0/0/14 | 65/0/0/0 | 0.170 |
| optics-v5-r2 | 74 | 51/0/0/14 | 65/0/0/0 | 0.164 |

Final2 untouched offset 104729, generated after that parser freeze:

| Specialist | Baseline right/wrong/FY/withheld | Final right/wrong/FY/withheld |
|---|---|---|
| electrical | 46/0/0/2 | 48/0/0/0 |
| electronics | 222/0/0/0 | 222/0/0/0 |
| electronics-r2 | 222/0/0/0 | 222/0/0/0 |
| optics | 125/6/0/0 | 131/0/0/0 |
| optics-v2 | 128/7/0/0 | 135/0/0/0 |
| optics-v3 | 121/0/0/14 | 135/0/0/0 |
| optics-v5 | 118/0/0/14 | 132/0/0/0 |
| optics-v5-r2 | 118/0/0/14 | 132/0/0/0 |

Wiring has no shipped generator and is absent from fresh totals. The generators
retain the original author's formulas, templates and blind spots. Offsets
71019 and 82031 were seen during development; final results are respectively
1,140/1,140 and 1,164/1,164, against baseline 1,085/13/0/42 and 1,106/12/0/46.
Offset 93437 was first evaluated on the first final candidate, which exposed
withholdings, so it is **seen**, not the untouched evaluation. After the final
parser repair it reaches 1,153/1,153, against baseline 1,098/13/0/42. The first
failed candidate remains in `var/c-physical-emoptics/final/results.json`.
Offset 104729 was not used for tuning. A later root consumer question drove
the final3 optional-possessive grammar repair, so this evaluation predates
that source change.

Measurement receipts, under `var/c-physical-emoptics/`: `score-final2.json`,
`final2/results.json`, `baseline/results.json`, `baseline-reserved/results.json`,
`final-untouched/results.json`, `baseline-untouched/results.json`,
`probes-final2.json`, `awg-final2.json`, and `parity/`.

## What the implementation changes

All five optics wrappers identify incident and transmitted medium roles using
one corrected parser. Equal or repeated refractive indices retain their roles.
Critical-angle ellipsis, speed-in-medium, lens power, and transformer winding
phrasing reach existing verified kinds. Wiring no longer intercepts ordinary
electronics voltage-drop questions without wire/gauge/cable/length context.
Signed and scientific circuit quantities retain their values and signs.

Lens input roles and explicit length units select image, object, focal length
or magnification calculations. HOL normalizes lengths to centimetres; missing
roles or units decline. New kinds are `object_distance`, `focal_length`, and
`object_at_infinity`, declared in the optical capability sidecar. Static model
metadata describes the whole supported optical catalogue, with conditional
operation assumptions; it is not a checked interpretation of each reply.

The first bound final candidate exposed eight shipped lens phrasings withheld
and a consumer transformer question using “on primary” withheld. Final2 accepts
“sits at a distance of” and optional articles in winding roles. Final3 shares
one target grammar for object and focal inverses, accepting optional “the”
and “its”; the root question with object 30 cm/image 0.6 m now returns focal
length 20 cm. Both rebuilds use the same passed proof export through the
immutable compiler helper; no new HOL source or proof claim was introduced.

The original 33 probes derive expectations from cited OpenStax optics, circuits,
transformer and photon equations. They include direction reversal, equal
indices, normal incidence, boundary refusals, signed focal length, mixed units,
inverse lenses and zero/zero refusal. Their author also wrote the parser;
they are independent arithmetic/source checks, not blind language validation.
On the original 33, baseline has 16 right, 4 wrong, 4 false yes and 9 valid
withheld. Final2 passes 33/33. Five final3 regression cases add article and
possessive inverse targets, mixed units and zero/zero refusal; final3 passes
38/38 (28 positive and 10 negative cases). An additional 40-case cross-wrapper
target-role matrix passes. Receipts: `probes-final3.json` and
`possessive-final3.json`. Affected optical panels are in
`score-final3-optics.json` (674/674 in both modes). Parent current composition
is `var/c-physical-integration/emoptics-final3-consumer.json` (11/11), bound
to final3 actual input and binary hashes. Table transcription checks pass 28/28.

## Proof obligations and trust boundary

The audit's proposed resistor equivalence was false without a coverage premise:
`C_Circ True [] (CB_Parallel [(0,P_1)])` declines because the parallel body also
checks its own branches. The replacement states the actual decision:

```
kernel (C_Circ True rall b) = Decline (Impossible R_resistor)
iff list_ex (lambda r. cv r <= 0) rall
 or (exists rs. (b = CB_Parallel rs or b = CB_Series rs)
               and list_ex (lambda r. cv r <= 0) rs)
 or (exists r c. b = CB_Rc r c and cv r <= 0)
```

The new source also checks signed passive series/parallel and RC inputs,
rejects nonpositive photon frequency, and closes the old lens zero/zero hole.
The focus/infinity theorem now explicitly assumes nonzero focal length.

The new parallel bound says that an exact answer for a nonempty list of strictly
positive branch resistances is at most its smallest branch. The approximate
reply theorem connects an answered `Approx k d` to `stated = Some(value_lit k d)`
and the existing real-model error bound `abs(dec_val d - phys r) <=
abs(phys r)/1000 + 1/1000000000`. It does not prove that an arbitrary downstream
parser reads the printed string correctly.

The inverse lens laws state `1/d = 1/f - 1/di` and `1/f = 1/d + 1/i` for exact
kernel results. Forward image evaluation followed by inverse object evaluation
recovers the original distance when both return exact answers. The unit helper
states `lens_cm l / 100 = amt lu_scale l`.

English recognition, JSON framing, and scorer code remain untrusted. Physical
laws describe ideal thin lenses and the stated electrical models, not every
real apparatus. The final managed Isabelle build checked these statements and their dependencies.

## Accepted build, runtime and remaining work

Passed managed proof attempt: `20261018T073153Z-5cfb0fd53cae` on hbox.
Receipt: `var/emoptics/remote-attempts/20261018T073153Z-5cfb0fd53cae/receipt.json`.
Session log marker: `VERI7VN_EMOPTICS PASS theorems=61 scanned=17855 oracles=0`.
The 61 explicitly selected physical/numerical/consumer claim roots are distinct
from the 17,855 broad family facts, many generated by datatypes and functions.
The latter count is not a count of new physical theorems.

The accepted binary is `var/emoptics/bin/emoptics`, 776,952 bytes. SHA256:
`4be9f6d32d571847a9c7d5090a2832346199ae02481e24af360660104aa909a9`.
Its actual consumed-input manifest is
`var/emoptics/native-attempts/20261018T075712Z-2fdba43036b0/compile-inputs.json`,
also published at `var/emoptics/build/compile-inputs.json`. It freezes the
actual compiler inputs and binds them to the passed managed proof export;
this is not a retrospective hash list inferred from the current checkout.
Generated SML SHA256:
`5f2da2e7ac7fb5eebb299b6c99e07ffbd86eee6213df506dec70c69a30670437`.
Proof source digest:
`234bf7a32407b33fa8f9840cf3a82706725756d54baa1358e528c444586917d3`.
Recognizer input SHA256:
`9922ebac9d3faf76c95e940e5d889909e5875e79c15828615e844c71280554a1`.
This C packet does not yet consume ExactNumeric/numeric.sml.

Parent final2 runtime receipts are
`var/c-physical-integration/emoptics-bound-consumer.json` (8/8, including
30 A transformer, reversed media, inverse/mixed-unit lenses and refusals) and
`dispatch-final.json` in that directory (96/96 fleet, 96/96 pinned).
The earlier transformer miss is retained as `emoptics-before-grammar-consumer.json`.

Baseline cold startup was 137.8, 63.8, 64.8, 64.6, 64.3 ms; final2 runs were
6.510, 5.595, 5.732, 5.790, 5.429 ms. Final3 cold runs were 6.048, 6.003, 5.816, 5.751, 5.858 ms.
Baseline size was 760,296 bytes; final2 was 760,344; final3 is 776,952.
The exported eager self-test was removed while retaining the build-time check;
short direct requests also avoid duplicate expensive reply evaluation.
AWG precision stays at 32 bits: all 41 gauges 0–40 answer within the declared
error bound. A rejected 24-bit optimization answered only 19/41 and withheld
22. Its failure is retained in `unassured-numerical-check.json`; the baseline
41/41 is in `awg-baseline.json`. Startup improvement does not rely on reducing
numerical precision.

Two early transport/queue attempts ran no Isabelle proof. The first complete
attempt `20261018T064241Z-b0c2532898cb` checked the new mathematics but failed
the expanded oracle scan. Diagnostic `20261018T071353Z-4d22c8636ce9` identified
exactly 36 oracle-bearing generated test equations: 18 full-exhaustive and
18 narrowing equations, each using Isabelle Quickcheck's test-generator
oracle. None was a physical/numerical assurance lemma. The implementation
disables those two unused datatype generator plugins; code extraction and the
full family scan remain enabled without fact exclusions. Exact names and
dependencies are in the diagnostic attempt's `results/session.log`. The final
passed proof includes this repair and restored 32-bit precision.

Changed commit paths:

- `src/extract/emoptics/Emoptics.thy`
- `src/extract/emoptics/Emoptics_Export.thy`
- `src/extract/emoptics/recognizer.sml`
- `src/extract/emoptics/build.sh`
- `src/extract/emoptics/README.md`
- `src/extract/emoptics/beyond_score.py`
- `src/extract/emoptics/check_probes.py`
- `src/extract/emoptics/probes.json`
- `src/extract/emoptics/capabilities.json`
- `project/lanes/C-physical-emoptics.md`
- `project/lanes/C-physical-emoptics-next.md`

Remaining semantic work is recorded per specialist in the next-packet report:
line/phase AC roles, complete transformer inverses, LED supply/load roles,
named divider branches, network current/power targets, wire length/PF models,
in-medium optical waves and explicit angle/interface geometry. Its fourteen
cases expose thirteen wrong runtime answers and one computable withheld,
so all-right panels must not be read as semantic completeness. Current C
inputs remain frozen until root integrates and captures them; next work is
prepared only in scratch.
