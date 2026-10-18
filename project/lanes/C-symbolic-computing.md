# Computing continuation, 18 October 2026

Owner: Codex symbolic/computing. C packet checked on macOS and ready for
integration. The proof gate, native build, all shipped panels, two fresh seeds,
40 explicit/differential probes and 11 actual-dispatch checks pass. Linux
compilation/parity is assigned to the package owner. Next-packet semantic
counterexamples remain explicitly open below.

## What changed

The old git recognizer treated almost any mention of a stash as a request to
save changes. It therefore answered “brings back the stash” with `git stash`.
The new recognizer distinguishes saving, restoring, listing, and restoring while
keeping the saved stash. The latter two have typed command-table entries. Git
commands are never run. The proofs establish table properties and the command
put in a reply; they do not establish the semantics of Git itself.

Existing computations become reachable through plural password requests,
smallest-prefix requests without an address, bare Python references and
possessive signature requests, and a three-sentence differential-wheel request
whose parameters are all supplied. The original narrative guard remains for
other robotic stories. The SQL answer no longer falsely says it ran SQLite.

Entropy is the only computation whose precision changes: its direct logarithm
of 62 has an interval too wide at both 53 and 80 bits. A local diagnostic of
the exported enclosure found 120 bits sufficient. No family-wide precision
change is made. Self tests remain part of the Isabelle build but are no longer
exported as eagerly evaluated values in each newly started process.

## Review by specialist

These rows distinguish examined behavior from the still-unexamined parts of
each specialist. Final panel scores belong below; a green family score does
not imply all of these boundaries have been reviewed.

| Specialist ID | Concrete examination and change | Remaining boundary |
|---|---|---|
| `networking` | Shipped prefix-for-hosts questions without an address were blocked at the initial recognizer gate; allow that explicit request. Actual dispatcher now preserves impossible `/20` subdivisions of `/24`. | Other IPv4 recognition and address-direction ambiguity retain their existing implementation; fresh generator instances reuse its author's templates. |
| `embedded` | Existing timer/UART/UBRR/CTC computations were scored on both shipped splits and reseeded generator instances. A deeper probe found two 3-bit memory locations incorrectly reported as 0 bytes, and a 7E1 characters/sec answer labelled bytes/sec. These repairs belong to the next packet. | No independent hardware timing, register-width or clock-tolerance model was added; the capacity and unit counterexamples remain open. |
| `cyber` | Plural passwords were unreachable. The entropy interval for 12 alphanumeric characters was too wide at 53 and 80 bits; 120 bits permits the checked enclosure to render 71.45. Zero-alphabet refusal survives actual dispatch. | Uniform independent character choice and constant guess rate are assumptions; entropy models for human-selected passwords are outside this work. |
| `linux-v2` | Actual dispatch dropped the invalid octal mode 889 refusal; the numeric-mode context now preserves it. Existing command-related computations were scored unchanged. | No operating-system execution semantics or independent cron/calendar model was added. |
| `git` | The heldout restore-stash question wrongly returned save-stash. Distinguish save, restore, restore-and-keep and list; handle cherry-picks/shows inflections. Explicit delete/compare/encrypt/advice probes must decline. | Commands are table values, not executed transitions; compound or ambiguous intent interpretation remains unproved. |
| `sql` | Independent semantics now target DISTINCT value classes and grouped COUNT(*) source partitions, including duplicate rows, NULL keys and equal integer/real values. SQLite probes compare entire rendered result rows. | General grouped SUM/AVG/MIN/MAX, stable tie ordering and SQLite binary-floating arithmetic remain outside the new correspondence statements. |
| `python` | Bare `Explain what NAME does` and possessive signature requests were rejected despite matching reference rows. Recognize those forms; preserve case and let the checked resolver handle missing or ambiguous names. | The Python 3.12.3 reference transcription is data, and the generated question templates are not independent coverage of natural language. |
| `python-r2` | The same reference implementation serves this separate specialist ID; its own shipped panel and fresh generator instances are scored separately. It receives the same bare-name and possessive fixes. | No separate proof of Python runtime behavior or independent reference source was added. |
| `robotics-v2` | Three-sentence differential-drive requests with explicit wheel speeds and separation were blocked as narrative. A bounded direct-request exception admits them; both angular signs are probed. | Ideal no-slip motion, units and extracted parameters remain assumptions; general stories and unmodelled mechanics still decline. |

## Checked SQL statements

The `select_distinct_relational` statement says an executed nonaggregate,
ungrouped SELECT DISTINCT with no LIMIT returns exactly one representative
of each projected SQL-value class among rows satisfying the independent
WHERE meaning. ORDER BY is allowed. The value classes identify an integer
with an equal real and NULL with NULL. This establishes multiplicity as well
as membership, and does not assume the engine's deduplication was correct.

The `select_group_count_relational` statement covers
`SELECT g, COUNT(*) ... WHERE ... GROUP BY g` without ORDER BY or LIMIT.
Its output has each SQL-value key once, all and only the keys of the rows
satisfying WHERE, and the count for a key is the length of the independently
defined source-row partition. Duplicates and NULL keys count. It does not
assert general grouped SUM/AVG/MIN/MAX correspondence.

## Checked artifact and panel results

Managed proof receipt:
`var/computing/remote-attempts/20261018T073456Z-61c7bff22545/receipt.json`.
Hbox finished in 2m25s with exit 0 and
`VERI7VN_COMPUTING PASS theorems=116 oracles=0`. Both new SQL correspondence
statements are in the final oracle scan. The export hash is
`7f5aa0716f205e481eab88138efcdd459bf203398c0e908a870d8c29d2a9df0e`.

The shared immutable native compiler used that exact receipt:
`var/computing/native-attempts/20261018T075347Z-6deb1b6ec233/compile-inputs.json`.
Its binary is 1,199,752 bytes, SHA-256
`967e1dc818741cc58292973c3c324c8470f72f5bb25012d901edadd97e3e4107`.
The receipt binds the actual generated code, commons.sml, recognizer.sml and
main.sml inputs. The subsequent build-script and table-checker changes alter
no theorem or executable input.

All nine shipped specialist scorers: **1,364/1,364 right, 0 wrong, 0 false yes,
0 valid withholds**, versus the prior verified binary's 1,274 right, 1 wrong,
89 valid withholds and 0 false yes. Counts include correctly declined invalid
items. The single previous wrong was git's restore-stash question.

| Specialist | Before dev | Before heldout | Final dev | Final heldout |
|---|---:|---:|---:|---:|
| `networking` | 74/74 | 68/71 | 74/74 | 71/71 |
| `embedded` | 25/25 | 25/25 | 25/25 | 25/25 |
| `cyber` | 19/20 | 16/20 | 20/20 | 20/20 |
| `linux-v2` | 42/42 | 42/42 | 42/42 | 42/42 |
| `git` | 10/10 | 7/10 | 10/10 | 10/10 |
| `sql` | 61/61 | 61/61 | 61/61 | 61/61 |
| `python` | 198/198 | 186/224 | 198/198 | 224/224 |
| `python-r2` | 198/198 | 186/224 | 198/198 | 224/224 |
| `robotics-v2` | 36/36 | 20/23 | 36/36 | 23/23 |

Evidence: `var/computing-beyond/shipped-final.json` and
`var/computing-beyond/parity-final/`. The scoped parity harness independently
records these same panel counts. Its overall verdict remains **INCOMPLETE**:
it has no head/core comparison, LANE/SELF or complete BUDGET measurement.
These panel results are not a claim that all six admission criteria passed.

The measured median request time is at most 0.214 ms across the nine
specialists. Cyber's maximum in-binary time is 76.559 ms; its p50 is 0.1285 ms
against the 50 ms p50 budget. Five process-start measurements have a median
of 4.054 ms versus 13.92 ms before; the first new-binary launch took 250.126 ms,
so this is not a guarantee about first-ever launch latency. The shared binary
shrinks from 1,297,496 to 1,199,752 bytes, but still exceeds a 1 MB individual
store budget if charged in full to one specialist.

`beyond.py` runs the shipped generators without writing upstream. Offset
718103 is the tuning set; offset 910619 was generated after recognizer tuning
froze and was not used to tune it. SQL has no shipped generator. These are new
instances of the same author's templates, not independent language coverage.

| Panel | Prior kernel right / wrong / valid withholds | Original organ right / wrong / valid withholds | Final kernel right / wrong / valid withholds |
|---|---|---|---|
| Tuning 718103, 1,238 items | 1,151 / 1 / 86 | 1,152 / 1 / 85 | 1,238 / 0 / 0 |
| Untouched 910619, 1,253 items | 1,156 / 1 / 96 | 1,158 / 1 / 94 | 1,253 / 0 / 0 |

All three columns have 0 false yes. Per-specialist splits are recorded in
`var/computing-beyond/fresh-final-tune/report.json` and
`var/computing-beyond/fresh-final-eval/report.json`.

`probes.py` scores **40/40 right, 0 wrong, 0 false yes**, versus 22/40 right,
3 wrong and 2 false yes before. Twenty-four cases were written by the
recognizer/proof author; sixteen compare every SQL result row/value against
in-memory SQLite. All sixteen SQL cases already passed before: their purpose
is independent executable regression evidence for the new correspondence
proofs. Receipt: `var/computing-beyond/probes-final.json`, SQL seed 921877.

`tables_check.py` reports `TABLES PASS`. Its git check retains original command,
note, warning and order comparisons, checks unchanged patterns, and explicitly
accounts for two stash extensions and four intentional pattern changes.
Changed pattern behavior is tested by probes rather than pretending it is an
unchanged transcription. Python remains the original 856-row reference.

Earlier queued attempts were cancelled after collector transport failures.
The first actual proof attempt hit its 16 GiB cap during an uninstantiated
search; direct conjunction projection fixed that. Two subsequent proof runs
exposed normalization and induction obligations, which were repaired without
weakening the statements. Only the final passed receipt supplies the artifact.

## Consumer boundary

`capabilities.json` registers cyber `impossible` and `imprecise` refusals and
robotics `imprecise` refusals. The shared runtime validator accepts the file
and unions those kinds with the original manifests. The evidence declarations
say what the kernels do and what interpretation remains untrusted; they are
not per-answer proof certificates. New git intents retain `git_cmd`.

`var/computing-beyond/composition-final.json` records **11/11 actual-dispatch
checks** against the final binary hash. New git apply/list, Python bare-name
and possessive queries, entropy, prefix sizing, DISTINCT and grouped COUNT
reach their answers. Zero-alphabet entropy, impossible `/20` subdivision of
`/24`, and Unix mode 889 retain `withheld/impossible`. Every case is
`taken=true`, `dispatch.decisive=true`, with only the specialist stage run.
The two missing networking/Linux contexts have bounded capability additions.
These checks exercise composition; declarations still do not certify the
question's interpretation.

The primary `build.sh` delegates to shared `tools/dev/native-compile`, requiring
a passed managed receipt matching computing and commons theories and validating
the export hash. It freezes the actual MLB inputs, records hashes and binary
size, and publishes the binary atomically. An optional argument selects the
exact receipt. Its negative check fails when no matching receipt exists, so
local stale heaps cannot silently supply the new build.

## Remaining

General grouped SQL aggregate correspondence, stable ORDER BY with ties,
SQLite floating-point compatibility, natural-language interpretation, and
resource guarantees for arbitrarily large supplied programs are not proved.
The checked artifact is ready for Linux compilation and parity; that receipt
is pending with the package owner. No Linux pass is claimed here yet.

Concrete next-packet counterexamples are recorded under
`var/computing-beyond/embedded-next-challenges.jsonl` and
`var/computing-beyond/next-semantic-challenges.json`. In addition to embedded
capacity truncation and UART unit wording, the Python and Python-r2 reference
reader says Python's `os` module has no `remove` when that entry is merely
absent from its partial reference table. Cyber recognition also passes an
explicitly nonuniform character-selection question to the uniform entropy
model. These are open semantic repairs, not covered by the current panel gain.
