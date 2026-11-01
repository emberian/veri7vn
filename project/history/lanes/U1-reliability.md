# U1 reliability: everyday answers under small changes

The combined candidate removes the one wrong numeric answer while preserving all
six correct answer texts. Its replacement clarification is still unhelpful, and
five ordinary tasks still fail. See the replay receipts below.

The first actual engine run completed all 15 questions with HTTP 200. Six gave
the correct scalar, three safely withheld, five needlessly withheld or asked for
clarification, and one answered an inconsistent question incorrectly. Three of
ten paired checks passed. These are fresh usage experiments, not specialist
panel numbers. **No specialist panels were run. No theorem is claimed.**

The agent caller benefits from a reusable checker that notices both unstable
answers and stable-but-wrong behavior. It requires independently correct answers
at both ends of a pair; two identical refusals cannot masquerade as reliability.

## Actual questions and outcomes

All arithmetic expectations were saved before querying in
`tools/usage/reliability/expectations.json`. Each question used its own
conversation ID. The full original requests are in `cases.json`; exact complete
response bytes, all fields and latency are retained in
`var/usage-20261026/reliability/run-1/results.jsonl`.

| Case | Independent result | Actual result |
|---|---|---|
| `percent_base`: 20% of 80 | 16 | 16, word-problem route |
| `percent_paraphrase`: twenty percent of eighty | 16 | 16, closed-grammar computation route |
| `percent_changed`: 25% of 80 | 20 | 20 |
| `area_base`: room 3 meters long, 4 meters wide; its area | 12 square meters | Asked what “its” refers to despite room in same request |
| `area_paraphrase`: rectangle width 4 meters and length 3 meters | 12 square meters | 12 “square units”; specific unit omitted |
| `area_incidental`: Apartment 12, room 3 meters long and 4 wide | 12 square meters | Generic parse clarification |
| `perimeter_requested`: same room, asks its perimeter | 14 meters | Same unnecessary “its” clarification |
| `temperature_negative`: −5 degrees Celsius to Fahrenheit | 23 °F | 23 °F |
| `temperature_paraphrase`: five degrees below zero Celsius | 23 °F | Withheld; treated as a factual-record question |
| `zero_denominator`: 10 divided by 0 | Undefined; explain/refuse | Correctly explains undefined division |
| `zero_numerator`: 0 divided by 10 | 0 | 0 |
| `speed_zero_time`: 150 km in 0 hours | Undefined; explain/refuse | Generic withholding; does not explain zero time |
| `speed_base`: 150 km in 3 hours | 50 km/h | Same generic withholding |
| `speed_contradiction`: same trip exactly 3 and exactly 4 hours | Clarify inconsistent duration | Same generic withholding; does not identify conflict |
| `area_contradiction`: same room length exactly 3 and exactly 5 m, width 4 m | Clarify inconsistent length | **12 square units**, using first length |

The last reply's full answer text was:

> [ev:derived] 12 square units. Read as geometry: A = L x W = 3 x 4. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.

Its provenance says `organ_word_problem`, `schema: geometry`, `value: 12.0`,
`parent_path: act:clarify_specific`, `parent_status: clarification`. The evidence
shows substitution of the first length, not justification for ignoring the
second. Its claim that the required quantities were checked does not establish
that the premises were consistent or uniquely bound.

The percentage paraphrase passes despite changing routes. The numeric percentage
change and moving zero from denominator to numerator also pass. Rectangle wording,
incidental-number wording and negative-number wording expose friction. The
area-versus-perimeter pair does not establish quantity sensitivity because both
requests are refused. The speed contradictions are safely withheld but do not
establish contradiction detection: the well-posed trip is withheld identically.
The incidental apartment pair changes wording as well as introducing the identifier,
so it does not isolate the identifier as the cause of failure.

No data is missing for these arithmetic tasks. The failures concern recognition,
routing and premise binding. Direct inspection confirms the word-problem module
can compute the well-posed speed request as 50, while the actual engine's precision
guard withholds a definition of speed. A prompt rewrite that works is a workaround,
not an engine repair.

Observed client latency: minimum 0.016897 s, median 0.158228 s, maximum 3.241292 s;
7.676740 s total across the requests. These exclude startup and are one-run
observations, not a benchmark. The run summary retains startup capabilities and
process cleanup status.

## Repair and reusable check

Root authorized editing only the source checkout's
`var/ap1-upstream-slim/root/wander-train/word_problems_v1.py`. Before editing,
its hash matched the immutable appliance file:
`391dca52e670889d7ba28d2883359878d5e2ba1891f31830c103af8af9e0d221`.
The repaired hash is
`9f6ce4bae03c87b90884b97a8c144e35a94cfc45a566ad3df723f7d5d2e285c1`.
The durable patch is `tools/usage/reliability/geometry_ambiguity.patch`.

The old geometry recognizer selected the first nearby number for each named role.
The repair binds each explicit length, width, radius, diameter or height to a
length unit and checks all occurrences. Unequal repeated roles, malformed units,
unbound length quantities, inconsistent radius/diameter and mixed units are
refused. Equal repeated roles and irrelevant unitless identifiers are accepted.
Mixed units are deliberately withheld because the existing output lacks a reliable
unit contract; this patch does not silently multiply incompatible raw numbers.

The actual consumer is the existing word-problem fallback in OracleEngine.
Direct calls on all 15 original strings change exactly one module result: the
contradictory room changes from 12 to `None`. That comparison is retained in
`var/usage-20261026/reliability/recognizer-comparison.json`. The combined engine
replay below confirms that no later route restores the wrong numeric answer.

Changed owned files:

- `tools/usage/reliability/cases.json` and `expectations.json`: original task pack.
- `tools/usage/reliability/check_pairs.py`: retained-reply pair checker.
- `tools/usage/reliability/geometry_ambiguity.patch`: source repair for integration.
- `tools/usage/reliability/README.md`: running and interpreting the experiment.
- `tests/usage/reliability/test_reliability.py`: 19 focused checks.
- This report.

Exact checks:

- `.venv/bin/python -B tools/usage/run_batch.py --cases tools/usage/reliability/cases.json --out var/usage-20261026/reliability/run-1`: exit 0; 15/15 HTTP 200.
- `.venv/bin/python -B tools/usage/reliability/check_pairs.py --results var/usage-20261026/reliability/run-1/results.jsonl --out var/usage-20261026/reliability/run-1/pair-report.json`: exit 1 as expected; 6 correct scalars, 3 safe refusals, 5 needless refusals, 1 wrong answer, 3/10 pairs pass.
- `.venv/bin/python -B -m unittest discover -s tests/usage/reliability -v`: exit 0; 19 tests passed. Full output in `var/usage-20261026/reliability/tests.txt`.

Remaining: better within-request pronoun handling,
length/width wording coverage, spelled negative temperature recognition, and the
speed route precedence. The checker is deliberately scalar-level; it does not
prove dimensional correctness or validate provenance claims. The room's
unspecified “square units” remains a presentation limitation even on the passing
scalar case.


## Combined candidate replay

The original 15 requests were replayed against
`var/usage-20261026/candidate-first`, with a new private workspace. The candidate's
word-problem source hash matches the repaired hash above. All 15 returned HTTP
200. Results: **6 correct scalars, 4 safe refusals, 5 needless refusals, 0 wrong
numeric answers in these 15 tasks**. Paired checks remain **3/10**; the unresolved
baseline area request prevents the contradiction pair from passing.

All six previously correct answer texts are unchanged. Fourteen of the fifteen
answer texts, statuses and paths are unchanged. The sole changed answer is
`area_contradiction`:

- Before: `answered`, `organ:math>word:geometry`, 12 square units.
- After: `clarification`, `act:clarify_specific`:
  `What does "its" refer to? Nothing earlier in this conversation names it. Tell me the name.`

The wrong numerical answer is fixed through the full engine. The replacement
clarification still gives an inappropriate explanation: the room appears in the
same request, and the actual defect is conflicting lengths. Thus the safety check
passes, while useful contradiction diagnosis remains unfinished. “Safe refusal”
does not mean task completion or a good explanation.

Exact replay checks:

- `.venv/bin/python -B tools/usage/run_batch.py --runtime /Users/ember/dev/o7vn/var/usage-20261026/candidate-first --cases tools/usage/reliability/cases.json --out var/usage-20261026/reliability/run-2`: exit 0; 15/15 HTTP 200.
- `.venv/bin/python -B tools/usage/reliability/check_pairs.py --results var/usage-20261026/reliability/run-2/results.jsonl --out var/usage-20261026/reliability/run-2/pair-report.json`: exit 1 as expected because five ordinary tasks still fail; 3/10 pairs pass.

Full unmodified replies: `var/usage-20261026/reliability/run-2/results.jsonl`.
Complete before/after reply objects and change flags:
`var/usage-20261026/reliability/run-2/comparison.json`. Scalar and pair judgments:
`var/usage-20261026/reliability/run-2/pair-report.json`. No specialist panels or
fleet-wide score claim accompanies this replay.
