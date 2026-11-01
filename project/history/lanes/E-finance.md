# Finance: opening balances, deposit timing, and earned interest

Status: promoted after root integrated D as `fb5c6ec`, validated against the
same successful proof and frozen for root integration. Current sources compile
to the identical checked staged E binary. E includes the final D retail repair;
earlier staged E binaries preceded that repair and remain historical. Selected
delivery changes still require root selection and exact immutable capture.

The model treats an opening balance and equal monthly deposits separately.
Deposits occur at the beginning or end of each monthly interest period. Output
is either the ending balance or interest after subtracting the opening balance
and every deposit. All three finance IDs use the same typed request. The reader
also selects monthly loan payment versus total loan interest explicitly;
“Calculate the interest paid ... with monthly payments” no longer selects one
payment. Bare target phrases, such as “Monthly payment on ...”, remain supported.
Unsupported breakdowns and conflicting targets stop with a typed refusal.

## Checked statements and boundary

The scoped proof scans 79 statements, zero oracles. Four new public statements
connect the implementation to separately defined monthly steps:

- The closed-form cashflow value equals the balance obtained by repeatedly
  multiplying the previous balance by `1+i` and adding the timing-adjusted deposit.
  At the start of a period, the deposit receives that period's growth.
- After subtracting growth of the opening balance, the start-period deposit
  contribution equals the end-period contribution multiplied by `1+i`.
- An accepted balance request has nonnegative opening balance, deposit and
  duration, a positive monthly growth factor, and an exact whole monthly count
  equal to twelve times the years. Its result equals the independent recurrence.
- For accepted interest, `interest + opening balance + months*deposit` equals
  that same recurrent ending balance. Interest is selected before rounding.

The recurrence equality holds algebraically for every rational rate. Public
requests impose positive monthly growth factors. The annual rate is nominal,
with monthly compounding; supplied APY/effective annual yield is not silently
substituted. Amounts and periods may be zero. Fees, withdrawals, mixed schedules,
and contradictory timing remain unsupported. Parsing, source roles, stated
units, target classification, and JSON are untrusted. The loan formulas and
nonnegative-rate amortization theorem are inherited; this packet changes their
requested-quantity binding, not their financial model.

## Actual evaluations

| Evidence | D a5f10 baseline | Final staged E |
|---|---:|---:|
| Shipped panels, both modes | 553/559 | 553/559 |
| 90 authored questions, each of four modes | 9 right, 1 wrong, 76 valid withheld, 4 answered without scalar reference | 79 right, 0 wrong, 11 valid withheld |
| Authored policy assertions | 24/360 | 360/360 |
| Fresh numeric monthly recurrences, seed191118 | not rerun | 32/32 |
| Actual staged Dispatcher | not rerun | 8/8 |

The 79 right cases per mode consist of 75 numeric answers and four invalid-domain
refusals. The 11 valid unsupported requests are capability misses even though
refusal-policy checks pass. The fixture covers opening/deposit zero and nonzero,
positive/zero/negative rates, zero/twelve periods, both timings, both cashflow
targets, loan targets, and conflicting/unsupported request boundaries. Fresh
samples were generated after selecting the final staged binary; their reference
is an independent Python Fraction loop, not the closed-form implementation.
The exact shipped scores retain the six Fisher-versus-subtraction discrepancies
from D. No scorer or acceptance cap was changed.

D's 101 policies and the final 60 retail-role policies were preserved by the
staged implementation; the final two bare loan-target additions restore the
32 shipped short-form items that an intermediate reader withheld. Intermediate
521/559 and 553/559 receipts remain distinct. No intermediate result is relabeled.

## Five-specialist frontier

| ID | Examined behavior and result | Remaining concrete scope |
|---|---|---|
| finance | Opening balance plus deposits now computes, with both timings. | Irregular cashflow dates and withdrawals are unsupported. |
| finance-v2 | Short monthly-payment and total-interest targets preserved; exact whole months required. | Loan amortization tables and breakdowns are unsupported. |
| finance-v2-r2 | Interest excludes every deposit; negative but positive-factor rates compute. | Effective annual yield conversion is not implemented. |
| economics | D's exact Fisher default and explicit approximation remain unchanged. | Wider price/quantity unit applicability remains bounded. |
| retail | Final D disjoint percentage, tax-base and stage binding is inherited. | Generic explicit discount lists remain valid withholds. Days-inventory ignores stated COGS periods: $700/week and $100 inventory returns52.14 days instead of1; $3000 over30 days and $1000 inventory returns121.7 instead of10. These are recorded next repairs, not fixed here. |

## Exact staged artifacts

- Checkout: `var/finance/d-cashflow/proof-inputs-20261018T085518Z`.
- Proof: its `var/finance/remote-attempts/20261018T092106Z-d18fb1f07cb7/receipt.json`;
  actual Finished, source stable, exit0, marker `theorems=79 oracles=0`.
- Export: `e0c12b3e1fca38ca64a29f6e77addafa74d468f551c6ef448b8e92abf391def0`.
- Final native: `4f0ca77ea98c207e198ec5ebb87a74209b14627a4f557e5f113a4790605aa4bf`.
- Compiler manifest: checkout's
  `var/finance/native-attempts/20261018T093903Z-efe5458a4392/compile-inputs.json`.
- Raw evaluations: `staged-shipped-final2.json`, `staged-90-final.json`,
  `d-baseline-90.json`, `fresh-final.json`, and `composed-final2.json` under
  `var/finance/d-cashflow/`.

The shared helper compiled frozen inputs under the common repository lock.
The failed first proof had an unterminated generated string literal; the corrected
snapshot passed without changing the mathematical statements. Source promotion and normal current-source native validation are complete;
package capture is the remaining delivery gate. Root owns integration. Seven candidate files are enumerated with
source paths, hashes and D predecessor hashes in `var/finance/d-cashflow/ready.json`.

## Live promotion after D integration

Root integrated D as `fb5c6ec`. The seven E target paths were promoted only after every predecessor and successor hash matched the staged ready manifest. The common helper compiled current live sources against the same successful staged proof receipt, producing the identical `4f0ca77ea98c207e198ec5ebb87a74209b14627a4f557e5f113a4790605aa4bf` binary. Current proof/runtime closure passed helper validation. The live compiler manifest is `var/finance/native-attempts/20261018T095640Z-a639f3ec56b8/compile-inputs.json`. All eight actual dispatcher checks pass again in `var/finance/d-cashflow/live-composed.json`; no duplicated proof or shipped suite was needed for the identical implementation. This E packet is now frozen pending root integration and immutable capture.
