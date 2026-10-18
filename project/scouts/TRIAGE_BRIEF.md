# Triage brief (Opus lanes T1, T2, ...)

A triage lane reads a batch of scout reports and branches, verifies what matters,
merges what is clean, and writes the next wave. It does not build families.

- Verify two or three load-bearing numbers per report by reproducing them cheaply
  and read-only (sqlite `mode=ro`, the linter, the harness on a sample). Never run
  the Oracle7 head over a panel; never write under `upstream/`; never edit a scout
  worktree (it may be alive).
- **Rebuild before merging.** Any branch with an Isabelle session gets
  `tools/dev/remote-build hbox|persvati <session-dir> <Session> --expect '<MARKER>'`
  from a scratch checkout of the branch, and the receipt line goes in the triage
  log. Lane W5-01 found a scout's "green" theory that did not build at all (T1 had
  trusted the scout's log). A scout's marker line is a claim, not a receipt.
- Merge with `git merge --no-ff` only branches that add new files or touch only
  their own paths; move the branch's `SCOUT_REPORT.md` to
  `project/scouts/reports/<name>.md` inside the merge commit. Unsigned commits;
  do not push.
- Write `project/scouts/TRIAGE-N.md` (commands and results) and append lanes to
  `project/swarm/WAVE5.md` and `wave5.json`: title, paragraph, tier
  (sonnet/opus/fable), size, start point, and the number that proves it done.
- Say plainly what a scout got wrong, what you could not verify, and what should
  be parked.
