# Chemistry I — mass-defined concentration prefixes and bounded zero stock

This follows H (`f6d8720`, with executable build entry point restored in `f3e38dc`). H already answered directed dilution and preserved gram/mole/volume units. It withheld valid mass-defined concentration requests in mM or micromolar, and the zero-stock/zero-target/zero-final-volume corner. This packet carries both through the checked solution model.

## What the model proves

For a successful mass-defined concentration request, some parsed formula has positive molar mass; the supplied mass is nonnegative and solution volume is positive. The exact result satisfies **concentration × volume × formula molar mass = supplied mass × grams per supplied unit**. Output M, mM, or micromolar scales the displayed value, while the public reply theorem binds affirmative replies to this successful exact model result.

The stock calculation preserves **stock concentration × stock volume = target concentration × final volume**, with stock volume between zero and final volume. A zero stock concentration is accepted only when target concentration and final volume are both zero, returning zero stock volume. Uniqueness explicitly ranges over other volumes between zero and final volume. For a positive final volume and zero stock/target concentrations, the requested stock volume is still underdetermined.

## Evidence

The managed hbox proof attempt `20261018T100815Z-127dd0369e4a` passed with **133 scanned theorems and zero oracles**. Its exact staged receipt is `var/chemistry/next-solution-complete/proof-inputs-20261018T100804Z/var/chemistry/remote-attempts/20261018T100815Z-127dd0369e4a/receipt.json`. The public reply theorem and both new laws are in the scan.

The shipped panels, scored by their own scorers, remain **1,206 right, zero wrong, zero false yes, zero withheld-valid**:

| Specialist | Dev right / total | Heldout right / total |
| --- | ---: | ---: |
| chemistry | 225 / 225 | 281 / 281 |
| chemistry-v3 | 225 / 225 | 281 / 281 |
| decay | 42 / 42 | 42 / 42 |
| labsolutions | 28 / 28 | 27 / 27 |
| labsolutions-r2 | 28 / 28 | 27 / 27 |

The authored 174-case mass-concentration panel scores **170 right, zero wrong, four withheld-valid**, with all 174 policy assertions passing, both directly and through actual staged dispatch. Each lab ID has 85 right and two withheld-valid. On these exact same cases, the immutable predecessor H binary scored **68 right, zero wrong, 106 withheld-valid**. These are development probes, separate from the shipped metric.

The existing authored solution-role panel improves to **130 right, zero wrong, 16 withheld-valid** (146 policy assertions pass), 65 right and eight withheld-valid per lab ID. The 124 zero-domain cases all remain right; the 181 mass-unit cases retain 169 right, zero wrong, 12 withheld-valid. These all pass both direct and composed checks. The prior reaction and domain panels also preserve their direct results: 178/0/18 on 196 policy cases and 118/0/20 on 138 policy cases.

Evidence is under `var/chemistry/next-solution-complete/`: `i-panels.json`, `i-{mass,solutions,zero,units}-{direct,composed}.json`, `i-net.json`, and `i-correctness.json`. The composed configuration pins the copied dispatcher, registry, sidecar, arbiter, and native binary in `staged-dispatch-inputs.json`.

## Boundary

The model uses the repository's exact atomic-mass table and assumes the named formula is the solute. It does not infer mixtures or charged species. Supported mass inputs are grams, milligrams, kilograms, and micrograms; concentration outputs are M, mM, and micromolar. Unsupported valid units count as withheld-valid. Negative quantities, zero concentration denominators, malformed numerals, and plain-quantity/rate mismatches must not produce affirmative replies.

Reaction mass inputs and mixed elapsed-duration sums remain outside this packet. Reaction feeds remain mole-based; syntactic formula identity is separate from elemental balance.

## Current-source integration

The current-checkout compile receipt is `var/chemistry/native-attempts/20261018T102034Z-f93346a47116/compile-inputs.json`. It validates the current proof closure against the passed staged receipt, with no differences and without the retained-snapshot override. Its binary is bit-identical to the staged binary: `2cd5db6261a7822152fc7a490d031e5646b09ab5e393f6c2fb7438481d2079fc`.

A fresh live-dispatch replay of the new 174 mass-concentration cases and the 146 solution-role cases also passes all 320 policy assertions, with the same capability counts. Results are `i-mass-live-composed.json` and `i-solutions-live-composed.json` beside the staged evidence. No capability-sidecar expansion was required; these use the existing molarity and dilution answer kinds.

`var/chemistry/next-solution-complete/i-live-ready.json` binds the exact eight changed files, their modes, proof/native receipts, binary, and evidence. Promotion validated the committed H predecessor and preserved existing destination modes; `build.sh` remains executable and was not rewritten. The changed files are Solutions.thy, Chemistry_Export.thy, recognizer.sml, main.sml, README.md, the updated check_solutions.py, the new check_mass_concentrations.py, and this report. Root owns the commit and runtime owns the immutable package capture.
