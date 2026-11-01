# AP1: move vessel state into the configured workspace — 2026-10-26

Root integration, 26 October: included in the tracked appliance patch and the passing real-engine candidate. Proposed upstream in [HF slim #1](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/1), not merged. See [batch results and remaining work](../APPLIANCE-2026-10-26.md). The lane evidence below describes its scoped checks before root integration.

The first real stock appliance smoke exposed source-tree writes from vessel
reception: `self_loop/vessels.json`, `vessels_events.jsonl`, and
`vessels.sqlite3`. The request log also used the same source directory.

## Change

In the private upstream clone `var/ap1-upstream-slim`, changed:

- `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w175.py`
- `tests/runtime_state/test_vessel_state.py` (new)

When `ORACLE7_STATE` is explicitly present, w175 resolves that directory,
creates its `vessels/` subdirectory, and places the JSON snapshot, event log,
and curriculum request log there. When the variable is absent, the historical
source-relative paths remain unchanged. Import now fails if an explicitly
configured state directory cannot be created; it does not silently fall back
to writing source.

No w480 edit was needed. Its existing `VESSEL_DB =
_w175.VESSELS.with_suffix('.sqlite3')` follows the relocated JSON path, and its
indexed receipt code already uses w175's event/request paths. The adapter's
explicit state root is the consumer. The stock materialized runtime was not
modified by this lane.

## Checks

```sh
.venv/bin/python -B -m unittest discover -s var/ap1-upstream-slim/tests/runtime_state -v
```

**3 tests passed**, 0 failures/errors, 0.055 seconds:

1. Independently imported module globals select different explicit workspaces;
   absent configuration preserves the legacy location; w480 derives the matching
   database path in all three cases.
2. Real w175 `_receive`, JSON save, event append, and reinforcement request append
   write separate content in two workspaces, with no files added to source.
3. Real w480 database creation and indexed reception write separate SQLite rows,
   event logs, and request logs in those same distinct workspace scopes.

These import the actual modified source with controlled base modules, grounding
helpers, and disabled optional organ imports. They exercise real persistence
methods but do not construct the complete Engine or establish answer quality.
Theorem statements: none. Specialist panel numbers: none.

Root owns the next complete Engine run and full before/after runtime inventory.
This patch fixes the demonstrated vessel paths; it does not claim all runtime
state writers have been found. Separate service processes are still required
because the upstream paths are module globals captured at import time.
