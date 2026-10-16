# Shared UI/CLI operation proposal

Consumer requirements under C01/C03/C04/C05, not a frozen schema or authority
implementation. Names below are product operation names and proposed CLI spellings.
The integrated native/host stewards own wire constructors, identifiers, native
codecs and commit rules. In particular, the feasibility host's
`veri7vn_host_v1` ping/run/cancel commands are probe plumbing, not this API.
Host61 confirms revision + epoch + exact authorized batch identity/delta, durable
acknowledgement and committed-state recovery are required integration constraints.

## Common envelope and responses

Every operation carries correlation/operation identity, selected workspace/object,
expected relevant revision/epoch for mutation, and declared execution/effect policy.
A request that reasons or executes pins the environment and request observation
context required by C03/C04, including state/time use or its explicit absence.
Native family values use their registered codec, never a universal JSON HOL value.
Credentials are opaque workspace references. Unknown fields cannot grant authority.

Read/preview responses return exact base identities, source maps/diagnostics and
scope, not approval to execute. A proposal identifies original immutable input,
changed sources/configuration, affected consumers, unresolved obligations, effect/
export closure and expiry policy. Applying a proposal checks current source,
permissions and lifecycle authority; a saved stale preview is insufficient.

Jobs emit progress plus typed terminal outcomes, with partial subgoal status and
explicit searched scope. Progress is not an accepted answer or committed effect.
Native claim acceptance, proposed state delta, durable batch commit and executor
outcome are distinct records. The client shows activation/effect success only at
the appropriate durable state; dispatch acknowledgement need not establish external
world success. Cancellation itself may be acknowledged while an already handed-off
external action remains unknown and requires reconciliation.

For concurrent retries, operation identity locates an existing attempt; the host
must distinguish same identity/same request from identity reused with different
payload. Unknown outcomes are inspected, never assumed safe to replay. Event cursors
resume observation, not execution. Permission denied, version conflict, unavailable
source, failed execution, cancelled and inconclusive search remain distinct results.
The proposed local wire can display these without author-written authority flags.

## Operation matrix

| Product operation / proposed CLI | Input and precondition | Output and scope | Persistence / authority seam |
|---|---|---|---|
| `workspace inspect` | Workspace reference/access | Source/release/deploy/binding identities, jobs, current authority | Read only; includes inaccessible tombstones without payload |
| `gap enable/list/clear` | Explicit opt-in or retained journal access | Scoped original requests/reasons; clear impact | Private collection policy; clear is managed deletion, derived copies shown |
| `gap draft` | Gap IDs + recipe choice + package base | Proposed examples with unknown expectations and origin | New development revision after apply; no truth labels inferred |
| `package create` | Supported recipe + editable name/examples | Draft source + native obligations/view projection | Canonical source revision, no export theorem assumed |
| `import stage/inspect/map/apply` | Original archive/dir or native release, bounded intake policy | Preserved originals, source mapping, sender exposure, unresolved semantics | Stage inert bytes; controlled build later, existing deployment intact |
| `source inspect/patch-preview/patch` | Document/base revision + recognized span + requested edit | Exact patch/source diff + diagnostic/native locator map | Atomic revision-checked source update; preserve opaque expert blocks |
| `development check` | Exact source/dependency revision + native policy | Build/admission diagnostics with actual promised route | Controlled worker/native gate; no arbitrary worker source to resident authority |
| `example run` | Candidate + examples + expected-status labels | Exact observation per example; unknown remains unknown | Private observations; never silently counted qualification |
| `qualify start/inspect/cancel` | Candidate/baseline, binding/scorer, panel/split, exposure mode, fixture/real probe authority | Regression/holdout/interference results, spent/aborted exposure, timings | Durable job/exposure identity; no activation from passing tests alone |
| `request interpret` | Original input + policy/context | Resolved/ambiguous/unrecognized readings and scoped blockers | No execution implied; accepted reading decision attributable |
| `request run/inspect/cancel` | Accepted interpretation or typed plan, environment/observations, budget/effect policy | C03 outcomes per part + typed dependencies + exact scope | Shared authority transition; no parsing answer prose into inputs |
| `repair preview/apply` | Diagnostic/counterexample + explicit repair choice + base | Meaning/domain preserving versus changing diff | Creates new source revision; neither counterexample nor timeout is auto-repair permission |
| `profile start/inspect` | Workload + runtime/candidate/baseline/resource manifest | Samples and attributed costs, incomplete-run flags | Observation artifact; optimization stays candidate until bridge established |
| `release create/inspect` | Exact source/build/dependency identities + selected evidence | Immutable release manifest, rebuild recipe, unresolved dependencies | No activation; friendly label resolves exact generation |
| `deployment preview/activate/rollback` | Release, private bindings, expected deploy revision/epoch | Affected consumers, required gates, exact pending/committed state | One native-authorized batch + durable host ack; rollback is new authorized transition |
| `feedback propose/evaluate/publish/undo` | Actual result/reading/invocation + correction kind | Attributable event + versioned policy candidate/diff/evaluation | Existing policy remains until atomic qualified activation; undo is new revision |
| `source configure/discover/preview/probe/start/stop` | Interface/target/schema/config, secret ref, exact chosen operation authority | Inert config, discovery observations, probe payload/result, acquisition state | Discovery/probe/poll can have effects; no implicit calls from viewing settings |
| `source reconfigure/retire/forget` | Expected config revision + impact preview + retain/remove curated choice | New policy version, blocked uses, deleted derivatives, remaining tombstones | Current lifecycle check incl cached followups/pending work; no late acquisition resurrection |
| `history recall/restore` | Session/checkpoint ID + access/current lifecycle | Retained historical claims or allowed typed restored state, unavailable forgotten parts | No request replay; restore state via authoritative transitions |
| `history execute-again` | Explicit selected original input + new policy/context | New request identity and fresh observations | New execution including effect preview; never automatic reconnect |
| `scratch edit/run/promote` | Content/test bytes + worker/toolchain + explicit trusted/isolated policy | Artifact revision, exact observations, open native obligations | Ordinary candidate artifact; optional worker separate from authoritative process |
| `export preview/package` | Selected public/authored artifacts + classifications + exact closure | Included/omitted private dependencies and recipient limitations | Recheck closure/authority before writing; secret refs excluded |
| `explanation preview/export` | Selected structured result/graph + retained evidence access | Full local HTML, optional WebM and companion scope/history | Presentation artifact, not a new acceptance route |
| `adapter preview/dispatch/status` | Explicit remote media/registry adapter, payload/destination + permission | Export receipt/attempt/outcome | Same C05 effect boundary; D16 handoff scope unresolved |
| `operation inspect/reconcile` | Existing operation/attempt identity and event cursor | Committed/pending/unknown state with next permitted actions | Read status; reconciliation may require new explicit authorized action |

No endpoint in this table creates a second publication mechanism for authoring,
search or synthesis. Their proposals enter common development/admission/qualification/
release/deployment operations. Descriptor schema revision is unchanged.

## Recoverable command examples

Proposed spellings, not available commands:

```text
v7 import stage original.zip --format oracle7-specialist/1
v7 import inspect intake-12 --mapping --exposure --unresolved
v7 source patch package-7 --base r4 --patch patch-file
# Conflict => inspect base/current/proposed; request new proposal, never --force overwrite.
v7 qualify start package-7 --revision r5 --mode regression --probe-policy fixture
v7 operation inspect op-81 --events-after cursor-9
v7 deployment preview workshop --release package-7@0.3 --expected-epoch 8
v7 deployment activate workshop --preview deploy-preview-2 --operation op-82
# Connection lost => inspect op-82. Do not resend with a new identity.
v7 explanation export result-42 --format html --closure-preview export-preview-9
```

The CLI renderer displays conditions, partiality and artifact lifecycle in human
output; `--json` retains the agreed typed encoding. CLI exit status distinguishes
transport failure, user input needed, failed check and an inconclusive job; numeric
codes remain a CLI implementation choice. It does not return exit-success merely
because HTTP or the transport command succeeded.
