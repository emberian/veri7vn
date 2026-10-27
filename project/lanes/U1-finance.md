# U1 finance usage: quantities need roles before arithmetic

No specialist panels were run. These are 15 ordinary task turns, a 13-prompt
arithmetic follow-up, and a 13-prompt run of the implemented caller. They do not
change the six-criterion scoreboard. No new theorem, verified kernel, or proof
claim was added.

## What actually happened

The immutable `var/appliance-20261026/candidate` was queried through the shared
private-workspace runner. Expectations were computed with Python Decimal and
saved **before** the first query. All inputs are hypothetical; no financial
advice or current tax rule is involved.

The ordinary questions completed **0/15 tasks**: 6 withheld, 9 clarification,
0 numeric answers and 0 wrong numeric answers. All 15 returned HTTP 200. Thirteen
questions supplied enough information for a unique numeric result; two asked a
boundary or left the interest convention unspecified. Neither boundary received
a useful explanation of its actual issue. Safe abstention is not task success.

| Task | Independently expected | Ordinary answer | Explicit caller |
|---|---:|---|---|
| Net monthly budget less four expenses | 1200 | Withheld definition of budget | 1200 |
| Invoice, 12 × 7.50 + 3 × 2 | 96 | Generic clarification | 96 |
| Same invoice, add 10% tax | 105.60 | Asked what “that” meant | 105.6, with subtotal explicitly supplied |
| 80 less 25%, no tax | 60 | Asked what “its” meant | 60 |
| 80 less 25%, then add 8% tax | 64.80 | Generic clarification | 64.8 |
| 108 already includes 8% tax; find pretax | 100 | Unparsed word problem | 100 |
| Simple interest, principal 1000, annual 6%, 2 years | 120 interest | “Outside the arithmetic I can carry out” | 120 |
| Same, 6 months | 30 interest | Same | 30 |
| Same, 2 years, final balance | 1120 balance | Same | 1120 |
| Annual compounding, 1000 at 6%, 2 years | 1123.60 balance | Same | 1123.6 |
| Sale 100, cost 80, margin on sale price | 20% | Generic clarification | 20 |
| Cost 80, sale 100, markup on cost | 25% | Generic clarification | 25 |
| Fixed cost 1000, price 30, variable cost 20 | 100 units | Generic clarification | 100 |
| Positive fixed cost, price equals variable cost | No finite break-even | Generic clarification | Explicitly rejected by caller; not claimed solved |
| 1000 at 6% for 2 years, unspecified conventions | Ask rate period and simple/compound, or condition answer | Generic clarification | Unsupported; not silently assigned a model |

The second run manually expressed the 13 numeric questions as arithmetic;
**13/13 answered correctly**. The third run used the new compiler's actual output;
**13/13 answered correctly**, all via `compute:verified`. This is an upstream path
label, not independently established formal authority. The audit found 13 exact
rational matches, no missing IDs, and preserved every complete Oracle reply.

Median per-request wall time was 0.170048 seconds in the ordinary run (range
0.101270–3.718123), 0.043329 in the manual arithmetic run, and 0.043757 in the
compiled run (range 0.004954–0.178196). Whole batches took 14.740, 6.274 and 12.748
seconds respectively, including startup and any slot wait; no speed claim is
made from these small warm-state samples.

## Diagnosis and useful change

No missing external facts are needed for these calculations. Finance and retail
source handlers exist in the candidate, but these ordinary requests never reach
them through `Oracle7.Engine.chat`. Observed paths are general explanation,
clarification and arithmetic guards. This is a routing/interface limitation,
not evidence that the underlying formula is absent. Whether another entry point
would use the specialists requires integration work beyond this lane.

The tax-inclusive question is a particularly useful regression: the returned
withheld provenance says `108 + 8 = 116`, with `verified: true`. The guard refused
to present that as an answer. A consumer that mines numbers or trusts the flag
without checking status and quantity roles could turn a safe refusal into a
wrong answer. The new audit refuses to do that.

`prepare.py` requires named quantity roles and emits a small arithmetic question,
plus a separate contract containing those roles, assumptions, expression and
local rational expectation. It distinguishes tax-inclusive totals from tax
bases, months from years, principal from interest/balance, and margin from
markup. It refuses unknown fields, missing roles, zero denominators and the
unsupported break-even boundary. The invoice follow-up requires the caller to
supply 96 explicitly; context recovery is not repaired.

The consumer is an agent preparing a hypothetical calculation and checking the
returned arithmetic. It can use the task schema instead of guessing a specialist
phrase. The caller is an **untrusted Python workflow** and its assumptions remain
the agent's responsibility. No candidate, upstream or shared source was edited.

## Changed files and exact checks

- `tools/usage/finance/make_cases.py`, `cases.json`, `expectations.json`: original
  tasks and independently calculated answers, including boundary expectations.
- `tools/usage/finance/tasks.json`, `prepare.py`: explicit role inputs and compiler.
- `tools/usage/finance/audit.py`: request-bound answer comparison that retains
  full replies and hashes the original runner evidence.
- `tools/usage/finance/README.md`: runnable workflow and limits.
- `tests/usage/finance/test_workflow.py`: 9 narrow checks, including all 13 original
  numeric expectations, tax role reversal, missing interest model/time/target,
  zero contribution, invalid values, refusal preservation and prompt mismatch.
- This report.

`.venv/bin/python -B -m unittest discover -s tests/usage/finance -v`:
**9 tests, 0 failures, 0 errors** (0.004 seconds).

Actual shared-runner receipts, complete response bytes and provenance are under
`var/usage-20261026/finance/run-1/`, `run-2/`, and `run-3/`, each with `cases.json`,
`results.jsonl`, `summary.json`, `adapter.log` and a private workspace. Original
manual rewrites are `var/usage-20261026/finance/explicit-cases.json`. Compiler
output is `var/usage-20261026/finance/prepared/`. The full checked comparison is
`var/usage-20261026/finance/audit-3.json`. Scratch outputs are not committed.

Runner metadata identifies source revision
`083e3a6c0e2cfc131e62bdc16cb4ec1346194635`, tip
`oracle_release_runtime_w436`, and deployment receipt hash
`5e2115181f1b6f0b3fb27894e8c9838f1cf526e5242021420283779dd220517b`.
The adapter explicitly does not verify deployment contents from this hash.

What remains: connect the plain task wording to the arithmetic/specialist route;
handle useful ambiguity and zero-contribution explanations; support explicit
rounding and whole-unit targets where required; evaluate on actual shipped
specialist panels before making scoreboard claims.
