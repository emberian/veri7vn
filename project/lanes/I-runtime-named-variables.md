# Named scalar affine variables

The checked affine route now accepts one selected scalar letter, a through z,
normalized to lowercase. For example, “Solve 3t+2=11 for t” returns t=3.
Targets may appear before or after the equation or in find/what-is wording.
Without an explicit target, the sole variable is inferred; constant-only
questions preserve x as the default. Explicit constant-only questions can
classify every/no value of another selected name.

The original typed tree retains its variable names. No adapter rewrites the
user's t into x. `affine_norm`, candidate selection, the actual checker and
reply rendering now take the selected name as an argument. The key theorem is:

`affine_norm name e = Some(a,b)` implies
`ev i e = Some(a * i(name) + b)` for every variable reading i.

A new connected theorem proves `vars e` is a subset of `{name}` whenever
normalization succeeds. The generalized original-equation theorem equates
satisfaction with a*t+b=c*t+d. Accepted unique checks characterize precisely
one rational root; accepted all checks establish every rational value; accepted
none checks establish no rational value. The unique checker evaluates both
original sides with the selected variable assigned the proposed root.

A foreign unknown refuses even in `t+y-y` or `t+0*y`. Conflicting target names,
nonlinear products, undefined divisors, malformed scientific notation and
trailing instructions refuse. Explicit `2*e` may name e, while malformed `2e`
is not split into a coefficient and variable. Incidental derivative/graph
assignments still fall through. A source audit exposed the article “a” in
“What is a function with y=x?” being mistaken for a target; the final reader
requires an equation-shaped start or explicit connective after a question
target, and both article-based controls now fall through. Closed expressions still permit no variables.

The existing affine packet schema1 now permits a single lowercase ASCII letter
in inputs.variable and requires every original AST var.name to equal it.
Independent Python replay binds the displayed variable in unique/all/none
answers as well as the coefficients and exact root. Original complete
request_text remains mandatory. This verifies the supplied typed computation;
it does not establish that the parser understood English correctly. Guards
only reconstructs complete-equation and classification features; it does not
verify the packet. Its kernel is unchanged and coverage remains 20/87 codes.

Proof/native evidence:

- Managed Math proof `var/mathorgan/remote-attempts/20261018T101346Z-dd6263bac0ab`
  passed on persvati: actual Finished target in 20 seconds, 53 scanned statements, zero oracles.
  One earlier attempt failed only at equality orientation in the normalized
  equation proof; the fixed tactic proved the unchanged statement.
- Export SHA-256 `37d52bae41479818335d66066bf181830632fa0e4b1eeb4e09a0340d3893cf8d`.
- Math manifest `var/mathorgan/native-attempts/20261018T101932Z-59503620f5c8/compile-inputs.json`;
  binary `0d27f7de5c1cf3cd7d60668b7627b1f3bac7852f17f6f464bb4b0cb3cb2ef6a4`.
- Guards manifest `var/guards/native-attempts/20261018T101443Z-8d167a654e87/compile-inputs.json`;
  binary `1cc908820046cd9cc8c77dbf040fa2910ac43d2cff3f5ddd5778fca16a825b73`.
  It reuses the unchanged previously proved Guards export.
- `var/mathorgan/named-variable/producer.json` records eight actual packets or
  refusals against the exact Math native.
- Four new test methods pass: 12 named answers/classifications through actual
  guards, 12 invalid requests, 6 incidental fallthroughs and 12 actual-packet
  mutations. Existing seven affine, five closed, three request-phrasing and eight route methods pass (including 114
  historical guard fixtures). The old y-only refusal was replaced by an
  explicitly mismatched-target refusal; named y is now a supported capability.

The actual default dispatcher passes **10/10** focused controls with all stages
and families enabled, stable before/after hashes, checked packets and actual
guards: `var/mathorgan/named-variable/final-default.json`. Parent independently
checked four additional default-dispatch cases on the final native (courteous
k solution, z all, q none, explicit e), and all 16 target/display/foreign-AST/
classification mutations were rejected. The stable-hash record is
`var/runtime-default/named-affine-final.json`; all nine shared affine checker
methods pass. The dispatcher lane also passes **10/10** named-variable dialogue
controls with all default stages and families enabled: t=3 then square=9,
a separately seeded cube=27, and unknown-name, fresh-session, all-solutions
and no-solutions controls that create no scalar ground. Its record is
`var/dispatch/successor/20261018T102146Z/receipt.json`, binding the same final
Math/Guards and canonical Stores C (`c719f82f`), with stable source hashes.
A newer selected Stores artifact failed on unrelated equations and is outside
this receipt. No broad suite or specialist-panel score is claimed.

Owned files: `src/extract/mathorgan/{Math_Affine.thy,Math_Export.thy,affine.sml,
main.sml,test_affine.py,test_named_variables.py,README.md}`;
`src/extract/guards/recognizer.sml`; this report. Parent owns the shared checker
and its tests; the dispatcher lane owns dialogue grounding and follow-up tests.
