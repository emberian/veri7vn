# Workspace interaction design

2026-10-15 · authoring61 · workspace-interaction · consumes C01/C03/C04 and
D12/D20–D29. This is a reviewable interaction design, not an implemented native
client, accepted theorem path or recipient usability trial.

Open `design/workbench/index.html` as a local file for the offline prototype.
It contains thirteen navigable, source-backed walkthroughs; no external assets,
network requests, package execution or deployment. Regenerate with
`python3 design/workbench/render.py`. The scenario records are display fixtures,
not package descriptors or a second semantic source. The supported source remains
canonical `.thy` recipes and expert blocks. Proposed CLI spellings are illustrative;
common wire encoding remains reserved for integrated native client review.

## One understandable workspace

The ordinary entry is an existing workspace, its active capabilities and a question
box. A result offers **Inspect**, **Improve**, **Explain/export** and context-specific
**Correct** actions. Improve opens the same development package used by Build;
it does not create another registry. A left navigation gives Questions, Packages,
Sources, Gaps (off until enabled), Scratch, and History. The preview's navigation
lists walkthroughs for review instead of pretending to be a working application.

The package header always identifies four different objects: editable source
revision, immutable release if any, deployment in this workspace, and private
bindings. Three separate readiness labels show **Math check**, **Example checks**, and
**Use**, corresponding to native admission, operational qualification and deployment.
Precise statuses and terminal commands are available in collapsed Advanced details. There is no universal green “verified” badge.
An admitted reader can report contradictory rows, an empirically useful scratch
program can have no proof, and a fully qualified release can remain inactive.
Each label opens exact scope, policy, dependencies and outstanding obligations.

For a beginner, Create asks what to do, picks a supported recipe and offers an
editable example. Formula fields show domain, units and expected behavior; readers
show source schema, selection and treatment of ambiguous/missing rows. “I do not
know yet” is a first-class expectation. The example can be saved and run as an
exploration but cannot count toward a passing expectation. A proposed model answer
is marked proposed until the author/source explicitly selects its status.

Expert source is one click away with diagnostic spans. Forms operate only on
recognized recipe commands; opaque theory blocks stay visible and editable in the
expert view. A source edit increments the same package revision, updates parsed
views and invalidates old patch proposals. An unsupported expert construct gets
an honest source-only view rather than destructive normalization.

## Canonical source editing and recoverable concurrency

The form renders a read-only projection obtained from native parsing: recipe kind,
source span, base source revision and resolved declarations. Editing a field asks
for a source patch proposal. The preview shows exact old/new text, meaning/domain
changes, generated obligations and affected consumers. The author applies that
patch against the expected revision. The host/native development service validates
its target and commits a new source revision; client projection fields grant no
authority and are not saved as independent editable semantics.

Positions use the source document's declared encoding and a native position mapping.
The UI must not reinterpret PIDE offsets as JavaScript UTF-16 indexes. Patch identity
includes document revision and expected original span text/digest; a recipe locator
alone cannot authorize replacing changed content. Multiple edits in one proposal
use one base revision and explicit atomicity; no partial source replacement.

A concurrent expert edit produces “This source changed since you opened the form.”
Show base/current/proposed diff, preserve both drafts and request a newly parsed
proposal. Rebase only after parsing the current document and obtaining a fresh
proposal. Never overwrite or silently merge formula meaning. Malformed theory
source remains durably saved as a development revision with diagnostics; it does
not replace a working deployment. The editing service needs controlled privileged
native-development policy where arbitrary Isar/ML is involved.

Growth cost is visible beside the patch: recipe/config/data updates reuse the
compiled finite bundle when representable; new carriers/kernels/code setup stage a
new bundle. Adding an ordinary theorem may require checking without rebuilding the
executable bundle. Do not promise zero validation cost or automatic compatibility.

## Closed author loop

1. Enable the private gap journal explicitly. Inspect an original unresolved request,
   its interpretation alternatives and scoped reason. Select one or a cluster.
2. Create a draft recipe and retain selected questions as origin-linked unknown
   expectations. Set an expected result, property, clarification or permitted decline.
   Show whether copying private examples into curated package material is intended.
3. Edit canonical source, inspect generated meaning and run examples. A missing
   premise offers supplying it, adopting a scoped source premise, or changing the
   specification. None of these are silently equivalent.
4. Build/admit the promised route, then qualify composed behavior with named baseline,
   regression/interference cases, scorer, resource environment and exposure policy.
   “Stop” cancels work; progress is not acceptance. An aborted exposed panel remains
   attributable exposure, not a measured failure/success or fresh set.
5. Profile a representative workload. Compare startup, admission, interpretation,
   acquisition, search, execution, checking, rendering, memory, I/O and evidence size.
   Preserve workload/toolchain/sample identity. An optimization makes a new candidate
   plus preservation obligation. Measurements do not discharge the obligation.
6. Create a release from exact source/dependency closure. Preview deployment impact,
   missing bindings, qualification/assurance requirements and current epoch. Activate
   through the shared authority/durable host. Only a durable committed response
   changes the active label. Running requests retain their pins subject to retirement.
7. Collect attributed feedback from actual result/invocation identities. Distinguish
   factual correction, intended reading and tool choice. Propose a policy revision,
   evaluate without unauthorized probes, publish atomically or retain prior policy.
   Undo creates a new revision, with retention applying to learning derivatives.

The negative-square-root walkthrough deliberately presents two repairs:
`sqrt(x*x) = x` restricted to `x ≥ 0`, or all-real `sqrt(x*x) = abs(x)`.
A found counterexample is distinct from inconclusive search. The conflict walkthrough
shows both source rows and the licensed report about disagreement. The multipart
walkthrough retains area accepted, paint conditional and supplier unavailable;
no answer text is reparsed as a typed dependency. A truncated collection visibly
shows displayed prefix, total/coverage if known, ordering and exact claim scope.
Ambiguity opens alternatives before execution; a failed domain guard blocks its
reading while other justified readings can remain available under routing policy.

## Oracle7-original intake

Import recognizes Oracle7 original archives/directories as well as veri7vn releases.
Stage bytes without loading Python modules or invoking scorers. Preview manifest,
card/README, panel splits, scorer, organ, declared sources and sender exam history.
Report the original JSONL transfer incompatibility as an intake repair, not a reason
to discard the log. Reject traversal, unsafe links, duplicate paths, excessive size
or unsupported members with precise diagnostics and an intact existing workspace.

The mapping screen places original and proposed theory side by side. Known patterns
become recipe candidates with preserved versus repaired behavior labeled; paint
coverage is a concrete starter, not an assertion all Python formulas are supported.
Unknown custom organ semantics remain unresolved until a real native port and bridge.
A trusted scratch run can observe legacy behavior, but does not complete that lift.
Sender verdict and exposure remain attributed historical evidence. Recipient repeated
panels are regression; fresh generalization claims need fresh evidence. Selecting
**Create development package** establishes lineage to retained originals and mappings;
activation is a later operation after the relevant gates.

## Private sources, effects and recovery

Source setup chooses file/corpus, computer/SSH, MCP, sensor or conversation recall.
The package declares interfaces; private workspace bindings name actual targets and
secret references. Setup offers fixture/schema preview before real acquisition.
Discovery, readback probe, qualification/requalification and polling each show exact
operation, target, data leaving the workspace, permissions and retry/cancel policy.
A tool's read-only annotation is informative, not proof. Heuristic MCP arguments are
shown and validated; no guessed Boolean/integer conversion silently commits action.

Acquisition is configured → running → stopped/failed → retired. Reconfiguration
creates a new policy/version. Observation cards preserve source event time, receipt
and evaluation time, origin, unit/calibration/config, validity and coverage. “Last
valid, stale” differs from “fresh”; repeated polls cannot refresh event time. Sensor
retention settings describe actual managed deletion, not only query windows.

**Retire** previews blocked new uses and allowed retained inspection. **Forget** shows
transitive managed copies: transcript, snapshots, gap examples, learned features,
indexes, cached handles and pending dependent publication. Curated copies require an
explicit retain-or-remove choice, never a hidden exemption. Forgetting/revocation
cancels dependent pending publication and invalidates access; minimal tombstones carry
no snippets. External recipients/public commitments are listed as outside managed
erasure. Expiry takes the same current-authority paths, including cached followups.

History separates read-only recall, state restoration and execute-again. Restoration
loads allowed typed checkpoints/transitions and reports missing forgotten state; it
never asks old questions again. A disconnected client inspects committed operation
status. Unknown executor handoff enters reconciliation with attempt identity; neither
reconnect nor a Retry button dispatches it automatically.

## Scratch and explanation export

Scratch preserves editable code, tests, inputs, toolchain and actual observations
alongside open obligations. It is ordinary-user functionality. Worker policy says
trusted code unless a real supported isolation backend exists; `python -I` and a
temporary directory are insufficient. Promote proposes native development and its
bridge, not “tests passed → admitted.” New native code never runs as unrestricted
ML in the authoritative resident process.

Explain/export starts with a selected structured result/derivation. Preview full
polarity, conditions, historical time/status, sources and evidence before local HTML
or browser WebM. Video truncation links a full companion explanation; it cannot
silently drop premises. Graph/Film controls preserve selected turns, framing and
pause while hidden; rendering/codec compatibility needs implementation evidence.
Generated images remain labeled decoration. Export closure defaults to authored
public material and explicit result scope, excludes private payloads/feedback/gap
examples/credentials and shows omitted recipient bindings. A stale preview must be
recomputed if contents, classification or authority change.

Optional remote narration/illustration and public integrity/registry adapters have
separate destination/payload/permission previews. They are visible potential flows,
not default Film execution or startup dependencies. First-handoff inclusion remains
root D16 scope; no contact/upload is performed by this design.

## Accessibility, durable history and error treatment

All operations have keyboard access through labeled controls, visible focus, Tab/
Shift-Tab and Enter/Space; Esc closes a proposal dialog without discarding its draft.
Source editor shortcuts and command palette supplement ordinary controls. Do not
steal browser/system shortcuts. Errors are associated with fields and announced;
status uses text and icons, never color alone. Preview demonstrates Tab/Enter and
Alt+Right walkthrough navigation; actual editor/screen-reader trials remain open.

The CLI supports the same operations, structured result output and source locations;
noninteractive destructive/effectful commands require an already authorized concrete
preview/policy, never a hidden prompt that changes semantics. It can select parts,
show conditions, cancel and inspect jobs and export artifacts. Human output is concise;
machine output preserves all licensed structure and does not flatten partiality.

Durable history distinguishes source revisions, candidate artifacts, job observations,
releases and committed deployment changes. Source conflict preserves drafts. Build
failure preserves active release. Lost acknowledgement shows pending/reconciling,
not failure or success. Revoked content shows a non-content unavailable marker.
Diagnostics link original spans and proposed repairs; safe summaries omit secrets,
with explicit access to retained local details. Refresh never retries an action.

See `operations.md` for the shared operation proposal and `walkthroughs.md` for the
scenario/acceptance matrix and exact review evidence. Production workspace-client
remains dependent on integrated authority, host and canonical source interfaces.
