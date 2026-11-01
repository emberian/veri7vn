# Lane W6-04-climate: Climate theorem fixes (2026-10-18)

Family `src/extract/climate/`, session `Veri7vn_Climate`. Marker (last command of `Climate_Export.thy`, remote
build on persvati): `VERI7VN_CLIMATE PASS theorems=80 oracles=0` (was 79: two vacuous theorems removed, three
binding ones added, so 79 - 2 + 3). The fusion session `Veri7vn_Fusion`, which checks Climate_Num and Climate
again inside itself, rebuilt remotely: `VERI7VN_FUSION PASS theorems=32 oracles=0`. No exported constant was
renamed; `tools/fusion/measure.py` still gives 101 of 102 core network items with the same plan and the same text
(the one other is the recorded `needs geometry-v4` decline), climate panels composed_right 297, node phrasing 70/70.

## What was removed

- `mass_ppm_inverse` (`c / g * g = c`, true of any nonzero g, never mentioned the kernel).
- `kernel_deterministic` (`kernel r = o1 ==> kernel r = o2 ==> o1 = o2`, true of any function).

## New binding theorems (verbatim, all in `Climate.thy`, all in the export scan)

```
theorem carbon_kernel_roundtrip:
  assumes "cc_kernel (Cc_c_to_co2 m u) = Exact k q"
  shows "cc_kernel (Cc_co2_to_c q u') = Exact K_co2_to_c m"

theorem sub_index_monotone:
  assumes "sub_index p c1 = Some a1" "sub_index p c2 = Some a2" "c1 \<le> c2"
  shows "a1 \<le> a2"

theorem albedo_decline_iff:
  assumes "0 \<le> s"
  shows "cl_kernel (Cl_eff_temp (Some s) (Some a)) = Decline (Impossible R_albedo_range)
         \<longleftrightarrow> a < 0 \<or> 1 < a"
```

What they bind to. `carbon_kernel_roundtrip` is the whole kernel path (decline check and kind included), not the
bare value function. `sub_index_monotone` is stated for every pollutant against the transcribed table `rows p`
(`idx_rows` zipped with `bps p`): the helper predicate `rows_ordered` (each row has positive concentration width and
non-decreasing index range; every later row starts strictly above in concentration and at or above in index) is
proved of all six tables by `all_rows_ordered` (`simp` on the table constants, no oracle), then `find_rows_mono`
shows the first-matching-row index is monotone. A mis-ordered or overlapping breakpoint row makes
`all_rows_ordered` fail. Concentrations in a gap between rows have no index and are not compared (the organ
declines them). `albedo_decline_iff` adds the converse half, using `cl_decline_cases` (the only other decline of
that request is Imprecise).

Helper lemmas added (not headline): `rows_ordered_valid`, `interp_mono`, `interp_le_hi`, `interp_ge_lo`,
`find_in_row`, `find_rows_mono`, `all_rows_ordered`.

## Counts (var/audit extract + markers + class file, climate row)

| | before | after |
|---|---|---|
| theorems+lemmas | 85 | 93 |
| vacuous | 2 | 0 |
| binding | 46 | 49 |
| helper | 13 | 20 |
| unscanned headline theorems | 0 | 0 |
| marker last, oracles | yes, 0 | yes, 0 |

(`aggregate.py` currently fails on another family's class file, so the climate row was taken from
`check_class.py climate` after editing `var/audit/class/climate.txt`, which is untracked.) No `by eval` in the family.

## Panels

All six specialists re-scored through `tools/parity/harness.py` (`PYTHONDONTWRITEBYTECODE=1`, `--split both`)
with the rebuilt binary and, as control, the previous binary: all 306 replies identical (reply text, status,
value; only timing differs). Numbers unchanged: carboncapture 14/14, airquality 38/30, climate 24/24,
carbonmat 17/17, coldchain 30/30, coldchain-v2 30/29 (dev/heldout right, 0 wrong, 0 false yes).
Binary `var/climate/bin/climate` rebuilt from the persvati export (619,944 bytes).

## Notes for root

- Remote builds from `tools/dev/remote-build` share `~/veri7vn-builds/o7vn` on persvati between lanes; mine collided
  once (SQLITE primary-key failure) and was killed (exit 143) several times when run from the shared name. I built
  from a copy named `w6-04-climate` (scratch checkout of src/ and tests/), then ran isabelle build under nohup with a
  recorded PID. Remote dir `~/veri7vn-builds/w6-04-climate` can be removed by you when convenient.
- `build.sh` was not run (it takes the local lock and builds Isabelle locally); the MLton step was done by hand
  with the same mlb, against `var/climate/export-remote/Veri7vn_Climate/`.
