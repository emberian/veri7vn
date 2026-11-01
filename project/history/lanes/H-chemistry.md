# H chemistry — directed solutions, units and zero quantities

**Promoted and ready for root integration as the complete F/G/H superset. E was integrated as `2f62b16`; runtime capture and root commit of H are the remaining gates.** The selected staged binary is `6303883bfd16b9fcfa55689be18cf090c926b4211c3b3a25b157e88ec2c293e1`. No new Isabelle or native job is running. `var/chemistry/next-solution/h-live-ready.json` binds the current named files, proof ancestry, final native manifest and evidence. `ready.json` retains the pre-promotion staged selection.

## What changed

The old solution reader sorted its two concentrations. Asking how much 1 M stock was needed to make 2 M solution therefore produced a calculation using 2 M stock. The new typed request retains stock and target roles, refuses an impossible concentration increase, and computes the unique required stock volume for positive stock concentration. It accepts target-first wording and explicit “from ... to ...” direction. Stock and final volumes are bound by explicit “to” or “final volume” wording rather than their numeric sizes.

A zero amount, zero concentration or zero stock volume is allowed wherever the formula is defined. Concentration still requires a positive denominator. Water-addition requests retain the stated stock concentration, so a negative concentration cannot disappear when constructing a volume-only request.

The requested litre, mole or molar output prefix is retained through the typed kernel: base, milli and micro are exact scales. Plain quantities are distinct from compound rates. An incompatible requested dimension is refused. The reader also refuses different explicit solute formula spellings or different named solutes; it does not infer chemical identity from equal element counts. Unrecognized amount-unit requests cannot fall through to a gram answer.

Existing reply-kind names come from `ckind_name`, preserving the consumer contract. The F net-species and G measured-mass models are included unchanged. G's mass-unit corrections, inverse-decay enclosure repair and bounded precision retry remain part of this selected superset.

## What the new proof says

`stoich/Solutions.thy` computes internally in litres, moles and mol/L. Its request stores the domain quantities; the public `RL` request additionally stores the desired output prefix.

- `directed_stock_conserves_solute`: if the calculation returns stock volume `v`, stock concentration `s` is positive, target concentration `t` is nonnegative and at most `s`, final volume `f` is nonnegative, `0 <= v <= f`, and `s*v = t*f`.
- `directed_stock_unique`: if that calculation returns `v`, every other volume satisfying `s*other = t*f` equals `v`.
- `solvent_volume_conservation`: a returned water amount `w` has nonnegative stated concentration and stock volume, `w >= 0`, and `stock + w = final`.
- `solution_amount_conservation`: a returned solute amount equals concentration times volume, with both inputs nonnegative.
- `solution_molarity_conservation`: a returned concentration has nonnegative input amount, positive volume, and `concentration * volume = amount`.
- `solution_dilution_conservation`: a returned final concentration preserves `result * final volume = stock concentration * stock volume`, with nonnegative quantities, final volume at least stock volume, and positive final volume.
- `solution_reply_value` and `reply_of_solution_value`: an affirmative reply has a successful value above, renders `Chemistry.g4(value / requested scale)`, and multiplying that unrounded requested-unit value by the positive scale recovers the internal value.

The zero-domain predecessor also extends the existing concentration, water and amount laws to nonnegative inputs. The amount-to-concentration inverse explicitly requires positive volume. Three executable laws cover zero-volume amount, zero-amount molarity and dilution of zero stock volume. The final scan includes all of these: **131 theorems, 0 oracles**. No axioms or proof escapes were added. The English role and unit recognition remains untrusted.

## Final executable evidence

The selected current-source native build is `var/chemistry/native-attempts/20261018T100426Z-228e2656a830/compile-inputs.json`. It is bit-identical to the staged build `2df9bbd4e3b8`. It uses the passed proof receipt at:

`var/chemistry/next-solution/proof-inputs-20261018T095255Z/var/chemistry/remote-attempts/20261018T095302Z-3ee992cff268/receipt.json`

The current-source native helper reports `proof_source_context=current_checkout`, `current_proofs_match=true`, no proof differences and no proof error. It used the exact passed staged receipt without `--proof-snapshot`, after verifying all E predecessor hashes and all promoted proof/runtime hashes. The actual five MLton inputs are captured by the native helper. Shared numeric source remains `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.

Shipped panels: **1206 right / 0 wrong / 0 false yes / 0 withheld-valid**. Each specialist was scored by its own shipped scorer:

| Specialist | Dev | Heldout |
|---|---:|---:|
| chemistry | 225/225 | 281/281 |
| chemistry-v3 | 225/225 | 281/281 |
| decay | 42/42 | 42/42 |
| labsolutions | 28/28 | 27/27 |
| labsolutions-r2 | 28/28 | 27/27 |

Final measured p50 is 0.20–0.41 ms; each shipped budget is 50 ms. The scorer was run with `--specialist-mode-only`; the separate authored composition checks below exercise the real dispatcher with the selected family pinned.

The following authored tuning sets pass both direct native and actual staged-dispatch replay. They are separate sets, not additions to the shipped completion metric. A valid unsupported question remains withheld-valid even when its deliberate refusal passes a policy assertion.

| Authored set | Policy checks | Right | Wrong | Withheld-valid |
|---|---:|---:|---:|---:|
| New directed solution roles, units and solute identity | 146/146 | 128 | 0 | 18 |
| New zero-domain boundaries | 124/124 | 124 | 0 | 0 |
| G mass-unit and inverse-decay cases | 181/181 | 169 | 0 | 12 |
| F net-reaction cases | 196/196 | 178 | 0 | 18 |
| D complete-token/domain cases | 138/138 | 118 | 0 | 20 |

For the new directed set, each lab specialist has 64 right, 0 wrong and 9 withheld-valid. Each has 62/62 right in the zero-domain set. The same final 146 cases on frozen G give **50 right / 58 wrong / 38 withheld-valid**. The same 124 zero cases on G give **86 right / 0 wrong / 38 withheld-valid**.

Reports are `var/chemistry/next-solution/h-{panels,solutions,zero,units,net,correctness}.json`, with `-composed` reports for each authored set. `staged-dispatch-inputs.json` pins ordinary copies of the runtime, registry, family sidecar, arbiter, fusion executable and selected chemistry binary. These are actual Dispatcher calls with read-only upstream data and no shared runtime edits. After promotion, fresh actual live-dispatch replay preserved all 146 solution, 124 zero-domain and 181 mass-unit policy checks, recorded in `h-{solutions,zero,units}-live-composed.json`. The live native binary is bit-identical to the fully tested staged binary.

## Ancestry and diagnostic history

E live proof `502262086ce7` led to F net-species proof `e35b6b95a949`, then G mass-unit proof `5b376e2f1322`. H's zero-only precursor `90a522ffd1d3` passed 123 theorems. It remains diagnostic ancestry, not a separately selected native consumer.

The initial combined model passed 131 theorems at `08b3bf8d5ef3`. Its first native preserved numeric answers but failed 24 shipped scorer checks because the stock-volume sentence used a colon rather than the scorer's required “is/Use/need” syntax. It also withheld six valid directed “from ... to ... for final volume” cases due to the legacy narrative filter. These were repaired. A subsequent replay caught three reply-kind aliases; the final model reuses the established `ckind_name` definitions. Final source and tests additionally cover differing solutes and unfamiliar requested amount units. The ready H proof is `3ee992cff268`; the final staged native is `2df9bbd4e3b8` and its bit-identical current-source rebuild is `228e2656a830`. Earlier variants are diagnostic evidence only.

## Remaining boundaries and integration

Mass-defined concentration currently supports mol/L output only; requested mM is a valid withhold. Gallon, tablespoon, nano and other unsupported unit targets, conflicting output units, unnamed stock direction, mixtures and compound rate units remain outside this reader. Zero stock concentration is not handled by the directed stock-volume request: with a positive final volume and zero target the volume is underdetermined; the zero-final-volume corner is also withheld even though its physically bounded volume is zero. Dilution assumes solute-free added solvent and additive volumes. Naming/role recognition is not a theorem of chemical species identity.

The inherited reaction input remains mol/mmol with mol/gram yield and final inventory, not gram reactant inputs or kg reaction output. Different elapsed versus half-life units work; summed elapsed durations remain unsupported. G's small inverse-decay fractions may require roughly 0.5 seconds for the bounded precision retry.

The E baseline `var/chemistry/stoich/e-ready.json` was checked before promotion. Root integrated E as `2f62b16` and explicitly released the complete H superset. The 19 named H files were promoted, the current proof and runtime closure matched the staged selection exactly, and the managed `build.sh` compilation used `PROOF_RECEIPT` with the passed export and no snapshot override. Runtime has been asked to capture native `228e2656a830`; root owns the final commit. Source and binary are frozen until those gates complete. F/G remain historical steps; do not overlay their older reader/export after H. The newer completion draft under `var/chemistry/next-solution-complete` was not promoted.
