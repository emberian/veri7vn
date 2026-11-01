# Materials continuation, 18 October 2026

Status: implemented, proved, compiled and checked through the shared runtime.
No commits were made by this lane; root owns integration.

The materials specialist now computes both missing directions
of the uniaxial linear-elastic relation: stress from Young modulus and strain,
and strain from stress and Young modulus. Pa, MPa and GPa are normalized;
negative stress/strain represents compression, and strain may be given as a
percentage. Nonpositive modulus is refused. The answer names the linear
elasticity assumption; it does not judge whether a sample remains elastic.

The existing `stress` and `strain` kinds remain usable by dispatch. The producer
contract is `src/extract/materials/capabilities.json`. New replies select the
corresponding binding theorem in their metadata; recognition remains untrusted.

## Baseline

Freshly measured warm binary, specialist and family modes, right / wrong /
false yes / withheld-valid:

| Specialist | Shipped dev | Shipped heldout | Fresh 20261018 dev | Fresh heldout |
|---|---|---|---|---|
| additive-v2 | 32/0/0/0 | 20/0/0/0 | 32/0/0/0 | 20/0/0/0 |
| materials-v2 | 34/0/0/0 | 24/0/0/0 | 34/0/0/0 | 24/0/0/0 |
| soil | 36/0/0/0 | 36/0/0/0 | 36/0/0/0 | 36/0/0/0 |
| soil-r2 | 36/0/0/0 | 36/0/0/0 | 36/0/0/0 | 36/0/0/0 |
| water | 46/0/0/0 | 47/0/0/0 | 48/0/0/0 | 49/0/0/0 |
| water-r3 | 46/0/0/0 | 47/0/0/0 | 48/0/0/0 | 49/0/0/0 |

The original organs match these baseline numbers. The final 29 authored extension
and boundary probes initially give 10 right, 0 wrong, 0 false yes, 19 valid
withheld for both original organs and warm binary. These probes share the
recognizer author's assumptions. Fresh seeds vary selections from existing
pools and templates; they are not independently designed questions.

Receipts: `var/materials/codex/{before,fresh-before,organ-baseline,probes-before}.json`.
The first build attempt is
`var/materials/remote-attempts/20261018T063143Z-e693718fed5e/receipt.json`.

## Final results

The new binary preserves all shipped counts above. The final untouched seed
offset 20261231, generated after the numeric-token repair, passes completely in
specialist and family modes: 438/438 right, zero wrong, false yes or valid
withheld. Its water/water-r3 panels have 45 dev and 47 heldout items; all other
counts match the first fresh seed. The original organs and before binary also
pass these panels completely.

The newly usable inverse requests pass 29/29 authored probes in specialist and
family modes, versus 10/29 before: 19 new valid answers and ten correct refusals.
This includes stress/modulus labels before or after values, compression,
percentage and leading-dot/scientific numerals. Malformed multi-dot numerals
and comma groups are refused rather than interpreted as a trailing number.
Explicit requested targets take precedence over a supplied quantity whose label
happens to end the question. These authored checks share the reader author's
assumptions and are not independent evaluations.

The scoped parity harness reports 347/347 right, 0 wrong and 0 false yes across
the five manifest panels. Its verdict is **INCOMPLETE**, because no whole-head
domain-gain/lane/self comparison was requested. water-r3's manifest has no panel;
`score.py` separately tests its inherited water panel (93/93), giving 440/440
across six specialist mappings. Do not count those inherited questions as new
independent evidence.

The runtime owner tested actual shared acceptance and arbitration: stress
200 MPa and strain 0.002 answer, and a zero modulus is a terminal `impossible`
refusal. It also checked quantity-before-label inputs (strain 0.002, stress
140 MPa) and retained the zero-modulus refusal. Receipts:
`var/C-runtime-consumers/materials-inverse.json` and `materials-role-order.json`.
The final numeric-token consumer check also passes: leading-dot strain gives
stress 200 MPa; malformed decimal and comma inputs are terminal refusals with
no network fallback. Receipt:
`var/C-runtime-consumers/materials-numeric-boundary.json`.

## What is proved

Three new statements in `Materials.thy`, all included in the final oracle scan:

- `kernel (HookeStress e eu strain) = Exact k q` implies `0 < e`,
  `k = K_stress`, and `q = e * smpa eu * strain`.
- `kernel (HookeStrain stress su e eu) = Exact k q` implies `0 < e`,
  `k = K_strain`, and `q * (e * smpa eu) = stress * smpa su`.
- Under `0 < e`, applying `HookeStrain` to the exact stress computed by
  `HookeStress`, with stress units MPa and the same modulus, returns the original
  strain exactly.

These are statements about the specified linear-elastic model. The kernel does
not prove that natural-language recognition selected the right quantities or
that a real material obeys this model. The general formatting theorem continues
to bound the printed value's rounding. Request-selected theorem metadata is a
link to the checked statement, not a per-answer proof object.

Fresh build: `VERI7VN_MATERIALS PASS theorems=70 oracles=0`, first attempt,
receipt `var/materials/remote-attempts/20261018T063143Z-e693718fed5e/receipt.json`.
The immutable export SHA256 is
`5915a5fe3f93c926a1d51a4031b1a534147b8ab314bdfbdf5626221c6fca53a9`.
`tables_check.py` passes, including 20,301 soil-composition checks.

## Delivery and measurements

Changed files: `Materials.thy`, `Materials_Export.thy`, `recognizer.sml`,
`main.sml`, `build.sh`, `score.py`, `README.md`, plus new `capabilities.json`
and `probes.json`, all within `src/extract/materials/`.

`build.sh` requires `VERI7VN_GENERATED` pointing to the exact successful export;
it neither deletes earlier exports nor silently reads stale local heaps.
`score.py` now supports `--fresh-seed`, `--panel-root` and `--probes`, recording
which shipped generator supplied each panel.

Binary: 775,928 bytes (before 775,416). Final five new-process starts:
4.50–5.28 ms, median 4.99 ms. The first launch after compilation in the earlier
measurement took 79.7 ms, so the 20 ms target does not hold for every observed
launch. Final specialist in-binary medians are 0.09–0.63 ms, below one tenth of
the 50 ms budgets. No interval precision was lowered.

Final source SHA256: `recognizer.sml`
`3fcc90ecfefeb72e41ab3d6bd9f82e528a120f6d70eda75925ce76e502b09418`;
`Materials.thy` `e9380c89ca914eeac0fdac1e577c21bb53935667cb31824802dc87b6c9009870`;
`Materials_Export.thy` `08a6d83e53239ff7621b00af9eadb6cf6d16b5b724351dbe414fcb1029e45630`.
Binary SHA256: `845cff9d9ccde5e648e1dd3bd9002289a93d8171260b60d3a0b860a086012a22`.
Full hashes: `var/materials/codex/final-source-sha256.json`.

Final receipts under `var/materials/codex/`: `numeric-final.json`,
`numeric-untouched.json`, `numeric-untouched-before.json`,
`organ-numeric-untouched.json`, `probes-numeric-before.json`,
`organ-numeric-probes.json`, and `parity-numeric/`.

Remaining limits: this is uniaxial linear elasticity, not plasticity, anisotropy
or structural safety. A fresh Linux binary/package receipt for this change is
still the delivery owner's work; the old Linux receipt does not cover it.
