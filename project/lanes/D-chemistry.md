# Chemistry: complete quantities and formulas before reaction arithmetic

The next investigation covered all five specialist IDs directly. It found affirmative wrong answers in existing capabilities, so correcting those takes priority over adding reaction stoichiometry. The raw 25-case investigation is in `var/chemistry/stoich/gap-probes.json`; eight additional numeric/formula questions exposed leading-decimal, fraction, scientific-notation and nested-bracket failures. These are development diagnostics, not independent held-out panels. A second recorded diagnostic (`var/chemistry/stoich/quantity-role-gaps.json`) captures 18 affirmative replies from the pre-D binary to reaction, mixture, multiple-solution, and ambiguous combined-formula requests; it records that binary’s hash.

## Specialist gap ledger

| Exact specialist ID | Current shipped dev / held-out baseline | Observed defect or missing capability | Work and boundary |
|---|---:|---|---|
| chemistry | 225/225; 281/281 | `-18.015 g H2O` was read as positive 18.015 g; `.5 g` as 5 g; `1/2 g` as 2 g. `Ca[OH]2` was reduced to Ca. `H0` received a zero molar mass as though it described a molecule. | Shared exact numeric tokens, complete formula spans and matched bracket normalization implemented. Public typed-input nonnegativity/positive-mass proof checked. Reaction stoichiometry and kg-to-moles remain genuine missing capabilities. |
| chemistry-v3 | 225/225; 281/281 | Same numeral failures; `Ca[OH]2` became OH, and `K4[Fe(CN)6]` became K4. | Same repairs; complete nested formula is used, with no fragment recovery. Charged species remain unsupported and must not become neutral prefixes. |
| decay | 42/42; 42/42 | `after -10 days` became positive 10 days. Mixed-unit initial/final amounts and half-life inference from two observations safely withhold. Named-isotope requests missing a required amount/time were declined correctly by the binary but discarded by composition. | Signed elapsed values preserved; public typed guard checked. Isotope+remaining-intent context added so missing-input refusals survive composition. The mixed-unit/inverse problems remain open. |
| labsolutions | 28/28; 27/27 | Negative concentration/moles became positive; `.5 mol` became 5 mol; `1e3 mol` became 3 mol. | Measured quantity roles consume issued exact tokens. Public typed guard checked. Physically valid zero-concentration/zero-mole cases remain an extension gap in some newer kinds. |
| labsolutions-r2 | 28/28; 27/27 | Same numeric failures as labsolutions. Reversed dilution and zero final volume already decline. | Same repair, preserving existing boundary narrowing. No claim that correct declines are newly supported computations. |

The final D native binary scores all 1,206 shipped questions correctly, with zero wrong answers and zero false affirmatives. Exact per-specialist dev/held-out counts are in the table above and `var/chemistry/stoich/final-panels.json`. The final development challenge passes 138/138 directly (`var/chemistry/stoich/final-correctness.json`) and 138/138 through the scoped front dispatcher (`var/chemistry/stoich/final-composed.json`). These are policy-regression passes, not 138 newly correct computations. Retrospective expectation review separates 37 answered computations, 81 invalid/underspecified refusals, and 20 valid-but-unsupported withholds: **118 mathematically right / 0 wrong / 20 withheld-valid**. The charged-species mass question is valid but unsupported, as are the recorded reaction/mixture aggregation questions. The classification is recorded in `var/chemistry/stoich/d-expectation-review.json`; the original receipts are unchanged. These authored challenges are not an independent held-out benchmark.

The authored capability breakdown by exact ID is:

| Specialist | Right | Wrong | Withheld valid | Policy passes |
|---|---:|---:|---:|---:|
| chemistry | 25 | 0 | 5 | 30/30 |
| chemistry-v3 | 25 | 0 | 5 | 30/30 |
| decay | 24 | 0 | 0 | 24/24 |
| labsolutions | 22 | 0 | 5 | 27/27 |
| labsolutions-r2 | 22 | 0 | 5 | 27/27 |

## Shared numeric reader

`src/extract/commons/numeric.sml` is ordinary untrusted SML, with a deliberately small shared API. It returns exact reduced signed `IntInf` fractions and half-open byte spans. It accepts signed decimals, leading decimals, scientific notation, properly grouped commas and slash fractions. U+2212 is an explicit negative sign. It reports malformed numeric runs rather than scanning their tails. Digit count and exponent magnitude are bounded at 4,096 and 10,000 respectively.

`scan`/`at` let a consumer retain semantic structure such as sports records or innings. `mask` replaces complete numeric spans with issued markers and returns their exact values; a role recognizer must resolve every captured marker through that table. Issued markers are absent from the case-folded original text, so a user-supplied `QNUM0Q` cannot borrow another quantity's value after lowercasing. Numbers inside names, formula groups, and unit exponents are left alone. A single hyphen before a unit adjective (`10-second`) is a separator; malformed `10--second` and `10-3` are not quantities. A slash followed by an optional space and a letter belongs to the following unit/text (`3.19/gallon`), whose meaning remains the caller’s responsibility. Numeric denominators still parse as fractions, including all four spacing forms of `1/2`; zero, empty, and malformed numeric denominators are rejected.

The focused MLton test file `numeric_test.sml` passes 88 checks, including malformed tails, negative signs, scientific/fraction arithmetic, embedded formulas/units, marker collisions, and resource-limit boundaries. Its current source hash is `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`. Other families own their adoption and panel evidence; a lexer test pass alone is not evidence that a consumer assigned quantities to the right roles.

## Chemistry interpretation and typed domain

The chemistry reader now uses shared masks and binds markers to the existing quantity roles. It reads formula-shaped tokens whole. Square brackets are normalized only when bracket types/nesting match; malformed or charged formulas cannot fall through to an interior fragment. The original question remains available for isotope names containing a space before the isotope number. A one-species amount conversion must bind a single source amount and agree with all relevant formula tokens. This closes actual wrong answers that treated a reaction product request as the mass of its reactant, or answered a two-ingredient mixture from its first ingredient. Solution molarity likewise requires a single supplied mole or gram quantity, and each solution operation checks its own required count of volumes and concentrations. Multiple-solute or multiple-solution arithmetic is not claimed. Molar mass also requires one formula throughout the question. Every marker in the masked question must be issued, so an unknown marker cannot make one candidate disappear and select unrelated grams through fall-through.

The public HOL `reply_of` interface checks physical input domains before rendering a reply. Underlying arithmetic functions remain total algebraic maps. New checked statements are:

- `answered (reply_of r) ==> physical_request r`.
- `physical_request r ==> reply_of r = raw_reply r`.
- An invalid physical request is withheld with kind `impossible`.
- An answered grams-to-moles request has a nonnegative supplied mass.
- An answered solution mass request has nonnegative concentration and volume.
- An answered remaining-amount decay request has nonnegative elapsed time and starting amount.
- An answered molar-mass request has a successfully parsed formula whose mass total is positive.

The first scoped attempt reached the final positive-mass proof but needed the already-proved physical-domain premise supplied explicitly. The corrected hbox attempt `20261018T073224Z-1f8c1b34f2de` passed: **76 theorems, 0 oracles**, with the expected marker and published export. The source has seven new entries in the final oracle scan and executable checks for negative inputs and H0.

`stoich/check_correctness.py` provides the separate interpretation challenge, covering each specialist by exact ID. It includes numeric-format metamorphic cases, malformed/negative refusals, complete/mismatched/charged formulas, missing decay inputs and a safely unsupported reaction question. It contains 138 cases and passes 138/138 against the fresh checked export. The old C arithmetic answered 19 negative/zero-mass cases in the diagnostic; the checked D public interface now declines them. The challenge also checks all formerly observed first-ingredient and forged-marker errors.

## Composition

The decay sidecar adds an explicit conjunction: a known isotope name/alias and remaining/fraction/percentage/half-lives intent. This preserves genuine missing-input refusals; it does not replace the runtime owner's repair of control-character boundaries in the original manifest. Runtime replay confirms the three formerly dropped isotope missing-input refusals are now retained: `var/dispatch/acceptance-coverage/context-repaired/coverage.json`. The final D challenge also passes all 138 cases through `tools/dispatch/dispatch.py --order front --organs chemistry --specialist ID --no-reader --no-routes`, including negative typed-domain declines and valid exact-numeral answers.

## Next algorithm boundary

Reaction work remains isolated under `src/extract/chemistry/stoich/`. The intended kernel consumes explicit formula/coefficient lists, checks positive coefficients and element conservation using the proven parser, and computes exact limiting extent, leftovers and theoretical product amounts from stated reactant amounts. Its certificate would establish element balance and the arithmetic bottleneck, not that the reaction actually occurs. There is no canned molecule list and no claim of implemented reaction capability yet. Correcting the demonstrated interpretation defects comes first.

## Final compiler inputs

The managed native compiler captured the actual input files before compiling: `var/chemistry/native-attempts/20261018T074652Z-32df69d0d726/compile-inputs.json`. It binds the successful hbox proof receipt to the generated kernel and to the frozen shared numeric source. Binary SHA-256: `5c6cf8cef031a561a4823dc6e7a8082c34d784b2d1542db04e2a9db1412e3fde`; generated SML SHA-256: `4e25cc90cb71ae43260c5b693405694aea652d7a64b61af787c71cf86e54ffd3`. The build recipe now uses `tools/dev/native-compile`.
