# Workbench omissions audit

Read-only source review, 2026-10-15. Compared the shipped `upstream/workbench`
implementation with C01–C05 revision 0, ACC-01–ACC-16 and `project/tasks.json`.
No upstream code was imported or executed; no service was contacted. Findings below
are source-derived behavior, not exercised demonstrations. Paths and line numbers
refer to this checkout. This report proposes decisions; it does not change scope.

The design already covers native admission, observation/state pins, effects,
package transfer, diagnostics and a coherent UI/CLI. `workbench-audit` explicitly
tracks most original features. The omissions are decisions needed to make those
broad commitments implementable, especially retention, empirical qualification,
adaptive routing and connector operation lifecycles. They do not justify replacing
the native design with the Python implementation.

## 1. Retention and retirement must constrain immutable-history reuse

**Enabled upstream:** opt-in journal recording and clearing (`server.py:826–841`),
conversation persistence on/off and deletion (`server.py:974–985`), and a temporary
conversation specialist, default seven days, configurable 1–365 (`server.py:986–1006`).
Recall quotes the historical answer with date and route (`sources.py:402–409`);
`takes` requires an explicit recall question (`sources.py:393–400`), despite the
class docstring also advertising repeated-question interception. Removing the
conversation file empties that reader's cached turns on its next load
(`sources.py:372–381`). This is useful behavior to preserve deliberately.

**Actual defect:** pronoun follow-ups invoke a cached specialist before the expiry
filter (`server.py:417–431`). A specialist that expires while loaded can still answer
through that path. Conversation deletion does not clear `Workbench.last`, the core
session or the gap journal. Clearing the journal also cannot undo questions already
copied into a draft's development examples (`server.py:553–556`).

**Design gap:** C04:18 and :68 preserve old pins and historical meaning; ACC-14 and
`package-lifecycle` exclude accidental private transfer. Neither defines managed
deletion, retirement, retention classes, or the relationship between them. Immutable
identity must not imply perpetual payload retention or authority to keep executing
a retired capability. Recommend explicit lifecycle states and a current authority
check at every invocation/commit path, including follow-ups and cached handles.
Distinguish retiring execution, deleting managed source/history payloads, retaining
a non-content tombstone/receipt, and explicitly exporting material. Track derived
dev examples, feedback, summaries and recall indexes so their retention treatment
is reviewable. Define cancellation/revocation for already pinned work; old proof
meaning may remain valid while access or new effects are disallowed. Do not promise
erasure of external recipients' copies or public commitments.

**Owners/check:** `state-effects`, `dependency-updates`, `package-lifecycle`,
`workspace-interaction`; add delete/expire during a follow-up and pending effect,
then inspect managed derived stores and export contents.

## 2. Empirical qualification is a product workflow separate from proof admission

**Enabled upstream:** authors edit organ, manifest, panel and scorer. Development
tests repeat; held-out panel hashes are single-use, recorded before execution so a
crash spends the set (`exam.py:145–162`). Qualification compares core with the
core-plus-specialist, measures gain, false assertions, wrong answers, interception
of general questions, identity behavior and latency (`exam.py:169–224`). Source
readers instead use repeatable readback probes and routing checks
(`exam.py:270–318`). These are different evaluation protocols, both currently called
`ADMIT`. A proof of an operation's stated semantics does not replace testing whether
its language binding selects the right question or improves the composed product.

**Concrete transfer defect:** packaging includes every non-pycache file
(`server.py:568–576`), including `exam_log.jsonl`. Import renames verdicts but retains
that log (`server.py:602–611`). The advertised recipient rerun of the same held-out
set then hits the already-used hash check (`exam.py:153–156`). Simply deleting the
ledger would lose useful evidence of evaluation exposure.

**Design gap:** C02 correctly denies tests theorem authority. C01 connects examples
and evidence, but no contract specifies evaluation records, panel exposure policy,
repeatable regression versus fresh qualification, or readiness-to-activate policy.
Recommend separate native semantic admission, operational qualification and active
publication states. Evaluation receipts should bind candidate and baseline
generations, binding/routing policy, dataset/split, scorer, source/state observations,
resource environment and exposure history. Keep sender evidence distinct from
recipient evaluation. Decide whether single-use holdout discipline is preserved,
replaced or optional; do not inherit the import contradiction. Record an explicit
aborted/spent result rather than treating a crash as measured failure or success.

**Owners/check:** `package-lifecycle`, `native-admission`, `workspace-client`,
`performance-envelope`; transfer an already examined package and exercise both
repeatable regression and whatever fresh qualification policy is chosen.

## 3. Gaps-to-authoring and guarded fallback need first-class workflow semantics

**Enabled upstream:** the journal groups non-answers by decline reason and recurring
words (`server.py:509–538`); a selected gap seeds editable development examples with
blank answers (`server.py:541–557`). This is a concrete author growth loop, beyond
asking a solver to prove an existing obligation. Journal enablement/clearing is a
user operation, not automatic collection implied by chat.

Fallback is deliberately restricted to missing readings, excluding false-premise,
same-name and unresolved-reference guard paths (`exam.py:56–64`; application at
`server.py:463–470`). Separately, addressed local sources take precedence before the
core (`server.py:427–447`). A single indiscriminate “try next specialist on decline”
rule loses this distinction; a single global pre-core rejection would also change
legitimate local-source behavior.

**Design gap:** C03 has outcome categories, but no continuation/authority policy
specifies which non-answer permits another interpretation, another source, a
clarification, or no fallback. `authoring-assistance` tracks proof/search/repair but
does not yet require discover-gap → inspect original request/reason → create
proposed binding/specification/examples → validate composed behavior. Recommend
structured decline reasons plus an explicit routing continuation policy, and
record journal-derived examples as proposals with origin and retention class.
Do not manufacture ground truth from an unanswered request or blank expected value.

**Owners/check:** `routing-dialogue`, `interpretation-model`,
`authoring-assistance`, `workspace-interaction`; demonstrate a missing-reading
extension and a guarded decline that an overly broad extension cannot override.

## 4. Connector onboarding and qualification themselves can execute effects

**Enabled upstream:** selecting MCP tools creates a source reader and starts probes
(`server.py:946–956`); readback probes invoke `sp.reply` (`exam.py:281–289`), and MCP
`answer` directly calls `tools/call` (`mcp.py:252–271`). Thus qualification is not
necessarily observational or harmless. The general-lane check uses routing-only
`takes` when available (`exam.py:295–304`), but it does not make the readback probes
safe. `takes` can still discover schemas via the server (`mcp.py:196–221`). Argument
filling is heuristic and handles required properties only; booleans default from
negation words and integer inputs truncate floats (`mcp.py:224–250`). Tool schemas
are cached once per object, with no version check (`mcp.py:196–199`).

**Design gap:** C05's authority boundary is sufficient in principle; the missing
mapping is that connect/discover/test/qualify/requalify/poll are operations under
that boundary too. Specify credential references separate from transferable
packages, connector identity/schema versions, declared operations and target
authority, argument validation, cancellation/retry and admission of changed schemas.
Discovery is not authorization to call every discovered tool. An external server's
read-only annotation can inform policy but cannot prove absence of effects. Use
fixtures or explicitly authorized probes for qualification. The capability claim
for an opaque external response can be “this server returned this payload under
these observations”; stronger domain assertions need their own assurance route.

**Owners/check:** `stateful-connectors`, `state-effects`, `source-import`; qualify
a mock connector whose tool increments a counter and prove/check no test or
feedback path executes it without the selected authority.

## 5. Feedback adaptation must publish a new policy, not mutate a live one

**Enabled upstream:** right marks add question words to a tool's vocabulary; wrong
marks remove words; three wrong marks, exceeding right marks, suppress that tool
(`mcp.py:201–214`, :274–287). Only MCP tool specialists actually learn; other marks
return “noted” without comparable adaptation (`server.py:957–968`). Feedback writes
`credit.json` before asynchronously rerunning the saved source probes. Routing reads
that file on each call. Credit and probes are excluded from `files_sha`
(`exam.py:47–53`), so changed behavior can coexist with the prior admitted identity
and can be observed before requalification finishes. Requalification can repeat
actual tool calls as described above.

**Design gap:** C04 already requires ranking changes to create a generation and
C05 prohibits alternate publication. Apply those rules explicitly to user marks:
append an attributable feedback event linked to the actual request/result/tool
invocation, propose a policy update, evaluate it without unauthorized effects,
publish atomically or keep the previous policy. Separate feedback about factual
correctness, intended interpretation and tool choice; a “right” mark is not a
proof. Define correction/undo and retention for learning-derived material.

**Owners/check:** `synthesis-growth`, `dependency-updates`, `stateful-connectors`;
mark while a request is running and verify old/new requests retain distinct routing
policy identities, with failed evaluation leaving the working policy active.

## 6. Sensors require an ingestion protocol, not only timestamped result fields

**Enabled upstream:** HTTP/MQTT/serial/file/simulated sources feed background polling;
adding a sensor performs an immediate read and starts the poller before checking the
reader (`server.py:1011–1037`; `sensors.py:344–372`). Rows retain value, unit, validity
and source; invalid latest readings leave a last-valid value available
(`sensors.py:304–320`, :407–428). The “24 hours” limit is always a query window but
physical pruning only runs above 4 MB (`sensors.py:318–320`, :324–339).

**Concrete semantic defects:** MQTT returns the cached message time only in a source
string (`sensors.py:235–236`), then polling stamps a new `now` on the same message
(:304–313). Freshness uses that polling time (:418–419), so repeated polls can make
an old source message appear fresh. The measured/simulated label comes from current
configuration (:399–403), not each stored observation. Aggregates group by quantity
and use an unweighted sample mean (:407–426); configuration/unit changes are not
partitioned, and “last hour trend” is endpoint difference, not a fitted rate.

**Design gap:** C04 already distinguishes clock bases and observation sequences.
The connector model should instantiate source event time, receipt/poll time,
sequence/deduplication identity, raw payload reference, mapping/calibration/quality
policy version, units and simulated/measured origin per observation. Decide handling
of duplicates, late events, invalid values, stale last-valid reads and unit/config
changes, then specify aggregate population/window semantics. Define start/stop,
configuration replacement and removal as resource lifecycles, with no late worker
recreating deleted history. These requirements do not require a distributed stream
engine initially; a small explicit ingestion state machine suffices.

**Owners/check:** `source-import`, `stateful-connectors`, `state-effects`; repeated
old MQTT sample, mixed-unit configuration change, invalid latest reading, and removal
during a pending poll are required local fixture cases.

## 7. Resume/recall/action replay are distinct operations

**Enabled upstream:** when warming a session, the workbench re-executes the last two
answered core questions and discards their new responses (`server.py:448–459`). It
does not restore the recorded answers/state. Source-specialist answers separately
update both workbench subject memory and the core's conversation context
(`server.py:473–490`). This can change interpretation on reconnect; an effectful
core question would be executed again. The source alone does not establish that a
particular real external effect has actually been duplicated.

**Design gap:** `runtime-service` already requires reconnect/replay checks and C04
pins state. Specify read-only transcript recall, restoration of accepted session
state, and an explicit new execution as separate operations. Restore state using
versioned transition receipts/checkpoints, with idempotency identities for actions;
do not reconstruct a session by asking its natural-language questions again.
Deletion/retirement in finding 1 must also constrain restored sessions.

**Owners/check:** `runtime-service`, `state-effects`, `routing-dialogue`; reconnect
after one mock action and verify its effect count remains one, while follow-ups
retain the accepted referent and historical-source distinction.

## 8. Transfer, verification, registry, code runner and Film need explicit dispositions

**Enabled, distinct assurance surfaces:** install verification recomputes release
part hashes and reports changes/missing/extra parts (`verify.py:63–88`); optional
anchor checking searches a transaction for the published root (:91–113). Registry
fingerprints bind files/verdict/heldout/release (`registry.py:43–70`); wallet-signed
registration/attestation is implemented in the UI (`static/app.js:494–520`), not
just advertised. Checks primarily compare file and verdict hashes
(`registry.py:164–200`). These are integrity/attribution evidence, not native proof
or independent truth validation. ACC-14 explicitly leaves external registry scope
for a decision; preserve that decision and distinguish it from our native capability
registry. Package transfer excludes all `source: true` readers (`server.py:564–565`),
but a non-source package can include journal-derived questions or other arbitrary
local files. Use classified, selected export contents rather than a source boolean.

**Enabled author tools:** `/api/code/run` executes arbitrary authored Python and
tests with `-I`, a temporary cwd and a ten-second subprocess timeout
(`server.py:658–668`, :1089–1090). This is not a filesystem/network sandbox, nor a
verified compiler. Decide its native replacement or explicit disposition; don't
silently count the expert theory editor as preserving this exact experimentation
workflow.

**Enabled Film:** selected answers/routes are rendered into a local browser WebM;
optional illustration, narration and sound call a remote provider
(`static/app.js:325–359`; `server.py:897–939`). Generated images have an explicit label
(`static/app.js:370–377`). Answer cleanup strips evidence markers (:313–314), and
narration truncates at 700 characters (:345), so export fidelity needs more than
capturing the screen. Film belongs to this workbench, not to a separately investigated
sibling system. Recommend a deliberate preserve/repair/defer row: a useful replacement
is a shareable derivation/execution explanation bound to a result receipt, preserving
conditions, uncertainty and historical status, with generated decoration separately
labeled. Any remote narration/illustration is an explicit export/effect operation;
it must not inherit permission merely from local playback or authoring.

**Coverage gap:** `workbench-audit` includes broad UI/CLI and registry coverage but
does not name Film or arbitrary code experimentation. CLI shares answering core
(`cli.py:47–64`), yet does not mirror every UI mutation, and its ask path does not
write the gap journal as the HTTP path does. “Coherent UI/CLI” should mean shared
authoritative operations and explicit capability coverage, not an unverified claim
of existing parity. Add workflow rows for these surfaces before closing ACC-02/14/15.

## Minimum additions before the respective implementations

1. Retention/retirement/export policy reconciled with generation pinning and session
   restoration, including derived private data and late workers.
2. Separate qualification/evaluation records and activation policy, including
   recipient evaluation and gap-derived examples.
3. Connector operation lifecycle and schema/effect authority, including test paths;
   versioned feedback publication and sensor ingestion semantics.
4. Typed fallback continuation policy and workflow dispositions for Film, code
   experimentation, release integrity and public registry.

These are focused elaborations of existing tasks and contracts. Most can be accepted
as explicit design decisions now and refined into representation choices in their
own lanes. They should not be left to independent implementers to infer differently.
