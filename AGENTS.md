# Working on veri7vn

Read `project/HANDOFF-2026-10-18.md` and `project/PLAN.md` first. It names the lanes, the frozen areas and the
scoreboard. The original Oracle7 lives under `upstream/` (ignored by git, 43 GB)
and runs: `cd upstream && ../.venv/bin/python oracle7.py "Who wrote Leaves of Grass?"`.

## Scoreboard before anything

The shipped specialist panels under `upstream/root/specialists/*/` scored by
their own scorers under `upstream/workbench/exam.py`'s six criteria are the only
completion metric. A lane's report states its panel numbers, or states that it
has none yet. Compilation, a green theory and a passing fixture are not numbers.

## Lanes

Root dispatches, integrates and commits. A lane owns the paths its brief names
and edits nothing else; it asks root for a transfer when it needs another path.
Frozen areas (listed in the plan) are read-only for everyone. No lane spawns
agents without root's say-so.

A handoff names: changed files, the theorem statements (not just names), what
check ran and its exact result, what remains, and what the consumer is.

## Evidence

No `sorry`, `oops`, `skip_proof` or new axioms. Read theorem statements; a
vacuous or tautological statement is not progress. A Python shim is untrusted
by construction and says so in its docstring. Source rows are data: absence,
uniqueness and aggregates need explicit coverage premises.

Run the narrowest check that could refute the change.

## Resources

- `python3 tools/dev/check-native --session <S> --session-root <dir> --expect '<marker>'`
  holds the single build lock; use it for every Isabelle build. One Isabelle:
  `/Applications/Isabelle2026-RC1.app`. MLton is at
  `/Applications/Isabelle2026-RC1.app/contrib/mlton-20241230-1/*/bin/mlton`.
- Never write into `upstream/`. Scratch state goes under `var/<lane>/`.
- Never kill by pattern (`pkill -f`, `killall`, `kill -u`). A process you
  started is stopped by the PID you recorded for it, and only that.
- Never `git stash`, `git reset` or `git add -A`; the tree is shared. Stage
  named files. Unsigned commits are fine.
- Disk pressure: stop writing, report, wait. Delete only what you created.
- No unfiltered test suites. Filter to what exercises the change.
- Keep corpora, heaps, credentials and transient artifacts out of commits.

## Writing

Plain words, for a reader who is not a software engineer. Say what the thing
does, what it proves, and what it cannot do yet.
