# Wave 6 lane brief (theorem fixes)

You are one wave-6 fix lane. Your launch message names your lane id (W6-NN) and
family. Read `AGENTS.md`, `project/swarm/LANE_BRIEF.md` (rules), your row and
section in `project/swarm/WAVE6.md`, and your family's section in
`docs/assurance/theorem-audit.md` (the proposed missing binding theorems, with
Isabelle statements over the family's real constants, and the vacuous or
unscanned statements to retire or scan). The family lives under `src/extract/`
or `src/isabelle/` as the row says, with its lane handoff in `project/lanes/`.

Do: add the binding theorems the audit proposes (or stronger ones), each tied
to something independent of the code (a defining equation in another form, an
error bound against the real model, an exact decline condition stated apart
from the decline function, a cross-kind law); retire vacuous statements; bring
every headline theorem under the export theory's oracle scan with the PASS
marker as the LAST command; replace `by eval` proofs (they record an oracle)
with `simp`/`code_simp` or a `tables_check.py` check. Rebuild remotely on
persvati (`tools/dev/remote-build persvati <session-dir> <Session> -d
src/extract/commons --expect '<MARKER>'`; hbox's heaps are being repaired),
rebuild the binary, re-score every specialist of the family through
`tools/parity/harness.py` with `PYTHONDONTWRITEBYTECODE=1`. Recount with
`tools/audit/` (extract.py, markers.py; see the audit for the exact commands).

Done when: the family's audit count shows the new binding theorems, vacuous 0,
unscanned 0, marker last with `oracles=0`, and every panel reply is unchanged
(or each change is a named defect fix the audit asked for). Commit named files
unsigned (`git -c commit.gpgsign=false commit -m "[lane W6-NN] ..."`); do not
push; write `project/lanes/W6-NN-<family>.md` with the new statements verbatim
and the before/after counts. Two-build cap per lemma. Never edit another
family, commons, or tools. Box safety per LANE_BRIEF.md. If you pass ~400k
tokens, commit what is green, write `var/<slug>/CONTINUE-W6.md`, and stop.
