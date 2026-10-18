# Wave 6: make the theorems bind (from the A1 theorem audit, 2026-10-17)

Lane A1 read all 2,234 theorem and lemma statements and sorted them by what they
promise ([`docs/assurance/theorem-audit.md`](../../docs/assurance/theorem-audit.md)).
Of the 1,725 that claim something, 1,079 (63%) bind the code to something
independent of it, 471 (27%) restate the code, 15 are empty, 26 lean on a flag the
untrusted fetch sets, and 134 are worked examples. Three sessions print PASS
without refusing oracles (guards, specialists, reader), and 109 headline theorems
are missing from their family's scan. Wave 6 is one fix lane per family (two for
computing and facts), each adding the binding theorems the audit proposes for it.
Machine-readable copy: [`wave6.json`](wave6.json).

Every lane is done on the same kind of number: *N binding theorems added, vacuous 0,
unscanned 0, marker last with oracles=0, panel replies unchanged* (harness diff 0
on every specialist panel of the family). A theorem that turns out false of the
current kernel is reported with its counterexample before the kernel is touched.

## Lanes

| Lane | Tier | Size | Start from | Done when |
|---|---|---|---|---|
| W6-01-quantity-acoustics Cross-kind laws for quantity and acoustics | sonnet | S | dev | 6 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) |
| W6-02-anatomyagri Exact declines and grounded constants for anatomyagri | sonnet | M | dev | 3 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) |
| W6-03-chemistry Parser soundness and cross-kind laws for chemistry | sonnet | M | dev after lane B-chemistry lands (it is editing src/extract/chemistry/) | 3 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) |
| W6-04-climate Climate: drop two vacuous theorems, AQI monotone | sonnet | S | dev | 3 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) |
| W6-05-computing Computing: timer bound, scan the 44 | sonnet | M | dev | 2 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) and 44 more theorems in the scan |
| W6-06-computing-sql SQL select against a relational specification | opus | L | dev after W6-05 lands (same session) | 1 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) |
| W6-07-discrete MST minimality and exact declines for discrete | opus | M | dev | 3 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) |
| W6-08-document Document route: anchor and release computed in HOL | sonnet | M | dev after W5-18 lands (document captures) | 3 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) and the document's 231 core items unchanged (tools/document/measure.py) |
| W6-09-earth Earth: explicit declines, symmetry, scan the 7 | sonnet | S | dev | 3 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) and 7 more theorems in the scan |
| W6-10-emoptics Emoptics: exact resistor decline, parallel bound | sonnet | S | dev | 3 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) |
| W6-11-energy Energy: cross-kind laws, one exact-soundness fact per sub-family | sonnet | S | dev | 3 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) and the definitional count down by at least 10 |
| W6-12-facts-tables Facts: the organ tables as a checked equality | sonnet | M | dev | 22 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) (21 table equalities plus the sentence theorem) |
| W6-13-facts-guards Facts: guards with a HOL meaning | opus | L | dev after W6-12 lands (same session) | 1 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) for at least one store, its panel unchanged |
| W6-14-finance Finance: say what the real-rate kernel computes | sonnet | S | dev | 3 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) |
| W6-15-geostats Geostats: negative lengths, complete modes | sonnet | M | dev | 3 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) |
| W6-16-guards Guards: vectors without eval, guards as narrowing folds | sonnet | M | dev | 2 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) and 114 vectors proved without an oracle, Guards_Vectors before Guards_Export in ROOT |
| W6-17-humanities Humanities: exact silence, round trips | sonnet | S | dev | 3 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) |
| W6-18-life Life: explicit declines, model laws tied to e_phys | sonnet | M | dev | 2 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) |
| W6-19-materials-mechanics Materials and mechanics: cross-kind laws | sonnet | S | dev | 6 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) |
| W6-20-readers Relation readers: coverage against a store snapshot | opus | M | dev | 2 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) and Veri7vn_Reader's 18 theorems scanned; relations 16,284 right / 0 wrong unchanged |
| W6-21-isabelle-sessions Routing and specialists sessions: scans and eval | sonnet | S | dev | 2 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) and Veri7vn_Specialists' 25 theorems scanned with 0 by eval |
| W6-22-space Space: explicit declines, Hohmann delta-v | opus | M | dev | 3 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) |
| W6-23-stores Stores: completeness computed in HOL | sonnet | M | dev | 3 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) |
| W6-24-trades-wordprob Trades and wordprob: symmetry, involution, no vacuous values | sonnet | S | dev | 6 binding theorems added (statements as in the audit or stronger), vacuous count 0 in the family, unscanned theorems 0, PASS marker last with oracles=0, panel replies unchanged on every specialist panel of the family (harness diff 0) |

## Deferred

- **fusion-error-propagation**: fusion 1-3 (L, opus): optional; fusion is already among the strongest families
- **routing-full-catalogue**: routing 3 (L, opus): needs the 346 folds encoded first (lane B's catalogue)

## Order

W5-12 has landed; start any lane whose start_from is plain dev. W6-03 waits for lane B-chemistry, W6-06 for W6-05, W6-13 for W6-12, W6-08 for W5-18.

W6-01, W6-08, W6-20 and W6-21 edit paths LANE_BRIEF.md reserves to their
original lanes (`src/extract/quantity`, `acoustics`, `src/isabelle/*`); root
grants the transfer when it launches them.

## Common brief

Each lane's brief in `wave6.json` starts with the same paragraph: read the audit's
section for the family and the class rules, add the proposed theorems (restated if
a constant differs, never weakened into a restatement of the code), replace the
vacuous ones, scan every headline theorem, keep the marker last, and leave every
panel reply unchanged. Box safety is LANE_BRIEF.md's, quoted in every launch.
