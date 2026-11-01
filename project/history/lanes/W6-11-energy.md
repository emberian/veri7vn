# Lane W6-11-energy handoff

Family `src/extract/energy/` (session `Veri7vn_Energy`). Remote build on persvati:
`VERI7VN_ENERGY PASS theorems=98 oracles=0` (was 92), marker last.

## What changed
- Five cross-kind laws added in `Energy_Family.thy`, all in the oracle scan.
- One exact-soundness theorem per sub-family kept (`thermo_exact_sound`, `home_exact_sound`,
  `hvac_exact_sound`, `iot_exact_sound`, `ren_exact_sound` and `ren_pi_sound`). The two restatements per
  sub-family (`kernel_X_exact`, `exact_parts_X`, `pi_parts_r`, `kernel_r_pi`) are gone as separate lemmas;
  `exact_parts*` are now `lemmas` fact lists cut out of the kept theorem, so the later proofs are unchanged.
  The kept theorems are now proved directly from `kernel_X_def` and `mk_exact` / `mk_pi`.
- Retired: `hvac_sizing` (restated the decline function; `hvac_sizing_always_declined` stays),
  `reply_r_pi_enclosed` (was `pi_bounds_sound` again).
- `pair_difference_nonneg` is now in the scan. Unscanned theorems: 3 to 0.
- No exported constant was renamed or removed. Generated SML is byte-identical to the previous build
  (216,642 bytes), so the binary `var/energy/bin/energy` is unchanged.

## New statements (verbatim)
```
theorem sensible_heat_swap:
  assumes h: "kernel_t (Thermo [t0, t1] (TSens m cs DT_temps)) = Exact k q"
  shows "kernel_t (Thermo [t1, t0] (TSens m cs DT_temps)) = Exact k (- q)"

theorem tons_btuh_roundtrip:
  assumes "kernel_v (VTons b) = Exact k q"
  shows "kernel_v (VBtuh q) = Exact (STR ''btuh'') b"

theorem btuh_tons_roundtrip:
  assumes "kernel_v (VBtuh t) = Exact k q"
  shows "kernel_v (VTons q) = Exact (STR ''tons'') t"

theorem cost_is_energy_times_tariff:
  assumes c: "kernel_h (HEnergy (Some w) (Some h) (Some rate) True) = Exact k c"
    and e: "kernel_h (HEnergy (Some w) (Some h) r False) = Exact k' e"
  shows "c = e * rate"

theorem swap_is_energy_difference:
  assumes s: "kernel_h (HSwap a b (Some h) r) = Exact k sv"
    and ea: "kernel_h (HEnergy (Some a) (Some h) ra False) = Exact k1 ua"
    and eb: "kernel_h (HEnergy (Some b) (Some h) rb False) = Exact k2 ub"
  shows "sv = ua - ub"
```
Helpers: `neg_swap`, `pre_t_none` (a temperature list has a sub-zero-kelvin entry independent of order).
Each law reads the kernel at two kinds; they hold because the kernel computes the pieces, so a kernel that
priced a swap or a cost differently from the energy kind would fail them.

## Counts (tools/audit, class file re-graded by hand)
| | statements | vacuous | definitional | binding | helper | unscanned theorems |
|---|---|---|---|---|---|---|
| before | 118 | 0 | 44 | 62 | 12 | 3 |
| after | 111 | 0 | 30 | 67 | 14 | 0 |

## Panels
Harness on the unchanged binary, thermo/energy-v2/energy-v3/hvac/renewables/iot, both splits: 569 replies,
status, response, kind and path identical to the previous run (0 diffs). Numbers as in S06-energy.md
(renewables heldout 23/26, rest all right).

## Fusion
Fusion imports the energy session; see the lane report for the remote rebuild result.

## Remaining
Cross-kind laws for renewables and iot (for example annual energy against capacity factor) not added.

## Fusion result
Remote rebuild of `Veri7vn_Fusion` on hbox (persvati killed the build twice under load) from a scratch copy with
climate and space taken from git HEAD, because the shared tree's `Climate.thy` and `Space.thy` were mid-edit by other
lanes and did not build. Marker `VERI7VN_FUSION PASS` found; the run then exited 2 on a database primary-key clash
while storing the session, after the theories had passed. `tools/fusion/measure.py`: 101 of 102 network items
same text (1 declined, needs geometry-v4), node phrasing 70/70, 12/12 validity. Unchanged.
