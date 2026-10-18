# Front door consumer integration, 18 October 2026

Owner: Codex runtime/dispatch. This is Python consumer work; no theorem was
added or changed, and this lane ran no Isabelle build.

## What now works

The dispatcher uses the explicit runtime registry, resolves specialist owners
without executing probes, and shares the manifest-plus-extension acceptance
contract with packaging. Accepted refusals selected by arbitration end the turn. Acceptance follows the
shipped loader: a declared normal operation kind remains accepted when its
status is withheld, while a decline-only kind requires matching domain context
or, for a nonanswer, an explicit CLI specialist pin. The pin applies only to the owned ID's
declared kinds and never overrides `taken=false`. A family filter does not
supply domain context. Meaningful `clarify` responses stay terminal nonanswers.
Every accepted non-answered reply is classified as a decline for arbitration. Unrecognized questions fall through; stage failures withhold with
an error instead of silently disappearing.

It connects the new general relation adapter and document adapter, plus the
separate arithmetic, word-problem and precision-guard stages supplied by the
runtime/routes lane. Math's refusal fallback runs after answer-producing
routes. Precision guards inspect the selected answer, not a synthetic reply.
Disabled callbacks do not appear in `stages_run`. The document adapter uses the
repository Python environment because the system Python lacks its dependencies.

Evidence from producers is retained. Shared capability declarations are marked
as declarations, not a proof of the question's interpretation. The shared
consumer validator can reject an inconsistent asserted computation packet.
Its arithmetic is unverified Python corroboration, not a theorem.

Stateful families are not allowed to commit as speculative arbitration
candidates. Stores supports `--preview`, declared by `preview_flag` in the
registry. The dispatcher uses preview for unpinned fan-out, keeps cooking
answers and pure warehouse reads usable, and withholds a selected unpinned
proposal, order or cancellation with an explanation that an explicit pin is needed.

Pinned warehouse uses two long-lived children sharing a private state file:
one preview child and one committing owner. The whole turn is serialized.
Preview passes acceptance, selection and precision guards before the exact
original request is committed once. Preview reloads committed state each turn;
only the committing child writes. A guard rejection makes no state change.
An uncertain commit is never automatically retried. The actual commit reply is
reported without later narrowing and compared with the preview for diagnostics.
This relies on exclusive ownership of the private state file; it is not a
transaction protocol for independently writing processes.

## Checks and observed numbers

- `python3 -B tools/dispatch/test_dispatch.py`: 13 tests passed. These exercise
  registry roles, owner pins, acceptance, refusal composition, relation silence,
  preview/pinned state selection, skipped stateful perturbations, malformed
  subprocess and direct-call malformed metadata failing closed, and guard rejection
  preventing commit.
- `python3 -B tools/dispatch/dispatch.py --selftest`: 5/5 exact arbitration
  results, including candidate indexes. Previously the test compared only the
  decision name.
- `python3 -B tools/dispatch/test_routes.py`: 7 tests passed (owned by routes),
  including the actual guards protocol. No leaked Child streams in this run.
- Shipped held-out panels through pinned front composition, chemistry and
  finance families with all registered non-family routes enabled:
  **chemistry-v3 281/281 right, 0 wrong, 0 false yes; retail 51/51 right,
  0 wrong, 0 false yes**. Receipts: `var/dispatch/c-runtime-final/panels/`.
  The harness reports INCOMPLETE: head comparison, lane/self preservation and
  the full budget criterion were not measured.
- Eight end-to-end probes with chemistry and finance families, all other route
  roles active: 8/8 intended outcomes. H2O composition and discount-plus-tax
  answer; unknown element declines; Leaves of Grass returns Walt Whitman;
  negative distance declines; square root of 9.5 declines at math without
  later routes; square root of 9 answers 3; an unknown word withholds.
  `var/dispatch/c-runtime-final/frontdoor.json` records requests and replies.
- Chemistry's owner separately ran 9/9 composed positive/negative cases for all
  five extensions (`var/chemistry/c-composed-probes.json`). The physical deputy
  reports 96/96 scoped own-scorer cases unpinned and 95/96 pinned against warm
  candidates (old statistics-v2 withheld one valid item). These are their
  consumer observations, not a current full-fleet score.

`python3 -B tools/dispatch/check_state.py` checks the actual preview/commit
children. It passed: two losing warehouse candidates create no state file;
an unpinned stock read answers 107 with no state file; pinned stock read followed
by “Where is it?” returns bin A5-05 while a fresh session withholds; cooking still
answers and receives guards; pinned reorder plus confirmation
places exactly one order; repeat/cross-session confirmation adds none; an
injected guard blocks proposal with no file and blocks confirmation with the
pending-state bytes unchanged; a simulated uncertain commit is attempted once
and never retried. An unknown-item request is terminal when pinned and falls
through when unpinned; neither creates state. With an existing order and
reference state, the same unknown-item request in a fresh session leaves the
whole state file byte-identical. The receipt records the stores binary hash in
`var/dispatch/c-runtime-final/state-transaction.json`. Injected failures test
consumer sequencing, not completeness of the guard recognizer.

## Limits and next consumer checks

The real unpinned multi-domain probe “What is the density of Mercury?” still
selects the element from chemistry over the planet from astronomy. Both were
accepted candidates; the existing extracted arbitration ranks the element's
wording higher. The implementation preserves this rule and names the limitation;
it does not claim general disambiguation. A domain-specific pin selects its
own specialist.

The stage order covers the lifted capabilities, not every released head fold.
Guards model only 20 of 87 catalogue codes and do not yet receive store facts.
Unpinned warehouse previews do not persist conversation-reference state. Pinned
reads commit after guards and retain same-session references. Document summary/timeline composition is unfinished. Relation evidence still
assumes recognition, entity linking, complete fetches and source assertions.
A successful kernel call cannot establish those assumptions.

The current stores producer can resolve an explicit unknown item to a prior
same-session reference: after M4 valve stock/location queries, “purple widgets
count?” returns the M4 count. This newly observed producer defect is assigned
to the stores owner; the consumer's no-write test uses a fresh session against
a meaningful existing file. It does not claim to repair noun recognition.

Changes owned here: `tools/dispatch/dispatch.py`, `tools/dispatch/test_dispatch.py`,
`tools/dispatch/README.md`, `tools/dispatch/check_state.py`, and this report. The runtime deputy owns the shared
registry and contract; runtime/routes owns its module and tests; symbolic owns
the relation and document adapters. Root integrates and commits.
