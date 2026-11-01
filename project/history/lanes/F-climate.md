# F-climate: partial records and complete cooling compliance

Status: checked kernel, selected native, authored policy probes and actual
composed consumer pass. Source and native are frozen for immutable capture and
root integration. The official scorer now withholds 23 shipped questions whose
partial records do not establish complete compliance; this is not a parity claim.
The corrected E artifact remains independently
captured and committed in `90249a8`.

A 70 F to 41 F second-stage duration of five hours can meet the complete deadlines
if the first stage took one hour, or fail if it took three. Conversely, a total
135 F to 41 F duration of six hours does not reveal whether 70 F was reached
within two hours. The inherited reader answered both questions without retaining
that uncertainty. Root approved correcting the model even when inherited scorer
labels disagree; those labels will remain unchanged and divergences will be counted.

The new model records a first, total, or second-stage elapsed time. A compatible
complete record has nonnegative first-checkpoint time no later than final time,
and agrees with the supplied elapsed observation. The algorithm says True only
when every compatible record meets both deadlines, False when every compatible
record fails, and underspecified when compliant and noncompliant records both
remain possible. Compatibility is nonempty for every nonnegative elapsed value,
so the universal statements are not vacuous.

The independent relation and checked laws are:

- A compatible record exists for each nonnegative elapsed observation.
- Existence of a compliant record is equivalent to first<=2, or total<=6, or
  second<=6 respectively.
- Existence of a noncompliant record is always possible for first-only or
  second-only information, and equivalent to total>2 for total-only information.
- The actual partial-request kernel's True, False and underspecified results
  correspond respectively to universal compliance, universal failure, and
  existence of both sorts of record.
- Negative elapsed time is impossible; explicit checkpoint-only requests use
  the first two-hour or total six-hour deadline without claiming full compliance.

Temperatures bind the observation using exact supplied-unit nominal values:
135/70/41 F or 57/21/5 C. This narrow partial model describes times of reaching
those checkpoints, not arbitrary later readings below a checkpoint. Such other
partial readings remain unsupported. Whole-schedule questions take precedence
when a question also mentions a first-stage limit. Explicit earlier-clock wording
retains its own time and builds the complete E schedule; it is not thrown away.

The old typed `Cd_cool` remains for historical internal fixtures, but no English
reader constructs it. Runtime proof provenance now names the actual partial and
complete schedule laws. The previous E evidence and 108 authored cases are
preserved; new clock-completion policy probes are separate while validation runs.

## Checked artifact and actual results

Proof receipt: `var/climate/remote-attempts/20261018T083636Z-c1510d513a6f/receipt.json`.
Persvati exit 0, fresh export published, source stable; assertion
`VERI7VN_CLIMATE PASS theorems=107 oracles=0`. Fourteen new scanned facts cover
compatibility, nonempty possible records, classification and the actual request
kernel. The initial attempt 8f85102091ca failed on explicit existential witnesses,
propagation of the nonnegative premise and one string delimiter. Repairs retained
the model statements; no failed export was consumed.

- Generated SML SHA256: `67e84711759987e13a227d645afeba1537de086692923c8516db78d4e6ec1313`.
- Native `var/climate/bin/climate`: `569508c14b1c49b2ed1cc23dcf6cd07dba17ae290415b0d79c8bef2218759a88`, 678456 bytes.
- Actual compiler-input manifest: `var/climate/native-attempts/20261018T084244Z-29bc459c9ee5/compile-inputs.json`.
- Consumed shared numeric dependency: `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.

The common helper binds the actual compiled generated SML, recognizer, driver,
shared SML inputs and compiler to that proof. It rechecks those inputs before
publishing the native.

| Official-scored panel | Right / total | Wrong | False yes | Valid withheld |
|---|---:|---:|---:|---:|
| All six shipped specialists |283/306|0|0|23|
| Fresh offset 30701 |288/311|0|0|23|
| Reserved offset 35701 |289/310|0|0|21|
| Actual coldchain family harness |97/120|0|0|23|

The fresh offsets were generated after this compile. The exact shipped
divergences are retained in `var/climate/f-partial/shipped-divergences.json`:
11 for coldchain and 12 for coldchain-v2. They are generic compliance questions
with only a first or second stage stated. Upstream labels remain unchanged.
The harness is INCOMPLETE because head/core/self admission checks were not run.
This is the root-approved correction of the partial-information model, with its
visible scorer cost; it is not full six-criterion completion.

New authored policy assertions pass 96/96, compared with 48/96 for the prior E
native. A separate untrusted rational witness enumerator provides compatible
passing and failing clocks for ambiguous questions; the quantified HOL theorem,
not that finite enumerator, establishes the universal result. Baseline and final
raw replies remain in `var/climate/f-partial/e-baseline.json` and
`var/climate/f-partial/final-probes.json`.

Combined authored policy assertions pass 204/204. Eighteen earlier generic
compliance expectations were explicitly revised to underspecified, with their
old expectations and reasons retained. Official labels were not revised.
The valid-question slice has 102 answered cases out of 169: 50 valid questions
remain underdetermined and 17 remain unsupported. These 67 withheld cases are
visible capability boundaries, not answered successes. The other assertions
cover 20 impossible inputs, 10 malformed inputs, 3 missing-required-input
questions and 2 outside the computational domain.

Shipped p50 milliseconds: carboncapture 0.125, airquality 0.182, climate 2.770,
carbonmat 0.075, coldchain 0.114, coldchain-v2 0.119. Cold median 3.42ms.
Full receipts: `var/climate/f-final/report.json`, `var/climate/f-parity/`,
`var/climate/f-partial/final.log`, and `var/climate/f-partial/native.log`.

Seven independent actual CLI-composed probes pass on the selected hash:
135→41 F in six hours and 70→41 F in five hours are terminal underspecified;
a two-hour total is True; a three-hour first stage is False; an explicit
first-stage two-hour check is True; known first 1h plus second 5h is True while
known first 3h plus second 5h is False. Receipt:
`var/C-runtime-consumers/climate-F-final.json`. This remains a next-cohort artifact
until root selects it; earlier captured versions are preserved.

## Remaining boundaries

The clock model presumes elapsed times of reaching the stated nominal checkpoints,
with the first checkpoint no later than the final checkpoint. It does not infer
crossing times from arbitrary later sensor readings, model a temperature curve,
or establish the Food Code's applicability to a particular food. Non-nominal
partial endpoints remain unsupported. The explicit earlier-clock grammar is
narrow; arbitrary rearrangements and unrecognized timing roles are not silently
read as a complete schedule. Other family model gaps remain in D-climate.
