# Chemistry: stated reactions, limiting amounts and theoretical yield

The executable now calculates yield and leftovers for explicitly supplied balanced reactions. It preserves all **1,206/1,206 shipped results**, with zero wrong answers or false affirmatives. The new authored reaction challenge scores **110 right / 0 wrong / 12 withheld-valid**; its separate safety-policy checks pass **122/122** directly and through the scoped dispatcher. These authored cases are development evidence, not an independent held-out panel.

## What a user can ask

```text
2 H2 + O2 -> 2 H2O; 4 mol H2, 1 mol O2; yield H2O in grams
2 H2 + O2 -> 2 H2O; 4 mol H2, 1 mol O2; leftover H2 in mol
```

The first returns 36.03 g theoretical yield; the second returns 2 mol H2 left. Coefficients must be positive integers (omitted means one), every reactant must have one named amount, and the formula/coefficient lists must conserve every element. The reader uses three semicolon-separated clauses, mol or mmol inputs, and mole or gram outputs. It binds reordered amounts by species, preserves complete formulas and exact fractions/decimals/scientific notation, and never selects a single ingredient from an incomplete reaction to answer a different question.

This assumes complete conversion of the limiting reactant. It does not establish reaction occurrence, equilibrium, kinetics or measured yield. Formula parsing, numeric role binding, unit conversion and requested-species selection remain ordinary untrusted SML. The checked kernel owns balance, input-domain checks, the limiting extent, and answer arithmetic.

## Checked statements and executable connection

- `balanced_reaction lhs rhs` implies `side_atoms e lhs = side_atoms e rhs` for every element `e`, including elements absent from both sides.
- A successfully parsed side contains known elements, distinct element keys within each formula, positive atom counts and positive reaction coefficients.
- A valid feed is nonempty, with positive coefficients and nonnegative mole amounts. Its computed extent is feasible: nonnegative and unable to consume more than any supplied amount.
- Any other feasible extent is at most the computed extent.
- At least one valid feed row has zero leftover, and every computed leftover is nonnegative.
- A successful checked reaction binds parsed sides to the supplied formula lists, requires one amount for each left-side row, and binds those coefficients and amounts to the feed.
- An answered public `RS` request has an actual successful checker result and requested value, conserves every element, uses a greatest feasible extent, and exhausts a feed. The mole-yield renderer is additionally bound to extent times the requested product's coefficient.

The initial consumption model requires distinct element-count compositions across both sides. The executable guard uses a count vector over the complete element table. This conservatively withholds catalysts, spectators, duplicate formula aliases and ambiguous equal-composition species; it does not claim that equal compositions establish chemical identity. Without the guard a catalytic feed could falsely limit the calculated reaction.

Final hbox proof receipt: `var/chemistry/remote-attempts/20261018T082626Z-502262086ce7/receipt.json`: **89 theorems, zero oracles**, expected marker and export. The public reaction certificate and independent conservation/bottleneck laws are included in the final scan. Earlier failed attempts concerned the ROOT subdirectory declaration, proof decomposition and a missing default order on string lists; the final model uses no added axioms or proof escapes.

## Actual consumer evidence

| Exact specialist ID | Shipped dev | Shipped held-out | New reaction right / wrong / withheld-valid | New reaction policy checks |
|---|---:|---:|---:|---:|
| chemistry | 225/225 | 281/281 | 55 / 0 / 6 | 61/61 |
| chemistry-v3 | 225/225 | 281/281 | 55 / 0 / 6 | 61/61 |
| decay | 42/42 | 42/42 | No new reaction capability | — |
| labsolutions | 28/28 | 27/27 | No new reaction capability | — |
| labsolutions-r2 | 28/28 | 27/27 | No new reaction capability | — |

The reaction challenge contains 78 correct computed answers, 32 correct invalid/underspecified refusals and 12 valid-but-unsupported withholds. It covers seven distinct reaction forms, requested yield/leftovers, gram output, zero feeds, limiting ties, reactant/product reordering, coefficient scaling, and an independently calculated Fraction grid. Controls include malformed formulas, unbalanced equations, missing/extra/duplicate quantities, forged numeric markers, negative amounts, catalysts and formula aliases. The 12 withheld-valid cases include gram inputs, kilogram outputs, initially present product, and overlapping/duplicate compositions.

The D interpretation regression still passes 138/138 policy checks, with its separately reviewed capability score of 118 right / 0 wrong / 20 withheld-valid. Its exact per-specialist accounting is in `D-chemistry.md`. No valid unsupported refusal is counted as a newly correct capability.

Reports under `var/chemistry/stoich/`:

- `e-panels.json`: shipped panels, using their existing scorers.
- `e-reactions.json` and `e-composed-reactions.json`: 122 direct/composed reaction policy checks and expectation classes.
- `e-correctness.json` and `e-composed-correctness.json`: existing 138 direct/composed interpretation policy checks.
- `d-expectation-review.json`: retrospective D classification; original receipts preserved.

Composition runs the actual front dispatcher with `--organs chemistry --specialist ID --no-reader --no-routes`. Positive reaction results are accepted at the specialist stage with their exact new kinds. The capability sidecar describes the model and untrusted boundaries; the declaration is not itself a proof of interpretation.

## Reproduction and compiler inputs

```sh
tools/dev/remote-build hbox src/extract/chemistry Veri7vn_Chemistry -d src/extract/commons --expect 'VERI7VN_CHEMISTRY PASS'
CHEM_GEN=var/chemistry/remote-attempts/20261018T082626Z-502262086ce7/results/export/Veri7vn_Chemistry/Veri7vn_Chemistry.Chemistry_Export/code/chemistry.ML sh src/extract/chemistry/build.sh
python3 -B src/extract/chemistry/score.py --specialist-mode-only --out var/chemistry/stoich/e-panels.json
python3 -B src/extract/chemistry/stoich/check_reactions.py --out var/chemistry/stoich/e-reactions.json
python3 -B src/extract/chemistry/stoich/check_reactions.py --dispatch --out var/chemistry/stoich/e-composed-reactions.json
```

Managed native receipt: `var/chemistry/native-attempts/20261018T083140Z-007ea0f03a26/compile-inputs.json`. Binary SHA-256: `488cf06decf66fc787c28b416d8791a52859b188cd4c0edc5881fccd55c67582`. Generated kernel SHA-256: `c8f4da91a7221bb0e19ac44678d6948b99200a72dcd7db2c890c88da98c0143e`. Shared numeric SHA-256 remains `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.

Changed source: `stoich/Stoichiometry.thy`, `Chemistry_Export.thy`, `ROOT`, `recognizer.sml`, `main.sml`, `capabilities.json`, `README.md`, and `stoich/check_reactions.py`. `stoich/check_correctness.py` and `D-chemistry.md` also gain explicit capability-versus-policy accounting.

## Remaining work by specialist and next model

Chemistry and chemistry-v3 still lack general kilogram-to-mole conversion, charged formulas, automatic balancing, inferred excess, alternate reaction punctuation, gram reaction inputs and kg outputs. Decay retains mixed-time/amount-unit and inverse-half-life limitations. Both labsolutions IDs retain some valid zero-quantity withholds and lack multiple-solute/multiple-solution aggregation.

The next reaction extension should aggregate coefficients by explicit supported species identity, then use net consumed coefficients for the limiting extent. Element counts remain solely the balance check: equal compositions do not identify ethanol and dimethyl ether. Repeated syntactically identical named species may combine; distinct structural formula spellings must not be equated merely because atom counts match. A catalyst with equal coefficients on both sides has zero net consumption and cannot be the bottleneck. The model must distinguish newly formed product from final amount when product is initially present. This is follow-on work, not a capability of this executable.
