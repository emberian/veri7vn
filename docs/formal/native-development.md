# Receiver-owned expert development

`src/isabelle/admission/development/native_development.ML` reconstructs complete
original `.thy` sources in a private descendant of approved native parents. It
retains the exact original bytes; source equality and the exact host-resolved parent
imports are checked before any declaration is constructed. The supported first
slice is a normal `theory … imports … begin … end` containing native `definition
name :: type where "equation"` and `lemma`/`theorem name: "proposition" by (simp
add: facts)`. Definitions retain the native command’s checked parameter treatment. No separately editable formula recipe is required.

The source parser does not invoke `Outer_Syntax`, `Method`, `Attrib`, or source ML.
It builds each definition with the admission gate’s fixed controlled
`Specification.definition_cmd` constructor and carries its returned successor policy.
This preserves the original exported equation, default code equation and native
Spec_Rules registration; a primitive lambda definition alone would change them. Theorems are proved by a
fixed receiver simplifier and installed with no source attributes. Policies are
advanced only across unchanged axiom tables; they are never reset over an authored
theory. Unsupported syntax fails before declarations execute. Source byte equality
is an integrity check, not proof authority: the approved policy must be supplied by
the trusted resident host, never decoded from worker labels.

Installed implementation inspected: Isabelle2026-RC1
`Contents/Resources/src/Pure/theory.ML` (`add_def`, `add_axiom`),
`src/Pure/Isar/specification.ML` (`gen_def`), and
`src/HOL/Tools/typedef.ML` (`primitive_typedef`, `prepare_typedef`, `add_typedef`).
`typedef` introduces its primitive axiom before the package discharges inhabitedness;
therefore neither a Defs report nor command observation is authority for an
untrusted worker extension. A future controlled typedef constructor must own the
native type declaration, representation set, nonempty witness proof and all package
side conditions. Datatypes, function packages, locales/classes, richer proofs and
code setup likewise need explicit trusted reconstruction constructors or a distinct
privileged native-plugin policy. This first command slice does not close them.

The full build closure remains the packaging inventory's responsibility:
`SessionInventory.inspect` uses actual Isabelle session/dependency analysis. The
inventory is data, not a proof or filesystem sandbox. This source reconstructor
takes explicit host-resolved `(source import locator, approved policy)` parents.
It merges their actual native keyword tables, begins the native theory with those
actual parents and uses the gate’s checked policy join. Source import spelling is
never guessed from the native theory name. It finalizes the resulting native theory
and advances the carried policy across finalization. It does not load arbitrary
session imports, execute a worker build, attest a heap or establish executable code
identity. Resident managed-lifetime/source ownership and recovery publication must
consume the retained source plus approved parent identity before exposing these
objects as durable evidence. No opaque object from this module is by itself an
accepted consequence; callers must use `Native_Admission.admit` in its returned
policy and exact native generation.

The narrow test is `tests/admission/development/Native_Development_Test.thy`.
It exercises an actual complete source file, definition and proved consequence. It compares an independently ordinary-built
source definition’s proposition, code equations and Spec_Rules registration with
the reconstructed result,
plus ML policy-forgery, embedded tactic, false theorem, axiom, exact-source swap
and parent-import swap negatives. A two-parent test proves a theorem consuming both
controlled branch definitions and rejects a wrong source-locator/native-context map.
Build execution is serialized by the shared build steward through `check-native`.

## Owned build inputs

`src/packages/native_build/NativeBuildInputs.scala` consumes the host's registered
`WorkerResources` input lifetime. The empty owner is registered inside the exact
current source read scope before copying any object. A bounded parser-clone envelope
is reserved first; temporary parser copies are cleared, the immutable parsed revision
is retained only by a releasable private root, and file slots are tracked before
writes. The resulting opaque owner exposes checked inventory and release rather
than a raw source snapshot or filesystem resolver. Its inspection uses the actual
`SessionInventory` and checks all discovered files against the captured manifest or
the accepting host's installed-source pins; captured ROOT/ROOTS are reread afterward.

This is a host-internal source operation, not an authorization API. The production
coordinator must consume the generated source/build/reveal grant before invoking it
and before exposing bytes to a worker. Revocation invalidates the registered lifetime;
cleanup stops/join workers, clears buffers, drops private roots and erases only owned
paths. Durable crash ownership intents, the closed authorized coordinator route,
actual worker/build handoff and managed native replay are additional integration
requirements. A JVM payload reservation is not a process memory limit or a sandbox.

`literal_spans.ML` provides a shared storage-only token/span adapter.
Isabelle's `Token.source_of` is compact inner input with deletion padding rather
than raw lexical source; concatenating it loses quote/comment delimiters. The
adapter maps actual native token position ranges back to the retained original
bytes using the installed symbol scanner. It accounts for native CR/CRLF and legacy
encoded-control normalization while retaining the original bytes, then requires
contiguous complete token coverage. It neither unparses tokens nor authorizes a
source. Quoted strings, comments, UTF-8, named symbols, cartouches and CRLF are
included in the native fixture. The helper lives in the shared admission base before managed provenance; recipe
consumers use the same API. No second source parser is introduced. The first leaf
pass is archived with its exact pre-relocation body; the context-sensitive legacy
control/UTF-8 edge correction has its own pending regression.

The owned-input consumer passed in the canonical 29-source runtime check on
2026-10-15 (25.532 s, all nine groups). Exact source bodies and logs are archived at
`var/runtime-host/canonical29-20261015T230218Z`. The native-build checks exercise
actual session dependency inventory, missing installed-source pins, swapped source
hashes and post-analysis ROOT changes, followed by registered source capture,
materialization, Forget invalidation, rejected use after release and owned directory
cleanup. This qualifies that component; it does not establish the fixed native
replay service handoff, the complete transitive private package build graph or a
successful deployed build.

The full controlled development session passed on 2026-10-15 in 5 s. The exact
production gate/helper/replay and ordinary source/test bodies are archived at
`tests/admission/development/evidence/native-development-20261015`, verified against
immutable attempt `c9cef8ad8ec3ce76/2e7c3e46336b4ad99290c991d7b46363`. The overall
batched receipt failed in an unrelated service-frame module; no service pass is
claimed. Actual assertions compare the independently built source and receiver
reconstruction, admit the consequence through C02 and exercise the two-parent and
adversarial cases above. Managed-provenance integration and a fixed authorized
service operation remain required consumers.

## Managed specialist producer consumer

The generic admission image now loads the checked development core before managed
provenance. `Managed_Provenance.replay_source` consumes actual approved managed
parents, an installed source owner and an exact original slice. It owns the new
context and source leases, retains the ordered replay construction trace and exposes
canonical `named_theorem` production through C02. The producer is not a service
operation or execution grant.

`tests/admission/development/Provenance_Specialist.thy` is the first specialist
consumer: it selects observations whose origins are classified and proves that
selection excludes unknown origins and respects input batching. This is a theorem
about that filter, not a source-population coverage claim. The managed fixture uses
this same authored file in a nonzero retained-source slice, produces a native
descriptor, checks exact target/source dependencies and exercises wrong owner,
short alias, parent release and source Forget. This new composition is pending its
first native check; the earlier standalone replay pass does not establish it.

A candidate specialist artifact is nonassertional and may have no theorem exports.
D43 gives it a typed artifact requirement/output instead of a dummy claim. The
service-owned charged ticket must bind the original source revision, actual parent
closure, export intent, fixed builder pin and positive bounded resource profile.
The native builder pin identifies Isabelle/PolyML replay code and supported command
policy; it is not refined-execution assurance. Selected theorem exports separately
undergo C02. A plain descriptor ingress is not the charged candidate-build route.

Managed callers allocate `P.construction_scope` before invoking
`P.replay_source_owned`. The fresh context is registered in that scope inside the
producer's bounded publication transition, closing the deferred-interrupt gap
before the caller receives its return value. The caller restores interruptibility
around replay and proof checks, then records descriptor/development roots before
committing the scope. Exceptions abort the scope and release only its fresh
products. The managed fixture covers a failed named export after replay while a
preexisting descriptor and shared parent remain live. This composition awaits its
queued native check; source-level review does not replace that result.

The managed producer composition passed in the actual native development session
(4 s, managed theory 0.632 s cumulative time), immutable attempt
`fe9f8d5b32b933ac/0bdc71ea70dc40e9b752245c6353eefb`. Exact production and fixture
bodies are archived with verified attempt hashes in
`tests/admission/development/evidence/managed-development-20261016`. The mixed batch
failed only in a separate recovery test API call; no whole-batch pass is asserted.
This supersedes the pending managed-fixture status above. It establishes the finite
managed full-source producer/native descriptor consumer and its tested rollback and
lifetime behavior. The D43 charged artifact service, persistent candidate/restart
consumer and full dependency build graph remain open.

## Charged candidate producer

`native_build_candidate.ML` provides the opaque `Veri7vn_Native_Build_Candidate`
functor for the private service assembly. Its prepared input captures the exact
managed source owner and original byte slice, ordered approved managed parents,
source revision/manifest associations and exact ordered export declarations. The
fixed assembly supplies the shipped executable pin, registered code generation,
operation template/profile/setup and maximum source bytes. Numeric associations
are inert snapshots: the owner must validate their protected current bindings and
exact `Executable_Identity.same` pin before issuing its existing private pure ticket.
No second ticket issuer is introduced.

`execute_owned` consumes that one-use, durably charged ticket, checks the fixed code
generation/profile, workspace, exact registered source/parent input bindings, unit cost
and implementation artifact, then invokes the existing controlled
`P.replay_source_owned`. Replay retains the native command policy and its ten-second
bounded constructor. The caller supplies a construction scope before execution and
owns abort on failure and root publication before commit. A missing selected export
therefore rolls back the fresh replay through that scope; shared parents survive.
The artifact exposes its actual original replay recipe for fixed recovery consumers.
An empty export list yields a valid nonassertional candidate. Selected exports use
`P.named_theorem` independently; no descriptor or assertion is fabricated for an
empty artifact. The artifact lineage is charged execution identity, not semantic
native generation. Forget or parent release invalidates the candidate.

The child fixture `Native_Build_Candidate_Test.thy` exercises this actual producer,
zero-export construction, one-use and zero-charge rejection, failed-export rollback
and source Forget. It is queued with the shared build steward; no compiled pass is
claimed here. The generated D43 service output ledger, protected BuildCandidate
recovery witness and actual workbench publication remain coordinated consumers.

The exact prepared execution plan also captures request, slot, execution and charged
semantic-generation IDs. The worker checks them against the consumed ticket,
together with its fixed registered operation and exact unit cost. The profile's
one unit means one bounded source-build attempt; it is not a CPU/latency estimate.
A failed native replay consumes that same one-use ticket. Runtime memory/process
isolation remains the host's separate boundary. Native declaration errors now retain
the original byte range through the next declaration/end; syntax errors without a
checked command mapping retain no exact range. `Build_Failure` carries actual phase,
source revision, manifest and optional raw-byte span for governed repair inspection.

Restoration consumes only `VERI7VN_CHECKED_DEVELOPMENT_VIEW` witnesses from the fixed
recovery producer. It preserves the original charged plan and exact export list,
retains the checked graph witness and releases that lease instead of releasing a
shared recovered managed development. Its cached original recipe supports aliases
which deliberately have no fresh `P.replay_recipe`. Native semantic context identity
is distinct from the charged operation's semantic generation and execution lineage.

Registered execution inputs are distinct from native provenance dependencies.
The prepared input captures one source parameter followed by the ordered authored
candidate-parent parameters; the owner validates those actual registered associations before issuing
the ticket. Its managed projection separately retains the complete native context
and source closure. Recovery preserves both lists and their distinct roles.

## Original package intent and source ingress (pending composed checks)

`NativeBuildInputs.Owned.exportIntent` parses the original captured `package.json`
with the existing `PackageModel.descriptor` under a reserved private root. The
opaque carrier preserves draft, original revision/manifest, descriptor path/pin,
original bytes and typed specification/contract/executable locators. It precedes
candidate replay. `withTheoryTransfer` and `withDescriptorTransfer` use the same
registered resource owner and an explicitly attached transfer worker. Each bounded
clone is registered before copying and cleared after native transfer; native I/O
runs outside the store and resource monitors. `currentSourceGuard` comes from that
same registration. Historical repair inspection has its own retained-access gate;
it never grants a stale build or current-source acceptance.

The child `Native_Package_Inputs` owns at most two transfers, with original descriptor
and selected theory each bounded to 1,000,000 bytes and chunks to 64 KiB. Offsets are
contiguous, headers and SHA256 source pins are checked, and abort wipes staged
arrays idempotently. Finish installs actual managed source owners under the caller's
construction scope and invokes only the installed `veri7vn.package_descriptor_v1`
Scala function on its own original descriptor source. That function reuses the
existing package parser; the bounded typed YXML result is expectation data under an
explicit trusted metadata-adapter boundary, never theorem evidence. The selected
file must be a declared source and its native theory header must be listed. Finish
produces an opaque source-input owner before request allocation or build charging.

`Native_Export_Intent` retains the independent descriptor source. The fixed host
parser bridge alone installs this carrier; no RPC accepts decoded expected names.
The original locator's declaring theory qualifies a local name; a fully qualified
name is retained exactly and must preserve that theory prefix. The builder captures
this opaque intent before charge, retains its own lease and includes descriptor
source dependencies in the artifact closure. Initial qualification consumes the
same original intent identity, independently of produced theorem names. Restore
must reparse the protected original descriptor using the same fixed adapter.

Compilation and execution of the current child fixtures are queued through the
shared steward; no new pass is claimed. The transfer fixture tests bounds, offsets, hash failure and abort before
calling the adapter; it does not substitute a fake successful parser. Actual finish
and fresh-process parsing require the packaged JVM's registered Scala function and
remain a distinct composed consumer until that test passes.

Installed public imports resolve through the builder's immutable setup map to
actual approved native developments. They are distinct from authored candidate
parents: only authored parents contribute artifact association IDs and parameter
rows. Replay retains the full mixed import order and exact source spelling;
recovery must resolve each installed root through its fixed approved root registry,
with actual theory identity checked rather than interpreting a label as authority.

Ingress correlation uses a host-generated 32-hex upload nonce before the first
RPC. An exact-header retry returns the same transfer; conflicting headers reject.
Discard cancels a stage or releases its unaccepted completed producer. Acceptance
transfers producer ownership to a known prepared handle. Settlement removes a
terminal nonce only after the host worker has joined and the serial native RPC
queue has replied to the acceptance or disposal barrier. Unknown cancellation
also retains a bounded tombstone until settlement, preventing a late begin from
publishing an abandoned input. Accepted input release does not invalidate
independent request/candidate leases.

The host Scala composition passed eleven groups in steward run
`bf0cb5fe3f7f4e4d8a8ce06f3777d337`, including captured-source historical inspection,
current-source refusal after editing, transfer ownership and nonce handoff races.
This does not establish native replay integration or packaged Scala-function
registration; those remain separate native and fresh-process checks.

The fixed builder functor now installs no workspace numeric identities at ML load.
Its private runtime installer creates an opaque installation after the actual host
identity block arrives, capturing template/profile/setup/operation/code IDs and the
actual approved installed-parent map. Each prepared plan retains that installation;
projection, replay resolution and ticket checks use the same captured values.
Generic consumers receive no installation constructor. Installation references do
not own root leases: the fixed service owner retains those roots and replay checks
their native liveness. Restoration requires the current fixed installation and
compares the saved checked metadata and shipped executable pin before adoption.

The fixed `Native_Build_Recovery` adapter derives durable metadata from opaque
candidate/prepared handles and the actual allocator-bound native generation. It
preserves selected C02 exports independently from the full original descriptor
expectation. Pending request restoration consumes a checked request witness,
checks fixed installation/pin and exact installed theory identity, and preserves
saved logical parent aliases. Its retained wrapper owns the witness; it does not
replay the target or issue a charged ticket.

The explicit `Veri7vn_Native_Build_Restart` fixture requires the newly packaged
Scala function on the fresh JVM classpath. It exercises actual descriptor parsing,
protected candidate/request envelopes, graph/source fragment installation and
retained aliases. Its pending target contains a false lemma, so successful
input-only restoration cannot stand in for successful target replay. This fixture
is source-ready and awaiting steward execution; it is not a deployed heap/image
manifest qualification or a completed application restart claim.

Native provenance dependencies and ledger retention edges have separate jobs.
`prepared_parent_dependencies` adds the exact authored parent artifact associations
to the prepared native closure. `retention_dependencies` additionally includes the
actual canonical charged input rows, so Forget of a parent candidate or source
parameter reaches its child artifact. These lists come from the owned prepared
snapshot, never a caller-provided dependency extension. Native recovery graph
metadata continues to describe its exact native source/context closure; the fixed
service reconstructs the additional ledger edges from the restored plan/parents.

The `Build_Service_Metadata` child constructors make request/goal/slot edges
explicit on aggregate source parameters and artifact rows. RequestLocal ownership
alone does not create such an edge. Artifact rows also retain the actual replayed
native generation separately from the charged goal generation. The native child
fixture constructs an actual parent and child development, then runs generated
`forget_closure`: native provenance alone misses Forget of the parent artifact,
while the derived retained dependencies remove the child for either its parent or
its source parameter. This regression is source-ready, queued with the steward,
and has not yet passed native compilation.

Historical build-source reopening uses a separate `HistoricalOwned` owner created
from the authenticated committed host source lease. It recovers the original
manifest under a registered retained resource and checks its revision, selected
path, byte count and hash before exposing a borrowed read-only source view. It
has no materialized directory, transfer worker, current-source guard or execution
method. Closing releases the registered capture before the source capability.
The host/effects composition and controlled committed-lease regression passed
in host attempt `7f0f74d1eff3436b98bd85474f13c453`; this does not establish
successful native restart execution.
Recovery never dispatches work. A paid interrupted attempt stays terminal; the
first supported way to work again is a new request under current authorization.

The fixed service metadata constructors now take the actual original generated
request and child. They derive shared request dependencies and all original goal
references, including interpretation, capability and unresolved predecessor slots.
The Frame adapter checks original parent/child membership before construction;
canonical artifact preflight rejects rows that omit these relationships.

Versioned BuildRequest material carries the immutable control/source plan and a
separate prepared or observed-failure phase. An observed failure records the actual
execution, reason, native source associations, replay/export phase and optional
original byte span. Its bounded plain diagnostic preserves unavailable message
content explicitly. The aggregate role remains within the existing 100,000-byte
reconstruction limit. Inert decoding grants no observation or execution authority:
the fixed committed-role checker must match the exact paid run and failed outcome.
The new runtime fixture exercises actual failed replay and producer retirement;
its behavior check remains pending.

The candidate module load passed native attempt
`11e4c8fe75104641ade809a68d422b84`, including the fixed deferred checker,
development recovery factory and opaque builder. This is a compiler result;
the runtime producer, descriptor replay and reconstruction fixtures remain
separate checks.

The input constructor and deferred checker are loaded as one trusted ML file.
Standard ML does not permit the fixed functor inside a `local` declaration. The
file therefore binds its construction implementation under a reserved temporary
structure name, gives the public input structure its opaque interface with the
same prepared-input type, and defines the fixed recovery functor while that
implementation is lexically available. Its final declaration shadows the
temporary name with an empty opaque structure. A failed load must prevent
resident startup. This is a trusted module-loading boundary, not a sandbox for
arbitrary ML programs or a public raw-input adoption operation.

A completed native output must own its actual authored ancestor leases beyond
prepared-entry teardown. Merely copying a parent development is insufficient:
managed provenance releases an owner's registered children when that owner is
finally released. The runtime candidate group therefore has its own counted
parent CandidateOwner leases, rooted before acquisition, and releases its child
development before draining those ancestors. Installed parents remain owned by
the fixed workspace installation; restored candidates retain their checked graph
ancestry. The runtime regression drops every external parent owner while keeping
the child output, then separately tests invalidation through the parent identity.
The complete runtime leaf and metadata theory compiled in native attempt
`3f5404f23f724e2bab37a50033c04b01`. The descriptor-backed worker and ancestor
retention regression remain separate, queued behavior checks. This compiler
result does not establish the parent service's dispatch or restart path.

Cancelled-request restoration still requires the original request alongside the
candidate in the current consumer. D74 requires each committed candidate capsule
to authenticate its own original inert control and source plan before active
request material can be removed. That migration must preserve charged-operation
and installed-parent native aliases through the shared reconstruction graph;
historical source ownership supplies no ticket or permission to replay a build.
