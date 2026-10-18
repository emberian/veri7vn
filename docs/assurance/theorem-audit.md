# Theorem audit: how much of the assurance is real

Lane A1, 2026-10-17. Tree at `e1a3738` (after lane W5-12 moved every family onto
`commons`). Read-only: no theory was edited and nothing was built.

## In plain words

veri7vn's claim is assurance: each kernel comes with proofs that say something a
wrong kernel could fail. This audit read every theorem and lemma statement in the
30 theory directories (2,234 statements) and sorted them by what they actually
promise.

- **About three in five claims are real.** Leaving aside 509 helper lemmas (proof
  plumbing such as "this interval expression evaluates to that real number"),
  1,725 statements claim something. **1,079 (63%) are binding**: they tie the
  executable code to something independent of it (a physical law in a form the
  code does not compute, an error bound against the real-number model, an exact
  decline condition written out, a round trip, an invariant over all inputs).
  A kernel with a wrong formula, a wrong branch or a wrong rounding would fail them.
- **About one in four restate the code (471, 27%).** They unfold a definition and
  close: `kernel (Density m) = Exact K_density (density m)`, `wvalue (RectArea l w)
  = l * w`. If the definition were wrong, the theorem would be wrong in the same
  way and still prove. They document the code; they do not check it.
- **15 are empty**: they hold for any function (`kernel r = o1 ==> kernel r = o2 ==>
  o1 = o2`), are `x / y * y = x` in disguise, or never mention the kernel at all.
- **26 lean on a flag an untrusted fetch or recognizer sets** (a "complete" bit on
  fetched rows, an "anchor present" bit, a "negative given" bit). They are true,
  but a lying fetch makes them true of the wrong world.
- **134 are worked examples** (ground instances such as `epoch_is_thursday`, the 40
  W540 routing vectors). They catch regressions at one point, nothing more.

Of the 1,079 binding statements, about half (533) speak about the kernel, reply or
decision function itself; 122 are laws of the family's real-number model (they
count only together with the family's approximation-soundness theorem, which
every approximating family has); 424 are about helpers (rounding, parsers, sorting,
tables). The split is by a name heuristic and is approximate.

**Mechanical checks.** No `sorry`, `oops`, `skip_proof`, `axiomatization` or
`quick_and_dirty` appears in any session. But three sessions do not do what their
PASS marker implies:

1. **Guards**: `ROOT` lists `Guards_Vectors` after `Guards_Export`, so the marker
   prints before the vectors theory is checked, and `vectors_pin` and
   `vectors_count` are proved `by eval` (the code-generator oracle). Lane T4 found
   two `by eval` lemmas hiding after the scan; they are still there.
2. **Specialists** (`src/isabelle/specialists/`): the marker is a bare
   `writeln "VERI7VN_SPECIALISTS PASS"` with no oracle scan, and the session
   proves 11 lemmas `by eval`. None of its 25 theorems is checked for oracles.
3. **Reader** (`src/isabelle/reader/`): bare `writeln` marker, no scan; its 18
   theorems are unscanned. (The `relations` family re-proves the reader in its own
   session with a scan, so the shipped relation kernel is covered.)

Elsewhere every marker is the last command of its export theory and refuses
oracles, but 64 more `theorem`-keyword facts are missing from the scan list
(computing 44, earth 7, discrete 5, energy 3, geostats 2, life, space, routing 1
each). `Thm_Deps.all_oracles` is transitive, so an unscanned lemma used by a
scanned theorem is still covered; an unscanned headline theorem is not.

**Where it is strong.** acoustics (86% binding: Doppler, harmonics and decibel laws
against the real model), discrete (Dijkstra optimality, binary search, base64 and
percent-encoding round trips, truth-table semantics), finance (amortization closed
forms, `pmt_amortizes`, `sinking_reaches`), fusion (search completeness, shallowest
agreement, disagreement never picked), chemistry, music, the routing cascade's
general theorems, and lane F's relation reader.

**Where it is weak.** guards (18%: the guards are their own specification; 30 of
44 restate `firesL_def`), wordprob (23%: six of its `*_value` theorems are
`x / y * y = x`, fifteen restate `wvalue`), document and the readers (external
flags), routing (54 of 89 are test vectors), energy and geostats (exact-value
theorems restate; energy states the same exact-soundness fact three times per
sub-family).

**The common gaps**, which the fix list below targets:

- **Declines checked against the code's own decline function.** Most families
  prove `kernel r = Decline (Impossible w) <-> impossible r = Some w` where
  `impossible` *is* the code. Lane G's pattern pairs that with `reason_of_exact`
  against a separately written predicate; most families skipped that half.
- **No cross-kind consistency.** A family that answers both "spring force" and
  "elastic energy" never proves energy = force x extension / 2; one that answers
  "gauge" and "absolute" pressure never proves they differ by one atmosphere. A
  kernel can be internally inconsistent and every theorem still holds.
- **Tables are checked by Python, not by theorems.** `tables_check.py` compares the
  HOL constants to the organ's tables; that is a test, outside the proof.
- **Domain holes.** geostats declines no negative length: `g_kernel (G_cube_volume
  (Some (-2)))` answers -8, and no theorem forbids it. finance's real-rate kernel
  states `i - p` (the Fisher approximation) while `fisher_relation` proves the
  exact Fisher equation about a formula the kernel never computes.

## Method

`var/audit/extract.py` pulls every `theorem`/`lemma`/`corollary` (name, statement,
proof) from the `.thy` files; `var/audit/markers.py` parses each `ROOT`, finds the
PASS marker, checks it is the last command, collects the `@{thm}` scan list, and
greps for oracles; `var/audit/class/<family>.txt` holds one class per statement;
`var/audit/check_class.py` checks every statement is classified exactly once;
`var/audit/aggregate.py` prints the table. (These are lane scratch under `var/`,
not in git; root may move them to `tools/audit/`.) Classes:

| Class | Rule |
|---|---|
| Vacuous (V) | true of any function, a tautology, `x / y * y = x` under an assumed `y ~= 0`, or a fact that mentions no constant of the kernel |
| Definitional (D) | unfolds the definition it is about and closes: `kernel X = Exact k <the code's expression>`, `q = <code expression>`, a decline iff over the code's own decline function, a one-way decline lemma proved by `simp`, a reply lemma that restates `reply_of` |
| Binding (B) | relates the executable function to something it does not literally compute: a law in another form (`y * k = f` where the code computes `f / k`, with the guard derived from the kernel), an error bound against the real-number model, a decline condition written as explicit inequalities, a round trip or composition across two calls, an invariant over all inputs (sorted, in range, distinct), a semantic characterization (first match, shortest path) |
| External (X) | its content depends on a flag the untrusted fetch or recognizer sets (`complete`, `nq_complete`, `ev_complete`, `anchor_present`, `neg`) |
| Example (E) | a ground instance, a test vector, a table well-formedness check on concrete data |
| Helper (A) | proof plumbing: `interpret_floatarith` equations, constructor-distinctness, arithmetic lemmas, list lemmas |

Borderline calls, stated so a reader can re-grade: master soundness theorems such
as lane G's `kernel_exact_sound` count as binding (they carry the decline
exactness against `impossible` via `reason_of_exact`), although their `rl q = phys
r` conjunct is circular for exact kinds; table positivity lemmas (`scale_pos`)
count as binding (a zero entry fails them); the shared rounding theorems count as
binding once per family that re-proves them. Every class file is a plain list and
can be regraded line by line.

## Per-family table

"Binding share of claims" is binding / (all - helper). "In PASS scan" counts the
statements named in the family's oracle scan (what its marker vouches for).
`variants` has no session (it exports `Veri7vn_Quantity`) and no theorems of its own.

| Family | Statements | Vacuous | Definitional | Binding (kernel / model / helper) | External | Example | Helper lemma | Binding share of claims | In PASS scan (of which binding) | Marker and scan |
|---|---|---|---|---|---|---|---|---|---|---|
| acoustics | 38 | 0 | 3 | 25 (5 / 16 / 4) | 0 | 1 | 9 | 86% | 27 (23) | last, all scanned |
| anatomyagri | 56 | 0 | 20 | 31 (21 / 0 / 10) | 0 | 1 | 4 | 60% | 49 (31) | last, all scanned |
| chemistry | 52 | 0 | 8 | 36 (19 / 7 / 10) | 0 | 0 | 8 | 82% | 43 (33) | last, all scanned |
| climate | 85 | 2 | 22 | 46 (22 / 7 / 17) | 0 | 2 | 13 | 64% | 71 (43) | last, all scanned |
| commons | 11 | 0 | 0 | 5 (0 / 0 / 5) | 0 | 0 | 6 | 100% | 11 (5) | last, all scanned |
| computing | 140 | 3 | 20 | 91 (5 / 0 / 86) | 0 | 4 | 22 | 77% | 59 (49) | last; 44 theorems unscanned |
| discrete | 139 | 0 | 11 | 71 (32 / 0 / 39) | 0 | 3 | 54 | 84% | 70 (62) | last; 5 unscanned (one-line `reply_of_*`) |
| document | 58 | 0 | 14 | 15 (11 / 0 / 4) | 4 | 14 | 11 | 32% | 31 (13) | last, all scanned |
| earth | 146 | 0 | 38 | 70 (14 / 35 / 21) | 0 | 2 | 36 | 64% | 87 (55) | last; 7 unscanned |
| emoptics | 91 | 0 | 13 | 47 (30 / 10 / 7) | 0 | 1 | 30 | 77% | 51 (39) | last, all scanned |
| energy | 118 | 0 | 44 | 62 (53 / 0 / 9) | 0 | 0 | 12 | 58% | 89 (59) | last; 3 unscanned |
| facts | 37 | 0 | 1 | 11 (11 / 0 / 0) | 0 | 22 | 3 | 32% | 13 (11) | last, all scanned |
| finance | 77 | 1 | 9 | 43 (19 / 10 / 14) | 0 | 0 | 24 | 81% | 43 (33) | last, all scanned |
| fusion | 74 | 0 | 2 | 23 (20 / 0 / 3) | 0 | 2 | 47 | 85% | 24 (20) | last, all scanned |
| geostats | 110 | 0 | 30 | 45 (33 / 0 / 12) | 0 | 0 | 35 | 60% | 69 (42) | last; 2 unscanned |
| guards | 44 | 0 | 30 | 7 (3 / 0 / 4) | 0 | 3 | 4 | 18% | 38 (7) | **not last**: `Guards_Vectors` builds after the marker with 2 `by eval` |
| humanities | 136 | 0 | 22 | 92 (38 / 4 / 50) | 0 | 3 | 19 | 79% | 110 (85) | last, all scanned |
| life | 116 | 2 | 34 | 54 (29 / 0 / 25) | 0 | 0 | 26 | 60% | 77 (44) | last; 1 unscanned |
| materials | 84 | 0 | 18 | 57 (35 / 2 / 20) | 0 | 0 | 9 | 76% | 62 (45) | last, all scanned |
| mechanics | 86 | 0 | 28 | 42 (27 / 8 / 7) | 0 | 0 | 16 | 60% | 61 (36) | last, all scanned |
| quantity | 60 | 0 | 18 | 32 (24 / 2 / 6) | 0 | 0 | 10 | 64% | 43 (27) | last, all scanned |
| reader | 44 | 0 | 5 | 11 (9 / 0 / 2) | 6 | 9 | 13 | 35% | 0 (0) | **no oracle scan** (bare `writeln`); 18 unscanned |
| rel-novels | 29 | 0 | 5 | 12 (5 / 0 / 7) | 3 | 0 | 9 | 60% | 18 (9) | last, all scanned |
| relations | 36 | 0 | 4 | 13 (5 / 0 / 8) | 5 | 0 | 14 | 59% | 25 (12) | last, all scanned |
| routing | 89 | 0 | 1 | 15 (14 / 0 / 1) | 0 | 54 | 19 | 21% | 21 (12) | last; 1 unscanned |
| space | 93 | 1 | 24 | 53 (16 / 14 / 23) | 0 | 0 | 15 | 68% | 46 (33) | last; 1 unscanned (`kernel_deterministic`) |
| specialists | 44 | 0 | 10 | 18 (14 / 2 / 2) | 0 | 11 | 5 | 46% | 0 (0) | **no oracle scan**; 25 unscanned; 11 `by eval` |
| stores | 55 | 0 | 11 | 23 (12 / 0 / 11) | 6 | 0 | 15 | 58% | 37 (20) | last, all scanned |
| trades | 52 | 0 | 11 | 22 (6 / 5 / 11) | 0 | 1 | 18 | 65% | 24 (16) | last, all scanned |
| wordprob | 34 | 6 | 15 | 7 (1 / 0 / 6) | 2 | 1 | 3 | 23% | 34 (7) | last, all scanned |
| **all** | **2234** | **15** | **471** | **1079** (533 / 122 / 424) | **26** | **134** | **509** | **63%** | **1333 (871)** | 3 sessions unsafe, 109 theorems unscanned |

## What each family should prove next

For each family: the three binding theorems whose absence lets a wrong kernel
through, each with what that wrong kernel could do, a proposed statement over the
family's actual constants (ASCII Isabelle syntax; constants taken from existing
statements, argument shapes copied from them), and the mechanical fixes. Sizes:
S = under a day of one lane, M = a day or two, L = needs a new specification.
Tier is sonnet unless the proof needs search, interval or real-analysis work.
A statement marked *(may be false)* is one the audit expects the current kernel to
fail; the fix lane decides whether the kernel or the statement is wrong and must
keep the family's panel replies unchanged either way. Names not yet in the tree
(`spans`, `wsum`, `exact_eval`, `anchored_claim`, `guard_holds`, `complete_wrt`,
`has_negative_given`, `nominal_of`, `vt1`, ...) are new definitions the fix lane
writes; a name it cannot match in the theory is renamed, not invented around.

### quantity (lane G, the reference) — S, sonnet
1. Energy and force agree. A kernel stating `k * x^2` for elastic energy passes `elastic_energy` if the statement is copied from it.
   `kernel (SpringEnergy (Some k) (Some x)) = Exact c e ==> kernel (SpringForce (Some k) (Some x)) = Exact c' F ==> 2 * e = F * siq x`
2. Absolute is gauge plus one atmosphere.
   `kernel (PressureAbs f (Some h)) = Exact c a ==> kernel (PressureGauge f (Some h)) = Exact c' g ==> a = g + p0`
3. Temperature conversion round-trips (`convert_composes` covers linear units only).
   `kernel (Convert x (Tmp a) (Tmp b)) = Exact k y ==> kernel (Convert y (Tmp b) (Tmp a)) = Exact K_temperature x`

### acoustics — S, sonnet
1. The reply states the model value: today `reply_states_kernel_value` restates `reply_of`; nothing joins the printed decimal to `phys`.
   `answered (reply_of r) ==> EX k d. kernel r = Value k d & stated (reply_of r) = Some (render_dec 4 d) & abs (dec_val d - phys r) <= abs (phys r) / 1000 + 1 / 1000000000`
2. Open and closed pipes are consistent (a kernel swapping the 2L and 4L denominators fails).
   `0 < len L ==> phys (PipeOpen n (Some L) s) = 2 * phys (PipeClosed n (Some L) s)`
3. Adding sources never lowers the level.
   `l : set ls ==> rl l <= phys (DbSum ls)`

### anatomyagri — M, sonnet
1. The germination decline is exact (only the `==>` half exists).
   `kernel (SeedsNeeded gp t) = Decline (Impossible R_germination) <-> ~ (0 < gp & gp <= 100)`
2. The grid count fits the bed (`garden_grid` restates `fit`).
   `kernel (GardenGrid l w s) = Value v ==> 0 < s ==> 0 <= l ==> 0 <= w ==> v * s ^ 2 <= (l * 12) * (w * 12)`
3. The acre-inch literal 27154 is tied to its derivation (`acre_inch` restates the literal).
   `kernel (AcreInch i (Some a)) = Value v ==> 0 <= i * a ==> abs (v - i * a * gal_per_acre_inch) <= i * a / 2`

### chemistry — M, sonnet (start after lane B-chemistry lands)
1. The formula parser returns known elements with positive counts, once each. Nothing constrains `parse_formula`; a parser that drops a subscript after a parenthesis passes every theorem.
   `parse_formula f = FOk cs ==> (ALL p : set cs. find_sym (fst p) ~= None & 0 < snd p) & distinct (map fst cs)`
   (a full reference grammar, `parse_formula f = FOk cs <-> formula_spec f cs`, is L/opus and optional)
2. Dilution never needs more stock than the final volume.
   `ckernel (Dilution a b v2) = CExact k v1 ==> 0 <= v2 ==> v1 <= v2 * 1000`
3. Remaining amount and half-lives agree.
   `dkernel (Remaining h (Some p) (Some (a, u))) = DVal k v ==> dkernel (HalfLives h (Some p)) = DVal k' n ==> nreal v = rl a * decay_real (nreal n)`

### climate — S, sonnet
1. Delete `kernel_deterministic` and `mass_ppm_inverse` (vacuous); lift the carbon round trip from `cc_val` to the kernel.
   `cc_kernel (Cc_c_to_co2 m u) = Exact k q ==> cc_kernel (Cc_co2_to_c q u) = Exact K_co2_to_c m`
2. AQI is monotone in concentration (a mis-ordered breakpoint row fails).
   `sub_index p c1 = Some a1 ==> sub_index p c2 = Some a2 ==> c1 <= c2 ==> a1 <= a2`
3. The albedo decline is exact (only the `==>` half exists).
   `0 <= s ==> cl_kernel (Cl_eff_temp (Some s) (Some a)) = Decline (Impossible R_albedo_range) <-> a < 0 | 1 < a`

### computing — M, sonnet (item 2 opus)
1. Replace `emb_ctc_gives` (vacuous, `x / y * y = x`) with the achieved timer frequency's distance from the target.
   `emb_decline (ECtc fc P ft bits) = None ==> abs (fc / (of_nat P * (1 + emb_value (ECtc fc P ft bits))) - ft) <= fc / (2 * of_nat P) * abs (1 / (1 + ctc_raw fc P ft) - 1 / (2 + ctc_raw fc P ft))`
   (the exact right-hand side is the lane's to choose; it must be a bound a mis-rounded count fails)
2. SQL: a select without grouping returns exactly the rows the WHERE keeps, projected (today only `where_rows` is characterized, not `exec_sq`). L, opus.
   `exec_sq (STable tn to cols rows) (SQ dst its tb (Some c) None [] None) = SRes hdr out ==> set out = (%r. project cols its r) ` set (where_rows cols (Some c) rows)` (constructor and projection names to be fixed against `Sql.thy`)
3. Replace `exec_group_order_is_key_order` (vacuous: it is `isort_sorted` restated and never mentions `exec_sq`) with a statement about the grouped output's key order; put all 44 unscanned theorems in the scan.

### discrete — M, opus (item 1)
1. Minimum spanning tree is minimal (today `a_mst_sound` proves only that the tree's edges are input edges).
   `mst_kernel es = Some t ==> spans t es & (ALL t'. spans t' es --> wsum t <= wsum t')`
2. The base-conversion decline is exact (only `==>` exists).
   `f_kernel (F_base tok src dst cs) = FBaseBad tok' src' <-> digits_val src cs = None`
3. SHA padding keeps the message as a prefix and adds at most one block.
   `take (length m) (sha_pad big m) = m & length (sha_pad big m) <= length m + 72`

### document — M, sonnet
1. `anchor_present` is set by the fetch; make it a HOL function of the fetched claims so no flag can open the explain route.
   `anchor_present p <-> (EX c : set (claims p). anchored_claim c)` with `anchored_claim` defined in HOL from the claim's row fields
2. The answer text quotes the cited sentence.
   `decide t ev = Answer c e ==> EX pre suf. response_of t ev (decide t ev) = pre @ sentence c @ suf`
3. `released ev c` (the weak route's release test) is likewise a fetch flag; define it in HOL from the claim's fields and prove `released ev c <-> release_spec c`.

### earth — S, sonnet
1. Declines per kind are explicit (the four `*_impossible_iff` are over the code's `*_impossible`).
   `(EX w. gl_kernel (GlAge h (MFrac f)) = Decline (Imposs w)) <-> gl_missing (GlAge h (MFrac f)) = None & ~ (0 < f & f <= 1)` (one per impossible reason; the condition must be written out)
2. Great-circle distance is symmetric.
   `geo_kernel (GGc mi p1 l1 p2 l2) = Value x ==> geo_kernel (GGc mi p2 l2 p1 l1) = Value x' ==> xsem x = xsem x'`
3. The reply states the value within the layout error, end to end (combine `w_answered_iff`, `w_value_sound`, `render_x_sound`); add the 7 unscanned theorems to the scan.
   `answered (w_reply r) ==> w_kernel r = Note | (EX x L d. w_kernel r = Value x & abs (dec_val d - w_phys r) <= layout_err L (w_phys r))`

### emoptics — S, sonnet
1. The resistor decline is exact (only `==>` exists).
   `kernel (C_Circ True rall b) = Decline (Impossible R_resistor) <-> list_ex (%r. cv r <= 0) rall`
2. Parallel resistance is below the smallest branch.
   `kernel (C_Circ res rall (CB_Parallel rs)) = Exact k t ==> rs ~= [] ==> list_all (%r. 0 < cv r) rs ==> t <= lmin (map cv rs)`
3. An approximate reply states a decimal within the bound of `phys`, end to end (from `reply_answered_iff`, `kernel_approx_sound`).

### energy — S, sonnet
1. Sensible heat changes sign with the temperature order (`sensible_heat_temps` restates).
   `kernel_t (Thermo [t0, t1] (TSens m cs DT_temps)) = Exact k q ==> kernel_t (Thermo [t1, t0] (TSens m cs DT_temps)) = Exact k (- q)`
2. Tons and BTU/h round-trip (`btuh_law` restates).
   `kernel_v (VTons b) = Exact k q ==> kernel_v (VBtuh q) = Exact k' b`
3. Cost is energy times tariff across the two kinds (`cost_law` restates).
   `kernel_h (HEnergy (Some w) (Some h) (Some rate) True) = Exact k c ==> kernel_h (HEnergy (Some w) (Some h) r False) = Exact k' e ==> c = e * rate`
   Also: keep one of `kernel_X_exact` / `exact_parts_X` / `X_exact_sound` per sub-family (they say the same thing three times) and scan `hvac_sizing`, `pair_difference_nonneg`, `reply_r_pi_enclosed` (the last is `pi_bounds_sound` restated; drop it).

### facts — L, opus
1. The guard matcher `m` is a parameter filled by the untrusted SML regex port, so every theorem is "for whatever the recognizer says matched". Give guards a HOL semantics over the question text and prove the kernel with it.
   `organ_reply narr (guard_holds q) og = Answer k v s n i ==> guard_holds q (guard (store_rules (organ_store og) ! i))` with `guard_holds :: string => guard => bool` defined in HOL
2. The answer sentence carries the stated value.
   `organ_reply narr m og = Answer k v s n i ==> EX pre suf. s = pre + v + suf`
3. Turn `tables_check.py` into a theorem: generate the organ's rules as a second HOL constant from the shipped store and prove `facts_<x>_rules = organ_rows_<x>` for all 21 tables (M, sonnet; the generator stays untrusted, the equality is checked).

### finance — S, sonnet
1. The real rate is the Fisher approximation: say so, with its error (today `fisher_relation` proves the exact Fisher equation about a formula the kernel never computes, so it is vacuous for the kernel).
   `kernel (E_RealRate i p) = Exact k v ==> v = i - p & abs ((1 + v / 100) * (1 + p / 100) - (1 + i / 100)) <= abs (v * p) / 10000`
2. Loan interest agrees with loan payment across kinds (`loan_interest_is_total_minus_principal` restates `pmt`).
   `kernel (F_LoanInterest (Some p) (Some r) (Some y)) = Exact k ti ==> kernel (F_LoanPayment (Some p) (Some r) (Some y)) = Exact k' pay ==> ti = of_nat (months y) * pay - p`
3. Price from markup round-trips with markup.
   `kernel (R_PriceMarkup c m) = Exact k v ==> c ~= 0 ==> qval (R_Markup c v) = m * 100` (scale per `R_Markup`'s definition)

### fusion — L, opus (optional)
1. Error propagation: the answer is within the stated tolerance of the plan evaluated with the kernels' exact values (today each node is bounded; the chain of up to three is not).
   `decide nd ops m mem g c p = Answer (FVal v) pl ==> abs (rl v - exact_eval pl) <= 4 / 10000 * abs (exact_eval pl)`
2. `disagreement_never_picked` for `Anchor` mode, or a stated reason why Anchor may pick (`anchor_three_plans` shows it does).
3. One general node theorem replacing the five per-node ones: every `fnode` value is a kernel's exact value rounded by `phrase` (they exist per node; a new node would currently need its own).

### geostats — M, sonnet
1. Lengths are non-negative. *(may be false)* `cube_volume_value` proves the kernel answers `s * s * s` for every `s`, including negative ones.
   `g_kernel (G_cube_volume (Some s)) = GExact k v ==> 0 <= s` and the same for every length-taking kind, or a decline `GR_negative_length`
2. Modes are complete (only soundness exists).
   `xs ~= [] ==> x : set xs ==> (ALL y. count_list xs y <= count_list xs x) ==> length (smodes xs) ~= length xs ==> x : set (smodes xs)`
3. Exact geometry values as laws, not restatements: e.g. `g_kernel (G_box_volume (Some l) (Some w) (Some h)) = GExact k v ==> g_kernel (G_rect_area (Some l) (Some w)) = GExact k' a ==> v = a * h`; scan `leg_missing`, `circle_missing`.

### guards — M, sonnet
1. Reprove `vectors_pin` and `vectors_count` by `code_simp` (no oracle), move `Guards_Vectors` before `Guards_Export` in `ROOT`, and scan both. This is the only check that the HOL guards behave as Python's on 114 recorded turns.
2. The precision guards are narrowing folds, so lane B's `narrow_never_adds` applies to them.
   `decision S F = Some r ==> status (guard_reply S F) = Withheld` and a `Narrow` encoding with `is_narrow (guard_fold S)`
3. The feature extractors (`f510` ... `f534`, `nums_q`) are SML; at least `nums_q` gets a HOL definition from the question text with `g : set (nums_q F) ==> numeral_occurs g (question F)`.

### humanities — S, sonnet
1. Grammar silence is exact for every flag (only the past participle has `gkernel_silent_unknown`).
   `gkernel r = GSilent ==> g_plural r ==> ~ g_pp r ==> ~ g_past r ==> ALL c : set (g_cands r). map_of plurals c = None`
2. MIDI number and note round-trip at the kernel.
   `mkernel (MMidiNum n (Some oct)) = OMidiNum k ==> mkernel (MMidiNote k) = OMidiNote n' oct' ==> pcn n' = pcn n & oct' = oct`
3. Mythology's two tables agree both ways (`r2g_from_g2r` has one direction).
   `ALL r : set g2r_rows. snd (snd (snd r)) ~= fst r --> (snd (snd (snd r)), fst (snd (snd r)), fst (snd r)) : set r2g_rows`

### life — M, sonnet (item 3 opus)
1. Declines per kind are explicit (`e_impossible`, `f_impossible`, `hw_impossible` are over the code's `*_bad`).
   `(EX w. f_kernel (F_Doyle d l) = Decline (Impossible w)) <-> d <= 4` (one per reason)
2. Tie `doubling_property` and `logistic_starts_at_n0` (vacuous: they never mention the kernel) to `e_phys`.
   `0 < r ==> exp (rl r * e_phys (E_Doubling r)) = 2` and `n ~= 0 ==> k ~= 0 ==> e_phys (E_LogN r n k 0) = rl n`
3. Shannon diversity is between 0 and ln S (Gibbs). L, opus.
   `cs ~= [] ==> list_all (%c. 0 < c) cs ==> 0 <= e_phys (E_Shannon cs) & e_phys (E_Shannon cs) <= ln (real (species cs))`

### materials — S, sonnet
1. Every complete texture gets a class (a gap in the triangle answers nothing silently).
   `fsum t = 100 ==> 0 <= fst t ==> 0 <= fst (snd t) ==> 0 <= snd (snd t) ==> classify t ~= None`
2. Volumetric water is gravimetric times bulk density across kinds (`volumetric_water` restates).
   `kernel (VolWaterContent (Some w) (Some d) (Some bd)) = Exact k v ==> kernel (WaterContent (Some w) (Some d)) = Exact k' g ==> v = g * bd`
3. Mesh vertices and faces invert each other.
   `kernel (MeshVertices f g) = Exact k v ==> kernel (MeshFaces v g) = Exact k' f' ==> f' = f`

### mechanics — S, sonnet
1. Kinetic energy and momentum agree (`kinetic_energy`, `momentum_def` restate).
   `kernel (PhKE (Some m) (Some v)) = Exact c e ==> kernel (PhMomentum (Some m) (Some v)) = Exact c' p ==> 2 * e * m = p ^ 2`
2. Energy is conserved in a drop.
   `0 <= h ==> 0 <= m ==> rl m * phys (PhImpact h) ^ 2 / 2 = rl (m * g0 * h)`
3. Stopping distance is reaction plus braking (`stopping_def` restates).
   `kernel (FvStopping (Some v) (Some mu) (Some rt)) = Exact c s ==> kernel (FvBraking (Some v) (Some mu)) = Exact c' b ==> s = spd v * rt + b`

### readers (relations, rel-novels, src/isabelle/reader) — M, opus
1. Coverage in HOL: `complete c` is a bit the fetch sets. Define completeness against a store snapshot and prove the answer theorems under it, so a fetch that drops rows is caught by the kernel's premise rather than trusted.
   `complete_wrt S c <-> set (rows c) = store_rows S (qid c)` and `decide_spec sp f attempts = Answer x ==> (ALL a c. ... --> complete_wrt S c) ==> unique_in_store S x`
2. Add an oracle scan to `Relation_Reader_Test` (marker today is a bare `writeln`) covering all 18 theorems.
3. The selection rule is stated, not just case-split (`select_cases` restates `select`).
   `select cs = take 1 cs <-> dominated (take 3 cs)` with `dominated` written as its numeric ratio

### routing — S, sonnet (item 3 opus, L)
1. Scan `narrow_never_adds'`.
2. Python order for the whole W540 cascade is pinned by vectors; add `w540_python_order` as a statement against an independent list of the three guards' Python source order (today it unfolds `w540_def`).
3. The full 346-fold catalogue: `ALL f : set catalogue. is_narrow f --> ...` so `narrow_never_adds` covers more than W540 (needs the folds encoded; L, opus).

### space — M, opus (item 3)
1. Delete `kernel_deterministic`. Write the declines out per kind (the `decl_*` and `kernel_*` iffs are over the code's `nosync`, `fake`, `novalue`, `reason_of`).
   `(EX w. kernel (PGravity b) = Decline (Impossible w)) <-> ~ ppos b` (one per reason)
2. Exhaust velocity and thrust-to-weight agree (`exhaust_model` restates).
   `kernel (SExhaust i) = Exact k ve ==> kernel (SMassFlow F fu (Ve ve)) = Exact k' mdot ==> mdot * ve = F * forcef fu` (constructor for a given exhaust velocity per `ve_of`)
3. Hohmann delta-v against vis-viva (today only `hohmann_dv_nonneg`).
   `0 < hr1 ob p ==> 0 < hr2 ob p ==> phys (OHohDv ob p) = abs (vt1 - v1) + abs (v2 - vt2)` with each speed from `hohmann_vis_viva`

### stores — M, sonnet
1. `nq_complete` and `ev_complete` are fetch bits (six theorems lean on them). Compute completeness in HOL from the fetched rows and the question's food/sensor keys.
   `nq_complete e <-> (ALL f : set (near_keys e). row_of (nq_rows e) f ~= None)` (exact rule per the organ)
2. Staleness is monotone in time.
   `stale now fresh ts ==> now <= now' ==> stale now' fresh ts`
3. Mass grams are positive per unit (`grams_per` is a table checked only by Python).
   `0 < grams_per u`

### trades — S, sonnet
1. Paint mixing is symmetric.
   `mix_ryb a b = mix_ryb b a & mix_rgb a b = mix_rgb b a`
2. Complement is an involution.
   `comp_of (comp_of x) = x`
3. Actual lumber is smaller than nominal (`kernel_duo_sound` restates the table).
   `actual a = Some x ==> x < nominal_of a`

### wordprob — S, sonnet
1. Replace the six vacuous `*_value` theorems (`unit_price_value`, `convert_value`, `percent_of_total_value`, `motion_speed_value`, `cone_vol_value`, `sphere_vol_value`) with kernel-level ones whose guard comes from `wdecline`.
   `~ wdecline (UnitPrice p n) ==> n ~= 0` and `answered (reply_of (rnd, [UnitPrice p n])) ==> n ~= 0`
2. The reply's printed number is the value within the rounding bound, end to end.
   `answered (reply_of (rnd, [r])) ==> abs (dec_val d - rl (wvalue r)) <= 1 / (2 * 10 ^ n) + abs (rl (wvalue r)) / 200000` for the `d` it states
3. The negative-given check reads the question, not a recognizer bit (`neg` is a parameter).
   `reply_checked (has_negative_given q) x` with `has_negative_given` defined in HOL over the question text

### specialists (src/isabelle/specialists) — S, sonnet
1. Add an oracle scan to `Specialists_Tests` and reprove its 11 `by eval` lemmas by `code_simp`.
2. Tolerance shortcut: when `agree_shortcut` picks, every non-declined candidate is within tolerance of the pick (`tolerance_not_transitive_shortcut_picks` shows the pick happens; nothing bounds it).
   `agree_shortcut same cs ==> arbitrate same g cs = Pick c ==> ALL d : set cs. ~ declined d --> same_opt same (val c) (val d)`
3. `admit_iff_criteria` restates `admit`; bind it to `exam.py` by checking the gate against every shipped `verdict_heldout.json` (an exported test, not a theorem; say so).

### commons — no gap
Helpers only; its five rounding/enclosure theorems are binding and scanned.

## Appendix A: every vacuous and every external statement

| Family | Vacuous | External (flag it leans on) |
|---|---|---|
| climate | `mass_ppm_inverse`, `kernel_deterministic` | - |
| computing | `emb_ctc_gives`, `cyb_base64_len`, `exec_group_order_is_key_order` | - |
| document | - | `no_answer_unanchored`, `statement_never_unanchored`, `explain_answer_witnessed`, `explain_no_anchor_iff` (`anchor_present`) |
| finance | `fisher_relation` | - |
| life | `doubling_property`, `logistic_starts_at_n0` | - |
| reader | - | `evidence_answer`, `answer_requires_coverage`, `incomplete_refusal_names_a_gap`, `agreeing_candidates_keep_answer`, `more_candidates_never_flip_answer`, `decide_answer_requires_coverage` (`complete`) |
| rel-novels | - | `attempt_values_sound`, `answer_stored`, `decline_stored` (`complete`, `dom_complete`) |
| relations | - | `attempt_values_sound`, `attempt_values_sound_inv`, `answer_stored`, `decline_stored`, `answer_senses_agree` (`complete`, fetched candidate list) |
| space | `kernel_deterministic` | - |
| stores | - | `nutrient_answer_sound`, `nutrient_requires_complete`, `nutrient_incomplete`, `incomplete_fetch_declines`, `sensor_fresh`, `stale_declines` (`nq_complete`, `ev_complete`, fetched timestamps) |
| wordprob | `convert_value`, `unit_price_value`, `percent_of_total_value`, `motion_speed_value`, `cone_vol_value`, `sphere_vol_value` | `negative_given_declines`, `checked_answered_iff` (`neg`) |

## Appendix B: unscanned headline theorems

`theorem`/`corollary` facts that no `@{thm}` scan in their family names (lemmas
used by a scanned theorem are covered transitively and are not listed):

- computing (44): `fixed_str_sound net_of_eq_iff usable_p2p priv_block_range priv_block_complete net_kernel_value net_decline_ip net_decline_prefix net_decline_mask net_prefix_value net_wildcard_value net_usable_value net_same_value net_forhosts_declines_iff net_reply_withheld_names_decline emb_address_value emb_address_bytes_exact emb_reply_answered_iff cyb_digest_hex cyb_birthday_value cyb_keyspace_value cyb_brute_avg_half cyb_underspecified dur_unit_years cyb_reply_answered rob_diff_straight rob_pwm_bound rob_reply_withheld_iff_decline py_module_states_row py_doc_states_row ins_stable_before_equal where_null_never_kept agg_count_star_len agg_max_is_member exec_group_order_is_key_order validity_bad_leading_word validity_yes_reply_answered validity_unknown_withheld sig_name_some umask_values lin_chmod_declines_iff lin_umask_declines_iff lin_exit_value git_all_intents_complete`
- earth (7): `answers_iff_kernel_answers age_ratio_decay_law age_fraction_decay_law harvest_without_efficiency_is_before_losses mw_spec_is_mw_of m0_spec_is_m0_of rnd_even_class_saffir`
- discrete (5): `reply_of_games reply_of_logic reply_of_algos reply_of_calc reply_of_formats`
- energy (3): `hvac_sizing pair_difference_nonneg reply_r_pi_enclosed`
- geostats (2): `leg_missing circle_missing`
- guards (2, `by eval`, after the marker): `vectors_pin vectors_count`
- life (1): `gc_count_le`; space (1): `kernel_deterministic`; routing (1): `narrow_never_adds'`
- reader (18, no scan at all) and specialists (25, no scan at all, 11 `by eval` lemmas)

## Reproduce

```
python3 -B var/audit/extract.py          # 2,234 statements -> var/audit/thms.json
python3 -B var/audit/markers.py          # marker position, scan lists, oracle grep
python3 -B var/audit/check_class.py $(ls var/audit/class | sed 's/.txt//')   # every statement classified once
python3 -B var/audit/aggregate.py        # the table above
python3 -B var/audit/dump.py src/extract/<family>   # one line per statement, to regrade
```
