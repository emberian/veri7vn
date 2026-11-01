# W6-22 space: declines written out, Hohmann delta-v against vis-viva

Family `src/extract/space/` (session `Veri7vn_Space`, marker `VERI7VN_SPACE PASS`). Commit 71160ff.

## What changed

- `kernel_deterministic` (vacuous: `kernel r = o1 ⟹ kernel r = o2 ⟹ o1 = o2`, and unscanned) is deleted.
- Each kind's decline condition is now stated directly in the numbers and names the question gave, not through the
  code's own predicates (`missing`, `nosync`, `reason_of`, `fake`, `novalue`): `declines_exact_kinds`, `declines_enclosed_kinds`.
  Imprecise (the interval was too wide) is still described by `kernel_imprecise`: it happens only to enclosed kinds,
  so the exact kinds' iffs hold for every decline.
- Hohmann delta-v is tied to vis-viva at both ends of the transfer, with each speed given only by its defining
  equation, first as the real value (`hohmann_dv_vis_viva`) and then for the decimal the kernel prints, with the
  family's enclosure and rounding bound (`hohmann_dv_stated`). The second one does not assume positive radii: a stated value implies them.
- Cross-kind law: the exhaust velocity the kernel states for a specific impulse is the one its mass flow divides by (`exhaust_mass_flow_agree`).
- All new theorems sit in the export theory's oracle scan; the PASS marker is still the last command.
- `build.sh` takes the generated SML from `var/space/export-remote/` when a remote build left it there (same as wordprob does).
- No `by eval` in the family (there were none before either).

Helper lemmas (auxiliary): `pos_times_iff`, `std_g0_pos`, `ve_of_pos_iff`, `sidereal_none_iff`, `kernel_decline_exact`,
`hohmann_dv_real`, and the new projection `ve_given` (the number the question gave for the exhaust velocity: the Isp or the speed).
`unknown_cells` names the five sheet cells NASA marks Unknown (pressure of Jupiter, Saturn, Uranus, Neptune; Pluto's magnetic field) and is proved over the transcribed table.

## New statements (verbatim)

```isabelle
theorem declines_exact_kinds:
  fixes M R k F P i n r wt :: rat
  shows "kernel (PGravity (Pb_si M R u)) = Decline w ⟷ w = Impossible R_nonpositive ∧ (M ≤ 0 ∨ R ≤ 0)"
    and "kernel (PGravity (Pb_earth M R)) = Decline w ⟷ w = Impossible R_nonpositive ∧ (M ≤ 0 ∨ R ≤ 0)"
    and "kernel (PWeightE M R k) = Decline w ⟷ w = Impossible R_nonpositive ∧ (M ≤ 0 ∨ R ≤ 0)"
    and "kernel (SExhaust i) ≠ Decline w"
    and "kernel (STwr F fu M mw) = Decline w ⟷ w = Impossible R_nonpositive ∧ M ≤ 0"
    and "kernel (SMassFlow F fu v) = Decline w ⟷ w = Impossible R_nonpositive ∧ ve_given v ≤ 0"
    and "kernel (SBurn F fu v P pu) = Decline w ⟷
           w = Impossible R_nonpositive ∧ (ve_given v ≤ 0 ∨ F ≤ 0)"
    and "kernel (CLight None rt) = Decline w ⟷ w = Underspecified N_dist"
    and "kernel (CLight (Some d) rt) ≠ Decline w"
    and "kernel (CXfer n pf bytes r ru) = Decline w ⟷ w = Impossible R_nonpositive ∧ r ≤ 0"
    and "kernel (CBits None rq) = Decline w ⟷ w = Underspecified N_dist_rate"
    and "kernel (CBits dx None) = Decline w ⟷ w = Underspecified N_dist_rate"
    and "kernel (CBits (Some d) (Some x)) ≠ Decline w"
    and "kernel (AFake nm) = Decline w ⟷ w = Unknown"
    and "kernel (AProp b p) = Decline w ⟷ w = NoValue ∧
           ((p = P_pressure ∧ (b = A_jupiter ∨ b = A_saturn ∨ b = A_uranus ∨ b = A_neptune)) ∨
            (b = A_pluto ∧ p = P_magnetic))"
    and "kernel (ARatio rs b1 b2 p) = Decline w ⟷
           w = Impossible R_nonpositive ∧ cell_num (sheet b2 p) = 0"
    and "kernel (ALight b) ≠ Decline w"
    and "kernel (AWeight wt wu b) ≠ Decline w"
    and "kernel (AYears b) ≠ Decline w"
    and "kernel AMoonKm ≠ Decline w"
    and "kernel AMoonKkm ≠ Decline w"

theorem declines_enclosed_kinds:
  fixes M R a a1 a2 M0 MF dv x :: rat
  assumes "w ≠ Imprecise"
  shows "kernel (PEscape (Pb_si M R u)) = Decline w ⟷ w = Impossible R_nonpositive ∧ (M ≤ 0 ∨ R ≤ 0)"
    and "kernel (PEscape (Pb_earth M R)) = Decline w ⟷ w = Impossible R_nonpositive ∧ (M ≤ 0 ∨ R ≤ 0)"
    and "kernel (POrbV (Pb_si M R u)) = Decline w ⟷ w = Impossible R_nonpositive ∧ (M ≤ 0 ∨ R ≤ 0)"
    and "kernel (POrbV (Pb_earth M R)) = Decline w ⟷ w = Impossible R_nonpositive ∧ (M ≤ 0 ∨ R ≤ 0)"
    and "kernel (PDensity (Pb_si M R u)) = Decline w ⟷ w = Impossible R_nonpositive ∧ (M ≤ 0 ∨ R ≤ 0)"
    and "kernel (PDensity (Pb_earth M R)) = Decline w ⟷ w = Impossible R_nonpositive ∧ (M ≤ 0 ∨ R ≤ 0)"
    and "kernel (OSync None) = Decline w ⟷ w = Underspecified N_body"
    and "kernel (OSync (Some b)) = Decline w ⟷ w = NoSync ∧ (b = O_sun ∨ b = O_venus)"
    and "kernel (OSpeed None oa) = Decline w ⟷ w = Underspecified N_body"
    and "kernel (OSpeed (Some b) None) = Decline w ⟷ w = Underspecified N_alt"
    and "kernel (OSpeed (Some b) (Some a)) = Decline w ⟷ w = Impossible R_nonpositive ∧ brad b + a ≤ 0"
    and "kernel (OPeriod None oa) = Decline w ⟷ w = Underspecified N_body"
    and "kernel (OPeriod (Some b) None) = Decline w ⟷ w = Underspecified N_alt"
    and "kernel (OPeriod (Some b) (Some a)) = Decline w ⟷ w = Impossible R_nonpositive ∧ brad b + a ≤ 0"
    and "kernel (OEscape None oa) = Decline w ⟷ w = Underspecified N_body"
    and "kernel (OEscape (Some b) None) ≠ Decline w"
    and "kernel (OEscape (Some b) (Some a)) = Decline w ⟷ w = Impossible R_nonpositive ∧ brad b + a ≤ 0"
    and "kernel (OHohDv None hp) = Decline w ⟷ w = Underspecified N_body"
    and "kernel (OHohDv (Some b) None) = Decline w ⟷ w = Underspecified N_alts"
    and "kernel (OHohDv (Some b) (Some (a1, a2))) = Decline w ⟷
           w = Impossible R_nonpositive ∧ (brad b + a1 ≤ 0 ∨ brad b + a2 ≤ 0)"
    and "kernel (OHohTime None hp) = Decline w ⟷ w = Underspecified N_body"
    and "kernel (OHohTime (Some b) None) = Decline w ⟷ w = Underspecified N_alts"
    and "kernel (OHohTime (Some b) (Some (a1, a2))) = Decline w ⟷
           w = Impossible R_nonpositive ∧ (brad b + a1 ≤ 0 ∨ brad b + a2 ≤ 0)"
    and "kernel (SDeltaV v M0 u0 MF uf) = Decline w ⟷
           (w = Impossible R_final_exceeds_initial ∧ M0 * massf u0 < MF * massf uf) ∨
           (w = Impossible R_nonpositive ∧ MF * massf uf ≤ M0 * massf u0 ∧
            (ve_given v ≤ 0 ∨ M0 ≤ 0 ∨ MF ≤ 0))"
    and "kernel (SProp0 v dv du M0 u0) = Decline w ⟷ w = Impossible R_nonpositive ∧ ve_given v ≤ 0"
    and "kernel (SPropF v dv du MF uf) = Decline w ⟷ w = Impossible R_nonpositive ∧ ve_given v ≤ 0"
    and "kernel (CFspl None f) = Decline w ⟷ w = Underspecified N_dist_freq"
    and "kernel (CFspl d None) = Decline w ⟷ w = Underspecified N_dist_freq"
    and "kernel (CFspl (Some (Dist a sc bs)) (Some (x, fq))) = Decline w ⟷
           w = Impossible R_nonpositive ∧ (a ≤ 0 ∨ x ≤ 0)"

theorem hohmann_dv_vis_viva:
  fixes v1 v2 vt1 vt2 :: real
  assumes r: "0 < hr1 ob p" "0 < hr2 ob p"
    and v: "0 ≤ v1" "v1 ^ 2 * rl (hr1 ob p) = rl (mu (obd ob))"
           "0 ≤ v2" "v2 ^ 2 * rl (hr2 ob p) = rl (mu (obd ob))"
    and t: "0 ≤ vt1" "vt1 ^ 2 = rl (mu (obd ob)) *
              (2 / rl (hr1 ob p) - 1 / ((rl (hr1 ob p) + rl (hr2 ob p)) / 2))"
           "0 ≤ vt2" "vt2 ^ 2 = rl (mu (obd ob)) *
              (2 / rl (hr2 ob p) - 1 / ((rl (hr1 ob p) + rl (hr2 ob p)) / 2))"
  shows "phys (OHohDv ob p) = |vt1 - v1| + |v2 - vt2|"

theorem hohmann_dv_stated:
  fixes v1 v2 vt1 vt2 :: real
  assumes k: "kernel (OHohDv ob p) = Approx k d"
    and v: "0 ≤ v1" "v1 ^ 2 * rl (hr1 ob p) = rl (mu (obd ob))"
           "0 ≤ v2" "v2 ^ 2 * rl (hr2 ob p) = rl (mu (obd ob))"
    and t: "0 ≤ vt1" "vt1 ^ 2 = rl (mu (obd ob)) *
              (2 / rl (hr1 ob p) - 1 / ((rl (hr1 ob p) + rl (hr2 ob p)) / 2))"
           "0 ≤ vt2" "vt2 ^ 2 = rl (mu (obd ob)) *
              (2 / rl (hr2 ob p) - 1 / ((rl (hr1 ob p) + rl (hr2 ob p)) / 2))"
  shows "|dec_val d - (|vt1 - v1| + |v2 - vt2|)| ≤
         pow10 (snd d) / 2 + (|vt1 - v1| + |v2 - vt2|) / 1000000 + 1 / 1000000000"

theorem exhaust_mass_flow_agree:
  assumes e: "kernel (SExhaust i) = Exact k ve"
  shows "kernel (SMassFlow F fu (Ve_isp i)) = Exact k' mdot ⟹ mdot * ve = F * forcef fu"
    and "kernel (SMassFlow F fu (Ve_speed ve Su_mps)) = Exact k' mdot ⟹ mdot * ve = F * forcef fu"

lemma unknown_cells:
  "is_unknown (sheet b p) ⟷
     (p = P_pressure ∧ (b = A_jupiter ∨ b = A_saturn ∨ b = A_uranus ∨ b = A_neptune)) ∨
     (b = A_pluto ∧ p = P_magnetic)"
```

## Checks and results

- Build: `tools/dev/remote-build persvati src/extract/space Veri7vn_Space -d src/extract/commons --expect 'VERI7VN_SPACE PASS'`
  gave `VERI7VN_SPACE PASS theorems=104 oracles=0` (log `var/space/remote-build.log`). Three persvati attempts: one statement type
  error (a variable name reused at two types), one killed by the shared `swarm.slice` OOM while other lanes were building, one PASS.
  No proof needed a second attempt.
- Generated SML is byte-identical to the previous build's (`cmp`), so the kernel code did not change. Binary `var/space/bin/space` 743,496 bytes.
- Panels, `PYTHONDONTWRITEBYTECODE=1 python3 tools/parity/harness.py --answerer "var/space/bin/space --specialist {id}" --specialist orbits,planetary,spacecraft,spacecomms,astronomy,astronomy-v2,astronomy-v3,astronomy-v3-r2 --split both --out var/space/parity-w6-after`,
  against a baseline run of the pre-change binary (`var/space/parity-w6-before`): **0 reply differences over 1,185 items**
  (timing fields ignored). Right / scored per split, unchanged:

| specialist | dev | heldout |
|---|---|---|
| orbits | 35/35 | 35/35 |
| planetary | 18/18 | 18/18 |
| spacecraft | 21/21 | 14/21 |
| spacecomms | 32/32 | 36/36 |
| astronomy | 60/60 | 68/81 (13 wrong, as before) |
| astronomy-v2 | 138/138 | 130/138 (8 wrong, as before) |
| astronomy-v3 | 138/138 | 137/138 |
| astronomy-v3-r2 | 138/138 | 137/138 |

  False yes 0 everywhere.
- Audit recount (`python3 -B tools/audit/extract.py`, `check_class.py space`, `markers.py`), with `var/audit/class/space.txt` updated for the new names:
  before 93 statements, V=1 D=24 B=53 A=15, 1 unscanned theorem; after **104 statements, V=0 D=24 B=59 A=21**,
  `marker_last=True oracle_scan=True`, **0 unscanned theorems** (50 theorems).

- Fusion (lane H2 imports this session): `tools/dev/remote-build persvati src/extract/fusion Veri7vn_Fusion -d src/extract/quantity -d src/extract/commons -d src/extract/energy -d src/extract/climate -d src/extract/space --expect 'VERI7VN_FUSION PASS'`
  gave `VERI7VN_FUSION PASS` (second attempt; the first was killed by the shared-slice OOM while re-checking Space's `decline_text`).
  Its generated SML is byte-identical to `var/fusion/build/fusion_generated.sml`, so `var/fusion/bin/fusion` is current and was not rebuilt.
  `PYTHONDONTWRITEBYTECODE=1 python3 -B tools/fusion/measure.py --out var/space/fusion-measure.json` with the new space binary:
  core network items **101/102 same text** (1 declined, needs geometry-v4; 12 validity same), both AGREE modes; space panels
  composed 1155 right of 1185, verdict changed 0.

## What remains

- The astronomy and astronomy-v2 heldout wrongs are unchanged and were not in this lane's scope.
- `decline_text` (a large `fun` over every request constructor) is the memory peak of the Space theories, about 10 GB when Fusion re-checks it;
  it is what the shared slice kills. Splitting it into per-kind functions would make every build that includes Space cheaper; not done here, since it changes code.

## Consumer

Lane H2's fusion (`src/extract/fusion/Fusion_Nodes.thy` imports `Veri7vn_Space.Space`). No exported constant was renamed; only `kernel_deterministic` was removed, and fusion does not use it.
