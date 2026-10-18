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

Mixed units and dataset exclusions (D)
-------------------------------------

Geometry converts explicit mm, cm, m, km, international inches, feet and yards
with exact rational factors before applying the existing shape calculation.
A requested output unit selects the common length base; otherwise the first
explicit input unit does. Responses label squared/cubed units for areas and
volumes. Bare dimensions inherit one common input unit and are then converted to the
requested output unit together with explicit lengths. Polygon side counts
remain dimensionless. A mixture of
explicit units plus a bare dimension is refused. Unsupported units and
malformed scalar captures cannot donate a numeric suffix to a length role.
The reader binds complete issued numeric spans; role and unit interpretation
remain untrusted. Exact factors follow NIST's international length definitions:
https://www.nist.gov/pml/owm/si-units-length .

Ordinary dataset operations consume the whole finite list. Explicit
`excluding`, `except`, `without` and `omitting` clauses remove every occurrence
of each named value. The HOL filter preserves retained order and multiplicity,
then feeds the existing mean/median/mode/range/variance/deviation kernel. Empty
and singleton results retain the existing operation-specific refusals. Commas
in datasets are separators, not thousands grouping. Unsupported modifiers,
including weighted exclusions, are refused instead of silently ignored.

New statements connect converted rectangle area to its original physical
lengths and the filtered mean to the original sum plus excluded observations.
These verify the typed computations; they do not certify English parsing.

Weighted requests share the ordinary complete-list parser for observations and
weights. Both “weighted mean of 1, 2, 3 with weights 1, 1, 2” and “mean of 1, 2,
3 weighted by 1, 1, 2” return 2.25; “using weights” and “average” are equivalent.
Lists admit exact fractions, scientific notation and signed observations, with
optional matched brackets. A weight list is never silently dropped. Negative
weights, unequal lengths and all-zero weights reach the existing kernel refusal;
zero individual weights remain valid. Weighted exclusions and other statistical
modifiers such as a trimmed mean remain unsupported, valid-but-withheld requests.


## Paired observations: covariance and fitted lines

Population/sample covariance and ordinary least-squares regression use equal-length
x and y lists, paired by position. Duplicate observations remain separate. Inputs
can use the same exact decimals, fractions and scientific notation as other
statistics. Examples:

- `What is the sample covariance for x values [1, 2, 3] and y values [2, 5, 5]?`
- `What is the regression slope for x values [1, 2, 3] and y values [2, 5, 5]?`
- `What is the least-squares line for x values [1, 2, 3] and y values [2, 5, 5]?`
- `Predict y at x=4 from the least-squares line for x values [1, 2, 3] and y values [2, 5, 5]?`

One pass accumulates n, sum x, sum y, sum x² and sum xy using exact rationals.
Population covariance needs at least one pair; sample covariance needs two.
A fitted line needs nonconstant x data. Empty or unequal-length lists are
refused before zip can discard observations. The returned line predicts y from
x with an intercept; explicit reversed-variable fits, weighted/filtered fits,
nonlinear models, constrained fits and uncertainty intervals are outside this
packet. Unread operation-prefix or list-tail modifiers are refused. Explicit
population/sample choice is required for covariance.

The exported computation is tied to independent centered-product covariance,
zero residual sum and zero x-weighted residual sum. Its squared-error
decomposition proves that the actual returned coefficients minimize squared
error over all intercept/slope pairs. These are exact typed-input statements;
English interpretation remains untrusted. Display uses four decimal places.
A full-line reply explicitly labels both coefficients as rounded and has no single scalar `value`;
slope, intercept, prediction and covariance do carry their scalar value.

`paired_probes.json` covers the coherent operations, malformed/incompatible data
and safe refusals. `check_paired.py` checks exact Fraction expectations and both
full-line coefficients. It separately reports right/wrong/false-yes/withheld-valid
and policy assertions, so a correct refusal of valid weighted or reversed
regression does not inflate capability counts. `generate_paired.py SEED OUTPUT`
provides independent seeded noisy/affine rational data for untouched evaluation.

Evaluating the displayed rounded line can accumulate error proportional to the
magnitude of x. The prediction operation instead evaluates exact internal
intercept + slope × x and then rounds that result; it does not first round the
coefficients. Exact-rational or significant-digit line display is future work.


Side and edge roles accept both “side 2 m” and “side length 2 m” forms.
MeasuredInput now binds complete source length units and complete requested
length/area/volume units before the existing exact HOL conversion. Unit symbols
retain their original case, and unsupported compound continuations such as m/s
or cm²/s are refused. Spelled unit names are case-insensitive. Polygon side
counts remain dimensionless and do not inherit a length unit. Unlisted length
scales, including megametres, remain unsupported even though mathematically
convertible; they are counted as valid withheld requests in evaluation.
