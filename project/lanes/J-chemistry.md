# Chemistry J — physical reaction inventories and requested yield units

**Root integration update:** J is now the live chemistry implementation. Root adopted the frozen packet after the drain, reused its checked proof, and compiled it against the current checkout. The original staging record below remains historical evidence; the new integration receipt is `var/root-chemistry-j/integration.json`. No additional proof build was needed.

## What it does

The explicit reaction reader retains each named inventory's unit and the requested result unit. The kernel converts the inventories to moles, runs the existing net-species balance and limiting-extent calculation, then scales only the checked result to the requested unit. It accepts mol, mmol, micromoles, and grams, milligrams, kilograms, and micrograms, including mixed units and zero inventory. For example, `2 H2 + O2 -> 2 H2O; 4.032 g H2, 31.998 g O2; yield H2O in kg` returns 0.03603 kg.

Spectators retain their inventory and do not limit extent; existing product inventory contributes to the final inventory, separately from newly formed yield. Formula spelling after supported syntactic normalization remains the species identity. Equal element counts do not establish that two names are the same species.

## The proved claims

- If an inventory converts successfully, its supplied quantity and normalized mole quantity are nonnegative, its formula parses with positive molar mass, and **moles × units per mole = supplied quantity**. In the mass case, **moles × molar mass = supplied mass × grams per supplied unit**.
- Normalization retains the inventory names and associates every supplied inventory with its exact converted quantity.
- An affirmative measured-reaction reply has a successful normalized inventory and checked net reaction, an exact selected mole result, and a positive output scale. Its displayed numeric value is the checked result times that scale; dividing the exact scaled value by the scale recovers the mole result. The public `reply_of` theorem binds this to the executable answer interface.
- The affirmative reply also carries the existing balance and limiting certificate: every element is conserved across the equation and final inventory; extent is feasible and greatest among feasible extents; at least one net reactant is exhausted; every final species inventory is nonnegative.

The final managed persvati proof attempt `20261018T103520Z-77455a5b9222` passed with **142 scanned theorems, zero oracles**. Its receipt is under the staged checkout `var/chemistry/next-reaction-units/proof-inputs-20261018T103452Z/var/chemistry/remote-attempts/20261018T103520Z-77455a5b9222/receipt.json`. The earlier `ddcbef7c21d4` attempt failed at three local proof scripts; the final retry retained the statements and supplied the proper algebraic simplification, explicit witnesses, and theorem arguments. No further proof retry was made.

## Consumer results

All **1,206 shipped cases are right, with zero wrong, zero false yes, and zero withheld-valid**, using their own scorers:

| Specialist | Dev right / total | Heldout right / total |
| --- | ---: | ---: |
| chemistry | 225 / 225 | 281 / 281 |
| chemistry-v3 | 225 / 225 | 281 / 281 |
| decay | 42 / 42 | 42 / 42 |
| labsolutions | 28 / 28 | 27 / 27 |
| labsolutions-r2 | 28 / 28 | 27 / 27 |

The new 342 authored physical-reaction cases pass all policy assertions both directly and through the actual staged Dispatcher: **334 right, zero wrong, eight withheld-valid**. Each chemistry ID has 167 right and four withheld-valid. The exact same panel on predecessor I had 22 right, zero wrong, and 320 withheld-valid. These are development probes, distinct from shipped completion numbers.

The prior 196 net-reaction cases also pass all policy assertions directly: 180 right, zero wrong, 16 withheld-valid. The gram-inventory and kg-output cases now expect their numerical answers. A request for a species absent from the equation is classified as withheld-valid, rather than counted right merely for refusing it. Historical panel labels are retained in their earlier evidence, not silently rewritten.

Evidence is in `var/chemistry/next-reaction-units/`: `j-panels.json`, `j-units-direct.json`, `j-units-composed.json`, `j-net.json`, and `i-baseline.json`. `staged-dispatch-inputs.json` pins the actual copied dispatch/registry/sidecar/arbiter/native inputs. The capability sidecar expands the explicit reaction context to supported mass units, with existing answer kinds retained.

## Frozen staged artifact and remaining boundary

The single successful staged native compile manifest is `var/chemistry/native-attempts/20261018T104334Z-224f039d165f/compile-inputs.json`. It is explicitly **receipt_snapshot**, not a current-checkout claim. The binary is `1680f709301d12047bbd1f8604f073f85c04af1604dc9e85e89636bde64b0679` under the stage’s `var/chemistry/bin/chemistry`.

`var/chemistry/next-reaction-units/j-ready.json` binds the nine proposed files, modes, proof/native receipts, binary, and evidence. `ready-files.json` maps those destinations to the frozen staged sources. Nothing has been promoted over I. Future adoption must validate the I baseline, preserve destination modes, compile through the managed current-checkout receipt validation, and capture the exact consumer inputs. `build.sh` is not part of this packet and remains executable.

The reader still uses the explicit three-clause reaction/inventory/query grammar. Rates are not inventories. Unsupported units, repeated inventory batches, unknown query species, and unresolved formula aliases/isomers remain withheld. Complete limiting-reactant conversion is a supplied model assumption; this does not establish reaction occurrence, kinetics, equilibrium, or actual experimental yield. Atomic masses are the embedded supplied decimals. Text recognition, unit/name binding, and authored probes are untrusted boundaries.

The lane is drained: no running jobs, no further successor or retries, no pending live mutation. Root owns future integration.


## Root adoption after drain

Current-checkout compile `20261018T111952Z-db46d7f92800` reproduced the exact
staged native `1680f709…`; verifier reports no proof or runtime differences.
Root inspected the positive-scale, quantity-conservation, normalized-name and
net-conservation statements and their public `reply_of` connection. All frozen
packet/evidence hashes and predecessor I source/native hashes matched before
adoption. The eight source files retain their recorded modes.

The exact-native shipped result remains1206/1206, with zero wrong/false yes.
It was not redundantly rerun: the rebuilt native is byte-identical. Current
scoped Dispatcher composition freshly passes342/342 assertions:312 numerical
answers,22 correct invalid refusals, and8 valid requests withheld. The report's
334 right includes those22 invalid refusals. Root's independent methane panel
adds14 numerical answers and4 invalid refusals across both chemistry IDs.
Initial root tolerance was too strict for the documented four-significant-digit
interface; exact Decimal half-up display expectations now pass, and the initial
observations are retained. Seven selected fresh requests also pass through the
actual full default Dispatcher:five numerical answers andtwo invalid refusals.

Evidence and exact consumer hashes are under `var/root-chemistry-j/`.
An immutable source/export/native capture is at
`var/C-runtime-package/bound-prepared/20261018T111952Z-db46d7f92800/chemistry`.
The current checkout still contains unrelated preserved drafts. These chemistry
checks do not certify them. Linux comparison and selected portable archive
refresh remain pending; the fixed-cohort delivery record has not changed.
