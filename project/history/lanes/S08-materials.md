# Lane S08-materials: additive-v2, materials-v2, soil, soil-r2, water, water-r3 (handoff, 2026-10-17)

Six specialists as one verified HOL kernel, exported to SML, compiled with MLton into
`var/materials/bin/materials` (775,144 bytes, arm64, not committed; cold start 3.5 to 5.2 ms).
Files: `src/extract/materials/` ([README](../../src/extract/materials/README.md)).

## Result (own scorer of each shipped panel; right / wrong / valid withheld / false yes)

| Specialist | Dev | Held-out | Shipped organ held-out | p50 in binary (budget 50 ms) |
|---|---|---|---|---|
| additive-v2 | 32 / 0 / 0 / 0 | **20 / 0 / 0 / 0** | 20 / 0 wrong / 0 fy | 0.08 ms |
| materials-v2 | 34 / 0 / 0 / 0 | **24 / 0 / 0 / 0** | 24 / 0 / 0 | 0.17 ms |
| soil | 36 / 0 / 0 / 0 | **36 / 0 / 0 / 0** | 36 / 0 / 0 | 0.08 ms |
| soil-r2 | 36 / 0 / 0 / 0 | **36 / 0 / 0 / 0** | no verdict of its own (soil's 36) | 0.06 ms |
| water | 46 / 0 / 0 / 0 | **47 / 0 / 0 / 0** | 47 correct, 0 fy | 0.10 ms |
| water-r3 | 46 / 0 / 0 / 0 | **47 / 0 / 0 / 0** | no verdict, manifest or panel of its own | 0.12 ms |

Same numbers per manifest (`--specialist ID`) and as one family (no argument, order water,
additive-v2, materials-v2, soil). All 6 x 2 splits: 0 organ disagreements (same status, kind,
value) over every panel question. Harness (`var/materials/parity/`) reports each split
`INCOMPLETE` only because no head answerer was run; its ok/fy/wrong columns match above.

**water-r3 status.** Lane A found no panel for it. Its manifest has no `panel` or `budgets`
block and no verdict. It is the water-r2 boundary patch plus a second one, over `water`'s code
(`water_panel_v1.json` is byte-identical in `water-r3/`). Scored on `water`'s panel with its own
narrowing in the recognizer; the number is therefore the same as water's and says nothing about
what the extra "silent on molar or mole turns" rule costs on other traffic.

Mid-build note: the first working binary withheld pH for `3.2e-5` mol/L (enclosure too wide at
60 bits); raising the working precision to 120 (`prec`, outside every soundness theorem) fixed it.
In family mode the first order (soil before materials) made soil answer aerogel porosity with
2.65; the order was changed to put materials-v2 first, as the organs' domains require.

## Check-native receipt

`Veri7vn_Materials` marker `VERI7VN_MATERIALS PASS theorems=64 oracles=0`, status passed;
receipt `var/native-scaffold/sessions/56a69f8fcaa8f659/receipt.json`. Sessions
`Veri7vn_Materials_Base` (`base/`: interval-arithmetic import and the number machinery, lane G's
rounding proofs plus `to_dec3`, `to_fixed`) and `Veri7vn_Materials`. Build about 1 min each.
`tables_check.py`: TABLES PASS, 18 checks (constants, unit factors, atoms per cell, the twelve
texture rules against the organ on 20,301 fractions, class names).

## Theorem statements (verbatim from `Materials.thy`)

Model: `qval` is the exact rational value; `phys` the real model (pi, sqrt, log, powr);
`decline_of` the decline predicates; `approx_spec` the interval expression of each irrational
kind; `tol_approx lay d x` the printed-digit tolerance (half unit for exact roundings,
`|x|/10^(p-1)` for p significant digits, `10^e` for fixed decimals).

```
theorem kernel_exact_sound:
  assumes "kernel r = Exact k q"
  shows "decline_of r = None \<and> approx_spec r = None \<and> k = kind_of r \<and> q = qval r \<and> rl q = phys r"
theorem kernel_approx_sound:
  assumes "kernel r = Approx k d lay"
  shows "decline_of r = None \<and> k = kind_of r \<and>
    (\<exists>fa m. approx_spec r = Some (fa, m) \<and>
       \<bar>dec_val d - phys r\<bar> \<le> tol_approx lay d (phys r))"
theorem kernel_class_sound:
  assumes "kernel r = Class k c"
  shows "decline_of r = None \<and> k = kind_of r \<and> class_of r = Some c"
theorem kernel_decline_iff:
  assumes "w \<noteq> Imprecise"
  shows "kernel r = Decline w \<longleftrightarrow> decline_of r = Some w"
theorem kernel_imprecise:
  assumes "kernel r = Decline Imprecise"
  shows "decline_of r = None \<and> (\<exists>spec. approx_spec r = Some spec)"
theorem mesh_vertices_euler:
  assumes "kernel (MeshVertices f g) = Exact k v"
  shows "k = K_mesh_vertices \<and> even_int f \<and> v - 3 * f / 2 + f = 2 - 2 * of_nat g"
theorem mesh_edges_shared:
  assumes "kernel (MeshEdges f) = Exact k e"
  shows "k = K_mesh_edges \<and> even_int f \<and> 2 * e = 3 * f"
theorem mesh_faces_euler:
  assumes "kernel (MeshFaces v g) = Exact k f"
  shows "k = K_mesh_faces \<and> v - 3 * f / 2 + f = 2 - 2 * of_nat g"
theorem extrude_time:
  assumes "kernel (Extrude (Some (v, u)) q uq pm) = Exact k t"
  shows "k = K_extrude_time \<and> 0 < q \<and>
    t * 60 * (q * vmm3 uq / (if pm then 60 else 1)) = v * vmm3 u"
theorem crystal_density:
  assumes "kernel (CrystalDensity (Some st) a u m) = Exact k rho"
  shows "k = K_crystal_density \<and> 0 < a \<and> rho * (NA * (a * xcm u) ^ 3) = atoms st * m"
theorem porosity_aerogel:
  assumes "kernel (PorosityAerogel b s) = Exact k p"
  shows "k = K_porosity \<and> 0 < s \<and> b \<le> s \<and> (1 - p / 100) * s = b"
theorem stress_def:
  assumes "kernel (Stress f fu a au) = Exact k s"
  shows "k = K_stress \<and> 0 < a \<and> s * (a * amm2 au) = f * fnewton fu"
theorem strain_def:
  assumes "kernel (Strain d du l lu) = Exact k e"
  shows "k = K_strain \<and> 0 < l \<and> e * (l * lmm lu) = d * lmm du"
theorem modulus_def:
  assumes "kernel (Modulus s su e) = Exact k m"
  shows "k = K_modulus \<and> 0 < e \<and> m * 1000 * e = s * smpa su"
theorem texture_sound:
  assumes "kernel (Texture a b c) = Class k cl"
  shows "k = K_texture \<and> classify (filled a b c) = Some cl \<and> 2 \<le> length (givens a b c) \<and>
    \<bar>fsum (filled a b c) - 100\<bar> \<le> 1 / 2"
theorem soil_porosity:
  assumes "kernel (SoilPorosity (Some b) pd given) = Exact k p"
  shows "k = K_soil_porosity \<and> 0 < b \<and> b < pd \<and> (1 - p / 100) * pd = b"
theorem gravimetric_water:
  assumes "kernel (WaterContent (Some w) (Some d)) = Exact k g"
  shows "k = K_gwc \<and> 0 < d \<and> d \<le> w \<and> g / 100 * d = w - d"
theorem hardness_round_trip:
  assumes "kernel (HardnessGpg x) = Exact k y" "kernel (HardnessMgl y) = Exact k' z"
  shows "z = x"
theorem pounds_product:
  assumes "kernel (Pounds (Some f) (Some d) (Some p)) = Exact k lb"
  shows "k = K_pounds_product \<and> 0 < p \<and> lb * (p / 100) = f * d * lb_gal"
theorem dilution_balance:
  assumes "kernel (Dilution (Some (ca, cb)) (Some (v2, u))) = Exact k v1"
  shows "k = K_dilution \<and> 0 < min (cval ca) (cval cb) \<and>
    max (cval ca) (cval cb) * v1 = min (cval ca) (cval cb) * v2 \<and>
    min (cval ca) (cval cb) \<le> max (cval ca) (cval cb)"
theorem ph_value:
  assumes "kernel (PhOf h) = Approx k d lay"
  shows "k = K_ph \<and> 0 < h \<and> \<bar>dec_val d - (- log 10 (rl h))\<bar> \<le> tol_approx lay d (- log 10 (rl h))"
theorem ph_inverse: "0 < h \<Longrightarrow> 10 powr (- phys (PhOf h)) = rl h"
theorem h_conc_inverse: "log 10 (phys (HConc p)) = - rl p"
theorem water_not_potable:
  "kernel Potable = Decline Judgement"
enclose_sound / stated_of_sound (base/Materials_Numbers.thy):
  assumes "enclose m fa = Some (d, lay)"
  shows "|dec_val d - interpret_floatarith fa []| <= tol_approx lay d (interpret_floatarith fa [])"
  "ok_st (stated_of f q) q"   (the printed decimal of an exact value is within tol_exact)
```

Also proved: per-kind equations for scad cube/sphere/cylinder/frustum, scaling (s cubed and s
squared), extrusion time, packing factor, modulus, expansion, soil bulk density and volumetric
water, gpg, pounds formula, CT, dose, reply theorems (`reply_answered_iff`,
`reply_withheld_names_decline`, `reply_states_exact`).

## Untrusted and unproved

- `regex.sml` (copy of lane G's with the case-folding fix of d85f26c), `recognizer.sml`,
  `main.sml`: hand-ported from the organs. The recognizer builds typed requests; only the half of a
  diameter and a temperature difference are computed there, as exact fractions.
- Text layout (`render_dec`, `render_fixed`, `render_commas`) is checked by the self test and the
  panels, not proved. Reply wording is ASCII (the organs use unicode symbols; scorers read only the
  numbers). Value ties round up on the exact decimal; organs round a binary float.
- Texture class names for fractions in a gap of the NRCS rules: the organ returns nothing, the
  binary stays silent (`silent`).
- Differences from the organs, none on a panel: zero or negative denominators reach the kernel
  and decline as impossible (an organ would raise); a dilution with units other than L, mL, gal
  prints the unit it read.

## Remaining

- Reply wording is not byte-identical to the organs' (numbers are).
- No broader traffic test of the recognizer than the panels and organ comparison on them.
- water-r3 has no panel of its own to judge its extra narrowing.

## Reproduce

See the README. Scratch under `var/materials/` (build logs, `score.txt`, `parity/`, `stmts.txt`).
