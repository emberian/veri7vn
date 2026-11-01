# Exact affine equations with checked typed evidence

Owner: runtime/routes, 2026-10-18. Parent owns the independent consumer in
`tools/runtime_contract.py`. This lane makes no commits.

The request parser now preserves a typed expression tree instead of reducing
coefficients in untrusted SML. Numeric atoms use the shared `ExactNumeric`
parser. The finite grammar accepts one variable x, exact numbers, parentheses,
addition/subtraction/negation, multiplication and division. The HOL normalizer
accepts multiplication only where one normalized side is constant, and division
only by a normalized nonzero constant. Unsupported nonlinear expressions,
variable denominators, undefined divisions, powers, malformed numbers and
other variables refuse. Complete solve requests are anchored; derivative
assignments do not enter this solver.

The theorem connection is to the original typed tree:

- `affine_norm e = Some(a,b)` implies `ev i e = Some(a*i(x)+b)` for every reading.
  Thus the accepted expression is defined, not merely algebraically similar
  outside an unstated exceptional set.
- With normalized sides (a,b) and (c,d), satisfying the typed equation is
  equivalent to `a*x+b=c*x+d`.
- `check_affine l r (AffineUnique x)` implies a rational t satisfies the
  original typed equation iff t=x. The actual checker also substitutes x into
  both original expression trees.
- `check_affine l r AffineAll` implies every rational t satisfies it.
- `check_affine l r AffineNone` implies no rational t satisfies it.
- Normalized sides guarantee the computed candidate passes the checker.

The answer states a canonical exact rational root, every rational value, or
no rational solution. Each answered algebra request must carry kind
`affine_equation`, the actual original request text, and a mandatory checked
computation packet. The packet includes original AST, normalized coefficients,
classification and root when unique. The route adapter rejects missing/wrong
kind, missing packet, stale/swapped request text, and failed independent
arithmetic replay. This consumer replay is ordinary Python, not formally
verified. Request-text binding prevents transport mistakes; it does not prove
that the untrusted parser interpreted the text correctly.

The recognizer enforces 128 total AST nodes, depth 32 and 256 decimal digits
per reduced rational component in emitted evidence. The shared lexer has its
own broader caps; this consumer deliberately has a smaller finite budget.

Guard reconstruction recognizes exact all/no-solution sentences on complete
finite equation requests as solution-set answers. P2 therefore does not demand
a numeric token in that classification. This is untrusted answer-type
recognition. Standalone Guards does not verify a packet; the route consumer
must do that first. An unrelated nonnumeric response still faces P2, and an
incidental assignment echo still faces G5.

Validation:

- Managed proof `var/mathorgan/remote-attempts/20261018T081347Z-fa668924d7c5`
  passed on persvati: 47 scanned statements, zero oracles, actual Finished
  target in 23 seconds, completed/uncancelled/source-stable exit 0. Export
  SHA-256 `cad4a869fc501bb02aa1361dd9a15ed330f8f93fd08fd6a2f4f86542998ac19f`.
- Immutable Math native manifest:
  `var/mathorgan/native-attempts/20261018T082725Z-7cf931c76e23/compile-inputs.json`.
  Binary SHA-256 `f9e3efa7dc8b175c7a81bc5a0b080410bddd089d24dd0c6389254e8f63d0c2c6`.
  Shared numeric input is frozen `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.
- Guard feature reconstruction uses the unchanged proved P2/G6 export
  `736b288377920032be97e62e43a653c7ce7b2aefbd69a8c78c6e3026569dc2c3`.
  Final native manifest:
  `var/guards/native-attempts/20261018T082040Z-3ec2f60c252f/compile-inputs.json`.
  Binary SHA-256 `96e370bad2913cac9e2371cb7260af5d789d48273e33f1d28f48a2af26f27928`.
- All 7 new affine test methods pass: 14 unique-root examples, 8 all/no-solution
  examples through actual guards, 14 explicit refusal boundaries, 3 incidental
  assignment fallthroughs, 7 packet/display mutations, swapped/missing request
  text, simultaneous kind+packet removal, and a genuine nonnumeric P2 refusal.
- All 7 previous math boundary methods pass. The old assertion requiring
  obsolete “read it as” prose now checks the original typed right-hand AST and
  its normalized coefficient, retaining its substantive regression coverage.
- All 8 route methods pass, including the 114 historical synthetic guard
  inputs. All 3 measured Wordprob methods still pass (34 numeric/domain
  boundaries plus 12 actual guard composition cases).
- Actual selected dispatcher: **8/8** unique/all/none and refusal/fallthrough
  outcomes, with consistent independent evidence replay and guard silence on
  each answered result. Receipt `var/mathorgan/affine-final-dispatch.json`.
  It pins Math, Guards, Wordprob and Fusion bytes and the command used.
- Parent independently checked the actual dispatcher: **9/9** further cases,
  including both-sided rational root 29, normalized constant-product root 2,
  all/no classifications, undefined `0*(1/x)`, zero denominator and ambiguous
  multiple equations. Receipt: `var/C-runtime-consumers/affine-final.json`.

The first affine proof attempt stopped on an equality-symmetry finish; the
statement was retained and that step repaired. One native compile exposed a
leftover legacy `findEq` helper reference; it was replaced by the identical
boolean equals-sign test. Neither failed artifact was published. No weakened
theorem, new axiom or oracle was introduced.

Files: `src/extract/mathorgan/{Math_Affine.thy,Math_Export.thy,ROOT,affine.sml,
recognizer.sml,main.sml,build.sh,test_affine.py,test_recognizer.py,README.md}`;
`src/extract/guards/{recognizer.sml,README.md}`; `tools/dispatch/routes.py`;
this report. Parent's consumer files are a separate owned part of the same
integration. No new specialist-panel completion claim is made.
