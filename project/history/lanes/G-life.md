# Life G: forestry stand and length models

G fixes dropped tree classes, lost metric stand density, mixed eye-height
units and unsigned log-length suffixes. The frozen F counterexamples are
recorded before the implementation in var/life/g-next/counterexamples.json.
Two classes of 50 trees/acre at 10 in and 20 in now sum to 136.35 sq ft/acre under the
stated imperial coefficient. A stand of 100 trees/acre at 20 cm gives pi m2/acre,
not the single-tree 0.03142 m2. A 10 m horizontal view at 45 degrees with 5 ft eye
height gives 11.524 m, rather than 15 m. Negative log length declines.

The official shipped score is 179/179 in both modes, with zero wrong, false yes
or withheld-valid. Development 10181001/10182003 and untouched 10189033 each
score 179/179. All 13 source-table checks pass. The binary is 802488 bytes;
median of five recorded process starts is 4.126 ms.

On 136 same-author model probes, all 136 policy assertions pass. Capability is
124 right,0 wrong,0 false yes,12 withheld-valid. Frozen F on the same questions has
105 right,9 wrong,6 false yes,15 withheld-valid and1 unassessed answer. The organ has
43 right,31 wrong,29 false yes,30 withheld-valid,2 errors and1 unassessed answer.
The extra valid limitation is arithmetic-mean-only exact stand area: the
second moment is missing, so no unique numerical reference is invented.

## Statements and assumptions

The final proof scans 128 theorems with zero oracles. New binding laws state:

- Successful imperial stand aggregation has nonnegative diameters/counts,
  nonnegative output, and output=0.005454×sum(diameter²×trees-per-acre).
- Combining two supplied class lists adds their model basal areas, for both
  metric and imperial units.
- A one-class stand agrees with the existing per-acre basal-area kernel,
  including physical-domain refusal.
- If q²×n equals the sum of diameter²×count, its basal-area formula agrees
  with the summed class formula. This is the quadratic-mean identity.
- Successful clinometer approximation requires positive horizontal distance,
  an angle strictly between 0 and 90 degrees and nonnegative supplied eye height.

Existing successful log/area statements now include nonnegative dimensions;
the shared interval law also covers metric stand area. Imperial basal area
retains the rounded coefficient 0.005454; metric area uses pi. The reader binds
diameter classes in explicit count-before-diameter order and declines unmatched
multiple observations. A single representative stand diameter is interpreted
as uniform diameter or quadratic mean diameter. Explicit arithmetic mean alone
cannot establish exact area. This distinction follows the USDA Forest Service
quadratic-mean definition:
https://www.fs.usda.gov/Internet/FSE_DOCUMENTS/fseprd1178202.pdf

Class coverage, disjointness, physical observations, English recognition and
unit-role assignment are external premises. This does not establish species,
bark or taper effects, sloping-ground clinometry, plot sampling, arbitrary
mixed-unit log role order or allometry. The existing family-wide ledger remains
open. New valid limitations count as withheld capability rather than solved
policy refusals.

## Exact artifact and consumers

Proof: `var/life/g-next/checkout/var/life/remote-attempts/20261018T092539Z-b9770fa71b7b/receipt.json`.
Native binding: `var/life/g-next/checkout/var/life/native-attempts/20261018T092857Z-bc7d9f42d1c8/compile-inputs.json`.
Binary SHA: `d4e5df4401906f6dc7917651055dc7b3b8ed48da3ec39a8b133497b5baba9984`.
Shared numeric SHA: `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.
The shared native helper compiled immutable copied inputs and verified the
full proof closure. The staged checkout records passed F base plus exact owned
overlays; canonical live E/F files were not overwritten. The first staged
proof needed an explicit application of stand nonnegativity; the later passed
receipt supersedes it.

The specialist/family CLI consumes the new weighted classes and typed units.
The sidecar declares ba_per_acre_m2 and forestry domain refusals for the shared
runtime consumer. Six actual composed controls are requested in
var/life/g-next/runtime-probes.json; their result is tracked separately.

Changed candidates relative to F are Forestry.thy, Life_Core.thy,
Life_Export.thy, gen/part2.sml, generated recognizer.sml, capabilities.json,
probes.json, README.md and semantic-gaps.md, plus this report. Transfer baselines
are F candidate hashes, not a claim that F is already canonical. Exact mapping
is var/life/g-next/transfer.json; immutable packet is
var/life/g-delivery/ready.json. Final evaluations are probes-bound.json,
probes-f-baseline.json, shipped-bound.json and g-bound fresh-panel receipts.


Actual shared Dispatcher composition passed 6/6 final checks.
Receipt: `var/C-runtime-consumers/staged-G-life-rendered-final.json`. Numeric checks
respect the documented rendered precision (Life four significant digits;
Anatomy two decimals) and separately assert decisive status, kind and unit text.
Initial strict absolute-tolerance diagnostics remain preserved.
