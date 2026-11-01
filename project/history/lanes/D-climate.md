# D-climate: model boundaries after the C packet

Status: checked kernel, selected native and exact composed checks pass; immutable
package capture is complete. This is the historical D checkpoint; later E through H packets are integrated as recorded in the natural-family drain report. C measurements remain in C-climate.md. Each ledger row
below records an actual boundary probe, not a claim of complete domain coverage.
Raw initial replies: `var/earth/d-domain/ledger-probes.json`.

| Specialist | Model boundary exercised | Actual result | Next concrete work |
|---|---|---|---|
| carboncapture | Physical capture fraction is in [0,100]. | Explicit -20% wording not taken. | Probe alternate signed placements; kernel currently only checks upper bound, so feasible-domain theorem needs mass/rate constraints. |
| airquality | Pollutant concentration is nonnegative. | -10ug/m3 wording not taken. | Check alternate reading grammar and averaging-period roles; existing numerical AQI law is not evidence of correct pollutant/time selection. |
| climate | Logarithmic forcing concentrations are positive. | 280→-560ppm treated as missing, underspecified. | Preserve full signed concentrations so existing impossible guard can explain refusal; distinguish signed changes from absolute concentrations. |
| carbonmat | Single-sheet physical area is nonnegative. | -2m2 becomes +2m2 and mass1.5223mg. | Signed lexer, kernel area/thickness guards, dimensional area conversion and mass nonnegative law. |
| coldchain | Elapsed cooling time is nonnegative; compound requests require every stage. | D now declines -1h as impossible. A compound 135→70 F in1h then41 F in9h still answers Yes from stage1 alone. | Completed elapsed-time guards and bound verdict laws. Next: parse and check the complete compound schedule, or explicitly refuse unsupported compound requests. |
| coldchain-v2 | Same elapsed-time and complete-schedule semantics as coldchain. | D negative-duration repair passes both consumers. Compound-stage coverage remains incomplete. | Completed shared kernel repair and dispatcher checks; extend the same complete-schedule handling to both readers. |

## Change and assurance

Changed `Climate.thy`, `Climate_Export.thy`, `recognizer.sml`, `build.sh`,
`beyond-probes.json`, and new `capabilities.json`. Negative cooling and
time-without-temperature-control durations now produce the existing impossible
kind. The cooling reader preserves that refusal instead of dropping every request
for which answers=false. Both specialist IDs explicitly accept the refusal.
No policy thresholds or minimum cooking temperatures changed.

Both coldchain readers use shared `ExactNumeric.mask`. Signed decimals, Unicode
minus, scientific notation and fractions map to exact typed rationals. Malformed
numbers and forged placeholder names are not taken; every placeholder must exist
in the lexer's returned table. English recognition and role selection remain
untrusted. Build scripts now use the common immutable-input native compiler helper.

The checked statements say:

- A cooling verdict has a nonnegative elapsed duration.
- The impossible negative-time result occurs exactly when elapsed duration<0.
- A passing cooling verdict has 0<=hours<=6.
- A passing TPHC verdict has exactly 0<=hours<=4.
- Not-a-stage is distinct from impossible negative time.

All four added theorem names enter the oracle scan; the existing cooling verdict
statement is stronger. Hbox proof receipt
`var/climate/remote-attempts/20261018T071733Z-ee097b9b817a/receipt.json`
reports exit 0 and `VERI7VN_CLIMATE PASS theorems=85 oracles=0`. It includes the
required Commons session root. The fresh checked export is:
`var/climate/remote-attempts/20261018T071733Z-ee097b9b817a/results/export/Veri7vn_Climate/Veri7vn_Climate.Climate_Export/code/climate.ML`.

## Selected compile and results

- Checked export SHA256: `b35cb58724518ae7f1a2309b7aa2ab00908c51e171c54e3b426a03efe06760b5`.
- Selected `var/climate/bin/climate` SHA256: `682af3740d1dceae4c406f54aeb31daa180f41fd12164191d65e3ae639f69d55`, 657496 bytes.
- Immutable compiler receipt: `var/climate/native-attempts/20261018T073846Z-136ebc073cad/compile-inputs.json`.
- Frozen numeric dependency: `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.

The common helper copied the actual MLB inputs before compiling, verified the
export against the passed current proof receipt, and rechecked copied hashes after
MLton success. It records consumed generated SML, recognizer/main, commons.sml,
numeric.sml, rewritten MLB, and compiler identity. Earlier diagnostic native
candidates are superseded. The untrusted SML reader was completed after the HOL
proof; the checked kernel source/export did not change.

All six shipped panels pass 306/306. Fresh offset 4701 passes 303/303. Reserved
final offset 7701, generated only after this selected compile, passes 305/305.
All have zero wrong, false yes, and valid withheld replies. Actual family-mode
harness for both coldchain IDs passes 120/120. Its labels remain INCOMPLETE because
head/core/self checks for all six completion criteria were not run for this scoped
repair.

Authored probes pass 52/52: prior 20, 16 duration boundaries, and 16 lexical cases.
The frozen C binary passed 12/16 duration cases and falsely passed all four negative
ones. New cases include -1,0,2,2.1h cooling; -1,0,4,4.1h TPHC; Unicode negative
fraction; .5,1/2,1/ 2,5e-1; malformed 1.2.3; forged placeholders with and without
real numerals in the same question. These are authored, not independent examples.

Shipped p50 milliseconds: carboncapture 0.135, airquality 0.142, climate 2.757, carbonmat 0.131, coldchain 0.119, coldchain-v2 0.102. Cold median 4.07ms.

Receipts: `var/climate/d-final/report.json`, `var/climate/d-parity/`, and
`var/climate/d-duration/selected-native.log`. Actual dispatcher receipt
`var/C-runtime-consumers/climate-D-final.json` binds the selected exact hash and
passes both negative-duration terminal refusals and the positive single-stage
1h cooling request. Immutable capture is complete at
`var/C-runtime-package/bound-prepared/20261018T073846Z-136ebc073cad/climate`.
Root committed this D packet in `4a68e6e`; Linux refresh is separate and pending.

That composed audit also found an unresolved false yes: “Food cools from135 F to70 F
in1 hours and then to41 F in9 hours. Does it meet the cooling rule?” evaluates
only the first stage. Existing positive multistage examples likewise did not
establish whole-schedule coverage. The current packet fixes signed elapsed time;
complete compound-stage interpretation is the next repair, after immutable capture.

Remaining model gaps in carbon capture, airquality interpretation, forcing roles
and carbon materials stay in the ledger. This repair validates stated elapsed-time
arithmetic; it does not decide whether a particular food is safe or establish
applicability of the declared rule to a situation.

The compound-stage repair is tracked in [E-climate.md](E-climate.md).
