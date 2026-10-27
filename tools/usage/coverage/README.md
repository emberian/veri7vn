# Explain a knowledge refusal

This workflow distinguishes missing records from a missed route to existing
records. It also flags a returned subject that differs from the intended person.
It does not supply substitute Oracle answers or automatically judge correctness.

Run the real question pack in a new directory:

```sh
.venv/bin/python -B tools/usage/run_batch.py \
  --cases tools/usage/coverage/cases.json \
  --out var/usage-20261026/coverage/run-new
```

Then inspect the stored reply against operator-supplied entity and relation
hypotheses, with primary sources recorded in the expectations file:

```sh
.venv/bin/python -B tools/usage/coverage/diagnose.py \
  --expectations tools/usage/coverage/expectations.json \
  --results var/usage-20261026/coverage/run-new/results.jsonl \
  > var/usage-20261026/coverage/diagnosis-new.json
```

The tool opens the selected package's name index and v2 relation store with
`mode=ro&immutable=1` and SQLite query-only mode. Exact indexed probes have result
limits and a VM instruction budget; it does not scan or copy the corpora. The
package must remain immutable while the connection is open. Manifest hashes are
reported as declarations, not newly performed integrity checks.

Interpret the output as a next step:

| Finding | Next step |
| --- | --- |
| Intended name and relation rows exist, answer refused | Inspect parsing, routing, admission and evidence fit before importing data. |
| Relation rows exist, exact name did not retrieve the entity | Verify the alias and inspect the linker; candidate output is bounded. |
| Returned subject differs from intended entity | Investigate partial-name or wrong-entity routing. |
| Property has rows, intended entity/property pair does not | Confirm the mapping, then acquire a relevant source record. |
| No rows for the property | Check import policy and add coverage from a relevant source. |
| Requested qualifier is missing | Obtain a source for that exact event or constraint. |
| Question asks for every item | Define scope and secure a complete inventory before claiming completeness. |
| Ambiguous name | Ask which entity the user means. |
| Answer returned | Review it against the independent source and requested semantics. |

Missing records never establish a negative fact. Present records do not prove
truth, relevance, uniqueness or completeness. In particular, a developer record
cannot automatically answer who originally created something, and a generic
opening date does not answer when pedestrians were admitted.

For a new task, write independent natural-language expectations before the run.
Provide an entity name, a candidate Wikidata ID, a property ID, and an operation
(`forward`, `verify`, `qualified`, `ambiguous`, or `enumerate_all`). These mappings
are operator hypotheses and must themselves be checked. The initial pack records
corrections to two guessed entity IDs after lookup; its expected facts were not
changed. Separate original answers from this diagnostic output.

Narrow checks:

```sh
.venv/bin/python -B -m unittest discover -s tests/usage/coverage -p 'test_*.py' -v
```

The private router regression check is separate from diagnosis and engine replay:

```sh
.venv/bin/python -B tools/usage/coverage/check_routers.py \
  --runtime var/appliance-20261026/candidate \
  --source var/ap1-upstream-slim/root/wander-train
```

It needs the corrected source files named by root. Its result covers direct
router behavior only; replay the original case pack through the shared runner
after those files are integrated into a fresh immutable runtime.
