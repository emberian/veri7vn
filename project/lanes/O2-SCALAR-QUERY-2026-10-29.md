# O2-SCALAR-QUERY: viability asks one yes/no question

Lane O2-SCALAR-QUERY, 2026-10-29. Not committed; root commits.
Evidence: `native/evidence/2026-10-29-scalar-output.json`. Raw runs: `var/o2-scalar/`.

**Panel numbers: none.** This change is meant to save work, not to change
answers, and no answer changed.

## What changed

When the reader builds a composed reading, it first checks whether each
fragment picks out any entities at all ("viability"). Before, that check ran
the whole query and fetched every id, statement and attribute just to ask
whether the list was empty. Now the check asks SQLite one question,
`SELECT EXISTS(SELECT 1 FROM n<output>)`, after running exactly the same
stages, language guard and stage metering as before.

| File | Change |
|---|---|
| `native/oracle-core/src/query.rs` | New `Demand { Full, Exists, Count }` and `Delivered { Full(Box<QueryResult>, Selection), Exists(bool), Count(u64) }`. `evaluate_with_mode` takes a demand; scalar demands run `compile()` unchanged, then one aggregate (1 fuel), and fetch no ids, facts or attributes. New `evaluate_language_demand`. `evaluate`, `evaluate_language`, `evaluate_language_shared` keep their signatures and stay Full. New `#[cfg(test)] mod output_contract`. `Count` has no production caller, so both `Count` variants carry `#[cfg_attr(not(test), expect(dead_code, reason = ...))]`; the expectation turns into a warning the day a caller appears. |
| `native/oracle-core/src/reader.rs` | Only the viability closure: it calls `evaluate_language_demand(.., Demand::Exists)` and returns `matches!(.., Some(Delivered::Exists(true)))`. |
| `native/oracle-core/tests/fixtures/query_output_full.json` (new) | Full replies for 27 plan/projection cases, graph mode and shared language mode, recorded from the executor before `Demand` existed. `query.rs` and `reader.rs` are byte-identical between the recording commit `ecfeec3` and `6077aef`. |
| `native/evidence/2026-10-29-scalar-output.json` (new) | Receipt for this lane. |
| `project/lanes/O2-SCALAR-QUERY-2026-10-29.md` (new) | This report. |

## Caller audit

| Caller | Demand | Why |
|---|---|---|
| `reader.rs` viability closure | Exists | Needs one boolean. The fragment's last step has Entities output, so an admitted plan has a nonempty output stage and `Exists(true)` is the same as the old `is_some()`. |
| `reader.rs` final candidate evaluation | Full | Returns entities and records the selection. |
| `runtime.rs` turn execution (line 729) | Full | Saves the selection as the next turn's Previous. |
| `runtime.rs` `Image::query` (line 853) | Full | API returns entities and facts. |
| `image.rs` `query_program` (line 525) | Full | API returns entities and facts. |
| (none) | Count | No caller yet. |

## Behaviour change, accepted by root

Exists no longer pays the row charges for fetching the reply. A fragment whose
Full fetch would have failed with `Error::Limit("materialized rows")` is now
judged viable. Root accepted this: viability asks whether the entity set is
nonempty, and the fetch limit belongs to whoever fetches. Every stage limit and
the language workspace's shared-row limit still apply to Exists. The final
candidate evaluation is still Full and still enforces the fetch limit.
`output_contract::scalar_demands_keep_stage_limits_and_drop_only_fetch_charges`
pins both halves.

## Rust checks (this session)

| Check | Result |
|---|---|
| `cargo clippy -p oracle-runtime-core --all-targets -- -D warnings` | Clean. Before the `expect(dead_code)` marks it failed on two lints, both on the unused `Count` variants. |
| `rustfmt --check` on `query.rs`, `reader.rs` | Clean. `cargo fmt --check` still reports diffs in `oracle-core/src/lib.rs`, `tests/session_contract.rs` and `tests/runtime_session_contract.rs`; this lane did not touch those files. |
| `cargo test -p oracle-runtime-core --lib output_contract` | 4 passed |
| `cargo test -p oracle-runtime-core --lib query::` | 13 passed (includes the 4) |
| `--test composition_contract` | 12 passed |
| `--test reader_contract` | 10 passed |
| `--test runtime_contract` | 14 passed |
| `--test runtime_language_contract` | 2 passed |
| `--test segments_contract` | 31 passed |

What the four `output_contract` tests check: Full replies equal the frozen
file in graph and shared-language mode; Exists agrees with Full on every plan
(8 refused, 17 nonempty, 2 empty in language mode) and leaves an identical
workspace stage table; Count equals the number of distinct ids, including
parallel edges; limit names are unchanged.

## Binaries compared

| | Path | SHA-256 | Built from |
|---|---|---|---|
| HEAD | `var/control-20261029/binding/oracle_native.so` | `bed42ac8...` | root, `6077aef`, debug profile |
| O2 | `var/o2-scalar/candidate/oracle_native.so` | `01ba70ab...` | `6077aef` + this lane + O3's in-progress oracle-python / oracle-logic edits, debug profile |

The O2 binary also contains O3's edits as they stood at build time (now
committed as `0931bd1`). They do not touch the query or reader paths. The
working-tree state at build time is in `var/o2-scalar/candidate-diffstat.txt`.

Machine: Apple M2 Max, 12 cores, shared with other lanes. The 1-minute load
average was 175 to 245 during every run. Treat all timings as noisy.

## Result: the 16 targeted composition questions

The script pins artifact hashes in its cohort file, so the runs use a copy of
`native/tests/composition_cases_targeted_20261029.json` with only the
`artifacts` block replaced (`var/o2-scalar/cohort-o2*.json`).

**At the cohort's own 1-second deadline the comparison is not usable.** Both
debug builds are about 20 times slower than the release builds the cohort was
written for, and 6 to 9 of the 16 questions hit "deadline exceeded" in each.
Which ones hit it moves with load.

At a 60-second deadline (four runs, two in each order), both builds give the
same 1 correct / 4 declined as expected / 7 unanswered / 4 errors in every
run, byte-identical replies on all 16. This matches the release receipt. The 4
errors are "resource limit: composition bytes", lane O1's.

| Run | Order | HEAD CPU s | O2 CPU s | HEAD wall s | O2 wall s |
|---|---|---|---|---|---|
| 1 | HEAD then O2 | 6.10 | 5.24 | 8.48 | 5.65 |
| 2 | HEAD then O2 | 5.14 | 5.18 | 5.82 | 5.56 |
| 3 | O2 then HEAD | 5.00 | 4.86 | 5.54 | 5.07 |
| 4 | O2 then HEAD | 5.33 | 5.73 | 5.74 | 6.60 |
| Median | | 5.24 | 5.21 | 5.78 | 5.61 |

Per question, median of four runs (seconds):

| Question | Outcome | HEAD CPU | O2 CPU | HEAD wall | O2 wall |
|---|---|---|---|---|---|
| `baseline_city_website_saskatoon` | unanswered | 0.199 | 0.214 | 0.229 | 0.238 |
| `segment_city_website_population_saskatoon` | unanswered | 0.543 | 0.530 | 0.612 | 0.584 |
| `segment_city_population_website_saskatoon` | unanswered | 0.667 | 0.637 | 0.800 | 0.710 |
| `nested_university_city_website_saskatoon` | unanswered | 0.219 | 0.209 | 0.244 | 0.225 |
| `nested_university_city_website_population_saskatoon` | unanswered | 0.166 | 0.168 | 0.211 | 0.184 |
| `nested_university_city_website_population_belfast` | unanswered | 0.166 | 0.168 | 0.176 | 0.181 |
| `nested_headquarters_city_website_population_bristol` | errors | 0.350 | 0.347 | 0.382 | 0.379 |
| `segment_city_website_population_bristol` | unanswered | 0.505 | 0.533 | 0.536 | 0.570 |
| `nested_human_count_bristol` | answered_correct | 0.145 | 0.142 | 0.158 | 0.150 |
| `ambiguous_human_selection_bristol` | declined_expected | 0.166 | 0.167 | 0.176 | 0.185 |
| `nested_university_count_cardiff` | errors | 0.347 | 0.322 | 0.394 | 0.334 |
| `ambiguous_university_selection_cardiff` | errors | 0.331 | 0.328 | 0.350 | 0.337 |
| `empty_segment_changed_population_bristol` | declined_expected | 0.501 | 0.525 | 0.571 | 0.591 |
| `empty_nested_changed_population_bristol` | declined_expected | 0.151 | 0.132 | 0.165 | 0.134 |
| `empty_segment_conflicting_city_anchors` | declined_expected | 0.491 | 0.482 | 0.513 | 0.501 |
| `empty_parent_headquarters_saskatoon` | errors | 0.344 | 0.314 | 0.430 | 0.325 |

## Result: 100 validation questions (`qualify_reader.py --cases 100`)

With `--expected-coverage whole_and_exact_fragment_outer_v1+exact_segment_and_single_nested_v1`.
The script allows deadlines up to 10 s, so the long runs use 10 s. Every run
exits 1 because of the script's non-answer gates (macOS has no `/proc` memory
figures), not because of answers.

| Run | Deadline | Correct | Wrong | Refused | Unknown | Errors | CPU sum s | Wall sum s | p50 s | p95 s |
|---|---|---|---|---|---|---|---|---|---|---|
| HEAD | 1 s | 36 | 0 | 4 | 60 | 0 | 7.95 | 12.89 | 0.075 | 0.457 |
| O2 | 1 s | 35 | 0 | 4 | 60 | 1 | 8.17 | 13.15 | 0.062 | 0.401 |
| HEAD a | 10 s | 36 | 0 | 4 | 60 | 0 | 8.82 | 12.71 | 0.059 | 0.403 |
| O2 a | 10 s | 36 | 0 | 4 | 60 | 0 | 8.01 | 10.48 | 0.043 | 0.324 |
| O2 b | 10 s | 36 | 0 | 4 | 60 | 0 | 7.87 | 9.68 | 0.047 | 0.257 |
| HEAD b | 10 s | 36 | 0 | 4 | 60 | 0 | 7.98 | 10.00 | 0.041 | 0.281 |

All four 10-second runs agree on every question's outcome, answer, status,
reason, matched programs, successful readings, unsupported programs and
ambiguous executions. The one difference at 1 s is validation row 200, which
needs about 0.7 s of CPU in a debug build and went over the deadline in the O2
run at load 230; it answers correctly in every other run of both builds.

The ten slowest questions (mean of the two 10-second runs, seconds):

| Row | Kind | Outcome | Matched programs | HEAD CPU | O2 CPU | HEAD wall | O2 wall |
|---|---|---|---|---|---|---|---|
| 200 | QueryAttrQualifier | answered_correct | 6 | 0.709 | 0.702 | 1.309 | 1.127 |
| 2688 | SelectBetween | answered_correct | 8 | 0.315 | 0.308 | 0.363 | 0.360 |
| 5930 | QueryAttr | answered_correct | 11 | 0.290 | 0.304 | 0.451 | 0.379 |
| 5826 | SelectBetween | answered_correct | 9 | 0.281 | 0.247 | 0.390 | 0.275 |
| 748 | QueryRelation | answered_correct | 24 | 0.260 | 0.226 | 0.465 | 0.267 |
| 3371 | QueryRelation | answered_correct | 10 | 0.241 | 0.224 | 0.265 | 0.231 |
| 6407 | Count | unknown | 0 | 0.230 | 0.225 | 0.257 | 0.272 |
| 3290 | QueryAttr | unknown | 3 | 0.228 | 0.204 | 0.317 | 0.245 |
| 1475 | What | answered_correct | 9 | 0.200 | 0.191 | 0.256 | 0.219 |
| 6111 | QueryAttrQualifier | answered_correct | 4 | 0.186 | 0.180 | 0.240 | 0.214 |

Per-question times for all 100: `var/o2-scalar/reader100-per-question.json`.

## Verdict

Answers are identical. **No timing gain is visible above the noise.** O2 is 0
to 11 percent lower in the sums, but HEAD's own two reader runs differ by 10
percent in CPU and 27 percent in wall time. The likely reason is that the
fetch Exists skips is small next to the stage materialization it still does.
This was not profiled.

## What this cannot do yet / what remains

- Linux receipt: root's.
- Release-profile timing on a quiet machine. Both binaries here are debug
  builds on a laptop at load 175 to 245. A release pair on hbox is the
  measurement that could show a gain.
- Scalar API flag for pure queries (`Image::query`, `query_program`). They
  still fetch the full reply.
- `Demand::Count` has no production caller.
- The integer-posting image adapter is NOT built.

## Questions for the reviewer

1. Should unused `Count` stay, behind `expect(dead_code)`, until the scalar
   API flag exists? Or should it go and come back with its first caller? Its
   tests (Count equals distinct ids on parallel edges) would go with it.
2. With no measured gain, is the change still worth merging for its contract
   (viability can no longer fail on a reply fetch it never uses), or should it
   wait for a release-build measurement?
3. The 16-case cohort's 1 s deadline cannot be met by debug builds. Should
   controls for this cohort always be release builds, or should the lane recipe
   name the deadline used for debug comparisons?
4. Exists still charges every stage row to the workspace's shared-row limit,
   so a viability probe can still fail on `language shared rows`. Is that the
   intended place for that limit, given the same rows are then reused by the
   Full evaluation?
