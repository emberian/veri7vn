# Workbench omissions audit

This source review supplies lifecycle/workflow requirements for C01–C05 and ACC-01–16. The [executed WB01–11 audit](../workbench/audit/README.md) distinguishes exercised boundaries from source inference. In particular, ordinary import rejects an examined archive's `exam_log.jsonl` before extraction; repeated imported-holdout execution was not reached.

## 1. Retention and retirement must constrain immutable-history reuse

Original `server.py:826–841,974–1006` supports opt-in journal, conversation deletion and temporary recall (default seven days, configurable 1–365). `sources.py:372–409` quotes dated historical answers. Cached pronoun dispatch precedes expiry filtering (`server.py:417–431`); deleting a file does not clear subject/core memory, journal or derived draft examples.

Apply current authority at every invocation/adoption, including restored/cached handles. Separate retire, revoke, Forget and explicitly curated copies. Propagate dependencies through examples, feedback, summaries and indexes; minimal tombstones contain no snippets. Test expiry/deletion during follow-up and pending publication. Owners: effects/updates/lifecycle/workspace; PO-08/09/10.

## 2. Empirical qualification is a product workflow separate from proof admission

`exam.py:145–224` compares baseline/composed answers, false assertions, wrong answers, interception, identity behavior and latency. Holdout exposure is written before execution; crash spends it. Source checks (`270–318`) instead repeat readback/routing probes.

Keep semantic admission, operational qualification and activation distinct. Receipts bind baseline/candidate, routing, learned state, scorer/panel/split, runtime, source/state and exposure. Imported sender evidence is not recipient freshness; repeatable regression is permitted (D23). An abort is not a measured verdict. Packaging includes the exposure log but upstream import rejects its extension (WB04); repair intake without deleting attributable exposure. Owners: lifecycle/admission/client/performance.

## 3. Gaps-to-authoring and guarded fallback need first-class workflow semantics

`server.py:509–557` groups opt-in declines and copies questions into new examples with blank answers. `exam.fillable` permits missing-reading fallback but protects false-premise/same-name/reference guards; addressed local readers may precede core.

Preserve original request/reason/private origin; represent unknown expectations explicitly rather than blank-but-valid ground truth. Define continuation per scoped blocker. Demonstrate decline→draft→reviewed source→qualification, plus a guard an overbroad extension cannot evade. Owners: dialogue/interpretation/assistance/workspace.

## 4. Connector onboarding and qualification themselves can execute effects

MCP save starts probes; `exam.py:281–289` calls `reply`; `mcp.py:252–271` invokes `tools/call`. Even `takes` may discover schema. Argument filling guesses Boolean/integer values; schema caches lack version checks.

Connect/discover/preview/probe/qualify/poll require selected target/operation authority, secret references, schema/configuration identity, validated arguments and cancellation/retry contracts. Discovery or read-only annotation grants no execution authority. Use fixtures or authorized probes. Test a qualification tool that increments a counter. Owners: connectors/effects/sources.

## 5. Feedback adaptation must publish a new policy, not mutate a live one

`mcp.py:201–214,274–287` changes keyword credit/suppression immediately; `server.py:957–968` then requalifies asynchronously. Credit/probes are excluded from `files_sha`; non-MCP feedback only says noted.

Retain result/invocation-linked feedback, distinguish factual/reading/tool correction, propose a policy revision, evaluate and publish atomically. Failed evaluation keeps prior policy; undo makes another version. Test running old/new requests and learning-derived Forget. Owners: growth/updates/connectors.

## 6. Sensors require an ingestion protocol, not only timestamped result fields

Sensor add polls/starts before qualification. MQTT cached-message time becomes a new poll timestamp; origin is read from current configuration. Aggregates ignore configuration/unit partitions; trend is endpoint difference. The 24-hour setting is a query window; physical pruning is conditional on 4 MB.

Retain event/receipt/evaluation clocks, sequence, raw payload, mapping/calibration/quality/unit/config/origin per observation. Define duplicate/late/invalid/stale policies, aggregate population and actual retention. Removal stops/joins resources and rejects late publication. Test old-message repoll, changed authentication/configuration, mixed units and invalid latest/last-valid. Owners: sources/connectors/effects.

## 7. Resume/recall/action replay are distinct operations

`server.py:448–459` warms context by re-executing two previous questions; specialist answers separately update subject/core state. Restore versioned accepted state without execution; recall quotes historical scope; execute-again is a new request. Reconnect after one mock action must keep its effect count one and retain the accepted referent. Owners: host/effects/dialogue.

## 8. Transfer, verification, registry, code runner and Film need explicit dispositions

Local hash verification and optional chain attestations establish integrity/attribution, not domain truth. Export selected classified closure, not merely all files from a non-source specialist. Credentials/private history/gap-derived examples require explicit handling. D16 governs external registry/media scope; the native capability registry is separate.

`run_code` uses Python `-I`, temporary cwd and ten-second timeout: useful scratch execution, not filesystem/network isolation or proof. Film exports selected turns/routes as local WebM; optional narration/illustration is remote. Marker stripping and 700-character narration can lose evidence. Export full conditions, historical status and provenance in a companion explanation; decoration stays labeled. CLI/UI share authoritative operations while exposing honest surface differences.

## Minimum additions before the respective implementations

Use one lineage for editable source, candidates, qualification, admission, releases and deployment. Close retention/derived-copy rules, scoped fallback, effectful onboarding, versioned feedback and artifact export through actual consumers. Preserve the author loop; a theory editor alone does not migrate scratch, gaps, recall or Film. The [acceptance matrix](../product/ACCEPTANCE.md) and task ledger remain completion gates.
