# The anatomy and agriculture family

Five shipped Oracle7 specialists as one program: `anatomy`, `anatomy-r2` (stable human
anatomy counts, superlatives, which organ makes a substance), `agriculture-v2` (fertilizer grade,
seeding rate, bushels to kg/ha, acre-inches), `gardening` (bed volume, bags, plant grid,
fertilizer per area, water) and `nutrition-label-v2` (BMI and category, calories from
macronutrients, percent Daily Value, percent calories from fat).

The facts, formulas and decisions to decline are in Isabelle/HOL (`AnatomyAgri.thy`) with proofs.
All arithmetic is exact rational arithmetic; nothing needs a square root. Isabelle generates
Standard ML, and the MLton compiler inside Isabelle builds one binary that speaks the
[answerer contract](../../../docs/contracts/answerer.md). `--specialist ID` reads questions the way
that manifest's organ does; with none, the family is asked in a fixed order.

| Part | File | Status |
|---|---|---|
| Tables, requests, kernel, rounding, reply text | `AnatomyAgri.thy` | HOL, proved, exported |
| Export, self test, oracle check | `AnatomyAgri_Export.thy` | build fails on an oracle or a failed self test |
| Table transcription check | `tables_check.py` | Python check against the organ files, not a proof |
| Reading English | `../commons/commons.sml`, `recognizer.sml` | **untrusted**, hand port of the organs' regexes |
| JSON framing | `main.sml` | **untrusted** |

Build and run:
```sh
python3 tools/dev/remote-build persvati src/extract/anatomyagri Veri7vn_AnatomyAgri -d src/extract/commons --expect 'VERI7VN_ANATOMYAGRI PASS'
python3 src/extract/anatomyagri/tables_check.py
VERI7VN_GENERATED=/path/from/successful/receipt/anatomyagri.ML sh src/extract/anatomyagri/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/anatomyagri/score.py     # has an RSS guard
```
The binary is under `var/anatomyagri/bin/` and is not committed. Results and statements:
[lane handoff](../../../project/lanes/S10-anatomy-agri.md).

The numeric layout helpers (`digits`, `digit_lit`, `lit`, `strip_zeros`) and the
Regex/Json SML come from the shared `Veri7vn_Commons` session and
`src/extract/commons/commons.sml` (lane W5-12); the rounding here stays
nat-based and local.

## Rectangular planting grids

Different row and plant spacings use whole rectangular spacing cells, with no
plants on the border. If a nonsquare bed has unequal spacings, name the side
along which rows run; otherwise the answerer asks for that information. For
example, a 10 by 4 ft bed with 18 inches between rows and 9 inches between
plants holds 26 plants with rows along the 10 ft side, or 30 along the 4 ft side.
The proved fit bound relates the returned count to the physical bed area.

Anatomy handles inverted superlative questions and applies its table only in
the human domain. Source facts and English interpretation remain untrusted.
`capabilities.json` declares these limits for dispatch and packaging. Current
work and receipts are in [C-anatomyagri](../../../project/lanes/C-anatomyagri.md).

The current C candidate scores 156/156 shipped items in both specialist and
family dispatch, versus 154/156 for the re-evaluated shipped organs; all
wrong and false-yes counts are zero on these panels. Three fresh seeds each
score 156/156 and 23 targeted probes pass. See
[C-anatomyagri](../../../project/lanes/C-anatomyagri.md) for assumptions,
per-specialist numbers, the 54-theorem zero-oracle receipt and performance.

## Expected-stand seed planning

A whole-seed purchase now rounds upward to the smallest count whose expected
stand reaches the target. This does not guarantee how many seeds will actually
germinate. Rational seeding-rate questions retain their expected requirement.
Total and per-acre scope are explicit, and malformed or signed percentages
cannot be recovered as positive suffixes. Unsupported mixed area/total scopes
and hectare requests decline.

The E artifact passes 156/156 shipped items and three fresh panels. All 66
same-author policy checks pass; capability is 49 right and 17 valid requests
withheld, with no wrong answers or false yes. See
[the E report](../../../project/lanes/E-anatomyagri.md) for model statements,
compiler binding and the remaining limits.


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
