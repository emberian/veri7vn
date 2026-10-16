# Canonical package lifecycle — implementation in progress

`PackageModel.scala` indexes existing C01 descriptor format 0; it does not add an
editable semantics schema. Duplicate JSON keys, unknown fields, malformed shapes,
unsafe indexed paths and dependency conflicts are rejected. Source/dependency build
inputs retain exact revision/content identities; the final actual Isabelle import,
ML/code-setup and runtime closure must come from the native build service, not the
descriptor file list. Zero-export support/data packages remain legal without a
fake native payload. Service integration must keep source revisions, release candidates, workspace
bindings and active native publication distinct. This component currently implements
development/source pins and build-input planning, not deployment authority.

`TransferPolicy.scala` computes transitive private provenance before export, requires
explicit curation for public copies derived from private content, excludes secret
references, and reports missing recipient replay dependencies. Preview identity binds
bytes, classifications and dependencies and is rechecked before a no-overwrite local
ZIP write. Forget preview computes managed derivatives and native association scope;
a source-only erasure cannot report complete native forgetting. Full native-context,
proof/value/descriptor/audit-cache release or private-worker lineage drop must join
the generated lifecycle transition before completion. Uncontrolled recipient copies
and public commitments are outside managed erasure.

`src/packages/recipes/Package_Recipes.thy` is trusted image command code.
`v7_math_formula name = "native math_expr"` declares a closed expression over the
existing exact-mathematics language. Parameters are explicit indices consumed by an
explicit evaluation environment; scalar arithmetic does not infer geometry/units or
a manufacturer's spread rate. `v7_reader_query name = "(predicate, observed rows)"`
creates a closed typed predicate/list pair, interpreted through the existing
`candidates` and `covers` meanings. A declared universe and proof are required for
external absence, uniqueness, count, extremum or ranking claims. Setting the universe
to the observed rows is legitimate only for that explicitly observed-population scope.
Source provenance ranks retain named or ordinal categories as the source profile
requires; no integer-only rank conversion is introduced here.

Commands join existing trusted parent policies through the shared gate’s `A.join`,
then call `A.define` and retain the actual generated constant/definition theorem and
source position. They never install `A.policy` over arbitrary user axioms. The shared
`admit_definition` consumer inserts the actual native theorem into the existing
registry and invokes the real gate for its exact native proposition. That does not
admit a renderer's English claim or attach an executable implementation. Expert HOL
blocks remain source; an arbitrary expert ML/Isar extension is an explicitly trusted
build/image operation, not ordinary worker proof transport. The join checks the actual imported axiom-table union and intersects oracle permissions.
Two independent controlled-definition package theories are composed in the native
fixture; this consumer is pending its first dependency-backed build.

Private theory development must live in disposable/releasable native lineages.
Do not intern private package theories in a shared irreversible application heap.
Forget must release every retained native object or drop its owned worker lineage;
removing bytes from SQLite/object storage alone is insufficient.

## Joining the existing components

The combined host/intake check passed the existing 26 fixtures with the byte-object
seam. The next managed consumer uses a `ByteObjects` adapter with exact-byte
`put` and bounded `read`. Host `ManagedSources.Stage` durably records a prepared
operation association before any write and tracks all written objects, including
unused prepared results. Operation identity binds exact canonical request bytes and
expected source head; identical retries return a historical receipt, while a changed
request under the same identity rejects. Historical replay is not current authority.
Committed/current/history/prepared references participate in managed forgetting;
shared live objects stay retained. Legacy roots require explicit migration, never an
untracked sweep. The host owns the journal extension; no package SQL registry is added.

The first Scala/JVM check passed nine fixture groups in 21.2126 seconds with stable
inputs. The receipt, logs and all 35 exact inputs are archived under
`tests/packages/lifecycle/evidence/model9-20261015T150741Z`. This covers the descriptor
fixture corpus, actual Isabelle source tokenizer/edit behavior, exact operation
identity, pinned migration diagnostics and local transfer policy/ZIP behavior.
Two more groups now check dependency substitution/missing packages/cycles/version
conflicts and the actual Isabelle declared session/theory/ML-file inventory; these
are queued separately because they ask new concrete questions.

The eleven-group model check passed with clean process exit in 29.8939 seconds;
`tests/packages/lifecycle/evidence/model11-clean-20261015` retains its receipt/logs
and all 36 exact inputs. The first inventory run passed its assertions but timed out
because Isabelle's shared non-daemon pool kept the standalone Scala process alive;
the test runner now uses official `Command_Line.tool`, without shutting down the
shared library pool.

Pending actual checks: native recipe tests against the latest frozen Math/Source/
Admission parents; the sixth managed-source invalid-edit group; native release/build/
export composition and governed dataset access.
No local mock is counted as an admitted or deployed package, and this task remains
open until its native dependencies and service consumers are connected.

Recipe projection/policy caches have an explicit `release_private` hook and
`retention_scope` identifying their native projection root and required context/worker
release. Private successor cells retain lineage for source-version inspection;
release clears the managed cells transitively and leaves the public trusted baseline.
The host must invoke this only after its association/refcount checks, so an actively
shared private context is not erased by an unrelated request. Immutable theorem/theory
references held elsewhere still require native root release or private worker drop;
the hook deliberately does not report complete forgetting on its own.

The storage boundary is now present in `SourceObjects.scala`: `ByteObjects.put`
and bounded `read`, with compatibility `Path` constructors explicitly backed by
legacy unmanaged local objects. `referenceClosure` verifies the binary manifests
and returns the complete source/original/archive object set; history and every
prepared write remain additional host-owned references. The managed host stage
adapter must track its operation before all writes. Operation request bytes can
contain private source edits; forgetting therefore includes replay request payloads,
temp records and unwanted content-derived identifiers, not just the final source
blob. After forgetting, retrying an old operation may report unavailable using an
opaque tombstone, without returning forgotten bytes or their old hashes.

Native export resolution checks the selected actual theory context and resolves fully
qualified constant/fact names into actual certified terms/theorems. Short aliases,
wrong selected contexts and unavailable objects reject. Executable locators remain
candidates: a constant lookup cannot establish a code attachment or runtime relation.
The native fixture covers these paths but has not yet run against verified parents.

`ManagedDrafts.scala` now consumes the actual host `ManagedSources` ledger. Creation
preserves original intake before writing the source manifest; edits read the current
source and original association together within the host lifecycle monitor, then
apply exact revision/byte checks and commit the verified closure by host CAS. A
stale source head records a durable terminal conflict; an exact retry reports its
historical status. Operation receipts contain no object locator and grant no source
access. Read callbacks expose only bounded associated objects and cannot be retained
as a raw storage capability. The actual-host consumer fixture passed five groups in the combined 52.714-second
run: create/edit/replay/reopen, preserved JSONL, stale conflicts, prepared writes,
shared live source retention and physical storage erasure. The exact 22 input bodies,
receipt and logs are archived in
`var/runtime-host/managed-combined-20261015T152136Z`. The subsequent current-manifest membership, deterministic request-budget race and
effect-profile boundary checks passed with the same five package groups in 28.593
seconds; the exact 27-input archive is
`var/runtime-host/managed-effects-20261015T153144Z`. A later combined run compiled
all consumed sources and passed all six package groups, including terminal validation
abort: a rejected exact-byte patch preserves its diagnostic,
leaves the source unchanged, and an exact retry returns the historical Aborted receipt
without reapplying the patch. Its exact receipt/source/log archive is
`var/runtime-host/resources-native-artifacts-20261015T163856Z`. That combined driver
failed later in the native-build input fixture's resource cleanup; these are scoped
consumer results, not an overall passing runtime receipt. This API deliberately names
its erasure operation `forgetStorage`; full Forget still requires the generated
retirement acknowledgment and native/private-lineage release.

The bounded native source producer `produce_from_command` consumes one exact retained
command slice from a host-installed source owner. It accepts only the three known recipe
commands, parses their actual binding and embedded term using the selected native
keywords, checks the family type, and derives the RHS slice from original token-byte
lengths. The admission producer decodes that exact quoted/cartouche token and creates
the controlled definition and provenance witness. It receives neither a normalized
caller RHS nor an asserted dependency list. Arbitrary theory commands, ML and tactic
execution do not run through this bounded path. Trusted expert theory development
still needs a separate controlled build lineage.

The new native fixture checks the actual owner/witness/descriptor path, rejects a
different original input owner, and verifies that released native developments make
their consequences/descriptors unusable while potentially shared original inputs
remain retained. Its allocator block is explicitly a native fixture, not evidence of
a production durable host source installation. The host must still bind installed
source owners to the actual protected managed source association and join native
release with generated retirement and storage erasure. These native fixtures await
the latest admission-provenance and mathematics parent builds.

`SessionInventory.scala` uses Isabelle's actual dependency analyzer with inlined load
files enabled. It records the selected session/root set, transitive theory/session
inputs, ROOT/ROOTS and declared ML-file sources, then checks exact bytes against the
analyzer's source digests. This is a read-only declared dependency inventory. It does
not execute the ML files, build a heap, certify dynamic file access or produce an
executable deployment. Trusted expert build orchestration still needs to bind actual
build outputs, code setup and runtime closure to these immutable source inputs.

The selected-ZIP writer now returns a local `ExportReceipt` binding the actual ZIP
SHA-256/byte count, selected source-byte count, exact selected artifact identities,
classifications, curation and omitted replay dependencies. The queued fourteen-group
model check covers this addition and the actual legacy paint-panel data importer. It does not silently include omitted private IDs
or the private graph fingerprint in the recipient archive. The service must persist
the receipt through the existing host store and construct its classification graph
from actual producer associations. A generic selected ZIP is not automatically a
complete native package, within the recipient intake limits, executable or admitted.
For governed material, exposure acknowledgment must precede reading bytes into that
graph; see [governed resources](governed-resources.md).


Canonical finite test-data recipes use `Expect_Unknown | Expect_Match criterion`.
Criteria and actual result types belong to the registered family; a sealed family
matcher returns `bool option`, preserving unscorable `None` separately from a
scored mismatch. No generic package result datatype hides decline, partiality,
missing input or rejection. The recipe theorem is a logical scoring meaning, not
an arbitrary runtime callback registration. Native declarations and producer
fixtures are implemented but not yet compiled; deployed matcher/profile linkage
and governed reveal acknowledgment remain separate integration work. Original
LegacyScore expectations remain attributed compatibility data, not mathematical
axioms or a claim that exact native matching preserves its permissive criteria.

## Current integration seams

The recipe producer and the deployed family instance have different jobs. The
producer retains the actual source owner and defines a finite typed list through
admission's controlled-definition path. The family instance supplies the executable
request, full result carrier and fixed matcher operation. A package declaration of
a representation profile alone supplies none of these operations.

The current mathematics consumer is `Veri7vn_Mathematics_Execution`: `prepare`
binds a native input to a particular instance and executable pin, `execute` returns
an opaque output, and `belongs_to` checks its request association. Its result view
preserves undefined arithmetic, missing parameters, invalid syntax and exhausted
budget. A matcher must consume this actual output path rather than parse rendered
text or turn non-values into a numeric mismatch. Its fixed matcher extension is
not implemented yet. The local rat-option scoring lemma tests the logical wrapper
only.

The row consumer is `Veri7vn_Row_Instance`: `qualify` supplies its fixed operation
and actual accepted implementation/projection/component/codec/cost contracts;
`elaborate` binds source metadata in the recipe generation. The proposed fixed
summary matcher compares the complete native summary, including source scope,
coverage limits, materialization and missing/rejected/window diagnostics. A stopped
or unavailable result is unscorable, never an invented count of zero. This matcher
also remains a family implementation dependency, not an arbitrary package callback.

The host handoff must bind the source-backed finite item declaration to these
actual family handles and then install the resulting membership through the
canonical authority protocol. It must not derive eligibility from `v7_test_data`,
the word `heldout`, a source hash, or a successful native definition check. Before
inspection, export or dispatch, the canonical resource-by-audience exposure change
must receive the existing exact durable acknowledgment. Current domain-only
reservation state cannot satisfy this: exposing A={Q1,Q2} must prevent a fresh
reservation of B={Q2,Q3} for the same governed audience, even when both memberships
were installed before A was read. This remains an authority/host integration task;
package code does not maintain an independent exposure ledger.

After that handoff, the runner can connect actual request/output membership and
sealed matcher observations to canonical qualification records. Publication still
requires the independently admitted export objects, explicit qualified policy,
exact source/dependency/runtime pins and current publication-slot CAS. Replay of
an operation receipt cannot grant a new byte lease or fresh native authority.

The first actual expert-source replay check exposed an installed-API pitfall that
also affects the pending recipe command producer: ML `Token.source_of` contains
compact position padding, not an exact copy of the original quoted/comment bytes.
The pending producer now delegates to the shared original-symbol-position to
byte-range helper and slices the retained original bytes; its native consumer stays
unqueued until that helper passes its actual tests and is installed in the shared
admission parent. The recipe fixture includes a command slice
at a nonzero offset in the retained original input. Admission's embedded RHS parser
already consumes the exact owned slice and does not reconstruct it using token
source text. This finding does not invalidate the separately checked Scala editor
round trips; no native recipe byte-fidelity pass is claimed.

## Protected update integration

Source inspection is provided by `PackageUpdates.describe` and exact paired
`inspect`; these records carry no admission or publication authority. Its
`Consumers` computes transitive impact from full-snapshot dependency edges.
Native source, source-index changes and unindexed build inputs require a native
build-service classification before an update plan is returned. Data, example
and documentation edits retain the executable identity unless the native service
explicitly requests a different growth tier.

The native update gate must retain the actual opaque builder candidate and its
managed development owner. An arbitrary source digest, candidate number, parsed
wire record or caller-provided metric cannot construct the gate. Its fixed
qualifier owns the run specification, measured observations, native associations
and exposure dependencies. A bounded supported profile is reported explicitly;
passing that profile is not a theorem of arbitrary package quality.

Publication runs the existing generated stages through the single host writer:
qualification reservation and durable acknowledgement; charged qualification
start and durable exposure; licensed measured qualification and acknowledgement;
then qualified publication and acknowledgement. Publication compares the exact
current slot candidate with `publication_previous`. Failure before the final
commit leaves the active slot unchanged. A committed update whose acknowledgement
is lost requires restart recovery of the latest committed state; retry must not
rerun qualification or spend a fresh holdout merely to recover an acknowledgement.

A rollback is a new update of a retained earlier candidate. It freshly qualifies
under current policy and permissions and replaces the current slot by the same
compare-and-swap path. Rewinding the journal would incorrectly restore revoked
permissions, erased material or unspent exposure, and is forbidden. Existing
requests retain immutable old context/executable pins. Replacement changes new
selection; retirement, revocation and Forget keep their distinct cancellation,
new-invocation and managed erasure behavior.
