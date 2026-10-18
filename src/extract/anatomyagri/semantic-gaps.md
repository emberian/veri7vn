# Anatomy/agriculture semantic gap ledger

| Specialist | Supported capability and current repair | Remaining work and evidence |
|---|---|---|
| anatomy | Standard human facts, now with typed developmental applicability for count requests. Explicit unsupported skeletal/dentition stages decline. | Frozen C answers 206 adult bones for a newborn, and 206 for an adult human skull/hand/foot because a generic adult pattern shadows the named part. D also prioritizes a named anatomical structure over that general pattern. D implements policy-based narrowing, not a biological proof or universal infant count. Individual variation, mixed subject contexts and specialized cell types remain beyond the table. |
| anatomy-r2 | Same typed fact table and stage policy as anatomy. | Same newborn counterexample; both readers are probed together. |
| agriculture-v2 | Fertilizer grades, expected stand, crop test weights, acre-inch volumes. | E adds whole-seed minimum planning with sufficiency/minimality against expected stand, and exact signed germination/target roles. Hectare and mixed total/area scopes remain unsupported. Germination variability is explicitly outside the expected-stand guarantee. |
| gardening | Full rectangular spacing cells, row orientation, bulk soil volume. | Border planting, paths, staggered and curved layouts need different geometric models. A negative soil-depth exploratory question safely withheld; no claim of a reachable sign bug from that example. |
| nutrition-label-v2 | Label arithmetic, daily values and adult BMI categories. | Label rounding versus exact arithmetic, multiple servings, and nonadult/pregnancy model applicability need broader coverage. The exploratory negative-protein question safely withheld; typed negative quantities alone are not a demonstrated English bug. |

D focuses on the concrete newborn/juvenile applicability failure. It preserves stage-independent standard-table counts; that model does not assert that every individual has those counts. Same-author probes are additional coverage, not independent biological fact verification.

D verification: 58 scanned theorems, zero oracles; 156/156 shipped in both
dispatch modes; two development seeds and new untouched 10184009 each 156/156;
49/49 same-author probes. Frozen C is 31/49 (6 wrong, 12 false yes) and the organ is 16/49
(6 wrong, 13 false yes, 14 valid withheld). Exact compiler/proof binding and final
artifact hashes are in the lane report. These counts do not resolve the
remaining per-specialist semantic limits above.

## E seed-planning repair verified

Observed frozen-D inputs: target 101 plants at 80% germination invents per-acre
units and returns a fractional purchase; -80% is read as 80%; malformed 1.2.3%
is read as 2.3%. Negative target -101 already withholds. E binds full numeric
roles, carries total/per-acre scope, and proves a minimum integer seed count
against an expected stand. It keeps stochastic realization outside that claim.
Hectare conversion and mixed total/area calculations currently decline rather
than silently changing the target's units. The proof passed 62 theorems and zero oracles; native panels pass 156/156 in both modes and three fresh seeds, including untouched 10185011. All 66 policy assertions pass, but capability is 49 right, 0 wrong, 0 false yes and 17 withheld-valid; developmental requests outside the table are conservatively counted as unsupported, not solved. See the standalone E report for complete counts.


## F: supplied macronutrients and fertilizer dimensions

The general Atwater supplied-component sum preserves signed/fraction/scientific
amounts, declines negative/malformed/duplicate roles and accepts explicit zero.
Unlisted components are zero for this supplied-component sum, as shown in the
response. This is not a food-specific energy or label-rounding model.

Fertilizer requests bind one N-P2O5-K2O grade, one nutrient/product amount and
an explicit total or per-acre scope. Area multiplies a rate only when a total
is requested, or divides a total when a rate is requested. Amounts and total
area are nonnegative, division requires positive area and each grade column is
at most100 percent. Elemental P/K conversion and hectare/kg requests remain
unsupported. Negative and malformed values cannot be recovered from suffixes.

F passes156/156 shipped items in both dispatch modes, two development panels
and new untouched10188029 at156/156 each;99 authored policy assertions pass.
Capability is79right,0wrong,0false yes,20withheld-valid. The final67-theorem,
zero-oracle proof and immutable native binding are detailed in
project/lanes/F-anatomyagri.md. Remaining anatomy, gardening and nutrition
limits in the existing per-ID ledger still apply.


## G: nutrition scalar roles and applicability

Nutrition now binds complete signed/fraction/scientific quantities for fat
energy share, Daily Value amount, BMI mass and height. Duplicate/malformed roles
decline. Fat-calorie share uses an unrounded9kcal/g model with positive total
energy and fat energy between zero and total. Daily Value percentages use the
fixed reference table and may exceed100%. BMI requires positive mass/height;
mixed metric/imperial quantities convert exactly, while wholly imperial BMI
retains the traditional703 coefficient. Explicit ages under20 or child/teen
contexts decline because the response includes an adult category, not age/sex
percentiles. Unknown age retains the explicitly described adult model.

This does not implement serving multiplication, label-rounding tolerance,
food-specific calorie factors, pediatric BMI or individualized intake advice.
Other per-ID limits above remain open. G passes156/156 shipped in both modes,
two development panels and untouched10189041. All129 authored policy checks
pass; capability is108right,0wrong,0false yes,21withheld-valid. The proof scans72
theorems with zero oracles; see project/lanes/G-anatomyagri.md.


## H: calorie reference portions

The observed G error is concrete: a label with 10 g protein, 20 g carbohydrate
and 5 g fat per 100 g returned 165 kcal when asked about a 250 g portion.
The supplied-component general Atwater model requires 412.5 kcal.

H carries reference and requested portions into the kernel as grams or serving
counts. Kilograms and milligrams convert exactly to grams in the reader.
Serving counts and mass convert only with a stated positive mass per serving.
Reference quantity must be positive; requested quantity and all supplied macro
amounts must be nonnegative. Zero requested quantity returns zero energy.
Duplicate, malformed or conflicting roles decline; an explicit unsupported
reference cannot silently fall back to the unscaled nutrient sum.

This is a linear, homogeneous-portion model, using general 4/4/9/7 kcal per gram
factors for the supplied protein/carbohydrate/fat/alcohol amounts. Omitted
components contribute zero. Food-specific factors, label-rounding intervals,
fiber/polyol treatment, volume portions and mixture heterogeneity remain open.
A milliliter reference and milliliter target are mathematically sufficient for
same-unit scaling, but that valid capability remains withheld in this packet.
The anatomy/anatomy-r2 stage coverage, agriculture expected-stand limits and
gardening layout assumptions above are unchanged. See project/lanes/H-anatomyagri.md
for final proof, panel and consumer evidence.

H verification: 77 theorems, zero oracles; shipped 156/156 in both dispatch
modes; two development seeds and untouched 10192063 each 156/156. All 158
policy assertions pass; capability is 136 right, zero wrong/false yes and
22 withheld-valid. Frozen G on the same questions is 112 right, 9 wrong,
10 false yes and 27 withheld-valid. The finite drain ends with this packet.
