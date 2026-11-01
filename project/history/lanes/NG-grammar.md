# Native learned reader tables

Owner: Codex lane NG, 2026-10-28. Consumer: the shared native image builder and
language reader entry point. The second step implements the whole-question
consumer in `reader.rs`; root owns Runtime/PyO3 integration. There are **no new
specialist-panel numbers and no theorem statements** from this lane.

## What changed

- `native/tools/export_reader_tables.py` is an explicitly untrusted offline
  builder. It invokes the pinned Reader6 and Reader7 learners directly, without
  loading KQA or Engine, and never opens a pickle. It emits plain versioned JSON.
  The default cache10 sequence, both template levels, every skeleton and support
  count, fragment/outer/segment fallback rows, outer X shapes, admitted aliases,
  operator/kept/glue words and answer forms are retained. Metadata records source,
  training and KB hashes and learning settings. A fixture and explicit-JSON
  input mode work without training data. Training mode requires hash seed 0.
- `native/oracle-core/src/grammar.rs` imports those rows atomically into indexed
  SQLite tables. The tables live in the shared release image. No tenant loads a
  learned Python table graph, relearns a corpus or mutates a global alias table.
- Native lookup preserves all alternatives and their counts. An exact entry
  prevents fallback even when all its skeletons fail the admission guards.
  Whole templates use Reader6's hidden-word replication rule; compositional
  tables use Reader7's replication, dominance and outer replication rules.
  Kept asking words cannot disappear as glue.
- Whole-template matching binds slots in question order, keeps canonical
  spelling alternatives, fills numeric units and returns candidate programs.
  The generic expansion helper also rebases dependencies when inserting X
  programs. Answer-form checking vetoes all successful readings if any has a
  forbidden answer kind. It must run after execution, not on candidate programs.

The importer validates versions, positive support, slot structure, prior-step
references and source/filter segment roles. It rejects duplicate keys. A failed
import rolls back schema and rows through a savepoint. Host limits bound export
rows/bytes, lookup alternatives, combinations, program steps and materialized
output; release admission additionally limits one skeleton to 1 MiB, 1,024 steps
and 16 inputs per step. Budget charges include serialized lookup bytes and each
backtracking step. One mutable backtracking path avoids quadratic frontier
copies. Exhaustion refuses the request rather than presenting a truncated list
as complete ambiguity. SQLite VM work still needs the image's progress hook.

## Connected whole-question consumer

`native/oracle-core/src/reader.rs` now supplies
`Image::read_whole(&Arc<Image>, tenant, question, cancellation)` and
`read_whole_with_limits`, returning a bounded JSON `ReaderResult`. Coverage is
always `whole_templates_only`. Status distinguishes answered, unknown,
ambiguous and refused; answers require agreement across both template levels.
Unknown native operations do not disappear beside a successful reading: their
presence refuses the complete answer. Ambiguous native projections also veto
answering. Absence and source empty-intermediate guards remain failed readings.
Cancellation, deadline, fuel, SQL errors and all bounds propagate as errors.

The internal reusable hook is
`reader::evaluate_whole(db, identity, raw_question, previous, limits,
reader_limits, budget) -> Result<(ReaderResult, Option<Selection>)>`.
It uses the caller's leased worker and budget without opening another worker.
It returns a state selection only after answer agreement AND identical entity,
relation and attribute evidence across every successful reading. The public
Image API is pure and persists no selection or dialogue state.

The predicate lane added `query::evaluate_language` as a separate mode of the
common evaluator. It materializes every entity-producing stage once and refuses
any empty stage unless the terminal operation is Count. This includes dead and
union branches that ordinary final-output DAG evaluation could otherwise hide.
Direct graph/program execution retains its existing semantics. Each language
candidate gets clean private scratch before evaluation. There is no separate
reader interpreter and no prefix reexecution loop.

Forms are checked only after actual successful typed execution. Equivalent
checks are cached by answer kind for this question; one forbidden successful
kind vetoes the complete set. Evidence and successful candidate programs remain
available in the bounded result even on a form veto or answer disagreement.

`ReaderLimits` bounds lexical work, combinations per level, matched programs,
program steps and materialized bytes under the ordinary host Limits/Budget.
The same worker remains owned through native evaluation and error cleanup.

## Integration hooks

Expose `pub mod grammar` and `pub mod reader` from `oracle-core/src/lib.rs`
(root-owned). Reexport the optional reader image builder and its options for
external consumers.

The image builder deserializes `ReaderExport`, checks its KB provenance against
its admitted KB bytes, and calls
`install_tables(&db, &export, max_rows, max_bytes)` before publication. The
`reader_*` tables are created by that function, not by a tenant. Its savepoint
composes with a surrounding builder transaction. `lexicon::install_grammar_aliases`
can then import `reader_alias(phrase,kind,canonical)` into the release lexicon.
The lexicon lane coordinated support for N aliases, normalization metadata and
separate whole/compositional candidate modes.

The implemented whole-question consumer follows this sequence:

1. Reject `unreadable(raw_question)` **before** normalization. The normalized
   string no longer contains the evidence for this Reader7 veto.
2. Read the shared policy with `read_policy(&db)`. Obtain lexical candidates for
   each level with the export's normalization and `compositional=false`.
   Reader7 whole reading inherits Reader6's candidate rules; Reader7 fragment
   rules are different even though both use possessive normalization.
3. Flatten lexical alternatives to `GrammarSpan { start, end, kind,
   canonical }`, and pass `CandidateSet.normalized` directly to `match_whole`.
   Do not normalize that string again: possessive normalization is not
   idempotent. `GrammarSpan.kind` is `LexicalKind::code()`.
4. Convert each `MatchedProgram.program` through the closed typed Program
   compiler and execute it. Unsupported/failed/empty results are not successful
   readings. Preserve Count's source empty-set rule in execution.
5. Call `forms_allow` on **all successfully executed programs**, vetoing the
   entire set on failure. Only answer when every surviving answer agrees.
   Candidate support never selects a winner.

For future composition, `lookup` accepts whole/fragment/outer/segment plus level
and explicit `Fallback::{None,Content,Strip}`. It returns the matched key,
exact/fallback distinction, total support and every candidate's support and
rejection reason. `outer_shapes` returns all X-root shape counts. `expand`
handles @NOP/@X and rebases the inserted program's dependencies. `delex` binds
supplied nonoverlapping byte spans; it does not discover fragment boundaries.

## Checks and limitations

`rustfmt --edition 2021` completed successfully on the owned Rust source and
contract files. **No
builds, tests, training export or panel runs were executed in this lane**, as
root reserved execution for the centralized hbox run. No local training JSON
or trained cache was found in the pinned runtime source snapshot. The source
signatures and cache10 learning sequence were inspected directly.

`grammar_contract.rs` adds nine contracts: retained ambiguity/counts, exact
presence blocking fallback, hidden-word support/dominance distinctions,
kept-glue handling, dependency/unit expansion, ordinal/overlap handling,
whole-set form veto, bound/cancellation refusal and atomic malformed-import
rollback. `reader_contract.rs` adds ten contracts through the actual optional
image builder and public Image reader: alias spelling, unknown/raw-script
refusal, disagreement, form veto, unsupported alternatives, absent versus
ambiguous execution, source emptiness versus direct-program/Count semantics,
bounds/cancellation cleanup, typed projection and possessive normalization across
both levels. Their results are pending root's centralized run.

This implements whole-template language reading and shared table infrastructure,
not the complete Oracle language interpreter. Native fragment-region search, learned segment assembly,
nested composition, outer assembly, nearest-template analogy and clause101
peeling/patch attachment remain to be connected or implemented. Fragment,
outer, segment and shape data are exported for these consumers; clause patches
and execution caches are not exported. Normalized ASCII numbers follow the
source numeric guard; non-ASCII digit constants are conservatively treated as
hidden words by the native guard. Canonical spelling collisions retain all
native typed alternatives rather than Python's first global spelling choice.
Those changes and hard refusal at combination bounds need real-data comparison;
no claim of full reader equivalence is made.

## Bounded real-question qualification harness

`native/tests/qualify_reader.py` now selects default 40, at most 100, real
validation questions by a fixed hash. It requires a validation digest and a
KB-bound reader image receipt. An optional prior explicit case file, including
`qualify_programs.py`'s 233-case sample, can restrict the pool; every case is
checked back against its validation question, exact gold answer and program.
Gold programs are provenance only and never supplied to the language reader.

The harness launches a fresh process using the installed `oracle_native`, opens
one Image and Runtime, and measures import/image/ready/first-read timings,
p50/p95 including errors, PSS/RSS at ready and after use, and peak RSS. It creates
exactly 256 scoped tenant handles on that shared Runtime and runs only three
additional scoped reads. Handle-creation memory growth is measured separately
from query working-set growth and checked against an explicit configurable
8 MiB default bound. Worker release and scoped-result stability are checked.

The report separates answered correct, answered wrong, refused, unknown and
operational errors, with raw native status/reason counts (native ambiguity is
included in refused totals and separately visible). Gold comparison uses exact
strings. Mismatch records and process logs are bounded. Timeout or process
failure leaves an incomplete receipt; wrong answers, operational errors or a
failed tenant-memory check produce nonzero exit. No upstream whole Reader or
Engine is constructed; absence of that reference comparison is explicit. No
filesystem caches are evicted, so fresh-process cold timings are not a cold-disk
claim. Root owns running this harness and retaining its results; this lane did
not execute it.

## Indexed whole-template search correction

The first real-question run exposed an algorithmic defect: the 400-combination
bound counted nonmatching subsets of lexical spans. Ordinary questions could
therefore exhaust the bound before reaching their learned wording. Raising that
bound would preserve the powerset cost.

`grammar::match_whole` now walks positions in the question. Each transition emits
either its next literal word or a typed ordinal slot for a lexical span beginning
there. A bounded indexed prefix probe on the existing
`reader_template(family,level,template,skeleton)` primary key prunes a transition
unless some learned whole template continues with that exact token prefix. The
binary range is `[prefix + " ", prefix + "!")`; it respects word boundaries and
cannot mistake E10 for an E1 continuation. Terminal paths use the existing exact
lookup, support rules, slot expansion and ambiguity collection.

A per-request prefix cache holds at most a quarter of the materialized-byte
bound. Cache saturation merely resumes indexed probes under fuel; it does not
remove readings. Search retains one mutable path and restores its ordinals and
canonical bindings on backtracking. The combination bound counts only complete
bindings whose exact template key exists. More than 400 genuine matching
bindings still fail the entire request. No image rebuild, table-format change,
raised cap or new language coverage is needed for this correction.

Three additional grammar contracts compare the indexed search with an
independent small powerset traversal, cover 24 irrelevant disjoint spans
(2^24 possible subsets) with one learned binding at a combination bound of one,
and require refusal for 401 genuine canonical bindings. Existing grammar and
reader budget tests now use multiple genuinely learned bindings rather than
unreachable subsets. Root owns the centralized execution and repeat of the same
40-question sample; this lane ran no tests or builds.
