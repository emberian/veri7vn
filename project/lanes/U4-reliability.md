# U4 reliability: recognize room dimensions and explain conflicts

The geometry fallback now reads “3 meters long and 4 meters wide,” computes
area as 3 × 4 = 12 and perimeter as 2 × (3 + 4) = 14, and explains conflicting
lengths instead of asking what “its” means. This is checked through the actual
word-problem module and its w488 consumer with a substituted parent. It is not
yet a fresh full-Engine result. **No specialist panels were run; no theorem or
fleet-wide score is claimed.** Frozen candidates, including v5, were untouched.

The original U1 appliance experiment gave six correct scalar answers, five
needless refusals and four safe refusals after the first repair. In that actual
experiment, the conflicting room stopped receiving the wrong answer 12 but got
an unrelated clarification about “its.” That original evidence remains under
`var/usage-20261026/reliability/run-2/`; it has not been relabeled as U4 evidence.

## What changed and why

The old geometry reader understood `length 3 meters` but not `3 meters long`.
It returned `None` for both unsupported grammar and contradictions, so w488
could neither answer the ordinary room nor explain the real problem with an
inconsistent room.

One shared, untrusted reader now binds prefix dimensions and the postfix words
`long`, `wide`, `tall` and `high`. It checks every typed length, including repeated
mentions; a unitless apartment number remains irrelevant. A numeric mention
written both ways, such as `length 3 meters long`, counts once. Legitimate
length/width differences remain valid. Conflicting values for the same role
prevent calculation. Negative/malformed dimensions, unknown units, unbound
extra lengths and raw mixed-unit multiplication remain refused.

The same reader provides a bounded conflict explanation. It distinguishes
contradictory values from equivalent quantities expressed in different units:
3 meters and 300 centimeters are not described as contradictory (calculation
with mixed units still waits for an output-unit contract). A supplied radius and
diameter must agree with diameter = 2 × radius. The explanation declines when
the text contains unsupported/multistep syntax; it does not claim a general
English contradiction detector. Requests for multiple shapes, multiple measures
or an explicit output unit receive a separate bounded capability explanation.

The real w488 `_c480_dispatch` consumes these explanations only after its parent
has not answered and the word module has not produced a numeric result. It emits
`clarification` at `organ:math>word:conflicting_dimension` for inconsistent
dimensions, or `organ:math>word:unsupported_geometry_request` for unsupported
request scope, preserving the prior
path/status in provenance. It does not give a refused answer a numeric value or
claim proof/admission authority. Already answered parent replies stay unchanged.
No changes were made to the landed AO grammatical-it filter or w534 history guard.

## Actual component comparison

The same controlled parent clarification was passed through the old and new
w488 classes and word modules. Expected dimensions and formulas were independent
arithmetic, not previous scorer labels.

| Original task | Before | After |
|---|---|---|
| Room 3 m long, 4 m wide; asks its area | “its” clarification | 12 square units |
| Rectangle width 4 m, length 3 m; asks area | 12 square units | Same answer |
| Apartment 12, room 3 m long and 4 m wide | “its” clarification | 12 square units |
| Same room, asks its perimeter | “its” clarification | 14 |
| Same room length exactly 3 m and exactly 5 m | “its” clarification | Explains conflicting lengths |

The last response is exactly:

> The supplied length values disagree (3 meters and 5 meters). Which length should I use?

Complete controlled before/after objects and inputs are in
`var/usage-20261026/reliability/u4/consumer-comparison-final.json`. This is focused
consumer evidence, **not** an Engine launch, HTTP receipt, or new task score.
The unchanged “square units” and missing perimeter unit remain presentation
limitations; the patch does not claim to repair dimensional output formatting.

## Changed files and portable proposal

Root approved only these mutable source edits:

- `var/ap1-upstream-slim/root/wander-train/word_problems_v1.py`
- `var/ap1-upstream-slim/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w488.py`

Owned tracked additions:

- `tools/usage/reliability/u4-geometry.patch`: portable source-only patch, applied after the earlier geometry repair in the next candidate.
- `tools/usage/reliability/preserved_answers.json`: six explicitly labeled saved parent-reply fixtures from U1 run-2, not fresh output.
- `tests/usage/reliability/test_geometry_consumer.py`: real module/consumer tests.
- This report.

The patch was generated against exact pre-edit file snapshots, with concurrent
content checked before writing. Base and final SHA256 maps are retained in
`var/usage-20261026/reliability/u4/base-hashes.json` and `patched-hashes.json`.
Final patch SHA256: `05555f1df3db88dd9df1cc083c67466e65e1553c61f50c7057e9aa1e358041dd`.
Private source checkpoint: `2f3fc57ac1cbdfb32bcc092804ec0c169c750d2f`.

The source-only patch does not contain stores, receipts, credentials or candidate
artifacts. Existing U1 tests and patch were preserved. Root owns checkpointing and
future candidate construction.

## Check and exact result

Command:

```
.venv/bin/python -B -m unittest discover -s tests/usage/reliability -v
```

Result: **38 tests passed**: 19 previous regressions and 19 new consumer tests.
Full output: `var/usage-20261026/reliability/u4/tests.txt`.

The consumer harness imports actual w488 and word module source, and AST-selects
the unchanged w480 `_run` helper and `_c480_answered` predicate. Its substitute
parent returns the supplied prior reply; it does not launch the expensive head,
load stores or simulate its other routes. This tests the real fallback boundary
without asserting that the full serving ancestry has been exercised.

New checks cover the original room wording, changed requested quantity,
changing length to 5 changes area to 20, repeated equal/unequal dimensions,
prefix/postfix overlap, apartment numbers, malformed/negative/unbound dimensions,
mixed units, equivalent-unit duplicates, multiple shapes, malformed conflict
remainders, and radius/diameter consistency. All six saved correct parent replies
remain the identical returned objects. Non-geometry refusals remain unchanged.
The fixtures are retained replies used as inputs, not answers generated by this
new harness.

Remaining work is root's coordinated full-Engine replay in a later candidate.
The spelled-negative-temperature and speed-route failures are outside this
repair. Later serving folds may still alter these replies, and a parent that
already answers bypasses this fallback as before. No claim is made that all five
U1 needless refusals are fixed or that all English geometry descriptions are now
supported.


## Review counterexamples and final bounds

Root's independent probes caught three false answers in the initial extension.
They were fixed before freezing the portable patch, with consumer regressions:

- Two 3 m × 4 m rooms require total area 2 × 3 × 4 = **24 m²**. Returning 12 for the whole request is wrong. The consumer now explains that it handles one shape at a time.
- Asking for area and perimeter requires **both 12 m² and 14 m**. The consumer now asks for the requested measures separately rather than presenting one as a complete answer.
- Asking for the area in square centimeters requires **120000 cm²**, because 1 m² = 10000 cm². The consumer now explains its inability to bind an explicit output unit rather than returning bare 12.

These are deliberate bounded refusals, not completed calculations. The one-shape
check recognizes shape nouns, plural room/box nouns, explicit shape counts and
plural references; it does not reject arbitrary numeric identifiers. A separate
positive control retains **Apartment 16**, room 3 m long and 4 m wide, giving 12.
The recognizer remains conservative; unsupported wording or repeated shape names
can lead to additional refusals. It does not establish semantic uniqueness for
arbitrary English.

Actual focused response objects and the independent required values are in
`var/usage-20261026/reliability/u4/scope-controls.json`. These are component
receipts with a substituted parent, not full-Engine replies. The geometry output
unit contract, multiple-shape aggregation and multiple-measure answers remain
unfinished work rather than being silently treated as successes.


The final request-unit review also preserves ordinary location and rounding
wording. “Area in this diagram” remains 12, while a 3.12 m × 4 m rectangle rounded
to the nearest tenth gives 12.5. The unit guard recognizes the known length-unit
lexicon or explicit `square`, `cubic`, `sq`, `cu`, and `units of` syntax;
explicit unknown units still receive the capability explanation. Shape mentions
without a requested geometry measure do not trigger this guard or a geometry
clarification. These controls are included in the final 38 passing tests.


## Root checkpoint and full-Engine follow-through

Root committed the final mutable source as
`2f3fc57ac1cbdfb32bcc092804ec0c169c750d2f`. The public U4-owned file set is
`tools/usage/reliability/u4-geometry.patch`,
`tools/usage/reliability/preserved_answers.json`,
`tests/usage/reliability/test_geometry_consumer.py`, and this report.

The service lane subsequently replayed the original 15 questions unchanged
through the actual U4-v2 appliance. Its full retained replies are in
`var/u4-service/u4-v2-real/calls.jsonl`, with independent scalar/pair analysis in
`reliability-analysis.json`: nine correct scalars, four safe refusals, two
needless refusals, zero wrong numeric answers, and seven of ten pairs passing.
The intended room cases and exact conflicting-length explanation reached the
full serving consumer. Scope controls remained explicit capability explanations;
apartment 16, rounding and diagram wording worked. Numeric correctness remains
separate from dimensional completion: geometry replies still lacked specific
area/perimeter units. U5 owns that bounded follow-up. These are usage receipts,
not specialist panel scores or Mini admission.
