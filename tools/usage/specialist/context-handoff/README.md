# Carry a delivered scalar between turns

This workflow moves the dimensionless number used by Oracle w29's `_last_value`
into a small native record. Observe a delivered value, multiply it on the next
two turns, inspect it, then clear it after an unsupported correction. A missing
number produces an explicit withheld answer. The native arithmetic uses bounded
rationals. A number imported from a Python float keeps that rounded origin;
its decimal spelling does not become exact source precision.

`native_context.capture_after_finish` reads only the reconciled w29 scalar after
the outer final-outcome wrapper and the caller's delivery decision. It does not
read speculative candidates. Its caller owns that delivery boundary. The reverse
projection changes only `_last_value[session]` in an already tenant-bound Engine
on its serialized executor. It refuses an exact value that would round in that
cache. It does not reconstruct `chat_context_v2.Turn`, AN pending conversions,
transitions, solved variables, discourse, effects or files. Python workers remain
tenant-bound; exporting this owner does not make arbitrary tenant reuse safe.

The consumer's `Client.prepare_legacy_after_finish` connects that capture to a
retained native handoff request. Call it on the legacy serialized executor after
the delivery decision, then send its immutable `Turn` through `Client.send`. If
native delivery is lost, retry that turn rather than running the Engine again.
Legacy execution and native observation have no common transaction; a failed
handoff must be exposed, and this workflow cannot promise atomic cross-provider
front-door turns. Native observe/scale/inspect turns share one durable core
session and exact retry journal.

`context.execute` saves the typed scalar owner and exact reply atomically in
Runtime's existing session journal, with the full session compare-and-swap check.
There is no second journal. The host accepts structured `arguments.command`
(`observe`, `scale`, `inspect` or `clear`) plus `expected_version`.

This is an explicit caller-controlled import and restore route. The caller must
capture after delivery and submit the native observation; restoring a scalar into
an existing tenant-bound Engine likewise requires an explicit bridge call. The
host does not automatically take over Engine state or synchronize the two owners.

For an operator-admitted host exposing `context.execute`:

```
python3 tools/usage/context_handoff.py --url http://127.0.0.1:8000 --prefix fresh-run --conversation fresh-run
python3 tools/usage/specialist/context-handoff/scorer.py --url http://127.0.0.1:8000 --prefix fresh-panel
```

Schema 3 stores `native_extensions` independently of `oracle`. Native owners are
registered by compiled host code and versioned in the admitted release. Explicit
schema-1 and schema-2 migrations retain available selection and Oracle data;
unknown Python state stays unknown. Every stored owner is bounded and checked on
recovery. A native owner read returns an immutable snapshot with its memory
reservation retained through the consumer's use.

The consumer retains an immutable request ID, exact command and expected
old revision for retry. Retry the same turn after a lost response, including after
host restart; do not advance the expected revision speculatively. The server must
derive canonical identity from the actual typed command, replay the same core
reply and refuse changed commands under the retained ID. The
eight supplied workflow cases compare literal independently written values and
retry each turn. Transport failures are execution errors, not scored refusals.

No shipped specialist-panel numbers, build, executed test or performance result
exist for this lane yet. The Rust contract tests cover lost proposals, image and
tenant mismatches, revisions, owner versions, scalar limits and rounded origin.
The Python boundary tests cover final corrections, observed versus unknown
absence, independent session entries and exact-to-float refusal. Central runtime
validation must additionally cover restart after commit before delivery, changed
retry input, stale full envelopes, and schema-2 recovery. Measure owner bytes per
retained session, native follow-up latency, and host/worker process memory before
claiming a memory or speed improvement. This handwritten code adds no theorem.
