# Native package lifecycle

`PackageModel.scala` indexes C01 descriptor format0. It rejects duplicate/unknown fields, malformed shapes, unsafe indexed paths, dependency conflicts, substitutions, cycles, and version conflicts. Source revisions, build candidates, workspace bindings, and active publication are separate identities. Native build outputs establish the actual Isabelle import, ML/code setup, and runtime closure; descriptor file lists do not. Zero-export support/data candidates are legal.

## Source, recipes, and builds

`ManagedDrafts` uses the host `ManagedSources` ledger. Creation retains intake originals; edits read source/origin together under the lifecycle monitor, apply exact revision/byte checks, and commit through source-head CAS. Exact operation identity binds canonical request bytes and expected head. Retries report historical terminal status; stale/invalid edits preserve the source and diagnostic. Receipt locators grant no current byte access.

`SourceObjects.ByteObjects` supplies exact `put` and bounded `read`; `referenceClosure` verifies source/original/archive manifests. History, prepared writes, replay request payloads, and temporary records remain host-owned retention references. Forget must remove private edits and unwanted content-derived identifiers as well as final blobs. Opaque unavailable tombstones can prevent replay without returning forgotten hashes. `forgetStorage` names storage cleanup; complete Forget also requires generated retirement and native/private-lineage release.

Trusted image commands in `src/packages/recipes/Package_Recipes.thy` define typed native objects:

- `v7_math_formula name = "native math_expr"` uses explicit parameter indices/environment; arithmetic alone infers neither units nor physical assumptions.
- `v7_reader_query name = "(predicate, observed rows)"` retains the existing `candidates/covers` meaning. External absence, uniqueness, count, extrema, and ranking require a covered universe.
- `v7_test_data` retains finite expectations `Expect_Unknown | Expect_Match criterion`. A sealed family matcher returns `bool option`, distinguishing unscorable from mismatch.

`produce_from_command` consumes the actual owned original command slice, parses supported binding/type/term, and derives embedded source byte spans. Original symbol-position mapping supplies slices; `Token.source_of` padding is not original text. Arbitrary ML/tactics/theory commands are a separate trusted expert-build privilege.

Recipes use `A.join` to check imported axiom unions and intersect oracle permissions, then `A.define`. The real registry/gate admits the actual definition theorem for its exact proposition. This does not admit English rendering or attach executable code. Named exports resolve fully qualified actual constants/facts in the selected context; short aliases and wrong contexts reject. Executable locators still need an implementation relation and pinned code setup.

`SessionInventory.scala` uses Isabelle's dependency analyzer with inline load files to inventory selected ROOT/ROOTS, theories, sessions, and ML sources against actual digests. It is a declared input inventory, not an executed heap or proof of dynamic file closure.

Private developments remain disposable lineages. Recipe `release_private` clears managed projection/policy successors after host association/refcount checks; all other theorem/context references or workers must also drain before complete forgetting.

## Transfer and evaluation

`TransferPolicy.scala` follows transitive private provenance, requires curation for public derivatives, excludes secrets, and reports missing replay dependencies. Preview binds actual bytes/classification/dependencies and rechecks them before no-overwrite ZIP creation. `ExportReceipt` records ZIP digest/size, selected bytes/identities, classification, curation, and omissions; it excludes private IDs and private graph fingerprints. A selected ZIP is not automatically a replay-complete native deployment.

[Governed resources](governed-resources.md) require durable audience exposure acknowledgement before inspect/export/run reads. A heldout label, native definition, or source hash cannot establish freshness. Overlapping memberships share resource exposure: reading `{Q1,Q2}` affects `{Q2,Q3}` for the same audience. Package code owns no parallel exposure ledger.

Family matchers consume actual opaque outputs and preserve partiality. `Veri7vn_Mathematics_Execution` distinguishes exact results, undefined arithmetic, missing parameters, syntax failure, and exhausted budget. `Veri7vn_Row_Instance` retains source scope, coverage, materialization, and missing/rejected/window diagnostics. Text parsing or an invented zero count cannot replace those carriers. Fixed deployed matcher integration remains an obligation.

## Qualification and publication

`PackageUpdates.describe/inspect` return source inspection records. `Consumers` computes transitive impact from full dependency snapshots. Native source/index/unindexed build changes require native classification; data/examples/docs retain executable identity unless the native service selects a different growth tier.

The update gate owns the actual builder candidate and managed development. Its fixed qualifier binds run specification, actual observations, native associations, and exposure dependencies. Qualification reservation/ack, charged start/exposure, licensed observation/ack, and publication/ack use the existing generated writer. Final publication CAS compares `publication_previous`; failure preserves the active slot. Lost acknowledgement recovers the committed state without rerunning qualification.

Rollback freshly qualifies a retained earlier candidate under current permissions and uses the same publication CAS. It never rewinds the journal, permissions, erasure, or exposure. Existing requests retain immutable old context/code pins; replacement affects new selection. Cancellation, revocation, and Forget retain distinct meanings.

## Evidence and remaining consumers

- `tests/packages/lifecycle/evidence/model11-clean-20261015` pins eleven model groups, including dependency/inventory checks.
- `var/runtime-host/managed-combined-20261015T152136Z` and `managed-effects-20261015T153144Z` cover real host source creation/edit/replay/reopen, preserved JSONL, prepared/shared objects, and storage erasure.
- `var/runtime-host/resources-native-artifacts-20261015T163856Z` includes six package groups, including historical validation abort; its later native-build cleanup failure prevents an overall-pass claim.
- Intake's current 26-group receipt is documented in [intake.md](intake.md).

Native recipe/source-byte fidelity, family matchers, governed exposure, expert build/export composition, and current package publication/restart consumers require their own designated checks. Component receipts establish their named paths, not a complete installed specialist workflow.
