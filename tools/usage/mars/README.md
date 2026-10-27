# Convert named planetary years

The original question asked for three Mars years in Earth years, using supplied
periods of 687 and 365.25 days. The final U1 appliance answered Earth's one-year
table entry instead. This pack reproduces that failure and checks the repair.

`cases.json` contains 21 requests, with independent expected values/refusals in
`case-expectations.json`. Twelve are valid conversions; nine have contradictory,
malformed, unbound or unsupported inputs. The original unchanged question is
also isolated in `baseline-cases.json`.

Run against a newly provisioned candidate:

```sh
.venv/bin/python -B tools/usage/run_batch.py \
  --runtime /absolute/path/to/candidate \
  --cases tools/usage/mars/cases.json \
  --out var/usage-20261027/mars/new-run
```

The output directory must be new. Keep complete replies; HTTP completion is not
an answer-correctness score.

The actual private specialist regression uses its manifest loader and its real
versioned module chains, plus the real Family composition in both loading orders:

```sh
.venv/bin/python -B -m unittest discover -s tests/usage/mars -p 'test_*.py' -v
```

Defaults point to `var/ap1-upstream-slim` for source and the immutable final U1
candidate for NASA data. `MARS_SOURCE` and `MARS_DATA_ROOT` override those paths.
The test runner does not create a full Oracle engine. Existing constructors emit
ResourceWarnings for their unclosed NASA-sheet reads under unittest; the tests
still complete successfully.

Replay each version's actual shipped panel through its own scorer:

```sh
.venv/bin/python -B tools/usage/mars/check_panels.py \
  --source var/ap1-upstream-slim \
  --data-root var/usage-20261026/candidate-final/root
```

This read-only script measures direct specialist replies, not a fresh held-out
admission or the Workbench's complete six-criterion composition exam.

`astronomy_year_conversion.patch` records the nine private Python source changes;
`source-manifest.json` records exact paths and hashes. The arithmetic is
`count × source period / target period`. The parser binds every supplied period
to a named planet, rejects unparsed conditions and conflicting periods, keeps
source and target direction, and labels supplied versus table/convention inputs.
It is untrusted Python interpretation and arithmetic, not a proof. Moon orbital
months and unknown/fictional planets are not silently treated as solar years.
The legacy one-year lookup remains for ordinary table-property requests.

See `project/lanes/U2-mars.md` for measured results and the native typed-operation
boundary. No admission/hash field is rewritten by this pack.

The actual U2 Python candidate replay completed all 12 valid conversions and
withheld all nine invalid/unsupported requests. The unchanged U1 baseline had
zero valid completions and answered six invalid requests. `repaired-summary.json`
and `baseline-summary.json` record these task outcomes separately from panels.
