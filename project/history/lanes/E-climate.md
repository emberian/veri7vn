# E-climate: complete two-stage cooling schedules

Status: corrected kernel, selected native, official panels and actual composed
checks pass. Source and native are frozen for immutable capture and root integration.
The earlier b9f2 candidate remains rejected diagnostic evidence.

A compound question previously answered from its first stage alone: 135 F to
70 F in one hour, then 41 F in nine hours received Yes. The typed request now
records all three temperatures and both incremental durations. It checks the
first checkpoint within two hours and the complete schedule within six hours.
One hour plus five hours passes; one hour plus nine hours fails.

Root then found that the first E candidate wrongly accepted 70.4 F and 41.4 F.
The corrected complete-schedule model removes the inherited half-degree slack.
It uses the published nominal thresholds from [Food Code 2022, 3-501.14(A),
page 91](https://www.fda.gov/media/164194/download): 135 F / 57 C at the start,
at most 70 F / 21 C at the first checkpoint, and at most 41 F / 5 C at the final
checkpoint. Each reading uses its supplied unit's explicit nominal table;
rounded Celsius labels are not computed by converting Fahrenheit thresholds.
Above-limit checkpoint readings produce False, rather than an unsupported refusal.

Changed files: `Climate.thy`, `Climate_Export.thy`, `recognizer.sml`,
`capabilities.json`, `beyond-probes.json`, and `README.md`. Successful schedules
use `cooling_check`; negative durations use `impossible`; unsupported or ambiguous
schedules use `underspecified`. Both coldchain manifests accept the refusal kind.

## Checked statements and model boundary

The independent clock model requires 0<=first<=2 and first<=total<=6.
For typed temperatures a,b,c and incremental durations d,e, the checked laws say:

- A successful True verdict occurs exactly when the supplied-unit endpoint
  inequalities and the independent clock model hold, with first=hours(d) and
  total=hours(d)+hours(e).
- Impossible negative-time refusal occurs exactly when either duration is negative.
- Shortening either stage while both durations stay nonnegative preserves True
  for the same endpoint readings.
- True binds each supplied temperature to its actual nominal-unit inequality.
- Given a supported start and nonnegative durations, exceeding either checkpoint
  temperature limit forces False.
- Exact nominal F and C triples satisfy the endpoint model.
- The explicit missing-schedule request always returns underspecified.

These eight added scan facts (including both nominal-unit equations) bind the
kernel's actual result. They do not prove English interpretation or that the rule
applies to a particular food. The untrusted reader consumes exactly three
temperatures and two durations through the shared exact lexer. Supported wording
uses incremental “in” or “over” times and explicit “then”. Ambiguous total/within/
after wording, missing or extra stages, and starts below the modeled threshold
are withheld. Compound requests cannot fall through to first-stage evaluation.

## Exact checked candidate

Persvati proof receipt:
`var/climate/remote-attempts/20261018T081430Z-3f06cc73e351/receipt.json`.
Exit 0, source stable, fresh exports published, marker
`VERI7VN_CLIMATE PASS theorems=93 oracles=0`.

- Generated SML SHA256: `dff675797b0cb4edebaf51493b67960b69d34ae2b2334982e0023fd06c288084`.
- Native `var/climate/bin/climate`: `2e7ffb79ebd047bcb800f683bc120d6de8ed89d97c0225fc7c53ae4956bef056`, 675560 bytes.
- Actual compiler-input manifest: `var/climate/native-attempts/20261018T082633Z-a44193849e5f/compile-inputs.json`.
- Shared numeric dependency: `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.

The common helper froze actual generated SML, recognizer/main and shared inputs,
verified the checked export, and rechecked the inputs after compiling.

## Results and limits

| Official-scored panel | Right / total | Wrong | False yes | Valid withheld |
|---|---:|---:|---:|---:|
| All six shipped specialists |306/306|0|0|0|
| Fresh offset 18701 |307/307|0|0|0|
| Reserved offset 23701 |312/312|0|0|0|
| Actual family harness, both coldchain IDs |120/120|0|0|0|

The new offsets were generated after this compile. The actual family harness
remains INCOMPLETE because head/core/self admission checks were not run; this is
not a full six-criterion completion claim.

Authored policy assertions pass 108/108. They are not 108 answered capabilities:
74 answerable model cases pass, and 11 mathematically valid unsupported queries
remain withheld. That capability slice is 74/85 with 11 withheld-valid cases.
The remaining assertions cover 12 impossible inputs, 6 malformed inputs, 3
missing-required-input questions and 2 outside the computational domain. Explicit
classification is in `var/climate/e-cooling/probe-classification.json`; upstream
scorer labels were not altered. The added endpoint probes include exact and
just-above nominal bounds in both units, mixed units, and above-limit midpoint
readings correctly answered False.

Shipped p50 milliseconds: carboncapture 0.153, airquality 0.163, climate 2.571,
carbonmat 0.083, coldchain 0.132, coldchain-v2 0.139. Cold median 3.31ms.
Receipts: `var/climate/e-endpoints-final/report.json`,
`var/climate/e-endpoints-parity/`, and `var/climate/e-cooling/endpoints-native.log`.

Actual CLI composition passes six checks on the exact selected native:
70.4/41.4 F returns False, nominal Celsius and mixed-unit schedules return True,
1h+5h returns True, 1h+9h returns False, and a negative second duration produces
terminal impossible. Receipt: `var/C-runtime-consumers/climate-E-corrected-final.json`.

The rejected candidate `b9f2f6df669c61a45fa93eab0f7b44566629a58ab9d1c3f8e5580b3bbdfe3af2`
and its 89-theorem proof are diagnostic only. Its original measurements remain
in `var/climate/e-final/report.json`; the newly exposed counterexamples are in
`var/climate/e-cooling/tolerance-baseline.json`. It is not approved for delivery.

## Remaining partial-information gaps

The inherited single-stage model is still limited: a 135 F to 41 F total of six
hours answers Yes to the total-time limit without evidence of when 70 F was
reached. A 70 F to 41 F duration of five hours answers No under the old fixed
four-hour stage model, even though a complete one-hour-plus-five-hour schedule
meets both checkpoint deadlines. Actual prior replies are in
`var/climate/e-cooling/partial-model-gaps.json`.

This packet fixes complete schedules. A subsequent partial-information model must
distinguish a failed known deadline, an individual checkpoint question, and an
unknown earlier checkpoint. Other specialist gaps remain in [D-climate.md](D-climate.md).
