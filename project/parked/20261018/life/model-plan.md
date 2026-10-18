# J: diversity model selection and finite abundance roles

Canonical I demonstrably treats -10, 20, 30 as positive Shannon counts and
answers an explicit proportions-squared Simpson request with the distinct
without-replacement calculation. Exact observations are in
counterexamples-initial.json. For 10,20,30 the two dominance values are 7/18
and 67/177 respectively; neither formula is a universal synonym for the other.

Keep the shipped default visibly named: finite sample pairs without replacement,
D = sum n_i(n_i-1)/(N(N-1)), requiring N >= 2. Explicit proportions squared,
with replacement, or population-proportion requests instead use
D = sum n_i^2/N^2, requiring N > 0. Diversity is 1-D and reciprocal diversity
is 1/D; incompatible explicit model cues decline. The official vegan manual
separates the proportions-based indices and unbiased discrete-sample variants:
https://vegandevs.github.io/vegan/reference/diversity.html . NIST defines the
proportions-squared count-vector formula directly:
https://www.itl.nist.gov/div898/software/dataplot/refman2/auxillar/simpson.htm .

A count vector is a finite list of whole nonnegative abundances, including zero
entries. Complete shared numeric tokens must retain signs, fractions and
scientific notation; negative, fractional and malformed count tokens cannot
be recovered as positive suffixes. Probability/relative-abundance inputs are
a separate valid domain and should either be typed explicitly or withheld,
never silently coerced into these individual counts. One-species and total-zero
boundaries must depend on the chosen index, not a blanket reader cutoff.

Independent laws: normalized finite-count proportions sum to one when N>0;
squared-proportion dominance lies in [0,1]; exact output times N^2 equals the
sum of squares; complements sum to one; reciprocal times D is one under its
positive denominator; whole-count request success entails the count domain.
Do not claim statistical unbiasedness merely from an algebraic identity.

Implementation follows Anatomy H native convergence; no J proof submitted.
