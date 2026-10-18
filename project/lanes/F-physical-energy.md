# Unit-aware calorimetry and thermal process work

Owner: Codex energy/geostats implementer under the physical deputy. Energy's
preceding physical-domain and fuel-ownership packets are integrated and captured.
This continuation begins with a finite unit-aware sensible-heat packet; explicit
water/ice/steam phase enthalpy is the next substantive model, after incremental
review/capture. Shared MeasuredInput 11f703 is read-only.

## Baseline and intended capability

The current a720c691 native treats 4.186 kJ/(kg K) or J/(g K) as 4.186 J/(kg K),
a factor-of-1000 error. It also substitutes water's table value when a supplied
specific heat is unknown, and silently ignores efficiency or additional phase
heating. Fahrenheit intervals are safely withheld. The 22 new sourced unit and
condition probes score 6 right / 7 wrong / 4 false yes / 5 valid withheld before
this change (`var/c-physical-energy-geostats/energy-F-units-before.json`). These
are authored capability probes, not shipped panel completion. Final after-panel numbers are recorded below.

Specific heat units carry energy, mass and temperature-interval dimensions.
The reader selects J/kJ/MJ, kg/g, and K/C/F constructors; exported HOL computes
all conversion factors. Fahrenheit differences scale by 5/9, without an
absolute-temperature offset. Complete numeric and unit spans preserve original
symbol case. The shared adapter selects a whole unit; the family also checks
the remainder of each grammatical field and every supplied numeric input.
Supplied unknown specific heat does not fall back to a material table. Unread
or incompatible units/conditions become a typed missing-input or unsupported
model reply, rather than an invented zero or a silently dropped condition.

The unit model follows [NIST's SI conversion tables](https://www.nist.gov/pml/special-publication-811/nist-guide-si-appendix-b-conversion-factors/nist-guide-si-appendix-b9)
and [temperature-interval definition](https://www.nist.gov/pml/owm/si-units-temperature).
The planned phase model distinguishes sensible heating from latent phase change,
as in the [DOE thermodynamics handbook](https://www.energy.gov/documents/doe-hdbk-1012-92vol1).
It will preserve distinct ice/liquid endpoints at 0 C and liquid/steam endpoints
at 100 C, under an explicitly constant-specific-heat, standard-pressure model.
Temperature alone does not determine phase fraction. Signed heat added and
positive heat removed must remain separate requested meanings.

## Statements and implementation status

`Calorimetry.thy` defines specific-heat factors and temperature intervals.
The intended checked consequences state:

- An interval converted to kelvin equals the difference of two converted
  absolute temperatures in the same scale.
- Converted specific heat times source mass/interval factors equals its stated
  source energy factor.
- The actual accepted sensible-heat kernel result satisfies the corresponding
  dimensional energy balance.
- The kernel's interval computation agrees with its endpoint-temperature
  computation.

The typed model-limit wrapper is connected to the family's existing decline
contract. This is infrastructure for truthful refusals, not an additional
mathematical assurance achievement. The ordinary sensible-heat computation and
its established physical guards are reused.

Managed hbox attempt 438ba9c71e45 reached the new theory but failed Fahrenheit
rational simplification and a datatype-case tactic. The first now uses explicit
field simplification; the second names the constructor fields with obtain.
Successor 072a556a4cfc passed with actual Finished, correct marker, 111 theorem
roots and zero oracles. No failed export was used. Its checked export SHA is
1cd97ebc39a1b36e2759139c5065b23532502d8dce0c002bddbad4d6e5448585.

Current incremental limits: efficiency/loss models, pressure-dependent heat
capacities, combined phase paths and net radiation exchange are not implemented
by the unit packet. Their valid requests stay valid withheld; refusing them does
not count as a completed capability. Phase enthalpy is deferred during user-requested drain. On resumption its intended
properties are actual accepted-endpoint reversal and path composition, plus
agreement with the existing pure sensible and latent kernels. No phase theory
or reader has been launched.


## Drain checkpoint

The finite sensible-heat unit packet is complete and frozen for root review.
Managed proof `var/energy/remote-attempts/20261018T102103Z-072a556a4cfc/receipt.json`
passed on hbox. Final native is
`3100b54b041014d0983a3548071bfa478512aab8c6ec89ca9c4912b62886dea8`,
834104 bytes, with actual input manifest
`var/energy/native-attempts/20261018T103345Z-fb43dbcd81ac/compile-inputs.json`.
It binds the current proof closure, reader and frozen MeasuredInput 11f703.
No build or compiler process remains active. No phase algorithm was launched.

The 22 sourced probes move from6 right / 7 wrong / 4 false yes / 5 valid withheld to
17 right / 0 wrong / 0 false yes / 5 valid withheld, with22/22 policy assertions. The five
valid-withheld requests are explicit unsupported millijoule units, efficiency,
combined phase heating, net radiation, and percentage emissivity; refusal does
not count as a completed capability. The first compiled reader exposed missing
spelled 'degrees C' aliases on eight shipped cases; the final binding table
restores those aliases while retaining original symbol case. That intermediate
c059 native and its failure receipts remain historical, not final evidence.

Final thermo own-scorer numbers are 44/44 dev and 50/50 heldout, zero wrong/false
assertions/valid withheld, in both pinned and whole-family modes. Cold starts
are 3.1–3.7 ms (five samples), p50 round trip 0.14 ms. Other shipped specialists
were not rescored for this thermo-only change; existing 34 domain controls remain
33 right / 1 valid withheld, 34 policy, and 22 runtime controls remain 22 right.
Two fresh independent Fraction-oracle samples, seeds 16918 and 17918, were first
generated after the final reader freeze: each 12/12 right. Against retained a720,
they were 2 right / 5 wrong / 5 withheld and 0 right / 8 wrong / 4 withheld respectively.
These samples are authored checks, not shipped completion panels.

Receipts under `var/c-physical-energy-geostats/` are
`energy-F-units-final.json`, `energy-F-thermo-final.json`,
`energy-F-fresh16918-after.json`, `energy-F-fresh17918-after.json`,
`energy-F-domain-controls.json` and `energy-F-runtime-controls.json`.
Independent consumer review is requested; root owns integration and runtime
owns immutable capture. No further source work is planned during drain.

Remaining phase frontier: a single non-boundary ice/water temperature on a latent
question can still fall into the existing pure-latent model; complete explicit
phase-path interpretation is not claimed by F1. A future model should represent
phase plus temperature as typed endpoints and distinguish signed heat added
from positive heat removed. Do not infer phase fraction from temperature alone.
