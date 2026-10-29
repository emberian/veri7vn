# O4 rational formulas: `algebra.simplify_rational`

Lane O4-RATIONAL-FORMULAS, 2026-10-29. No commit. Receipt:
[`native/evidence/2026-10-29-rational-formulas.json`](../../native/evidence/2026-10-29-rational-formulas.json).

**Panel numbers: none.** This lane changes no specialist answer path. The densities table below
checks that the new operation reproduces three shipped answers. It is not a panel score.

## What it does

The `reasoning` provider has a new operation, `algebra.simplify_rational`. It takes:

- a formula in prefix form, with `+ - * /`, exact rational numbers (`3`, `-1/2`) and variables;
- the SI dimension of each variable;
- optional closed bounds on variables (`rho` between 1 and 25000);
- an optional point at which to evaluate.

An e-graph search (egg) looks for a cheaper equivalent formula. We do not trust the search.
egg explains how it got from the original to the candidate. That explanation becomes a
step-by-step certificate, and a separate Rust checker replays every step. If any step fails, the
reply keeps the original formula and gives the reason in `selection_fallback`.

When replay succeeds, this is what it shows: **within the caller's bounds, the selected and
original formulas are defined at exactly the same points and give the same value at each of
them.** Variables with no bound range over all rationals. The identity is checked by replay in
Rust. It is not proved in Isabelle.

The reply also lists each denominator of the original formula as `nonzero_within_bounds`, when
interval arithmetic on the bounds shows it can never be zero, or else `not_established`. With a
point, the evaluator first checks the point against the bounds (`outside_bounds`). Next it
evaluates only the `not_established` denominators, innermost first, and stops at a zero
(`undefined`). Last, it evaluates the selected formula exactly. It never needs to evaluate the
whole original formula.

## Design

The plan from the previous session is kept, with one change of semantics (point 4 below).

1. **Separate operation.** `algebra.optimize_dimensional_polynomial` is unchanged, including its
   reply schema and its rule that a plain `0` can take any dimension. The new code reuses
   `Dimension`, `VariableAnnotation`, `Variable` and the parser size limits.
   `Dimension::product` is now public and `Dimension::quotient` is new. The pre-parse bound check
   (bytes, nesting, token count) moved out of `algebra::parse` into a shared
   `algebra::check_source_bounds`, which both parsers call. The old error names are kept.
2. **Representation** (`src/formula.rs`, which has no egg imports). The formula is a hash-consed
   DAG that only grows. Children always come before parents, so every pass is a loop rather
   than a recursion. Adding a node checks its dimension: addition and subtraction need equal
   dimensions, multiplication and division add or subtract exponents within ±64. Adding a node
   also checks the depth and node caps. Literals have no units. So `(+ x 0)` with `x` in metres
   is refused, and a zero that keeps metres is written `(* 0 x)` (or arises from `(- x x)`). The
   checker parses the request text itself, without recursion. egg's string parser is not used.
3. **Proposer** (`src/formula_search.rs`). egg runs with explanations on, using 17 rules: the
   polynomial ones (`sub-self` gives `(* 0 a)`, so units are kept), the experiment's three
   (`divide-self`, `cancel-right`, `fuse-denominator`), plus `divide-divide`
   (`(a/b)/c = a/(b*c)`) and `add-typed-zero` (`a + 0*b = a`). For each class, an egg analysis
   tracks its dimension, an exact interval, and whether it is defined everywhere in the bounds.
   The analysis gates cancellation, dropping a subterm, and `mul-zero` (which needs a
   dimensionless argument). These gates only steer the search.
4. **Rules are two-sided equivalences on the bounds.** Each checker rule holds wherever both sides
   are defined. Its side condition makes both sides defined at the same points within the bounds.
   So each rule can be used in either direction, which matters because egg's explanations use
   rules backwards. The relation is also symmetric, transitive and a congruence. The conditions are:
   - `divide-self` and `cancel-right` remove a denominator. They require it to be defined everywhere
     in the bounds, with an interval that excludes zero.
   - `mul-zero` and `add-typed-zero` drop a subterm. They require it to be defined everywhere in the
     bounds.
   - The other rules keep the same subterms (`fuse-denominator` keeps `d`; for `divide-divide`,
     `b≠0 and c≠0` is the same as `b*c≠0`). They need no condition.

   So no rewrite can remove a singularity that lies inside the caller's bounds. That is why
   evaluating the selected formula plus the unestablished original denominators is enough.
5. **Certificate and checker.** A certificate is a list of steps: reflexivity, a named rule at the
   root (forward or reverse), congruence from two earlier steps, or transitivity from two earlier
   steps. The checker:
   - matches each rule with its own patterns (shared with egg by name only; a test checks the two
     name lists are equal);
   - checks that each step keeps the dimension;
   - recomputes every condition from the caller's bounds with its own exact interval arithmetic;
   - refuses any term that contains a denominator whose interval on the bounds is exactly zero.

   egg's explanation is converted from its tree form (`TreeTerm`), with shared subtrees
   converted once. A first version used egg's flattened explanation. That took 4.3 s (debug
   build) to flatten 101 steps of the 200-deep test and produced 5150 certificate steps. The tree
   form takes 0.3 s and produces 603 steps.
6. **Budgets.** New `Limits` fields:

   | Field | Default |
   | --- | --- |
   | `rational_bits` | 4096 |
   | `rational_work` | 1,000,000 |
   | `formula_depth` | 64 |
   | `proof_steps` | 20,000 |
   | `formula_reply_bytes` | 65,536 |

   Each overrun is `Error::Limit` with a stable name (`"rational bits"`, `"rational work"`,
   `"formula depth"`, `"proof steps"`, `"formula reply bytes"`, and `"formula nodes"` for the DAG
   cap, which reuses `egraph_nodes`). An overrun inside the proposer, such as a large
   explanation, keeps the original formula with the reason. An overrun while admitting the
   request or evaluating it is an error. The catalog row repeats the budgets as
   `rational_limits`, and the Python adapter reads them from there, as it does for chemistry.
7. **Python adapter** (`tools/oracle_components/reasoning.py`). It has new input and output
   schemas, and it refuses the operation (`native_operation_schema_unsupported`) if the
   `rational_limits` or dimension fields are missing or malformed. It caps the reply at
   `formula_reply_bytes`. It also checks the reply's transport: the output dimension equals any
   requested one, an evaluation is present exactly when a point was given, a value is present
   exactly when the status is `value`, and a fallback keeps the original cost.

## Checks (macOS arm64, rustc 1.98.0-nightly 2026-06-21)

| Command (from `native/` unless noted) | Result |
| --- | --- |
| `cargo fmt -p oracle-reasoning --check` | exit 0 |
| `cargo clippy -p oracle-reasoning --all-targets -- -D warnings` | exit 0 |
| `cargo test -p oracle-reasoning --test formula_contract` | 12 passed, 0 failed |
| `cargo test -p oracle-reasoning --test contracts` (shared parser refactor) | 8 passed, 0 failed |
| `cargo test -p oracle-reasoning --test dimensions_contract` | 14 passed, 0 failed |
| `cargo test -p oracle-reasoning --test stoichiometry_contract` (clippy fix below) | 10 passed, 0 failed |
| `cargo test -p oracle-reasoning --test shortest_path_contract` (`Limits` change) | 7 passed, 0 failed |
| `cargo build -p oracle-runtime-python --features reasoning` | finished; log `var/o4-rational/build.log` |
| `python -B -m unittest test_python_domains.RationalFormulas -v` (in `native/tests`, `PYTHONPATH=var/o4-rational/binding`) | 3 passed |
| `python -I -B -m unittest discover -s tools/oracle_components -p test_reasoning.py` (repo root) | 27 passed |

Notes:

- `native/tests/test_python_domains.py` had no reasoning cases before this lane. The new class
  `RationalFormulas` is the only reasoning case in it, and it was the only class run. The file's
  bio and statistics classes need a build with those features. The class went in just before the
  file's final `if __name__ == "__main__"` guard, so it also runs when the file is run as a script.
- Clippy at first failed on existing code: the `needless_range_loop` lint at
  `src/stoichiometry.rs:341`, which this newer clippy reports. I changed that loop to iterate over
  the two matrix rows with `split_at_mut`. It makes the same budget calls in the same order, and
  `stoichiometry_contract` passes.

What `formula_contract` checks:

- **Forged certificates fail replay**, each one separately: cancellation with no bound,
  cancellation with a bound that admits zero, `divide-self` with no bound, a wrong cancelled
  factor, a broken transitivity chain, `(* m 0) -> 0` with `m` in kilograms (`"step changes
  dimension"`), dropping a partial subterm `(* (/ 1 c) 0) -> 0` with `c` unbounded, a step citing
  itself, a wrong conclusion, and a congruence whose children do not match. The checker also
  accepts the matching good versions (bounded cancellation, `c` in [1,2], the correct congruence,
  reverse use under the bound), so it does not refuse everything.
- **Domain:** `K/m + S/m` becomes `(K+S)/m`. With K=12, S=6, m=2 it evaluates to 9. At m=0 it is
  `undefined`, and the obligation `m` is `not_established`. `(a*b)/b` becomes `a` only when `b` is
  in [1,10]. At b=0 that point is `outside_bounds`. With no bound the formula is not changed.
  `x/x` becomes `1` with x in [1,10], and is kept as is with x in [-1,10].
- **Typed zero:** `(+ y (- x x))` becomes `y` (metres). `(+ x 0)` with `x` in metres is refused.
  `(+ y (* 0 (/ x z)))` with `z` unbounded is kept, because dropping it would hide z=0.
- **Denominator zero everywhere:** `(/ x (* 0 y))` is refused at admission.
- **Several steps:** `(/ (/ a b) c) + (/ (/ d b) c)` becomes `(/ (+ a d) (* b c))` = 5/6, by
  divide-divide twice and fuse once, through congruence and transitivity steps.
  `3·((x+1)y)/(x+1)` with x in [0,5] cancels to a formula without division, which evaluates to 21.
- **Limits:**
  - 200 nested divisions by `(+ x 1)`: with default limits this is `Error::Limit`. With a
    larger token cap it is `"formula depth"`. With depth 1000 allowed it completes, with no
    stack overflow. That run returned a replayed selection, with 603 certificate steps and search
    stopped by its time limit.
  - A 5000-digit literal gives `"rational bits"`. `rational_bits: 8` gives `"rational bits"`.
    `rational_work: 2` gives `"rational work"`. `formula_reply_bytes: 64` gives
    `"formula reply bytes"`. A certificate with 3 steps under `proof_steps: 2` gives
    `"proof steps"`.
  - The literal grammar refuses `01`, `-0` and `1/0`.
- **Hosting:** the request goes through `call()`, the catalog row carries `rational_limits`, and
  the catalog stays under the adapter's 16384-byte limit.

## Consumer check: densities volume formula

The source is `src/extract/quantity/Quantity.thy`:
`qval (VolumeOf m (Some M) u) = siq M / density m / scale u`. The request is `(/ (/ M rho) u)`:

- `M` is mass, bounded to [0, 1e6];
- `rho` is density in kg/m³, bounded to [1, 25000];
- `u` is the target unit's volume in m³, bounded to [1/1e6, 1].

The values are the theory's own table values: mercury 135336/10, silver 10501, concrete 2400,
litre 1/1000, cubic metre 1. The selected formula is `(/ M (* rho u))`: one division instead of
two (tree cost 15 instead of 19), by one `divide-divide` step. Both obligations are
`nonzero_within_bounds`.

The tolerance is relative: |exact − shipped| / exact ≤ 10⁻¹⁵, compared exactly against
`Fraction(shipped)`. For scale, the panel scorer accepts 0.5%.

| Panel question | Exact result | Exact as float | Shipped | Relative difference | Agrees |
| --- | --- | --- | --- | --- | --- |
| 1 kg mercury, in litres | 1250/16917 | 0.07389016965182953 | 0.07389016965182951 | 1.09e-16 | yes |
| 1200 kg silver, in m³ | 1200/10501 | 0.1142748309684792 | 0.1142748309684792 | 9.4e-18 | yes |
| 20 kg concrete, in litres | 25/3 | 8.333333333333334 | 8.333333333333334 | 7.1e-17 | yes |

All 3 agree. For mercury, the shipped float is about one unit in the last place away from the
correctly rounded exact answer. That gap comes from computing the shipped value in floats.

## What was absorbed from `native/experiments/conditional-symbolics`, and what was dropped

The experiment is unchanged; only its ideas were taken.

- **Absorbed:**
  - the hash-consed typed DAG, where a node that adds unlike dimensions cannot be built;
  - typed zero;
  - exact closed-interval premises;
  - its three rules with their nonzero gating;
  - an independent replay with congruence steps, which never trusts an e-class merge;
  - a checked handle tied to the premises it was checked under (`Checked` stores its premises;
    there is no separate snapshot to compare);
  - its mechanics fixture (`K/m + S/m`) and its `(a*b)/b` case, as tests.
- **Improved:**
  - Sign reasoning became exact interval arithmetic, which also handles addition (so `x+1` with
    x in [0,5] is nonzero).
  - The replay judgement became "same domain and same value on the bounds", so rules can be
    used in both directions.
  - Evaluation checks only the denominators that are not established, not the whole original
    formula. This is the "domain-obligation plan" that `native/experiments/REVIEW.md` asked for.
  - Bit, work, depth, proof and reply budgets were added.
  - Recursion was replaced by loops in parsing, the analyses, rendering and certificate
    conversion. (Rule pattern matching still recurses, but only through the fixed patterns,
    which are at most three levels deep.)
  - Transitivity was added.
- **Dropped:**
  - the experiment's `revision`/`source` strings on premises;
  - its sign-only analysis;
  - its single root-rewrite proposer (egg replaces it);
  - its rule of evaluating the original formula in full.

## What remains

- No Isabelle theorem for the checker or its rule table. Each rule's soundness rests on the
  comment next to it in `formula.rs` and on review.
- No transcendental functions, powers, roots or constant folding (`(+ 1 2)` stays as it is; egg
  custom appliers would need their unions explained to be certified).
- Only closed intervals on single variables: no open intervals, disjunctions or relations
  between variables.
- Interval reasoning is conservative. Dependent terms such as `(- x x)` widen, so some
  denominators that are never zero are reported `not_established`. "Zero everywhere" is detected
  only when the interval is exactly {0}, not by deciding polynomial identity.
- Search ceilings are cooperative. One run took 105 ms against a 50 ms limit.
- The tree cost is an abstract count, not a measured speed.
- The consumer check covers 3 items and is not wired into the densities specialist. No panel
  number exists.
- The Linux receipt is root's. The extension was built in a shared tree that held other lanes'
  uncommitted edits to `oracle-core` and `oracle-python`.

## Questions for the reviewer

1. **Semantics.** I chose "same domain and same values on the bounds" over "wherever the
   original is defined, the selected formula agrees" (refinement). Refinement would let
   `(a*b)/b -> a` happen without any bound, relying on the evaluation-time check of `b`. My choice
   keeps the brief's rule that cancellation needs a bound, and makes every rule usable in both
   directions. Is the stricter reading the one we want to host?
2. **Fallback.** A failed replay of an egg proposal keeps the original formula, with a visible
   reason, rather than refusing the request. The dimensional operation, by contrast, never falls
   back on a failed identity check. Should a replay failure here be an error, so checker/proposer
   disagreements surface loudly?
3. **Dropping subterms.** `mul-zero` and `add-typed-zero` may drop a subterm only when it is defined
   everywhere in the bounds. That is stricter than the brief, which gated `mul-zero` only on
   units. Agreed?
4. **Literals.** `(+ x 0)` with units is refused (no polymorphic numerical zero), unlike the
   dimensional polynomial operation. Is that difference acceptable to consumers, or should the
   adapter's description say so more prominently?
5. **Stoichiometry lint fix.** The `split_at_mut` rewrite in `stoichiometry.rs` was needed for the
   crate's clippy gate. Please confirm that the owner of that file is content.

## Files

Changed:

- `native/oracle-reasoning/src/lib.rs`
- `native/oracle-reasoning/src/algebra.rs`
- `native/oracle-reasoning/src/dimensions.rs`
- `native/oracle-reasoning/src/stoichiometry.rs`
- `tools/oracle_components/reasoning.py`
- `native/tests/test_python_domains.py`
- `native/docs/CAPABILITIES.md`

New:

- `native/oracle-reasoning/src/formula.rs`
- `native/oracle-reasoning/src/formula_search.rs`
- `native/oracle-reasoning/tests/formula_contract.rs`
- `native/evidence/2026-10-29-rational-formulas.json`
- `project/lanes/O4-RATIONAL-FORMULAS-2026-10-29.md`

Scratch is in `var/o4-rational/`: logs, `binding/oracle_native.so`, `consumer.json`, and
`scripts/consumer.py`.
