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
