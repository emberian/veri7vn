# Completing CT arithmetic, 18 October 2026

Status: final native and consumer checks passed; source frozen for root
integration and runtime capture. Selected native is 0c693169, bound below.
Earlier candidates retain their exact immutable snapshots and counterexamples.

The water specialists now calculate contact time from CT and residual
concentration, and residual concentration from CT and contact time. The requested
target stays explicit. Inputs use exact signed, fractional and scientific
numbers. Minutes, hours and seconds convert exactly to minutes. CT,
concentration and time must be nonnegative, and an inverse requires a strictly
positive divisor. Zero concentration cannot determine time; zero time cannot
determine concentration.

The model assumes the supplied constant residual throughout the stated contact
time. ppm follows the inherited dilute-water mg/L convention; density is not
inferred. It does not choose regulatory CT targets or decide whether water is
safe to drink. English recognition, unit attachment and framing are untrusted.

Checked independent laws:

- An exact inverse time has time kind, nonnegative CT/time, positive residual,
  and residual multiplied by time equal to CT.
- An exact inverse concentration has concentration kind, nonnegative CT and
  concentration, positive time, and the same balance.
- The forward CT binding additionally records nonnegative concentration/time.

Hbox proof `20261018T075206Z-27ab84a25c41` passed with 74 theorem roots and zero
oracles; build, whole-log and export exits are zero. Export SHA256:
`10d00ef01d669bfcba2aed95e6b15250c3be26e3a07cc4727492bfa874816a55`.
Later reader corrections reuse this unchanged proven request algebra.

## Quantity and unit binding

CT now consumes shared `MeasuredInput` measurements from raw user text. Byte
spans refer to original text; role matching uses a byte-preserving lowercase
copy. A label cannot override the actual unit dimension: CT with mg/L, residual
with minutes, and time with mg/L are refused. Unsupported compound division,
powers, multiplication, `per`, hyphenated units and adjacent known units cannot
be shortened to a supported prefix. Prefix and suffix quantity roles must agree.
Explicit requested targets take priority over incidental trailing input labels.
Bare labelled CT retains the established mg-min/L convention.

The shared adapter belongs to the physical lane; this lane edited no shared
file. Its final hash is
`11f703525511191a6e075930191903841d65d158544075845c0142bfc32e2cb7`.
The shared exact numeric lexer remains
`2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.
The local grammar still checks unknown bare fields; the adapter alone does not
establish that a whole English request is valid.

## Results and exact selected inputs

Selected native SHA256:
`0c693169e8180c7f7cc85d64c0ba87fb53ccf22c5dc31a2d54adccaac8d20d7c`.
Actual-input receipt:
`var/materials/native-attempts/20261018T090009Z-997e3b5c8ad5/compile-inputs.json`.
Native size 843688 bytes. No proof definition changed after the passed export.

Both specialist and family modes score 92/92 authored probes: 0 wrong, 0 false yes,
0 valid withheld. Evidence:`var/E-materials/operator-final-probes.json`.
The preceding90-probe set measured D 60 right/1 wrong/14 false yes/15 valid
withheld versus E 90 right; two operator-boundary regressions were then added.
These are authored regressions, not independently generated questions.
Malformed or contradictory units count as invalid; unsupported but valid
mathematics is not relabelled invalid merely because it is withheld.

Actual dispatcher 5/5 passes: mg/L.min, mg/L × min, mg/L·min and mg/L * min
all stop at specs with terminal underspecified; ordinary residual2mg/L times
30minutes yields CT60. Receipt:
`var/C-runtime-consumers/materials-E-operator-final.json`.

Historical scoped measurements retain their exact native attribution:
720c8a15 scores 440/440 mapped,347/347 official and462/462 untouched seed20271219,
all with0 wrong/0 false yes. Water-r3 has no own panel; its inherited93 count
only in mapped totals. Harness remains INCOMPLETE because full-head criteria
were not run. The following c2c19c80 shared-API-only rebind repeated 440/440 and
90/90 probes. Initial 5feedcfa scored 442/442 on fresh seed20270518, which is not
a final-reader fresh result. Fresh sampling uses shipped generator templates.
Receipts under var/E-materials: selected-final.json, selected-untouched.json,
selected-parity/, shared-api-final.json. The 720c first launch was 174.75ms and
next four 3.58–3.93ms; those timings are not assigned to the selected binary.

## Preserved corrections

- Initial 5feedcfa, integrated as b4a0699, accepted CT60mg/L as CT60mg-min/L:
  rejected-ct-unit-candidate.json.
- 41eb7ac2, integrated as d64fef4, accepted residual2mg/L per min:
  compound-word-review.json.
- b671aa5b accepted residual2mg/L-min and residual2mg/L min:
  rejected-adjacent-unit-candidate.json.
- c2c19c80 accepted residual2mg/L.min and residual2mg/L × min:
  rejected-unit-operator-candidate.json.

All evidence files are under var/E-materials and all candidate binaries remain
retained. No held candidate is the selected delivery. Reader changes bind
complete units through the shared adapter rather than adding local unit-tail
exceptions. Shared owner physical repaired the discovered operator cases.

Changed after d64fef4: build.sh, recognizer.sml, probes.json, README.md in
src/extract/materials plus this report. Initial E additionally changed
Materials.thy, Materials_Export.thy, main.sml and capabilities.json.
New wire kinds ct_time and ct_concentration serve water/water-r3. Linux capture
and root integration must select the current exact native/inputs; no platform
result is inferred from local native or dispatcher checks.

The selected 0c693169 native also repeats 440/440 mapped shipped cases in both
modes, with 0 wrong and 0 false yes. Current evidence:
`var/E-materials/operator-final-shipped.json`. Five launch times in ms:
3.57, 3.24, 3.38, 3.92, 3.37; median 3.38 ms.
