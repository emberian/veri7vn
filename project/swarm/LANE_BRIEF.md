# Swarm lane brief (wave 4)

You are one lane of a swarm lifting Oracle7 specialists into verified kernels.
Your launch message names your lane id, your slug, your Isabelle session name,
your specialists in priority order, and any batch-specific notes. Everything
else is here. Repo: `/Users/ember/dev/o7vn`, branch `dev`.

## Read first
`AGENTS.md`, `project/PLAN.md`, `docs/contracts/answerer.md`,
`docs/parity/README.md`, `project/swarm/README.md`, then lane G's finished
work, which is THE pattern you copy file for file:
`src/extract/quantity/README.md`, `project/lanes/G-quantity.md`, and every file
under `src/extract/quantity/` (ROOT, base/Quantity_Base.thy, Quantity.thy,
Quantity_Export.thy, tables_check.py, regex.sml, recognizer.sml, main.sml,
build.sh, score.py). `src/extract/acoustics/` (lane D) shows verified interval
arithmetic for sqrt/ln if a formula needs it. `src/isabelle/reader/` (lane F)
shows the pattern for a verified decision over rows fetched by an untrusted
shim, if a specialist reads a store.

## Goal
Lift your specialists as ONE verified family kernel in `src/extract/<slug>/`,
exported to SML, compiled with the MLton inside Isabelle into one binary
`var/<slug>/bin/<slug>` that speaks the answerer contract, and score each
specialist on its own shipped panel with lane A's harness. Commit after each
specialist lands with its number, so a partial result is still a result.

## Ground truth
Each specialist lives at `/Users/ember/dev/o7vn/upstream/root/specialists/<id>/`:
`manifest.json` (accept.kinds, declines_in_domain, context_regex, budgets;
paths use the placeholder `__ORACLE7_ROOT__` = `/Users/ember/dev/o7vn/upstream/root`),
`organ_*.py` (`class X: def answer(self, text, session_id) ->
{"kind","status","response","value"} | None`), a panel JSON (a flat list of
items with split/kind/valid/q/expect, or a dict with dev/heldout), a
`*_scorer.py` (`ok(item, reply) -> (good, asserted)`; read it for its tolerance
and number extraction, your reply text must satisfy it), `verdict_heldout.json`
(the shipped number to match; gate v2 format, `domain` block), and the shared
`narrow_v1.py` (word-problem narrowing that gates every organ; port its rule
once). Versions of one stem (-v2, -r2) share code: lift the newest fully, then
the older ones usually differ only by narrowing or wording; score each on its
own panel.

## Design (same as lane G)
- Verified kernel: one HOL datatype of typed requests across the family, a
  typed outcome (`Value kind rat` or `Decline reason`), theorems per kind: the
  stated value satisfies its defining equation; declines are exactly the
  organ's underspecified/impossible/mismatch predicates; determinism. Tables
  (constants, materials, factors, lookup rows) are HOL constants transcribed
  from the organ with `tables_check.py` asserting equality against the organ's
  Python table so they cannot drift. No tautologies; read your statements
  before reporting them.
- Recognizer: hand-port of each organ's regexes into SML, documented UNTRUSTED;
  one recognizer dispatching by manifest context; reply text rendered in HOL
  where lane G did (plain ASCII).
- sqrt/ln only via `HOL-Decision_Procs.Approximation` as lane D did, with lane
  D's rounding lemma pattern; no other transcendental. Cap any single lemma at
  TWO build attempts, then weaken or defer it with a named `remaining` entry;
  lane D lost hours on one lemma.
- Session `Veri7vn_<Session>` under `src/extract/<slug>/ROOT`; build ONLY
  through `python3 tools/dev/check-native --session Veri7vn_<Session>
  --session-root src/extract/<slug> --expect 'VERI7VN_<SESSION> PASS'
  --timeout 600` from the repo root, copying lane G's cached base-session trick
  and the oracle-refusing PASS marker from `Quantity_Export.thy`. The build
  lock is shared by about twenty lanes: write the WHOLE family's kernel and
  recognizer before your first build, expect to wait on the lock (the tool
  waits; do not bypass it or poll it in a tight loop), and keep builds few.
- Score: `python3 tools/parity/harness.py --answerer "var/<slug>/bin/<slug>"
  --specialist <id1>,<id2>,... --split both --out var/<slug>/parity` (the
  binary must reply withheld for anything it does not recognize). Report per
  specialist and split: right / wrong / withheld-on-valid / false yes, every
  named miss with the question text, binary size, cold start, p50 vs the
  manifest's budget, versus the shipped verdict.

## Deliverables (you own exactly these paths)
- `src/extract/<slug>/{ROOT, base/*.thy, <Family>.thy (split if large),
  <Family>_Export.thy, tables_check.py, regex.sml, recognizer.sml, main.sml,
  build.sh, score.py, README.md}`; binary under `var/<slug>/bin/` (not in git).
- `project/lanes/<lane-id>.md`: theorem STATEMENTS verbatim, the
  per-specialist table, receipt path and status, untrusted parts, remaining
  work, exact reproduction commands.

## Box safety (rules of this machine)
- Never kill by pattern. No `pkill -f <anything>`, no `pkill -x <bare word>`,
  no `killall`, no `kill -u`. A process you started is stopped by the PID in
  its PID file, and only that. Every detached job writes one
  (`nohup ... & echo $! > job.pid`). No PID file, no kill: tell root instead.
  If you must look first, `pgrep -fl` and read the list; it is never the
  argument to a kill.
- Never `git stash`, `git reset`, or `git add -A`; twenty lanes share this
  working tree. Commit only your own named files:
  `git add <paths> && git -c commit.gpgsign=false commit -m "[lane <id>] ..."`.
  Do not push; root pushes.
- Never write under `upstream/`. Never run the Oracle7 head
  (`upstream/oracle7.py`); you do not need it. Scratch goes under
  `/Users/ember/dev/o7vn/var/<slug>/`.
- Disk pressure is a stop condition: if `df` shows the disk low, stop writing,
  report, wait. Delete only files you created.
- No `sorry`, `oops`, `skip_proof`, axioms. No unfiltered test suites. One
  scoped Isabelle session, built through check-native only.
- Do not edit other lanes' files (`src/extract/quantity`, `acoustics`,
  `fusion`, `src/isabelle/*`, `tools/parity`). Copy what you need with a
  comment naming the source, or ask root in your handoff for a shared export.
- If you pass ~420k tokens of context, write `var/<slug>/CONTINUE.md` with
  exact state (what is proved, what is open, the current build error, which
  specialists are scored) and stop; root resumes from it.

## Report
Final message and `project/lanes/<lane-id>.md`: numbers per specialist, or the
exact reason there is none yet.

- Set `PYTHONDONTWRITEBYTECODE=1` (or `python3 -B`) for any Python that imports an organ from `upstream/`; a stray `__pycache__` under upstream is a write.
