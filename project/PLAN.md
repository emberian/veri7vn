> Active again, 26 October: [appliance and correctness batch](APPLIANCE-2026-10-26.md).
> Ember authorized appliance packaging, more specialists, upstream repairs and
> broad Terra review. The October 18 wrap-up below is historical.

> Latest terminal state and resume map: [DRAIN-2026-10-18.md](DRAIN-2026-10-18.md).
> The usage-aware drain is complete; the broader project remains unfinished.

> Current work and corrections: `project/CODEX-2026-10-18.md`.
> `project/HANDOFF-2026-10-18.md` records the preceding handoff; some of its
> completion claims were stronger than the receipts support.

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

The shared scoreboard runs the specialists' own shipped panels
(`upstream/root/specialists/*/`) through any
answerer that speaks the [answerer contract](../docs/contracts/answerer.md),
and scores them with the specialists' own scorers under the six criteria of
`upstream/workbench/exam.py`: domain gain, no false yes, few wrong, stays in
lane, self stays the core's, within budget.

Shipped answers are comparison data, not an obligation to preserve mistakes.
Ember's 18 October continuation explicitly requires judging every specialist
on its own merits. Keep the common panel numbers, and also check independent
counterexamples, mathematical models, units, requested quantities and actual
consumers. A perfect template score does not establish those properties. When
a scorer rewards an incorrect answer, record the disagreement and its reason;
repair the implementation rather than changing a constant to fit the scorer.

| Answerer | Specialists' panels right / wrong | Status |
|---|---|---|
| Oracle7 as shipped | 15,478 / 14 published on the held-out exams. Reproduced here: 14,667 right / 17 false yes with the shipped organs (129 non-relation readers exact; the 161 relation readers run on a reconstructed linker index over the v1 store, and the 811 missing answers sit on properties the shipped store does not contain) | the control (`docs/parity/BOARD.md`) |
| veri7vn revision-2 package (2026-10-16 morning) | 0 / 0, every panel item unrecognized | the starting line |
| veri7vn extracted `acoustics` binary (2026-10-16 night) | 69 / 0 on its 69 held-out items and 70 / 0 on dev, same as the shipped organ; 428 KB, 12 ms median, 0 false yes; also packaged as a drop-in Oracle7 specialist folder (`src/extract/acoustics/oracle7-organ/`) | first lifted specialist, at parity |
| veri7vn verified relation reader (2026-10-16 evening) | 60 answers on Oracle7's 205 relation-route core-panel items, 60 identical to Oracle7, 0 wrong | first lifted route |
| veri7vn `quantity` binary: densities, units, units-v3, springs, fluids, fuels (2026-10-17) | 320 / 0 on the six held-out panels and 321 / 0 on dev, same as the shipped organs; one 545 KB binary, 7 ms cold start, 0.2 ms median | one kernel, six specialists, at parity |
| veri7vn `fusion` binary: Oracle7's `network_v3` planner over the quantity, energy, climate and space kernels (2026-10-17) | 101 of the 102 core-panel fusion answers identical to Oracle7's text and route, 0 wrong; the last needs the geometry kernel; 0 verdict changes on 2,701 single-family panel items; 405 KB, 0.9 ms median | fusion proved: shallowest-depth agreement within 0.5% or decline |
| veri7vn beyond parity: chemistry and finance families (B-chemistry, B-finance, 2026-10-18) | chemistry/chemistry-v3 held-out 281 / 0 wrong / 0 withheld against the shipped organ's 223 / 2 / 56, decay 42/42 against 34/42; finance 129/0/0 against 116/0/13, economics 78/0/0 against 65/0/13; same on fresh generator seeds; cold starts 58 and 270 ms → 4 and 3 ms; the shipped retail organ ignores the sales tax it is asked to add (fixed) | the second scoreboard (`project/swarm/BEYOND.md`): 0 wrong stays the law, the other numbers move |
| veri7vn `relations` kernel: all 161 relation readers through one verified decision over the reconstructed linker index (2026-10-18) | 16,284 right / 0 wrong on their 18,976 panel items (shipped organs on the same store: 16,261 / 11); 1,814 silences are properties absent from the shipped store; the 11 homonym errors are now proved declines | one kernel, 161 specialists, 0 wrong |
| veri7vn: implementations for 144 of 144 non-relation specialist IDs (2026-10-18) | no current consolidated fleet score; current scoped repairs and their exact panel counts are in the Codex continuation and lane reports | the lift is a foundation; systematic semantic examination, correction and useful expansion continue beyond parity |

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
