# Discrete G: complete rational lists and signed graph edges

Ready for root integration after F commit `c82b5fb`. Scoped proof, immutable
native compile, independent checks and actual dispatcher pass. Linux packaging
for this exact G candidate is pending.

## Concrete behavior and consumer

The preceding recognizer sorted `[1/2, 3, 4, 5]` as `[2, 3, 4, 5]`, and
`[1, 2, 3, 4/5]` as `[1, 2, 3, 4]`. It dropped `A-B(-1)` from a supplied
spanning-tree graph, then confidently reported the optimum of the remaining
graph. Graph/list kernels already use exact rationals; the loss occurred before
the typed request reached them.

The replacement consumes one whole list or an explicit `Edges:`/`Graph:` section.
Every comma-separated element or edge must parse; malformed entries cannot be
silently skipped. Signed integer/decimal/fraction weights are supported,
including signed denominators, while zero denominators refuse. Empty/singleton
lists are supported. Complete sort/search commands prevent extra lists or
transformations from being ignored. Graph names retain case, so `A` and `a`
are distinct. `->` and `to` are directed; `-` and `<->` are undirected. Directed
minimum-spanning-tree requests refuse because they do not specify an undirected
problem. Extra isolated-node declarations are currently unsupported.

Negative edges are mathematically legitimate. Dijkstra produces a candidate,
then the existing independent shortest-path checker either certifies a globally
shortest walk or refuses. This packet does not claim Dijkstra completeness on
negative-edge graphs. Kruskal output likewise passes the existing independent
spanning-tree/minimality checker before being stated; algorithm completeness
against that checker remains open.

The actual reply text now gives exact fractions rather than six significant
digits. JSON integers remain numbers; noninteger values become fraction strings,
including within sorted arrays. The public consumer is `algorithms` through the
native discrete family and actual front dispatcher. Static capability metadata
is a declaration, not an interpretation proof or per-answer certificate.

## Existing checked statements bound to the actual branches

No new algorithm theorem is claimed. These existing statements are rechecked
against the extended request/reply definitions and connected to complete inputs:

```
a_kernel (A_sort xs desc) = ASorted ys d ⟹
  d = desc ∧ (∀a. count_list ys a = count_list xs a) ∧
  (if desc then sorted (rev ys) else sorted ys)

a_kernel (A_mst es) = AMst t ⟹
  spans t es ∧ (∀t'. spans t' es ⟶ wt t ≤ wt t')

a_kernel (A_sp es n s e) = AShortest p d n' s' ⟹
  walk es s e p ∧ wt p = d ∧ (∀r'. walk es s e r' ⟶ d ≤ wt r')

a_kernel (A_bsearch xs x) = ABs i p ⟹
  sorted xs ∧ i < length xs ∧ xs ! i = x
```

The reply-answered characterization is updated for the new `AUnsupported`
decline branch. Exact fraction rendering is executable serialization with
independent runtime checks; it is not a new formal inverse-parser theorem.

## Evidence

- Authored baseline: `var/discrete/g/expanded-before.json`, 11/147 policy/value
  assertions. Of 141 meaningful requests: 9 correct answers, 75 wrong answers,
  57 withheld. Six ambiguous/undefined requests were all answered.
- Expected MST weights enumerate every size `n-1` edge subset and check its
  connectivity. DAG shortest weights enumerate paths. Sorting uses Python
  exact fractions. Language is authored with the implementation; this is not
  independent-language evidence.
- Negative-edge requests for which a candidate cannot be certified may pass a
  refusal-policy assertion but still count as withheld-valid. Undefined and
  ambiguous inputs are listed separately.
- Passed proof `var/discrete/remote-attempts/20261018T100108Z-1651d47b103d/receipt.json`:
  actual `Finished Veri7vn_Discrete (0:01:25 elapsed time)`,
  `VERI7VN_DISCRETE PASS theorems=90 oracles=0`. Export SHA-256
  `f8c3923b7fb5483036fe9c1e27dab1f2e69dcc57a32939f6aad289ec01d7cd2f`.
- Final shared-helper compiler manifest:
  `var/discrete/native-attempts/20261018T100419Z-8e58abdc793f/compile-inputs.json`;
  immutable sibling `binary` and published `var/discrete/bin/discrete` SHA-256
  `398cea7c46f7d86b30a2fee5ced12512222e300256f5393e2dd6a5e3445146c5`.
  `tools/dev/verify-native-inputs.py` verifies 5 frozen inputs, 12 proof
  dependencies and current runtime/proof identity; no errors.
  `var/discrete/g/native-closure.json`.
- Development seed 181301: **147/147 policy/value assertions**, comprising
  **132 answered-correct, 0 wrong, 9 withheld-valid** and **6 ambiguous or
  undefined inputs all withheld**. `var/discrete/g/after-final.json`.
- Actual dispatcher pinned and unpinned: **147/147 assertions each**, same
  semantic outcomes, exact fraction values preserved and every expected
  refusal decisive. Scope: `--order front --organs discrete --no-reader
  --no-document --no-routes`. `var/discrete/g/dispatch-pinned.json` and
  `dispatch-unpinned.json`.
- Untouched post-freeze seed 181337: **150/150 assertions**, comprising
  **135 answered-correct, 0 wrong, 9 withheld-valid**, and **6 ambiguous or
  undefined inputs all withheld**. `var/discrete/g/heldout.json`. The varied
  graphs/lists are fresh, but the authored language is not independent.
- Supplied specialists' own shipped scorers: **508/508**, both specialist and
  family modes, **0 wrong, 0 false yes, 0 withheld-valid**. In particular the
  algorithms panel is **42/42 dev and 42/42 heldout**. Games 51+18, logic 33+12,
  formats 93+93, calculus 62+62 remain green. `var/discrete/g/shipped-final.json`.
  The supplied snapshot has no algorithms generator; no supplied fresh-generator
  claim is made.
- First native `271aa5ef` passed the authored set but withheld 40 valid shipped
  heldout phrasings. Complete alternative graph/sort/search command forms fixed
  that regression without restoring substring recognition. Proof/export is
  unchanged across this recognizer-only refinement; it is not the final native.
- Final binary 943,448 bytes. Algorithms specialist median round trip 0.106 ms;
  first observed launch 257.94 ms, following launches 3.95, 3.83, 3.90, 4.16 ms. The first
  launch does not support a cached-start or all starts under 20 ms claim.
- Capability contract validation and `git diff --check` pass.

## Changed paths

`src/extract/discrete/Disc_Algos.thy`, `Discrete_Export.thy`, `recognizer.sml`,
`main.sml`, `capabilities.json`, `algorithms_probes.py`, `README.md`, and this
report. No shared source or upstream path was edited.

## Per-specialist review boundary

| Exact specialist ID | Behavior examined in this packet |
|---|---|
| `algorithms` | Whole lists/graphs, exact rational weights and values, direction, case-sensitive nodes, independent tiny-graph semantics. Kruskal certificate completeness, general negative-edge search completeness and the complexity-table request grammar remain open. |
| `dataformats` | F raw-byte and complete-command work retained; no new formats capability claim. |
| `games-v3` | E finite dice/card work retained; no new games capability claim. |
| `calculus` | D ordinals retained. Independent-variable constants and the parked analytic integral bridge remain open. |
| `logic-v3` | Word-operator/turnstile substring defects have concrete baseline receipts under `var/discrete/h/`; complete formula grammar and a bounded truth-table resource policy are the next separate packet. |
