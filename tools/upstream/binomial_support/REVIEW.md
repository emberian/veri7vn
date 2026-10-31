# Independent source review — 2026-10-31

**Approved for the scoped upstream follow-up; no blocking finding.** Astra
reviewed the patch, portable tests, panel comparison code, pins, README, draft
PR body and the retained patched v2 source. No tests or other execution checks
were run by this review lane; reported results belong to the supplied receipts.

Final punctuation-refinement pass reviewed the frozen patch and eight-method
portable test source identified in `pins.json`:

- Patch SHA-256: `062794782482e9bcae8c52ce824d686ddf54ef6fe735ace617f6fb315b788adf`
- Test SHA-256: `0ebc582c2c07f4c051bc211dce579570e929f27e8f859ae4497ab1183a896df6`
- Three patched v1 copies: `b6fbab66f2abde01632176b1f55bf838f28159d1b2b44b926182bab8457d3788`
- Two patched v2 copies: `8c6cf096e70d85cfb8bef90449446dca5dccdc50aee12b123b393e60c3a33399`

These are the author/pin identities reviewed, not independently recomputed
hashes. No blocking issue found in the final refinement.

The mathematical change is correct: a valid binomial event with k>n has mass
zero. All three v1 copies and both v2 copies validate probability and complete
nonnegative integer counts before taking the zero branch. Thus invalid p cannot
be rescued by an impossible success count. In particular n=0, k>0, p=1 returns
before `(1-p)**(n-k)` could evaluate a negative power. Within-support evaluation
and the existing probability decoder are unchanged. V3 inherits the local
patched implementations.

The count regex consumes signs and the whole non-whitespace token. Its left
boundary prevents restarting inside `-3`, `3.5`, `3e2` or `3/2`; full-match
integer admission then rejects those unsupported tokens. The v1 combined
expression and v2 separate captures preserve their group roles. Plus signs and
negative zero are intentionally admitted when their integer value is nonnegative.
The five source hunks consistently apply the same policy.

The final refinement fixes the earlier ordinary-punctuation coverage regression.
The token captures leading parentheses; admission removes one terminal comma,
then only leading `(` and trailing `)`, before full integer validation. Thus
`exactly 2,`, `(3 trials)` and `(3) trials` retain their integer atoms. Interior
punctuation is not deleted: `(3/2)`, `(3.5)`, `(3e2)`, `(2+3)`, `(2)*3`,
`(3)/(2)`, `3e(2)` and `3,5,` still fail integer admission. `(-3)` retains its
negative sign and is refused. This is delimiter handling, not general expression
evaluation or a proof that arbitrary prose has only one reading.

The eight new test methods cover every class entrypoint, both support boundaries,
probability roles, invalid probabilities, malformed counts and signed integer
counts. Positive comma/parenthesis controls exercise within-support and
outside-support events; decorated malformed tokens and compact expressions are
separate negative controls, retaining the old malformed-count cases.
Bernoulli-sequence enumeration with Fraction weights is independent of
the implementation's combination formula, including the empty n=0 sequence.
The malformed-count cases expose real old false answers rather than preserving
them as expected behavior. The panel comparator uses the shipped scorers and
records unchanged replies separately from correctness/decline counts.

Pins identify separate exact slim/full revisions and identical corresponding
source hashes; the retained apply receipt agrees with those pins. The README
and PR body distinguish the reported eight new/five existing test
passes and 860 unchanged panel replies per tree from whole-head or six-criterion
admission. This source review does not independently regenerate those receipts
or hashes. Routing limitations and the dependence gate are explicit.

No Isabelle, SML, extracted binary, theorem statement, generic math reader or
combination/permutation operation is changed. The narrower extracted binomial
boundary remains clearly documented; the Python fix makes no new formal or
extreme-tail accuracy claim.
