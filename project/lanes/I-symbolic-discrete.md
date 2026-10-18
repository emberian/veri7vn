# Discrete I: derivatives along a named coordinate

Ready and frozen for integration after H commit `938de65`. The scoped proof,
actual native compiler closure, semantic checks and dispatcher pass. Linux capture
for this exact candidate is pending. Drain mode: no successor work is starting.

## Behavior and mathematical interpretation

A polynomial in `x` has zero positive-order derivative with respect to independent
`y`. The previous recognizer withheld that meaningful request. Worse,
`Find the derivative of f(y)=x^2` returned `2x`, discarding the function's declared
argument `y` and differentiating in `x` instead.

New typed requests retain both names, the original polynomial and the order. The
model varies one coordinate in an environment while holding the others fixed.
Thus `f(y)=x^2` treats `x` as a fixed free parameter. Explicit dependencies such as
`x(y)`, competing differentiation declarations and compound requests remain
unsupported. This free-coordinate interpretation is stated as an assumption;
English recognition is not proved.

Complete coordinate commands are parsed before admission: an operation/order,
one entire polynomial or function declaration, a target variable, and optionally
an evaluation point in that target variable. Extra modifiers or operations do not
silently disappear. Ambiguous scientific-number spellings such as `1e-3` also
refuse rather than being interpreted as a polynomial in `e`. An omitted target can come from `f(y)=...`; multiple competing
names do not select a convenient suffix. Positive derivative orders remain 1–50.
General multivariate expressions and multivariate antiderivatives are not included.

## Checked statements

`coordinate_partial p source target n` is `pder_n n p` when names match or
`n=0`, and the zero polynomial otherwise. At order zero, existing `norm_pev`
identifies its evaluation with the original polynomial's evaluation.

The new successive derivative theorem is genuinely over real functions:

```
((λt. pev (coordinate_partial p source target k)
          ((env(target := t)) source)) has_field_derivative
  pev (coordinate_partial p source target (Suc k))
      ((env(target := z)) source)) (at z)
```

Actual expression-request binding:

```
c_kernel (C_partial p source target (Suc k)) = CDer n q ⟹
  n = Suc k ∧ q = coordinate_partial p source target (Suc k) ∧
  ((λt. pev (coordinate_partial p source target k)
            ((env(target := t)) source)) has_field_derivative
    pev q ((env(target := z)) source)) (at z)
```

Actual evaluated-request binding:

```
c_kernel (C_partial_at p source target (Suc k) point) =
  CAt n q value point' tangent ⟹
  n = Suc k ∧ point' = point ∧ ¬ tangent ∧
  q = coordinate_partial p source target (Suc k) ∧
  ((λt. pev (coordinate_partial p source target k)
            ((env(target := t)) source)) has_field_derivative
    of_rat value) (at (of_rat point))
```

The existing derivative library suffices; no cold HOL-Analysis dependency or
analytic integral claim is involved. The public consumer is `calculus` through
the native family and dispatcher. Capability metadata is a declaration, not a
per-answer certificate.

## Evidence

`coordinate_probes.py` computes exact expected coefficients with falling
factorials and uses the supplied calculus scorer to read answer polynomials.
Evaluated replies must also contain the exact expected fraction in their text.
Both identical and different source/target variables, orders, rational
coefficients and rational evaluation points are varied. Language is authored
with this implementation, not independent-language evidence.

Baseline H native on development seed 181501: **150/238 policy/value assertions**.
Of 235 meaningful requests: **138 correct, 37 wrong, 60 withheld-valid**.
Three ambiguous/undefined requests were all refused.
`var/discrete/i/before-final.json`. Negative/zero derivative orders and competing
variable declarations are conservatively counted as meaningful withheld requests,
not as invalid merely because this interpreter does not support them.

- Passed proof `var/discrete/remote-attempts/20261018T102057Z-de48f072c2d2/receipt.json`:
  actual `Finished Veri7vn_Discrete (0:01:25 elapsed time)`;
  `VERI7VN_DISCRETE PASS theorems=95 oracles=0`. First attempt passed.
  Export SHA-256 `0d3a14506b9a4cacaa932b8c99eaab0129e6f000d35662e6640c9f0c3aceeb25`.
- Shared-helper compiler manifest:
  `var/discrete/native-attempts/20261018T102905Z-e99e4b159c23/compile-inputs.json`.
  Immutable sibling `binary` and published native SHA-256:
  `3c68959984b5d4dc07faf43c47b5ed0bbc064c0c356c5231cd555cbe052a7a13`.
  `var/discrete/i/native-closure.json` verifies 5 frozen compiler inputs and
  12 proof dependencies against current source; no differences or errors.
- Development seed 181501: **238/238 policy/value assertions**;
  **219 answered-correct, 0 wrong, 16 withheld-valid**, plus **3 ambiguous or
  undefined requests all refused**. `var/discrete/i/after.json`.
- Actual dispatcher pinned and unpinned: **238/238 each**, same semantic outcomes
  and every expected refusal decisive. Scope `--order front --organs discrete
  --no-reader --no-document --no-routes`. `dispatch-pinned.json` and
  `dispatch-unpinned.json` under `var/discrete/i/`.
- Untouched post-freeze seed 181547: **238/238**, same outcome counts.
  `var/discrete/i/heldout.json`. Fresh arithmetic variation is not independent
  language evidence.
- Supplied own scorers: **508/508 in each specialist/family mode**, **0 wrong,
  0 false yes, 0 withheld-valid**. Calculus 62 dev + 62 heldout; games 51+18,
  logic 33+12, formats 93+93, algorithms 42+42. These own-scorer totals include
  expected refusals. `var/discrete/i/shipped.json` and `.log`.
- Existing authored ordinal checks **168/168**, legacy calculus policy/value
  checks **24/24** after updating the now-supported distinct-coordinate request.
  These are regression assertions, not additional capability counts.
  `var/discrete/i/ordinals.json`, `legacy-probes.json`.
- Native 942,904 bytes; authored median kernel time 0.1035 ms; five measured warm
  launches 4.01, 3.48, 3.32, 3.26, 3.04 ms. No uncached-start claim.
  `var/discrete/i/performance.json`.
- Capability validation and scoped `git diff --check` pass.

The supplied snapshot has no calculus generator. Fresh authored arithmetic
variation must not be reported as an independently supplied generator.

## Changed paths

`src/extract/discrete/Disc_Calc.thy`, `Discrete_Export.thy`, `recognizer.sml`,
`main.sml`, `capabilities.json`, `coordinate_probes.py`, `probes.py`, `README.md`,
and this report. The existing authored `probes.py` expectation for `x^2` with
respect to `y` changes from refusal to zero. Shipped scorers remain untouched.

## Per-specialist review boundary

| Exact specialist ID | This packet's examination and remaining limit |
|---|---|
| `calculus` | Coordinate identity, fixed free variables, function argument declarations, exact polynomial derivative/evaluated values. General multivariate algebra, dependency/chain-rule grammar and the parked analytic integral bridge remain open. |
| `logic-v3` | H whole-formula semantics and 12-variable kernel guard retained; no new logic claim. |
| `algorithms` | G rational graph/list behavior retained; algorithm/certificate completeness remains open. |
| `dataformats` | F raw-byte formats and signed complete-token conversions retained; no new formats claim. |
| `games-v3` | E finite dice/card semantics retained; no new games claim. |
