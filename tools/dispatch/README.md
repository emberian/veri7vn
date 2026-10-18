# The dispatcher: one front door for the family binaries

An answerer (docs/contracts/answerer.md) that takes a question and routes it the
way Oracle7's released head does, using veri7vn's verified kernels as the
organs. It is **untrusted glue** around three verified pieces: the family
kernels (`var/<slug>/bin/<slug>`, one per family), the fusion planner
(`var/fusion/bin/fusion`), and the arbitration rule (`var/dispatch/bin/arb_check`).

## The order it reproduces

Read from the released chain itself (lane B's catalogue, `audit/folds/folds.json`):

| Stage | Oracle7 fold | What the dispatcher does |
|---|---|---|
| network | w508 (pre-route, index 64, fires before the specialists) | the fusion answerer; an answer returns as `network><trace>`; a **validity** decline ("26 hours a day") withholds the turn and stops the cascade, exactly as w508 does; any other decline falls through |
| specialists | w504 (index 68) then w525's new family (index 28, post-replace on a lacking turn) | every family binary is asked in parallel; replies that pass their manifest's accept rule (combo_runtime_v1's `_Organ.reply`) become candidates; **the exported HOL `arbitrate` picks** — an answer or a Disagree ends the turn, an in-domain decline is only a fallback |
| relation reader | the head's `organ:relation` route | lane F's reader, only when nothing above answered (the slowest organ) |
| decline | everything else | `dispatch>declined` |

`--order front` swaps the first two stages: the organ in front of the head,
which is the composition Oracle7's own shipped verdicts reproduce under, and
the one to use on a specialist's own exam panel.

With `--order front --specialist ID` the pinned specialist is asked **alone
first**, as Oracle7's own exam composes it. Only when it does not answer (a
decline or no take) does the rest of the cascade run: the other families
through the arbitration, then the network, then the reader. The arbitration
rule is untouched. Without `--specialist`, or with `--order head`, nothing
changes. This is what makes "According to NASA, what is the density of
Mercury?" come out as astronomy-v3's planet (5429) instead of chemistry-v3's
element: the arbitration ranks wording before the context cue, so the fix is in
the composition, not the rule.

## Run it

```sh
sh tools/dispatch/build_arb.sh     # MLton: exported Arbitration.thy + arb_driver.sml -> var/dispatch/bin/arb_check
python3 tools/dispatch/dispatch.py --selftest        # five arbitration cases against the HOL tests
echo '{"id":"1","q":"...","session":"s"}' | python3 tools/dispatch/dispatch.py --order head

# the 924-item core panel against the recorded status/path (needs PARITY_UPSTREAM for the panel):
PARITY_UPSTREAM=../../upstream python3 tools/dispatch/measure_core.py -- --order head

# ten whole-family panels, no regression (front composition):
PARITY_UPSTREAM=../../upstream python3 tools/parity/harness.py \
  --answerer "python3 tools/dispatch/dispatch.py --order front --specialist {id}" \
  --specialist springs,units-v3,densities-r2,physics-r2,chemistry-v3,cooking-v3,optics-v5,astronomy-v3,calculus,soil-r2 \
  --split heldout --out var/dispatch/panels
```

Binaries are looked up under `--var-root` (default `/Users/ember/dev/o7vn/var`)
as `<slug>/bin/<slug>`. The reader stage runs the main checkout's
`tools/reader/answerer.py` (it imports upstream's wander-train modules); `--no-reader`
drops it. Everything is read-only against `upstream/`.

## Whose rules apply, and refusing to start

A family binary holds several versions of a stem (astronomy-v3 and
astronomy-v3-r2) and, without `--specialist ID`, answers with the family's
fixed order. `dispatch.py --specialist ID` starts every family binary that
honours the flag (probed: it must answer for ID and exit non-zero for a bogus
id) with `--specialist ID`; other families stay in family mode. A family
without the flag (acoustics) runs in family mode with a note; an ID that is no
shipped specialist is an error (exit 2). The core panel uses no flag.

At start-up it checks every stage's program (each family binary, the fusion
binary and its `answerer.py`, the reader's `answerer.py` unless `--no-reader`,
`arb_check`). Any missing one prints `dispatch: stage <stage> is missing its
program: <path>` on stderr and exits 2. Before this, a copy without
`tools/fusion/` lost 58 network answers with the error only in a log.

## What is trusted where

- **Verified**: each family reply's value (proved kernels); the fusion decision
  (`Fusion.fdecide`); the arbitration outcome (`Arbitration.thy`'s `arbitrate`,
  called through `arb_check`; `--selftest` pins five cases from
  `Specialists_Tests.thy`).
- **Untrusted** (this directory): the reading of a turn into givens, wording,
  answer values, declines and context matches (a line-by-line port of
  combo_runtime_v1's oracles, kept in one block in dispatch.py); the
  counterfactual dependence count (re-asks the organ with each given nudged);
  the stage order; path relabelling (`veri7vn:fusion>` → `network>`);
  the `specialist_call>` prefix; the manifest accept gate; the fan-out.

## Known divergences from the recorded head

Named and counted in `SCOUT_REPORT.md`: the v3-only network (18 `network3>`
items and ~18 specialist items relabelled/stolen; 17 replies name `densities`
where the shipped network names `densities-r2`), no precision guards (60
core-panel answers where the head withheld), the reader's 35-pattern coverage
(69 of 204 `organ:relation` items), no `rel-*` specialist panels' stores, and
an alphabetical organ pick order where Oracle7 uses its family order. (The
Mercury planet/element item is fixed in pinned front order by asking the
pinned specialist first; head order without `--specialist` still lets the
arbitration choose the element.)
