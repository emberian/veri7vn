# Default composition and ordinary Math requests

The normal dispatcher, with all registered family heads, Fusion, Math,
Wordprob, relations, documents, code and dialogue enabled, passes **14/14**
independently authored focused controls. No `--organs`, `--specialist`, or
`--no-*` option was used. This is a selected composition check, not a complete
head or specialist-panel score.

The first run passed 13/14. “Please solve 3(x - 2) = 9 for x.” missed the Math
reader and reached an unrelated document refusal about 3. The repair accepts
one anchored task preface: `please`, or `can/could/would you` with optional
`please`, only immediately before `solve/find/calculate/compute/evaluate`.
The remaining equation or expression must still parse completely. Reply
request_text remains the original complete request, and original typed AST
checking and independent replay are unchanged.

Guards reconstructs the same finite equation surface for its G5/P2 features.
This is untrusted feature recognition, not certificate verification or a new
HOL premise. No theorem statement, kernel, ordering policy or Python dispatcher
implementation changed. Existing guard coverage remains 20 of 87 codes.

The final controls include affine unique/all/none outcomes, rational closed
powers, undefined arithmetic refusal, equal-time versus equal-distance trips,
unspecified weighting refusal, mixed-unit legs, mixed-unit geometry, ordinary
unit conversion and polite task wording. They exercise distinct real paths:
Math for equations/powers, Wordprob for trips, Fusion for rectangle area, and
the units-v3 specialist for 2.5 metres to 250 centimetres. Dialogue solves
x=-3/2 and then cubes x to -27/8 through the checked closed-expression route.

Evidence:

- `var/runtime-routes/default-composition/baseline.json`: 13/14, including the
  concrete document fallthrough failure.
- `var/runtime-routes/default-composition/final.json`: 14/14, all before/after
  hashes stable. It records the complete requests, replies, stages, registry,
  runtime sources and every available registered binary hash.
- Three new request-phrasing test methods pass: eight checked answers including
  all/none and closed expressions, five trailing/invalid input refusals and
  three incidental-assignment fallthroughs. Every successful answer retains
  exact original request binding and independent evidence consistency.
- All eight route methods pass, including the 114 historical guard fixtures.
- Math native manifest:
  `var/mathorgan/native-attempts/20261018T100548Z-1fd38381ec0d/compile-inputs.json`;
  SHA-256 `14df5dd3775d0c130fc8d684f5c8da30d50fb4a06812f9d39b45ae0908285851`.
- Guards native manifest:
  `var/guards/native-attempts/20261018T100544Z-24970f0d6b61/compile-inputs.json`;
  SHA-256 `003313aa4c387b478c2331d9ec3ee2c62addaa5a1cde00758f13d58837701e46`.

Both native builds use the already-passed unchanged proof exports. No new
Isabelle build, Linux compilation or broad suite was run. No jobs remain.

Changed files: `src/extract/mathorgan/{affine.sml,test_request_phrasing.py,
README.md}`, `src/extract/guards/recognizer.sml`, this report, and the factual
completion note in `project/lanes/F-runtime-closed.md`.

A useful next capability is an explicitly named scalar variable in affine
requests. `Solve 3t + 2 = 11 for t.` currently refuses because only x is
supported; receipt `var/runtime-routes/default-composition/next-variable.json`.
A coherent extension would carry the selected variable through the typed AST,
normalization theorem, independent replay, reply and dialogue binding. It
should still refuse multiple unknowns and incidental assignments. This is a
proposal, not an implemented capability or permission to weaken the existing
checked-packet contract.
