# H-climate: signed carbon quantities and capture-energy units

Status: promoted live successor over G; proof, native, official panels and
actual dispatcher checks pass. Immutable package capture is complete; root
integration remains outstanding. Selected delivery remains unchanged.

The prior G binary answers 1600 kWh for capturing 80% of 1000 kg CO2 at 2 kWh
per tonne. The correct energy is 1.6 kWh: 0.8 tonnes captured times 2 kWh per
tonne. It also loses signs and misreads fractions/scientific notation in several
carbon quantities. H fixes these reachable requests through the actual reader,
kernel and consumer. Baseline replies are preserved in
`var/climate/h-capture/g-baseline.json`.

The capture-energy request now carries a finite mass unit: grams, kilograms,
metric tonnes, Mt or Gt. HOL converts the mass to tonnes before multiplying by
capture fraction and energy intensity. Mt/Gt retain their case; bare lowercase
mt/gt are ambiguous and withheld. The reader uses shared exact numeric masking
for signed decimals, fractions and scientific notation. Each quantity role must
bind uniquely. Missing intensity cannot fall through to a captured-mass answer.
A distinct requested energy output unit is withheld rather than silently ignored.
Compound mass/intensity dimensions and the distinct mWh unit are unsupported.

The physical domain requires nonnegative mass, fuel volume and energy intensity,
positive mpg, and capture rate from 0 through 100%. Zero mass, rate or intensity
remains valid. The existing EPA tailpipe factors and carbon/CO2 molar-mass ratio
are unchanged; ton/tons mean metric tonnes and fuel volumes mean US gallons.
Energy is returned in the unit of the supplied per-tonne intensity. Other carbon
mass conversions retain the input mass unit. Output-unit conversion, alternate
intensity denominators and ambiguous models remain capability gaps.

Eight additional scanned laws bind the implementation:

- An actual exact carbon result exists if and only if its physical domain holds.
- Actual captured mass is nonnegative and no greater than the supplied mass,
  with rate within 0–100%.
- Actual capture energy is nonnegative.
- Four actual kernel equations identify equivalent gram/kilogram/Mt/Gt and
  tonne requests, including their guards.
- Feasible zero-intensity capture produces exact zero energy.

The repaired existing capture model states that actual energy equals normalized
mass in tonnes times capture percentage divided by 100 times energy per tonne.
Carbon roundtrip retains the successful-input premise. Above-100% decline laws
identify that specific reason, because negative inputs can now decline for their
own reason. These are not merely rendering or classifier tautologies.

Managed proof: hbox `20261018T094340Z-113e14dddf3f`,
`VERI7VN_CLIMATE PASS theorems=128 oracles=0`.
The first attempt 4101e608834e failed after automatic simplification obscured an
existential rational witness. The repair separates generic exact-result existence
from physical guards. Retry f063ca8e18e7 exposed the reserved fact name `output`;
renaming it `exact_shape` completed the unchanged statement. No failed export was
published or consumed.

Generated SML SHA256:
`cb97ffd7784a8005eedf27ca4151875e08885ddfa33ef328288ecaab3d6fb4df`.
Native SHA256:
`8adf2cace24cee2b05cd9a70d80f5feeb0b0ff196698ae5556a629613115567a`,
695736 bytes. Actual compiler manifest:
`var/climate/h-capture/stage/var/climate/native-attempts/20261018T094547Z-6bf35931a5ad/compile-inputs.json`.
It binds the successful export, recognizer/main, commons.sml and frozen exact
numeric input 2f313c77. It records the shared main compiler lock and leaves live
convenience pointers intact. Source staging and retries are recorded separately;
the final reader guard was captured in the successful proof snapshot and native.

| Official scorer panel | Right | Wrong / false yes | Valid withheld |
|---|---:|---:|---:|
| All Climate shipped | 283 / 306 | 0 / 0 | 23 |
| Fresh offset 50701 | 280 / 302 | 0 / 0 | 22 |
| Reserved offset 55701 | 284 / 307 | 0 / 0 | 23 |
| Carbon capture shipped | 28 / 28 | 0 / 0 | 0 |
| Carbon capture fresh | 28 / 28 | 0 / 0 | 0 |
| Carbon capture reserved | 28 / 28 | 0 / 0 | 0 |

The family withholds remain the approved partial-cooling information boundary;
H changes no cooling logic. The separate official carboncapture parity harness
scores 28/28, but admission remains INCOMPLETE: head/core/self and all six
completion criteria were not measured. This report claims no family admission.

All 50 H policies pass, versus 15/50 on G. They comprise 25 answered model cases,
14 impossible inputs, 9 valid unsupported requests and 2 malformed inputs. The
valid answer capability slice is 25/34; unsupported refusals do not become new
answers. All 50 G policies and all 204 prior Climate policies also pass.
Shipped carboncapture p50 is 0.099 ms; cold median is 3.109 ms. Evidence is in
`var/climate/h-capture/panels/report.json`, `h-probes.json`, `g-regression.json`
and `parity/`.

Actual staged Dispatcher checks pass 8/8 in
`var/C-runtime-consumers/staged-H-climate.json`: kg/Mt/Gt give 1.6 kWh,
half a tonne gives 0.8, negative mass/rate are terminal impossible, half a gallon
of gasoline gives 4.4435 kg CO2, and rational 80/2 mpg gives 222.175 g per mile.
This uses an explicitly injected staged capability source and changes no live or
selected artifact. The locator and full promotion hashes are in
`var/climate/h-capture/ready.json`. Promotion must retain the exact proof closure
and use the common native helper. The later live promotion is recorded below.

## Live promotion

Root released predecessor F after commit acd9b55. The six owned source files
were promoted byte for byte, and the common native helper validated the current
checkout proof closure. The canonical binary retains SHA256 8adf2cace24cee2b05cd9a70d80f5feeb0b0ff196698ae5556a629613115567a.
The live compiler manifest is
`var/climate/native-attempts/20261018T100529Z-ac0eda3486ff/compile-inputs.json`.
Canonical generated code, session export and default receipt discovery now
point to this checked version; `var/climate/h-capture/publication.json` records
the previous artifacts and exact publication.

All 50 H policies pass against the canonical live binary. The first three rows
of `var/runtime-default/live-climate-anatomy.json` independently pass the actual
full-default consumer: 1000 kg capture gives 1.6, negative mass terminates with
impossible, and half a gallon gives 4.4435. Other rows concern Anatomy.
Immutable capture is
`var/C-runtime-package/bound-prepared/20261018T100529Z-ac0eda3486ff/climate`.
The six source files and this report are frozen pending root integration.
The historical material model and results are in `project/lanes/G-climate.md`.
