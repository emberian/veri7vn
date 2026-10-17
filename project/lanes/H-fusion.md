# Lane H: specialist fusion (handoff, 2026-10-16)

Oracle7's `network_v3` planner is now a function proved in Isabelle/HOL, and it is compiled into
a standalone binary. The planner chains specialists through a pool of typed quantities, and
lane G's verified quantity kernel supplies the specialists. Files: `src/extract/fusion/`
([README](../../src/extract/fusion/README.md)) and `tools/fusion/`.

## Result

### The target: Oracle7's fusion answers on the core panel

Oracle7's head answered all 114 network-route items in one recorded pass (it reproduced
every recorded status and path). These are the 84 `network>` items, the 18 `network3>` items
and the 12 `network>validity` refusals. Pass: `var/fusion/oracle7_out.jsonl`, made with
`tools/parity/answerers/oracle7.py --state var/fusion/state`.

| | items | veri7vn fusion |
|---|---|---|
| Oracle7 answered by fusion | 102 | **60 answered, 60 with Oracle7's exact reply text, 0 wrong**, 42 declined |
| of which `network3>` (true fusion: one specialist's result feeds the next) | 18 | 12 answered identically (6 densities→fuels, 6 densities→fluids); 6 declined: need thermo (5), geometry+thermo (1) |
| of which `network>` | 84 | 48 answered identically (core math only); 36 declined: need thermo (18), carboncapture (12), planetary (6) |
| Oracle7's validity refusals | 12 | 12 refused with Oracle7's exact text |

- **Plan shapes.** All 60 answers take Oracle7's recorded node path, with `densities-r2`
  read as `densities` and `fluids-r2` as `fluids`.
- **Declines.** All 42 declines end as "no plan". Each one needs a specialist that has no
  verified kernel: thermo, carboncapture, planetary, geometry.
- **Agreement rules.** The pairwise and anchor rules give identical results on all 114.
- **Time.** The median time per question is 1.2 ms end to end (Python reading plus the
  binary). The binary is 326,856 bytes and starts in 5 to 11 ms; the machine's load average was
  about 250 during the measurement.

### Every specialist call re-asked in English

The 60 answers make 24 specialist calls. Each call was re-asked to lane G's binary in
`network_v3`'s own wording. All 24 values equal the typed node values the planner used.

### Differential against Oracle7's own planner

`measure.py` runs `network_v3.Network` itself, read-only, with its own `allowed` argument set
to the four specialists lane G answers. It is compared with the fusion answerer on a fixed
battery of 266 questions in `network_v3`'s phrasing families, including near-misses that must
decline. Both agreement rules give the same counts:

- **199 answered identically**, with the same plan.
- **54 declined by both**: 51 with no plan, 3 as invalid.
- **8 answered by both with different numbers.** Burning 15 or 250 litres of petrol or
  gasoline, in MJ and in kWh: Oracle7 says 494.8 MJ and fusion says 495.3 MJ (0.1 percent
  apart). The cause is in lane G, not in the planner. 0.015 m3 × 745 kg/m3 = 11.175 kg exactly.
  Lane G's `round_sig` rounds that exact tie up, to 11.18. The densities organ's `%.4g` rounds
  the binary double 11.174999999999999 down, to 11.17. The fuels step then multiplies the
  different mass. See the requests to root below.
- **5 answered only by Oracle7, and Oracle7 is wrong on all 5.** For "What is the buoyant
  force on a 500 g lump of copper in water?" Oracle7 says 49030 N; the true value is about
  0.55 N. The cause, from Oracle7's own trace: the volume is 5.597e-05 m3, `network_v2.g()`
  writes it as `5.5970e-05`, and the fluids organ reads that as 5 m3. The model declines a
  step whose input is below 1e-4 (`phrase`), so fusion declines.

### Lane G's six panels: does fusion change any single-specialist answer?

Lane G's six panels have 641 items (dev and held-out). Composing "lane G first, fusion only
where lane G withholds" **changes 0 verdicts**: 641 / 641 right, the same as lane G alone.
Fusion never answers an item that lane G withholds.

Fusion run alone answers 118 of the 641 items: densities 46, fuels 32, fluids 24, springs 16.
On all 118 its number equals lane G's, and it is within 0.5 percent of the panel's expected
value. Even so, the specialists' scorers reject all 118. The scorers read the number after
"is about", which is the organ's wording, and Oracle7's network says "The answer is ...". In
Oracle7 these questions never reach the network, because the specialists answer them first.

Report: `var/fusion/measure.json` (rows for every item, both agreement rules).
Lane A's harness (`tools/parity/harness.py`) was not used. It scores specialist panels only,
and the fusion target is a core-panel route. Part C of `measure.py` loads the scorers through
the harness's own `panels` module.

## Check-native receipt

`python3 tools/dev/check-native --session Veri7vn_Fusion --session-root src/extract/fusion --session-root src/extract/quantity --expect 'VERI7VN_FUSION PASS' --timeout 600`

- Status `passed`, inputs stable.
- Marker: `VERI7VN_FUSION PASS theorems=26 oracles=0`.
- Session build 2 min 45 s, on lane G's cached sessions.
- Receipt: `var/native-scaffold/sessions/3bbaa5bfccc23792/receipt.json`.
- Immutable attempt: `var/native-scaffold/sessions/3bbaa5bfccc23792/attempts/a4ff417092a24dfdac919c35ab0ea392/receipt.json`.

The ML block in `Fusion_Export.thy` prints the marker only after two checks. First,
`Thm_Deps.all_oracles` must be empty for the listed theorems. Second, the compiled
`fz_self_test` must hold. The self test runs:
- diesel → densities → fuels = 1431 MJ, with its plan;
- copper → densities → fluids = 21.96 N;
- the 54-dollar heater by core math alone;
- a single conversion;
- an invalid duty;
- heating water with no plan;
- the anchor counterexample;
- the name tables.

The counterexample theorems are proved by `code_simp`, which is the simplifier and adds no
oracle.

Machine note: under load, check-native's 0.1 s `ps` sampling sometimes exceeds its 5 s limit,
and the build is then aborted ("Kernel process inspection unavailable"). The retries were run
by `var/fusion/build_retry.sh`. It reruns only on that message and stops on any proof failure.

## Theorem statements (verbatim from `src/extract/fusion/Fusion.thy`)

How to read them:
- `nd` is an arbitrary node function and `ops` an arbitrary operation catalogue.
- `decide nd ops m mem g c p` is the planner: agreement mode `m`, path memory `mem`, goal `g`,
  context `c`, givens `p`.
- `search` is the breadth-first search. `fin_of` is a plan's value when it runs and finishes;
  `complete` means that value exists.
- `same_fin` is within 0.5 percent (`near`) for numbers and equality for yes/no.
- `qdecide m g c p = decide qnode ops_v3 m None g c p` is what the binary runs.

```
core_eval_sound:
  assumes "core_eval xs gd = Some v"
  shows "∃es. length es = length xs ∧ set es ⊆ {1, -1} ∧ dsum xs es = gd ∧ v = cprod xs es"

every_given_used_once:
  assumes "run_plan nd ops c p (start_st p) pl = Some s"
  shows "distinct (concat (map step_uses pl) @ avail s) ∧
         {..<length p} ⊆ set (concat (map step_uses pl) @ avail s)"

answer_has_complete_plan:
  assumes "decide nd ops m mem g c p = Answer v pl"
  shows "complete nd ops c g p pl ∧ fin_of nd ops c g p pl = Some v"

depth_bound:
  assumes "decide nd ops m mem g c p = Answer v pl"
  shows "length pl ≤ 3"

search_complete:
  assumes "search nd ops c g p = SDone d dn"
  shows "(∀pl. length pl < d ⟶ fin_of nd ops c g p pl = None) ∧
         (∀pl f. length pl = d ∧ fin_of nd ops c g p pl = Some f ⟶ f ∈ fst ` set dn)"

answer_all_shallowest_agree:
  assumes "decide nd ops m mem g c p = Answer v pl" and "m = Pairwise ∨ mem = None"
  shows "(∀pl'. complete nd ops c g p pl' ⟶ length pl ≤ length pl') ∧
         (∀pl' f. fin_of nd ops c g p pl' = Some f ∧ length pl' = length pl ⟶ same_fin v f)"

disagreement_never_picked:
  assumes f1: "fin_of nd ops c g p pl1 = Some f1" and f2: "fin_of nd ops c g p pl2 = Some f2"
    and len: "length pl1 = length pl2" and dis: "¬ same_fin f1 f2"
    and shallow: "∀pl. complete nd ops c g p pl ⟶ length pl1 ≤ length pl"
  shows "∄v pl. decide nd ops Pairwise mem g c p = Answer v pl"

decide_on_search:
  assumes "search nd ops c g p = SDone d dn" "∀q∈set p. invalid_why q = None"
  shows "decide nd ops m mem g c p = (if agree m (map fst dn)
            then Answer (fst (pick mem dn)) (steps (snd (pick mem dn)))
            else Disagree (map (steps ∘ snd) dn))"

memory_never_decides:
  "is_answer (decide nd ops m mem g c p) = is_answer (decide nd ops m None g c p)"
  "¬ is_answer (decide nd ops m None g c p) ⟹ decide nd ops m mem g c p = decide nd ops m None g c p"

pairwise_order_independent:
  "set vs = set ws ⟹ agree Pairwise vs = agree Pairwise ws"

agree_not_transitive_counterexample:
  "near 100 (502 / 5)" "near (502 / 5) (504 / 5)" "¬ near 100 (504 / 5)"
  "agree Anchor [FVal (502 / 5), FVal 100, FVal (504 / 5)]"
  "¬ agree Anchor [FVal 100, FVal (502 / 5), FVal (504 / 5)]"
  "¬ agree Anchor [FVal (504 / 5), FVal (502 / 5), FVal 100]"
  "¬ agree Pairwise [FVal (502 / 5), FVal 100, FVal (504 / 5)]"

anchor_three_plans:
  assumes "∀q∈set p. invalid_why q = None"
  shows "search nd ops c g p = SDone d [(FVal (502 / 5), s1), (FVal 100, s2), (FVal (504 / 5), s3)] ⟹
           decide nd ops Anchor None g c p = Answer (FVal (502 / 5)) (steps s1) ∧
           decide nd ops Pairwise mem g c p = Disagree [steps s1, steps s2, steps s3]"
    and "search nd ops c g p = SDone d [(FVal 100, s1), (FVal (502 / 5), s2), (FVal (504 / 5), s3)] ⟹
           decide nd ops Anchor mem g c p = Disagree [steps s1, steps s2, steps s3] ∧
           decide nd ops Pairwise mem g c p = Disagree [steps s1, steps s2, steps s3]"

single_conversion_not_answer:
  assumes "p = [q]" "g = GDim gd fct False" "core_math [q] gd = Some cm" "0 ≤ cm / fct"
  shows "decide nd ops m mem g c p = SingleConversion ∨ (∃i w. decide nd ops m mem g c p = Invalid i w)"

echo_not_answer:
  assumes "decide nd ops m mem g c p = Answer (FVal v) []" "g = GDim gd fct b" "fct ≠ 0"
  shows "∀q∈set p. qdim q = gd ⟶ amount q ≠ v * fct"

op_goal_needs_operation:
  assumes "decide nd ops m mem g c p = Answer v pl" "g = GDim gd fct True"
  shows "pl ≠ []"

answer_uses_givens_once:
  assumes "decide nd ops m mem g c p = Answer v pl"
  shows "∃s. run_plan nd ops c p (start_st p) pl = Some s ∧
     distinct (concat (map step_uses pl) @ avail s) ∧
     {..<length p} ⊆ set (concat (map step_uses pl) @ avail s)"

phrase_sound: "phrase x = Some y ⟹ |rl y - rl x| ≤ |rl x| / (2 * 10 ^ 5)"

qnode_sound:
  assumes "qnode f c qs = Some r"
  shows "∃xs rq q y. all_some (map (phrase ∘ amount) qs) = Some xs ∧ request_of f c xs = Some rq ∧
     kernel rq = Exact (kind_of rq) q ∧ q = qval rq ∧ r = NVal y ∧
     |rl y - rl (q * out_factor f)| ≤ |rl (q * out_factor f)| / (2 * 10 ^ 3)"
```

How the planner calls the kernels: option (a). `Veri7vn_Fusion` imports `Veri7vn_Quantity`.
`qnode` is defined from lane G's `kernel`, `stated_dec` and `request`. The search theorems
take the node function as a parameter, so they also hold for nodes that do not exist yet.
Lane G's files are not modified.

## What is trusted and untrusted

- **Proved (HOL):**
  - the pool, steps, slot typing, `network_v3`'s admission conditions for each operation
    (`admits`: attached amounts, fluid, fuel, burn, CO2 question, "full of");
  - the final arithmetic (`core_math`, including the temperature-difference rule);
  - Finish with its single-conversion, echo and "op goal" rules;
  - breadth-first search with the 3-step and 3000-state budgets;
  - both agreement rules, path memory, and network_v2's five validity rules;
  - the node instantiation through lane G's kernel.
- **Checked, not proved:** the name tables `v3_materials` and `v3_fuels`. The phrasing check
  and the differential cover the names those questions use.
- **Untrusted:**
  - `tools/fusion/answerer.py`: the port of `read_givens`, `read_goal`, `normalise`,
    `read_flags_v3`, `attached`, `depth_attached`, plus the reply layout;
  - `src/extract/fusion/main.sml`: JSON framing.
- **Trusted toolchain:** the Isabelle code generator and MLton.

## Deliberate differences from network_v3 (see the README)

1. The default agreement rule is pairwise. The shipped anchor rule is available with
   `--agree anchor`.
2. Duplicate states are merged only when the whole quantity matches, not just value and
   dimension.
3. A step whose input is below 1e-4 declines. Oracle7 writes such an input in exponent form,
   and the specialist misreads it.
4. Arithmetic is exact rational. In the tie check of the final arithmetic, Oracle7 rounds to
   9 decimals and the model compares exactly. When a reciprocal of 0 would be needed, Oracle7
   raises an exception and the model treats the state as not finishing.
5. Operations are tried in increasing pool order. Oracle7 iterates a Python `frozenset` of
   names, and that order changes the anchor rule's first plan.
6. The candidate cache is keyed by value and role, so Oracle7 could reuse one call's result
   for an input from a different source. The model has no cache.
7. No operation has two temperature slots, so the rule that keeps two temperatures in
   from→to order is not modeled. It only matters for thermo.

## Remaining

1. **Nodes for the other 42 items.** Thermo (sensible heat, melting ice; 24 items),
   carboncapture (gasoline CO2; 12) and planetary (planet weight; 6) need verified kernels. The
   planner takes them as new `fop` constructors with slots, an admission rule and a `qnode`
   case; the search theorems carry over unchanged. The thermo operation also needs the
   two-temperature order rule.
2. **Request to root for lane G (rounding ties).** `Quantity.round_sig` rounds an exact
   half-way value up. The organs print `%.4g` of a binary double, which can round it down
   (11.175 → 11.17). The two disagree in the fourth digit on exact ties. This is within lane
   G's proved bound, and the panels do not see it, but 8 of the 266 battery questions differ
   from Oracle7 because of it. Requested export or lemma: a stated-value rounding that matches
   Python's float formatting, or a statement of the tie behaviour. Fusion inherits whichever
   lane G ships.
3. **Order independence of the whole search** under a permuted operation catalogue is not
   proved. Proved instead: the pairwise check depends only on the set of values found, and
   path memory never changes whether the planner answers.
4. **Reply layout** (`g6`, "$%.2f") is Python and not proved. All 60 answers on the target
   are text-identical to Oracle7's.
5. **Board entry** for root: 60 of the 102 Oracle7 fusion answers, identical, 0 wrong. Board
   number: none on the specialists' own scorers; fusion is a core route, not a specialist panel.

## Reproduce

```sh
python3 tools/dev/check-native --session Veri7vn_Fusion --session-root src/extract/fusion \
  --session-root src/extract/quantity --expect 'VERI7VN_FUSION PASS' --timeout 600
sh src/extract/fusion/build.sh                 # export -n under the build lock, MLton -> var/fusion/bin/fusion
python3 tools/fusion/measure.py                # parts A-D -> var/fusion/measure.json
# the Oracle7 pass it compares against (one process, already recorded):
python3 -c "import json;d=json.load(open('upstream/workbench/data/core_panel.json'))['items'];[print(json.dumps({'id':'core:%d'%i,'q':x['q'],'session':'fusion-core-%d'%i})) for i,x in enumerate(d) if str(x.get('path','')).startswith('network')]" > var/fusion/oracle7_in.jsonl
.venv/bin/python tools/parity/answerers/oracle7.py --state var/fusion/state < var/fusion/oracle7_in.jsonl > var/fusion/oracle7_out.jsonl
```
