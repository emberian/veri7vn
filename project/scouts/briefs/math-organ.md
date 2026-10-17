Prototype a verified kernel for the part of Oracle7's head mathematics route that the core panel
exercises (`organ:math` 24 items, `op:` 17, `algebra:solved` 6, and 114 `precision_guard` declines
on `upstream/workbench/data/core_panel.json`). The organ is `upstream/root/wander-train/math_organ_v3.py`
(SymPy underneath) with `math_solver_v3.py`; the guards are folds in the w-chain (grep
`precision_guard` under `upstream/root/fable-content/.../self_loop/admitted/`).

A previous scout attempt in THIS worktree left an uncommitted 1,062-line draft
`src/extract/mathorgan/Math.thy` and ran out of context before building or reporting. Start by
reading that draft in parts, commit it as-is, write a first SCOUT_REPORT.md stating what it covers
and what it does not (commit it), then: build it remotely
(`tools/dev/remote-build persvati src/extract/mathorgan <Session> --expect '<MARKER>'`), fix or
`sorry`-mark proofs (say so per lemma), export, compile with MLton, write a recognizer for the
evaluate/simplify/solve-linear/gcd/lcm/integer-sqrt forms, and measure on the core-panel math items
by running lane A's head answerer `tools/parity/answerers/oracle7.py` ONCE in one process (set
`ORACLE7_STATE` under var/scout/; it redirects Oracle7's stray writes) to get Oracle7's answer
text, then compare. Report what SymPy does that an exact kernel cannot, and what the guards check.
Keep your context small: grep before reading, read files in parts, never print large outputs.
Commit often.
