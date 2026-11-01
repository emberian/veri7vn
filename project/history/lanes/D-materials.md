# Materials model corrections, 18 October 2026

Status: proof and final native passed; source frozen for root integration and
Linux/package capture. Hbox attempt `20261018T073117Z-f029699a361b` reports
`VERI7VN_MATERIALS PASS theorems=72 oracles=0`, with build/log/export exit zero.
The first D attempt failed on a reserved local fact name (`value`), repaired
to `computed` without changing the statements. C was captured before D edits.

The preceding shipped arithmetic could answer an explicitly impossible dilution by
silently swapping the stock and target concentrations. For example, stock
100 mg/L to target 200 mg/L in 1 L answers 0.5 L after pretending the stock was
200 mg/L. Separately, the soil reader interprets -100 g as positive 100 g,
.5 cm3 as 5 cm3, and 1e2 g as 2 g. These are reachable wrong answers, not missing
optional phrasings.

The repair preserves stock and target roles in a directed dilution request.
The kernel requires positive stock concentration, nonnegative target and final
volume, and target no stronger than stock. It computes target concentration
multiplied by final volume, divided by stock concentration. Role ambiguity is
withheld rather than resolved by sorting. The inherited percent convention
still means 1% = 10,000 mg/L; it does not infer mass/mass solution density.

The Hooke, soil and dilution readers now consume `ExactNumeric.scan` values and
original byte spans from the shared untrusted lexer owned by the chemistry
lane. They no longer define their own number grammar. Domain readers still
bind units and quantity roles. Malformed numeric runs cause missing-input
refusals; negative values remain negative. Bulk density rejects negative dry
mass and nonpositive volume. Volumetric water content also rejects nonpositive
bulk density.

Checked binding statements:

- An exact directed dilution answer has positive stock concentration,
  nonnegative target/final volume, target at most stock, and stock concentration
  times returned volume equals target concentration times final volume.
- Returned stock volume lies between zero and final volume.
- A positive stock weaker than the target receives the concentrating refusal.
- An exact bulk-density answer has nonnegative dry mass and density, positive
  core volume, and density times volume equals dry mass.

The statements concern the specified arithmetic and concentration convention.
They do not prove English recognition, physical sample identity, or actual
solution density. Request metadata links the relevant model statements; it is
not a per-answer proof object.

## Evidence

The captured C binary on all 46 extension/boundary probes scores 36 right,
2 wrong, 7 false yes, 1 valid withheld. The seventeen new D probes contribute
7 right, 2 wrong, 7 false yes, 1 withheld. Before receipt:
`var/D-materials-trades/materials-probes-before-final.json`.

A scratch prototype using the shared span reader but the captured C arithmetic
export preserves 440/440 shipped mapped answers (including inherited water-r3)
and 29/29 C probes in specialist and family modes. It correctly reads the
.5 cm3 volume and refuses malformed numeric runs. It does not contain the new
kernel guards, so this is only a reader regression check, not D completion.
Receipt: `var/D-materials-trades/prototype-shipped.json`.

The all-specialist gap survey and actual counterexamples are in
`var/D-materials-trades/semantic-gap-ledger.md` and `gap-probes.json`. Trades'
exact covering/fitting corrections have passed their separate D proof build. If exact counts disagree with an old epsilon-based
benchmark, the final report must show that disagreement rather than copy the
incorrect expected count.

The final native preserves all 440/440 shipped mapped cases and gets all 46/46
authored probes right in specialist and family modes: zero wrong, false yes or
valid withheld. This resolves two wrong numerical answers, seven false yes
answers and one missed valid answer in the authored boundary set. Fresh seed
20270318 gives 446/446, matching the captured C binary. Untouched seed
20270419 gives 450/450, also matching C; no tuning followed that sample.

The official scoped harness confirms all 347 cases with native manifest
panels. Water-r3 has no own panel; the mapped total includes its inherited
water cases. The harness verdict remains INCOMPLETE because full-head
criteria were not run, and it explicitly labels water-r3 NO PANEL.
Table/source checks pass. Final binary is 806,696 bytes. The first measured
launch took 90.86 ms; the next four took 3.97–4.33 ms. Specialist in-binary
median reply times range from 0.0755 to 0.2315 ms.

Seven actual composed dispatcher cases pass, including directed dilution,
ambiguous roles, negative dry mass, leading-dot volume, scientific mass and
a mixed fraction/scientific Hooke strain. Receipt:
`var/C-runtime-consumers/materials-D-final.json`. Linux/package capture and
root integration remain. Source stays frozen for both.

Final binary SHA256: `19f3a80f66575e370e4706936512d25be2e1ac55258f22807494d2a3a0bb8af7`.
Export SHA256: `61cf0095d03a3b0fdb007be9af855a0bc406265c694e579f1f5b7bb3707359b6`.
Actual input compile receipt:
`var/materials/native-attempts/20261018T074330Z-14079f63e3b1/compile-inputs.json`.
Source hashes: `var/D-materials-trades/materials-final-hashes.json`.
Final shared lexer: `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.
Checks: `var/D-materials-trades/materials-final.json`, `materials-fresh.json`,
`materials-untouched.json`, their saved-binary comparisons, and `materials-parity`.

## Per-specialist semantic ledger

These rows come from inspected request types and actual binary probes, rather
than inferring completeness from the shipped panels. Exact inputs/replies are
in `var/D-materials-trades/gap-probes.json`.

| Specialist | Observed behavior | Current repair or remaining limit |
|---|---|---|
| additive-v2 | Zero-face closed mesh returns two vertices; scaling a 10 cm length by two is withheld | Euler arithmetic does not validate existence of the supplied mesh; length scaling promised by the original description is still missing |
| materials-v2 | Stress 100 MPa with modulus 200 GPa gives strain 0.0005; all C inverse probes pass | Shared numeral migration implemented; linear elasticity still needs the stated physical assumption |
| soil | Dry mass -100 g in 100 cm3 is misread as positive and answers 1 g/cm3 | Signed span reader and negative dry-mass guard now checked and running |
| soil-r2 | Dry mass 100 g in .5 cm3 is misread as 5 cm3 and answers 20 | Final native now answers 200; surrounding domain exclusions remain |
| water | Explicit stock 100 mg/L to target 200 mg/L in 1 L answers 0.5 L by reversing roles | Directed dilution and concentration guard implemented; percent still uses the inherited mg/L convention |
| water-r3 | Stock 200 mg/L to target 100 mg/L correctly gives 0.5 L; asking time from CT 60 and residual 2 is withheld | Directed dilution shared with water; inverse CT is a separate unfinished capability |
