# Shared UI/CLI operation proposal

C01/C03/C04/C05 consumer requirements; names below are proposed operations, not an installed API. Native/host stewards own codecs, constructors and authority. For runnable commands see [recipient operations](../../reference/recipient-operations.md). Authoring/search/synthesis share one publication lineage.

## Common envelope and responses

Carry operation/correlation identity, workspace/object, expected mutation revision/epoch and selected execution/effect policy. Reasoning pins environment and observations, including explicit absence of state/time dependence. Family codecs retain typed values; secrets are opaque references. Unknown fields cannot confer authority.

Preview identifies immutable base, changes, effects/export closure and open obligations; Apply rechecks current access/revision. Jobs expose progress, typed per-part outcomes and searched scope. Native acceptance, proposed delta, durable commit and executor outcome differ. Cancellation ack may coexist with unknown external action outcome.

Same operation/same payload observes the existing attempt; same identity/different payload rejects. Cursors resume observation, not execution. Permission denial, conflict, missing dependency, execution failure, cancellation and inconclusive search remain distinct. HTTP success alone is not product success.

## Operation matrix

| Proposed operations | Required input → output / boundary |
|---|---|
| `workspace inspect` | Accessible workspace → exact source/release/deploy/binding/jobs; inaccessible entries reveal no payload |
| `gap enable/list/clear/draft` | Opt-in + original request/reason → private clusters, deletion impact or canonical draft examples with unknown expectations |
| `package create` | Recipe/name/examples → editable source/obligations, no admission |
| `import stage/inspect/map/apply` | Bounded original/native content → inert originals, mapping, sender exposure and unresolved behavior; existing deployment survives |
| `source inspect/patch-preview/patch` | Base revision/span/expected bytes → exact atomic patch; expert blocks preserved |
| `development check` | Captured source/parents/native policy → actual build/admission diagnostics and candidate |
| `example run` | Candidate + labeled expectations → exact private observations; unknown unscored |
| `qualify start/inspect/cancel` | Baseline/candidate, binding/scorer/panel/split/exposure/probe authority → measured or aborted result, spent exposure and timing; no activation by tests alone |
| `request interpret/run/inspect/cancel` | Original input/decision or typed plan + context/budget → scoped readings/blockers, per-part native outcomes/dependencies |
| `repair preview/apply` | Actual diagnostic, intended meaning choice and base → reviewed new source; timeout is not counterexample |
| `profile start/inspect` | Pinned workload/runtime/resources → attributed observation; optimization still needs preservation bridge |
| `release create/inspect` | Exact source/build/dependencies/evidence → immutable rebuildable release, separate activation |
| `deployment preview/activate/rollback` | Release/private bindings/current epoch → impact/gates, native-authorized batch and durable ack; rollback is new publication |
| `feedback propose/evaluate/publish/undo` | Actual result/invocation and correction kind → attributable policy candidate; old policy survives failed evaluation |
| `source configure/discover/preview/probe/start/stop` | Target/schema/config/secret ref/selected authority → explicit acquisition/effect observations and lifecycle |
| `source reconfigure/retire/forget` | Expected config/current authority/curated-copy choice → new policy or blocked/deleted closure; no late resurrection |
| `history recall/restore/execute-again` | Accessible session/checkpoint → historical quotation or restored typed state; only execute-again creates fresh work |
| `scratch edit/run/promote` | Exact code/tests/toolchain/trust policy → artifact/observations/open native obligations |
| `export preview/package`, `explanation preview/export` | Selected classified closure/structured result → permitted bytes, omitted bindings, full HTML/optional WebM scope; recheck before writing |
| `adapter preview/dispatch/status` | Remote media/registry destination/payload/authority → attempt/outcome under C05; D16 scope |
| `operation inspect/reconcile` | Existing attempt/cursor → committed/pending/unknown and permitted next action |

## Recoverable command examples

Design notation only:

```text
v7 source patch package-7 --base r4 --patch patch-file
v7 qualify start package-7 --revision r5 --mode regression --probe-policy fixture
v7 operation inspect op-81 --events-after cursor-9
v7 deployment preview workshop --release package-7@0.3 --expected-epoch 8
v7 deployment activate workshop --preview deploy-preview-2 --operation op-82
v7 explanation export result-42 --format html --closure-preview export-preview-9
```

On conflict, compare base/current/proposed and make a new proposal; no force overwrite. On lost connection, inspect the same operation rather than resend under a new identity. Human output shows conditions/partiality/lifecycle; machine output preserves the agreed typed encoding. Exit status distinguishes transport, needs-input, failed check and inconclusive work.
