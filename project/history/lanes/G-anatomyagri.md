# Anatomy/agriculture G: nutrition roles and valid models

G repairs demonstrated unsigned suffix and fraction errors in percent-fat
calories, Daily Value and BMI. The frozen F binary returned 45% for negative 10 g
fat in 200 calories, read 1/2 g fat as 2 g, and read 1/2 g sodium as 2 g. It also turned
negative BMI mass/height into positive values. Exact complete role binding now
preserves these inputs and their physical domains.

The unrounded 9 kcal/g model now refuses 30 g fat within 200 total calories because
its own fat energy exceeds the total. Daily Value is a different ratio: 4.6 g
sodium remains a valid 200% of the fixed 2300 mg reference. Mixed-unit BMI inputs
convert explicitly; raw values and adult-category applicability are not
silently conflated. An explicit 18-year-old request declines this adult-category
response. Raw pediatric BMI is mathematically valid but remains withheld here.

## Results

The final official score is 156/156 shipped in both specialist/family modes;
zero wrong, false yes or withheld-valid. Development 10181001/10182003 and new
untouched 10189041 each score 156/156. All source-table comparisons pass. The
binary is 515048 bytes; median startup over five samples is 3.774 ms, with 176 ms on
the first recorded launch.

All 129 same-author policy assertions pass. Capability is 108 right,0 wrong,
0 false yes and 21 withheld-valid. Frozen F on the same 129 questions has 88 right,
6 wrong,12 false yes and 23 withheld-valid. The shipped organ has 32 right,24 wrong,
27 false yes,31 withheld-valid and 15 unassessed answers. Authored model probes are
not independent language coverage. The extra valid unsupported case is the
18-year-old BMI request: the system currently couples the scalar to an adult
category. Unsupported refusals are not credited as solved capabilities.

## What is proved and assumed

The final proof scans 72 theorems with zero oracles. Five newly scanned laws:

- A successful fat-calorie percentage has nonnegative fat amount, positive
  total energy, fat energy no greater than total, and output in [0,100].
  The existing conservation equation output×total=900×fat remains binding.
- Successful metric BMI values or categories imply strictly positive mass
  and metric height.
- Successful imperial BMI values or categories imply strictly positive weight
  and height in inches.
- Successful Daily Value percentage implies nonnegative supplied amount;
  the existing output×reference=100×converted-amount equation remains binding.
- The explicit adult-model exclusion request always declines as underspecified.

The whole-imperial 703 constant remains the declared rounded model; mixed-unit
inputs use exact SI conversion. BMI response categories are for ages 20+, as
stated by the [CDC adult calculator](https://www.cdc.gov/bmi/adult-calculator/index.html).
The fixed Daily Value ratio describes the supplied nutrient amount against a
labeling reference, consistent with the [FDA label explanation](https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label).
It is not individualized advice. Percent-fat guards assume unrounded general
Atwater energy; food-specific factors and label-rounding tolerance are not
implemented. Source tables, model applicability, English role assignment,
unit conversion and JSON framing remain untrusted.

The reader requires one compatible mass/height pair or one nutrient/amount.
Saturated fat is resolved specifically rather than being mistaken for a second
generic-fat request. Duplicate observations and malformed numeric runs decline.
All five specialist ledgers remain in semantic-gaps.md; anatomy stage coverage,
gardening layout assumptions, agriculture expectations and fertilizer oxide
conventions are not claimed newly solved by this nutrition packet.

## Artifact and consumers

Passed proof: `var/anatomyagri/g-next/checkout/var/anatomyagri/remote-attempts/20261018T093230Z-a55d7dc69b1f/receipt.json`.
Native binding: `var/anatomyagri/g-next/checkout/var/anatomyagri/native-attempts/20261018T093418Z-bae405f6d452/compile-inputs.json`.
Binary SHA: `219430108e47ce8087f3d28c25bc597568d6646cdc8b50b0d287cade5c0b0a6d`.
Shared numeric SHA: `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.
The shared native helper binds immutable copied compiler inputs and full theory
closure. The staged checkout is passed F source plus exact owned overlays; it
does not overwrite live E/F source. The first proof needed the existing Daily
Value theorem connected through kernel_value after adding its domain guard;
the final passed receipt includes that repair.

The specialist/family CLI consumes the new model guards and exact reader.
Eight actual shared Dispatcher controls are requested through the staged
sidecar in var/anatomyagri/g-next/runtime-probes.json; composition evidence is
tracked separately. Final receipts are probes-bound.json,
probes-f-baseline.json, shipped-bound.json and g-bound fresh-panel receipts.

Changed candidates relative to F are AnatomyAgri.thy, AnatomyAgri_Export.thy,
recognizer.sml, capabilities.json, probes.json, README.md and semantic-gaps.md,
plus this report. Exact F baseline/candidate hashes are in
var/anatomyagri/g-next/transfer.json, and immutable artifacts are in
var/anatomyagri/g-delivery/ready.json. Promotion remains a root integration gate.


Actual shared Dispatcher composition passed 8/8 final checks.
Receipt: `var/C-runtime-consumers/staged-G-anatomy-rendered-final.json`. Numeric checks
respect the documented rendered precision (Life four significant digits;
Anatomy two decimals) and separately assert decisive status, kind and unit text.
Initial strict absolute-tolerance diagnostics remain preserved.


Root released the E predecessor after integration/capture. The complete F→G
source chain is now promoted to the live family directory after checking every
predecessor and candidate hash. The common native-input verifier reports an
exact current proof/runtime source match for the retained G native and passed
proof receipt; no rebuild was needed for path promotion. Promotion evidence is
var/anatomyagri/g-delivery/promotion.json and current-inputs-check.json.
The final live named-file packet is var/anatomyagri/g-delivery/live-ready.json.

The first default-runtime gate exposed the old E executable still at the
canonical path after source promotion. Verified G generated code, manifest
and executable were then published atomically per file, with binary last.
The corrected default gate passes 3/3 (fractional fat, excessive fat energy
and adult-only BMI scope), recorded in
var/runtime-default/live-anatomy-final.json. The initial publication failure
is retained. The canonical binary is executable; build.sh retains its tracked
0644 mode and documented explicit-shell invocation.
