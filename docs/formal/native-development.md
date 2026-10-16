# Receiver-owned native development

[Native development](../../src/isabelle/admission/development/native_development.ML) reconstructs exact original `.thy` sources under explicitly approved parents. The supported slice is `theory … imports … begin … end` with native `definition name :: type where "equation"` and named lemmas/theorems proved by fixed `(simp add: facts)`. No parallel editable formula recipe is required.

## Trusted constructors

The parser executes no source ML, `Outer_Syntax`, methods or attributes. Definitions use controlled `Specification.definition_cmd`, preserving exported equation, code equation, parameters and Spec_Rules registration. Theorems use the fixed receiver simplifier. Policy joins/advances preserve approved axiom tables across actual ordered parents and finalization. Source import locators map to host-resolved native contexts; names alone grant nothing. Consequences separately undergo C02 admission.

Unsupported syntax rejects before execution. Typedef requires a future controlled constructor owning the type, representation set, nonempty witness and package side conditions: observing a command or Defs entry cannot authorize its primitive axiom. Richer datatype/function/locale/class/proof/code packages require equivalent explicit constructors or a privileged plugin image.

`Managed_Provenance.replay_source_owned` retains the protected source slice, ordered parent closure, theory, policy and replay trace. Canonical `named_theorem` production audits the actual fact. Construction scopes register fresh products before interrupts resume; failed replay/export aborts only fresh roots. Shared parents and preexisting descriptors survive. [Managed specialist evidence](../../tests/admission/development/evidence/managed-development-20261016) checks this producer with original `Provenance_Specialist.thy` bytes in a nonzero slice, source dependencies, wrong owners/names and parent/source invalidation.

## Source capture and ingress

`NativeBuildInputs` registers `WorkerResources` under the exact current manifest before copying. Reserved envelopes cover parsing/clones; private roots own the parsed revision, and file slots precede writes. `SessionInventory.inspect` checks actual dependencies against captured or installed-source pins and rereads ROOT/ROOTS. Inventory is data, not admission or a sandbox.

`literal_spans.ML` maps native token positions to original bytes, handling quoting, comments, UTF-8, named symbols, cartouches, CR/CRLF and installed control normalization. It requires contiguous token coverage rather than concatenating compact `Token.source_of` text.

`Owned.exportIntent` parses original captured `package.json` using `PackageModel.descriptor`. It retains descriptor/theory bytes, revision/manifest, paths/pins and typed export locators before replay. Registered transfers reserve bounded clones before copying and run native I/O outside source/resource monitors. Current-head guard governs execution/commit; retained inspection alone permits only historical diagnosis.

`Native_Package_Inputs` bounds two transfers, each descriptor/theory to 1,000,000 bytes, contiguous chunks to 64 KiB. Finish checks offsets/hashes and invokes only installed `veri7vn.package_descriptor_v1`; the returned YXML expectation is metadata, not theorem evidence. The selected file must be declared and its native header listed. `Native_Export_Intent` retains the independent original descriptor and exact qualified export names.

Nonce handoff correlates begin/finish/accept/discard/settle with a host-generated identity. Matching retries reuse one transfer; conflicting headers reject. Settlement follows worker join and native disposal/acceptance barrier. Accepted producer release preserves independent request/candidate leases.

## Charged Build

D43's `Native_Build_Candidate` captures the actual source/intent, ordered parents, fixed builder installation, registered inputs, request/slot/execution IDs and exact export list. Its one-use paid ticket checks workspace, profile/code/operation/setup, cost, executable pin and registered source/parent bindings before controlled replay. One unit denotes a bounded build attempt, not CPU time. Failure spends it. Zero exports produce a valid nonassertional artifact; selected consequences separately use C02.

Installed public imports resolve through a fixed approved map and exact loader/theory checks. Authored candidate parents separately contribute artifact IDs/parameter rows. Runtime installation occurs after the durable ID block arrives; plans capture that installation rather than allocate workspace IDs during ML loading.

Candidate restoration consumes fixed checked-development witnesses, preserving original charged plan/export intent and shared graph leases. D64 binds original managed objects to the exact native BuildRequest slot in the same commit. Reopen grants historical original-source inspection; execution needs a current head, permissions and a fresh authorized transition. Build status comes from native exact-child polling, not upload-owner survival. Terminal diagnostics retain phase/revision/manifest and optional original byte span; historical navigation never authorizes editing a changed head.

## Evidence and remaining scope

[Native development evidence](../../tests/admission/development/evidence/native-development-20261015) compares ordinary/reconstructed definition propositions, code equations and Spec_Rules, two-parent imports and adversarial source/axiom/tactic cases. Managed producer evidence separately checks lifetime/rollback. Host source/inventory/resource checks passed under `var/runtime-host/canonical29-20261015T230218Z`; eleven-group ingress checks passed in `bf0cb5fe3f7f4e4d8a8ce06f3777d337`.

Those component passes do not qualify every charged Build, package-function installation, terminal diagnostic, upgrade or browser path. Actual captured service/deployment checks govern those consumers. D74 cancellation/history migration additionally governs retained Math/Search consumers of native products. Full transitive private-package builds and unsupported native packages remain open; activation and empirical qualification are separate from source construction. See [recovery](native-recovery.md) and [updates](updates.md).
