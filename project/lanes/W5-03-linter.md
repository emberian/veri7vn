# W5-03: the specialist linter, corrected and merged

The linter reads one specialist folder (or all 305) and says what is wrong with
its manifest, panel and verdict file, runs the verdict counts through lane C's
verified gate binary, and lists which head folds would see its questions first.
It writes nothing under `upstream/` and runs no organ.

## What changed from the scout's version
- Branch `w5-03` took the scout's two commits (new files only):
  `tools/lint/specialist-lint.py`, `docs/lint/specialists.md`; the scout report
  moved to `project/scouts/reports/specialist-linter.md`.
- The lane-cap finding was backwards and is fixed in the linter's aggregate text,
  in its per-folder text, and in the report. The sentence now reads:

  > Every shipped verdict measured the lane cap on a SAMPLE of about 400 of the 924
  > core questions. On that sample the formula's cap is 5; on the full panel
  > exam.py uses, 9. The three gate disagreements (rel-novels, rel-graphicartists,
  > rel-translators) are all specialists that took 6 general questions. The release
  > ADMITTED them, so it was looser than exam.py's cap of 9, not stricter; only the
  > gate run on the sample's cap of 5 rejects them.

- Fold guard base rates (how often the guard matches the 100-question
  calibration set) now appear next to every match: in cue matches, in the
  held-out-question matches, in the "universal guards" line, and in the aggregate's
  per-folder line. A 66% guard (`w55 _TOKEN`) is visibly nearly universal.

## Result (regenerated `docs/lint/specialists.md`, 305 folders)
Verified gate over 292 verdict files: 239 agree, 3 disagree (the three
above), 50 missing a count the gate needs, plus 13 folders with no verdict file.

## What it cannot do
Fold matching is regex matching on guards; a match is not the fold firing. W5-05
measures that against real head runs. The "not universal" cut is 90%.

## Reproduce
    PYTHONDONTWRITEBYTECODE=1 PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream \
      python3 tools/lint/specialist-lint.py --all --aggregate docs/lint/specialists.md
    PYTHONDONTWRITEBYTECODE=1 PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream \
      python3 tools/lint/specialist-lint.py rel-novels
