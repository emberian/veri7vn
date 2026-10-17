# The geometry and statistics family, end to end

This folder carries six shipped Oracle7 specialists as one program: `geometry`, `geometry-v3`,
`geometry-v4` (areas, volumes, Pythagoras, Heron, polygon angle sums) and `statistics`,
`statistics-v2`, `statistics-v3` (mean, median, mode, range, variance, standard deviation,
z-scores, combinations, permutations, binomial probability). Same recipe as the quantity family
(`../quantity/README.md`).

- `GeoStats_Num.thy`: rounding with proved bounds, interval enclosure of pi and square roots
  (Isabelle's `Approximation`), number layout.
- `GeoStats_Geometry.thy`, `GeoStats_Stats.thy`: typed requests, declines, values, theorems, reply text.
- `GeoStats_Export.thy`: SML export, self test, oracle check, the `VERI7VN_GEOSTATS PASS` marker.
- `recognizer.sml`, `regex.sml`, `main.sml`: untrusted English reading and JSON framing.
- `tables_check.py`: checks kinds, polygon names and decline sentences against the organs.
- `score.py`: scores each specialist on its panel and compares with the shipped organ.

Statements, results and reproduction: [lane S11 handoff](../../../project/lanes/S11-geometry-stats.md).
