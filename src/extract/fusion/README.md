# Specialist fusion, end to end

Oracle7 can chain its specialists. For "how much energy is released by burning 40 litres of
diesel?" no single specialist knows the answer. The densities specialist turns 40 litres of
diesel into 33.28 kg, the fuels specialist turns 33.28 kg of diesel into 1431 MJ, and plain
arithmetic states the result. Oracle7 calls this fusion (`upstream/root/specialists/_gate/network_v3.py`).

This folder holds that planner as a function written and proved in Isabelle/HOL. The
specialists it chains are lane G's verified quantity kernel (`../quantity/`). The HOL function
is exported to Standard ML and compiled into one standalone binary.

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

The exact statements are in the [lane H handoff](../../../project/lanes/H-fusion.md). The build
fails if any theorem in that list relies on an unchecked step, or if the self test fails
(`Fusion_Export.thy`).

**How the planner calls the kernels.** This session imports lane G's session (option (a) in
the brief). The search theorems take the node function as a parameter, so they cover every
node. `qnode` is defined directly from lane G's `kernel`, `stated_dec` and `request`, so
`qnode_sound` is a statement about the real kernels. Importing costs nothing to rebuild: lane
G's session is already built.

## What is not proved (untrusted)

- `../../../tools/fusion/answerer.py` reads the question. It finds the numbers, their units
  and roles, the asked unit, and which material or fuel each amount belongs to. It is a port of
  Oracle7's own reader, using exact fractions. It also lays out the reply text.
- `main.sml` converts between JSON and the HOL data.
- The tables of material and fuel names in `Fusion_Export.thy` (`v3_materials`, `v3_fuels`)
  map the names Oracle7 puts into its questions to lane G's table entries. `measure.py`
  checks the ones its questions use, by asking lane G's binary the same question in English
  and by running Oracle7's own planner on the same questions.

## Deliberate differences from Oracle7

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

## Build and run

```sh
python3 tools/dev/check-native --session Veri7vn_Fusion --session-root src/extract/fusion \
  --session-root src/extract/quantity --expect 'VERI7VN_FUSION PASS' --timeout 600
sh src/extract/fusion/build.sh            # var/fusion/bin/fusion
echo '{"id": "1", "q": "How much energy in MJ is released by burning 40 litres of diesel?"}' \
  | python3 tools/fusion/answerer.py
python3 tools/fusion/measure.py           # var/fusion/measure.json
```

## Current result

These are the 102 core-panel questions that Oracle7 answers by fusion. 84 go through its
`network` route and 18 through `network3`.

- **60 answered.** All 60 give Oracle7's exact reply text and the same specialist path.
- **0 wrong.**
- **42 declined.** Each one needs a specialist that has no verified kernel yet: thermo (23),
  carboncapture (12), planetary (6), geometry with thermo (1).

The 12 questions that Oracle7's network refuses as impossible (26 hours in a day, a negative
fall height) are refused with the same text. Details are in the
[lane H handoff](../../../project/lanes/H-fusion.md).
