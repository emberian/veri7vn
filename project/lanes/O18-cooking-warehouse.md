# Lane O18-cooking-warehouse: the store-backed specialists

Status: landed (commit b9035ab), at parity with the shipped organs on all six panels.

## What was built

`src/extract/stores/` (slug `stores`, session `Veri7vn_Stores`, marker `VERI7VN_STORES PASS theorems=37 oracles=0`):
one HOL kernel for cooking, cooking-v2, cooking-v3, cooking-v3-r2 (USDA nutrition) and warehouse, warehouse-r2
(site organ with sessions), exported to SML and compiled with Isabelle's MLton into `var/stores/bin/stores`
(564 KB, not committed).

- `Stores.thy`: the verified decision over fetched rows. Cooking (`nkernel`, `nreply`): unknown food / no value /
  clarify (readings in play differ by more than 15%) / no portion / incomplete fetch, else
  value = per100 x grams / 100 with grams from the asked mass, the shortest `1 cup...`/`1.0 cup...` portion row,
  or the organ's per-item preference; stated number rounded to the organ's 0/1/2 decimals. Site (`sstep`, `sread`,
  `sreply`): the session state machine (pending proposal, last item/zone/kind), stock = sum of events, run-out
  days = floor(count / (units picked in 7 days / 7)), sensor freshness, zone status, low list, neighbour bin.
- `Stores_Export.thy`: export, self test (nutrition, clarify, portions, counts, propose/confirm, run-out,
  sensor, stale, low list, number layout), oracle check, marker as an explicit `veri7vn/assertions` export
  (RC1 left the successful session's messages out of `build_log`; the export is what check-native found).
- `tables_check.py`: HOL tables (nutrient keys/units, gram factors, measure names, sensor kinds, unit suffixes)
  equal the organs and the store; every recognizer pattern (38 constants, 8 inline) equals the organ's text;
  word tables (FILLER, PRODUCT_TYPES, SPECIALTY, VARIANT, WORDNUM, PREP) equal the organ's. Passes.
- Untrusted: `recognizer.sml` (organ regexes, the USDA `match()` with its penalties, narrow_v1, the v2/v3 frame
  stripping, r2 boundary, the site's follow-up/pronoun/ellipsis resolution), `regex.sml` (lane G's port after the
  d85f26c case fix, verbatim), `json.sml`, `main.sml` (driver; starts the shim, parses ISO times),
  `fetch.py` (read-only sqlite `file:...?mode=ro`, unbounded queries, `complete: true`; warehouse session file).

Plumbing differs slightly from lane F: the binary is the answerer (the harness runs it directly) and it starts
`fetch.py` as its child, getting rows over a pipe; the stores are never copied. The warehouse session state is
computed by the kernel and stored by the shim in a JSON file (`--state`, default `var/stores/state/sessions.json`,
keyed by session id, plus an `orders` log). No time-based expiry of proposals exists in the organ, so none is
modelled: a proposal stays pending until a yes or no consumes it (`confirm_consumes`, `no_double_order`), or a
new proposal in the same session replaces it.

## Theorem statements (verbatim, Isabelle symbols spelled in ASCII)

- `first_min_Some`:
  ```
  "first_min f xs = Some y ==> y  in  set xs & (ALL z in set xs. f y <= f z)"
  ```
- `round_dp_sound`:
  ```
  "|of_int (round_dp k q) / pow10 k - q| <= 1 / (2 * pow10 k)"
  ```
- `nutrient_answer_sound`:
  ```
  assumes "nkernel e = NAnswer g p v pl"
  shows "EX f d. nq_hit e = Some (f, d) & row_of (nq_rows e) f = Some (p, nutrient_unit (nq_nutrient e))
  & amount_grams (nq_amount e) (nq_portions e) = Some (g, pl) & v = p * g / 100
  & nq_complete e & ~ spread (map fst (near_vals e))"
  ```
- `nutrient_requires_complete`:
  ```
  "nkernel e = NAnswer g p v pl ==> nq_complete e"
  ```
- `nutrient_value`:
  ```
  "nkernel e = NAnswer g p v pl ==> v = p * g / 100"
  ```
- `nutrient_default_grams`:
  ```
  "nq_amount e = A_default ==> nkernel e = NAnswer g p v pl ==> g = 100 & pl = None"
  ```
- `nutrient_mass_grams`:
  ```
  "nq_amount e = A_mass q w u ==> nkernel e = NAnswer g p v pl ==> g = q * grams_per u & v = p * q * grams_per u / 100"
  ```
- `nutrient_measure_portion`:
  ```
  assumes "nq_amount e = A_measure q nt ut m" "nkernel e = NAnswer g p v pl"
  shows "EX l w. pl = Some l & (l, w)  in  set (nq_portions e) & like_measure m l & g = q * w
  & (ALL x in set (nq_portions e). like_measure m (fst x) \<longrightarrow> slen l <= slen (fst x))"
  ```
- `nutrient_count_portion`:
  ```
  assumes "nq_amount e = A_count q nt w0" "nkernel e = NAnswer g p v pl"
  shows "EX l w. pl = Some l & (l, w)  in  set (nq_portions e) & count_ok l & g = q * w
  & (ALL x in set (nq_portions e). count_ok (fst x) \<longrightarrow> count_key l <= count_key (fst x))"
  ```
- `nutrient_readings_agree`:
  ```
  assumes a: "nkernel e = NAnswer g p v pl"
  and x: "x  in  set (map fst (near_vals e))" and y: "y  in  set (map fst (near_vals e))"
  shows "x - y <= 15 / 100 * lmax (map fst (near_vals e))"
  ```
- `nutrient_unknown_food`:
  ```
  "nkernel e = NDecline ND_unknown_food <-> nq_complete e & rows_ok e & nq_hit e = None"
  ```
- `nutrient_no_value`:
  ```
  "nkernel e = NDecline ND_no_value <->
  nq_complete e & rows_ok e & (EX fd. nq_hit e = Some fd & row_of (nq_rows e) (fst fd) = None)"
  ```
- `nutrient_clarify`:
  ```
  "nkernel e = NDecline ND_clarify <->
  nq_complete e & rows_ok e & (EX fd r. nq_hit e = Some fd & row_of (nq_rows e) (fst fd) = Some r)
  & spread (map fst (near_vals e))"
  ```
- `nutrient_no_portion`:
  ```
  "nkernel e = NDecline ND_no_portion <->
  nq_complete e & rows_ok e & (EX fd r. nq_hit e = Some fd & row_of (nq_rows e) (fst fd) = Some r)
  & ~ spread (map fst (near_vals e)) & amount_grams (nq_amount e) (nq_portions e) = None"
  ```
- `amount_grams_none`:
  ```
  "amount_grams a ps = None <->
  (EX q nt ut m. a = A_measure q nt ut m & (ALL x in set ps. ~ like_measure m (fst x)))
  | (EX q nt w. a = A_count q nt w & (ALL x in set ps. ~ count_ok (fst x)))"
  ```
- `nutrient_incomplete`:
  ```
  "nkernel e = NDecline ND_incomplete <-> ~ nq_complete e | ~ rows_ok e"
  ```
- `stated_within_tolerance`:
  ```
  "|stated_num u v - v| <= max (v / 20) (15 / 100)"
  ```
- `nreply_answered_iff`:
  ```
  "answered (nreply e) <-> (EX g p v pl. nkernel e = NAnswer g p v pl)"
  ```
- `nreply_states`:
  ```
  "nkernel e = NAnswer g p v pl ==>
  stated (nreply e) = Some (render_fixed (dp_of (nutrient_unit (nq_nutrient e)) v)
  (round_dp (dp_of (nutrient_unit (nq_nutrient e)) v) v))"
  ```
- `confirm_requires_proposal`:
  ```
  "fst (sstep s i ev) = SO_ordered n it ==> s_pending s = Some (n, it) & (EX r. i = I_confirm True r)"
  ```
- `confirm_without_proposal_refused`:
  ```
  "s_pending s = None ==> fst (sstep s i ev) ~= SO_ordered n it & fst (sstep s i ev) ~= SO_cancelled"
  ```
- `confirm_consumes`:
  ```
  "s_pending s = Some (n, it) ==>
  sstep s (I_confirm yes r) ev = (if yes then SO_ordered n it else SO_cancelled, with_pending s None)
  & s_pending (snd (sstep s (I_confirm yes r) ev)) = None"
  ```
- `no_double_order`:
  ```
  "s_pending s = Some p ==> fst (sstep (snd (sstep s (I_confirm yes r) ev)) (I_confirm yes' r') ev') ~= SO_ordered n it"
  ```
- `propose_sets_pending`:
  ```
  "ev_complete ev ==> sstep s (I_read (R_reorder n (Some it) w)) ev =
  (SO_confirm n it (stock_count (ev_events ev)), with_pending s (Some (n, it)))"
  ```
- `propose_idempotent`:
  ```
  "sstep (snd (sstep s (I_read (R_reorder n x w)) ev)) (I_read (R_reorder n x w)) ev = sstep s (I_read (R_reorder n x w)) ev"
  ```
- `reading_keeps_proposal`:
  ```
  "(ALL n x w. r ~= R_reorder n x w) ==> s_pending (snd (sstep s (I_read r) ev)) = s_pending s"
  ```
- `incomplete_fetch_declines`:
  ```
  "~ ev_complete ev ==> sstep s (I_read r) ev = (SO_incomplete, s)"
  ```
- `latest_Some`:
  ```
  "latest rs = Some (ts, v) ==> (ts, v)  in  set rs & (ALL x in set rs. fst x <= ts)"
  ```
- `sensor_fresh`:
  ```
  assumes "fst (sstep s i ev) = SO_sensor zn k u v lo hi a rng"
  shows "EX sn rs ts. ev_sensor ev = Some (sn, rs) & latest rs = Some (ts, v) & (ts, v)  in  set rs
  & (ALL x in set rs. fst x <= ts) & a = age_min (ev_now ev) ts & a <= of_int (ev_fresh ev)
  & sn = (u, lo, hi) & ev_complete ev"
  ```
- `stale_declines`:
  ```
  assumes "ev_complete ev" "ev_sensor ev = Some (sn, rs)" "latest rs = Some (ts, v)"
  "of_int (ev_fresh ev) < age_min (ev_now ev) ts"
  shows "fst (sstep s (I_read (R_sensor z k rng)) ev) = SO_stale (snd z) k (age_min (ev_now ev) ts)"
  ```
- `zone_parts_fresh`:
  ```
  assumes "(k, v, u)  in  set (zone_parts now fresh zs)"
  shows "EX sn rs ts. (k, sn, rs)  in  set zs & latest rs = Some (ts, v) & ~ stale now fresh ts & fst sn = u"
  ```
- `stock_value`:
  ```
  assumes "fst (sstep s i ev) = SO_stock nm c rl"
  shows "c = sum_list (map snd (ev_events ev)) & rl = ev_reorder ev"
  ```
- `runout_days`:
  ```
  assumes "fst (sstep s i ev) = SO_runout nm c rate d"
  shows "c = stock_count (ev_events ev) & rate = of_int (used7 (ev_now ev) (ev_events ev)) / 7 & 0 < rate
  & of_int d <= of_int c / rate & of_int c / rate < of_int d + 1"
  ```
- `low_exact`:
  ```
  "set (low_rows its) = {(nm, sum_list ds, rl) | nm rl ds. (nm, rl, ds)  in  set its & sum_list ds <= rl}"
  ```
- `low_sorted`:
  ```
  "sorted (map fst (low_rows its))"
  ```
- `stale_not_answered`:
  ```
  "~ answered (sreply (SO_stale zn k a))"
  ```
- `sensor_reply_states_value`:
  ```
  "stated (sreply (SO_sensor zn k u v lo hi a False)) = Some (show_g v)"
  ```

Definitions these rest on (all in `Stores.thy`): `spread vs <-> 0 < lmax vs & 15/100 < (lmax vs - lmin vs) / lmax vs`;
`rows_ok` (no negative amount, store unit = nutrient unit); `like_measure m l` (lower-cased label starts with
`1 <m>` or `1.0 <m>`); `count_ok`/`count_key` (SQL's per-item filter and ORDER BY as a tuple key);
`latest rs = first_min (%r. - fst r) rs`; `stale now fresh ts <-> of_int fresh < (now - ts)/60`;
`used7 now evs = - sum of negative deltas with now - 7*86400 <= ts`.

## Numbers (tools/parity/harness.py, `--split both`, right / wrong / false yes)

| Specialist | dev | held-out | shipped held-out |
|---|---|---|---|
| cooking | 200 / 1 / 0 (n 202) | 158 / 0 / 0 (n 218) | 158 / 218 |
| cooking-v2 | 209 / 0 / 0 (n 210) | 155 / 0 / 0 (n 210) | 155 / 210 |
| cooking-v3 | 191 / 1 / 0 (n 192) | 224 / 2 / 0 (n 228) | 224 / 228 |
| cooking-v3-r2 | 191 / 1 / 0 (n 192) | 224 / 2 / 0 (n 228) | no verdict file; panel is cooking-v3's |
| warehouse | raw 199 / 0 / 0; aligned (no `off_site`) 193 / 0 / 0 | raw 199 / 0 / 0; aligned 193 / 0 / 0 | 193 / 193 |
| warehouse-r2 | raw 199 / 0 / 0; aligned 193 / 0 / 0 | raw 199 / 0 / 0; aligned 193 / 0 / 0 | 193 / 193 |

Organ cross-check (`score.py`): 0 decision disagreements on all 2,476 items. Text identical except 87 cooking
replies (28 + 23 + 18 + 18) whose value is an exact decimal tie at 150 g (e.g. 1.3 g x 1.5 = 1.95): kernel rounds
up, organ prints the float below. Held-out misses, all the organ's own:
- cooking: 60 withheld, all "What's the X content of ..." (v1's frame leak, e.g. "s content spanish raw peanut").
- cooking-v2: 55 withheld: 52 "Can you give me the X content of ..." (the stripped question no longer asks),
  plus "What is the calcium value for 100 g of pound fat cake?" (clarify), and two no_value entries
  ("pink grapefruit juice" fiber).
- cooking-v3 / -r2: wrong "Would you tell me the iron value for 150 g of brain cooked beef?" (3.5 vs 3.33) and
  "... carbohydrates value for a cup of jackfruit?" (38.4 vs 42.6, different cup weight); withheld no_value
  "pumpkin flower" sugar and "pink grapefruit juice" fiber.
- dev: cooking "How many fat are in a cup of degermed cornmeal?" (wrong, as organ), "Sugar in a cup of crouton?"
  (no_value); v2 "What's the fiber level in a cup of pumpkin leave?"; v3 the cornmeal item.
- warehouse: none.

Timing: cold start (process start to first reply, including the Python shim and reading 7,793 food names)
120-145 ms cooking, 52-58 ms warehouse; median per item 0.45-0.8 ms cooking (budget 150), 1.25 ms warehouse
(budget 50). Rules 1, 2, 4, 5 of exam.py are INCOMPLETE on the board (no head or lane run in this lane).

## Known differences from the organs (none on the panels)

- Exact arithmetic: two store items (12mm pulley, large valve) get run-out days one more than the organ's float
  floor (135 units at 9 a week: exactly 105 days; the organ says 104).
- Clarify options are ordered by length then reading order (the organ's order for equal lengths depends on
  Python's set hashing).
- A count reply writes `x` for the organ's multiplication sign (the kernel's text is ASCII).
- A sensor without readings is declined as `incomplete` (the organ raises).

## Reproduce

```sh
python3 tools/dev/check-native --session Veri7vn_Stores --session-root src/extract/stores \
  --expect 'VERI7VN_STORES PASS' --timeout 900
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/stores/tables_check.py
sh src/extract/stores/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/parity/harness.py \
  --answerer "var/stores/bin/stores --specialist {id} --state var/stores/parity/state-{id}.json" \
  --specialist cooking,cooking-v2,cooking-v3,cooking-v3-r2,warehouse,warehouse-r2 --split both --out var/stores/parity
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/stores/score.py      # organ cross-check, timing
```
Receipt: `var/native-scaffold/sessions/df9b502bdac0335d/receipt.json` (status passed, build 6).

## Remaining

- Board rules needing the head (domain gain, false yes vs core) and the lane/self runs were not measured here.
- The session machinery (follow-ups, pronouns, neighbour, propose/confirm) is exercised by the self test and a
  smoke run, not by the panels, which give every item its own session.
- Family mode (no `--specialist`) asks cooking-v3-r2 then warehouse-r2; not scored.
