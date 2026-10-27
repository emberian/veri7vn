# Inspect what supports an Oracle answer

This offline command reads complete replies retained by the usage runner. It shows
source citations, reported computations, native comparisons, proof claims,
clarifications, missing support and unavailable metadata separately.

```sh
.venv/bin/python -B tools/usage/evidence/inspect.py \
  var/usage-20261026/evidence/run-1/results.jsonl --case zero

.venv/bin/python -B tools/usage/evidence/inspect.py \
  var/usage-20261026/evidence/run-1/results.jsonl --format json
```

Input may also be one JSON reply, an adapter envelope or a JSON array. Text mode
prints the whole active answer, with evidence observations beneath it. `--raw`
includes the entire original record. JSON mode always retains it, including
unknown fields, rejected answers and exact response bytes retained by the runner.
The inspector neither executes answer content nor reads source databases.

A source identifier means a citation was returned, not that its source was
checked. An empty `references` list can coexist with a citation in the answer's
prose. Historical `replaced_response` fields are retained but are not counted as
support for the active answer. A reported computation is not a recomputation by
this inspector. A native agreement is a comparison of displayed outputs, not
proof that the question was correctly recognized or that theorem premises hold.
The absence of `kernel_check` does not tell us whether a check was skipped,
unavailable or never requested. `proved` and `verified` stay upstream claims.

The `unsupported_claim` category identifies missing returned support or a
specific contradiction/non-finite marker; it does not decide whether arbitrary
English claims are true. Ambiguous entity selection and source coverage still
need a person or a stronger consumer to examine them. The command never changes
the answer status, silently repairs an answer or promotes a withholding to success.

The twelve questions and independently written expectations are in `cases.json`
and `expectations.json`. To repeat the real-engine experiment, choose a fresh
output directory:

```sh
.venv/bin/python -B tools/usage/run_batch.py \
  --cases tools/usage/evidence/cases.json \
  --out var/usage-20261026/evidence/run-2
```

The focused tests use small synthetic replies. Math repair tests optionally load
the provisioned editable source; set `MATH_ORGAN_SOURCE` to test another source
copy. Missing source skips those tests explicitly.

```sh
.venv/bin/python -B -m unittest discover -s tests/usage/evidence -v
```

No theorem or shipped specialist panel score is established by these checks.
