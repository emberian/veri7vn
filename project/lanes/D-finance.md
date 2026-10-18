# Finance: requested quantities and exact numeric roles

Status: final checked kernel and immutable native are ready for integration.
The 75 scanned statements use zero oracles. The final binary passes all 101
authored policy assertions: 88 correct supported/domain-refusal cases and 13
valid unsupported requests withheld, with zero wrong answers or false yes.
It preserves all 31 C probes and all 26 pilot probes.
The unchanged shipped scorers report **553/559**, with six exact real-rate
answers disagreeing with their expected subtraction approximation. Their wrong
labels are preserved below; no scorer was changed. The other 553 items pass in
both specialist and family modes, with zero false yes and zero valid withheld.

## What changed

A compound-interest request now returns interest rather than final balance.
The target reader handles direct requests, passive “compound interest is earned”
wording, amount-of-interest phrases, contractions and possessives, dollar-amount
questions, and a short follow-up target. It explicitly classifies interest,
balance, or unknown/conflicting intent; an unrecognized request never silently
selects balance. Unsupported breakdowns, rate targets and requests for both
interest and balance produce a typed terminal unsupported-model reply. A checked
refusal equivalence binds that constructor to its outcome; source-side terminal
acceptance keeps the consumer from reinterpreting it. These useful unsupported
requests remain capability misses, even when their refusal-policy checks pass. The same classification governs simple interest
and recurring deposits. These finite English rules remain untrusted. A balance
question that merely mentions earned interest remains a balance request.
The requested interest is computed before cents rounding, including for a
sub-cent initial amount. Continuous and fractional-period compound interest
use certified approximation bounds around balance minus principal. A simple-
interest total request returns principal plus interest. All three finance IDs
share these typed targets; the capability overlay admits their new kinds.

Monthly loans and savings goals now require a whole positive number of months
exactly equal to 12 times the supplied years. Nonnegative principals/goals and
positive monthly growth factors are required. A 0.1-year term no longer silently
becomes one payment. Lump-sum growth and simple-interest models also check their
declared nonnegative principal/time and growth domains.

The default real rate is the exact purchasing-power rate. Explicit approximate
requests still select nominal minus inflation. Inflation cannot be -100% or
less, and nominal rate cannot be below -100% in the exact factor model.

Retail percentages now bind by occurrence identity to discount or tax roles.
Every percentage must be claimed exactly once; overlapping regex matches for
the same role are deduplicated, conflicting roles are refused, and exactly one
tax rate is required. Ordinary discounted/reduced-by wording and separate
discount/tax sentences are supported. Standalone tax cannot consume an
unclaimed first percentage. This repairs the relocated package counterexample
that returned100 for an80 item discounted25% then taxed8%, instead of64.80.
Explicit tax-base claims are also bound: only declared original/discounted
price bases are accepted; an unspecified shipping-cost base is refused.
Multiple discount mentions also require explicit stage succession. A repeated
description such as25%discount meaning25%off is withheld rather than applied
twice. Explicit stacked/successive stages remain supported, including equal
percentages. This is conservative stage interpretation, not a proof of English.
The new30-question fixture passes60/60 policy checks in retail/family modes:
36 correct answers and24 valid unsupported withholds. The c937 baseline had
14 right,8 wrong,22 valid withheld and16 answered without a scalar reference;
only16/60 policy assertions passed.

All economics quantity roles now resolve complete tokens from the shared
`ExactNumeric.mask` table. Calendar roles require exact integer years in the
existing 1900–2099 range. Finance money/rate/time/deposit roles and retail roles
also use the shared lexer. Signs, leading dots, scientific notation and rational
fractions survive; malformed tails and unissued placeholder names are not numeric
inputs. Recognition, quantity-role binding, and JSON remain untrusted.

Preserving signs exposed missing economics domains. The kernel now rejects
negative gross output, negative unemployed/participating counts, and nonpositive
CPI indices. CPI conversion retains signed money, so a debt may be adjusted.
Retail recognition also binds savings, price, markup and margin to the requested
quantity; explicitly excluded quantity names do not select the target.

## What the checked statements say

- A returned compound-interest fraction has positive denominator and equals
  principal times the growth factor minus principal. Whole-period cents round
  this interest fraction itself; approximation intervals enclose the same
  quantity for continuous/fractional periods.
- Successful monthly loan/savings requests contain a whole positive monthly
  schedule exactly equal to 12 times the years. The existing amortization and
  savings recurrence laws retain their explicit nonnegative-rate premise;
  negative rates with positive monthly factors are accepted algebraically but
  those two recurrence statements have not yet been generalized to them.
- An accepted exact real rate satisfies
  `(1 + real/100) * (1 + inflation/100) = 1 + nominal/100`.
- Every accepted unemployment or participation rate lies in [0,100], without
  requiring an additional caller premise that its numerator is nonnegative.
- Accepted real GDP has nonnegative nominal output, positive deflator and a
  nonnegative result. Accepted inflation has two positive indices and satisfies
  `(1 + rate/100) * old_index = new_index`.

New physical-domain laws state that an accepted reorder point is nonnegative
and equals demand times lead time plus safety stock; an accepted price from a
markup is nonnegative; and accepted inventory turnover is nonnegative and
multiplied by average inventory gives cost of goods sold. Negative demands,
costs, lead times, safety stocks, COGS and elasticity levels are rejected.
Zero values remain valid wherever their model and divisor permit them.

The break-even model requires nonnegative fixed/variable costs and price. Zero
fixed costs now return zero units even when unit margin is zero or negative.
The accepted solution is nonnegative and satisfies
`units * (price - variable_cost) = fixed_cost`; either fixed cost is zero or unit
margin is positive. The no-value answer requires positive fixed costs and
nonpositive unit margin. These are continuous quantities; the displayed whole
unit threshold is a separate rounding of the continuous solution.

The generic kernel exact/cents/approximation statements bind these results to
actual requests and answers. The existing retail product checker still supplies
a per-answer typed packet; the new operations do not claim per-answer proof
objects. Proofs concern the stated mathematical models, not English accuracy or
financial suitability.

## Specialist review and remaining work

| Specialist | Concrete semantic finding | Intended model repair |
|---|---|---|
| finance | Asking interest on $1000, 5%, two annual periods returns value 1102.50 although interest is 102.50. Beginning-month deposits are refused. | Make requested quantity typed, round interest itself; later support explicit deposit timing. |
| finance-v2 | A 0.1-year loan silently becomes one monthly payment. Compound-interest target also returns total. | Require exact whole monthly schedules; share target semantics across all variants. |
| finance-v2-r2 | Starting balance plus monthly deposits is refused. | General periodic cashflow model with initial balance and timing, after correcting accepted wrong answers. |
| economics | Unqualified real interest defaults to i-minus-inflation, while the exact Fisher rate is only shown in prose. | Exact purchasing-power factor by default; approximation only when explicitly requested. Preserve signed inflation. |
| retail | Savings/markup target confusion; negative demand, cost and COGS accepted; zero fixed costs described as never break-even when unit margin is nonpositive. | Bind target and denominator; nonnegative physical inputs with zero allowed where meaningful; exact zero-fixed-cost solution. |

These are examined behaviors and declared limits, not a claim of arbitrary
financial-language coverage. Explicit list wording such as “receives two
successive discounts of25% and25%” and “receives stacked discounts of25% and10%”
currently yields a typed refusal; these two useful requests are valid capability
misses, while the off-then-off form is supported. The annuity reader retains the earlier explicit
frequency/timing/existing-balance exclusions. A request for recurring-deposit
interest alone now withholds instead of returning total balance; this valid
capability remains unfinished. The next cashflow model is already staged with
an initial balance, beginning/end deposit timing, and separate balance/interest
targets. Its independent monthly recurrence and contribution-decomposition
statements are in `var/finance/d-cashflow/Finance_Cashflow.thy`, not yet checked
or connected. Sixty-four exact independent recurrence probes are currently valid
withheld cases on the pre-cashflow candidate. Other retail/elasticity models still need wider physical
and applicability review beyond this packet.

## Measured results

| Evidence | Frozen C | Final D |
|---|---:|---:|
| Shipped, both dispatch modes | 559/559 | 553/559; six approximation-model disagreements |
| New authored semantic probes | 38 right, 26 wrong, 15 false yes, 10 valid withheld, 12 answered without scalar reference | 88 right, 13 valid withheld; 101/101 policy |
| C authored boundary probes | 31/31 | 31/31 |
| Earlier pilot probes | 26/26 | 26/26 |
| Untouched numeric samples, seeds 190071–190076 | 467/467 | 461/467; six approximation-model disagreements |

The finance/economics untouched samples were generated after selecting c937,
before the final retail-only role repair. Those branches are unchanged. A new
retail arithmetic sample, seed191103, was generated after selecting finala5f10;
all24 independently computed Fraction expectations pass.
They retain the original generators' phrasing and are independent numeric
samples, not independent language evaluation. Retail has no numeric generator.
The official parity harness reports economics `WOULD FAIL`/`NEGATIVE` because
of those six measured differences; other scoped labels remain `INCOMPLETE`
because full-head/domain/lane/self comparisons were not measured.

The six shipped differences are explicit:

| Shipped question | Shipped expected percent | Exact model percent |
|---|---:|---:|
| The nominal interest rate is 4% and inflation is 1%. What is the real interest rate? | 3 | 300/101 ≈ 2.97029703 |
| The nominal interest rate is 3% and inflation is 4%. What is the real interest rate? | -1 | -25/26 ≈ -0.961538462 |
| The nominal interest rate is 8% and inflation is 6%. What is the real interest rate? | 2 | 100/53 ≈ 1.88679245 |
| With 1% inflation and a 4% nominal rate, what is the real rate? | 3 | 300/101 ≈ 2.97029703 |
| With 4% inflation and a 3% nominal rate, what is the real rate? | -1 | -25/26 ≈ -0.961538462 |
| With 6% inflation and a 8% nominal rate, what is the real rate? | 2 | 100/53 ≈ 1.88679245 |

The prior c937 native passed10 composed controls and five arithmetic-packet
mutation tests, then failed the package's independent discount-wording probe.
Its immutable capture remains historical and unpromoted. Finala5f10 source and native are frozen. Actual replacement Dispatcher
composition passes24/24 owner controls and25/25 independent runtime controls,
including the clarified discount refusal and explicit successive equal discounts.
Five mutations of an actual retail packet are rejected in both checks. Receipts:
`var/finance/d-semantics/composed-final10.json` and
`var/C-runtime-consumers/finance-stage-accepted.json`.
Replacement immutable capture is complete:
`var/C-runtime-package/bound-prepared/20261018T093013Z-1fb15837953b/finance`.
Final Linux replies match Darwin on all559 shipped questions, with the same
553/559 official score and zero false yes. Six relocated native checks and
three extracted-boundary checks on each platform pass. The candidate21-family,
144-specialist archives are under `var/C-runtime-package/candidate-both-a5f10/`;
source integration and final selection remain root-owned.
All earlier candidate captures remain historical evidence, not final selection.
The table/source compatibility check passes all 25 checks.

Final native size: 806,536 bytes. Five cold launches were 3.87, 3.66, 3.55, 3.73, 3.99 ms; median 3.73 ms. Specialist median round trips range from 0.128 to 0.937 ms, below their50ms budgets.

## Frozen artifacts

- Proof: `var/finance/remote-attempts/20261018T084610Z-afee50aab8d4/receipt.json`;
  actual Finished, exit 0, durable assertion `VERI7VN_FINANCE PASS theorems=75 oracles=0`.
- Export SHA256: `8c1cb7ad43dc1c920d1e73b5324b0679d176c5b37c9f4b05c61798ef18c9a8e6`.
- Native SHA256: `a5f10a53ffb98c3d2aa2b24628a01b16e6bdb79284c76fc597f172f296d641c9`.
- Compiler manifest: `var/finance/native-attempts/20261018T093013Z-1fb15837953b/compile-inputs.json`.
- Shared numeric SHA256: `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.

The common native helper validates the current proof closure and exact generated
export, freezes every consumed application input, compiles only that snapshot,
and records the final binary. The initial D build finished but lacked stored
assertion messages; its receipt remained rejected. A durable assertion export
fixed that gap. The final proof includes the physical-domain guards and zero-fixed-cost model.
The nonrecursive text renderer is now a plain case definition, eliminating
function-package processing; the final scoped build took 85 seconds versus
176 seconds for the preceding arithmetic snapshot. No failed receipt authorizes
this final binary.

Raw evaluations are under `var/finance/d-semantics/`: `shipped-final10.json`,
`probes-final10.json`, `probes-before101-classified.json`, `c-probes-final10.json`,
`pilot-probes-final10.json`, `untouched-final6/` and `untouched-before6/`.
Changed named files: `Finance.thy`, `Finance_Export.thy`, `recognizer.sml`,
`build.sh`, `capabilities.json`, `d_probes.py`, `README.md` under
`src/extract/finance/`, plus `role_probes.py` and this report. Root owns integration and commits.
