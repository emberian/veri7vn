# Lane S03-earth: geography, geology, seismology, hydrology, ocean, meteorology, greenhouse, greenhouse-r2

Files: `src/extract/earth/` (ROOT, base/Earth_Base.thy, Earth_Num, Earth_Geo, Earth_Geol, Earth_Seis,
Earth_Hydro, Earth_Ocean, Earth_Weather, Earth_Green, Earth, Earth_Export, tables_check.py, regex.sml,
recognizer.sml, main.sml, build.sh, score.py, README.md). Binary `var/earth/bin/earth` (919 KB, not in git).

## Result (lane A harness, both splits; same counts from score.py, 0 disagreements with the organs)

| Specialist | dev right/n | heldout right/n | wrong | false yes | shipped heldout | p50 ms (budget 50) |
|---|---|---|---|---|---|---|
| geography | 9/9 | 9/9 | 0 | 0 | 9/9 | 0.1 |
| geology | 18/18 | 18/18 | 0 | 0 | 18/18 | 37 |
| seismology | 34/34 | 29/34 | 0 | 0 | 29/34 | 43 |
| hydrology | 50/50 | 52/52 | 0 | 0 | 52/52 | 0.4 |
| ocean | 23/23 | 23/23 | 0 | 0 | 23/23 | 2.3 |
| meteorology | 52/52 | 46/46 | 0 | 0 | 46/46 | 0.5 |
| greenhouse | 48/48 | 45/45 | 0 | 0 | 45/45 | 37 |
| greenhouse-r2 | 48/48 | 45/45 | 0 | 0 | (no verdict shipped) | 37 |

Seismology misses (5 heldout, all kind gr): "For a region with a-value 6.4 and b-value 0.95, how many quakes of
magnitude at least 5 occur per year?" and four siblings. The shipped organ withholds the same five
(its regex wants "a-value of/is/=", these say "a-value 6.4"); the port is faithful, so the miss is identical.
Cold start ~0.87 s (the first item is a great-circle distance; cos/arctan enclosures). Wait: cold start is
over the reported p50 budget only for that first distance question.

## Receipt
Remote build on hbox: `var/earth/remote-build.log`, marker `VERI7VN_EARTH PASS theorems=87 oracles=0`
(also exported to `veri7vn/assertions/earth`). Exit 0.

## Theorem statements (all in src/extract/earth/*.thy; read them there, key ones)
- `render_x_sound`: render_x f x = Some s => exists layout L and decimal d with s = render_layout L d and
  |dec_val d - xsem x| <= layout_err L (xsem x)  (4 significant digits: |x|/1000 + 1e-9; fixed places: 101/200 * 10^-n).
- `gc_sound`: geo_kernel (GGc mi p1 l1 p2 l2) = Value x => latitudes in range and exists c, 0<=c<=pi,
  sin(c/2)^2 = hav(...) and x*(1 or km-per-mile) = 6371*c. `central_angle`, `hav_le_one` support it.
- `antipode_sound`, `antipode_involution`, `solar_time_sound`, `lat_distance_sound`, `capital_split_stated`.
- `gl_value_sound`, `gl_age_ratio_law`: (1/2) powr (age/h) * (1 + D/P) = 1; `gl_age_fraction_law`: (1/2) powr (age/h) = f;
  `left_composes`, `left_after_one_half_life`; declines: `gl_underspecified`, `gl_impossible_iff`.
- `seis_value_sound`, `seis_asks_back`, `energy_is_amplitude_power` (energy = amplitude powr 3/2), `energy_ratio_adds`,
  `mw_of_m0_of`, `m0_of_mw_of`, `sp_travel_times` (d/vs - d/vp = dt), `gr_log_count`, `gr_decreases_with_magnitude`.
- `hy_value_sound`, `manning_velocity`, `fill_time_times_flow`, `rational_method_si`.
- `oc_value_sound`, `shallow_speed_squared`, `tsunami_time_times_speed`, `deep_speed_relation`, `sonar_round_trip`.
- `w_value_sound`, `w_wind_chill_undefined`, `w_range_iff`, `dew_point_below_air`, `dew_point_humidity_roundtrip`,
  `rnd_even_nearest`, `ss_cat_monotone`, `bft_force_monotone`.
- `gh_value_sound`, `vpd_air_complements_vapour_pressure`, `ppfd_inverts_dli`, `plant_count_bounds`, `gdd_nonneg`.
Each domain also has `*_answered_iff` (answered iff the kernel gives a value that renders) and
underspecified/impossible iff-theorems.

## Untrusted / unproved
Recognizer, regex, JSON driver; `tables_check.py` is a check; text layout is not proved. greenhouse-r2's boundary
filter is in the recognizer (it is a narrowing wrapper), not in the kernel. The kernel is exact-enclosure, so a number
too imprecise to state four digits is withheld (`imprecise`); precision is per expression (50 bits default; wind chill 140, Mw 100).

## Remaining
Heat-index and others agree with the organ to the scorer tolerance but the organ's float rounding on exact ties can
differ (as in lane G). Core-panel lane/self checks (harness --lane-answerer) were not run.

## Reproduce
```
tools/dev/remote-build hbox src/extract/earth Veri7vn_Earth --expect 'VERI7VN_EARTH PASS'
sh src/extract/earth/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 -B src/extract/earth/score.py
python3 -B tools/parity/harness.py --answerer "var/earth/bin/earth" --specialist geography,geology,seismology,hydrology,ocean,meteorology,greenhouse,greenhouse-r2 --split both --out var/earth/parity
python3 -I -B src/extract/earth/tables_check.py
```
