# Life semantic gaps

This ledger separates tested repairs from remaining model limits. Passing the shipped panels does not establish arbitrary biological correctness.

| Specialist | Supported model and current result | Remaining semantic work |
|---|---|---|
| genetics-v2 | Independent diploid Mendelian loci under complete dominance; one to six distinct loci; parent/target order now matched by identity. Reordered ccbbAa and parents produce 1/32; duplicate loci decline. | Phased linkage, penetrance and codominance require their own explicit models. Recognition and real-world applicability remain untrusted. |
| biology | Standard genetic code, first-base frame; explicit template/coding role and strand direction normalized in HOL. Both template orientations yield AUGCCU/MP in focused tests; incompatible code/frame or ambiguous direction declines. | Nonstandard codes, alternative frames, splicing, ambiguous nucleotide alphabets and multiple sequences are not implemented. The default unstated direction is 5-prime to 3-prime. |
| ecology | Diversity estimates, continuous logistic/exponential and discrete geometric growth. Shipped and fresh panels all pass. | E binds population versus derivative and initial versus future time, with physical domain guards and zero equilibrium. Mixed time units, backward time and negative-rate above-capacity finite trajectories remain unsupported. Distinguish sample/population Simpson conventions. |
| forestry | Basal area, Doyle, Smalian, height and stand calculations; plural DBH phrasing repaired. | Audit species/bark/taper assumptions and signed/unit role inputs beyond templates. No new concrete counterexample is claimed. |
| wildlife | Lincoln–Petersen/Chapman, survival and density; explicit count roles and impossible survivor counts repaired. | Sampling assumptions, population closure and unequal capture probabilities remain external premises; further ambiguity and extra-observation tests are useful. |
| microbiology-v2 | Binary fission, serial dilution and CFU. CFU now requires explicit uniquely bound plated volume and preserves numeric signs/fractions/scientific notation. Kernel proves nonnegative concentration under nonnegative count, dilution in (0,1], positive volume. | Replicate-plate aggregation and uncertainty are not implemented. Growth requests still need broader physical-domain review beyond existing generator templates. |

D passed 179/179 shipped items in both dispatch modes, two development fresh seeds and new untouched seed 10186013 after the final shared numeric parser freeze at 179/179 each, and 43/43 same-author targeted probes. Those probes scored 25/43 with six wrong answers and nine false yes on the frozen C binary. The final D receipt has 110 scanned theorems and zero oracles. See the lane report for immutable artifacts and exact checks.

## E verified follow-up

The D claim for microbiology concerns colony count and volume, not complete
numeric grammar coverage. Root found `45 colonies from a -1:100 dilution with
0.25 ml plated` wrongly returned 18000; E replaces dilution suffix matching with
whole-token, role-bound exact parsing. This is an actual reachable defect.

Ecology E repairs observed confusion between input growth rate and requested
population, between initial and future derivative, and the K=0 population
answer. Negative N/K exploratory inputs already withheld; their typed-domain
holes alone were not treated as demonstrated reader failures. New time/target
requests and kernel domain laws passed 116-theorem proof/zero-oracle scan and bound native verification. E does
not settle species-count parsing, Simpson conventions, mixed units, arbitrary
multi-observation contexts, or the rest of the family ledger above.

E passes 179/179 shipped in both modes and development seeds 10181001/10182003
plus new untouched seed 10187017. The 80 authored policy checks all pass;
capability is 73 right, 0 wrong, 0 false yes, 7 withheld-valid. Valid unsupported
requests are not credited as solved merely because their intended refusal
passed. See the lane report for the seven remaining examples and comparisons.


## F: microbiology dimensions and domains

Binary-fission inputs now preserve complete signs, fractions and scientific
notation for the initial/final count, doubling time and elapsed time. Seconds,
minutes, hours and days convert exactly; generation-time output uses the
explicitly requested unit (minutes by default). This model assumes constant
binary fission, positive doubling time, nonnegative initial count and forward
time. Serial dilution requires a positive integer factor and a nonnegative
integer number of steps; zero steps is the identity dilution.

The bound F artifact passes 179/179 shipped items in both modes and each of
three fresh panels, including untouched seed 10188019. All 109 authored policy
assertions pass. Capability is 98 right, 0 wrong, 0 false yes and 11 valid
requests withheld. The proof scans 123 theorems with zero oracles. Remaining
limits include backward-time requests, rational serial factors, output weeks,
replicate-plate uncertainty and nonconstant growth. These are limits rather
than solved capabilities. See project/lanes/F-life.md for the exact artifact.


## G: forestry quantities and stand aggregation

The forestry reader binds complete dimensions and tree-density roles. It sums
explicit nonoverlapping diameter classes, retains metric stand density, converts
eye height separately from horizontal distance, and declines negative dimensions
or counts. An arithmetic mean alone does not determine exact basal area;
uniform diameter or quadratic mean diameter does. The imperial model retains
the stated0.005454 inch coefficient; metric cross sections use pi. Doyle and
Smalian remain log-rule models, and clinometer height assumes horizontal ground.

G has128 scanned theorems with zero oracles and passes179/179 shipped items
in both modes, two development seeds and new untouched10189033. All136 authored
policy checks pass; capability is124right,0wrong,0false yes,12withheld-valid.
See project/lanes/G-life.md for the exact receipt and remaining assumptions.


## H: wildlife observations and requested units

Counts use complete exact numeric tokens and unique roles. Density converts
between hectares, acres, square kilometers and square miles. Two-endpoint
closed-cohort survival distinguishes conditional second-period mortality
from cumulative mortality:100→75→60 means20% and40%, respectively. Explicit
first/second endpoint identity is preserved when statements are reordered.
Conflicting observations, negative/fractional counts and unsupported period
conversions decline. A multi-year aggregate alone cannot identify an annual
rate. Existing Chapman positive-overlap coverage remains; zero-overlap Chapman
and more than two sampling occasions still need a separate coverage/model.

H proves133 scanned statements without oracles. Shipped and each of three
fresh179-item panels pass in full;174 authored policy checks pass, with
161 right,0 wrong,0 false yes and13 withheld-valid capability cases.
See project/lanes/H-life.md and var/life/h-delivery/ready.json. H is staged on
G; canonical E and frozen F/G packets remain unchanged until root promotion.


## I: explicit positive translation frames

After normalizing the stated strand role/direction, the kernel selects frame
1,2 or3 by dropping frame-1 bases, checks complete remaining codons and
translates the standard genetic code up to the first stop. Mixed T/U is checked
before selecting a suffix. Replies name the frame; a stop at the selected start
is explicitly an empty protein. Protein-length intent uses the same selection.
Negative-frame/six-frame search, alternate codes, ORF discovery and trailing
partial codons remain outside this model. Frame absence preserves frame1.

I has138 scanned theorems without oracles. Shipped/fresh panels remain179/179;
195 authored policy checks pass, with180 right,0 wrong,0 false yes and15
withheld-valid capability cases. See project/lanes/I-life.md and the immutable
var/life/i-delivery/ready.json packet, based on H ancestry.
