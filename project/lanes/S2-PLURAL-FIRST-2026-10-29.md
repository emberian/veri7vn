# S2-PLURAL-FIRST: run the plural-first regression tests

Owner: lane S2-PLURAL-FIRST. Consumer: root.
No specialist panels run; no panel numbers. No theorem statements.

## What ran

Copies of the pinned upstream `workbench/swarm/` (67 files) were placed in
`var/s2-plural-first/control` and `var/s2-plural-first/candidate`. The patch
`tools/reader_audit/canonical_plural_first.patch` was applied to the candidate
copy only (`patch -p3 reader_v7.py`), cleanly, without fuzz. Nothing under
`upstream/` or the pinned snapshot was written.

Command, with Python 3.12.14 from the repo venv (`-I -B` worked as is):
`python -I -B tools/reader_audit/test_canonical_plural_first.py --source-dir <dir>`

Hashes of `reader_v7.py`: control `f37f687e8190f08ff862738543790d6bcd56185a1a807ffdbd5cf8340da85354`
(the pinned hash), candidate `03e43e4e742b1bc6093fb67d00425ab47b679278fe1519b799b8cab91b90e57f`.
The test file hash matches the frozen `269a27c827c9d0ab586a15ec681215cf946f37284d4f84f890da76d5cd49f1b1`.

## Results (8 tests each)

| test | control | candidate |
|---|---|---|
| count_cue_not_consumed_by_album_alias | FAIL: span is "number of albums", expected "albums" | ok |
| exact_two_training_examples_no_longer_replicate_wrong_outer | FAIL: Count support for `which X1` is 2, expected 1 | ok |
| direct_canonical_phrase_with_number_of_is_unchanged | ok | ok |
| existing_plural_branches | ok | ok |
| how_many_retains_count | ok | ok |
| nonconcept_literal_still_uses_alias | ok | ok |
| plural_disabled_preserves_alias_behavior | ok | ok |
| unrelated_alias_remains_usable | ok | ok |

Control: 2 failed, 6 ok. Candidate: 8 ok. This is the predicted split, so the
two tests do detect the defect; the other six pass on both and show the patch
leaves those behaviors unchanged. No test or patch was edited.
`outer_provenance.py --help` parses and exits 0; it was not run for real.

Receipt: [plural-first regressions](../../native/evidence/2026-10-29-plural-first-regressions.json).

## Changed files

* `native/evidence/2026-10-29-plural-first-regressions.json` (new)
* `project/lanes/NFORM-EVIDENCE-2026-10-29.md` (two "not run" statements replaced)
* this note
* Logs, outside git: `var/s2-plural-first/{control,candidate}{,.verbose}.log`

## What this does not establish

Small fixtures only. No retraining, no image rebuild, no native cohort run.
Reader6 (`learn6`) has its own alignment code that this patch does not touch.

## What remains

1. Retrain and export on hbox with the patched source, then compare exact row deltas.
2. Rebuild the image.
3. Run the 16-case frozen cohort; keep code-only and data-only variants separate.
4. Inspect Reader6 alignment.
5. Post the upstream PR (not yet posted).
