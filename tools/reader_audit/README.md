# Isolated plural repair and frozen comparison

No new panel numbers. These tools are untrusted build/evaluation helpers. They
never construct the upstream Engine or execute dataset programs. Nothing under
`upstream/` is written. The repair is the maintained
`canonical_plural_first.patch`, already checked against eight independent small
source fixtures. No training labels, replication thresholds, answer forms or
agreement/dead-branch rules are changed.

The confirmed defect is row 32261: the alias **number of albums → album** eats
the count cue and teaches Count under `which X1`. Canonical plural precedence
aligns only *albums*, preserving `which number of X1`. Row 9630, “Which calendar
month follows March?”, asks for an entity but ends in Count in the dataset. It
stays visible as mislabeled training data; we do not claim its stored answer 1
is the right answer to that English question. The two rows no longer replicate
the same poisoned outer skeleton. Row 43846 is a separate singleton skeleton;
its support must not be added to theirs. Reader6 whole-template learning still
has its own alias-first alignment without a plural branch; this recipe changes
only the reviewed Reader7 rule. Broad alias-policy repair needs separate evidence.

## Executor recipe

Run after the measurement lane's baseline window, one full learner at a time.
The retained hbox inputs are `/tank/lanes/o7-native-20261028/source/swarm` and
`/tank/lanes/o7-native-20261028/data/{train.json,kb.json}`. The baseline image is
`/tank/lanes/o7-native-20261028/data/reader-image-v3.sqlite`. Train/source/KB hashes
are enforced by `prepare_plural_export.py`. This is CPU learning from JSON;
no model calls, no Isabelle and no Rust compilation are involved. Allow space
for a copied small source tree, explicit export and a new roughly 260 MB image;
do not copy the corpus or clean anyone else's scratch artifacts.

```
python3 -B tools/reader_audit/prepare_plural_export.py \
  --source-dir /tank/lanes/o7-native-20261028/source/swarm \
  --train /tank/lanes/o7-native-20261028/data/train.json \
  --kb /tank/lanes/o7-native-20261028/data/kb.json \
  --work /tank/lanes/o7-native-20261028/plural-retrain-20261031
python3 -B tools/reader_audit/export_delta.py CONTROL_READER_JSON \
  /tank/lanes/o7-native-20261028/plural-retrain-20261031/reader-plural.json DELTA_JSON
```

Retain the old explicit reader export from the image's original build receipt;
if absent, export the control source with identical pinned inputs/environment.
`export_delta.py` emits every added/removed row and both metadata records; it
fails if policy/forms changed. Inspect exact `which X1` Count support and the
preserved count wording in that delta before native qualification. Do not
subtract support or delete rows manually.

Build a new image with the **same existing extension**, pinned KB and
`oracle_native.build_reader_image(kb, NEW_IMAGE, 536870912, 16777216,
Path(NEW_READER_JSON).read_text())`; retain its JSON build receipt. The
`oracle-image` CLI alone does not import reader tables. Verify source hash in
that receipt equals the old image's source hash. Record image digest after
construction. No U8 materialization source changes belong to this experiment.

## Four cells

`compare_frozen.py --manifest MANIFEST_JSON --work NEW_DIRECTORY` runs baseline,
code-only, data-only and combined serially, each in a fresh child. The manifest
has this shape (replace every placeholder before freezing):

```json
{
  "retained100": {"path": "ABSOLUTE_ORIGINAL_CASES_JSON", "sha256": "SHA256"},
  "targeted16": {"path": "ABSOLUTE_FROZEN_TARGETED_JSON", "sha256": "SHA256"},
  "extensions": {
    "control": {"path": "ABSOLUTE_CONTROL_SO", "sha256": "SHA256", "coverage": "DECLARED_COVERAGE"},
    "candidate": {"path": "ABSOLUTE_CANDIDATE_SO", "sha256": "SHA256", "coverage": "DECLARED_COVERAGE"}
  },
  "images": {
    "control": {"path": "ABSOLUTE_OLD_IMAGE", "sha256": "SHA256"},
    "candidate": {"path": "ABSOLUTE_NEW_IMAGE", "sha256": "SHA256"}
  },
  "limits": {"workers": 2, "timeout_ms": 1000, "fuel": 10000000},
  "process_timeout_seconds": 600
}
```

Original retained100: `var/o1-arena/reader100-control-run2/cases.json`; original
16: `native/tests/composition_cases_targeted_20261029.json`. Do not resample or
relax the limits. Warm baseline extensions are under `var/o1-arena/{control,candidate}`;
use exact retained provenance and hashes, not a similarly named current build.
Root supplies the wave's actual pre/post extensions once integrated.

Every original question, full reply, successful program, entity set, fact,
attribute and refusal is retained. Independent SQL checks the 16's referents
against the ORIGINAL image; candidate wording never supplies truth. An answered
case passes only when its text and every reading's entity set agree with the
source expectation. Retained100 still compares dataset text and is explicitly
labeled a dataset control, not independent truth. Any gain there requires
question-by-question source review before making an answer-coverage claim.
Compare code-only to baseline and combined to data-only for changed denotation,
evidence and refusal obligations; compare data-only to baseline to attribute
plural repair gains. Full reply evidence supports review when equal text hides
different entities or qualifiers.

Independent adversarial controls already retained: targeted16 has empty and
ambiguous selections, contradictory attributes, reordered intersections and
entity/count pairs; the eight source tests independently cover the exact album
cue, March entity wording, how-many Count, canonical “number of” concepts,
plural morphology, aliases, disabled plurals and entity alias fallback. The
source tests validate alignment, not answers to March or full semantic safety.
Additional duplicate-name/duplicate-path/qualifier/dead-child counterexamples
belong to the sharing lane's finite-image checks; these tools do not claim those
have passed. All original declines remain in the denominator.

## Source 3625: a newly demanded invalid date interpretation

Read-only investigation after the first four-cell run; no new learning, native
calls or builds. All 100 cases stay in the cohort. The question is “How many
national cuisines are in the sovereign state country whose inflation rate is
49.3 percentage?” The original data-only and combined exceptions are retained
under hbox `/tank/lanes/o7-sol-validation-20261031/reader-four-cells/`;
`reader-four-cell-manifest.json` pins their artifacts. Control image SHA-256 is
`8fcb1db9a08e234179f66ea9e032d2633b38cdcb902f4c95d1ba2c2d49c842f4`;
`reader-plural.sqlite` is
`0522cdc44f8c485385c6737623916750e3fe6eedc39c9072190d084b5cac86a8`.
The full explicit exports and `plural-delta.json` are retained beside them.
Training indices below are zero based in the pinned train JSON (`e9fbe4…`, full
hash enforced by the preparation driver).

The exact outer key `how many X1 percentage` newly replicates two Count
skeletons at level 0: length 6, Count depending on step 4, goes from support 1
to 2; length 4, Count depending on step 2, also goes from 1 to 2. At level 1,
the length-4 skeleton goes from 1 to 2 and its A-root shape does likewise.
The relevant source rows are:

- 9466: research universities, unemployment 7.7 percentage; already aligned in
  full under this outer. 37802: association football clubs, inflation −10
  percentage; the old alias matches only *football clubs*, leaving
  *association*, whereas the canonical plural matches the whole concept.
  These supply the length-6 outer.
- 19528: states, inflation greater than 210 percentage; already under the outer.
  68241: constitutional monarchies, inflation 330 percentage; the old alias
  matches only *monarchies*, leaving *constitutional*. The canonical plural
  moves it into the length-4 outer, including level 1.

This outer demands X **without** the final word *percentage*. The unchanged
level-1 fragment key `C1 whose A1 is N1` includes
`FindAll; FilterDate(A1,N1,=); FilterConcept(C1)` with support 31 in BOTH images.
It also includes numeric and string variants. Source Reader4 labels any
number-leading literal N, including dates; that lexical class does not preserve
its scalar type. Consequently an inflation-rate/49.3 binding can instantiate
FilterDate with 49.3, which the typed program validator rejects: it is neither
a calendar year nor a Gregorian date. FilterDate itself is implemented; this is
an invalid learned literal instantiation, not evidence of an unsupported valid
operation or a scalar-producing child. The generic date row was not introduced
by the plural repair. The newly admitted outer exposes it.

Attribution limit: the failed native call archived only the generic
“unsupported composition fragment” exception, not the first failing callback's
program. Exact source/template/slot inspection establishes this concrete invalid
admitted candidate and its new demand route; it does not prove which candidate
raised first. Do not turn that missing trace into a claim of full runtime
provenance. The sharing lane's narrow correction retains an UnsupportedProgram
refusal obligation rather than propagating an exception or accepting a winner.

Independent SQL over the finite candidate image finds one exact quantity row:
Iceland Q189 has inflation rate 49.3, unit percentage, qualified at 1981-01-01.
Forward country edges into Q189 have subjects Q189 and Q3740828 (both named
Iceland). Their intersection with recursive national-cuisine membership rooted
at Q1968435 is empty. The inspected SQL uses `attributes` with exact key,
`json_extract(value,'$.value')=49.3` and unit `percentage`, followed by forward
`edges(predicate='country',object='Q189')` and `parents` concept closure. This
supports the dataset's 0 on this finite store; it is not world completeness.
Current child-nonempty admission still prevents delivering that zero.

Backlog owned by root: carry typed scalar domains and unit context through
learned slots and X boundaries, preserving legitimate type overlaps rather than
blacklisting a date row or silently dropping an invalid admitted interpretation.
Separately define checked closed-empty Count semantics with explicit finite
coverage and retained required-child obligations. That is a language/coverage
change requiring independent zero/duplicate-path/missing-classification cases;
do not weaken the current nonempty rule to force this gold answer. No further
first-wave implementation is proposed here.
