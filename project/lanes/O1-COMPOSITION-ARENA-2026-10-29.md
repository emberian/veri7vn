# O1: composition arena

Owner: lane O1-COMPOSITION-ARENA. Consumer: the native learned-language reader
(`reader.rs` calls `composition::match_composed`). Evidence:
[`native/evidence/2026-10-29-composition-arena.json`](../../native/evidence/2026-10-29-composition-arena.json).
No specialist-panel numbers: this lane changes storage, not what the reader can read.

## What was wrong

Four of the sixteen frozen cohort questions stopped with
`resource limit: composition bytes`. The earlier diagnosis showed why: one
question region held 1,290 alternative readings, each stored as a full copy of
its program and of a text description of every piece it was built from, plus a
second full copy used to spot duplicates. Those 1,290 readings were assembled
from only about 650 learned pieces, so almost all of the 2 MiB budget held
repeats.

## What the change does

The reader now keeps one shared store per question (an "arena"):

- Each distinct program step is stored once, keyed by its exact JSON text.
  Each distinct program is stored once, as a short list of step numbers and
  dependency numbers. Two programs get the same number exactly when their JSON
  text is equal, which is the identity the old code used.
- A reading is a small record: its word span, its program number, its support,
  and where it came from (a learned fragment's wording, up to four segment
  pieces by number, or a nested recipe plus its chosen child readings).
- Duplicate detection, the resolved-reading count, the viability cache and the
  final duplicate check all compare these numbers instead of JSON strings. The
  viability cache is now `BTreeMap<ProgramId, bool>` (it was string-keyed and
  local to `match_composed`; nothing outside needed the string).
- Full programs and the public description text are rebuilt only where the old
  interface needs them: when the semantic check runs a program, when a nested
  recipe or the outer question splices child programs in, and when the final
  `MatchedProgram` list is produced.
- The byte budget is charged for what is kept: each stored step and program
  once, each reading record at its size, and short-lived rebuilt programs while
  they exist (charged, then released). Every charge is tagged with an owner so a
  measurement can say where bytes went. Fuel is still spent on every charge and
  never refunded.

Files: `native/oracle-core/src/segments.rs`, `native/oracle-core/src/composition.rs`,
`native/oracle-core/tests/segments_contract.rs`,
`native/oracle-core/tests/composition_contract.rs`. No change to `reader.rs`,
`grammar.rs`, the viability closure, any limit, the cohort or any expected fact.
`Chart::new` now takes the shared ledger instead of a byte count; it is
crate-internal.

A measurement hook, `composition::probe`, records each call's peak bytes and
owners. It is off unless a test calls `probe::enable()`; when off it costs one
flag read per question and never changes a result or error.

## What was checked

| Check | Result |
|---|---|
| `cargo test` on segments, composition, reader, runtime_language contracts | 35, 12 (+1 ignored measurement), 10, 2 passed |
| `cargo clippy -p oracle-runtime-core --all-targets -- -D warnings` | exit 0 |
| `rustfmt --check` on the four owned files | clean |
| `cargo fmt --check` (whole crate) | reports `lib.rs`, `tests/runtime_session_contract.rs`, `tests/session_contract.rs`, same as on dev; not this lane's files |
| Public JSON of every `match_composed` call in those suites, old vs new | 108 of 109 calls byte-identical (sorted-lines SHA-256 `28ba82c9…706e`); the one difference is the new fit test below |

How the JSON comparison was made: a copy of the dev sources and the new
sources each got one extra line that appends `(question, level, serialized
output or error)` for every call; both ran the same four suites (including the
four new tests). The line was removed from the new source afterwards.

New tests, each run on the old code first:

| Test | What it compares | Old code | New code |
|---|---|---|---|
| `nested_parent_over_chain_child_publishes_chain_provenance_and_child_witness` | the exact published template, child witness span/program and supports for a nested reading over a two-piece chain | pass | pass |
| `chain_paths_with_equal_programs_share_one_node_and_keep_first_provenance` | two piece paths with the same program: one reading, first path's description, one semantic check | pass | pass |
| `shared_unit_chains_are_stored_once_and_fit_the_unchanged_envelope` | 28 pieces that build 2,401 distinct four-piece programs: all 2,401 checked once, under the unchanged 2 MiB budget | fails: `composition bytes` | pass |
| `shared_unit_chains_still_exhaust_a_smaller_byte_envelope` | same input under a 100,000-byte budget still stops with `composition bytes` | pass | pass |

Invariants and how each was checked:

| Invariant | Check |
|---|---|
| All alternatives kept; support never picks a winner | identical public JSON; fit test counts 2,401 checks |
| Child-region witnesses survive; equal parent programs cannot erase a differing child | existing `identical_child_programs_at_distinct_boundaries_spend_distinct_witness_nodes`, `omitted_nested_x_*` tests; the reading key includes every child's span and program |
| Guard order: outer syntax, then base viability over the whole demanded union, then resolution | code order unchanged; `empty_base_union_still_checks_unsupported_sibling_before_product_pruning`, `only_viable_base_choices_enter_nested_product_without_losing_witness_regions` and the viability-call counts in `repeated_nested_child_admission_reuses_program_viability_cache` pass |
| Empty child alternatives drop the nested recipe | unchanged code path; `empty_base_candidates_are_pruned_before_nested_products_and_node_admission` (100 checks, 0 parent products) |
| Error names unchanged | identical error lines in the JSON comparison (`composition bindings`, `Invalid(...)`); smaller-budget test still gives `composition bytes` |
| Reader7 piece order in chain assembly (source first, then concept filters, then others, each in surface order) | `four_source_bounded_units_and_concept_first_order_match_pinned_assembly`, `source_qualifier_stays_attached_before_surface_first_concept_filter` |
| Temporary charges released, kept ones not refunded | the ledger panics on any release larger than its owner's charge; all suites and both qualification runs ran without that panic |

## Frozen cohort (16 questions)

The script only accepts extensions whose hashes are pinned in the cohort's
`artifacts` block, so it ran on a copy whose only change is that block
(`var/o1-arena/cohort-repinned.json`; original SHA-256 `388810fd…b853`
unchanged). Control is root's shared debug build of dev; candidate is this
lane's debug build. Both report the same coverage string.

| Case | Control | Candidate |
|---|---|---|
| baseline_city_website_saskatoon | unanswered (answer_form) | same, byte-identical result |
| segment_city_website_population_saskatoon | unanswered (answer_form) | same, byte-identical |
| segment_city_population_website_saskatoon | unanswered (answer_form) | same, byte-identical |
| nested_university_city_website_saskatoon | unanswered (answer_form) | same, byte-identical |
| nested_university_city_website_population_saskatoon | unanswered (answer_form) | same, byte-identical |
| nested_university_city_website_population_belfast | unanswered (answer_form) | same, byte-identical |
| nested_headquarters_city_website_population_bristol | error: composition bytes | unanswered (answer_form; readings say `1` and `University of Bristol`) |
| segment_city_website_population_bristol | unanswered (answer_form) | same, byte-identical |
| nested_human_count_bristol | correct: 6 | same, byte-identical |
| ambiguous_human_selection_bristol | expected decline | same, byte-identical |
| nested_university_count_cardiff | error: composition bytes | **correct: 2** |
| ambiguous_university_selection_cardiff | error: composition bytes | expected decline (answer_form) |
| empty_segment_changed_population_bristol | expected decline | same, byte-identical |
| empty_nested_changed_population_bristol | expected decline | same, byte-identical |
| empty_segment_conflicting_city_anchors | expected decline | same, byte-identical |
| empty_parent_headquarters_saskatoon | error: composition bytes | expected decline (no_template) |

| Totals | correct | expected decline | unanswered | wrong | errors |
|---|---|---|---|---|---|
| Control | 1 | 4 | 7 | 0 | 4 |
| Candidate | 2 | 6 | 8 | 0 | 0 |

The script exits 1 because the control run has errors. The Bristol
headquarters miss is the same learned `which X1` → `Count` conflict already
recorded for the other single-entity misses; it is not new.

## Bytes at peak on the four former failures

Measured by the ignored test `composition_byte_peaks_on_frozen_cases` on the
real image. Each question calls the composer twice (level 0, level 1).

| Case | Old, at failure | New peak, level 0 | New peak, level 1 | Share of 2 MiB |
|---|---|---|---|---|
| nested_headquarters_city_website_population_bristol | 2,097,670 | 30,378 | 969,147 | 46% |
| nested_university_count_cardiff | 2,097,469 | 27,917 | 969,034 | 46% |
| ambiguous_university_selection_cardiff | 2,097,748 | 30,403 | 969,166 | 46% |
| empty_parent_headquarters_saskatoon | 2,097,185 | 17,483 | 960,831 | 46% |

At the level-1 peak the largest owners are the step/program store (about
570,000 bytes), reading records (232,280), the viability cache (about 103,000)
and segment pieces (about 37,800). These are the reader's own accounting
totals, not measured process memory.

## 100-question reader qualification

| Run (load average) | correct | refused | unknown | wrong | errors | process wall s | peak RSS bytes |
|---|---|---|---|---|---|---|---|
| control, run 1 (217) | 36 | 4 | 60 | 0 | 0 | 30.6 | 98,287,616 |
| candidate, run 1 (224) | 35 | 4 | 60 | 0 | 1 | 34.2 | 97,959,936 |
| candidate, run 2 (185) | 36 | 4 | 60 | 0 | 0 | 28.7 | 98,418,688 |
| control, run 2 (174) | 36 | 4 | 60 | 0 | 0 | 25.0 | 98,107,392 |

Finding: in run 1 the candidate hit the 1-second deadline on validation row
200. Control answered that row in 0.999 s of wall time, 1 ms under the
deadline. The candidate used less CPU on it (0.42 s against 0.75 s) and lost on
wall time while this Mac's load average was about 220 (other lanes building).
In run 2, with the order reversed, control and candidate agree on all 100
outcomes. This is a debug-build timing margin, not a changed reading. Wall
times and RSS are descriptive only. Every run exits 1 because the tenant memory
check reads `/proc`, which macOS does not have; that is the same for both.

`native/docs/CAPABILITIES.md` is unchanged: the counts are the same.

## What remains

- Linux build and the hbox receipt (root).
- Release builds of the Python extension on this Mac produce a dylib that
  `dlopen` rejects ("mis-aligned LINKEDIT string pool"), for control and
  candidate alike. All numbers above are debug builds.
- Out of scope: deeper nesting, analogy, clause wrappers.
- The step/program store is now the largest owner. If a later question needs
  more room, step dependencies could be stored more compactly; nothing here
  needs it.

## Questions for the reviewer

1. Step identity uses the JSON text of `(function, inputs)` and keeps
   dependencies separately. I argued this is equal-iff the old whole-program
   JSON is equal (field order is fixed and JSON values are self-delimiting);
   please check that reasoning, including `arbitrary_precision` numbers.
2. The viability check now charges the rebuilt program before calling the
   closure. In a question sitting right at the budget edge this could stop with
   `composition bytes` slightly earlier than before; it cannot change an answer.
3. When two segment paths give the same program, the first path's description
   is kept (as before). The new test pins this; please confirm "first in walk
   order" is the intended rule and not an accident of the old code.
4. The probe hook lives in production code behind a runtime flag, because a
   compile-time switch would have needed a `Cargo.toml` lint entry this lane
   does not own. If a Cargo feature is preferred, it is a small move.
5. The cohort ran on a copy with re-pinned artifact hashes. If root wants the
   receipt to use the original file, the script would need a way to accept
   unpinned local builds.
