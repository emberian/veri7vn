# A computer algebra system where every stated answer is proved

Lane D1, 2026-10-18. This is a design, not a build. Nothing here has been
compiled. Statements about Isabelle and AFP are from reading their sources:
the Isabelle2026-RC1 distribution under `/Applications/Isabelle2026-RC1.app/src`
and the AFP snapshot at `~/isabelle/afp-2026-05-29/thys` (dated May 2026; not
registered with RC1, so compatibility with RC1 is not yet checked).

## In plain words

The goal, in ember's words, is "Mathematica, except everything is actually
correct". The design below says this is reachable for a large, useful core,
and reachable in the way veri7vn already works:

1. **Anyone may guess; only a proof may answer.** Finding an antiderivative,
   a factorization or the roots of an equation is hard and full of heuristics.
   Checking a proposed answer is usually much easier. So the search is done by
   an untrusted program (SymPy today; Mathematica, Maxima or FriCAS would do as
   well), and the answer is shown only if a checker written and proved in
   Isabelle accepts it. If the checker does not accept it, the system says it
   cannot verify the answer. This is the pattern the discrete family already
   uses for minimum spanning trees (`mst_cert_minimal` in
   `src/extract/discrete/Disc_Algos.thy`): Kruskal's algorithm is not proved,
   the certificate check is, and a failed check withholds.
2. **Exact by default.** Numbers are exact rationals, exact algebraic numbers
   (such as the square root of 2, kept as "the positive root of x^2 - 2"), or
   symbols. Decimals appear only when asked for, and then as an interval that
   is proved to contain the true value, exactly as the finance and quantity
   kernels already do.
3. **A refusal is a statement, not a shrug.** Every withheld answer carries a
   reason, and for some of them the reason is itself proved ("the integrand is
   undefined at x = 0, which lies inside the interval you asked about").
4. **Same delivery as the rest of veri7vn.** The proved checker is exported
   from Isabelle to Standard ML and compiled with MLton into a small binary. No
   Isabelle runs when a question is answered.
5. **Scored against someone else's tests.** SymPy ships its own test suite: in
   version 1.14.0 there are about 330 integration tests with ordinary
   (elementary) functions alone. Those tests, and later the Rubi integration
   suite and Mathematica's documented examples, are the panels. The law stays
   **0 wrong**. What moves is how many of them we answer.

What the design cannot do is also plain. It cannot prove that an integral has
*no* closed form. It cannot make "simplify" mean "the simplest form", because
there is no agreed meaning of simplest. It decides "are these two formulas
equal?" only for families of formulas where that question has a decision
procedure, and withholds elsewhere. It will lag Mathematica in breadth for a
long time, especially in special functions, and that is acceptable: a smaller
system that is never wrong is a different product, not a worse copy.

**Root's sketch holds, with three corrections.** (a) For several capabilities
Isabelle and the AFP already have *verified algorithms*, not just checkers
(polynomial factorization over the integers and rationals, real roots of
polynomials, determinants and inverses, linear programming); there the
untrusted finder is unnecessary and the checker pattern is the wrong tool.
(b) The hard part of a checker is usually not the certificate but deciding
whether two expressions are equal. For integrals this is the whole problem,
and the design has to say which equalities it can decide (section 2.0).
(c) A checker proves a statement about a *domain*: "F is an antiderivative of
f where both are defined". The answer has to carry that domain or it is a
true theorem about a different question.

## 0. How the oracle organ already does this, and why it is not enough

Oracle7 has a SymPy-backed math organ (`upstream/root/wander-train/math_organ_v3.py`,
read-only) that already follows "find, then check independently". Its own
docstring lists the checks:

| Directive | Oracle7's check |
|---|---|
| solve | every solution substituted back satisfies every equation |
| factor | the product expands back to the input |
| simplify | equal to the input at 5 random rational points (`equiv`, tolerance 1e-7) |
| differentiate | agrees with a central difference at 3 random points (tolerance 1e-4) |
| integrate | the antiderivative differentiates back (via `equiv`); a definite value agrees with numeric quadrature |
| limit | agrees with evaluating the expression at the point plus 1e-7 |

The shape is right; the checks are floating-point samples. A sample can pass
on a wrong answer (`sin(1/x)` near 0 for limits; any two functions that agree
at five points), and `equiv` first calls `sp.simplify(a - b) == 0`, which
trusts SymPy's simplifier. "Solve" checks that the stated solutions are
solutions, not that they are *all* the solutions. The verified version keeps
the directive list and replaces each check by a proved one. The deployed head
route (`src/extract/mathorgan/`, scout report in
`var/scout-wt/math-organ/SCOUT_REPORT.md`) covers percent, unit conversion,
integer square root, gcd/lcm and one linear equation; the `calculus`
specialist (polynomial derivatives and integrals) is already verified inside
the discrete family (`Disc_Calc.thy`, 62/0 on its held-out panel).

## 1. What exists in Isabelle today, and whether it exports

"Exports" below means: the functions have code equations, so `export_code
... in SML` can produce Standard ML that MLton compiles. "Verified" means
there is a theorem about the executable function's output, not just about a
mathematical definition. "In use here" means a veri7vn session already
imports it.

### 1.1 Distribution sessions (Isabelle2026-RC1)

| Session / theory | What it gives | Proved | Exports |
|---|---|---|---|
| `HOL-Computational_Algebra.Polynomial` | univariate `'a poly` with coefficient lists as the code representation (`code abstype`, `coeffs`), arithmetic, division, `pderiv` with fast code (`pderiv_coeffs_code`) | the algebra laws | yes |
| `HOL-Computational_Algebra.Polynomial_Factorial` | gcd and lcm of polynomials over fields and over factorial rings (`gcd_poly_code [code]`) | `gcd` is the gcd | yes |
| `HOL-Computational_Algebra.Euclidean_Algorithm`, `Primes`, `Squarefree`, `Normalized_Fraction` | extended Euclid (`bezout_coefficients`), primality by trial division, normalized fractions | yes | yes |
| `HOL-Computational_Algebra.Formal_Power_Series`, `Formal_Laurent_Series`, `Fundamental_Theorem_Algebra` | formal power series as functions `nat ⇒ 'a` | rich theory | **no** code equations (0 `[code]` annotations); usable only in proofs |
| `HOL-Decision_Procs.Approximation` (in use: finance, quantity, life) | the `floatarith` expression language (`Add, Minus, Mult, Inverse, Cos, Arctan, Abs, Max, Min, Pi, Sqrt, Exp, Powr, Ln, Power, Floor, Var, Num`) with real semantics `interpret_floatarith`; interval evaluation `approx` with soundness `approx`; bounded-variable formulas `approx_form` (bisection over `Bound x a b`), Taylor-series refinement `approx_tse`, `approx_tse_form` | soundness of every enclosure | yes; this is how the finance enclosures are built |
| same theory | **symbolic differentiation**: `DERIV_floatarith n f` with `isDERIV n f vs` side conditions, theorem `DERIV_floatarith`: under `isDERIV`, `DERIV (λx'. interpret_floatarith f (vs[n := x'])) x :> interpret_floatarith (DERIV_floatarith n f) (vs[n := x])` | yes | yes. This is the template for our own differentiation theorem |
| `HOL-Decision_Procs.Commutative_Ring` + `Commutative_Ring_Complete` | reflected polynomial expressions `pol`, normaliser `norm`; `norm_ci`: the normal form has the same value; `Commutative_Ring_Complete`: the normal form is canonical | yes (soundness and canonicity) | the functions are plain HOL functions and should export; not yet tried |
| `HOL-Decision_Procs.Reflective_Field` | field-expression normalisation with the nonzero side conditions it needs | yes | as above |
| `HOL-Decision_Procs.Cooper`, `Ferrack`, `MIR` | quantifier elimination: Presburger arithmetic (`pa`, theorem `mirqe`: `Ifm bbs bs (pa p) = Ifm bbs bs p ∧ qfree (pa p)`), linear real arithmetic (`linrqe`), mixed integer/real | yes | yes (they run through reflection; the code is plain HOL) |
| `HOL-Library.Sum_of_Squares` | Positivstellensatz/SOS as a *tactic* that calls an external SDP solver and replays the certificate in the kernel | the replay | **no**: ML proof procedure. The certificate *idea* transfers (section 2.10) |
| `HOL-Real_Asymp` | limits and asymptotics of real functions by multiseries | yes, inside proofs | **no**: ML proof method, nothing to export |
| `HOL-Analysis` (`Derivative`, `Henstock_Kurzweil_Integration`, `Interval_Integral`, `Equivalence_Lebesgue_Henstock_Integration`, `Gamma_Function`) | derivatives (`has_real_derivative`, `has_field_derivative`), integrals (`has_integral`, `integral`), the fundamental theorem (`fundamental_theorem_of_calculus`: if `a ≤ b` and f has derivative f' on [a, b] then `(f' has_integral (f b - f a)) {a..b}`; `fundamental_theorem_of_calculus_interior` needs only continuity on [a, b] and the derivative inside), Gamma | yes | **no code**, and none is wanted: these are the *specification* our checkers prove against. Only `Euclidean_Space` carries code annotations |
| `HOL-Library.Landau_Symbols` | big-O and little-o | yes | specification only; for series remainders |
| `HOL-Library.Code_Real_Approx_By_Float` | maps `real` to machine floats | **unsound by design** | must never be imported by a kernel |

### 1.2 AFP entries (snapshot of 2026-05-29)

veri7vn uses no AFP entry today; adopting one is a new build dependency on the
remote hosts (open question 1 in the lane file). "Export" below is judged from
code annotations and `value`/`export_code` uses in the sources; none was run.

| Entry | What it gives | Headline theorem (verbatim or close) | Export |
|---|---|---|---|
| **Berlekamp_Zassenhaus** (Divasón, Joosten, Thiemann, Yamada) | complete factorization of integer and rational polynomials into irreducibles | `factorize_int_poly`: `factorize_int_poly_generic f = (c,fs) ⟹ square_free_factorization f (c,fs)`, each factor `irreducible` and of nonzero degree; `factorize_rat_poly` likewise | yes; `Factorization_External_Interface` gives `factor_int_poly :: integer list ⇒ integer × (integer list × integer) list` with its soundness lemma. Uses record-based finite-field arithmetic and `Code_Abort_Gcd` |
| **Polynomial_Factorization** | Kronecker factorization, square-free factorization, rational root test, Gauss's lemma | yes | yes |
| **LLL_Factorization** | polynomial-time factorization via lattice reduction | yes | yes (`export_code ... in Haskell` in the entry; SML should work) |
| **Algebraic_Numbers** (Thiemann, Yamada) | exact real and complex algebraic numbers (`real_alg`), arithmetic, comparison, `floor`, n-th roots, printing; **all real roots of a rational polynomial** | `real_roots_of_rat_poly`: `p ≠ 0 ⟹ set (real_roots_of_rat_poly p) = {x. rpoly p x = 0}`; `complex_roots_of_int_poly_all` with a square-free premise for degree ≥ 3 | yes; `Algebraic_Numbers_External_Code` exports to Haskell. Caution: it installs `code_datatype real_of` for `real`, which would clash with any session that relies on HOL's default `Ratreal` code for `real`. Our kernels compute on `rat`/`float` and use `real` only in proofs, so a CAS session would use `real_alg` directly |
| **Factor_Algebraic_Polynomial** | factoring polynomials whose coefficients are algebraic numbers | yes | yes (code annotations) |
| **Sturm_Sequences** (Eberl) | count real roots of a polynomial in an interval | `count_roots_correct`, `count_roots_between_correct`; fast `[code]` equations (`count_roots_code`) | yes |
| **Sturm_Tarski**, **BenOr_Kozen_Reif** | Tarski queries, univariate sign determination | yes | yes (code annotations; not exercised) |
| **Count_Complex_Roots** | count complex roots in a rectangle or half-plane | yes | yes |
| **Cubic_Quartic_Equations** | Cardano and Ferrari | yes | not checked |
| **Virtual_Substitution** | verified real quantifier elimination for low-degree formulas | soundness of the QE | yes (two theories export) |
| **Jordan_Normal_Form** (Thiemann, Yamada) | matrices `'a mat` with code (`Matrix_Impl`), determinant (`det_code`), Gauss–Jordan (`gauss_jordan_single`: same solutions, row echelon form), inverse (`mat_inverse`: `None ⟹ A` not invertible; `Some B ⟹ A * B = 1 ∧ B * A = 1`), characteristic polynomial, Jordan normal form | yes | yes |
| **Gauss_Jordan**, **Echelon_Form**, **QR_Decomposition** (Aransay, Divasón) | rank, inverse, determinant, least squares via immutable arrays | yes | yes, with explicit `export_code ... in SML` (`Code_Generation_IArrays_SML.thy`) |
| **Simplex** (Spasić, Marić, Thiemann, Bottesch) | incremental simplex for linear rational constraints | `simplex cs = Sat v ⟹ ⟨v⟩ ⊨cs set cs`; `Unsat I ⟹` no solution, and `I` is a minimal unsatisfiable core | yes |
| **Farkas**, **Linear_Inequalities** | Farkas' lemma, certificates of infeasibility | yes | partly |
| **Groebner_Bases**, **Groebner_Macaulay**, **Signature_Groebner** (Maletzky, Immler) | Buchberger and F4 over multivariate polynomials (`Polynomials` entry: `MPoly`, `Poly_Mapping` with code) | the result generates the same ideal and is a Gröbner basis | yes (examples run by `value`) |
| **Polynomials**, **Subresultants**, **Polynomial_Interpolation** | multivariate polynomials with code; subresultant gcd; Lagrange/Newton/Neville interpolation | yes | yes |
| **Linear_Recurrences** (Eberl) | closed forms of linear recurrences with constant coefficients; rational formal power series; **partial fraction decomposition** (`partial_fraction_decomposition`, `decompose_code [code]`) | `solve_lhr`: `linear_homogenous_recurrence f cs fs ⟹ Some sol = solve_lhr cs fs ⟹ f = interp_ratfps_solution sol` | yes (`Linear_Recurrences_Solver` session) |
| **Taylor_Models**, **Affine_Arithmetic** (Immler, Traut) | multivariate Taylor models and affine forms with proved remainder bounds | `compute_bound_tm_correct` etc. | Affine_Arithmetic yes; Taylor_Models has no code annotations but is built on executable float operations |
| **Ordinary_Differential_Equations** (Immler) | verified ODE enclosures (HOL-ODE-Numerics; used to verify the Lorenz attractor) | yes | yes, but large |
| **Formal_Puiseux_Series**, **Bernoulli**, **Euler_MacLaurin**, **Error_Function**, **Lambert_W**, **Polylog**, **Zeta_Function** | specification-side theory of series and special functions | yes | mostly not executable; they supply the *meanings* our special-function kernels would prove against |
| **CakeML_Codegen** (Hupel, Nipkow) | a verified code generator from HOL to CakeML | yes | an alternative to `export_code` that removes the code generator from the trust base (section 5) |

**Not found in the AFP**: any symbolic integration (no Risch, no Hermite
reduction, no Rothstein–Trager, no rule-based integrator), Gosper or
Zeilberger summation, cylindrical algebraic decomposition as exportable code,
multivariate polynomial factorization, a verified expression simplifier, a
verified parser for mathematical notation. These are exactly where the
checker pattern is needed.

## 2. The certificate catalogue

### 2.0 The common core: an expression language and when two expressions are equal

Every capability works on one HOL datatype, `cexpr`: rational constants, the
symbolic constants π and e, variables (the variable of the problem and named
parameters such as `a`), `+ − × ÷`, integer powers, `sqrt` and n-th roots,
`exp`, `log`, `sin`, `cos`, `tan`, `atan`, `asin`, `acos`, `sinh`, `cosh`,
`tanh`, `abs`. It has

- a real semantics `cval :: cexpr ⇒ (var ⇒ real) ⇒ real`;
- a **domain predicate** `cdom e ρ`: every denominator is nonzero, every `log`
  argument is positive, every `sqrt` argument is positive (strictly, so the
  derivative exists), every `tan` argument avoids odd multiples of π/2, and so
  on. The domain is part of every answer;
- a verified derivative `cderiv x e`, proved the way `DERIV_floatarith` is
  proved in `Approximation`:
  `cdom e ρ ⟹ ((λt. cval e (ρ(x := t))) has_real_derivative cval (cderiv x e) ρ) (at (ρ x))`;
- a **formal normaliser** `cnorm`. It treats each distinct transcendental
  subterm (`exp u`, `log v`, `sin w`, ...) as a fresh symbol, after a small
  set of sound rewrites (`exp(u+v) = exp u · exp v`, `sin² = 1 − cos²`,
  `tan = sin/cos`, `sqrt(u)² = u` on the domain), and brings the result to a
  quotient of multivariate polynomials over ℚ in the variables and those
  symbols, reusing `Commutative_Ring`/`Reflective_Field` normal forms and
  `Polynomial_Factorial` gcds. Theorem `cnorm_sound`: on the domain, the
  normal form has the same value.

The key observation: **if the normal form of `a − b` is the zero polynomial,
then `a = b` everywhere on the domain**, whatever relations hold between the
transcendental symbols, because a formal identity stays true under every
assignment of values. So the equality test is sound without any theory of
algebraic independence. Independence would only be needed to make it
*complete* (to conclude "not equal"), and the design never concludes "not
equal" from a normal form. Constant subexpressions built from rationals and
roots are compared exactly with `Algebraic_Numbers`, which decides them.

Where the normal form is not zero but the two expressions are in fact equal
(Richardson's theorem says this cannot be avoided in general once `exp`, `sin`
and absolute value are present), the checker fails and the system withholds
with the reason "could not establish the identity". A proved interval
evaluation at a point where the difference is provably nonzero (via
`approx`) can establish *non*-equality; the scorer uses that (section 4).

### 2.1 The table

"Finder" is the untrusted search; "checker" is what the HOL theorem says when
the binary answers; "withhold" is what happens otherwise; "gap" is what the
design does not cover.

| Capability | Finder (untrusted) | Checker statement in Isabelle terms | Withhold means | Honest gap |
|---|---|---|---|---|
| **Evaluate** an exact expression | none needed | `ceval e = Some v ⟹ cval e ρ = v` with `v` a rational or `real_alg`; decimals via `approx` and the finance-style `to_dec_at_sound` | the expression is transcendental and no exact form is in the table: give an enclosure instead, or decline | exact values of `sin`, `log` etc. only at tabled points (each table row a theorem: `sin (π/6) = 1/2`) |
| **Expand** | none | verified: `cval (expand e) ρ = cval e ρ` on the domain, `expand e` in the canonical polynomial normal form (`Commutative_Ring_Complete`) | never for polynomials | "expanded" for non-polynomial input has no canonical meaning; we expand the polynomial skeleton only |
| **Simplify** | SymPy `simplify`, `radsimp`, `factor`, `cancel`; any rewriter | `cdom e ρ ⟹ cdom s ρ ∧ cval s ρ = cval e ρ` (via `cnorm (s − e) = 0` and a proved domain inclusion), plus a *computed, not proved* size `csize s ≤ csize e` | identity not established, or `s` needs a smaller domain than `e` (SymPy's `x/x → 1`): either state the extra condition or withhold | "simplest" has no correctness notion. We prove only "equal on the stated domain"; the size measure is a ranking, said so in the answer |
| **Factor** (one variable, over ℤ or ℚ) | none needed | verified by Berlekamp_Zassenhaus: product equals the input and each factor is irreducible | never (degree limits are performance, not correctness) | multivariate factorization: no AFP algorithm. Checker for a proposed multivariate factorization proves the product only (`cnorm (∏ fᵢ − p) = 0`); irreducibility of the factors is not claimed, and the answer says "a factorization", not "the" |
| **Partial fractions** | SymPy `apart`, or Linear_Recurrences' verified `partial_fraction_decomposition` | `cnorm (Σ pieces − e) = 0` and each piece has the stated shape | denominator not fully factored over ℚ | over algebraic extensions later |
| **Solve: one polynomial equation** | none needed for real roots; SymPy for radical forms | verified: `set (real_roots_of_rat_poly p) = {x. rpoly p x = 0}` gives *all* real roots; a radical form `r` is shown only if `real_alg` comparison proves `r` equals the algebraic root; completeness of a SymPy list is checked by comparing against the verified list (or Sturm `count_roots`) | a root has no radical form (degree ≥ 5 in general): answer "the root of p in [a, b]" with an enclosure, which is still exact and proved | complex roots need the square-free premise for degree ≥ 3 (`complex_roots_of_int_poly_all`); parameters in coefficients are out of scope at first |
| **Solve: linear systems** | none needed | verified Gauss–Jordan (Jordan_Normal_Form, `gauss_jordan_single`): the solution set equals the stated parametrised set; no-solution comes with a certificate `y` with `yᵀA = 0`, `yᵀb ≠ 0`, checked exactly | never over ℚ | symbolic coefficients: generic-case answers (SymPy's default) are not true for all parameter values; we would state the conditions or withhold |
| **Solve: polynomial systems** | SymPy `solve`, Gröbner, triangular decomposition | each proposed solution substituted exactly (`real_alg`); *completeness* through a Gröbner basis from the verified `Groebner_Bases` and the elimination polynomial's verified root list; inconsistency through `1 ∈ ideal` with cofactors checked by expansion (Nullstellensatz certificate) | positive-dimensional solution sets; any step not certified | phase 2 at the earliest |
| **Solve: transcendental equations** | SymPy `solve`/`nsolve` | a root exists in `[a, b]`: interval signs at `a`, `b` (by `approx`) plus continuity from the domain predicate, via the intermediate value theorem; uniqueness in `[a, b]` from a derivative enclosure of one sign (`approx_form` over `Bound x a b` on `cderiv`) | no certified bracket | "all solutions" of `sin x = 1/2` needs periodicity theorems per function; at first we certify roots in a stated interval only |
| **Inequalities, one variable, polynomial or rational** | none needed | verified: roots by `real_roots_of_rat_poly`, sign on each piece by exact evaluation at a rational sample point; answer is a union of intervals with algebraic endpoints, with `{x. p x > 0} = ⋃ intervals` proved | never | — |
| **Inequalities, several variables** | SDP solver for sums of squares; Simplex for linear | linear: Simplex's `Sat`/`Unsat` theorem; polynomial `p ≥ 0`: a certificate `p = Σ cᵢ qᵢ²` with rational `cᵢ ≥ 0`, checked by exact expansion; quantifier elimination for small formulas by Virtual_Substitution, Ferrack, Cooper | no exact SOS certificate after rounding the SDP solution | strict positivity and Positivstellensatz with denominators are more work; cylindrical decomposition is out of reach |
| **Differentiate** | none needed | verified: `cderiv` with the theorem in 2.0; the printed form may be a SymPy-simplified `s` with `cnorm (s − cderiv x e) = 0` | only when the simplified form cannot be certified; then print the unsimplified derivative | derivative at a point where the domain predicate fails (`abs x` at 0): withhold with that reason |
| **Integrate, indefinite** | SymPy `integrate` (Risch, heurisch, manual rules), Rubi, any CAS | `check_anti F f x = True ⟹ ∀ρ. cdom F ρ ∧ cdom f ρ ⟹ ((λt. cval F (ρ(x:=t))) has_real_derivative cval f ρ) (at (ρ x))`; implemented as `cnorm (cderiv x F − f) = 0` | no candidate, or derivative identity not established | (1) "no elementary antiderivative exists" cannot be stated: it needs a verified Risch decision procedure. (2) The answer holds on each interval of the domain separately, with a separate constant on each: `∫ 1/x = log|x|` is printed with that domain. (3) SymPy answers that pass through complex numbers (`atan` written with `I`) are rejected until complex semantics exist |
| **Integrate, definite** | same, plus bounds | `F` is certified as above **and** `[a, b] ⊆` domain, proved by `approx_form` over `Bound x a b` for each domain condition (each is a strict inequality, so bisection can prove it), giving through `fundamental_theorem_of_calculus` `(λt. cval f (ρ(x:=t))) has_integral (cval F (ρ(x:=b)) − cval F (ρ(x:=a)))) {a..b}`; the value then simplified as an exact constant | domain not established on `[a, b]`; a domain condition fails at an exact point of `[a, b]`: a **proved decline** "improper on this interval" | improper integrals (infinite bounds, endpoint singularities) need limits; until 2.13 lands they are withheld. Integrability is supplied by the FTC theorem itself; an antiderivative that exists only off a point of `[a, b]` is never enough, which is precisely what the domain proof rules out |
| **Integrate, numerically** | none needed | Darboux enclosure: on each subinterval, the interval evaluation of `f` bounds it; with `f` continuous on `[a, b]` (domain predicate) the integral lies in `Σ width × [lo, hi]`; theorem via `integral_le`/`has_integral_bound`; printed with `to_dec_at_sound` | enclosure too wide for the requested digits after the step budget | slow for oscillating integrands; Taylor models (AFP) would tighten it |
| **Limits** | SymPy `limit` (Gruntz) | three certified cases: (a) `e` continuous at the point (domain predicate there): limit = value, via `isCont`; (b) rational functions: cancel the gcd (verified), then (a), or degree comparison at ±∞; (c) the proposed limit `L` with a certified series expansion (2.14) whose leading term gives `L` | anything else | the general case (Gruntz's algorithm) has no verified version; `Real_Asymp` is a proof method only. Oracle7's "evaluate near the point" check is unsound and is not reused |
| **Series** | SymPy `series` | proposed polynomial `P` of order `n` at `a`: `(λx. cval f x − P x) ∈ O[at a](λx. (x − a)^(n+1))` (Landau_Symbols), proved by verified truncated power-series arithmetic over `cexpr` (composition rules for `exp`, `log`, `sin`, ... each a theorem from Taylor's theorem in HOL-Analysis) | a coefficient that is not an exact constant; an operation outside the truncated-series rules | Puiseux and asymptotic series later; formal power series in the distribution have no code, so this is new work |
| **Sums** | SymPy `summation`, Gosper's algorithm | closed form `S` for `Σ_{k=m}^{n} f k`: `cnorm (S(n) − S(n−1) − f(n)) = 0` and `S(m) = f(m)` checked, then induction gives the sum for all `n ≥ m` (the telescoping certificate, the WZ idea); recurrences through Linear_Recurrences' verified `solve_lhr` | no closed form proposed, or the telescoping identity not established | infinite sums (ζ(2) = π²/6) only as tabled theorems, each a HOL fact (the Basel sum is `inverse_squares_sums` in HOL-Analysis's `Gamma_Function`); convergence of a general series is not decided |
| **Matrices** | none needed for exact entries | verified (Jordan_Normal_Form, Gauss_Jordan): determinant, rank, inverse (`mat_inverse`), solve, characteristic polynomial; eigenvalues as algebraic roots of the characteristic polynomial; eigenvectors checked by `A v = λ v` exactly over `real_alg` | symbolic entries beyond what `cnorm` handles | singular value decomposition and anything needing numerics on ill-conditioned matrices |
| **Numerics `N[e, d]`** | none | `approx` + `to_dec_at_sound`: the printed `d` digits are within half a unit in the last place of the true value | enclosure too wide at the precision budget (a proved "imprecise" decline, as in quantity) | no "fast floating point mode": every number is enclosed |
| **Number theory** (gcd, primes, modular arithmetic, factoring integers) | any factoring program | `prime` by `Primes` code for small numbers; Pratt certificates (AFP `Pratt_Certificate`) checked for large primes; integer factorization checked by multiplication plus primality of each factor | factor not certified prime | — |

### 2.2 Withhold, precisely

The outcome type mirrors the kernels we already ship:

```
datatype cas_outcome =
    Answer cexpr domain certificate
  | Enclosure interval nat
  | Decline cas_reason
datatype cas_reason =
    No_candidate | Identity_unproved | Domain_unproved | Improper_on_interval
  | Outside_language | Imprecise | Not_elementary_claimed_by_finder
```

`Improper_on_interval` and `Imprecise` are proved declines (a theorem states
exactly when they fire, the `kernel_impossible` pattern of
`Quantity.thy`). The others are honest "I could not verify", with the
finder's own output kept in the log for inspection. `Not_elementary_claimed_by_finder`
reports what SymPy said without endorsing it.

## 3. Front end: an expression language, not English

The CAS binary accepts only a formal expression language. English belongs to
recognizers outside the trusted core, exactly as everywhere else in veri7vn.

### 3.1 Grammar sketch

SymPy's surface syntax is chosen so that SymPy's tests convert with little
translation; a Mathematica-style front (`D[f, x]`, `Integrate[f, {x, a, b}]`)
can be a second untrusted rewriter into the same commands.

```
command  ::= op "(" expr { "," arg } ")"
op       ::= "evaluate" | "N" | "expand" | "simplify" | "factor" | "apart"
           | "solve" | "diff" | "integrate" | "limit" | "series"
           | "summation" | "det" | "inverse" | "rank" | "eigenvals"
arg      ::= expr | "(" var "," expr "," expr ")" | "[" expr { "," expr } "]"
           | var "=" expr                              (assumptions, e.g. a = positive)
expr     ::= term { ("+" | "-") term }
term     ::= unary { ("*" | "/") unary }
unary    ::= "-" unary | power
power    ::= atom [ ("**" | "^") unary ]               (right associative)
atom     ::= integer | decimal | rational | var | "pi" | "E" | "oo"
           | func "(" expr { "," expr } ")" | "(" expr ")"
func     ::= "sqrt" | "root" | "exp" | "log" | "sin" | "cos" | "tan" | "atan"
           | "asin" | "acos" | "sinh" | "cosh" | "tanh" | "Abs"
           | "Rational" | "Matrix"
```

No implicit multiplication (`2x`), which is where Oracle7's organ misread
"1969 d" as `1969*d**2*i`; recognizers may insert `*`, the language never
guesses. Decimals in the input are read as exact rationals (`0.1` is `1/10`)
and the echo says so.

### 3.2 Verified parser or untrusted parser

- **Verified option.** Parser and printer written in HOL over `String.literal`,
  with the round-trip theorem `cparse (cprint e) = Some e` (the printer is
  injective and the parser inverts it), plus a precedence lemma that `cprint`
  parenthesises minimally. The discrete family already proves base64 and
  percent-encoding round trips, so the technique is in the house. Cost: about
  a week of an opus lane for this grammar.
- **Untrusted option.** A small SML parser with a property test (parse∘print
  is the identity on every expression in every panel), labelled untrusted.
- **Either way**, the binary echoes what it read using the *verified printer*
  (`I read: integrate(x**2*exp(x), x)`). The round trip makes the echo
  faithful: what is shown is exactly the term the theorem is about. What no
  theorem can give is that the term is what the person meant; the echo is how
  they find out.

Recommendation: untrusted SML parser plus verified printer in phase 0, the
verified parser and round-trip theorem in phase 1.

### 3.3 How Oracle7's English questions map

Oracle7's math organ reads a directive and a span. Its directive list maps
onto the commands one to one:

| Oracle7 directive (`math_organ_v3.py`) | Command |
|---|---|
| solve (equation / system / inequality) | `solve([eq, ...], [vars])` |
| simplify, "combine", "reduce" | `simplify(e)` |
| factor | `factor(p)` |
| expand, "multiply" | `expand(e)` |
| evaluate (with assignments `x = 3`) | `evaluate(e, x = 3)` / `N(e, d)` |
| differentiate (`f(x) = ...`, "slope of the tangent") | `diff(e, x)`, `evaluate(diff(e, x), x = a)` |
| integrate ("from a to b") | `integrate(e, x)`, `integrate(e, (x, a, b))` |
| limit ("as x approaches a") | `limit(e, x, a)` |
| decompose | `apart(e, x)` |

The English recognizer (untrusted, outside the binary) emits a command string;
the precision guards already in the head (G5 echo, G6 units-not-variables, P7,
and the Q1/R1 "English as algebra" declines the scout found unmodelled) run
before it. The deployed head-math kernel (percent, conversion, integer square
root, gcd/lcm, one linear equation) becomes a client of the same expression
language rather than a separate one, once the CAS kernel exists.

## 4. Measurement

### 4.1 Panels

| Panel | Source | Size (elementary subset) | Role |
|---|---|---|---|
| `sympy-integrate` | SymPy 1.14.0 (the version in `.venv`), `integrals/tests/test_integrals.py`, `test_rationaltools.py`, `test_manual.py`, `test_heurisch.py`, `test_risch.py` | an AST scan (scratch, untrusted) finds 538 `assert integrate(...) == expected`-shaped tests (and the `ratint`, `manualintegrate`, `heurisch`, `risch_integrate` variants); 280 indefinite and 49 definite ones mention no special function, `oo`, `I`, `Piecewise` or `Abs` | phase 0 |
| `sympy-diff` | `core/tests/test_diff.py` (60 asserts) and derivative asserts elsewhere | ~60 | phase 0 control |
| `calculus` | the shipped Oracle7 specialist panel (124 items, 62 held-out) | 124 | must stay 62/0 |
| `sympy-factor`, `sympy-solve`, `sympy-matrices`, `sympy-limits`, `sympy-series`, `sympy-sums`, `sympy-simplify` | `polys/tests/test_polytools.py` (1,615 asserts), `test_factortools.py` (211), `solvers/tests/test_solvers.py` (754), `test_solveset.py` (891), `matrices/tests/test_matrices.py` (850), `series/tests/test_limits.py` (576), `test_series.py` (96), `concrete/tests/test_sums_products.py` (621), `simplify/tests/test_simplify.py` (352) | to be filtered per capability | phases 1–2 |
| `rubi` | the Rubi integration test suite (tens of thousands of integrands with optimal antiderivatives, MIT licence; used in published comparisons of Mathematica, Maple, Maxima, FriCAS, Giac and SymPy) | its elementary-function chapters | the external held-out for integration; nobody tuned SymPy's tests against it |
| `mathematica-docs` | In/Out pairs from Wolfram's reference documentation | hand-harvested | phase 2; copyrighted text, so kept under `var/`, never committed |

### 4.2 What "right" means for a CAS answer

Deciding whether our answer equals the expected one is itself a CAS problem,
and an undecidable one in general. The scorer is untrusted Python (like every
scorer here) and three-valued:

1. **Proved equal**: our own checker accepts the identity (for antiderivatives:
   `cnorm (cderiv x ours − cderiv x expected) = 0`, i.e. they differ by a
   constant on each interval; for values: `real_alg` equality or `cnorm`).
2. **Numerically equal**: mpmath at 50 digits at 8 seeded random points of
   the common real domain (for antiderivatives, compare differences
   `F(p) − F(q)` so the constant drops out); all agree to 40 digits.
3. **Numerically different**: some point where both are defined and they
   differ by more than 10⁻³⁰ relative. That is a **wrong** if our checker did
   not certify, and a **dispute** if it did.

An item is **right** when the binary answers with a verified certificate and
the scorer says 1 or 2. It is **wrong** when the binary answers and the
scorer says 3. A dispute means our proof and SymPy's expected value disagree;
since our answer is proved, either the statement is the wrong statement (a
domain or branch mismatch, which is our bug in the *specification*) or
SymPy's test is wrong. Every dispute is read by hand and reported; the board
counts disputes separately and the target is 0 unadjudicated. **Withheld** is
any decline. The six exam criteria carry over as: 0 wrong, 0 false yes (an
answer on an item whose expected value is "no closed form" or "diverges"),
within budget (p50 latency of the binary, excluding the finder).

### 4.3 Splits

dev and held-out by a stable hash of `(file, line)` of the test, 50/50,
fixed before any lane runs; Rubi as the fresh panel. The rule from
`BEYOND.md` applies: never tune on a panel you then score on, and say that
SymPy's tests share SymPy's blind spots (they test what SymPy can do).

### 4.4 The first number

**`sympy-integrate` held-out, elementary subset (about 165 of the ~329
items): right / wrong / withheld, with wrong = 0.** The control on the same
items is Oracle7's math organ check applied to SymPy's own answers
(right/wrong/withheld by its `equiv`), and SymPy itself (which passes its own
tests by construction, so its row measures our withhold rate, not its errors).
The phase-0 target is the share answered, not parity with SymPy.

## 5. Trust base and limits

**Trusted:** the Isabelle kernel and HOL's axioms; the code generator's
translation of HOL equations to SML (not verified; the AFP's
`CakeML_Codegen` is a verified alternative path that would remove it, at the
cost of moving to CakeML); the target-language mapping of `int` and `integer`
to MLton's `IntInf` (GMP underneath); MLton and its runtime; the operating
system. `Code_Real_Approx_By_Float` is forbidden. **Untrusted, and harmless
to correctness by construction:** the finder (SymPy, or any CAS), the
recognizer, the scorer, the test extractor. A lying finder can only cause
withholds. **Untrusted and relevant:** the parser until its round trip is
proved, and above all the *statement* of each checker theorem. If the
statement says the wrong thing (forgets a domain, uses `≤` where the user
meant `<`), the system is proved correct about the wrong question. The
defence is A1's audit discipline: statements bind to HOL-Analysis's
definitions (`has_real_derivative`, `has_integral`, Landau symbols), never to
our own code.

**What cannot be made correct this way:**

- Negative claims that need a full decision procedure: "this integral has no
  elementary form" (needs verified Risch), "this equation has no closed-form
  solution", "these two expressions are different" outside decidable
  classes. We say "could not verify", never "impossible", unless a theorem
  says so.
- Notions without a specification: "simplest form", "nicest antiderivative".
- Generic answers. SymPy and Mathematica answer `∫ xⁿ dx = xⁿ⁺¹/(n+1)` and
  mention `n ≠ −1` only sometimes. A proved answer must state its conditions,
  so ours will look fussier.
- Floating-point speed for large numerical work. Every number is enclosed.

**Where Mathematica still wins, and why that is acceptable.** Breadth: about
6,000 built-in functions, special functions (Bessel, hypergeometric,
elliptic, Meijer G), Risch plus thousands of Rubi-style rules, asymptotics,
differential equations, plotting. Each of those would need HOL definitions
and derivative or identity theorems before we can certify an answer that uses
them; some already exist in the AFP (Gamma, erf, Lambert W, polylogarithm,
zeta). But the finder is pluggable: Mathematica itself can be our finder. The
product is then literally "Mathematica's answers, the ones that can be
proved, and an honest refusal for the rest". The withhold rate measures the
remaining distance; the wrong count stays 0.

## 6. Phased plan

Tiers follow `BEYOND.md`: sonnet for extraction, scorers and plumbing; opus
for new HOL kinds with real analysis or interval arithmetic.

### Phase 0: one week, one opus lane plus one sonnet lane

New family `src/extract/cas/`, session `Veri7vn_CAS`, imports only the
distribution (`HOL-Analysis`, `HOL-Decision_Procs.Approximation`,
`HOL-Computational_Algebra`) and `commons`; no AFP yet.

1. (opus) `Cas_Expr.thy`: `cexpr` (rationals, π, variables and parameters,
   `+ − × ÷`, integer powers, `sqrt`, `exp`, `log`, `sin`, `cos`, `tan`,
   `atan`), `cval`, `cdom`, `cderiv` with the derivative theorem; the
   verified printer `cprint`.
2. (opus) `Cas_Norm.thy`: formal normaliser to polynomial quotients over
   kernel symbols, with `cnorm_sound`; the rewrites `exp(u+v)`, `sin²+cos²`,
   `tan = sin/cos`, `log` of products only when the domain proves the factors
   positive.
3. (opus) `Cas_Integrate.thy`: `check_anti` with the indefinite theorem;
   definite integrals through `fundamental_theorem_of_calculus` with the
   domain on `[a, b]` proved by `approx_form`; the proved
   `Improper_on_interval` decline; the exact value of `F(b) − F(a)` printed
   when rational, otherwise as an expression plus a proved 15-digit
   enclosure.
4. (sonnet) untrusted SML parser for the grammar in 3.1 with the property
   test; JSON protocol `{"command": ..., "candidate": ...} → {"outcome": ...}`;
   the finder as a Python subprocess calling SymPy (untrusted, outside the
   binary).
5. (sonnet) `tools/cas/extract_sympy.py`: AST extraction of the panels in
   4.1 with file:line ids and the SymPy version; the three-valued scorer;
   dev/held-out split; panels under `var/cas/`, never committed.

**The number that proves phase 0:** `sympy-integrate` held-out elementary
subset, right / 0 wrong / withheld, plus `sympy-diff` right / 0 wrong, plus
the `calculus` panel unchanged at 62/0 through the new kernel, marker
`VERI7VN_CAS PASS theorems=N oracles=0`. A plausible first result is that
most polynomial, rational and `exp`/`log` items pass and many trigonometric
ones withhold on `Identity_unproved`; the withhold list by reason is part of
the report.

### Phase 1: three to five weeks, two or three opus lanes

- Adopt the AFP on the build hosts (after ember decides; lane file, question 1):
  Berlekamp_Zassenhaus, Algebraic_Numbers, Sturm_Sequences, Jordan_Normal_Form,
  Simplex, Linear_Recurrences. Check RC1 compatibility first.
- Factor (verified), real roots and univariate inequalities (verified, exact
  algebraic output), linear systems and matrices (verified), partial fractions,
  exact constants through `real_alg`.
- Verified parser with `cparse (cprint e) = Some e`.
- Stronger normaliser: trigonometric functions through `exp(i·)` with complex
  semantics, `abs` and `sign` with case splits proved by the domain.
- Numeric definite integrals by Darboux enclosure.
- The English route: Oracle7's math organ questions (from `math_organ_v3.py`'s
  test material and the head's `organ:math` core-panel items) through an
  untrusted recognizer into commands.

**Numbers:** each `sympy-*` panel for the capabilities above (right / 0 wrong
/ withheld, held-out and dev); `rubi` elementary chapters as the external
held-out for integration; Oracle7's math organ on the same items as control.

### Phase 2: months, open-ended

Limits (continuity, rational, series-based), truncated series with Landau
remainders, sums by telescoping certificates (Gosper as finder), SOS
certificates for polynomial inequalities, Gröbner certificates for polynomial
systems, special functions in the order the AFP supplies their theory
(Gamma, erf, Lambert W), Mathematica's documented examples as a panel, and
the `CakeML_Codegen` route to shrink the trust base. **Numbers:** the
`sympy-limits`, `sympy-series`, `sympy-sums` panels and a
`mathematica-docs` panel, each with 0 wrong; the headline is the share of
Rubi's elementary chapters answered with a proof.
