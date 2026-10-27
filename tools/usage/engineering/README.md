# Engineering worksheets for Oracle7

The packaged engine often has the arithmetic needed for a physical calculation
but loses the requested quantity or a supplied condition while reading English.
This helper lets a caller select a physical model and assign each quantity a
name. It retains those inputs, validates their units, writes down the formula,
and generates an arithmetic question for Oracle7.

This is an **untrusted workflow workaround**, not an engine repair or a verified
physics solver. The caller must check the chosen model and quantity roles. A
`compute:verified` reply to generated arithmetic does not prove the model fits
the original situation. Local reference results are explicitly labeled as local;
they are never Oracle output.

## Try the retained examples

From the repository root:

```sh
.venv/bin/python -B tools/usage/engineering/worksheet.py \
  tools/usage/engineering/examples.json \
  --bundle var/usage-20261026/engineering/my-worksheets
.venv/bin/python -B tools/usage/run_batch.py \
  --cases var/usage-20261026/engineering/my-worksheets/cases.json \
  --out var/usage-20261026/engineering/my-answers
```

Both output directories must be new. Review `worksheets.json` before using the
answers: it contains the original structured request, model assumptions, formula,
normalized quantities, arithmetic question and separate exact local reference.
`cases.json` contains only the ID, conversation ID and question. The shared runner
keeps full replies, including refusals and evidence. Do not turn a refused
arithmetic question into a successful Oracle answer by substituting the local
reference.

For one request, save a JSON object like this, then run
`worksheet.py /absolute/path/to/request.json`:

```json
{
  "model": "spring_energy_change",
  "quantities": {
    "stiffness": {"value": 200, "unit": "N/m"},
    "initial_extension": {"value": "0.1", "unit": "m"},
    "final_extension": {"value": "0.3", "unit": "m"}
  }
}
```

The requested answer is the **additional** stored energy, 8 J, not the 9 J
stored at the final extension. The generated expression retains both extensions.
Decimal values must be quoted strings, preserving exact decimal arithmetic;
integers may be JSON integers. Booleans, NaN, expressions and binary floating
point inputs are rejected.

## Models and boundaries

| Model | Required quantity roles | Result |
| --- | --- | --- |
| `lift_input` | mass, rise, gravity, efficiency | electrical input energy in J |
| `pump_input` | density, flow, rise, gravity, efficiency | electrical input power in W |
| `spring_energy_change` | stiffness, initial_extension, final_extension | change in stored energy in J |
| `spring_force` | stiffness, unstretched_length, final_length | force magnitude in N |
| `sensible_heat` | mass, specific_heat, initial_temperature, final_temperature | signed heat in J |
| `battery_runtime` | capacity, load, efficiency, depth_of_discharge | runtime in hours |
| `flow_conversion` | flow | cubic metres per second |
| `temperature_interval` | change | temperature interval in Celsius degrees |

`battery_runtime` also accepts `inverter_rating`. It checks that load does not
exceed that rating; it never divides energy by the rating instead of the load.
All other extra roles are rejected. A request containing heater efficiency,
pipe friction or other unsupported conditions must not lose them to fit a model.
Choose another model or extend the helper explicitly.

The supported units are intentionally finite: kg/g, m/cm/mm, m/s^2, kg/m^3,
m^3/s or L/min, N/m, J/(kg K), K/C/F for absolute temperatures,
delta_K/delta_C/delta_F for intervals, W/kW, Wh/kWh, and 1/% for fractions.
Units are case sensitive. Efficiencies and usable depth must be between zero
and one; inferring input power or energy requires positive efficiency. A zero
load has no finite runtime in this model and is rejected. Temperatures below
absolute zero are rejected. Cooling and a decrease in stored spring energy
retain negative signs. The local formulas use exact rational arithmetic;
Oracle may return rounded decimals.

## What the experiment found

The 14 ordinary-language cases completed only one of 12 valid numerical tasks
correctly; one of two invalid requests received a useful refusal. Three valid
tasks received incorrect answers under the stated assumptions, and one invalid
request received an unadjusted answer. Eight valid tasks were refused or needed
clarification. See `project/lanes/U1-engineering.md` for retained response details,
separate workflow results and the cases where rephrasing helped.

No shipped specialist panels were run. No theorem or fleet-score claim follows
from this usage experiment. Narrow helper checks:

```sh
.venv/bin/python -B -m unittest discover -s tests/usage/engineering -p 'test_*.py' -v
```

A follow-on source repair is retained in `condition_attachment.patch`: explicit
trailing assumptions stay with the preceding question, and short independent
questions can no longer disappear through the combiner's fragment join. It is
applied only to the authorized private Slim checkout pending root's combined
appliance replay. The report distinguishes these component checks from the
original immutable-candidate observations. Its 16 narrow regressions run with:

```sh
.venv/bin/python -B -m unittest discover -s tests/usage/engineering -p 'test_condition_attachment.py' -v
```

These tests use `var/ap1-upstream-slim` by default; set `ENGINEERING_SLIM_ROOT` to
another source checkout to test that consumer. They explicitly skip when no
source checkout is available; a skipped test is not a repair verification.
