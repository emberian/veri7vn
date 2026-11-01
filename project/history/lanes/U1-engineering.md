# U1 engineering: practical calculations with preserved quantity roles

## Results

No shipped specialist panels were run. There are **no new panel numbers**, no
Isabelle build, and no new theorem claim. These are private-adapter usage
experiments against the immutable appliance candidate on this host.

The initial 14 questions included 12 valid numerical tasks and two invalid
requests. Of the valid tasks, **one was answered correctly, three received an
incorrect answer under the supplied assumptions, and eight were withheld or
needed clarification**. One invalid request received a useful refusal; the other
received an unadjusted numerical answer. All 14 requests returned HTTP 200 with
no transport errors. Median measured request latency was 0.244151 s, range
0.089856–3.770988 s. These timings include adapter/engine work, not startup or
slot waiting.

The initial questions and independent expectations were saved before querying
in `tools/usage/engineering/cases.json` and `expectations.json`. Exact complete
response objects, including evidence and path, are retained in
`tools/usage/engineering/observations.json`; judgments are separate fields, not
rewritten Oracle output. Raw response bytes and adapter logs remain under
`var/usage-20261026/engineering/run-01/` through `run-04/`.

| Initial case | Independent expected result | Actual result and judgment |
| --- | --- | --- |
| Lift 25 kg by 4 m, g=9.81, no losses | 981 J | Clarification; no computation |
| Same lift, 80% efficiency follow-up | 1226.25 J | Asked what “that” referred to despite same conversation ID |
| Pump 0.002 m³/s of water up 10 m, 70% overall efficiency | 1962/7 W ≈ 280.285714 W | Clarification |
| Spring k=200 N/m, extension changes 0.1→0.3 m | 8 J additional energy | Timeline route refused: needed dated statements on stiffness |
| Spring unstretched length 0.4 m, final length 0.5 m, k=200 N/m | 20 N | Physics route requested mass and acceleration |
| Spring k=200 N/m, extension 0.3 m | 9 J | Spring route found elastic energy; precision guard withheld it |
| Heat 2 kg of water 20→80 C, c=4180 in following sentence | 501600 J | 502300 J using table c=4186; appended a missing-mass refusal |
| Heat 2 kg of water by 60 K, c=4180 | 501600 J | Correct: 501600 J with supplied c in explanation |
| 1000 Wh battery, 100 W load, 500 W inverter rating, 90% efficiency, 80% usable depth | 7.2 h | 10 h before losses; did not answer the requested adjusted runtime |
| Same battery without rating detail | 7.2 h | 10 h before losses |
| Battery with 120% efficiency | Reject impossible efficiency in this model | 10 h before losses; invalid condition ignored |
| 30 litres/minute to m³/second | 0.0005 m³/s | Clarification |
| Temperature increase of 18 F to increase in C | 10 Celsius degrees | Clarification |
| 2 metres to kilograms | Refuse dimension mismatch | Useful refusal explaining length versus mass |

“Before losses” makes the battery replies more candid than an unqualified wrong
number, but they still do not provide the requested quantity. The supplied
factors are enough to calculate it. No refusal above is relabeled a success
because the local worksheet knows an answer.

## What the follow-ups distinguish

Three further ordinary-language probes retained the same numerical assumptions:

- Putting the 500 W inverter rating before the 100 W load changed the reply
  from 10 h to **2 h**. Its explanation explicitly divided 1000 Wh by 500 W.
  This is a quantity-role defect: a rating and consumed power have the same
  units but are not interchangeable. It also still ignored efficiency/depth.
- Keeping c=4180 in the same sentence as the water-heating request produced the
  correct **501600 J**. The earlier two-sentence answer explicitly used c=4186
  for water, despite the supplied value. This is a composition/condition-loss
  defect; it is not missing material data. The one-sentence form is a workaround.
- Changing “What is the elastic energy...” to “How much energy is stored...”
  still triggered `precision_guard:Q2_half_answer` after the spring specialist.
  Both replies said: “not the a you asked for.” The trace indicates an answer
  type/guard problem after recognition, rather than unavailable arithmetic.

The heat error is small numerically but changes the stated model; matching
within a broad numeric tolerance would hide that error. Its explanation and
contradictory missing-mass tail make the lost condition directly observable.

Candidate source inspection corroborates the battery behavior:
`var/appliance-20261026/candidate/root/specialists/energy-v3/organ_energy_v1.py`
lines 85–105 take the first power match and return runtime before losses.
The checked-in extracted energy recognizer already has adjusted runtime support;
these observations do not show a failure of that implementation. The adapter's
capabilities declare `kernel_platform: linux-x86_64` and explicitly say that
metadata/contents were not verified by the adapter. This report therefore
claims only behavior of this candidate through this host's private adapter,
not a verified-overlay deployment result.

## Implemented workflow

`tools/usage/engineering/worksheet.py` is an **untrusted** structured input helper
for lift input energy, pump input power, spring energy change, spring force,
sensible heat, battery runtime, flow conversion and temperature intervals.

The caller chooses a model and binds explicit names to quantities. The worksheet
retains all inputs and assumptions, shows the formula and normalized roles,
and emits an arithmetic-only question plus a separately labeled exact local
reference. It rejects missing roles, extra unsupported conditions, wrong units,
duplicate JSON fields, invalid efficiencies and loads exceeding an inverter's
rating. It treats the rating as a constraint and the load as the denominator.
It retains both spring extensions and both temperature endpoints, including
cooling or decreasing stored energy, rather than silently changing an increment
into a total. It distinguishes absolute temperature units from interval units.

This is useful for an engineer or a technically curious caller who can choose a
simple physical model but should not need to guess Oracle's English templates.
The existing shared runner is the consumer of the generated cases; a human
reviews the retained worksheet when interpreting the numerical answer.

The 11 worksheet examples were queried in `run-02`. **Ten arithmetic questions
were answered correctly; one was withheld.** The first interval generator
collapsed 18×5/9 to the bare question “What is 10?”, which routed to an
encyclopedic passage about year 10. The helper now keeps the conversion visible
as “What is 18 * (5 / 9)?”. That final query answered **10** in `run-03`.
The changed flow-conversion expression, “What is 30 * (1 / 60000)?”, answered
**0.0005** in `run-04`. Thus each of the 11 final worksheet questions has an
observed correct arithmetic answer, across these runs. This is not a claim of
11 repaired natural-language tasks: role selection and physical modeling remain
in the untrusted worksheet/caller. The initial refusal is retained.

All 30 requests across the four runs returned HTTP 200. Run-02 median latency
was 0.050530 s, range 0.003639–4.168500 s; its slowest request was the withheld
bare-number query. The path `compute:verified` and `verified: true` are Oracle's
own labels, retained as evidence rather than promoted to Isabelle assurance.
The displayed flow steps round `1/60000` to `0.000017`, then print
`30 x 0.000017 = 0.0005`; that displayed rounded chain is not exact arithmetic.
The final result agrees with the independent exact rational reference.

## Checks and changed files

Command:

```
.venv/bin/python -B -m unittest discover -s tests/usage/engineering -p 'test_*.py' -v
```

Exact final result: **Ran 20 tests in 0.002s — OK**. Tests independently check all
11 example outputs and parse their emitted arithmetic through a restricted test
AST evaluator, plus role ordering, rating changes, overloaded inverter rejection,
invalid/zero efficiency, zero load, unknown/missing roles, dimension mismatch,
spring endpoint equality and compression, mixed temperature scales, cooling,
absolute-zero violations, interval/endpoint separation, duplicate JSON fields,
and invalid numeric encodings. No engine, Isabelle or broad test suite is run
by these unit tests.

Changed files:

- `tools/usage/engineering/worksheet.py`
- `tools/usage/engineering/README.md`
- `tools/usage/engineering/cases.json`
- `tools/usage/engineering/expectations.json`
- `tools/usage/engineering/examples.json`
- `tools/usage/engineering/followup_cases.json`
- `tools/usage/engineering/followup_expectations.json`
- `tools/usage/engineering/observations.json`
- `tests/usage/engineering/test_worksheet.py`
- `project/lanes/U1-engineering.md`

No shared source, frozen files, appliance source or upstream source was edited.
No subagents or Git operations were used. No theorem statement was added.

## Remaining work

An engine repair should bind power quantities by their roles, honor supplied
runtime factors, preserve conditions across sentences, and repair the spring
answer-type guard. Those changes need the shared source owners and actual
candidate integration; this lane has not edited those files. Re-evaluate these
ordinary-language cases after integration, then run the relevant shipped panels
through their own scorers. General variable-load battery behavior, pipe friction,
nonlinear springs, phase changes and other unsupported physics remain outside
the worksheet's stated models; it rejects extra quantities rather than hiding
them to produce a convenient answer.

## Follow-on core repair, authorized by root

This section supersedes the earlier “no shared source edited” statement and the
condition-splitting item in Remaining work. Root explicitly assigned the private
Slim combiner's splitting helpers, then approved the narrow short-fragment join
correction. The measured candidate and upstream remain unchanged.

Changed source:
`var/ap1-upstream-slim/root/specialists/_gate/combo_runtime_v1.py`.
The pre-edit file matched the measured candidate byte for byte, SHA-256
`00d721a0f9a9950d896b02a1c556c44f7f5b573aac6e4693bd775bab1526cda7`.
The frozen repaired file is
`425e19518cffaf49fc7d4362aeeb57bfe6cbb40361b9cbff18a038e684326221`.

The heat defect is in composition, not the thermo formula. The real `ThermoOrgan`
already answers the complete original request with 501600 J and supplied c=4180.
`_split_parts` separated the trailing “Use constant specific heat...” sentence;
the first fragment then used the water table, and the second requested a mass.
The repair attaches explicit condition-led declarative continuations to their
question before asking specialists. It keeps a subsequent independent question
separate, preserves quote/code spans, and leaves ambiguous/unrecognized
continuations visible. It is a finite untrusted English recognizer, not a general
proof of intent. “Given...” before another question stays with that next question.

A second live-composition regression exposed a related existing problem:
`_segment` joined any short uncovered question to its neighbor. Consequently,
“How much heat...? Use c=4180. What is 2+3?” could silently lose the second task
even after splitting correctly. The two joins now accept an explicit elliptical
vocabulary (such as “How much?”), instead of assuming every request with at most
six words depends on its neighbor. Full independent questions before or after
the heat request remain separate and visible in the returned parts. Pronoun
backreference handling is unchanged.

The exact original two-sentence heat request now returns **501600 J with c=4180**
through the real private-source `Combo` and real thermo manifest/organ, with
neither table substitution nor the contradictory missing-mass tail. This is a
component-consumer result; the combined immutable appliance has not yet been
replayed by this lane. Its integration remains with root. Battery reproducers,
expected 7.2 h and invalid-condition boundaries were sent to composition, which
owns that independent source repair.

Additional durable files:

- `tools/usage/engineering/condition_attachment.patch`
- `tools/usage/engineering/condition_attachment_receipt.json`
- `tests/usage/engineering/test_condition_attachment.py`

Exact scoped checks:

```
.venv/bin/python -B -m unittest discover -s tests/usage/engineering -p 'test_condition_attachment.py' -v
Ran 13 tests in 0.015s — OK

.venv/bin/python -B -m unittest discover -s var/ap1-upstream-slim/tests/runtime_guards -p 'test_runtime_guards.py' -k ComposedAdmission -v
Ran 13 tests in 0.027s — OK
```

The first group covers the original failure with real thermo composition,
independent tasks in both orders, actual elliptical follow-ups, trailing
conditions in eleven wordings, chained conditions, quoted/code question marks,
decimal/semicolon inputs, and imperative tasks that must not be absorbed. The
second is the existing narrow composition-admission regression class. The
previous 20 worksheet tests were already green and the worksheet was unchanged.
Before/after component replies are retained in
`var/usage-20261026/engineering/core-repair/{before,after}.json`.
No specialist panels, Isabelle builds or theorem claims were added.

## Combined immutable appliance replay

Root supplied the combined candidate at
`var/usage-20261026/candidate`. The original fourteen requests plus all four
retained follow-ups were replayed unchanged through the shared runner with an
explicit `--runtime` and fresh output directory
`var/usage-20261026/engineering/run-05-combined`.

All **18/18** requests returned HTTP 200; no transport errors, HTTP errors or
unrun cases. Median request latency was **0.153952 s**, range
**0.014429–3.518516 s**. The complete unmodified response objects and candidate
capabilities are appended to `tools/usage/engineering/observations.json` under
`run-05-combined`.

For the original fourteen requests: **three correct numerical answers, two
useful invalid-input refusals, nine uncompleted valid tasks, zero incorrect
numerical answers**. This compares with one correct numerical answer, one useful
refusal, eight uncompleted valid tasks and four incorrect/condition-ignoring
answers before integration. Counting the four follow-ups too, the combined
replay has six correct answers, two useful refusals and ten uncompleted valid
tasks. One of those six is the explicitly generated arithmetic-only interval
question; it is still not a natural-language conversion success.

Confirmed repairs and preserved positives:

- Original two-sentence heat request: **501600 J**, explicitly uses supplied
  **c=4180**, with no contradictory missing-mass tail. The one-sentence and
  interval-based heat variants also remain correct.
- Plain battery with 90% efficiency and 80% usable depth: **7.2 hours**.
- Impossible 120% efficiency: **withheld**, explicitly requests fractions
  between zero and one.
- Battery with **500 W inverter rating before 100 W load**: **7.2 hours**. The
  response divides by the 100 W load and explicitly notes that the load is
  within the 500 W rating; the original erroneous 2-hour answer is gone.
- Metres-to-kilograms remains a useful dimension-mismatch refusal, and the
  explicit `18 * (5 / 9)` interval arithmetic remains correct.

One runtime variant remains uncompleted. The original `battery_roles` request
includes a final sentence, **“The load is constant.”** The combiner still treats
that declarative condition as a separate part. The final reply is safely
withheld by `precision_guard:G4_admitted|specialist_call>combo:parts>energy-v3`
rather than the former wrong 10-hour answer, but this is **not** a completed
7.2-hour task. Root was told about the remaining declarative-condition gap.

Other failures persist: lift and its follow-up, pump power, spring increment,
spring force, simple spring energy and its rephrasing, flow conversion and
natural-language temperature interval conversion. The lift request now reaches
an unrelated cooking/unknown-food refusal instead of generic clarification;
its completion status is still unsuccessful. The spring energy guard still
says “not the a you asked for.” No incorrect answer was converted to a success
by using the worksheet reference.

The candidate was not mutated. No new specialist panel measurement or theorem
claim follows from this replay.

### Declarative constant-load follow-up repair

Root authorized a narrow extension for the one remaining battery wording found
in the combined replay. Explicit named-parameter declarations such as “The load
is constant.”, “The specific heat remains fixed.” and “Flow rate stays steady
throughout.” now attach to the preceding request. The grammar requires a named
physical parameter, an explicit copula and constant/steady/fixed; unrelated
assertions and new tasks remain separate. It does not treat arbitrary trailing
prose as a condition.

The private pre-edit file again matched the combined immutable candidate byte
for byte (SHA-256 `425e19518cffaf49fc7d4362aeeb57bfe6cbb40361b9cbff18a038e684326221`).
The cumulative patch and receipt have been refreshed. The exact original
`battery_roles` request now produces **7.2 hours**, divides by **100 W load** and
retains the **500 W inverter rating** through the actual private-source `Combo`
and patched energy-v3 organ. No `combo:parts` reply is produced.

The scoped condition test file now reports **Ran 16 tests in 0.020s — OK**.
Additional regressions cover that real energy consumer, multiple named
constant-parameter wordings, a subsequent independent question, unrelated
assertions, changing temperatures and requests embedded after a declaration.
The worksheet source and its previous checks are unchanged. The final frozen
source hash is recorded in `condition_attachment_receipt.json`; root will make
a further immutable candidate and replay the changed composition paths. The
run-05 outcome above is retained exactly and is not upgraded by this component
result. Neither immutable candidate was mutated.

## Root's final packaged replay (27 October)

Root provisioned `var/usage-20261026/candidate-final` after the declarative
constant-load fix. Receipt SHA-256:
`34b685093842cbada93de9cb510db4d322fdeb12e56c88d7346132da6063a156`.
All 14 original engineering cases ran unchanged within the 22-case final
integration pack. Both heat cases give 501600 J using c=4180; both valid original
battery cases, including the rated inverter and trailing constant-load sentence,
give 7.2 hours. The 120% efficiency and dimension-mismatch cases decline.
Results: four correct numerical answers, two useful invalid-input refusals,
eight valid uncompleted tasks, zero incorrect numerical answers. No task-success
claim is inferred merely from the 22 HTTP 200 responses.

Complete evidence is in `var/usage-20261026/integration-final/`; root's checked
summary is `project/USAGE-2026-10-26-results.json`. The final scoped engineering
suite has 36 passing tests (20 worksheet and 16 condition/composition tests).
