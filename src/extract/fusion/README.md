# Specialist fusion, end to end

Oracle7 can chain its specialists. For "how much energy is released by burning 40 litres of
diesel?" no single specialist knows the answer. The densities specialist turns 40 litres of
diesel into 33.28 kg, the fuels specialist turns 33.28 kg of diesel into 1431 MJ, and plain
arithmetic states the result. Oracle7 calls this fusion (`upstream/root/specialists/_gate/network_v3.py`).

This folder holds that planner as a function written and proved in Isabelle/HOL. The
specialists it chains are verified kernels: lane G's quantity kernel (`../quantity/`: densities,
fluids, springs, fuels), and since lane H2 the thermo kernel of lane S06 (`../energy/`), the
carboncapture kernel of lane S05 (`../climate/`) and the planetary kernel of lane S02
(`../space/`). The HOL function is exported to Standard ML and compiled into one standalone
binary.

## What the planner does

- **The pool.** It starts from the question's numbers, each one typed: an exact amount, a
  dimension (powers of metre, kilogram, second, ampere, kelvin, dollar), and a role such as
  "a duty of 6 hours a day" or "a temperature". Every value a specialist returns joins the pool.
- **Steps.** A step asks one specialist to do one operation, such as "mass of a volume" or
  "buoyant force on a volume". The step runs only if its inputs have the right dimensions and
  are not already used, and only if the question names what the operation needs. For example,
  the amount must be the amount *of* the material ("40 litres of diesel"). The inputs are then
  used up.
- **Finish.** Arithmetic over everything left in the pool must give the dimension asked for,
  using each remaining quantity exactly once (raised to the power +1 or -1). Three things never
  count as an answer: converting a single number to another unit, handing a given number back
  unchanged, and answering a pressure, force or mass question with arithmetic alone.
- **Search and agreement.** All plans of zero steps are tried first, then one step, then two,
  then three. The planner stops at the first depth where any plan finishes. All finished plans at
  that depth must agree within 0.5 percent, or the planner declines. It never picks one.

## Two agreement rules, and why

Oracle7's code does not do what its own description says. The description says every plan
must agree. The code compares every plan with *the first plan found*. Agreement within 0.5
percent is not transitive: 100 and 100.4 agree, 100.4 and 100.8 agree, but 100 and 100.8 do
not. So the shipped code answers 100.4 if it found 100.4 first, and declines if it found 100
first. The answer then depends on the order of the specialist list.

Both rules are in the HOL model. `Anchor` is the shipped rule; `Pairwise` is the described
rule, and the binary uses it by default. Both are proved to behave exactly this way on the
three plans above (`anchor_three_plans`). On every measured question the two rules give the
same result.

## What is proved

The search theorems hold for **any** specialist behaviour, because the node function is an
argument of the planner. The last theorem ties the actual nodes to lane G's kernel.

| Theorem | In plain words |
|---|---|
| `answer_has_complete_plan` | An answer comes with a plan that really runs from the givens and finishes, and the answer is that plan's value. |
| `depth_bound` | No answer uses more than three specialist steps. |
| `search_complete` | The search misses no plan: no plan shorter than the answer's depth finishes, and every finishing plan at that depth is among those compared. |
| `answer_all_shallowest_agree` | Every plan that finishes at the answer's depth is within 0.5 percent of the stated answer, and no plan finishes at a shallower depth. This holds for the pairwise rule, and for the shipped rule when no path memory is used. |
| `disagreement_never_picked` | With the pairwise rule, two shallowest plans that differ by more than 0.5 percent mean no answer at all. |
| `agree_not_transitive_counterexample`, `anchor_three_plans` | The 100 / 100.4 / 100.8 case, and what each rule decides for each order. |
| `memory_never_decides` | Oracle7's path memory only changes which agreeing plan is shown. It never changes whether the planner answers. |
| `pairwise_order_independent` | Under the pairwise rule, the decision does not depend on the order in which plans were found. |
| `every_given_used_once`, `answer_uses_givens_once` | Along a plan, every given is used by exactly one step or is left for the final arithmetic, and no quantity is used twice. |
| `single_conversion_not_answer`, `echo_not_answer`, `op_goal_needs_operation` | The three "never an answer" rules of the Finish step. |
| `core_eval_sound` | The final arithmetic is a product of the remaining amounts, each raised to the power +1 or -1, and the product has the asked dimension. |
| `qnode_sound`, `phrase_sound` | Every specialist value is lane G's exact kernel value for the request (`kernel_exact_sound` then says that this is the formula's value), rounded to four significant digits as the specialist states it. The inputs are rounded to six digits, as Oracle7 writes them into its question to the specialist. |
| `sensible_heat_node`, `melt_ice_node` | Heating: the value is mass times the specific heat from lane S06's table times the temperature rise, and melting ice: mass times 334 kJ/kg, each lane S06's kernel value stated to four significant digits. |
| `gasoline_co2_node` | Gasoline: the value is the volume in US gallons times 8887 g, lane S05's kernel value stated to four decimals. |
| `surface_gravity_node`, `planet_weight_node` | On a body of M Earth masses and R Earth radii, gravity times R squared is 9.81 M, and weight times R squared is the mass times 9.81 M, both lane S02's kernel values as the planetary specialist states them. |
| `fnode_lane_g` | The four lane G specialists are still lane G's nodes. |

The exact statements are in the [lane H handoff](../../../project/lanes/H-fusion.md). The build
fails if any theorem in that list relies on an unchecked step, or if the self test fails
(`Fusion_Export.thy`).

**How the planner calls the kernels.** This session imports lane G's session (option (a) in
the brief). The search theorems take the node function as a parameter, so they cover every
node. `qnode` is defined directly from lane G's `kernel`, `stated_dec` and `request`, so
`qnode_sound` is a statement about the real kernels. Importing costs nothing to rebuild: lane
G's session is already built.

The thermo, carboncapture and planetary nodes are defined the same way, in `Fusion_Nodes.thy`,
from lanes S06, S05 and S02's own kernel functions (`Thermo.kernel_t`, `Climate.kernel`,
`Space.kernel`) and their own rounding of the stated number. An Isabelle session builds on one
parent, so those lanes' theories are checked again inside this session rather than loaded
ready-made; that adds a few minutes to the build. Their files are not modified. Several of
those theories use the same short names (`rl`, `dec_val`, `outcome`, `Exact`, `request`,
`kernel`, `fuel`), so `Fusion_Nodes.thy` writes every name in full.

## What is not proved (untrusted)

- `../../../tools/fusion/answerer.py` reads the question. It finds the numbers, their units
  and roles, the asked unit, and which material or fuel each amount belongs to. It is a port of
  Oracle7's own reader, using exact fractions. It also lays out the reply text.
- `main.sml` converts between JSON and the HOL data.
- The tables of material and fuel names in `Fusion_Export.thy` (`v3_materials`, `v3_fuels`)
  map the names Oracle7 puts into its questions to lane G's table entries. `measure.py`
  checks the ones its questions use, by asking lane G's binary the same question in English
  and by running Oracle7's own planner on the same questions. The heating material is looked
  up in lane S06's own table (`Thermo.mat_table`) by the name the reader found.

## Deliberate differences from Oracle7

The scalar validity model now admits zero magnitudes and zero duty. Duty lies
between zero and one, including both endpoints; planetary mass/radius ratios
remain positive. Core arithmetic rejects a zero denominator where it is used,
and a target unit must have a positive conversion factor. A negative magnitude
is described as outside this planner's model, rather than physically impossible:
signed currents and flows exist, but this planner does not model their direction.
The laws `zero_magnitude_admitted`, `zero_body_rejected`,
`duty_outside_closed_interval`, `nonnegative_duty_admitted`,
`zero_power_product`, `zero_time_denominator`, and
`nonpositive_goal_factor_no_finish` state these boundaries and are included in
the export's oracle scan. Their current build status is recorded in
`project/lanes/D-runtime-fusion.md`.

The English reader uses typed numeric spans from `tools/fusion/numeric.py`.
Decimal, scientific and rational literals are consumed whole: `1/0` is malformed,
never a new given of `0 m`. Malformed or unread numbers stop before the model
receives a partial question. Issued markers bind exact values to roles; a marker
typed by a user cannot supply an amount. This reader remains untrusted Python.

1. **The pairwise agreement rule is the default.** See above.
2. **Duplicate states.** When two search states are the same, Oracle7 keeps one. It decides
   "the same" by values and dimensions only. The model decides by the whole quantity (role,
   origin, marks), because two states that differ only in role can lead to different plans.
3. **Tiny inputs.** Oracle7 writes a number below 0.0001 in exponent form ("5.5970e-05"),
   and the fluids specialist then reads it as 5. The model declines that step instead. See the
   measurement below.
4. **Exact arithmetic.** Oracle7 computes in floating point. When two equally good final
   formulas give values that differ only by rounding, Oracle7 rounds to 9 decimals before
   comparing; the model compares exactly.
5. **Temperatures in the heating question.** Oracle7 writes each temperature as Celsius
   rounded to 4 decimals, then to 6 significant digits; the model skips the 4-decimal step
   (they differ only for a temperature given to more than 4 decimals). A temperature of
   exactly 0 C (or anything below 0.0001 C in size) is written by Oracle7 in exponent form,
   and the model declines that step, as in point 3.

## Build and run

```sh
python3 tools/dev/remote-build persvati src/extract/fusion Veri7vn_Fusion \
  -d src/extract/quantity -d src/extract/commons -d src/extract/energy \
  -d src/extract/climate -d src/extract/space --expect 'VERI7VN_FUSION PASS'
PROOF_RECEIPT=/path/to/passed/receipt.json GENERATED_SML=/path/to/checked/fusion.ML \
  sh src/extract/fusion/build.sh
# The native helper binds the actual compiler inputs to a managed proof receipt.
echo '{"id": "1", "q": "How much energy in MJ is released by burning 40 litres of diesel?"}' \
  | python3 tools/fusion/answerer.py
python3 -B tools/fusion/test_numeric.py
python3 -B tools/fusion/test_validity.py --binary var/fusion/bin/fusion
```

For an explicitly selected retained dependency snapshot, also set
`PROOF_SNAPSHOT=1`. The helper checks the complete saved proof source inventory
and generated export, and records differences from the live source tree. This
does not claim that current dependency edits were proved. Future Fusion bundles
must copy `tools/fusion/numeric.py` beside `answerer.py`.

## Earlier comparison and current repair

The figures below are the earlier H/H2 capture. The current numeric and zero-
magnitude repair, its selected proof inputs and actual checks are reported in
[D-runtime-fusion](../../../project/lanes/D-runtime-fusion.md). In particular,
domain-refusal wording now describes the model's restriction, and small nonzero
answers are no longer rounded to zero before significant-digit formatting.

These are the 102 core-panel questions that Oracle7 answers by fusion. 84 go through its
`network` route and 18 through `network3`.

- **101 answered.** All 101 give Oracle7's exact reply text and the same specialist path
  (60 since lane H; 41 since lane H2: heating and melting with thermo, gasoline CO2 with
  carboncapture, planet weight with planetary).
- **0 wrong.**
- **1 declined**: it needs a geometry operation (a cylinder's volume) that is
  not connected to Fusion's operation catalogue.

In that capture, the 12 questions that Oracle7's network refused as impossible
(26 hours in a day, a negative fall height) were refused with the same text.
There were no changed verdicts on the 26 specialist panels of the four families
it called (2,701 items). Details are in the
[lane H handoff](../../../project/lanes/H-fusion.md) and the
[lane H2 handoff](../../../project/lanes/H2-fusion.md).
