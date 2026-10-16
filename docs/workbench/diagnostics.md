# Diagnosis and reviewable repair

The browser and resident CLI explain the outcome returned by the resident service
using `src/diagnostics/Diagnostics.scala`. Accepted HTML still comes only from the
resident's licensed result path. The presentation cannot mint a result, evidence,
or a selected interpretation. Unknown status tags produce an unavailable diagnostic.

Budget exhaustion and observer timeout are inconclusive. Undefined mathematical
operations are domain declines. Worker and handoff failures are execution failures,
not refutations or automatically admission failures. The current native `cancelled`
status means the request is not live: cancellation and retired dependencies are not
distinguishable in that tag. The explanation preserves this limit. A source edit or
new request does not bypass the native gate.

## Owner inspection frame v1

`RequestInspection.scala` defines a closed bounded YXML frame for local owner
inspection. It describes actual native object associations and is not a proof
certificate or execution capability. The initial family is explicitly mathematics.
Native producers must use `Request.project`, `Request.selected_index`, the selected
`Language_Input.resolve` slices, `Literals.offsets`, and `MathEntry.execution`.
The last is an execution identity, **not** the opaque native ticket.

The root `veri7vn-request-inspection` has exactly `version=1`, `family=mathematics`
and `status`. Its first child, `identity`, has exactly `request`, `goal`,
`interpretation`, `decision`, `capability`, `operation`, `semantic_generation`,
`executable_generation`, and `execution`. All are positive native IDs. The second
child is `reading` with `index`, `operation`, and `input_bytes`, containing exactly
two `literal` children with original physical byte `start` and `stop`. Operation
names are `sum`, `difference`, `product`, `quotient`, `subtract_from`; these names
describe the selected mathematical reading and are distinct from operation IDs.
An inaccessible reading instead has `reading-unavailable` with `reason=released`
or `reason=not_retained`, or `reason=invalidated` while authority is denied but
cleanup has not completed. Invalidated does not claim physical erasure. No original input payload, private native context,
or unrestricted dependency/source dump is included.

The parser rejects duplicate, missing, or extra attributes, unexpected children,
unknown family/version/status/operation, foreign request identity, excessive size,
and out-of-bounds or overlapping literal ranges. Frames are parsed only as
inspection. The recipient result path remains the separately licensed rendering.

The native `inspect_request` producer in `native_service.ML` and the host
`ResidentAuthorityService.requestInspection` adapter implement this frame in
source. Native result polling and inspection share `result_view`. Source wiring
alone does not qualify the resident or its restored-image consumer; those require
the actual service checks below.

This first schema does **not** claim to expose an assumption audit, source coverage,
source dependency graph, failed theorem span, or change-impact closure. These must
come from their actual native/host producers. Lack of those fields never means an
empty premise set or complete source coverage. The parser and synthetic codec
tests do not establish that a resident producer is integrated.

## Repairs

`Repair.propose` takes an existing captured source revision, original byte span,
replacement, diagnostic category, review reason, and an explicit meaning choice:
preserve meaning, restrict domain, change specification, or unresolved. It validates
the proposed patch through `Intake.patch`, including UTF-8 boundaries, without
writing anything. Its source text remains development material. For example,
changing `sqrt (x*x) = x` to `sqrt (x*x) = abs x` changes the specification; adding
`x >= 0` restricts the domain. Neither text edit establishes the theorem.

Applying a proposal calls the existing `ManagedDrafts.edit` with its captured
manifest and revision and exact original bytes. Conflicting current revisions
reject the edit. Managed Forget makes subsequent application unavailable. A saved
repair creates an inert source revision; the normal build, native admission,
qualification, and publication workflow must validate it before activation.
There is no parallel repair database, automatic journal collection, synthesized
ground truth, or alternate admission operation.

`tests/diagnostics/check.scala` checks outcome distinctions, owner-frame rejection,
and a real managed source repair with a Unicode prefix, stale revision conflict,
and Forget. The theorem-like source in that storage test is not built or proved.
The browser/CLI presentation and actual resident inspection need their own
consumer checks; a codec test is not native integration evidence.

`tests/runtime/service/inspection.scala` runs the actual owner-frame producer
through a resident, verifies exact selected reading and original byte spans,
checks an undefined quotient and an explicitly corrected new request without
rewriting the historical decline,
restarts with a nonempty checkpoint and compares all provenance, and checks that
cancellation and Forget withhold readings and HTML. The durable sequence check
detects workflow replay on restore. `tests/workbench/client/resident.scala`
additionally exercises the browser's licensed rendering and owner inspection.
These scripts define refuting checks; their presence does not assert a passing run.

The source-only diagnostic check passed in stable attempt
`d4eb383ddd55481d96d92cbbeecb0f31` (session scope `95fcfdd61e543422`). Its archived
`scala.log` records `DIAGNOSTICS_PASS` and script exit 0; the receipt reports stable
inputs. The same batch passed source-only authoring and compiled the host/UI
package interface. This establishes the parser and managed repair checks above,
not execution of the new native inspection producer or a proved source repair.

## Native build failures

`BuildFailure.scala` implements the agreed D43 failure frame. The closed phases
are replay and export, corresponding to native `NativeReplay` and `NativeExport`.
Their presentation codes are `build.replay_failed` and `build.export_failed`.
They report a failed build phase; neither identifies a false theorem or supplies
an inferred logical obligation. The associated native message supplies the
reported reason when governed source access permits revealing it.
The frame binds positive native `source_revision` and `manifest` identities, an
optional original physical byte span, and a text message. Absence of a reported
span is explicit. Oversized messages are explicitly unavailable rather than
silently truncated. Limits are 8192 UTF-8 bytes per frame and 4096 UTF-8 bytes per
message; structured markup in a message is rejected.

Those native identities are **not** managed editor revision hashes or manifest
locators. The host must join the failure to the same live or retained governed
captured input and check its original source span against actual source bytes
before highlighting or preparing a repair. A caller-supplied path or matching
numeric ID cannot establish this association. Historical inspection remains
read-only; build and revalidation require a current source binding.
An inspected view's `hasCurrentSpan` permits seeding a tentative source review
only when its exact captured manifest/revision matches the inspected editor head
and a native source position exists. Historical positions are never rebased
automatically. Applying the review still checks its captured draft head.

The decoder does not grant source access, create a diagnostic database, or infer
an empty premise set from omitted fields. The D43 native producer and governed
host join remain separate integration prerequisites. Stable attempt
`012b2a2987b94f449337a51985bd130d` (scope `95fcfdd61e543422`, 21.979 s) passed the
current `BUILD_FAILURE_CODEC_PASS`, `DIAGNOSTICS_PASS`, and source-only authoring
checks with stable inputs. The new native build-failure producer and source-owner
join are not covered by this source-only check.

## Package change impact

The package inspector links to **Inspect affected package declarations**; the
shared CLI provides `impact PACKAGE`. These are read-only consumers of
`PackageUpdates.Consumers.affected`, not a second dependency ledger. The graph
comes from actual inspected package descriptors and matches exact package IDs
and release versions. Each affected package includes a path back to the selected
package and its inspected source revision.

The view states its declaration-level scope. Missing providers, unavailable
descriptors and multiple drafts declaring the same release are explicit issues.
Ambiguous provider edges include each possible provider; they do not select a
winner. An unavailable target produces **impact not computed**, not an empty
affected-set claim. The inventory is bounded to 8192 drafts, 65536 declared
edges, 65536 expanded provider edges and 65536 explanation path nodes. Provider
expansion is checked before allocating edges; one reverse traversal records
deterministic path predecessors. The existing shared planner still determines
the affected set. Output paths are budgeted before materialization. Overflow
rejects the whole view explicitly instead of returning a partial or empty claim. Heads are read
individually; reinspect after edits. The view does not predict replacement-source
contents, native result invalidation, running requests, or physical erasure.

The native request inspector separately exposes its information limits:
assumption audits, source coverage and runtime dependency impact are not yet
projected. No missing field is treated as an empty premise list or complete
coverage.

## Original build source positions

`SourceDiagnostic.locate` runs inside the host's governed retained-source
callback. It checks the original captured size and SHA-256, validates physical
UTF-8 span boundaries, and returns path/revision, line/codepoint columns and
Current/Historical/Unknown status. It returns neither source text nor a borrowed
buffer; position decoding uses a bounded 1024-character scratch buffer that is
wiped on return. The host must first validate the native failure's request/prepared/source
association to that same owned input. Editor positions never come from whichever
source happens to be current. The formatter and its fixtures do not establish
that missing D43 association producer.

Stable source-only attempt `ba9d4813388f4a43a9a7467c3c7907f0` passed actual
authoring HTTP/CLI impact behavior, the source formatter, and diagnostic checks
(21.288 s, stable inputs). Review then found the ambiguous-provider expansion
and repeated path-traversal bounds gap. The expanded-edge and path-budget fixes
and dense/long-chain countercases passed in stable attempt
`aefbaca838584a09a36b41303bc8275a`: authoring and diagnostic scripts both exited
0. Its aggregate receipt failed on the third retained-source fixture's payload
reservation before callback checks. That fixture's archive read bound was then
corrected to its intended 64 KiB; the first two passing scripts remain distinct
from that failed combined receipt. The retained-only retry
`8b947c73207e4f01b2180e8fadab34f9` passed with stable inputs in 23.331 s and
`RETAINED_SOURCE_DIAGNOSTIC_PASS`. This qualifies the live governed callback,
original Unicode positions after an edit, historical revision pins and Forget
denial. It does not qualify the native-ID join or a reconstructed source lease
after process restart.

`tests/diagnostics/retained.scala` exercises the actual governed captured-source
callback after a source edit: the location remains attached to the original
Unicode source, and Forget denies the callback. Its diagnostic IDs are fixture
data, so it does not qualify the separate native-ID association producer.
