# S4: the arena and the scalar query, qualified together

Lane S4-COMBINED-QUALIFICATION, 2026-10-29. Not committed; root commits. Consumer: root.
Receipt: [`native/evidence/2026-10-29-combined-qualification.json`](../../native/evidence/2026-10-29-combined-qualification.json).
Raw runs: `var/s4-combined/` (macOS, and the Linux results fetched to `var/s4-combined/hbox/`) and
`/tank/lanes/o7-native-20261029/qualification-combined/` on hbox.
**Panel numbers: none.** The 116 questions are component checks on one finite image, not a panel score.

## What was run

Candidate: HEAD `cdc474c` (O1 composition arena and O2 scalar `Exists`/`Count` demand), default features.
The Linux archive was cut from the committed tree, so lane O4's edits are not in it. On macOS the
binary was built from the shared working tree; O4's uncommitted files were in
`native/oracle-reasoning`, `tools/`, `native/tests/test_python_domains.py` and
`native/docs/CAPABILITIES.md`, none in `oracle-core` or `oracle-python`, and the reasoning feature
is off, so none of it is in the binary (`var/s4-combined/build-diffstat.txt`).

| | Candidate | Control |
|---|---|---|
| macOS (debug) | `5fc84f8d...` built from `cdc474c` | `bed42ac8...`, root's debug build of dev at `6077aef`, before O1 and O2 |
| Linux (release) | `77a69bff...` built with `swarm-build`, 2 jobs, 74 s | `499e9e46...`, release build of `2fda9fe`, pinned in the retained receipts |

Full hashes are in the receipt. Image SHA-256 `8fcb1db9...42f4`.

## 16-case cohort

Four runs per platform, two with the control first and two with the candidate first. Every run gave
the same result for every case, with the same result hash for every case that does not error.

| Platform | Deadline | Control (correct / expected decline / unanswered / wrong / errors) | Candidate |
|---|---|---|---|
| macOS debug | 60 s | 1 / 4 / 7 / 0 / 4 | 2 / 6 / 8 / 0 / 0 |
| Linux release | 1 s (the cohort's own) | 1 / 4 / 7 / 0 / 4 | 2 / 6 / 8 / 0 / 0 |

Twelve of the sixteen cases are byte-identical between control and candidate on both platforms. The
four that differ are exactly the four that failed with `resource limit: composition bytes`:

| Case | Control | Candidate |
|---|---|---|
| nested_headquarters_city_website_population_bristol | error: composition bytes | unanswered (`answer_form`) |
| nested_university_count_cardiff | error: composition bytes | correct, 2 |
| ambiguous_university_selection_cardiff | error: composition bytes | expected decline (`answer_form`) |
| empty_parent_headquarters_saskatoon | error: composition bytes | expected decline (`no_template`) |

The candidate's results for the sixteen cases are the same on both platforms. The eight unanswered
positives all still end in `answer_form`; the arena removed the errors and did not make them answerable.

## 100 reader questions

Control, candidate, candidate, control on Linux; control, candidate, control, candidate on macOS.

| Platform | Deadline | Control | Candidate | Questions where any compared field differs |
|---|---|---|---|---|
| macOS debug | 10 s | 36 / 4 refused / 60 unknown / 0 wrong / 0 errors (2 runs) | same (2 runs) | 0 |
| Linux release | 1 s | same (2 runs) | same (2 runs) | 0 |

Compared per question: outcome, status, answer, reason, matched programs, successful readings,
unsupported programs, ambiguous executions. No run had a deadline miss.

## Timings (descriptive only)

| Run set | Load average at start | Reader-100 query CPU sum, control / candidate | p95 |
|---|---|---|---|
| Linux release | 10 to 14 | 1.51 s, 1.51 s / 1.51 s, 1.49 s | 0.045 to 0.046 s |
| macOS debug | 80 to 160 | 7.38, 7.79 s / 7.91, 7.33 s | 0.24 to 0.38 s |

Linux cohort median question time was 0.045 to 0.065 s for the control and 0.058 to 0.069 s for the
candidate in every run. The candidate does real work on the four cases where the control stopped early
with an error, and four runs are not a matched experiment. No timing claim is made; the
earlier lanes' finding (no gain visible above noise) stands.

## What this does not establish

- It does not separate O1 from O2; each was qualified alone earlier and this is the combination only.
- The two controls differ by platform and neither contains O1 or O2.
- Debug on macOS and release on Linux; timings are not comparable across them.
- The 116 questions are component checks. The reader sample is unchanged, so nothing here says the reader
  can read more questions; the only gain is on the targeted cohort.
- The 16 cohort questions are still not accepted: eight positives remain unanswered.

## Documents updated

The two reader rows in `native/docs/CAPABILITIES.md` and a new dated paragraph in
`project/lanes/NCOMP-CASES-2026-10-29.md` (the original failed result is untouched above it).

## What remains

- Package refresh: root's item; this lane did not touch or check the package.
- Reader retrain with the plural patch, so the replicated `Count` skeleton behind the `answer_form`
  refusals can be reviewed at the source.
- A release-profile timing pair on a quiet box, matched, if a speed claim is wanted.
