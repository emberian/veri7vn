# Native admission implementation

`src/isabelle/admission/native_admission.ML` owns the opaque consequence type.
The registry owns candidates; a successful registry lookup never supplies an
accepted constructor. The accepted record retains its actual native theorem,
certified target, immutable registry generation and handle, requested route and
closed exact-native-proposition scope. Inspection does not confer current invocation/publication authority.

The gate compares the complete native proposition with the certified target,
including term types and variable sorts. It compares explicit premises,
hypotheses and sort hypotheses exactly, rejects flex-flex constraints, and checks
native object ancestry against the generation context. Context export must happen
before admission; exported assumptions must remain in the requested sequent.
`Thm.consolidate` fulfills pending derivations and `Thm_Deps.all_oracles` audits
transitive dependencies. Proof skipping is always rejected. Kernel admission
allows no oracle; an oracle request additionally requires the policy's independently
configured allowlist. Failure never changes the requested route.

The baseline policy is installed by privileged trusted image ML. Its native
theory is the declared foundation, including its approved axioms and definitions.
Ordinary descendants may add facts/declarations if their complete native axiom
table is unchanged. A newly added axiom is rejected even when unused by the
candidate. Unreviewed defining axioms are rejected too. The controlled `define` constructor
accepts a closed certified RHS in the approved lineage and calls the native
`Local_Theory.define` package itself. It exports and checks the closed definition
theorem, then creates the successor policy from that exact resulting theory.
It accepts no arbitrary axiom or callback/command source. Calling `policy` on an arbitrary theory is privileged trust-image
installation, not an admissible worker operation. No worker ML channel exists in
this API. Trusted plugins able to execute arbitrary Isabelle ML change this trust
boundary and can install different policies.

Full theory-table validation is cached by actual immutable theory identity;
transitive oracle audits are cached by opaque immutable registry generation and
object-handle identity, never by printed proposition/name/receipt. Native checked
`Thm.transfer`/`transfer_cterm` restore context where legitimate trimmed certificates
are passed; lineage itself uses kernel-owned theory identities, not certificate
content. Transfer can allocate a new theorem wrapper, so pointer-only caching
would unnecessarily repeat dependency audits. Caches retain at most 64 theories and 256
theorems per policy. Target/context/scope checks still run for every request.
The complete native axiom table and kernel-owned theory ancestry establish
foundation containment without requiring fully recorded proof terms for all HOL
facts; oracle references are separately audited transitively.

Claims are opaque certified-target contracts. Accepted scope is the closed
`Exact_Native_Proposition` constructor; caller-supplied English modality/domain/
coverage strings cannot become accepted scope. `propose_scope` only licenses the
fixed exact-native-target projection. Stronger world, completeness, optimality,
probability or prefix-to-whole labels are rejected. Richer scopes require
registered elaborators constructing their specific native targets and checked
licensed projections; that bridge is not implemented here. Conditional theorem
hypotheses and premises remain explicitly present in the accepted native theorem.

`family_certificate.ML` provides one receiver-owned inert certificate family:
a Boolean list (at most 1000 elements) and claimed natural count (0–1000).
It constructs the exact HOL `length (filter id xs) = n` target, uses a fixed
receiver simplifier under a two-second timeout, then passes the actual theorem
through the gate. Its exact native target describes only that finite computation.
There is no worker-selected theorem name, method, tactic source, ML/Isar source,
callback, or serialized theorem channel. The host must bound framing before
allocation and enforce worker process resource limits. `proof_transport.ML` also implements inert proof-term transport: 100,000 bytes,
20,000 framing/proof nodes, depth 128, five-second reconstruction. It bounds YXML
nesting before tree parsing, rejects unavailable bodies/oracle nodes/undeclared
hypotheses, and uses Isabelle's `Proof_Checker.thm_of_proof` in the actual receiving
theory before passing the resulting theorem through the full gate. Native class
proof nodes are checked by Isabelle's actual `Sign.of_sort`/`Thm.of_class` path.
Canonical receiver theorem lookup closures are cached by exact immutable theory
identity (four contexts); no worker theorem handle is decoded. Sender export uses explicit receiving and worker native theories, validates
checked source transfer, and expands unavailable private references, completes annotations and strips retained
named-reference bodies. Missing ancestor bodies remain unavailable rather than
being replaced with axioms. A separate `record_proofs=2` child session tests private
Pure derivation reconstruction; anonymous concrete HOL class-reference
normalization is under probe, not assumed. These implementations require their
native checks before integration. The host still enforces process/stack/memory
limits; these wire/time bounds are not an OS sandbox.

No generic implementation-attachment constructor exists: a finite generated
bundle must own its sealed implementation record and close its actual generated
dispatch, invoking this gate on exact native refinement targets and validating
representation/code pins. Compiler/code setup/serializer association, generated
authority event minting and the native-to-machine bridge remain integration
obligations. Empirical qualification/activation are separate; this gate creates
neither an empirical proof route nor activation permission.

## Validation

`Admission_Tests.thy` consumes actual registry/gate objects and exercises positive
native theorem acceptance, wrong target, hidden False hypothesis, retained scoped
hypothesis, undeclared premise, correct/wrong/bounded inert certificates. Native
build status and further adversarial cases are reported by the lane handoff;
this document does not declare unexecuted probes passed.

## Native authority projection

`native_descriptor.ML` registers an actual opaque accepted kernel consequence.
It allocates machine IDs internally, retains the actual accepted record, resolves
the target ID to its certified native target, and resolves premise IDs to the
actual hypothesis/premise terms. Conditionality is derived from those assumptions and retained native sort conditions.
Sort IDs resolve through `resolve_sort`, term assumptions through `resolve_premise`.
One dependency ID denotes the whole immutable native generation and its registry
closure; it does not select only positive witnesses. Scope cannot be supplied by
a caller. Oracle records are rejected by this initial kernel-only projection.

`Admission_Metadata.thy` supplies the generated claim constructor used by the
host's single generated ML type universe. It fixes Mathematical, Scalar and
Unspecified; modality is Conditional if actual assumptions remain, otherwise
Asserted. Proof-only claims carry `NoExecution`, rather than inventing an executable
identity. The authority request still pins its real executable bundle. A native
mathematical claim can satisfy a matching goal with no execution obligation;
any goal explicitly requiring an executable generation rejects this proof-only
projection. Refined execution and oracle routes retain their separate actual
execution dependency checks. Existing specialist claims require their actual
typed elaborators and generation associations.

Native IDs are live lookup keys, never portable proof receipts. Restart must
resolve/replay and recheck actual theorem/target/assumptions/lineage, then register
a new descriptor and corresponding request; decoding historical integers cannot
restore accepted native objects. The host adapter must accept the opaque descriptor
and derive its actual generated claim itself, never accept an externally supplied
projection/claim record as evidence. `native_authority_descriptor.ML` is loaded after the host's central generated
metadata module. Its only constructor takes an opaque native descriptor, builds
the actual generated claim, assigns an evidence ID, and stores a closure over
that claim to generate the evidence event. It accepts no callback, raw event or
external projection. The generated native-to-metadata translation is a named
trusted boundary pending its concrete integration checks. Restore remains
unavailable when historical checkpoints need native associations; fresh live
serials must never be substituted for historical descriptor IDs.

## Managed native reference closure

Private acquired batches stay outside permanent shared theory fact/definition
heaps. Keep them in typed runtime stores and disposable request/context islands.
Opaque native IDs are not erasure: all managed roots retaining their payloads must
be released, and in-flight work must follow the host's serialized lifecycle rule.

| Native root | Owner and release operation |
|---|---|
| Descriptor theorem, target, assumptions, sorts and native generation | Admission `N.release`; payload becomes unavailable, stale native resolvers return `None` |
| Gate generation audit and theory-lineage caches | Admission `A.clear_cached_generation`, called by descriptor release for the generation and descendants |
| Canonical proof-checker context closures | Admission proof transport `release_generation`, called by descriptor release |
| Generated evidence claim closure | Authority adapter retains numeric generated claim fields only; `D.release` invalidates its native payload, `event_frame` refuses after release |
| Policy baseline and controlled-definition contexts | Host/package owner must discard private policy/context islands; clearing caches cannot remove an immutable baseline still held by the owner |
| Pending results, admission tokens, raw accepted records, active workers and native service association maps | Host must cancel/drain or release affected roots and recheck liveness before precommit/ack |
| Original source bytes, manifest, decoder candidate and bulk batch | Source importer owns candidate/decoder maps and must release every dependent managed reference |
| Typed runtime output/value/continuation closures | Sealed execution bundle owns store removal and dependent retained-handle invalidation; old immutable store snapshots must also be dropped |
| Actual native registry snapshots | Registry owner releases objects/generation islands and drops all old persistent snapshots; a current-table removal cannot erase a retained old snapshot |

The descriptor has no global generation-to-context intern table. Its semantic
locator comes from the registry's non-authenticating numeric generation locator.
Any durable-ID translation table must contain non-content IDs only, never native
contexts. After `N.release`, only the permitted non-content projection remains.
Policy baseline roots and raw accepted objects held elsewhere remain explicit
owner obligations; the release hook does not promise to erase unmanaged native
plugin references or previously exported copies.

## Managed native source developments

The passed receiver-owned development parser is loaded through generic Admission.
`P.replay_source` consumes explicit managed native import parents, a protected
source owner and its exact retained slice. It invokes the fixed native replay
core, then owns the resulting theory, policy, source and ordered parent closure.
A development may export no claims. `P.named_theorem` separately resolves an
exact canonical native theorem name and applies the complete admission audit;
it accepts no caller theorem object or assurance label.

The new publication implementation reserves its single context identity before
acquiring input leases. Only the fixed lease-to-development ownership handoff and
parent registration are interrupt-masked; native parsing and proof replay remain
interruptible. Every ordinary publication failure releases acquired units and
unused context/cache roots. A caller-owned bounded construction scope records
fresh products inside publication, before interrupts resume. Aborting releases
only those fresh products; committing transfers ownership at the consumer's
short publication boundary.

The selected Core Checks session passed in 3 seconds in immutable attempt
`fe9f8d5b32b933ac/ff23264a26cc4936bf0d62db255b3e93`. It executed scope rollback,
closed-scope rejection, ownership transfer and actual allocator-exhaustion
cleanup. Exact selected inputs, receipt and log are archived under
`tests/admission/evidence/scoped-publication-20261015`. The group failed in
separate managed-development and expert-recovery test helpers, so this does not
qualify the managed expert replay runtime or service consumer.

The subsequent selected `Veri7vn_Native_Development` session passed in 4 seconds,
including the managed specialist consumer (0.632 seconds cumulative theory time).
Its exact inputs and receipt are archived in
`tests/admission/development/evidence/managed-development-20261016`. The consumer
replays retained `Provenance_Specialist.thy` bytes from a nonzero slice, selects a
canonical theorem about classified observations and batching, and creates the
native descriptor. It checks source dependencies, foreign-owner and short-name
refusal, failed-export rollback preserving shared products, and invalidation on
parent release or source Forget. That group failed in a separate recovery test
API call; the D43 charged artifact service remains unqualified.

The artifact service operation and durable replay profile are separate consuming
obligations. A zero-export artifact must remain an artifact, without a fabricated
claim. Selection of a checked consequence, empirical qualification and executable
activation remain distinct operations.

## Durable identity and committed reconstruction boundary

`native_identity_allocator.ML` installs an opaque block only through the private
host service path after the existing workspace store transaction has advanced its
counter. It checks namespace, positive 128-digit bounds, block size and non-overlap;
all allocations stay `IntInf`, including claim/target/interpretation/premise/sort,
semantic-generation and evidence IDs. It performs no logical admission. The
semantic-generation map contains only `(workspace, live numeric generation locator)`
to allocated durable ID pairs, so it retains no native context. The language request
gate uses the same `N.semantic_generation_id` map; independent ID schemes are not
interchangeable. Fresh actual native handles remain distinct from durable IDs.

D40 adds a common input-identity map keyed by the actual literal owner's numeric
locator and workspace. The fixed checker interface supports protected source correspondences as
opaque input fragments; input and context fragments install in one checked atomic
batch. Restored source identities never pass through the allocating ordinary
getter. Registry input owners have independent consumer leases: invalidation
denies access immediately, while physical disposal waits for base ownership and
all leases to drain. Final disposal removes only that actual owner's numeric
associations; equal bytes from a different input remain a different identity.

The coherent registry, generic admission, recovery and source-span checks passed
in 77.146 seconds in
`var/native-scaffold/sessions/1ec15fb468670a61/attempts/a4cec1ebd31b408f8beb7f782b7d03a6`.
This executes source-map gating, shared input/independent lease lifetime,
last-owner disposal, pool correspondence and exact source-span regressions.
The actual language/math consumer migration and service composition require their
own checks. A subsequent repair must close the P unit-acquisition-to-development
publication failure window, including identity-block exhaustion; that repair is
not covered by this receipt.

`native_committed_recovery.ML` defines the opaque host-committed material capability.
Its installer accepts only the protected store/service path, validates envelope
identity and named byte bounds, and retains a releasable payload. Parsing/installing
that capability establishes neither native truth nor a restored descriptor. It
currently admits only the kernel/no-execution recovery profile; executable/source
bulk recovery requires its typed family bridge. The host owns actual journal
membership and SHA256 checks; native recovery must independently recheck the sequent,
proof/context/dependency meaning and every saved metadata correspondence.

Registry's native sequent artifact is inert syntax preserving target, full native
proposition, ordered hypotheses/premises/sorts and flex-flex pairs. It is never a
theorem deserializer. Persistent export must qualify all sequent/proof artifacts
against their receiver bounds before committing a recoverable association. Large
or unavailable reconstruction material remains explicitly nonrestorable. Saved
IDs must be rebound only after matching actual reconstructed native semantics;
they cannot be compared to fresh serials or supplied through a public rebind API.
The actual nonempty restore/export/recheck consumer remains an integration task.

### Managed producer qualification (D35)

`N.register` remains an ephemeral projection of a checked theorem. It does not
infer private source provenance and is insufficient for persistent authority
attachment. `D.register` now requires `N.provenance_complete`, obtained through
`N.register_produced` and an opaque controlled-producer consequence.

`Veri7vn_Managed_Provenance.public_image` constructs a fresh global context and
fresh admission cache policy from the explicitly approved public theory. Its
named-theorem producer retrieves the actual public fact internally; it does not
accept a privately constructed theorem and classify it by matching a name or
proposition. Private local contexts and old policy audit caches are not imported
into that profile.

The owned definition producer consumes an opaque host-installed source owner
and an exact slice of that actual `Native_Literals.input`. It parses the slice
itself, invokes controlled native definition, and retains the actual successor
registry generation, theorem handle, source owner and parent development. The
embedded-token variant uses Isabelle's lexer and term-token parser on the exact
quoted/cartouche token before native term parsing. There is no caller-supplied
parser, theorem, provenance-label list or acceptance callback. The source ID is
allocated once per actual input identity and workspace; the global lookup keeps
only numeric locators, not input payloads.

Development and consequence payload cells are releasable. Releasing a private
island detaches its actual context/policy/theorem roots and its owned child
islands, invalidating descriptor access through the same consequence cells.
Shared parent developments and shared original inputs are not forgotten by
child release. Their owner must apply lifecycle/refcount rules and drop external
snapshots and worker lineages. `native_object_dependencies` enumerates actual
gate-owned target, interpretation, claim, premise/sort and generation identities;
controlled source IDs and the complete logical native context lineage augment
the claim dependencies. Every ordinary development receives its canonical
workspace context ID during construction, including parents that have not yet
produced a descriptor. The generated authority's
separate managed-evidence closure must additionally include its evidence identity.

Recovery constructs temporary contexts only from protected committed material.
These generations remain staged and cannot produce consumer-visible descriptors
until the fixed semantic verifier checks the whole saved construction graph.
Typed verifier fragments bind the saved IDs atomically; conflicting prior
associations and two fresh generations claiming one saved ID in the same batch
are rejected. The canonical map retains numeric locators only. Shared physical
context-cache ownership is separate from logical parent dependencies: aliases
validate native theory and complete physical source-owner correspondence while
retaining the saved logical lineage, rather than inheriting an unrelated cache
alias's metadata identity.

`Veri7vn_Admission_Core_Checks` executes the same shared ML test body as the
full composition check. It passed in 11 seconds (theory 1.300 seconds) in
`var/native-scaffold/sessions/a6f87ab8d4ebe987/attempts/e843016747534eb191f6c2c01fd591ee`.
The actual tests cover public-fact and exact-source producers, foreign-owner and
embedded-token handling, parent-context dependencies, whole-map reverse
identity conflicts, atomic failed batches, owner teardown, sibling preservation
and repeated teardown with actual map removal. Recovery's separate native tests
also passed in that group. The group as a whole failed in unrelated math bundle
and development replay targets; this does not establish metadata/service or
source-family composition.

Generation binding and staged-flag clearing use one synchronized state update.
A saved generation ID cannot simultaneously identify two live physical
generations in one workspace. Whole context-owner teardown removes its numeric
association; individual descriptor release does not. Fixed native-root teardown
is interrupt-masked and iterative, without arbitrary callbacks or worker joins.
Outer resource lifecycle must cancel and drain workers first.
The actual host source-ingestion/package adapter, durable recovery exporter and
semantic rechecker remain required consumers. Arbitrary expert development
continues to require an explicit trusted build image and complete owned context
closure; this bounded producer does not replace that contract.

### Output specialization and conditional templates (D34)

The initial source query carries fixed acquisition-condition IDs, so its first
association may use identity correspondence for those conditions. This is not a
restriction of the general conditional-template contract. A template such as
`P output ==> result_spec output` requires native typed substitution into both
the conclusion and the retained condition templates. Original IDs remain
immutable; specialized native conditions receive their own identities with a
checked correspondence from every original condition occurrence. Isabelle may
normalize, reorder or merge equal instantiated hypotheses. A future general
bridge must preserve the original occurrence mapping while allowing a merge
only with actual native equality/equivalence justification; list cardinality or
order equality alone is not a general correctness criterion. Neither an omitted
condition nor a new caller-selected condition is licensed by output binding.
The whole-instantiation metatheory and generated/native correspondence remain
open beyond the initial fixed family.

### Source-family association (implementation pending native composition)

The source child now defines an opaque static functor over the restricted
operation-ticket view. The real issuer is created only in the final private
host assembly. Preparing a reservation retains the exact certified native
acquisition/query/context tuple and the fixed query function before any output
exists; its context carries the actual `ReservedSourceOutput` identity. Actual
manifest metadata arrives with the confirmed acquisition payload, not as a
fictional precomputed response.

Attachment consumes the single-use confirmed acquisition ticket, checks the
actual request/attempt/source binding/reserved slot and native-generation
association, original input ownership and source dependencies, then invokes the
fixed generated decoder on the exact retained bytes. Whole manifest metadata,
original wire, native batch/qualified observation, immutable query/context and
confirmation receipt stay associated. The sealed executable-instance work owns
the common implementation/refinement/codec/cost association; the source gate
must consume that same instance rather than creating a second profile registry.

The query result is a revocable managed cell containing the actual generated
`row_query_outcome`. Failed, missing or blocked traces remain outcomes, including
the full causal trace for `QueryStopped`; they never become accepted zero counts.
The accepted implementation contract is the general fixed refinement theorem,
not a fabricated kernel theorem for each computed row result. Source assertions
remain data, and input association is distinct from final answer-slot binding
and durable snapshot retention. Releasing the association clears every retained
query-result cell, including opaque aliases already returned to consumers.

The whole acquisition/query/context tuple remains a proposal interface. The
production declaration must parse exact governed configuration bytes as semantic
settings, instantiate runtime identities and context pins through the fixed native
constructor, and retain the separate original language/configuration owners.
Authored numbers cannot become runtime IDs or premise/retention grants.

This source child has not yet passed native compilation against the migrating
row kernel, ticket and authority interfaces. The fixed streamed-source bridge,
actual language declaration consumer, generated output-binding event, cost
reservation and host final assembly remain required integration work.
