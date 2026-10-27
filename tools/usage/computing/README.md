# Check a base conversion without losing its source base

The pinned Oracle appliance answers `Convert binary 11111111 to decimal.` with
`11111111`, although the answer is `255`. It marks that answer `verified: true`:
two arithmetic methods agree on the same incorrectly decoded input. Explicitly
writing `from base 2` does not repair the pinned engine.

`base_workflow.py` keeps digits, source base and target base separate. It emits
an ordinary runner request and a separately labelled local expectation. Its
checker retains the complete Oracle record, checks that it belongs to the exact
request, and reports wrong input binding separately from wrong arithmetic.
Withheld answers stay withheld. It does not execute code supplied in the input.

From the repository root:

```sh
.venv/bin/python -B tools/usage/computing/base_workflow.py 11111111 \
  --from-base 2 --to-base 10 --view cases > var/usage-20261026/computing/check-cases.json
.venv/bin/python -B tools/usage/run_batch.py \
  --cases var/usage-20261026/computing/check-cases.json \
  --out var/usage-20261026/computing/check-run-new
.venv/bin/python -B tools/usage/computing/base_workflow.py 11111111 \
  --from-base 2 --to-base 10 --check-stdin \
  < var/usage-20261026/computing/check-run-new/results.jsonl
```

The workflow accepts 1–128 unsigned digits, bases 2–36, no prefixes or separators.
The response checker deliberately recognizes only the operator's explicit
`N in base B is DIGITS.` answer shape. Other shapes need inspection; they are not
silently treated as success. The local expectation is ordinary untrusted Python,
not a theorem, an Oracle result, or proof that its evidence claims are correct.
For a one-off conversion, Python's `int(digits, base)` is simpler and faster.
This workflow helps an agent integrating Oracle retain and check what was asked.

`source-base.patch` is the actual operator repair applied to the authorized
working and admitted source copies under `var/ap1-upstream-slim`, relative to the immutable candidate. The engine imports the admitted copy first; changing only `wander-train` does not activate the repair.
It makes the parser preserve source digits and base, validates all digits, and
stops parsing suffixes of malformed or multi-request input. The function uses
standard integer decoding plus repeated division; the reference independently
expands the original digits and uses a positional output table. Their agreement
still depends on the shared untrusted parser. The repair accepts named source
bases and conventional `0b`, `0o`, `0x` literals; negative integers, conflicting
source markers, fractional values and malformed partial requests are declined.
Root owns provisioning and the full-engine integration check.

Run the narrow regressions against the admitted source used by the engine:

```sh
.venv/bin/python -B -m unittest discover -s tests/usage/computing -v
```

Set `ORACLE_OPERATOR_SPECS` to test another repaired module path. Tests cover the
actual wrong result, malformed digits and signs, hex words and literal prefixes,
zero and leading zeros, 6,125 combinations of source/target base and known value,
and the caller's preservation of refusals and original records. These are usage
regressions, not specialist panel scores.

`cases.json` and `base-cases.json` contain only runner inputs. Their separately
written expectations are in the corresponding `expectations.json` files.
Retained actual answers and final findings are linked in
`project/lanes/U1-computing.md`.
