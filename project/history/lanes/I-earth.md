# I-earth: complete pressure measurement roles

Status: promoted live with actual full-default checks passing, frozen pending
immutable capture and root integration. This reader-only successor includes the
checked E/F/G seismology and H runoff work. Selected delivery is unchanged.

The full-default consumer answered 30.17 kPa to “What is the gauge pressure at
depth 3 m in water with gravity 1 gram?” by silently using Ocean's default
seawater density and Earth gravity. It displaced a richer model's correct
refusal. The original counterexample is retained in
`var/runtime-default/finance-physical.json`.

Ocean now requires every supplied numeric measurement to be consumed as its
unique depth or optional density. Density must have an exact supported mass per
volume unit; compound dimensions and multiple density values cannot be truncated
into one plausible number. Explicit gravity, pressure baseline and other model
parameters cause Ocean to abstain. This includes unlabelled extra measurements,
not just a list of parameter names. The richer Quantity pressure model owns
custom gravity and baseline handling; Ocean does not manufacture a terminal
refusal for a valid model it cannot represent. Negative supported density still
reaches its existing physical guard and returns impossible.

The supported default model is unchanged: g=9.81 m/s2, freshwater/lake density
1000 kg/m3 and otherwise the existing seawater default 1025 kg/m3. An explicitly
supported density overrides that default. Custom acceleration, pressure baselines,
other density dimensions and ambiguous extra measurements remain unsupported by
Ocean. This packet adds no custom-gravity capability or new physical theorem.

The 16 authored pressure policies pass versus 4/16 on H: four supported numeric
answers, one impossible negative density, and eleven abstention policies covering
valid unsupported, dimensionally ill-typed and ambiguous requests. These are
policy checks, not sixteen newly answered problems. All 32 H runoff policies,
41 G seismology policies, 29 E policies, 15 F power controls and 50 original
Earth probes also pass.

| Official scorer panel | Right | Wrong / false yes | Withheld |
|---|---:|---:|---:|
| All Earth shipped | 554 / 554 | 0 / 0 | 0 |
| Fresh offset 58701 | 360 / 360 | 0 / 0 | 0 |
| Reserved offset 63701 | 356 / 356 | 0 / 0 | 0 |
| Hydrology shipped | 102 / 102 | 0 / 0 | 0 |
| Ocean shipped, each fresh panel | 46 / 46 | 0 / 0 | 0 |

Hydrology and meteorology lack fresh generators. Separate official hydrology
and Ocean parity scores are 102/102 and 46/46, but admission remains INCOMPLETE:
all six completion criteria were not measured. Ocean shipped p50 is 1.857 ms;
family cold median is 3.688 ms. These results are from the exact promoted binary,
measured before promotion, and do not claim a standalone H panel run.

The unchanged HOL closure uses successful H receipt
`var/earth/h-runoff/stage/var/earth/remote-attempts/20261018T100241Z-86c88f8ac79b/receipt.json`,
with 138 scanned roots and zero oracles. Its generated SML SHA256 is
`827fef6eaff03224df96f26a95cf91f64340267a064a969e272083212b910843`.
The main native helper validated the promoted current checkout closure against
that receipt, then produced canonical `var/earth/bin/earth` SHA256
`5f63016919cd33f06a39d10c4c266c055a10f00bf7d84a7cbcdaaa70b42149e4`.
The actual-input manifest is
`var/earth/native-attempts/20261018T101035Z-fb95e1d9880b/compile-inputs.json`.
No proof was rerun solely for relocation or this reader-only change.

The seven promoted source files and their hashes are in
`var/earth/i-pressure/promoted-sources.json`. Canonical generated code, session
export and default successful-receipt discovery were published as recorded in
`var/earth/i-pressure/publication.json`; previous D artifacts are preserved.
Model and policy receipts are in `var/earth/i-pressure/`, with official results
in `panels/report.json` and `parity/`. Actual full-default composition passes 7/7 in
`var/runtime-default/earth-I-pressure-final.json`: the original gravity-in-grams
request terminates with unsupported_model; lunar gravity gives 4860 Pa; the
gauge-pressure baseline control gives 30000 Pa; fraction/percent runoff both
give 0.2778; coefficient 1.5 and negative intensity terminate with impossible.
These checks bind stable Earth, Quantity, Mechanics and runtime hashes. All
16 pressure policies also pass directly against the canonical live binary.
