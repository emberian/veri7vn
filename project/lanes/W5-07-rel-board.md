# Lane W5-07: relation readers on the board, reconstructed linker index

Status: done. The 161 `rel-*` readers ran on the held-out split through lane A's answerer with only `ORACLE7_ROOT`
changed to the reconstructed overlay `var/linker/o7root` (names_v1 rebuilt by `tools/linker/`; provenance in its `meta`
table). Root granted running the Oracle7 head by name; nothing was written under `upstream/`.

## Totals (held-out, 9,510 items, release composition, each verdict's own head)

| | right | false yes | wrong |
|---|---|---|---|
| This run (161 readers) | 8,313 | 0 | 16 |
| Shipped (same 161) | 9,124 | 0 | 9 |
| Same run before the index (lane A, readers silent) | 1,796 | 0 | not summed |

- Matched shipped exactly (right and false yes): 55 of 161. Matching right, false yes and wrong where the shipped file
  records wrong: 52 of 161. 26 readers answer more items right than shipped (by 1 to 4); 80 answer fewer (846 fewer in
  all, net 811 fewer); 55 are equal.
- False yes: 0, as shipped.
- Held-out items on the 30 properties with no row in `relations_v1`: 903 of 9,510 (9.5%), in 69 readers; 1,814 across
  both splits (rel-census), so the held-out share is 49.8%. Computed by `var/W5-07/analyze.py` (a property counts as
  absent when `fact` has no row for it). 140 of 161 readers fall short of shipped by no more than their absent-property
  items, so their whole shortfall is store gap; 21 readers fall short by more (31 items over their gap in total; largest
  rel-albums 4, rel-songs 3, rel-engineers 2, rel-lawyers 2, rel-videogames 2; the rest 1 each or within 2 of the gap).
  Five readers answer nothing right (rel-diseases, rel-languages, rel-rivers, rel-themeparks, rel-wars); their held-out
  items sit on absent properties (wars 24 of 24, rivers 24 of 24, diseases 12 of 12, themeparks 12 of 12, languages 12 of 12).
- The 16 wrong: 12 answers by a reader (a same-name entity linked first), and 4 `clarification` replies from the core
  (rel-albums 3, rel-songs 1) that the scorer counts as wrong, as in lane A's board. The 12: rel-albums Infinite /
  Score / Speaking in Tongues, rel-boxers Davey Boy Smith Jr., rel-films-v2 The Lover, rel-novels Hyperion, rel-operas
  War and Peace (the core answered, not the reader), rel-police Charles Warren, rel-rowers John Wallace, rel-skiers
  Hans Beck, rel-songs Two of Us and Promise. All are homonyms (W5-02's agreement rule is the planned fix).
- Process deaths: none.

## New control comparison (whole board, held-out)

Non-relation readers (129): 6,354 right / 17 false yes, equal to shipped. Relation readers on the reconstructed index:
8,313 / 0. Together 14,667 right / 17 false yes, against the release's 15,478 / 14 total: 811 right fewer, all within
the relation readers; the held-out items on absent properties (903) are more than that, because the core answers some
of them. Not reproduced: the shipped 9,124 depends on `relations_v2` and the original names_v1, neither of which ships.

## Files

- `docs/parity/BOARD.md` re-rendered with this run; the run directory carries `NOTE.md` (the reconstructed-index
  statement), which `board.py` now prints at the top and in the run's section. This needed a small edit to
  `tools/parity/board.py` (reads an optional `NOTE.md`; the "could not run" wording is skipped for a run with a note;
  the non-relation sentences are skipped when a run has no non-relation specialists). The harness CLI is unchanged, the 23
  parity tests pass. Root should confirm the transfer of `tools/parity/board.py`.
- Run output: `var/parity/rel-linker-board/` (ignored), analysis `var/W5-07/analyze.py` and `analysis.json`.

## Reproduce

```sh
IDS=$(ls upstream/root/specialists | grep '^rel-' | paste -sd, -)
ORACLE7_ROOT=$PWD/var/linker/o7root PYTHONDONTWRITEBYTECODE=1 python3 tools/parity/harness.py \
  --answerer "$PWD/.venv/bin/python tools/parity/answerers/oracle7.py --compose front --tip {shipped_head} --specialist {dir}" \
  --specialist "$IDS" --split heldout --out var/parity/rel-linker-board     # about 2.6 hours
python3 -B var/W5-07/analyze.py
python3 tools/parity/board.py --run "<label>=var/parity/<dir>" ...         # the six runs listed in BOARD.md
```

The answerer was started with the repo's `.venv` Python (3.12), as lane A did; the harness with system `python3`.
No `--lane-answerer`, as in root's command, so LANE/SELF/BUDGET read INCOMPLETE and decisions are not ADMIT/NEGATIVE
verdicts.

## Unverified

- Per-item attribution of each silence to an absent property was not done; the 903 is the count of items whose property
  is absent, not the count of those items that were silent (the core answers a few).
- 5 of the 21 "beyond the gap" readers are within 1 item of their gap; the cause of the rest (linker misses) is not
  traced here.
