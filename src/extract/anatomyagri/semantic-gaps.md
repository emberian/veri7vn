# Anatomy/agriculture semantic gap ledger

| Specialist | Supported capability and current repair | Remaining work and evidence |
|---|---|---|
| anatomy | Standard human facts, now with typed developmental applicability for count requests. Explicit unsupported skeletal/dentition stages decline. | Frozen C answers 206 adult bones for a newborn, and 206 for an adult human skull/hand/foot because a generic adult pattern shadows the named part. D also prioritizes a named anatomical structure over that general pattern. D implements policy-based narrowing, not a biological proof or universal infant count. Individual variation, mixed subject contexts and specialized cell types remain beyond the table. |
| anatomy-r2 | Same typed fact table and stage policy as anatomy. | Same newborn counterexample; both readers are probed together. |
| agriculture-v2 | Fertilizer grades, expected stand, crop test weights, acre-inch volumes. | Expected stand inversion returns a rational expectation rather than a minimum integer seed purchase; germination variability and model choice should be explicit. Source-level signed physical inputs need a reachability audit. |
| gardening | Full rectangular spacing cells, row orientation, bulk soil volume. | Border planting, paths, staggered and curved layouts need different geometric models. A negative soil-depth exploratory question safely withheld; no claim of a reachable sign bug from that example. |
| nutrition-label-v2 | Label arithmetic, daily values and adult BMI categories. | Label rounding versus exact arithmetic, multiple servings, and nonadult/pregnancy model applicability need broader coverage. The exploratory negative-protein question safely withheld; typed negative quantities alone are not a demonstrated English bug. |

D focuses on the concrete newborn/juvenile applicability failure. It preserves stage-independent standard-table counts; that model does not assert that every individual has those counts. Same-author probes are additional coverage, not independent biological fact verification.

D verification: 58 scanned theorems, zero oracles; 156/156 shipped in both
dispatch modes; two development seeds and new untouched 10184009 each 156/156;
49/49 same-author probes. Frozen C is 31/49 (6 wrong, 12 false yes) and the organ is 16/49
(6 wrong, 13 false yes, 14 valid withheld). Exact compiler/proof binding and final
artifact hashes are in the lane report. These counts do not resolve the
remaining per-specialist semantic limits above.
