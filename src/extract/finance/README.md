# The finance family

Five specialists (`finance`, `finance-v2`, `finance-v2-r2`, `economics`, `retail`)
share a checked HOL arithmetic kernel and an untrusted English reader.

The kernel computes exact rational loan, savings, recurring-deposit, simple-
interest, economics and retail models. Whole-period compound balance and
interest round exact fractions to cents; continuous/fractional growth uses
certified approximation bounds. Requested interest, total balance, retail
savings, tax and final price have distinct typed meanings. The default real
rate uses the exact purchasing-power relation; explicit approximate requests
retain nominal minus inflation.

The reader consumes complete signed decimal/scientific/fraction tokens through
shared `ExactNumeric`. Model domains and refusal decisions are checked by the
kernel. English interpretation and real-world applicability remain untrusted.
Unrecognized or conflicting finance targets produce a terminal unsupported-model
reply. Retail physical inputs are nonnegative; zero values remain valid where
the formula permits them. With no fixed costs, zero units already break even.
Recurring-deposit timing and initial balances are still bounded; the next
cashflow extension is described in the semantic ledger.

Build the scoped proof with the managed driver, including Commons:

```
python3 tools/dev/remote-build persvati src/extract/finance Veri7vn_Finance -d src/extract/commons --expect 'VERI7VN_FINANCE PASS'
```

Set `VERI7VN_GENERATED` to that passed attempt's `finance.ML` export and run
`sh src/extract/finance/build.sh`. The common native helper verifies the proof
closure and freezes actual compiler inputs before publishing the binary.

Run `tables_check.py`, `score.py`, `d_probes.py`, and the scoped parity harness
for the relevant consumer. The unchanged shipped score is 553/559: six exact
real-rate answers disagree with approximation expectations. The report preserves
those measured labels and explains the model distinction; no scorer was edited.

Current statements, probes, measured limits and artifact bindings:
`project/lanes/D-finance.md`. Historical C and B reports retain earlier results.


Cashflow extension: an opening balance plus equal monthly deposits can request
either the ending balance or interest after subtracting every contribution.
Deposits occur at the specified start or end of the month (default end). The
term must contain a nonnegative whole number of months, amounts are nonnegative,
and the nominal annual rate gives a positive monthly growth factor. A separate
monthly recurrence agrees with the executable closed form; zero months returns
the opening balance and zero earned interest. Tax, fees, withdrawals, effective
annual yield, and mixed schedules remain unsupported. Explicit loan targets
select monthly payment or total interest; breakdowns/multiple targets refuse.

Inventory periods retain hour/day/week/365-day-year tags until the checked kernel converts them. Days of inventory uses the observed cost period, and reorder points align demand and lead-time units. Calendar months and business-day schedules are not assigned a guessed duration.
