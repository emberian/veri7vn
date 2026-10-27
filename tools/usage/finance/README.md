# Finance calculations with explicit quantity roles

This caller helps an agent turn a hypothetical budget, invoice, interest,
discount, tax, margin, markup or break-even calculation into an exact arithmetic
request. It does not interpret natural language or supply financial advice.

The ordinary-wording experiment completed none of 15 tasks. The same 13 tasks
with unambiguous numeric answers all worked through explicit arithmetic. The
caller is a workflow workaround, not a repair to Oracle7's natural-language
router. The two boundary tasks remain outside this caller's supported fragment.
No shipped specialist panels were run.

Try the included task pack from the repository root, using fresh output paths:

```sh
.venv/bin/python -B tools/usage/finance/prepare.py \
  tools/usage/finance/tasks.json --out var/usage-20261026/finance/my-prepared
.venv/bin/python -B tools/usage/run_batch.py \
  --cases var/usage-20261026/finance/my-prepared/cases.json \
  --out var/usage-20261026/finance/my-run
.venv/bin/python -B tools/usage/finance/audit.py \
  var/usage-20261026/finance/my-prepared/contracts.json \
  var/usage-20261026/finance/my-run/results.jsonl
```

Each task has an `id`, a `kind`, and exactly the fields shown in `tasks.json`.
Numbers are decimal strings. Tax requires an explicit `amount_role` of `pretax`
or `tax_inclusive`. Simple interest requires an annual rate, time unit, duration
and target (`interest` or `balance`). Compound interest requires explicit annual
compounding and a whole number of years. Margin divides by selling price; markup
divides by cost. Invoice subtotals exclude tax. Discount tasks apply tax after the
discount. Inputs assume one currency and no omitted costs, fees or cash flows.
The caller applies no rounding. A fractional break-even result is exact units,
not the next whole-unit sales target. Zero or negative contribution requires
separate analysis and is rejected rather than divided by zero.

`cases.json` contains only requests for the shared runner. `contracts.json`
separately retains input roles, expression, assumptions, output unit and a local
rational expectation. The latter is **not an Oracle answer**. The audit prints
the full Oracle reply and links it to the raw runner file by path and SHA-256.
It compares only answered computations with a recognizable final-number
sentence, and checks that the echoed question matches the contract. A withheld
reply stays unanswered even if its provenance contains a numeric computation.
Agreement means the Oracle arithmetic agrees with this untrusted caller model;
it does not establish the model matches unstated business or tax requirements.

The original ordinary questions are `cases.json`, with independently calculated
Decimal expectations in `expectations.json`; `make_cases.py` regenerates them.
`tasks.json` restates the 13 numeric tasks with explicit roles. The invoice tax
follow-up is deliberately restated with its subtotal: automatic conversation
state repair is not claimed.

Run the narrow regression checks:

```sh
.venv/bin/python -B -m unittest discover -s tests/usage/finance -v
```
