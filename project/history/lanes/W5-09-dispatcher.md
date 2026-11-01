# W5-09 Dispatcher: retract, fix, land

Branch `w5-09` (from dev, scout/dispatcher's two commits cherry-picked, report
moved to `project/scouts/reports/dispatcher.md`), merged into dev with
`--no-ff`.

## What the dispatcher is

`tools/dispatch/dispatch.py` takes a question and routes it like Oracle7's
head: the network stage (fusion), then every family binary with the verified
arbitration choosing, then the relation reader. It is untrusted glue; the
values come from the verified family kernels, the pick from the exported
arbitration rule. See `tools/dispatch/README.md`.

## The retraction

The scout's report said the space binary "has drifted past its parity receipt"
(astronomy-v3 111/3 against 137/0). That is wrong. Started with
`--specialist astronomy-v3` the space binary scores 137 / 0 / 0, as lane S02
recorded. The scout's control run and the dispatcher never passed the flag, so
the binary answered with astronomy-v3-r2's rules. The binary did not change.

## What changed

- `--specialist ID[,ID]`: the dispatcher starts every family binary that
  honours `--specialist` with that id (probed by running it for the id and for
  a bogus id; acoustics ignores its arguments and is not pinned). Other
  families stay in family mode. An id with a shipped manifest but no flag-aware
  binary runs in family mode with a note; an id that is no specialist exits 2.
  The harness passes it per specialist with `--specialist {id}`.
- Start-up refuses (stderr names the stage, exit 2) when a family binary, the
  fusion binary, `tools/fusion/answerer.py`, the reader's `answerer.py`
  (unless `--no-reader`) or `arb_check` is missing. Checked by moving
  `tools/fusion/` aside: `dispatch: stage network (fusion answerer) is missing
  its program: ...`, exit 2.

## Numbers (before is the scout's run; after is this branch)

Core panel, 924 items, head order, against the recorded status/path in
`upstream/workbench/data/core_panel.json`: **identical status and path on
924 of 924 items** before and after (the core takes no `--specialist`).
Statuses (dispatcher|record): answered|answered 268, answered|withheld 286,
clarification|answered 2, clarification|withheld 102, withheld|answered 58,
withheld|withheld 208. The 60 answers where the record withheld stay (no
precision guards yet; named in the report).

Ten whole-family panels, front order, held-out, ok / false yes / wrong:

| specialist | before (no flag) | after (`--specialist {id}`) | shipped ok |
|---|---|---|---|
| springs | 42/0/0 | 42/0/0 | 42 |
| units-v3 | 75/0/0 | 75/0/0 | 75 |
| densities-r2 | 51/0/0 | 51/0/0 | none shipped |
| physics-r2 | 123/0/0 | 123/0/0 | 123 |
| chemistry-v3 | 223/0/2 | 223/0/2 | 223 |
| cooking-v3 | 224/0/2 | 224/0/2 | 224 |
| optics-v5 | 51/0/0 | 51/0/0 | 51 |
| astronomy-v3 | 110/0/4 | 136/0/1 | 137 |
| calculus | 62/0/0 | 62/0/0 | 62 |
| soil-r2 | 36/0/0 | 36/0/0 | none shipped |

No regression on nine; astronomy-v3 rises from 110 to 136 right and from 4 to 1
wrong.

## What it cannot do yet

astronomy-v3 is 136/0/1, not the 137/0/0 the space binary alone gives. The one
item is "According to NASA, what is the density of Mercury?": the arbitration
picks chemistry-v3's element reading (13.5336 g/cm3) over astronomy's planet
(5429). Oracle7's head withholds this case. Moving the pinned family first in
the candidate order does not change the pick (tried, reverted), so it is a
property of the arbitration inputs (context match, dependence count), not of
order. Open; the wave's "137/0/0 through the dispatcher" is not met by this one
item. Chemistry-v3 and cooking-v3 keep their two wrong items each, as before.

## Reproduce

```sh
export PYTHONDONTWRITEBYTECODE=1 PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream
ARB=/Users/ember/dev/o7vn/var/scout-wt/dispatcher/var/dispatch/bin/arb_check   # or sh tools/dispatch/build_arb.sh
python3 -B tools/dispatch/measure_core.py -- --order head --arb $ARB
python3 -B tools/parity/harness.py --answerer "python3 -B tools/dispatch/dispatch.py --order front --specialist {id} --arb $ARB" \
  --specialist springs,units-v3,densities-r2,physics-r2,chemistry-v3,cooking-v3,optics-v5,astronomy-v3,calculus,soil-r2 \
  --split heldout --out var/dispatch/panels-after
```
