# Finish a calculation without losing what was asked

Oracle7 sometimes answers a valid intermediate calculation instead of the final
quantity. In the recorded battery question it returned 1.5 kWh used, while the
question asked for 3.5 kWh remaining. This caller workflow makes those two
quantities separate names and requires the subtraction explicitly.

The five example plans use actual atomic Oracle replies and then perform local
arithmetic. Their output clearly labels that arithmetic. These are workflow
workarounds, not repaired Oracle answers or verified programs.

| Plan | Oracle step | Local continuation | Result from retained replies |
| --- | --- | --- | --- |
| `battery-remaining.json` | Appliance energy used | Initial energy minus used energy | 3.5 kWh remaining |
| `solar-stored.json` | Solar energy before losses | Multiply by storage fraction | 1.6 kWh stored |
| `resistor-energy.json` | Resistor power | Multiply by duration | 15,000 J dissipated |
| `journey-total.json` | 150 / 60 | Assign hours, add parking minutes | 2.75 h total |
| `author-publication-gap.json` | Birth and publication dates | Subtract calendar years | 36 calendar years |

The publication plan explicitly names Walt Whitman, as established by the initial
Oracle author reply. It does not resolve author identity itself. A difference of
calendar years is not a person's attained age.

## Run a plan

From the repository root, generate requests, run them through the shared runner,
and inspect the retained replies through the plan:

```sh
.venv/bin/python -B tools/usage/composition/workflow.py \
  --plan tools/usage/composition/battery-remaining.json --cases \
  > var/usage-20261026/composition/battery-requests.json
.venv/bin/python -B tools/usage/run_batch.py \
  --cases var/usage-20261026/composition/battery-requests.json \
  --out var/usage-20261026/composition/battery-fresh
.venv/bin/python -B tools/usage/composition/workflow.py \
  --plan tools/usage/composition/battery-remaining.json \
  --results var/usage-20261026/composition/battery-fresh/results.jsonl
```

Use a new runner output directory each time. The existing experiment's results
can also be consumed directly with `--results
var/usage-20261026/composition/steps/results.jsonl`.

`--cases` produces only the three fields accepted by the shared runner. No
expected answer goes to Oracle. Initial questions and independently fixed
expectations are in separate files, as are the atomic follow-up requests and
expectations.

## What is checked

Each atomic recipe generates its exact question. A receipt must match that
question, request ID and conversation ID; the response must be complete and
answered. Narrow readers require an explicit expected quantity and unit, or a
relation statement naming the requested subject and property. Known numeric
routes are checked. Extra text, a different quantity, a partial answer, an
unrecognized route or a refusal stops the workflow for inspection.

Local steps name two existing quantities and an output. Names cannot be
reassigned. Addition and subtraction require matching dimensions; multiplication
and division check output dimensions. Unit conversions are explicit in the
unit table. No arbitrary expression evaluation or code execution is available.
Every Oracle step retains the entire supplied receipt, including failed steps.

The caller is responsible for choosing the plan, assigning input meanings and
checking assumptions. The code does not understand an arbitrary user question,
prove a specialist's formula, authenticate a receipt, or justify a physical
model. A dimension check cannot establish that a formula answers the question.
A caller can deliberately choose the wrong operands; this tool will not infer
the missing semantics. Recipe wording and response readers are intentionally
narrow, and a new valid response form may need review before it is accepted.

## Regression check

```sh
.venv/bin/python -B -m unittest discover -s tests/usage/composition -p 'test_*.py' -v
```

Eleven tests replay real atomic responses through all five plans and exercise
request mismatch, wrong quantity or unit, partial/refused answers, duplicate or
missing receipts, unit arithmetic and preservation of failed-step evidence.
These are usage regressions. No shipped specialist panels were run.

## Engine repair follow-up

The authorized private energy specialist repair is retained as
`energy_quantity_roles.patch`; `energy-repair-cases.json` contains the six real
remaining/stored/runtime failures for combined-appliance replay. It binds load,
rating, efficiency and usable capacity explicitly and computes remaining/newly
stored energy rather than returning consumption as the final answer.

`check_energy_panel.py --directory PATH` uses that folder's shipped v3 panel and
scorer without writing admission state. Original and repaired direct-specialist
results are 70/70 valid dev and 66/66 valid held-out, zero wrong/false yes, plus
four correct declines per split. These are published-panel replays, not a fresh
six-criterion admission. The lane report records exact hashes and admission
limitations. The complete scoped test suite now has 24 passing tests.
