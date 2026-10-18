# The life-science family, end to end

This folder carries six shipped Oracle7 specialists as one program: `genetics-v2`,
`biology`, `ecology`, `forestry`, `wildlife` and `microbiology-v2`
(`upstream/root/specialists/<id>/organ_*.py`). They share no unit system, so each has its own
small HOL kernel, but they share one numeric layer, one reply type and one binary.

- The decisions to answer or decline, and every value, are written in Isabelle/HOL with proofs.
- Isabelle turns the kernels into Standard ML; the MLton compiler inside Isabelle turns that and
  the hand-written recognizer into one standalone binary, `var/life/bin/life`. No Isabelle process
  runs when questions are answered.
- The binary speaks the [answerer contract](../../../docs/contracts/answerer.md). With
  `--specialist ID` it reads questions the way that one manifest's organ does; without it, it asks
  all six in a fixed order.

## What is proved and what is trusted

| Part | File | Status |
|---|---|---|
| Rounding to four significant digits, interval enclosure, decimal layout | `base/Life_Num.thy` | copied from lane G, proved |
| Outcomes, declines, reply text type | `Life_Core.thy` | HOL, proved |
| Punnett squares, Hardy-Weinberg | `Genetics.thy` | HOL, proved; exact except the square roots |
| Genetic code, complement, transcription, translation, GC content | `Biology.thy` | HOL, proved; code table checked by `tables_check.py` |
| Diversity indices, growth | `Ecology.thy` | Simpson and logistic rate exact; Shannon, evenness, exponentials enclosed |
| Basal area, Doyle, Smalian, trees per acre, clinometer height | `Forestry.thy` | exact except pi and tan (enclosed) |
| Mark-recapture, density, survival | `Wildlife.thy` | exact rationals |
| Growth, generations, plate counts, dilutions | `Micro.thy` | exact; a real power of two or logarithm is enclosed |
| Export, self test, oracle check | `Life_Export.thy` | the build fails if any listed theorem uses an oracle or the self test fails |
| Table transcription check | `tables_check.py` | a Python check of HOL text against the organ files, not a proof |
| Reading English | `../commons/commons.sml`, `recognizer.sml` | **untrusted**, hand-ported from the organs' regular expressions |
| JSON framing | `main.sml` | **untrusted** |

Enclosed values are rounded to four significant digits from a verified interval (40-bit precision, or 64 bits for Shannon diversity and evenness); each theorem bounds the error at one part in a thousand plus 1e-9. Genetics answers are
exact fractions (1/4, 3/4) with the percent alongside, as the organ prints them.

## Regenerating the recognizer

`recognizer.sml` is generated: `sh src/extract/life/gen/rebuild.sh` rebuilds it from
`gen/part{1,2,3}.sml` with `gen/conv.py` (which turns the bracketed regex text into SML string
literals). Edit the parts, not the generated file; `git diff` on it must be empty after a no-op regenerate.

## Build and run

```sh
python3 tools/dev/remote-build persvati src/extract/life Veri7vn_Life -d src/extract/commons \
  --expect 'VERI7VN_LIFE PASS'
python3 src/extract/life/tables_check.py
VERI7VN_GENERATED=/path/from/successful/receipt/life.ML sh src/extract/life/build.sh
echo '{"id": "1", "q": "Reverse complement of ATGCGT?", "session": "s"}' | var/life/bin/life
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/life/score.py     # organ cross-check, all six panels
```

## Current result

The current candidate scores 179/179 shipped items (previously 170/179),
with zero wrong answers or false yes on these panels. Three fresh seeds also
score 179/179 each. See [C-life](../../../project/lanes/C-life.md) for exact
receipts, per-specialist results and known semantic gaps outside the panels.

## Beyond the original phrasing

Genotype probabilities and phenotype ratios accept one through six distinct
independent loci. Explicit linkage, incomplete dominance, codominance and
epistasis are declined; a repeated locus is never treated as another independent
one. The declared assumptions are available in `capabilities.json`. They do
not prove that an actual biological cross satisfies the model.

The recognizer handles inverted cross descriptions, population qualifiers in
Hardy-Weinberg questions, plural DBH units and explicit survival-count roles.
The build checks all self-test vectors but does not export eager test constants
into the answerer. The expensive numeric reply paths reuse their result instead of recalculating intervals.

`beyond.py` reproduces fresh generator panels without writing to upstream;
`probe.py` runs the same-author model probes. See the current work and receipts
in [C-life](../../../project/lanes/C-life.md).

## Strand and measured-quantity repair

The current candidate normalizes explicit 3-prime/5-prime direction and
template/coding role before transcription or translation. It preserves the
standard-code, first-base convention and declines explicit incompatible
models. Independent genetic loci are matched by identity, so parents and
targets can use different locus orders without inventing duplicate loci.

CFU questions require an explicit plated volume. Count and volume are read
through the shared exact numeric lexer, including signs, fractions and
scientific notation; malformed and ambiguous inputs decline. The kernel
requires nonnegative colony count, dilution in (0,1], and positive volume.
The D receipt has 110 theorems and zero oracles; all 179 shipped items and
43 targeted probes pass. See [semantic gaps](semantic-gaps.md)
for the remaining limits beyond the shipped panels.

## Population and dilution roles

Ecology distinguishes a requested population from its growth rate, and an
initial rate from the derivative at a stated future time. Zero population is
an equilibrium. Population and forward time must be nonnegative; carrying
capacity must be positive. Explicit mismatched time units currently decline.
Complete dilution tokens retain their signs in colon, fraction, scientific and
power notation; a negative dilution is never recovered as a positive suffix.

The E artifact passes all 179 shipped items and three fresh panels. Its 80
same-author policy assertions pass, while capability counts are 73 right and
seven valid requests withheld, with no wrong answers or false yes. This
separation preserves visible model limits. The receipt scans 116 theorems with
zero oracles and binds the native compiler inputs to the successful proof.


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
