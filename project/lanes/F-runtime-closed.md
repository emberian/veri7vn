# Exact closed arithmetic for checked follow-ups

Owner: runtime/routes, 2026-10-18. Parent owns independent replay in
`tools/runtime_contract.py`; dispatch owner owns dialogue reconstruction.

The Math program now accepts complete finite arithmetic requests, including
“What is 5 squared?”, “What is (-3/2)^2?”, and explicit Calculate/Evaluate
requests. It reuses the existing exact numeric parser and expression AST.
Numbers, negation, sums, differences, products, division, parentheses, and
square/cube powers are supported. Symbolic powers have normal precedence over
unary minus: `-2^2` is -4 and `(-2)^2` is 4. The word suffix squared/cubed
applies to the entire preceding operand. Nested powers require parentheses.
Other exponents, unbound variables, malformed tails and oversized requests
are explicit refusals. No arbitrary expression span is extracted from prose.
Affine equation parsing still refuses powers; it was not silently expanded.

A dedicated `--route closed` stage sits between algebra and legacy operators.
It requires `closed_expression` replies with matching original request text
and a mandatory checked computation packet. The ordinary `--route ops` also
accepts this finite grammar for direct compatibility, while retaining its
older integer/unit operators. Closed answers use exact canonical integer or
fraction text, not floating-point or rounded display.

The packet names the original typed AST, exact result and actual
`Mathkernel.check_closed` result. A pow node contains an original base AST and
literal exponent 2 or 3. The consumer independently evaluates that AST using
exact fractions, verifies its domain and displayed result, and rejects
missing, forged or stale evidence. Both producer and consumer bound the tree
before arithmetic: 128 nodes, depth 32, 256 characters per signed numerator
or positive denominator. A conservative pre-evaluation work bound uses four
bits per decimal digit, sums operand costs (+1 for addition/subtraction),
and multiplies by the power. Cost above 8192 refuses before potentially large
nested-power arithmetic. The consumer is ordinary Python, not formally proved.

The new HOL statements connect the runtime check to the original expression:

- Accepted closed shape has no variables.
- `closed_value e = Some v` iff `check_closed e v`.
- `check_closed e v` implies `ev i e = Some v` for every variable reading i.
- The same accepted check implies the existing `kernel (EvalExpr e)` returns
  `Value K_eval v`.
- Undefined original evaluation implies the route refuses. Thus `0*(1/0)` is
  not simplified to zero and answered.

None of these proves that the untrusted parser interpreted the user's text
correctly. The original request-text equality prevents transport substitution,
not a dishonest or mistaken parser. No static theorem list is presented as a
newly verified answer certificate.

Proof and actual-consumer evidence:

- Managed proof `var/mathorgan/remote-attempts/20261018T085351Z-456cc2a5979e`
  passed on persvati, 52 scanned statements, zero oracles, actual Finished
  target in 20 seconds. Export SHA-256:
  `2dc1d544e904b5971fb235e01d9fac370f75f6b70ac382b218a8ee40666b9237`.
- Immutable native manifest:
  `var/mathorgan/native-attempts/20261018T085527Z-ba82c02d6a03/compile-inputs.json`.
  Binary SHA-256 `d5e406eff27d5e3555d5d430a3fc94d253e8ac0c62218ae777ae75315c2f6cf4`.
- All five new test methods pass: 16 actual Math/Guards values, 18 finite
  refusals, seven noncaptures, seven real-packet mutations, three request/kind
  downgrade checks. All seven affine, seven earlier Math, and eight route
  methods also pass (the route checks include 114 historical guard fixtures).
- Actual selected dispatcher: **11/11** expected answer/refusal results,
  independent evidence consistent and actual guard silence on every answer.
  Receipt `var/mathorgan/closed-final-dispatch.json` binds all stage binaries.
- Parent's independent replay accepted six actual producer packets and rejected
  six mutations: `var/C-runtime-consumers/closed-native-replay.json`.
- Dialogue's solve-then-square integration is owned by the dispatcher lane;
  this report does not claim a completed dialogue test before that evidence.

This is a finite capability extension, not a new specialist-panel score or
whole-head completion claim. No proof retry was needed; no axiom or oracle was
introduced. No jobs remain in this lane.

Changed owned files: `src/extract/mathorgan/{Math_Closed.thy,Math_Export.thy,
ROOT,affine.sml,recognizer.sml,main.sml,test_closed.py,README.md}`;
`tools/dispatch/routes.py`; this report. Parent's shared checker/tests form a
separate part of the joint packet. The prior affine artifact remains separately
captured; this source/native/checker cohort must be integrated together.
