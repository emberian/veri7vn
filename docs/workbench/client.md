# Local specialist authoring client

The first client operates on the same durable managed source objects as package
intake. The CLI and local browser share `veri7vn.workbench.Authoring`; neither
creates a separate package database or treats imported programs as accepted.
The actual Scala/JVM consumer check passed in 32.903 seconds on the pinned
Isabelle2026-RC1/macOS arm64 toolchain. The stable receipt, logs and 23 exact
hash-verified input bodies are archived in
[`tests/workbench/client/evidence/authoring14-20261015`](../../tests/workbench/client/evidence/authoring14-20261015/receipt.json).

From the source checkout, the pinned toolchain can launch the caller with
`/Applications/Isabelle2026-RC1.app/bin/isabelle scala src/cli/launch.scala` followed
by the arguments below. This launcher compiles the shared client sources locally;
it is not a prebuilt end-user distribution. The launcher source compiled in the
same check; the CLI operations were invoked directly rather than nesting the
process-exiting command-line wrapper.
`veri7vn.cli.Workbench` takes a private workspace directory followed by a command:

```
WORKSPACE import-original paint upstream/workbench/examples/paint-coverage import-paint-1
WORKSPACE list
WORKSPACE inspect paint
WORKSPACE migration paint
WORKSPACE source paint organ_paint_coverage.py
WORKSPACE serve
```

The browser address is printed after `serve`; it binds only to loopback on an
available port. Keep that process open while editing, then press Enter to close.
One process owns the workspace lock. A separate CLI invocation cannot write into
an already-open browser workspace. A prebuilt packaged launcher is not installed yet.

Imports accept a bounded directory or ZIP. Directory paths and their ancestors must
be physical directories, not symbolic links; select the real directory path (on
macOS a temporary `/var/...` path may alias `/private/var/...`). The intake keeps
this protection rather than silently following a link. Original specialist programs are retained
without running Python. For the shipped paint specialist, migration inspection
recognizes its exact source and proposes the scalar formula, while identifying the
remaining parser, units, rounding, domain, native execution and evaluation work.
Original expected values and historical test material remain attributed data;
importing a folder named `heldout` does not create a fresh exam.

The package list is a bounded query of live managed source heads, with no separate
index. If the limit is exceeded it reports that condition rather than presenting a
partial list as complete. Forgotten or revoked drafts are excluded.

The browser shows actual source files. Saving sends the original exact bytes,
revision and edit token with the replacement to the shared managed edit operation.
A competing edit is rejected rather than overwriting custom work. The CLI's `edit`
command offers a half-open original-byte span:

```
WORKSPACE edit DRAFT MANIFEST REVISION PATH START_BYTE END_BYTE EXPECTED_FILE REPLACEMENT_FILE OPERATION_ID
```

Obtain the current revision and edit token with `inspect`. `EXPECTED_FILE` must
contain exactly the selected original bytes. Native `.thy` source remains editable;
custom proof blocks are preserved unless explicitly selected for replacement.
The edit token is a concurrency locator, not proof or admission evidence.

The initial surface does not run, qualify, publish, export or forget specialists.
Those routes require actual engine operations and, for protected exam material,
the canonical exposure transaction before a byte lease. Ordinary imported author
source is inspectable, with recipient freshness Unknown. There is no control that
reports a simulated successful run. Family execution and search callers must keep
actual typed partial results, source scope, budget stops and unresolved conditions.

The passing test uses actual managed native import/edit/reopen, a stale save, the
original paint specialist's eighteen panel cases, sorted live listing and overflow,
storage-forgetting list removal, CLI list/inspect, and actual HTTP form reads and
missing-token denial. It does not execute Python, load native theories, run a
specialist, qualify or publish. The HTTP surface has not yet had a visual or
independent recipient rehearsal, and the source-checkout launcher has not been
invoked as a separate process. These remain explicit checks rather than acceptance
of ACC-01 through ACC-03.

## Native build consumer contract in progress

The next workflow starts with the current draft, its exact edit token and source
revision, a selected theory file, ordered retained parent candidates, selected
canonical theorem names (possibly none), and an installed build profile. These are
user selections, not native authority. The host must validate them and capture the
actual immutable manifest and dependency closure under the existing source lease.
`NativeBuildInputs` owns materialization, inventory verification, memory and scratch
lifetime. The client receives no raw worker-source callback or unleased path.

The actual typed build service must reserve the artifact goal/output, durably charge
the bounded build and hand its one-use prepared build to the fixed native producer.
A successful construction is shown as a candidate; selected theorem admission is
reported independently. It does not activate the specialist. A changed head, revoked
parent, cancellation or forgotten source prevents adoption rather than replacing
those dependencies with whatever is current.

The intended CLI/browser sequence is import or edit, request build of that captured
revision, inspect backend diagnostics or the resulting candidate, restart the
workspace and inspect the retained candidate. There is no build control yet: the
D43 typed artifact route and the host's real service API are still being connected.
The current materializer's successful integrity inspection is not a build result.

Native diagnostics must identify the immutable manifest/revision, portable source
path and half-open raw-byte span. Positions relative to a retained native slice
must add the slice's original byte start exactly once. `SourceLocation` maps those
positions to a line and Unicode character column for display. It rejects locations
outside the captured file or inside a UTF-8 encoding. If the editor now has a
different revision, the diagnostic belongs to the retained build source; it must
not highlight unrelated text in the current file. Unsupported syntax remains an
unsupported-command diagnosis, false proof attempts remain proof failures, and
budget/cancellation are not mathematical counterexamples.

Restart inspection must resolve the actual durable candidate association and
reconstructed native ownership, including zero-export candidates. A historical
receipt, matching hash or source filename is insufficient. The client will consume
the host's concrete request/result types directly once available, without a second
candidate registry or a mock successful backend.

## One resident workspace

The resident workbench uses the runtime's existing workspace writer, managed
source store and native client. `ResidentWorkbench.run(service, commands)` exposes
`serve`, `run QUESTION [INTERPRETATION_INDEX]`, `result REQUEST_ID`,
`cancel REQUEST_ID`, `forget REQUEST_ID --confirm`, `list`, `inspect PACKAGE`,
and `source PACKAGE PATH`. The runtime launcher owns startup and restore; its
`--workbench` route selects these commands. Source-only `specialistWorkbench`
continues to support import and edit without starting Isabelle.

The browser imports and edits original source and expert `.thy` files. Inspection
shows the immutable revision and manifest and opens files directly. After a
successful save, the editor uses the newly committed revision so another save is
possible; a conflict preserves the proposed text for review.

The resident browser also submits exact question bytes to the installed mathematics
capability, shows the returned request ID and polls its authoritative status.
Keep the request ID to inspect it after reopening the same workspace. Licensed
native HTML is displayed in a sandboxed result frame. Cancellation and Forget wait for the exact durable native acknowledgement;
physical erasure follows the cleanup barrier. Refresh to observe the request status. Forget requires a
checked confirmation and removes the request's dependent retained results.

Package source edits and installed capability execution are separate operations.
The screen does not offer Build or Admit until D43's real artifact construction
API exists. The resident inspector displays the actual native request/goal/selection/capability,
semantic and executable generation identities, planned execution identity, selected
mathematics operation and original literal byte ranges. Those identities do not
assert that a planned execution was charged or completed. Released readings are
reported explicitly. Full dependency graph inspection and original input retrieval
remain open. Plain-language diagnostics describe only the status the native service
actually returned. They do not turn a failed or unrecognized status
into an answer or an admission failure.

`ResidentWorkbenchTests` is the actual HTTP-to-native consumer test for this route:
submit a question, poll licensed output, reject unconfirmed Forget, confirm Forget
and observe output withdrawal. Source-only authoring tests remain distinct from
that resident integration test and from a recipient usability rehearsal.

For a runtime launched with the matching packaged Isabelle classpath, append
`--workbench` after the workspace, images and session-root options. For example,
use `--workbench serve` to open the combined browser or
`--workbench run 'the product of 6 and 7'` for a bounded native request. The latter
prints the native request ID, waits up to one minute and returns an unsuccessful
command outcome when no accepted result is available. Reopen with
`--workbench result REQUEST_ID` to inspect that durable request. `--workbench`
consumes the remaining arguments, so put runtime options before it.

The combined browser's Run action first asks the fixed native routing inspector.
A unique actual reading runs immediately; multiple readings show native indexes
and require an explicit choice. The client retains the exact original bytes for
that choice for up to five minutes, then wipes them. Closing the workspace also
wipes unresolved choices. Native alternatives currently lack human-readable meaning
previews; the UI does not infer them from answer text or guessed grammar rules.

Qualification boundary: current source-only authoring passed in immutable attempt
`3980963f1e114f49bc6968a0bcf63a83`, including browser preview/apply/cancel,
modified-review/stale-source/Forget rejection, repeated saves, paint migration,
and actual CLI edit/reopen. Assistance checks passed in
`770bfffd9ee643f789a46f7f9be7751a`. Independent source JAR production passed in
`90c8b77b61b34cbf974d3d33db8ad0cd`, compiling immutable captured source and
class-loading the actual Workbench entrypoint. This did not start the native heap.
Installed source CLI execution passed against generation `8cb3859a898e4a20df58d8a9ad5b183dbf3600a17a08c0c5a2de3ebef3c7f41c`:
four fresh JVMs imported, inspected, edited and reopened exact source bytes. Its
result is `var/deployment-source-check-0006b59c-slot2/result.json`; this check does
not qualify the installed browser or native admission. The combined native browser consumer passed in
`ccf79120fc7744b196fd268d69548f32`: real resident CLI import/edit and browser source
inspection shared one store, followed by native routing, licensed result content,
request provenance, redirect/reload and confirmed Forget. This qualifies the fixed
mathematics consumer, not every specialist family. Build diagnostic repair still requires
the host's protected original-source association and D43 service operation.

Native Run, selection and lifecycle submissions redirect to the retained request's
read-only URL. Reloading that page inspects the same request instead of submitting
and charging another one. The resident browser test checks the redirect and reload
boundary separately from licensed result content.

## Reviewed source changes

An open source file offers **Review a source change**. Name the work item, choose
obligation/condition/proposed example, state whether meaning is preserved, the
domain is restricted, or the specification changes, and give a reason. The byte
range defaults to the whole captured file; advanced edits can select a smaller
raw UTF-8 range. Preview shows the original and replacement before Apply or Cancel.
These are author-selected source decisions, not a native check or proof result.

The server keeps only a bounded, expiring review nonce and digest, not copies of
source or replacements. Apply verifies the reviewed fields and exact current
manifest/revision, then uses the existing managed edit. A changed or forgotten
source, modified proposal, cancelled review or reused review cannot apply silently.
Restart discards uncommitted reviews. If Apply cannot proceed, the response keeps
the submitted replacement visible and offers **Open current source**. It does not
rebase or merge the proposal. That response contains the submitted fields only;
it does not restore forgotten original source. Successful edits still need native
revalidation. The HTTP regression passed in source checkpoint
`ba9d4813388f4a43a9a7467c3c7907f0`; the immutable packaged UI described above
predates this recovery behavior.

Both source-only and resident CLI use the same source commands. For the resident
installation append `--workbench import-native NAME DIRECTORY OPERATION_ID`,
`--workbench migration NAME`, or the existing `edit` arguments to the shared
RuntimeMain invocation. These commands reuse the runtime's source owner. The
interactive `review NAME PATH START STOP WORK_ITEM KIND MEANING REASON REPLACEMENT_FILE
OPERATION_ID` command prints a preview, then accepts `apply` or cancels. Kind is
`Obligation`, `Condition` or `Example`; meaning is `PreserveMeaning`,
`RestrictDomain` or `ChangeSpecification`.

The staged package exposes these as explicit surfaces. Use
`python3 tools/deploy/stage.py launch --state STATE --surface source INSTALL -- serve`
for the packaged source editor without starting Isabelle's resident process. Use
`--surface workbench` for the combined resident workspace. The source surface
selects the actual `veri7vn.cli.Workbench` entrypoint in the pinned producer JAR;
it is not an automatic fallback or a source-checkout compiler. See
[deployment staging](../deployment/local-staging.md) for producer and installation
qualification requirements.

## Package workspace navigation

Current source adds read-only package URLs: `/?package=NAME` opens the captured
package revision and declared capabilities; adding `&file=PATH` opens its current
managed source and review controls. Source files and review results link back to
the package. `&view=migration` opens original-source mapping diagnostics and
remaining obligations from the same workspace. Reopening a file reads the current
managed revision; an old bookmark does not retain a forgotten source snapshot.

In the resident workspace, the package page also accepts a retained request ID.
The combined page shows the actual native result and provenance beside the package.
This is navigation, not an assertion that the installed specialist executed that
package's edited source. Native build/status controls still require the host's
qualified build execution and governed diagnostic-source API. The current host
source offers queued build proposal types but no qualified public status/failure
consumer. The source HTTP navigation checks passed in
`ba9d4813388f4a43a9a7467c3c7907f0`; the combined native request check remains
queued. These changes are newer than the immutable packages qualified above.

The package workspace also links **Inspect affected package declarations**
(`&view=impact`); the shared CLI command is `impact NAME`. This uses the existing
`PackageUpdates.Consumers` planner over individually inspected managed descriptor
revisions. Exact declared package/version dependencies produce transitive paths
back to the selected package. Missing providers, duplicate providers and unreadable
descriptors remain visible; an unavailable target yields no computed affected set.
The view predicts source-declaration dependencies only, not running request
invalidation or native replacement safety. Changing a dependency and reopening the
view recomputes from current managed heads; no second dependency index is stored.
This source consumer, shared CLI, and HTTP edit/reinspect/Forget checks passed in
`ba9d4813388f4a43a9a7467c3c7907f0`. The dependency-expansion and path-traversal guard repair subsequently passed the
client and diagnostics scripts in `aefbaca838584a09a36b41303bc8275a`; the overall
three-script attempt failed an independent retained-source fixture. That fixture
passed its separate narrow check `8b947c73207e4f01b2180e8fadab34f9`.

## Native Build consumer under integration

The source currently includes an optional typed Build consumer and browser
POST-to-read-only-GET flow for status, captured source identity, native failure
navigation, cancellation and confirmed Forget. It is not supplied by source-only
workspaces or the old D44 runtime. No native Build control appears without a real
resident adapter. The matching host must provide managed source capture, durable
build reopening and read-only installed-feature inspection before that adapter
can be enabled and qualified. The real adapter now consumes the landed managed
proposal and opaque reopening facade; its native composition remains unqualified.
Native diagnostics can seed a nonempty source span for the existing reviewed edit
only when both the governed diagnostic and a fresh editor read match the captured
manifest/revision. Historical spans are not rebased. A candidate artifact is reported separately from
package admission and activation; opening an old build never resumes an attempt.
The new Build consumer changes are not covered by the source checkpoint receipts
above or by the immutable installed packages.
