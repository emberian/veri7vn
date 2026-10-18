# Discrete H: complete propositional requests and bounded tables

Ready for integration after G commit `8c6800a`. The public `logic-v3` consumer,
native discrete family and actual front dispatcher use the checked kernel.
Linux packaging for this exact candidate is pending.

## Behavior

The preceding recognizer answered `Is p |- p and q valid?` as valid and
`Is p and q |- p valid?` as invalid. Its symbolic substring extraction dropped
word operators or parts of premises/conclusions. It could also discard unknown
text after a supported expression.

The replacement consumes the entire formula, every comma/semicolon-separated
premise, and the entire conclusion. Unknown text and empty entries refuse.
A genuinely empty premise set remains supported. Word and symbolic operators
can mix, Unicode operators work, and a single variable is a contingent formula.
Only complete recognized question wrappers and named-form templates are removed;
extra instructions and additional questions refuse instead of being ignored.

Precedence, highest first: negation, conjunction, disjunction, implication,
equivalence. Implication associates right; equivalence associates left. Variables
are case-insensitive single letters. These conventions are parser assumptions,
not an English-interpretation theorem. Quoted/backtick formulas are accepted as
whole expressions. Named natural-language forms remain six bounded templates.

The kernel itself checks the number of distinct variables before enumerating
assignments. Up to 12 variables means at most 4096 rows. Larger valid requests
receive a decisive unsupported refusal and count as withheld-valid. This bounds
row count, not AST size or elapsed runtime; no claim of general resource safety
is made. Quantifiers, XOR, compound requests and conditional English modifiers
remain unsupported.

## Checked statements connected to the actual kernel

New statements:

```
l_kernel (L_formula f) = LClass c t n ⟹ t ≤ n ∧ n ≤ 4096

l_kernel (L_argument ps c) ≠ LUnsupported ⟹
  length (envs (avars ps c)) ≤ 4096
```

The guard is in `l_kernel`, before `classify`, row counting or counterexample
search. Existing universal semantics are retained and rechecked:

```
l_kernel (L_formula f) = LClass c t n ⟹
  (c = Taut ↔ (∀g. eval g f)) ∧
  (c = Contr ↔ (∀g. ¬ eval g f)) ∧
  (c = Conting ↔ (∃g. eval g f) ∧ (∃g. ¬ eval g f))

l_kernel (L_argument ps c) = LValid n ⟹
  ∀g. (∀p ∈ set ps. eval g p) ⟶ eval g c

l_kernel (L_argument ps c) = LInvalid row ⟹
  ∃e. row = row_of (avars ps c) e ∧
      (∀p ∈ set ps. eval e p) ∧ ¬ eval e c
```

`l_reply_answered` now excludes both unparsed outputs and `LUnsupported`.
The static capability/theorem list is a declaration, not a per-answer proof.

## Evidence

- Proof `var/discrete/remote-attempts/20261018T101104Z-1a31e3f1b4f5/receipt.json`
  passed on the first attempt: actual `Finished Veri7vn_Discrete (0:01:25 elapsed
  time)`, `VERI7VN_DISCRETE PASS theorems=92 oracles=0`. Export SHA-256:
  `ad69dabf3f1684ac40165aaa25e72111197cce420244a9f9e16bb344daef563f`.
- Final shared-helper manifest:
  `var/discrete/native-attempts/20261018T101407Z-a6e706e9d5a1/compile-inputs.json`.
  Its immutable sibling `binary` and published native SHA-256:
  `93e72f594cd2f4694d0c8ddb9cb00e1632a1c849a3813afd5f5d9e1fe94b87eb`.
  `var/discrete/h/native-closure.json` verifies 5 frozen compiler inputs and
  12 proof dependencies against current source; no differences or errors.
- `logic_probes.py` independently enumerates Boolean assignments for authored
  ASTs. It checks exact true/total counts and evaluates every returned invalid
  argument assignment against all original premises and conclusion. Random
  formulas, full premise lists, empty premise sets, mixed operators, precedence,
  Unicode, quoted requests and 12-variable boundary cases are included.
- Final development seed 181401: **242/242 policy/value assertions**:
  **224 answered-correct, 0 wrong, 13 withheld-valid**; **5 ambiguous/undefined
  requests all refused**. `var/discrete/h/after-final.json`.
- Actual dispatcher pinned and unpinned: **242/242 each**, identical semantic
  outcomes; expected refusals remain decisive. Scope `--order front --organs
  discrete --no-reader --no-document --no-routes`.
  `var/discrete/h/dispatch-pinned.json`, `dispatch-unpinned.json`.
- Untouched post-freeze authored seed 181447: **242/242**, same outcome counts.
  `var/discrete/h/heldout.json`. Fresh ASTs are independent of tuning; generated
  language templates are authored with this change, not independent-language
  evidence.
- Baseline G native on the same non-budget subset: **119/238 assertions**;
  of 233 meaningful requests, **117 correct, 14 wrong, 102 withheld**. Five
  ambiguous/undefined requests: 3 answered and 2 withheld.
  `var/discrete/h/before-final.json`. Four over-budget requests are excluded
  from baseline comparison: an initial all-case old-native run was interrupted
  while evaluating the large table; no timing/result claim is made for it.
- First H native `1d799868` passed 221/222 earlier assertions but wrongly
  withheld an argument concluding variable `a`: the suffix mistook `a` for
  an English article. Tightening that grammar and adding explicit `a`-conclusion
  cases produced the final native above. The proof/export did not change.
- Supplied own scorers: **508/508 in each specialist/family mode**, **0 wrong,
  0 false yes, 0 withheld-valid**. Logic is 33 dev + 12 heldout; games 51+18,
  formats 93+93, algorithms 42+42, calculus 62+62. These scorer totals include
  their expected refusals. `var/discrete/h/shipped-final.json` and `.log`.
- Supplied logic generator/scorer development seeds 181401/181409: **90/90**;
  untouched post-freeze seed 181453: **45/45**, all zero wrong/false-yes/
  withheld-valid, equal to shipped organ. `var/discrete/h/fresh/report.json`
  and `heldout-fresh/report.json`. Shared generator templates remain a limit.
- Native 942,168 bytes; authored median kernel time 0.041 ms, largest observed
  13/26-variable refusal 0.142 ms. Five measured warm process launches
  3.87, 3.76, 3.34, 3.54, 3.48 ms. No uncached-start claim.
  `var/discrete/h/performance.json`.
- Capability validation and scoped `git diff --check` pass.

## Changed paths

`src/extract/discrete/Disc_Logic.thy`, `Discrete_Export.thy`, `recognizer.sml`,
`main.sml`, `capabilities.json`, `logic_probes.py`, `README.md`, and this report.
No shared source or upstream path was edited.

## Per-specialist review boundary

| Exact specialist ID | This packet's examination and remaining limit |
|---|---|
| `logic-v3` | Complete formula/premise consumption, semantics and returned counterexamples, full wrappers, bounded tables. General English, quantifiers, XOR and AST-size bounds remain outside this packet. |
| `algorithms` | G full rational graph/list behavior retained; Kruskal certification completeness, complete negative-edge search and complexity-request grammar remain open. |
| `dataformats` | F raw bytes and signed complete-token conversions retained; no new formats capability claim. |
| `games-v3` | E actual finite dice-sequence semantics and card counts retained; no new games claim. |
| `calculus` | D complete ordinals retained. Independent-variable constants and the unverified analytic integral draft under `var/discrete/codex/integral-draft/` remain open. |
