# Local specialist authoring client

The CLI/browser share `veri7vn.workbench.Authoring`, `ManagedSources` and one workspace writer. Imported source is inert; source revision, candidate, admitted evidence, qualification and activation are distinct objects. Start with the [installed workshop](../tutorials/installed-source-workshop.md) and [actual operations](../reference/recipient-operations.md).

```sh
V7=/absolute/path/to/installation/current/bin/veri7vn
"$V7" launch --state /absolute/private/source-state --surface source -- serve
"$V7" launch --state /absolute/private/native-state --surface workbench -- serve
```

The source surface opens no native heap; workbench starts the pinned resident. Both use the installed producer, not checkout compilation. Development-only entry: `/Applications/Isabelle2026-RC1.app/bin/isabelle scala src/cli/launch.scala WORKSPACE COMMAND…` compiles the source client. One writer owns a workspace; close `serve` with Enter before another process opens it.

| Shared source command | Purpose |
|---|---|
| `import-original/import-native NAME PATH OPERATION_ID` | Bounded inert directory/ZIP intake; physical path and ancestors must be symlink-free |
| `list`, `inspect NAME`, `source NAME PATH` | Live managed heads, descriptor/files and original bytes; overflow is explicit |
| `migration NAME` | Source-backed native formula proposal, parameter meanings, repairs and open obligations |
| `impact NAME` | Declared package/version dependency paths at inspected revisions |
| `edit …`, `review …` | Exact-byte revision-checked source changes |

```text
edit DRAFT MANIFEST REVISION PATH START_BYTE END_BYTE EXPECTED_FILE REPLACEMENT_FILE OPERATION_ID
review NAME PATH START STOP WORK_ITEM KIND MEANING REASON REPLACEMENT_FILE OPERATION_ID
```

Offsets are half-open UTF-8 bytes. `inspect` supplies current revision/edit token; the expected file contains exactly the selected original bytes. Tokens are concurrency locators, not proof authority. Original paint recognition leaves parser/units/rounding/domain/execution/evaluation obligations. Historical panels keep sender attribution and unknown recipient freshness.

## One resident workspace

Resident commands add `run QUESTION [INTERPRETATION_INDEX]`, `result REQUEST_ID`, `cancel REQUEST_ID` and `forget REQUEST_ID --confirm`. The runtime owns initialize/restore. A unique native reading runs; ambiguity requires selecting its actual index. Pending choices retain exact original bytes for at most five minutes and clear on close; useful descriptive alternatives remain a gap.

Result HTML comes only from the licensed native service. Run/selection/lifecycle POSTs redirect to read-only request URLs: reload inspects, never resubmits. Editing a package does not change the installed mathematics specialist.

## Reviewed source changes

**Review a source change** captures a work item and `Obligation`, `Condition` or `Example`, plus `PreserveMeaning`, `RestrictDomain` or `ChangeSpecification` and a reason. Preview compares old/replacement bytes; Apply uses the normal managed edit; Cancel abandons the proposal. Neither action proves its statement.

Bounded expiring nonces bind reviewed fields. Apply rejects modified/reused/cancelled reviews and stale/forgotten sources. Failed Apply preserves submitted replacement and offers current source; no automatic merge or rebasing occurs. Restart discards uncommitted reviews; expert text outside selected spans remains untouched.

## Package workspace navigation

`/?package=NAME` shows current managed revision/declarations; `&file=PATH`, `&view=migration` and `&view=impact` open source/mapping/declared impact. Bookmarks do not retain forgotten snapshots. A retained request can appear beside a package as navigation, without claiming that request executed its edited source.

Impact reuses `PackageUpdates.Consumers`, with missing/ambiguous providers and unavailable descriptors explicit. It predicts source declarations only, not native evidence invalidation, running requests or physical erasure. See [diagnostic bounds](diagnostics.md#package-change-impact).

## Native build consumer contract in progress

Build selection names exact draft/manifest/revision, theory, ordered retained parents, selected canonical theorems (possibly none) and installed profile. The host validates/captures immutable source/dependency closure using `NativeBuildInputs` and managed leases. User paths, hashes or numeric IDs cannot create native authority.

The service reserves an artifact goal/output, durably charges the build and hands its one-use prepared input to the fixed producer. Construction yields a candidate, separately from theorem admission, operational qualification or activation. Changed/revoked parents, cancellation or Forget prevent publication. Restart reconstructs actual candidate ownership, including zero-export candidates, without rerunning the build.

## Native Build consumer under integration

Current source includes optional `BuildWorkspace` and browser **Build native source**, status/captured-source inspection, cancel/Forget and diagnostic→review navigation. Controls require the matching resident adapter/feature support; source-only and old D44 packages do not supply it. POST redirects to `/?build=ID`; refresh/open never starts an attempt. Dependent packages need admitted parent selection.

A diagnostic may seed review only when governed original source, physical span and fresh editor revision agree. Historical spans remain read-only. Matching host/native producer, retained reopening and composed qualification remain the gate; source-only tests cannot establish this workflow.

Evidence: [authoring archive](../../tests/workbench/client/evidence/authoring14-20261015/receipt.json), [validation](../../project/VALIDATION.md), [standalone record](../../tests/deployment/evidence/standalone-aae0d7dd.json). Actual managed edits, installed source workshop and fixed native browser result/Forget have finite passing consumers. Source impact/guarded diagnostic callbacks have separate component checks. New Build/source changes require their own capture; independent recipient acceptance remains open.
