# Data reads and durable native state

The native runtime shares one immutable data image across tenants. Requests own
query plans, cached stages and returned evidence. A conversation retains a small,
versioned session record in SQLite. The [runtime host](RUNTIME-HOST.md) exposes
these through named operations; discovery shows which the operator admitted.

## Read several plans together

`graph.batch` accepts structured graph or KQA inputs. It checks each plan, then
runs the batch over one image with an empty `Previous` selection. Repeated stages
and parsed columns can share a bounded workspace during that invocation. The
cache disappears after the batch; it is not session memory.

For `POST /invoke`, use an ordinary object inside `arguments`:

```json
{
  "request_id": "read-one",
  "conversation_id": "example",
  "operation_id": "graph.batch",
  "arguments": {
    "batch": {
      "items": [{
        "dialect": "graph",
        "input": {
          "nodes": [{"op": "find", "name": "Alice"}],
          "output": 0,
          "projection": {"kind": "count"}
        },
        "demand": "full"
      }]
    }
  }
}
```

Each item chooses `full`, `exists` or `count`. An existence answer may stop early;
a count covers the selected source set. Neither establishes that the source has
all facts about the world. A batch reports item outcomes and workspace costs;
a failed item can leave later items `not_run`. It changes no conversation state
and retains no durable retry reply.

## Say exactly what a source scan covered

`graph.coverage` traverses the image's relation rows for explicit canonical IDs,
predicate and direction. Optional `qualifiers` matches the entire qualifier
object exactly. For example, its arguments can be:

```json
{
  "coverage": {
    "subjects": ["Q1"],
    "predicate": "knows",
    "direction": "forward",
    "traversal_limit": 100
  }
}
```

Only reaching the end of every declared cursor permits snapshot-relative count,
absence and uniqueness answers. The count is of distinct target IDs, rather
than statements. A missing subject or traversal limit produces incomplete
coverage and withholds those answers. Cancellation or a budget error returns no
completed coverage handle.

The receipt names the image revision and exact domain. It does not cover other
subjects, aliases or an entire entity class. Visiting supplied rows, exhausting
admitted language parses, and assuming a closed world are different premises.
A serialized receipt is a report; submitting it does not recreate the checked
in-process scan handle. Revisable evidence's supplied coverage declarations
likewise do not become checked source scans.

## Keep native state in the existing session transaction

Session schema 3 adds separately named, versioned native owners alongside the
selection and any explicitly imported Oracle state. Compiled hosting code
registers and validates each owner; retained JSON cannot register new behavior.
Selection turns, scalar turns and evidence revisions share the same session
version. A stale version conflicts, so interleaved turns cannot overwrite each
other's state.

A stateful operation commits its session change and exact reply together in the
existing core journal. There is no second owner journal or host replay record
for these native calls. Retry with the same tenant, conversation, request ID,
operation, typed command and `expected_version` to recover `core_reply_json`,
including after restart or a lost response. New structured commands derive
journal identity from their typed encoding. Legacy graph/KQA string inputs keep
their exact input-byte identity. HTTP wrapper bytes need not replay identically.

Schema-2 state can migrate additively under the same binding and revision: its
selection, coverage and optional Oracle payload survive; native owners begin
absent. This does not migrate a session to a different release or image. Those
changes require an explicit migration decision; reopening under a new identity
must not silently adopt the old conversation.

## Import one delivered scalar explicitly

`context.execute` owns a dimensionless scalar. It accepts `observe`, `scale`,
`clear` and `inspect`; even inspection is a versioned, replayable session turn.
For a fresh conversation, arguments can be:

```json
{
  "expected_version": 0,
  "command": {
    "op": "observe",
    "value": {"number": "12.5", "origin": "exact_decimal"}
  }
}
```

A subsequent command with `expected_version: 1` and
`"command": {"op": "scale", "factor": "2"}` delivers `25/1`. Scaling without a
prior scalar withholds the answer. Decimal/rational strings preserve exact numerical
values; `python_float` records an already rounded origin and remains marked
that way through arithmetic.

The optional Python bridge observes `_last_value` only after final delivery on
the Engine's serialized executor. Unsupported delivered answers clear the native
scalar. This is an explicit transfer of one owner, not automatic Engine takeover:
units, pending interpretations, files and other Python caches do not move. A
client-supplied `observe` value is supplied data, not evidence that an Engine
produced it. Restoring an exact scalar into Python's float cache refuses values
that would round.

## Revise evidence, then solve its snapshot

With the logic feature and admitted routes, `logic.workspace` inserts or withdraws
identified observations, rules and supplied coverage declarations. Its structured
arguments include both the session version and evidence revision:

```json
{
  "expected_version": 0,
  "command": {
    "command": "revise",
    "revision": {
      "expected_revision": 0,
      "token": "revision-one",
      "insert": [{
        "kind": "observation",
        "id": "row-one",
        "source": "supplied-file",
        "source_revision": "1",
        "atom": "ready"
      }],
      "withdraw": []
    }
  }
}
```

After that commit, `logic.workspace.solve` accepts
`{"expected_version":1,"command":{"command":"solve","expected_revision":1,"queries":["ready"]}}`.
It reads a checked immutable owner snapshot and runs the operator-admitted solver
fresh. The solve receipt binds that snapshot and solver identity; it does not
mean “latest evidence” after another revision. Solving does not advance the
session or store a retry reply. A failed solve leaves the already committed
evidence intact. Support records retain observation, rule, negative-guard and
coverage dependencies; supplied source names do not acquire external authority.

## What stays alive, and what the memory limit means

The image outlives requests and is shared rather than charged afresh to every
reader. Worker leases own SQLite access. Prepared plans, batch workspaces,
shared reader results and native owner snapshots retain explicit byte
reservations while their data remains live. Shared result clones charge once;
the final owner releases the reservation, including on cancellation unwind.
Nested work shares the parent ceiling and cannot mint another allowance.

`request_memory_bytes` limits these explicit, sometimes conservative accounting
charges. Live and peak counters describe that ledger, not allocator usage or
process RSS. SQLite caches, mapped image pages, foreign solver buffers and
untracked allocations remain subject to their separate settings, algorithmic
bounds and process containment. Persistent sessions and replies have separate
state, entry-count and byte limits.

The [central receipt](../evidence/2026-10-31-native-expansion-validation.json)
records real HTTP retry/restart, state isolation and source-query checks. A
256-request journey used 64 tenants in one process, with four threads observed
before and after the journey. This is a bounded functional check, not a
throughput, fairness or hard-RSS guarantee. The handwritten code has no inherited
Isabelle theorem merely because it shares this repository.
