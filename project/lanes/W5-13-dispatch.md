# W5-13 Dispatcher: the pinned specialist goes first

Change: `tools/dispatch/dispatch.py`, `Dispatcher.organs_stage`. In `--order
front` with `--specialist ID`, the family binaries started with the pin are
asked alone first and go through the (unchanged) arbitration. If that yields an
answer or a Disagree, the turn ends. Otherwise the other families go through
the arbitration, then the network and the reader run as before; the pinned
specialist's in-domain decline is kept as the fallback. Without `--specialist`,
or in head order, the code path is the old one. `Arbitration.thy` and
`tools/gate/` are untouched.

Why: the arbitration picked chemistry-v3's element reading for the Mercury
density question because its reply repeats question trigrams and wording ranks
before the context cue. That is Oracle7's own rule, so the composition changed.

## Numbers (held-out, front order, ok / false yes / wrong)

| specialist | W5-09 | W5-13 |
|---|---|---|
| springs | 42/0/0 | 42/0/0 |
| units-v3 | 75/0/0 | 75/0/0 |
| densities-r2 | 51/0/0 | 51/0/0 |
| physics-r2 | 123/0/0 | 123/0/0 |
| chemistry-v3 | 223/0/2 | 223/0/2 |
| cooking-v3 | 224/0/2 | 224/0/2 |
| optics-v5 | 51/0/0 | 51/0/0 |
| astronomy-v3 | 136/0/1 | **137/0/0** |
| calculus | 62/0/0 | 62/0/0 |
| soil-r2 | 36/0/0 | 36/0/0 |

Core panel (924 items, head order, no `--specialist`): status table identical
to W5-09's (268/286/2/102/58/208 for answered|answered ... withheld|withheld).
The path is unchanged by construction (the new branch needs a pin); I compared
the status counts, not a per-item path diff.

## Cannot do yet

Head order without `--specialist` still lets the arbitration choose the
element for the Mercury question; Oracle7's head withholds there for a reason
not traced. chemistry-v3 and cooking-v3 keep their two wrong items each.

## Reproduce

```sh
export PYTHONDONTWRITEBYTECODE=1 PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream
sh tools/dispatch/build_arb.sh
python3 -B tools/parity/harness.py --answerer "python3 -B tools/dispatch/dispatch.py --order front --specialist {id} --arb var/dispatch/bin/arb_check" \
  --specialist springs,units-v3,densities-r2,physics-r2,chemistry-v3,cooking-v3,optics-v5,astronomy-v3,calculus,soil-r2 \
  --split heldout --out var/dispatch/panels-w513
python3 -B tools/dispatch/measure_core.py -- --order head --arb var/dispatch/bin/arb_check
```
