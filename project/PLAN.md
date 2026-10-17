# veri7vn plan (revision 3, 2026-10-16)

veri7vn is Oracle7's sibling with an Isabelle spine. Oracle7 answers from
sourced records and 267 specialists, says "I can't verify that" otherwise, and
shows the path every answer took. veri7vn keeps that shape and adds two things
Oracle7 cannot have in Python: **assurance** (the kernels, the routing cascade,
the arbitration rule and the admission gate are HOL objects with proofs about
them) and **metareflective access** (the running system can state what its own
admission, routing and composition mean, and check a claim against that
statement). Components should flow both ways: a verified kernel extracted to a
small binary can sit inside Oracle7 as an organ, and an Oracle7 specialist with
its panel can be lifted into veri7vn and examined there.

Revision 3 supersedes the revision-2 plan and its 71-task tracker. That work is
kept in the tree and in git; it is not the path forward.

## The scoreboard

Nothing counts until it moves a number on the parity board. The board runs the
specialists' own shipped panels (`upstream/root/specialists/*/`) through any
answerer that speaks the [answerer contract](../docs/contracts/answerer.md),
and scores them with the specialists' own scorers under the six criteria of
`upstream/workbench/exam.py`: domain gain, no false yes, few wrong, stays in
lane, self stays the core's, within budget.

| Answerer | Specialists' panels right / wrong | Status |
|---|---|---|
| Oracle7 as shipped | 15,478 / 14 on the held-out exams (6,354 / 5 for the 144 non-relation specialists; 9,124 / 9 for the 161 relation readers, whose stores did not ship) | the control; the harness reproduces all 129 non-relation verdicts exactly (`docs/parity/BOARD.md`) |
| veri7vn revision-2 package (2026-10-16 morning) | 0 / 0, every panel item unrecognized | the starting line |
| veri7vn extracted `acoustics` binary (2026-10-16 night) | 69 / 0 on its 69 held-out items and 70 / 0 on dev, same as the shipped organ; 428 KB, 12 ms median, 0 false yes; also packaged as a drop-in Oracle7 specialist folder (`src/extract/acoustics/oracle7-organ/`) | first lifted specialist, at parity |
| veri7vn verified relation reader (2026-10-16 evening) | 60 answers on Oracle7's 205 relation-route core-panel items, 60 identical to Oracle7, 0 wrong | first lifted route |
| veri7vn `quantity` binary: densities, units, units-v3, springs, fluids, fuels (2026-10-17) | 320 / 0 on the six held-out panels and 321 / 0 on dev, same as the shipped organs; one 545 KB binary, 7 ms cold start, 0.2 ms median | one kernel, six specialists, at parity |
| veri7vn `fusion` binary: Oracle7's `network_v3` planner over the quantity, energy, climate and space kernels (2026-10-17) | 101 of the 102 core-panel fusion answers identical to Oracle7's text and route, 0 wrong; the last needs the geometry kernel; 0 verdict changes on 2,701 single-family panel items; 405 KB, 0.9 ms median | fusion proved: shallowest-depth agreement within 0.5% or decline |

The harness must first reproduce Oracle7's own `verdict_heldout.json` numbers
on a sample of specialists; until it does, it is not a scoreboard.

## What we are building now

| Lane | Deliverable | Owner |
|---|---|---|
| A. Parity harness | `tools/parity/`: runs any answerer over any panel, read-only against `upstream/`, reports per-specialist verdicts in `exam.py`'s terms; reference answerers for Oracle7 head, Oracle7 plus one specialist, packaged veri7vn | lane |
| B. Routing cascade | `audit/folds/`: a machine-readable catalogue of all 346 folds (guard, kind, what it reads, what it changes). `src/isabelle/routing/`: the cascade as a HOL object with its ordered semantics and the theorem that narrowing folds never add an answer | lane |
| C. Specialist contract and gate | `src/isabelle/specialists/`: manifest acceptance, `combo_runtime` arbitration (five ordered criteria; disagreement is refusal, never a pick) and the six exam criteria as HOL decision functions; exported and checked against the shipped verdict files | lane |
| D. One specialist end to end | `src/extract/acoustics/`: the acoustics organ lifted to HOL with its formulas proved, exported to SML, compiled with the MLton that ships inside Isabelle, speaking the answerer contract; scored on the acoustics panel through lane A | lane |
| F. Verified relation reader | `src/isabelle/reader/`: Oracle7's exact relation router (admitted patterns, up to three linked candidates, unique agreement or refusal) as a HOL decision over fetched candidate rows, with coverage of the fetch as an explicit premise; thin untrusted fetch over `upstream/root/relstore/relations_v1.sqlite3` | lane |
| E. Plain documents | README and this plan written for a reader who is not a software engineer | root |

Lanes own their paths. A lane that needs another lane's path asks root.

## Removed

The revision-2 operating system (Scala host, authority machine, durable
journals, recovery, Forget, search service, package lifecycle, deployment
generations, browser workbench, and the family theories that depended on those
sessions) was removed from the tree on 2026-10-17 after no lane needed it; it
remains in git history before that commit. What stays: the coverage audit
(`audit/coverage/`, `docs/coverage/`), the build driver (`tools/dev/`), and the
revision-3 work.

Deployment target is an extracted binary plus the SQLite stores, not a resident
Isabelle process. One Isabelle distribution exists on this machine; packages
never embed another.

## Rules

- A claim about behavior comes with a panel number or it is not made.
- `python3 tools/dev/check-native` holds the only build lock. Scoped sessions
  only; no full-tree builds without root.
- Documents say what the system does in plain words. A sentence a careful
  non-engineer cannot follow is rewritten, not compressed.
- Root commits named files often, including red checkpoints marked as such.

[DECISIONS.md](DECISIONS.md) keeps the revision-2 decisions for reference.
[VALIDATION.md](VALIDATION.md) and [REVIEW.md](REVIEW.md) describe the
revision-2 state as of 2026-10-16 and are not updated further.
