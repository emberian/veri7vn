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
