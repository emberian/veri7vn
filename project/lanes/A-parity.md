# Lane A handoff: parity harness

Status: harness, answerers, scorer, board and tests delivered; control done; veri7vn sample on the board; full
Oracle7 board running in the background (see "Full run"). Plain-language account: `docs/parity/README.md`.
Board: `docs/parity/BOARD.md`.

## Files (lane A owns these)

- `tools/parity/panels.py`: read-only loading of manifests, both panel shapes (`{"dev","heldout"}` and the flat list
  with `"split"`; all 304 shipped panels are the flat list), `__ORACLE7_ROOT__` substitution, scorer loading, core
  panel, shipped verdict normalised from both formats (exam.py's and the release gate v2's; all 290 shipped verdict
  files are gate v2). Bytecode writing off.
- `tools/parity/score.py`: exam.py's constants, `fillable`, tally, thresholds, LANE, p50 and decision with exam.py's
  reason strings. Adds `INCOMPLETE` for unmeasured criteria (never a pass).
- `tools/parity/harness.py`: drives any answerer over JSON lines; per-item timeout with restart; gives up after 3
  consecutive exits; resumable per-item `.items.jsonl` / `.lane.jsonl`; verdict `<id>.<split>.json` written last;
  `--rescore`; `{dir}` `{id}` `{shipped_head}` placeholders. Head counts come from `provenance.head`.
- `tools/parity/answerers/oracle7.py`: head; `--specialist` (exam.py composition, `exam.fillable` +
  `exam.Loaded.reply` imported from upstream); `--compose front` (release single-specialist composition: the organ
  in front, asked through upstream's `_gate/combo_runtime_v1` `_Organ`/`Combo._one`, one reply per turn);
  `--compose combo` (same through `Combo.reply`, which adds multi-part splitting); `--tip <fold>` (head built from an
  older admitted fold); `--alone`.
- `tools/parity/answerers/veri7vn_packaged.py`: wraps `bin/veri7vn launch --state ... --surface workbench -- run`.
- `tools/parity/board.py`: renders `docs/parity/BOARD.md`.
- `tests/parity/test_score.py`, `tests/parity/test_panels.py`: 19 tests, inline fixtures, no engine; one test reads
  exam.py's constants from the shipped file with `ast` and checks they equal score.py's.

## Contract notes (no contract change made)

- The answerer contract is unchanged. The harness uses two conventions inside it, documented in the README:
  `provenance.head` (the head's own reply, so one pass gives head and composed counts) and, for a specialist-alone
  answerer, `provenance.taken` (else a non-empty `path`) to mean "the specialist replied", which exam.py's LANE and
  SELF count. `provenance.specialist_ms` is the in-process specialist time used for BUDGET.
- `status` is passed through as the engine gives it (`clarification` occurs); scorers compare to `"answered"`.

## Control (held-out, right / false yes)

| Specialist | n | Shipped head | Our head | Shipped composed | A front, shipped head | B exam.py, shipped head | C exam.py, w540 |
|---|---|---|---|---|---|---|---|
| acoustics (w363) | 69 | 3 / 1 | 3 / 1 | 69 / 0 | 69 / 0 | 57 / 1 | 62 / 2 |
| cooking-v3 (w363) | 228 | 10 / 0 | 10 / 0 | 224 / 0 | 224 / 0 | 212 / 0 | 212 / 0 |
| densities (w524) | 51 | 3 / 0 | 3 / 0 | 51 / 0 | 51 / 0 | 50 / 0 | 51 / 0 |
| units (w363) | 76 | 5 / 0 | 5 / 0 | 76 / 0 | 76 / 0 | 43 / 0 | 47 / 0 |
| units-v3 (w363) | 75 | 4 / 0 | 4 / 0 | 75 / 0 | 75 / 0 | 48 / 0 | 48 / 0 |
| rel-actors (w525) | 96 | 24 / 0 | 20 / 0 | 96 / 0 | 20 / 0 | 20 / 0 | 20 / 0 |

Wrong counts (ours, run A): acoustics 0, cooking-v3 2, densities 0, units 0, units-v3 0, rel-actors 6. Shipped wrong
is recorded only for densities (0) and rel-actors (0; head 6, ours 6).

Explanations:
1. Head alone reproduces exactly on the five non-relation specialists with the head the verdict names.
2. The shipped composed numbers come from the release's composition (specialist in front of the head:
   `combo_runtime_v1.compose`, "as in spec_runtime_v1"), not exam.py's (head first, specialist only on a fillable
   decline). Run A uses the release's and matches exactly on the five. Run B's losses are all head-handled items
   (acoustics: 6 `operator:unparsed` declines, which are not in `READING_DECLINES`; 5 open-pipe items the head's math
   organ answered wrongly; 1 must-decline answered by `arb:explain_simply`).
3. The current head w540 contains the standing specialists itself (folds w504, w525, w526, w530, w533, w536 call
   `_gate/combo_runtime_v1.Family` / `Network`), so exam.py's DOMAIN gain is near 0 against it.
4. rel-actors: not reproducible here. All 161 `rel-*` organs (`organ_relation_v2`) link entities through
   `root/relstore/names_v1.sqlite3`; `exact_router_v1` / `general_reader_v1` read `root/relstore/relations_v2.sqlite3`.
   Neither ships (PACK_MANIFEST has only `relations_v1.sqlite3`; `mdfind` finds neither on this machine). Head 20 vs
   24 is UNVERIFIED per item: the likely cause is the w525 head's own relation network needing the same stores, but the
   shipped verdict keeps only 8 head fails, so the 4 items could not be identified.
5. LANE uses all 924 core-panel items as exam.py does; gate v2 used a 400-item sample, so taken counts are not
   comparable (units, units-v3 take 6 of 924, cap 9).
6. exam.py's `Loaded` cannot load shipped manifests (it does not substitute `__ORACLE7_ROOT__`, so e.g. cooking-v3's
   `db_path` fails). The answerer subclasses `exam.Loaded`, substitutes the placeholder, applies the release's
   init-path rule and constructs the organ with cwd in its folder; `Loaded.reply` is inherited unchanged.

## veri7vn packaged

Generation `var/deployment-ui-d44-standalone-aae0d7dd/generations/2fd159a8...`, acoustics held-out first 3 items:
**0 right / 0 false yes / 0 wrong**, all 3 withheld `veri7vn:unrecognized`, 36-47 s per call. State dir
`var/parity/veri7vn-state` (530 MB, reused). Parser checked on a success (`the sum of -2 and 3` ->
answered "The exact sum of -2 and 3 is 1.").

## Upstream writes: found and fixed for this lane, still live for others

The Oracle7 head writes `self_loop/vessels.json`, `vessels_events.jsonl`, `curriculum_requests.jsonl` and
`vessels.sqlite3` under `upstream/root/fable-content/oracle-m-series-2026-08-15/self_loop/` (fold w175 module
globals, w480 `VESSEL_DB`), regardless of ORACLE7_STATE. My first probe appended two events there (sessions `t1`, `t2`,
2026-10-16T22:00:43Z-22:00:45Z) before I found it; not reverted (another writer is live there). Since then the
answerer redirects those globals into its own state dir; checked: no `heldout-` session appears upstream. **Lane F is
currently writing there** (sessions `laneF-panel:*`), and `upstream/root/state/` exists (a run without ORACLE7_STATE).
Root should tell lane F; `redirect_self_loop()` in `tools/parity/answerers/oracle7.py` is the fix to reuse.

## Reproduce

```sh
P=$PWD/.venv/bin/python; LANE="$P tools/parity/answerers/oracle7.py --specialist {dir} --alone"
S=acoustics,cooking-v3,densities,units,units-v3,rel-actors
python3 tools/parity/harness.py --answerer "$P tools/parity/answerers/oracle7.py --compose front --tip {shipped_head} --specialist {dir}" --lane-answerer "$LANE" --specialist $S --split heldout --out var/parity/control-front-shipped-head
python3 tools/parity/harness.py --answerer "$P tools/parity/answerers/oracle7.py --tip {shipped_head} --specialist {dir}" --lane-answerer "$LANE" --specialist $S --split heldout --out var/parity/control-shipped-head
python3 tools/parity/harness.py --answerer "$P tools/parity/answerers/oracle7.py --specialist {dir}" --lane-answerer "$LANE" --specialist $S --split heldout --out var/parity/control-w540
python3 tools/parity/harness.py --answerer "python3 tools/parity/answerers/veri7vn_packaged.py var/deployment-ui-d44-standalone-aae0d7dd/generations/2fd159a898d0b7648dfce893f35a9a61f7ac0df05f7fa25314a29e001750cf45" --specialist acoustics --split heldout --limit 3 --out var/parity/veri7vn-sample
python3 -m unittest discover -s tests/parity
```

Control wall time: about 1-2 minutes per specialist warm (engine load about 5 s, about 0.1-0.8 s per item).

## Full run

`var/parity/run-full.sh` (var/ is ignored, so not committed; its two commands are below): pass 1 = release
composition (`--compose front`) with each verdict's head over all 305 specialists' held-out splits into
`var/parity/full-front-shipped-head/`; pass 2 = exam.py composition with w540 into `var/parity/full-exam-w540/`.
Resumable (rerun the script). Stop with `kill $(cat var/parity/full.pid)`; its trap stops the current harness by
`var/parity/full-harness.pid`, and the answerer exits on EOF. Progress: `var/parity/full.log`.

```sh
P=$PWD/.venv/bin/python; LANE="$P tools/parity/answerers/oracle7.py --specialist {dir} --alone"
python3 tools/parity/harness.py --answerer "$P tools/parity/answerers/oracle7.py --compose front --tip {shipped_head} --specialist {dir}" --lane-answerer "$LANE" --specialist all --split heldout --out var/parity/full-front-shipped-head
python3 tools/parity/harness.py --answerer "$P tools/parity/answerers/oracle7.py --specialist {dir}" --lane-answerer "$LANE" --specialist all --split heldout --out var/parity/full-exam-w540
python3 tools/parity/board.py --run "Oracle7 release composition, shipped head=var/parity/full-front-shipped-head" --run "Oracle7 exam.py composition, w540=var/parity/full-exam-w540" --run "veri7vn packaged, acoustics sample=var/parity/veri7vn-sample"
```

Status when this lane stopped: **running**, pass 1 at 15 of 305 (started 18:57 EDT; the machine's load average was
30-60 from other lanes, so expect about 3 h per pass; the 161 `rel-*` panels are 9,510 of the 17,436 held-out items,
about 0.8-1.3 s each). PID file `var/parity/full.pid`. The committed BOARD.md includes pass 1 as far as it had got.

Findings so far from pass 1:
- Every specialist finished with a shipped verdict has matched the shipped composed right and false yes exactly
  (14 of 14 at the commit; 24 of 25 in an earlier start that used `Combo.reply`).
- The one miss in that earlier start was `astronomy-v3` (129 vs 137): `Combo.reply` splits "Taking Mars as 1, how
  many times as massive is Mercury? (mass of Mercury relative to Mars)" into two parts and answers both, the first
  the wrong way round. The shipped exam predates that splitting; without it (`--compose front`) the count is 137,
  as shipped. That start was stopped and its outputs from the old mode deleted before restarting.
- exam.py's WRONG cap (max(1, 2% of n)) is not one of the gate v2 criteria: `astronomy` is shipped ADMIT with
  68 / 0 and 13 answered wrong; under exam.py's rules it is NEGATIVE ("WRONG: 13 answered wrong, cap 1").

## Unverified / remaining

- rel-* specialists (161) cannot score above their head here until `names_v1.sqlite3` and `relations_v2.sqlite3`
  exist; the board will show them as head-only.
- 14 `-r2` folders and `water-r3` have no shipped verdict (`water-r3` has no panel); `{shipped_head}` is empty for
  them, so the answerer uses w540 there.
- warehouse / warehouse-r2 exclude kind `off_site` (6 items) from the gate v2 count (`exclude_kinds_composed`);
  exam.py ignores it. Verdicts record both (`gate_aligned`); the board's delta column uses the gate-aligned count.
- The release gate's per-organ READING rule and multi-part splitting are in run A (through upstream's own `Combo`);
  exam.py composition (runs B, C) does not have them, as in exam.py.
- BUDGET p50 uses in-process `Loaded.reply` / `Combo.reply` times reported by the answerer, matching exam.py's
  timing points; not compared with shipped p50 (different machine).
