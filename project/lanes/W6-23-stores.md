# Lane W6-23-stores: completeness checked in HOL, tie rule, real-model scaling

Session Veri7vn_Stores, built on persvati (5 builds; the early ones failed on typos in new lemmas, not on proof difficulty).
Marker: `VERI7VN_STORES PASS theorems=42 oracles=0`, last command of Stores_Export.thy.
Binary rebuilt from the persvati export (564,184 bytes). Store files are now opened with `file:...?immutable=1`
(fetch.py and tables_check.py).

## What changed

`rows_ok` (the guard of `nkernel`, so every decline/answer theorem uses it) now checks, in HOL, that the fetched rows
agree with the query: at most one row per food, every row is for a food in play (the reading or a near reading), the reading
is among those in play, no negative amount, unit equals the nutrient's unit, every stored portion weighs more than 0.
Fails closed: `ND_incomplete`. Still the shim's claim and not checkable by the kernel: that no row was left out
(`nq_complete`; an absent row reads as "no value"). The audit's literal rule (every near food has a row) would turn the
organ's "no value" decline into "incomplete", so it was not adopted. Selecting the reading itself (organ `match()` with its
penalties) remains untrusted recognizer work; the kernel checks only that it is among the readings in play.

## New theorems (verbatim, ASCII spelling of symbols)

- `first_min_tie_first` (tie rule; SQL ORDER BY key LIMIT 1 keeps the first row among equals):
  `first_min f xs = Some y ==> EX pre post. xs = pre @ y # post & (ALL z in set pre. f y < f z) & (ALL z in set post. f y <= f z)`
- `nutrient_answer_covered`:
  `nkernel e = NAnswer g p v pl ==> distinct (map fst (nq_rows e)) & (ALL r in set (nq_rows e). fst r in set (map fst (nq_near e))) & (EX fd. nq_hit e = Some fd & fd in set (nq_near e) & (fst fd, p, nutrient_unit (nq_nutrient e)) in set (nq_rows e))`
- `nutrient_portion_real` (per-portion scaling against the reals, `realq = of_rat :: rat => real`):
  for `A_measure q nt ut m` and for `A_count q nt w0`: `EX l w. pl = Some l & (l, w) in set (nq_portions e) & 0 < w & realq v = realq p * realq q * realq w / 100`;
  for `A_mass q nt u`: `realq v = realq p * realq q * realq (grams_per u) / 100`.
- `grams_pos`: `0 < grams_per u`
- `stale_mono`: `stale now fresh ts ==> now <= now' ==> stale now' fresh ts`

## Counts (var/audit/extract.py, markers.py)

Before: 37 theorems in the scan list, 11 flagged external (audit table). After: 42 in the scan list; markers.py reports
thm=40 unscanned_thm=0, marker_last=True, oracle_scan=True, bad=[]. Vacuous: 0 (none before). The six theorems that lean on
fetch bits keep depending on `nq_complete`/`ev_complete` for the omitted-row claim (see above).

## Panels

Six specialists, `--specialist {id}` with `--state` per `state_flag`, both splits, 2,476 items: 0 changed replies
(status, response, value, kind compared against the previous run, item by item). Scores unchanged: cooking 200/1/0 dev,
158/0/0 held-out; cooking-v2 209/0/0, 155/0/0; cooking-v3 191/1/0, 224/2/0; cooking-v3-r2 191/1/0, 224/2/0;
warehouse and warehouse-r2 199/0/0 both splits. Harness output: var/stores/parity6/.

## Remaining

- Event-side completeness (`ev_complete`) is still the shim's bit; stock events carry no row identity to check against.
- Computing the organ's food choice in HOL would need `match()` and its tables ported into the kernel.
- tables_check.py passes; reproduce with persvati `tools/dev/remote-build persvati src/extract/stores Veri7vn_Stores -d src/extract/commons --expect 'VERI7VN_STORES PASS theorems=42 oracles=0'`.
