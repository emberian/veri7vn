# U3: agent discovery and direct computation — 2026-10-27

The appliance now exposes the implementations an agent can actually call,
including their inputs, units, examples, sources and limits. It no longer offers
only a text-chat endpoint. This adapter remains untrusted Python; Mini retains
its own admission and capability authority.

## Changed files and consumer

- `tools/appliance/operations.py`: runtime registration discovery, isolated direct
  specialist calls, existing structured numerical functions, core organs, and
  fixed optional Workbench/component providers.
- `tools/appliance/serve.py`: bounded catalog/detail and invocation routes, same
  Engine-owning thread, persistent method/route/body replay identity, and effective
  limits in capabilities.
- `tools/appliance/README.md`: agent-facing contract and assurance boundaries.
- `tests/appliance/test_operations.py`: dispatcher, schema, replay/migration and
  symbolic-value regressions; `test_service.py` updated for explicit journal
  columns. `test_component_composition.py` belongs to the adversary lane and was
  included in the scoped integration run.

The consumers are Mini's admitted application bridge and its agent discovery/
call tools. Contract agreed directly with both lanes:

- `GET /operations?offset=0&limit=10&q=...&availability=live_direct`
- `GET /operations/<operation_id>`
- `POST /invoke`, exactly `request_id`, `conversation_id`, `operation_id`,
  `arguments`; the last field is a structured object.

Operation IDs match `[A-Za-z0-9][A-Za-z0-9._-]{0,159}`. Search is at most 256
UTF-8 bytes, limit 1–50, offset 0–999999999. Unknown/duplicate query fields are
rejected. Discovery pages retain complete descriptors and paginate early below
32 KiB; descriptors are at most 24 KiB. The signed Mini profile selects a 65,536
byte whole-request envelope, while standalone keeps its prior 16 KiB default.
Capabilities, pages and descriptors expose the effective bound. Provider schema
ceilings do not override it. Invocation replies retain the configured 2 MiB
bound; Mini's model-display projection may be tighter than transport.

## What executes

The catalog reads standing-list references from modules in the live Engine's
class chain, then loads those registered organs through Oracle's existing
`_Organ` isolation. An unused specialist directory alone does not become live.
Failed loads remain unavailable. Direct `.answer` operations call the actual
organ method on the same thread that owns Engine's SQLite connections. Their
native text schema is explicit; numeric arguments are never interpolated into a
hidden chat template. The manifest admission result is reported, and the whole
raw dictionary is retained, including unfamiliar evidence fields. These direct
calls do not claim the head's routing, arbitration or global refusal guards.

Structured functions call the actual registered weather module's heat-index
and temperature-conversion functions, and registered chemistry organs' molar
mass methods. Core math and relation operations call the existing cached core
organs. SymPy expressions and symbol-keyed solutions use tagged records carrying
both display expression and constructor representation. Non-finite numeric
values fail explicitly; no numeric approximation silently replaces a symbol.

Fixed provider modules connect supplied-data Workbench operations and pinned
visual/decision/builder components. Missing optional sources/dependencies or a
provider load failure do not disable unrelated routes. Learned network
interpolation templates are `text_only`; external files, live sensor polling,
and arbitrary build/execution powers remain explicitly unavailable under this
computation interface. Provider input/schema checks are not Mini permissions.

One query/invocation runs at a time; discovery shares that same worker gate.
Request identity includes method, route and exact bytes. IDs collide across
`/query` and `/invoke` rather than executing twice. Existing journal rows migrate
as `POST /query` without reexecution. Deliberate refusals remain HTTP 200 completed
work; invalid arguments, missing operations, unavailable operations, runtime
faults and timeout remain distinct errors. Interrupted execution has the same
explicit uncertain-state behavior as the existing service.

## Checks and observed results

Final scoped command before packaging freeze:

```sh
.venv/bin/python -B -m unittest discover -s tests/appliance -v
```

**39 tests run in 2.456 seconds: success, one skipped.** The skip is the optional
visual composition test because the local `.venv` lacks Pillow; NumPy is present.
The suite includes fake-engine transport checks and actual supplied-data
Workbench/builder/component checks from the adversary lane. It is not a
specialist scoreboard. Notable regressions cover cross-route request collisions,
legacy journal migration, direct call/replay, raw evidence preservation, native
TypeError occurring only once rather than mistaken arity retry, strict schema
constants, optional-provider isolation, and exact tagged symbolic values versus
NaN/infinity rejection.

Two sequential real Engine processes were run against the **immutable**
`var/usage-20261027/candidate-final-v3`, each with a fresh workspace beneath
`var/u3-service/`. Both were stopped by their recorded owned PIDs (60286 and
97296); neither is running. No parallel Engine farm was started.

Receipts:

- `var/u3-service/live-initial-receipt.json` and
  `live-initial-catalog.json`: paged real catalog and direct calls. This snapshot
  had 331 live direct, one text-only and 14 unavailable descriptors with the
  optional-provider files available at its startup. This is a loadability count,
  not an accuracy score.
- `var/u3-service/live-updated-receipt.json`: corrected symbolic serialization,
  existing structured weather functions, and the 65,536-byte profile boundary.

Observed real results:

- Acoustics: 440/442 Hz tuning forks → **2 Hz**, retaining raw numeric value.
- Chemistry-v3: `H2O` → **18.015 g/mol**, counts H=2/O=1; unknown formula and
  empty-parenthesis formula deliberately withheld.
- Core math: factor `x^2 - 5*x + 6` → `(x - 3)*(x - 2)` with expansion check;
  solve `2*x = 6` → `x = 3` with substitution check and symbol-keyed value intact.
- Actual registered legacy weather function: 84°F/40% RH → **83.29043364000009°F**;
  32°F → 0°C; 20°C → 68°F.
- Workbench supplied document query returned the supplied boiler-limit sentence
  with its filename/line citation and input hash.
- Text-only template and separate sensor-poll capability returned 409; absent
  operation returned 404. All these requests replayed exactly without new work.
- A 60,000-character argument reached the dispatcher under the 65,536-byte
  profile and returned unknown-operation 404; 66,000 characters returned 413.

The initial core-math call exposed non-JSON SymPy values; the tagged serializer
fixed this and the subsequent real calls above passed. No fields were discarded
to make serialization succeed.

A post-run filename inventory against the immutable candidate receipt found
**zero new and zero missing runtime files**. This was not a rehash of the 15 GB
store set. Python bytecode writes are disabled before importing the adapter's
sibling module, as well as before upstream imports.

Theorem statements: none. Specialist panel numbers from this lane: none.

## Integration still owned by root

Final-v3 registers legacy `meteorology`, not the package's repaired v2 directory.
This discovery exposed the missing integration rather than advertising v2 as
live. The weather lane has now frozen explicit standing-list replacements; a
fresh U3 candidate must demonstrate `specialist.meteorology-v2.answer` and the
weather boundary examples. The service selects structured weather functions
from v2 when genuinely registered, otherwise from the registered legacy module.

Root assembles the fresh pinned candidate and signed Mini package, qualifies
its admitted application/agent path, and records the final catalog counts with
all frozen providers. This report's earlier final-v3 counts are not a claim about
that future candidate. Upstream correctness, global guard behavior for direct
calls, source closure, quotas and optional runtime dependencies remain explicit
limits rather than being inferred from this catalog.

## Full packaged candidate U3-v2 probe

A later root-requested addition made `core.query` discoverable. It calls
`Engine._rt.chat` directly on Engine's existing owner thread, preserving the
complete full-head reply and sharing conversation state with `/query`. It never
recursively calls the executor-backed `Engine.chat`. A focused thread/state test
passed: query and invoke use one owner thread, separate sessions stay separate,
and replay does not add another turn. The integer-safe argument-validator fix
also landed before this packaged run; large JSON integers cannot turn a normal
bounds rejection into a floating-point OverflowError.

The full packaged service at
`var/usage-20261027/candidate-u3-v2` was then exercised with its own immutable
`adapter/serve.py`, not development code. Receipt SHA256:
`e87aaadc39a6d7767e88aa34cd5b593f718ecd7256591e462865c9f6b2a003ec`.

Evidence: `var/u3-service/u3-v2-real/receipt.json`, complete `calls.jsonl`,
`catalog.json`, and `runtime-before.json`; runner/progress log:
`var/u3-service/probe-u3.py` and `probe-u3.log`.

**69 real HTTP requests, each replayed exactly.** One Engine held the host slot;
owned PID 58800 exited normally (code 0). All runtime filenames, sizes and
modification times matched the pre-run snapshot; the receipt hash also remained
unchanged. This is a before/after mutation check, not another full store rehash.

The local interpreter was the project's Python 3.12 environment. Its NumPy,
SymPy and other Oracle dependencies stayed first on the import path; Pillow
12.3.0 came from the Codex bundled Python 3.12 package directory. Thus the visual
calls are actual local computation, while qualification of the signed Linux
profile remains Mini's separate integration job.

Discovery returned **349 live direct, one text-only and nine unavailable**
operations. These are availability counts, not answer scores. Repaired
`specialist.meteorology-v2.answer` was live and all six weather examples passed:
ISA at 3000 m = -4.5°C; speed-as-altitude and negative altitude refused; heat
index, wind chill and dew point matched the earlier numeric expectations.
Structured v2 heat-index, chemistry mass and symbolic core math also passed.

Actual packaged companion calls succeeded for Workbench table/document/sensor/
prose operations, Trafficcop, DeepSpace, Infrastructure analysis, bounded program
construction with held-out read-back, Chameleon search plus witness validation
and contract validation, Vision image description, and Artist layout/rendering
with supplied sprites. The forecast-gate operation had no catalog example and
was not exercised in this run; the fixture explicitly records that coverage gap.

`core.query` and `/query` returned identical status/path/response for separate
fresh arithmetic sessions (6 × 7 = 42). An attempted cross-route follow-up,
“What did I just ask?”, was intercepted by `precision_guard:G2_private_state`
after the dialogue route had been selected. This is an observed guard/routing
failure, **not evidence that the adapter lost the session**. Root requested the
previously supported authored-work → author-birth follow-up on the next candidate
to separate state plumbing from that guard behavior.

The whole-head query cases expose remaining behavior that direct specialist
calls would conceal:

- All ten valid work/year examples withheld or clarified: eight creator-binding/
  complete-title-evidence failures and two unparsed Pride and Prejudice film
  questions. The two unsupported-year cases also withheld. Root assigned the
  positive-answer loss to the premise lane before final qualification.
- Both “Which band did Brian May form with Roger Taylor?” and the false
  Chopin/Freddie Mercury version clarified. The false version made no false
  assertion; the probe's narrower expected-`withheld` check failed because its
  actual status was `clarification`.
- Einstein's biography was withheld without calling Einstein its author.
- The explicit sole-Shakespeare premise for Emma was ignored: the full head
  answered Jane Austen through `literature-v2` without addressing the premise.
- Existing engineering, document and date integration cases were all recorded
  with their complete replies; this run did not declare every valid unanswered
  engineering request solved.

The raw receipt retains four failed checks: missing forecast example, the G2
follow-up, the narrow false-WITH status expectation, and the ignored sole-creator
premise. Transport/replay/component success must not be substituted for a claim
that those whole-head behaviors passed. Root is holding final Mini artifact
qualification while the next premise patch is integrated. No immutable candidate
or upstream source was edited by this probe.
