# Lane H2: fusion, second pass (handoff, 2026-10-17)

Lane H proved Oracle7's `network_v3` fusion planner in HOL over lane G's quantity kernels and
reproduced 60 of Oracle7's 102 fusion answers on the core panel. The other 42 needed
specialists that had no verified kernel. Lane H2 connects three more verified kernels to the
planner: thermo (lane S06), carboncapture (lane S05) and planetary (lane S02).
Files: `src/extract/fusion/` ([README](../../src/extract/fusion/README.md)) and `tools/fusion/`.

## Result

### The 102 core-panel answers Oracle7 gives by fusion

| | lane H (before) | lane H2 (now) |
|---|---|---|
| answered with Oracle7's exact reply text and specialist path | 60 | **101** |
| wrong | 0 | **0** |
| declined | 42 (thermo 23, carboncapture 12, planetary 6, geometry with thermo 1) | **1** (needs geometry) |
| Oracle7's 12 validity refusals, same text | 12 | 12 |

The 41 new answers: 17 heating questions (thermo; 5 of them first turn litres of water into kg
with densities), 6 melting-ice questions (thermo), 12 car and truck CO2 questions (core math
turns miles and mpg into gallons, then carboncapture), 6 planet-weight questions (planetary).
The one decline is a cylindrical tank "0.8 m across and 1.5 m tall"; its volume needs the
geometry specialist. Lane S11 (geometry) has not landed in git, so it was skipped as the brief
says. Both agreement rules (pairwise, anchor) give the same 114 results.

Planet weight is a good check of the plan order. Two shallowest plans finish: surface gravity
(11.6095 m/s2) times 75 kg gives 870.7125 N, and the planet-weight operation gives 870.7101 N.
They agree within 0.5 percent, and the first in network_v2's catalogue order, surface gravity,
is stated. Oracle7 states the same (870.712 N), so the catalogue keeps `ops_for`'s order.

Time: median 0.94 ms per question end to end (pairwise; 0.59 ms anchor). Binary 405,320 bytes,
starts in about 10 ms, 2.7 MB resident.

### Every specialist call re-asked in English

The 101 answers make 70 specialist calls: densities 17, fuels 6, fluids 6, thermo 23,
carboncapture 12, planetary 6. Each was re-asked in network_v2/v3's own wording to the family
binary that owns it, and the number Oracle7's `parse_value` reads from the reply (the first
number before the operation's unit) was compared with the value the planner used: **70 of 70
equal**. The 41 thermo, carboncapture and planetary calls were also asked of the shipped
organs (read-only, bytecode off): **41 of 41 equal**.

### No regression on the families' panels

For each of the four families whose kernels fusion calls, the family binary was run as its lane
scored it, alone and with fusion answering only what the binary withholds, on every panel of the
family (dev and held-out), and both were scored by the specialists' own scorers:

| family (binary) | panels | items | family binary right | composed right | verdict changes |
|---|---|---|---|---|---|
| quantity (lane G) | densities, units, units-v3, springs, fluids, fuels | 641 | 641 | 641 | **0** |
| energy (S06) | thermo, energy-v2, energy-v3, hvac, renewables, iot | 569 | 566 | 566 | **0** |
| climate (S05) | carboncapture, airquality, climate, carbonmat, coldchain, coldchain-v2 | 306 | 297 | 297 | **0** |
| space (S02) | orbits, planetary, spacecraft, spacecomms, astronomy x4 | 1,185 | 1,155 | 1,155 | **0** |

Same counts under both agreement rules. Fusion never answers an item its family binary withholds.
Fusion run alone answers 204 of these items (quantity 118, energy 80, climate 2, space 4). All
204 values are within 0.5 percent of the panel's expected value. The quantity and energy
scorers still reject their 198, because they read the organ's wording ("is about", "It takes")
and fusion says "The answer is". The climate and space scorers accept their 6. In Oracle7 these
questions never reach the network, because the specialist answers them first.

### Differential against Oracle7's own planner

`measure.py` runs upstream `network_v3.Network` read-only, with its `allowed` argument set to
the seven specialists that now have verified kernels, against the fusion answerer:

- **Lane H's battery (266 questions)**: unchanged from lane H. 199 identical answers and plans,
  54 declined by both, 8 different by 0.1 percent (lane G's rounding tie, see lane H's handoff),
  5 answered only by Oracle7, all wrong in Oracle7 (the 5.5970e-05 m3 misreading).
- **Lane H2's battery (130 questions** about heating, melting, gasoline CO2 and planet weight,
  with near-misses): 103 identical answers and plans, 20 declined by both (1 as invalid),
  6 different, 1 answered only by Oracle7.
  - The 6 differences are all exact decimal ties at the fourth significant digit
    (4.5 kg of water, copper, steel, lead or gold warmed by 50 K; 50 litres of water heated by
    45 K: 941,850 J, 86,625 J, 110,250 J, 29,025 J, 29,025 J, 9,418,500 J). Lane S06's kernel
    rounds an exact tie up (its stated deviation, `round_tie_up`). The organ's `%.4g` rounds an
    exactly stored float half to even. So Oracle7 says 941.8 kJ and fusion 941.9 kJ. This is
    within the proved bound (half a unit in the fourth digit) and is the same kind of difference
    as lane G's.
  - The 1 Oracle7-only answer: heating "from 0 C". Oracle7 writes 0 as `0.0000e+00` in its
    question to thermo, and the organ happens to read that as 0. The model declines any input
    below 0.0001 in size (lane H's deliberate difference 3), so it declines here.

Report: `var/fusion/measure.json` (every row, both agreement rules), log `var/fusion/h2/measure.log`.

## How the planner reaches the new kernels: option (a)

`Fusion_Nodes.thy` imports the lanes' own theories (`Veri7vn_Energy.Thermo`,
`Veri7vn_Climate.Climate`, `Veri7vn_Space.Space`) and defines the node function `fnode` from
their kernel functions (`Thermo.kernel_t`, `Climate.kernel`, `Space.kernel`) and their own
rounding of the stated number (`Energy_Core.num_dec_r G4`, `Climate_Num.g_dec`,
`Space.stated_dec`). The node-value theorems are therefore about the real kernels, not about an
abstract node. Why (a): the combined build stays well under 10 minutes. A session has one
parent heap, so the six lane theories it needs are checked again inside `Veri7vn_Fusion`; the
whole session takes 3 min 39 s (lane H's took 2 min 45 s). No other lane's file was changed.

The four families define the same short names (`rl`, `dec_val`, `round_sig`, `outcome`, `Exact`,
`request`, `kernel`, `fuel`, `temp`). `Fusion.thy` still imports only lane G, so lane H's proofs
are untouched. `Fusion_Nodes.thy` and `Fusion_Export.thy` write every lane name in full
(`Energy_Core.outcome.Exact`, `Quantity.fuel.F_diesel`, ...).

### The operations added (`Fusion.thy`)

Five constructors of `fop`, with their slots exactly as `network_v2.ops_for` declares them
(network_v3 keeps them, and adds the CO2 condition to carboncapture's):

| operation (network name) | node | slots: dimension, role | output | renders when |
|---|---|---|---|---|
| `Surface_gravity` (surface_gravity) | planetary | 1 with role earth_mass; 1 with role earth_radius | m/s2, "gravity" | always |
| `Sensible_heat` (sensible_heat) | thermo | kg, any; K, a temperature point; K, a temperature point | J, "heat" | a material is named and is not ice, the temperature rises, both temperatures are givens in the question's order |
| `Melt_ice` (melt_ice) | thermo | kg, any | J, "heat" | the text melts ice |
| `Gasoline_co2` (fuel_co2) | carboncapture | m3, any | kg, "co2" | the text names gasoline/petrol/gas/mpg and asks about CO2 |
| `Planet_weight` (planet_weight) | planetary | kg, any; 1 earth_mass; 1 earth_radius | N, "weight" | always |

The catalogue `ops_all` is `[Surface_gravity, Sensible_heat, Melt_ice, Gasoline_co2,
Planet_weight] @ ops_v3`, network_v3's order among the operations that have a kernel. The
phrasings (and so the requests) are network_v2's: "How much heat is needed to raise x kg of M
from a C to b C?", "How much energy does it take to melt x kg of ice?", "How much CO2 is emitted
by burning g gallons of gasoline?" (g = volume / 3.785411784e-3), "What is the surface gravity
on a planet with M times Earth's mass and R times Earth's radius?", "How much would an k kg
astronaut weigh on a planet with M Earth masses and R Earth radii?". The context gained three
facts: the heating material (`c_heat_mat`), "melt ... ice" (`c_melt`), and "gasoline"
(`c_gasoline`).

## Check-native receipt

`python3 tools/dev/check-native --session Veri7vn_Fusion --session-root src/extract/fusion --session-root src/extract/quantity --session-root src/extract/energy --session-root src/extract/climate --session-root src/extract/space --expect 'VERI7VN_FUSION PASS' --timeout 600`

- Status `passed`, inputs stable. Marker: `VERI7VN_FUSION PASS theorems=32 oracles=0`.
- Session build 3 min 39 s (first build 4 min 31 s).
- Receipt: `var/native-scaffold/sessions/3bbaa5bfccc23792/receipt.json`; see "Receipt" at the end
  for the immutable attempt of the final run.
- The marker is printed only after `Thm_Deps.all_oracles` is empty for all 32 theorems (lane H's
  26 plus the six below) and the compiled self test holds. The self test now also runs: heating
  4 kg of water 15 to 75 C (1.005e6 J, 67/240 kWh, plan `[Sensible_heat [Pool 0, Pool 1, Pool 2]]`),
  the same temperatures in the other order (no plan), melting 8 kg of ice (2.672e6 J),
  25 mpg over 350 miles (124.418 kg of CO2 through a core-math gallons step), and the planet
  weight above, including the 870.7101 N trace of the planet-weight plan.
- One build fix: the first build's session log came back empty, so check-native could not see
  the printed marker. `Fusion_Export.thy` now also writes it as an explicit
  `veri7vn/assertions/fusion` export (after the same checks), which check-native reads.

## Theorem statements (verbatim from `src/extract/fusion/Fusion_Nodes.thy`, with the new definitions)

All of lane H's theorems (see [H-fusion.md](H-fusion.md)) are stated for an arbitrary node
function and catalogue, so they hold for `fdecide m g c p = decide fnode ops_all m None g c p`
unchanged: an answer has a complete plan, at most 3 steps, every shallowest plan agrees within
0.5 percent, disagreement is never picked, every given is used once. The new theorems say what
each node value is.

```
fnode_lane_g:
  assumes "node_of f ∈ {Nd_densities, Nd_fluids, Nd_springs, Nd_fuels}"
  shows "fnode f c qs = qnode f c qs"

sensible_heat_node:
  assumes "fnode Sensible_heat c [m, t0, t1] = Some r"
  shows "∃s mt x a b q d. c_heat_mat c = Some s ∧ heat_mat s = Some mt ∧
     phrase (amount m) = Some x ∧ phrase (celsius (amount t0)) = Some a ∧ phrase (celsius (amount t1)) = Some b ∧
     Thermo.kernel_t (Thermo.request.Thermo [Thermo.temp.Temp a Thermo.tunit.TU_C, Thermo.temp.Temp b Thermo.tunit.TU_C]
        (Thermo.tq.TSens (Some (x, Thermo.munit.MU_kg)) (Thermo.csrc.C_mat mt) Thermo.dtq.DT_temps))
       = Energy_Core.outcome.Exact (STR ''sensible_heat'') q ∧
     q = x * Thermo.spec_heat mt * (b - a) ∧
     Energy_Core.num_dec_r Energy_Core.nfmt.G4 (of_rat q) = Some d ∧ r = NVal (dec_rat d) ∧
     |of_rat (dec_rat d) - of_rat q| ≤ |of_rat q| / (2000 :: real)"

melt_ice_node:
  assumes "fnode Melt_ice c [m] = Some r"
  shows "∃x q d. phrase (amount m) = Some x ∧
     Thermo.kernel_t (Thermo.request.Thermo [] (Thermo.tq.TFusion (Some (x, Thermo.munit.MU_kg))))
       = Energy_Core.outcome.Exact (STR ''latent_fusion'') q ∧
     q = x * 334000 ∧
     Energy_Core.num_dec_r Energy_Core.nfmt.G4 (of_rat q) = Some d ∧ r = NVal (dec_rat d) ∧
     |of_rat (dec_rat d) - of_rat q| ≤ |of_rat q| / (2000 :: real)"

gasoline_co2_node:
  assumes "fnode Gasoline_co2 c [v] = Some r"
  shows "∃g q. phrase (amount v / gal_m3) = Some g ∧
     Climate.kernel (Climate.request.Req_cc (Climate.ccreq.Cc_fuel_co2 Climate.fuel.F_gasoline (STR ''gasoline'') g))
       = Climate.outcome.Exact Climate.kind.K_fuel_co2 q ∧
     q * 1000 = g * 8887 ∧ r = NVal (dec_rat (Climate_Num.g_dec 4 q)) ∧
     (snd (Climate_Num.g_dec 4 q) = - 4 ∨ snd (Climate_Num.g_dec 4 q) = 0) ∧
     |of_rat (dec_rat (Climate_Num.g_dec 4 q)) - of_rat q| ≤ Climate_Num.pow10 (snd (Climate_Num.g_dec 4 q)) / 2"

surface_gravity_node:
  assumes "fnode Surface_gravity c [em, er] = Some r"
  shows "∃M R q d. phrase (amount em) = Some M ∧ phrase (amount er) = Some R ∧ 0 < M ∧ 0 < R ∧
     Space.kernel (Space.request.PGravity (Space.pbody.Pb_earth M R)) = Space.outcome.Exact (STR ''gravity'') q ∧
     q * R ^ 2 = 981 / 100 * M ∧
     Space.stated_dec Space.style.St_pl q = Some d ∧ r = NVal (dec_rat d) ∧
     |of_rat (dec_rat d) - of_rat q| ≤ Space.pow10 (snd d) / 2"

planet_weight_node:
  assumes "fnode Planet_weight c [m, em, er] = Some r"
  shows "∃k M R q d. phrase (amount m) = Some k ∧ phrase (amount em) = Some M ∧ phrase (amount er) = Some R ∧
     0 < M ∧ 0 < R ∧
     Space.kernel (Space.request.PWeightE M R k) = Space.outcome.Exact (STR ''weight'') q ∧
     q * R ^ 2 = k * (981 / 100 * M) ∧
     Space.stated_dec Space.style.St_pl q = Some d ∧ r = NVal (dec_rat d) ∧
     |of_rat (dec_rat d) - of_rat q| ≤ Space.pow10 (snd d) / 2"

| "slots Surface_gravity = [(d_one, λq. role q = Some Ro_earth_mass), (d_one, λq. role q = Some Ro_earth_radius)]"

definition given_before :: "quantity ⇒ quantity ⇒ bool" where
  "given_before a b = (case (origin a, origin b) of (Given i, Given j) ⇒ i < j | _ ⇒ False)"

| "admits Surface_gravity c [em, er] = True"
| "admits Sensible_heat c [m, t0, t1] = (c_heat_mat c ≠ None ∧ c_heat_mat c ≠ Some STR ''ice'' ∧
     amount t0 < amount t1 ∧ given_before t0 t1)"
| "admits Melt_ice c [m] = c_melt c"
| "admits Gasoline_co2 c [v] = (c_gasoline c ∧ c_asks_co2 c)"
| "admits Planet_weight c [m, em, er] = True"

definition fnode :: nodefn where
  "fnode f c qs = (case node_of f of
       Nd_thermo ⇒ (case thermo_req f c qs of None ⇒ None | Some r ⇒ map_option NVal (thermo_val r))
     | Nd_carboncapture ⇒ (case qs of [v] ⇒
          (case gasoline_req v of None ⇒ None | Some r ⇒ map_option NVal (climate_val r)) | _ ⇒ None)
     | Nd_planetary ⇒ (case planet_req f qs of None ⇒ None | Some r ⇒ map_option NVal (space_val r))
     | _ ⇒ qnode f c qs)"


definition ops_all :: "fop list" where
  "ops_all = [Surface_gravity, Sensible_heat, Melt_ice, Gasoline_co2, Planet_weight] @ ops_v3"


definition fdecide :: "agree_mode ⇒ goal ⇒ ctx ⇒ quantity list ⇒ decision" where
  "fdecide m g c p = decide fnode ops_all m None g c p"
```

How to read them. `phrase` is network_v2's six-significant-digit writing of a number (declines
below 0.0001), `celsius k = k - 273.15`, `gal_m3 = 3.785411784e-3`. Each theorem says: the node
asked the lane's kernel the request that the phrasing asks the organ; the kernel answered with
an exact value `q`; `q` satisfies the physics (m c (b - a); m times 334000 J/kg; g times 8887 g
per gallon; g R^2 = 9.81 M; weight R^2 = k 9.81 M); and the node value is the decimal the organ
states, within the stated rounding bound (four significant digits for thermo, half a unit in the
fourth decimal for carboncapture and planetary). `heat_mat` looks the reader's material name up
in lane S06's own table, `Thermo.mat_table`.

## What is trusted and untrusted

- **Proved (HOL):** everything lane H lists, now for the larger catalogue; the slots and render
  conditions of the five new operations (`slots`, `admits`, `given_before`); the node values
  (the six theorems above), through lanes S06, S05 and S02's kernels and their own laws
  (`thermo_exact_sound`, `latent_fusion_law`, `fuel_co2_model`, `gravity_model`,
  `weight_model`, `kernel_exact_sound`, `num_dec_r_sound`, `g_dec_sound`, `stated_dec_sound`).
- **Checked, not proved:** lane H's name tables; that the reader's heating material name is the
  one network_v2 writes (it is looked up in lane S06's table, so an unknown name makes the kernel
  decline). The 70-call phrasing check and the 41 organ calls cover the target.
- **Untrusted:** `tools/fusion/answerer.py` (now also ports network_v2's `material`, `melt` and
  `gasoline` flags and network_v3's heating-material fallback), `main.sml` (JSON framing),
  `tools/fusion/measure.py`.
- **Trusted toolchain:** the Isabelle code generator and MLton.

## Deliberate differences from Oracle7 (added to lane H's list)

8. **Temperatures in the heating question.** Oracle7 writes Celsius rounded to 4 decimals and
   then 6 significant digits; the model skips the 4-decimal step (differs only for a temperature
   given to more than 4 decimals). A temperature of 0 C is declined (see the differential).
9. **Operations without a kernel** (doppler, kinetic and potential energy, cold holding, circle
   area, cylinder volume) are not in the catalogue. On the target this costs the one geometry
   item and changes no answer.

## Remaining

1. **Geometry** (1 target item): lane S11's geometry kernel has not landed. When it does, add
   `Circle_area` and `Cylinder_volume` (slots: m with role diameter; m diameter and m height)
   to `fop` and a `fnode` case, as here.
2. **0 C in a heating question**: decline today. Oracle7's organ reads its `0.0000e+00` as 0. A
   faithful fix allows exactly 0 in the temperature phrasing (`phrase` returns None for it); it
   changes `thermo_req` and the `sensible_heat_node` statement. Not done, to keep the build
   count down.
3. **Rounding ties (request to root, joins lane H's request 2):** lane S06's
   `num_dec_r`, like lane G's `round_sig`, rounds an exact decimal tie up; the organs round a
   binary float half to even. Fusion inherits it: 6 of the 130 new battery questions differ from
   Oracle7 in the fourth digit. A shared "Python %g" rounding lemma or export would fix both.
4. **Order independence of the whole search** under a permuted catalogue is still not proved
   (lane H's remaining 3). The planet-weight case shows that the order decides which agreeing
   plan is stated, never whether the planner answers (`memory_never_decides`, `pairwise_order_independent`).
5. **Board entry for root**: 101 of Oracle7's 102 fusion answers, identical text and path,
   0 wrong; 0 verdict changes on 2,701 items of the 26 panels of the four families fusion calls.

## Reproduce

```sh
python3 tools/dev/check-native --session Veri7vn_Fusion --session-root src/extract/fusion \
  --session-root src/extract/quantity --session-root src/extract/energy \
  --session-root src/extract/climate --session-root src/extract/space \
  --expect 'VERI7VN_FUSION PASS' --timeout 600
sh src/extract/fusion/build.sh                    # var/fusion/bin/fusion
PYTHONDONTWRITEBYTECODE=1 python3 -B tools/fusion/measure.py   # var/fusion/measure.json
```
The family binaries must exist (`var/quantity/bin/quantity`, `var/energy/bin/energy`,
`var/climate/bin/climate`, `var/space/bin/space`; each lane's `build.sh`). Oracle7's recorded
replies are `var/fusion/oracle7_out.jsonl` (lane H's single pass; the Oracle7 head was not run).

## Receipt

Final run, after the last edit to any file in the five session roots: status `passed`, inputs
stable, marker `VERI7VN_FUSION PASS theorems=32 oracles=0`.
Receipt `var/native-scaffold/sessions/3bbaa5bfccc23792/receipt.json`, immutable attempt
`var/native-scaffold/sessions/3bbaa5bfccc23792/attempts/a039a056b12f4ad182bb3e835677692c/receipt.json`.
The theory build it certifies is attempt `441111c72d3a448aac8aed99964e8582` (3 min 39 s); the
final run found the heap up to date.
Binary: `var/fusion/bin/fusion`, 405,320 bytes, sha256
`2ab6d51624d3aea1f51ebbdfe4d7b7a69773d14ff7cb942eef7b135567a804f0`.
