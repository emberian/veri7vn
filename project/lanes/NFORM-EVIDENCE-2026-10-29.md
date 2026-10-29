# Where the conflicting Count reading came from

Owner: reader_form_evidence. Consumer: root's reader source admission repair.
No specialist panels run; no panel numbers. No theorem statements, native calls,
builds, program execution, or tests. The scoped read-only provenance replay below
returned exit 0. The patch is a proposal and has not been applied or checked.

## Verified source facts

The immutable training JSON on hbox is SHA-256
`e9fbe4c1cdf207aac83ae0d5e4a1a53a9965a2b13b403de699ca6d5dae6e4510`.
Pinned `reader_v7.py` is
`f37f687e8190f08ff862738543790d6bcd56185a1a807ffdbd5cf8340da85354`.
Read-only reconstruction used the image's exported aliases and pinned `learn7`
on only training rows whose final function is Count and first word is which.
It reproduced all exact `which X1` Count contributions, including support 2 at
level 0 and support 1 for the same skeleton at level 1.

The two level-0 supporting records are zero-based training indices:

* 9630: “Which calendar month follows March?” Program: Find March, Relate
  followed by forward, FilterConcept calendar month, Count. Stored answer: 1.
  The question asks for a month; the program and numeric answer instead count
  months. This is a question/program mismatch on its merits, regardless of its
  matching SPARQL count and numeric multiple-choice alternatives.
* 32261: “Which number of albums dates not published in 1998?” Program: FindAll,
  FilterYear publication date 1998 !=, FilterConcept album, Count. Answer: 23.
  Despite awkward grammar, this question actually asks for a count.

These both emit `[NOP, NOP, X(1), Count(dependency=2)]` under `which X1` at
level 0. At level 1 the March row does not align; the album row still does.
Another Count contribution, index 43846 (“Which literary award's country is the
sovereign state whose population is equal to 50155783 ?”), has a longer distinct
skeleton with support 1 at each level. It cannot explain the admitted support-2
row and also has an apparent requested-form mismatch.

The exact mechanism is **operator words swallowed by a learned concept alias**.
The image contains `('number of albums', 'C') -> 'album'`, and no other alias
whose target is album. The canonical album spelling does not occur as a word in
albums. `align` therefore selects the longer alias before it reaches its
existing plural-spelling branch. Its concept span is `[6,22)`, covering
“number of albums”. Its year span is `[46,50)`. The chain's replacement interval
starts at 6, so replacing the chain leaves only “which X1”.

This is not merely a mislabeled March example: a legitimate count example loses
its count cue during alignment. `number` is absent from the image's operator
and keep sets; `many` occurs in both. Existing alias operator guards therefore
do not protect this phrase. The source's form model classifies answer kinds by
training terminal functions, accepts a kind only above 5% in both deterministic
halves (with at least 50 combined records), then uses it as an all-reading veto.
Template support and form acceptance are separate learned statistics. Nothing
in construction guarantees their consistency. The exporter preserves both.

## Small source correction proposed

`tools/reader_audit/canonical_plural_first.patch` reorders the two existing
branches in Reader7.align: try canonical concept plurals before learned aliases.
It changes no answer arbitration, support thresholds, or form rules. For the
album example the existing plural rule should locate “albums” at `[16,22)`,
leaving “which number of X1” as the outer wording. The March mismatch then has
only one contribution to the offending skeleton and fails the existing outer
replication requirement. This causal prediction needs central verification.

This general precedence rule prefers explicit canonical morphology over a
learned phrase that can consume extra meaning. It does not blacklist Count,
which, the two records, or a particular answer. It also does not claim to repair
all damaged aliases or training labels. Raw learned aliases remain in the image;
other consumers may still select them. In particular Reader6.learn6 has its own
alignment code without this same plural branch. Root should inspect that
consumer before claiming a complete language-learning correction.

## Scoped central check requested

First replay provenance against an in-memory or isolated patched source and
check: the album outer is `which number of X1` at both levels; Count support for
`which X1` drops from 2 to 1 at level 0; the March row remains visibly mismatched
and is rejected by existing replication admission. Then re-export using the
pinned training input and compare exact row deltas before building a candidate.

Preserve independent cases: “Which calendar month follows March?” asks for an
entity; “Which number of albums ...” asks for count; “How many albums ...” must
retain Count. Canonical phrases that themselves contain “number of” should
still match directly, and unrelated aliases must remain usable. Repeated
genuine ambiguities must still decline; this proposal never changes agreement.
Run the original frozen 16-case cohort after the source repair and the separate
storage fix. Keep every failure and decline visible; do not revise expected
source facts to obtain a passing result.

## Reproduction and authored files

`tools/reader_audit/outer_provenance.py` is explicitly untrusted. It imports
pinned source, learns only candidate rows, and reads SQLite in immutable,
query-only mode. It never constructs KQA or runs a program. Usage on hbox:

```
python3 -B outer_provenance.py \
  --source-dir /tank/lanes/o7-native-20261028/source/swarm \
  --train /tank/lanes/o7-native-20261028/data/train.json \
  --image /tank/lanes/o7-native-20261028/data/reader-image-v3.sqlite
```

The first revision was run through ssh standard input and returned the exact
contributions described above. Added alignment spans and exported forms are
inspection fields in the final authored version and have not been rerun.
No large corpus/image copy or upstream write occurred. Changed files are this
report, the audit script, and the source patch proposal. Root must own and apply
any production source/export change; this lane changed none.

## Portable source regressions authored

`tools/reader_audit/test_canonical_plural_first.py` accepts `--source-dir` or
`READER_SOURCE_DIR`. It imports that source tree, never constructs KQA/Engine,
and uses only small question/program fixtures without corpus or KB access.
It covers the exact two contributing questions, Count remaining under
`which number of X1`, how-many Count, all existing s/es/y plural branches,
singular city, unrelated alias fallback, a direct canonical phrase containing
“number of”, PLURAL=False, and nonconcept entity alias alignment. Assertions
expect the candidate's corrected behavior; the unchanged control should fail
the count-cue and exact-two-example regressions. Authored only, not run here.
The frozen file SHA-256 is
`269a27c827c9d0ab586a15ec681215cf946f37284d4f84f890da76d5cd49f1b1`.


## Result recovered at handoff

Central provenance replays completed in an isolated patched source copy before
its agent stopped. Root retrieved and parsed all four reports from hbox
`/tank/lanes/o7-native-20261028/form-priority-20261029/` into
`var/reader-form-20261029/provenance/`. Row 32261 moves from `which X1` to
`which number of X1` at both levels. Row 9630 remains under `which X1` at level 0.
The separate row 43846 retains its distinct skeleton; do not sum all Count rows
as if they were one skeleton. The [receipt](../../native/evidence/2026-10-29-reader-form-provenance.json)
retains hashes and source identities. The eight authored regression tests have
no execution receipt yet. Full training export, image rebuilding and native
cohort comparisons have not run. No upstream PR has been opened for this patch.
