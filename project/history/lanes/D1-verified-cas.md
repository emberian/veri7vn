# D1-verified-cas: design for a computer algebra system with proved answers

Design-and-writing lane, 2026-10-18. No builds, no code. Output:
`docs/design/verified-cas.md`.

## What I read

AGENTS.md, README.md, project/PLAN.md, project/swarm/BEYOND.md, the summary of
docs/assurance/theorem-audit.md; `Quantity.thy` (exact rationals, proved
declines), `Disc_Algos.thy` (MST certificate checker, `mst_cert_minimal`),
`Disc_Calc.thy` (polynomial calculus), `Finance_Num.thy` (enclosures via
`approx`, `to_dec_at_sound`, `enclose_fmt_sound`); the math-organ scout report;
Oracle7's SymPy organ `upstream/root/wander-train/math_organ_v3.py` (read-only)
and the `calculus` specialist manifest and panel. Sources grepped, nothing
built: Isabelle2026-RC1 `src/HOL/{Computational_Algebra,Decision_Procs,Analysis,Library,Real_Asymp}`
and the AFP snapshot `~/isabelle/afp-2026-05-29/thys` (about 40 entries
checked for code equations and headline theorems). SymPy 1.14.0's test files
in `.venv` were counted by an untrusted AST scan in my scratchpad.

## What I concluded

- **The architecture is a basis.** "Untrusted finder, proved checker,
  withhold otherwise" carries over to a CAS for most capabilities, and
  Oracle7's own math organ already has that shape with floating-point checks
  (random-point `equiv`, central differences, "evaluate near the point" for
  limits, which is unsound). We keep its directive list and replace each check
  by a theorem.
- **Three corrections to root's sketch.** For factorization over ℤ/ℚ, real
  roots, determinants and inverses, linear programming and linear recurrences
  the AFP has *verified algorithms* (Berlekamp_Zassenhaus,
  Algebraic_Numbers' `real_roots_of_rat_poly`, Jordan_Normal_Form, Simplex,
  Linear_Recurrences), so no finder is needed. The real difficulty is
  deciding that two expressions are equal; the design uses a formal
  normaliser over "kernel symbols" whose soundness needs no independence
  theory (formally zero implies zero), withholds when it cannot decide, and
  never concludes "different" from it. Every answer carries its domain.
- **Isabelle already has the pieces for phase 0 without the AFP:**
  `Approximation`'s `DERIV_floatarith` (a proved symbolic derivative to copy),
  `approx_form` (to prove an interval avoids singularities), HOL-Analysis's
  `fundamental_theorem_of_calculus` (to turn a checked antiderivative into a
  proved definite integral), `Commutative_Ring`/`Reflective_Field`
  normalisers, `Polynomial_Factorial` gcds.
- **Missing everywhere:** symbolic integration, summation algorithms,
  multivariate factorization, a verified simplifier, a verified math parser,
  exportable limits (`Real_Asymp` is a proof method only), executable formal
  power series.
- **First number:** SymPy 1.14.0's elementary integration tests (about 329
  items: 280 indefinite, 49 definite), held-out half, right / **0 wrong** /
  withheld, with the `calculus` panel unchanged at 62/0.

## Phase-0 plan (one week)

New family `src/extract/cas/`, session `Veri7vn_CAS`, distribution only.
Opus: `cexpr` with real semantics, domain predicate, proved derivative and
verified printer; the formal normaliser with `cnorm_sound`; `check_anti` and
definite integrals through the FTC with the domain on [a, b] proved by
`approx_form`, plus the proved `Improper_on_interval` decline. Sonnet:
untrusted SML parser with property test, SymPy finder subprocess, AST panel
extractor, three-valued scorer (proved equal / numerically equal at 50 digits
/ numerically different), stable dev/held-out split under `var/cas/`.

## Found on the way (for root, not my path)

`Disc_Calc.thy`'s `c_def_sound` states `val = F b − F a` and that `F` has
derivative `p` everywhere, but never `has_integral`. One line through
`fundamental_theorem_of_calculus` would bind it to HOL-Analysis's integral.

## Open questions for ember

1. **The AFP.** Phase 1 needs AFP entries (Berlekamp_Zassenhaus,
   Algebraic_Numbers, Jordan_Normal_Form, Sturm_Sequences, Simplex). The local
   snapshot is from May 2026 and not registered with RC1; the remote hosts may
   have none. Adopt an AFP matching Isabelle2026 on hbox and persvati, or wait
   for the release? (Heaps for Algebraic_Numbers plus Jordan_Normal_Form are
   long builds.)
2. **The finder at answer time.** Phase 0 calls SymPy as a subprocess, which
   brings Python back into the answer path (untrusted, but slow and heavy
   compared with the 4–10 MiB binaries). Acceptable for the CAS, or should
   the common finders (rational-function integration by Hermite reduction,
   Rothstein–Trager) be ported to SML?
3. **Mathematica as finder and as panel.** Using `wolframscript` as an
   untrusted finder, and harvesting its documentation examples as a panel
   kept under `var/`: is there a licence, and is that use acceptable?
4. **Domains in answers.** Proved answers must say "for x > 0" where SymPy
   and Mathematica say nothing. Is the fussier output the product, or should
   there be a "generic" display mode that still records the condition?
5. **Priority against the beyond-parity lanes.** This is back-pocket work; is
   phase 0 wanted now, or after wave 6?
