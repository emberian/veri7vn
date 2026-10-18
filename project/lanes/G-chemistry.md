# G chemistry: preserve physical mass units

Staged work only. The live E source and binary are frozen pending root integration. This packet extends the already checked F net-reaction stage; neither staged packet has been promoted or tested through the production dispatcher.

The old reader treats some mass units as interchangeable by matching their first two letters. For a half-life of 10 days, `How long until 1000 milligrams decays to 500 micrograms?` answers 10 days, although the mass ratio is 1/2000. It also returns gram values when chemistry and solution-preparation questions request kilograms or milligrams. Molar-mass questions requesting kg/mol receive the g/mol value.

The replacement retains a typed mass unit in the request. Grams, milligrams, kilograms and micrograms have exact positive gram scales. The kernel performs the conversion; the reader binds complete numerals to roles and recognizes explicit unit aliases. Non-mass amount classes use explicit canonical identities, not shared prefixes.

## Source ancestry

E proof `20261018T082626Z-502262086ce7` establishes the initial checked reaction model. F proof `20261018T085454Z-e35b6b95a949`, under `var/chemistry/net/proof-inputs-20261018T085226Z/`, adds exact-name aggregation, net coefficients, spectators and final inventories. G starts from an ordinary copy of that exact F proof source; its overlays are listed in `var/chemistry/next-quantity/proof-inputs-20261018T090845Z/staging.json`. The F report remains `var/chemistry/net/F-chemistry.md`, and its checked `NetStoichiometry.thy` is unchanged in G.

All short artifact paths below are relative to `var/chemistry/next-quantity/` unless explicitly prefixed with repository `var/`. Exact base source digest: `0f305425dc0fcac304760f20b95029976115130206a5fc3112d3beb10aab9c08`.

## Consumer and statements

`Chemistry.reply_of (RM request)` calls `measured_reply`. Its variants cover mass-to-moles, moles-to-mass, molar mass, solution preparation, molarity from a measured mass, remaining radioactive mass, and inverse decay between two measured masses.

- Conversion conserves physical mass: `convert_mass q source target * grams_per_unit target = q * grams_per_unit source`. Conversion through an intermediate unit gives the same result as direct conversion.
- A successful inverse-decay fraction is strictly between zero and one, and multiplying it by the initial gram mass equals the final gram mass.
- An answered mass-to-moles request has a successfully parsed formula, nonzero molar mass, nonnegative input mass, and a stated value whose exact precursor satisfies `moles * molar_mass = input_quantity * input_gram_scale`.
- An answered mass output has a valid positive-mass formula and nonnegative mole amount; the stated value is the specified rounding of `moles * molar_mass / requested_gram_scale`.
- Molar mass and solution preparation likewise state the scaled formula mass or `concentration * volume * formula_mass`, with domain guards.
- An answered measured-molarity request has positive volume and satisfies `concentration * volume * formula_mass = input_quantity * input_gram_scale`.
- An answered remaining-mass request has nonnegative mass and elapsed time. Its actual decay-kernel value, multiplied by the requested gram scale, equals the initial gram mass times the decay factor.
- An answered inverse-decay request has an actual kernel value and rendered answer, and the decay law at that time maps the initial gram mass to the final gram mass.

These are claims about the typed request and arithmetic, not proofs that English recognition is correct. Atomic masses and isotope half-lives remain supplied data.

## Evidence

`check_mass_units.py` is an authored tuning challenge with independent Fraction arithmetic and logarithm expectations. Its 181 questions exercise all five specialist IDs. On the F baseline it found 47 right / 75 wrong / 59 withheld-valid. Requested-unit contract failures are counted as wrong even where the response describes an equivalent mass in grams. Deliberate refusals of valid unsupported questions remain withheld-valid.

The final isolated managed proof passed with **120 theorems and zero oracles**. The decimal enclosure tries 53 bits first and retries once at 212 bits; both branches retain the same proved `ndec_sound` error bound. The inverse logarithm uses the equivalent `ln(1/f) / ln(2)` form. The original 1000 milligrams to 500 micrograms example now returns **109.7 days**, both directly and through actual staged dispatch.

Shipped panels: **1206 right / 0 wrong / 0 false yes**, with no valid withholds. Per specialist: chemistry 225/225 dev and 281/281 heldout; chemistry-v3 the same; decay 42/42 and 42/42; labsolutions and labsolutions-r2 each 28/28 and 27/27. Shipped p50 remains below 0.4 ms. The difficult small-fraction cases can take roughly 0.5 seconds, including the bounded precision retry.

Authored unit challenge, direct and composed: **181/181 policy checks**, separately **169 right / 0 wrong / 12 withheld-valid**. Per ID:

| Specialist | Right | Wrong | Withheld valid | Policy checks |
| --- | ---: | ---: | ---: | ---: |
| chemistry | 38 | 0 | 4 | 42/42 |
| chemistry-v3 | 38 | 0 | 4 | 42/42 |
| decay | 65 | 0 | 2 | 67/67 |
| labsolutions | 14 | 0 | 1 | 15/15 |
| labsolutions-r2 | 14 | 0 | 1 | 15/15 |

Prior net-reaction challenge, direct and composed: **196/196 policy checks**, separately **178 right / 0 wrong / 18 withheld-valid**. Earlier D correctness challenge, direct and composed: **138/138 policy checks**, separately **118 right / 0 wrong / 20 withheld-valid**. These are three separate authored panels, not summed into the shipped completion metric.

The composed checks run ordinary copies of the actual Dispatcher and shared loader against the staged native binary and G capability sidecar. Other stages are disabled except the required network fallback. Runtime scripts, registry, capability sidecar, arbitration binary and fusion binary are captured in `staged-dispatch-inputs.json`. This is **staged composition**, not a production delivery or package capture.

Exact receipts:

- Proof: `proof-inputs-20261018T090845Z/var/chemistry/remote-attempts/20261018T092329Z-5b376e2f1322/receipt.json`.
- Native: repository `var/chemistry/native-attempts/20261018T092643Z-500b231114b4/compile-inputs.json`; explicit `receipt_snapshot` mode, production untouched.
- Native binary SHA-256: `7299077f6b85a83163f0857300c421ad76cfcf105a4cd9f2ca8188036b98dbda`.
- Actual reports: `g-panels.json`, `g-units.json`, `g-units-composed.json`, `g-net.json`, `g-net-composed.json`, `g-correctness.json`, `g-correctness-composed.json`.
- Ready source mapping and hashes: `ready-files.json`. The G export/reader includes F net-species support; do not overlay older F files after G.

After E integration releases live chemistry, promote the mapped files and compile against the exact staged proof receipt with ordinary current-source validation. Then package capture can label that final source closure; this staged native receipt must not be presented as a production build. Root owns commits.

## Remaining boundaries

Pounds, ounces and other mass systems; multiple requested output units; sums of elapsed times; charged species and mixtures; and ambiguous chemical species identities remain unsupported. Concentrations such as mg/dL are not silently treated as sample masses. Reaction inputs and outputs retain the F packet's mole/gram grammar; these unit constructors do not yet extend reaction quantities. Some valid zero-concentration/zero-volume solution requests outside mass-based molarity remain withheld and are tracked for the next correction.
