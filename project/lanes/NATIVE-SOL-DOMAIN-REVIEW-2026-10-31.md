# Sol consumer domain review — 31 October 2026

Independent source review by Astra domain lane. **No new specialist-panel
numbers. No builds or tests run by this lane.** Authored panels and assertions
below are proposed checks, not execution receipts. Central measurement and
validation own execution. Final source pass includes the host replay repair
described below; its authored regression still requires central execution.

## Finding repaired during review

**P2 — DNA page replay bypasses the shared execution budget and repeats whole
record normalization per hit.** In `native/oracle-host/src/pure.rs`,
`check_collection` receives no `WorkControl`. Inside its hit loop it calls
`to_ascii_uppercase()` on the entire original record. An admitted page containing
1024 one-base hits in one 131072-base record therefore does about 134 MiB of
repeated case traversal/allocation after the bounded native search. Neither that
work nor the loop observes cancellation or shared fuel. The native trie traversal
does charge each transition; this host replay undoes that compositional property.

Pass the invocation context into replay, charge the actual bounded work, and
compare only the hit slice (or normalize each referenced record once). Keep the
hash over original supplied bytes, including case and ordered duplicate labels.
The decisive focused regression is an admitted repeat-rich large record with a
full page, checked under an exhausted/cancelled invocation context; replay must
stop rather than return an answered page. Root and surface owner were notified.

**Final source pass: resolved.** `check_collection` now receives the shared
`WorkControl`, charges source bytes before hashing and bounded pattern/hit work
before each replay, and compares a borrowed original source slice with
`eq_ignore_ascii_case`. Original-byte hashing is unchanged. Budget/cancellation
failure returns an explicit withheld reply, not an answered page. The authored
`dna_page_replay_charges_source_once_and_each_short_hit` regression uses a real
131072-byte lowercase record and 1024 one-base hits, checks 136228 charged units,
and checks failure/withholding with 135000 available units. This review inspected
the actual repaired source and test; it did not execute them.

## Domain conclusions from the actual source

### Calibration

`native/oracle-statistics/src/calibration.rs` delegates to the existing bounded
SVD regression and preserves the requested direction. Inverse point mode computes
`(supplied_response - intercept) / slope`; it does not fit x on y. It refuses
inverse intervals, unidentified/ill-conditioned designs and slopes at the stated
roundoff threshold. Forward observation intervals require explicit relative
precision. HC3 fits the mean but explicitly withholds the new-observation
interval; it does not invent a noise model. The range flag is a diagnostic, not
an extrapolation guarantee. Unit strings and assumptions remain caller claims.

The host and Python adapter retain null intervals and reasons without confusing
a returned point with supplied uncertainty. Completely unavailable values are
withheld. Their checks are structural admission around trusted handwritten
numerical code, not an independent proof of regression correctness.

The numerical panel has independent analytic content: for x=(-1,0,1),
y=(0,-1,4), the line is 1+2x, SSE=6 and residual df=1. Its Cauchy critical-value
formula gives mean variance 2 and observation variance 8. It distinguishes
algebraic inverse 2 from reverse-regression 8/7 and exercises degeneracy, range,
weights and missing uncertainty. Policy cases such as perfect-fit interval
withholding test the documented policy, not statistical coverage.

`tools/usage/calibration.py` invokes the selected existing GeoStats executable,
keeps the kernel questions/raw replies, and labels all displayed coefficients and
predictions `rounded_*`. The inherited exact theorem states that a returned
rational line has zero residual and x-weighted residual sums and minimizes SSE
among rational intercept/slope lines on the supplied rows. It proves no sampling
or uncertainty model and does not verify this Python transport or binary choice.
The three extracted panel cases are rounded comparisons, not a new exact API.

### Thermal scenarios

`native/oracle-science/src/thermal_scenarios.rs` prepares one serial dense SVD
and reuses its factors. Scenario vectors cover all original nodes and preserve
boundary membership. Conductance derivatives solve the differentiated equation:
the selected edge adds `-(T_i-T_j)` at i and its opposite at j to the free-node
forcing. Load derivatives add one at the selected free node; an ideal-reservoir
load changes exchange rather than temperatures. Fixed-temperature derivatives
remain zero. Acceptance recomputes differentiated original-node balances.

Each scenario still passes through `thermal_with_solver`, retaining original
node power evidence and below-zero/rank/refusal outcomes. The prepared solver
revalidates stricter caller limits before factor reuse. Aggregate scenario work,
shared cooperative charges and explicit conservative memory reservations are
present; these do not promise allocator/RSS accounting or interruptible SVD.
The identity includes the complete serialized base network and numerical policy,
not merely topology. The scenario solve counters exclude the preparation solve.

The Python workflow separately reconstructs original-edge flows and derivative
balances. Literal panel temperatures/derivatives follow one-link/series formulas,
including reservoir-load and cooling cases; finite-difference tests supplement
those analytic checks. They are independent of calling the same matrix solver
twice, although the balance equations necessarily implement the same model.
No output establishes real-world physics, worst-case uncertainty or inverse design.

### Sequence collections

`native/oracle-bio/src/collection.rs` retains immutable normalized records and
provides a reusable prepared trie. Separate starts within each record prevent
cross-record matches. Reverse-complement patterns are searched against original
forward records, so returned zero-based half-open intervals need no reverse
coordinate conversion. Palindromes yield one `both` hit. Duplicate labels and
patterns retain input indices; identity includes ordered original bytes.

Pages resume at record/start/within-start hit offset. Replaying the current
position at a page boundary is intentional. `complete` means the requested
suffix is exhausted; arbitrary caller cursors do not establish full collection
coverage. The client starts without a cursor, checks source identity and strict
hit order, consumes all pages, and refuses completeness on its caps. Positive
hits receive independent slice replay; omission/completeness still trusts native
traversal unless the optional bounded naive reference is used. The authored
literal-coordinate panel covers overlaps, reverse hits, palindromes, duplicate
labels/patterns, empty records, exact page boundaries and cross-record absence.
These are supplied DNA claims, not biological interpretation or world coverage.

### Exact feasibility and chemistry

`native/oracle-reasoning/src/exact_lp.rs` means unrestricted variables and
original inequalities Ax<=b. Its Fourier–Motzkin proposal preserves nonnegative
original-row multipliers. Reconstruction goes backwards through elimination
history and replays the resulting point against original rows. The separate
checker accepts infeasibility only for y>=0, A^T y=0, b^T y<0. For minimization,
optimality requires primal feasibility, A^T y=-c and c^T x=-b^T y; unboundedness
requires a feasible base, Ad<=0 and c^T d<0. These sign conventions are mutually
consistent. The proposer only searches feasibility even when objective data is
present. Resource exhaustion is unknown/refusal, never infeasibility.

The new multi-nullity chemistry branch constructs paired equality inequalities
from original supplied inventories/charge and adds x>=1. This is equivalent to
strict positive homogeneous balance by scaling. It does not trust a computed
nullspace as the source for its new negative certificate. Positive rational
witnesses are denominator-cleared/GCD-normalized and independently replayed over
the inventories. This establishes neither chemical possibility nor a minimum
integer coefficient sum. Existing nullity-zero/one branches continue to use
their exact elimination decisions.

The host replays non-null exact certificates with the shared context. The blend
consumer independently replays primal/Farkas witnesses with Python fractions on
the normalized stock/total/solute constraints. Its four literal cases exercise
stock and composition obstructions and exact fractional boundaries. It correctly
refuses to interpret feasibility as optimization or physical blend safety.
Authored Rust tests include interval truth, zero-row contradictions, changed
original rows and invalid rays. No Isabelle claim was added.

## Scope and remaining evidence

Read the Sol brief, relevant statistics/science/bio/symbolic scouts, new native
implementations and focused tests, host dispatch/interpretation, Python adapters,
workflow clients and authored panel scorers. No source edits outside this report,
no builds/tests, no upstream writes, no commits and no agents spawned.

After the host DNA replay budget repair, this pass has no remaining blocking
source finding and found no demonstrated false-answer defect in the four new
domain algorithms. Runtime integration,
schema regeneration, actual extracted comparison, authored panel execution and
the shipped specialists' own six-criterion scores remain central-executor work.
Passing new fixtures cannot stand in for those shipped panel numbers.
