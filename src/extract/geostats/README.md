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
- `recognizer.sml`, `../commons/commons.sml`, `main.sml`: untrusted English reading and JSON framing.
- `tables_check.py`: checks kinds, polygon names and decline sentences against the organs.
- `score.py`: scores each specialist on its panel and compares with the shipped organ.

Statements, results and reproduction: [lane S11 handoff](../../../project/lanes/S11-geometry-stats.md).

## Beyond the shipped versions (Codex, 18 October)

All geometry and statistics version names now use the complete latest reader.
Geometry passes signed dimensions to the kernel, whose existing positive-length
guard rejects negative lengths. The new `weighted_mean` reply computes the sum
of value-weight products divided by the sum of weights, using exact rationals.
Values and weights must be equally long lists. Zero weights are permitted;
negative weights and a zero total are refused. Weights need not add to one.

Use an explicit question such as “What is the weighted mean of 10, 20 with
weights 1, 3?” The answer is 17.5. The theory proves the weighted balance
identity, exact refusal of invalid inputs, and agreement with the ordinary
mean when every weight is one. The English reader remains untrusted; malformed
or unsupported weighted syntax receives a refusal rather than an ordinary
unweighted mean. `capabilities.json` declares the new kind to the runtime.

`probes.json` and `check_probes.py` check the new behavior. The same author
wrote the recognizer and probes; the source formula is NumPy's documented
weighted-average equation, with our explicitly narrower nonnegative domain.

The build-time self-test still runs and the final oracle scan remains mandatory.
The self-test is no longer exported as an eager startup value. To compile a
checked remote export, pass its SML path as the first argument to `build.sh`.
