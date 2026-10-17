# Lane W5-06: route column on the board

## What changed
- `tools/parity/routes.py` (new): reads a path as `route>pipeline steps`, where `|` joins a guard or clarification to the
  organ it stood in front of. Counts the 924 core-panel items by route with the answered / withheld / clarification
  split; also counts recorded `*.items.jsonl` replies (`--items`), and what each `var/<family>/parity` run takes of the
  core panel (`--families`, from `*.lane.jsonl`, using `provenance.taken` else a non-empty path, as the harness does).
- `tools/parity/board.py`: a "Routes" section at the end of the board (`--no-routes` leaves it out). CLI and the rest of
  the output are unchanged; regenerating `docs/parity/BOARD.md` from the same five runs differs only in the timestamp
  and the new section.
- `tests/parity/test_routes.py`: 4 new tests (23 in all, `python3 -m unittest discover -s tests/parity`, OK).
  One of them asserts 0 of 924 core items reach the code organ.
- Nothing was run against Oracle7; nothing written under `upstream/`.

## Result
- Code organ: 0 of 924 core items have any route or pipeline step starting `code` or `organ:code` (the string "code"
  appears in no core path at all). Reproduces the scout's hand count.
- Route table: see `docs/parity/BOARD.md`, section Routes. Largest: `organ:relation` 204 (all answered),
  `specialist_call` 186 (142 answered, 44 withheld), `precision_guard:*` 114 (all withheld), `network` 96,
  `act:clarify` 94, `unverified:*` 37, `arb:*` 30, `organ:math` 24.
- Family reach (items the binary replies to): quantity 109, mechanics 55, facts 28, acoustics 0. Only these four have
  lane runs; the other 15 landed families were scored without `--lane-answerer`, so their reach is not recorded.
  Re-run those with a lane answerer to fill the column.

## Cannot do yet
- It is a count of recorded paths from the w538 head, not a prediction for a new family: a family's reach comes only
  from a run that included the lane answerer.
- Route keys fold `precision_guard`, `unverified`, `arb` and `op` variants into one row each.
