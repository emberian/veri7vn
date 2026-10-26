# AP1: named quantities and admitted swarm programs

Root integration, 26 October: included in the tracked appliance patch and the passing real-engine candidate. Proposed upstream in [HF slim #1](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/1), not merged. See [batch results and remaining work](../APPLIANCE-2026-10-26.md). The lane evidence below describes its scoped checks before root integration.

Implemented in `var/ap1-upstream-slim` on the root-prepared contribution branch.
Root owns the commit and upstream contribution. Original `upstream/` and the
universe survey checkout were not changed.

## What changes for users

- Width no longer answers height merely because both use metres. Each value
  carries its named role and exact unit. Repeated-unit operands keep their own
  values and order. Tasks can explicitly connect synonyms with an `aliases`
  map, for example `{"travel time (s)": "duration (s)"}`. Unit changes and alias
  cycles are rejected. Reserve building uses the same aliases; newly built
  parts remain available to later tasks without inheriting earlier aliases.
- A plan runs only the formulas needed for its requested output. An unrelated
  formula that divides by zero does not prevent a valid area-to-volume chain.
- The parts index is rebuilt from present admissions. Changed, removed,
  revoked, or expired parts do not remain usable through an old `parts.json`.
  Before using a formula, the planner takes a private snapshot, validates that
  snapshot with the existing held-out gate, and derives its signature from
  those same bytes. Its program, local imports, and relative data files execute
  from that snapshot in a fresh interpreter. Revocation and expiry are checked
  again at execution. Exported code includes the examined snapshot too.
- Research and specialist fallback require one explicit compatible quantity.
  Known units convert; parsecs and apples do not become metres. Multiple
  compatible quantities, missing units, a different named role, negated values,
  and nonfinite values are declined. A tag's version number is not an answer,
  and an answer equal to an input remains eligible. The complete reply is
  checked before its display text is shortened.

## Changed files

In the upstream contribution checkout:

- `workbench/swarm/point.py`
- `workbench/swarm/bound.py` (new admission snapshot/runner helper)
- `workbench/swarm/test_point.py` (new offline regression tests)

In veri7vn: this lane record only. Other lanes' runtime changes in the private
upstream checkout were left untouched.

## Evidence

No theorem was added or changed. No specialist panel was run, and no specialist
coverage or panel-score gain is claimed by this infrastructure repair.

Focused command, run from `var/ap1-upstream-slim`:

```
/Users/ember/dev/o7vn/.venv/bin/python -m unittest discover -s workbench/swarm -p test_point.py -v
```

Result: **21 tests passed in 0.710 seconds**. `git diff --check --
workbench/swarm/point.py` also passed with no output.

The suite uses synthetic ADMIT fixtures to test version binding; those fixtures
are not evidence of specialist accuracy. It covers repeated-unit operands,
positive two-step composition, explicit synonyms, reserve composition through
aliases, stale/revoked/expired admissions, stale signatures, mutations of program
and helper/data files after binding, exported helpers, finite-number checks,
unit conversions, ambiguous replies, and the reported tag-number failure.

Terra reviewed the implementation and identified the reserve/alias mismatch;
the fix includes an end-to-end fake-reserve regression.

## Limits and consumers

Consumers are `swarm point`, `swarm parts`, `swarm paths`, and code export.
The existing held-out exam remains the authority: this repair binds its result
to the code actually used; it does not establish mathematical correctness from
an empirical exam. The formula runner is trusted local Python, not a sandbox
for hostile uploaded code. Interpreter/installed dependency versions remain
outside the specialist folder's hash. Explicit aliases are caller assertions,
not facts inferred from dimensional equality. Reply parsing is deliberately
limited to direct named or result-labelled measurements and supported unit
conversions; richer prose can still decline.

No network builders, broad runtime suites, Isabelle builds, or commits were
run by this lane. Root can review and commit the three named upstream files.
