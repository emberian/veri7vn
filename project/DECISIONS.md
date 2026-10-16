# Design decisions

Accepted direction follows the conversation and authorization to scaffold.
Baseline engineering choices can change with evidence; research reports do not
override this register or the user.

Revision 2 of the [architecture proposal](../docs/ARCHITECTURE_PROPOSAL.md) is the
agreed implementation design. On 2026-10-15 the user authorized proceeding and
requested gpt-6.1-sol agents as much as practical. Scoped implementation is now
authorized; acceptance of the architecture does not claim its implementation exists.

| ID | Status | Decision / consequence |
|---|---|---|
| D01 | accepted | Primary product is an Isabelle-native engineering environment with serious deployed search/growth. A client may be external; semantic authority is native. |
| D02 | accepted | Open HOL meanings plus specialized operational calculi and real proof/refinement bridges. No universal closed HOL value type or wrapper counted as a lift. |
| D03 | accepted | Performance from the start: staged compilation, efficient runtime values, whole-path measurement. Extraction-only products are optional projections. |
| D04 | accepted | Coherent specialist development connects authoring source, meanings, implementation, evidence, examples, sources and deployment. Generated artifacts derive from canonical source. |
| D05 | accepted | Interpretation, conditions, disagreement, failures, state and effects stay explicit. Versioned source reports are not global world-truth axioms. |
| D06 | accepted | Kernel theorem admission, refined/generated execution and evaluation-oracle execution have distinct assurance routes, with no silent downgrade. |
| D07 | accepted | Root synthesizes/dispatches/integrates; scoped agents implement. At the user's latest instruction the obsolete Python/IR/C prototype is removed, recoverable from Git. Retain useful native probes, upstream reference and audit/development utilities; require evidence for reuse. |
| D08 | baseline | Descriptor schemas validate structure only. Portable receipts/identities locate artifacts, not native proof authority. Support/theory/data packages need not invent callable exports. |
| D09 | baseline | Requests pin theory/runtime/capability/data/interpretation generations and separately identify session/prestate and observation/evaluation time with its clock basis. Whole-generation dependencies are not sufficient for freshness or session state. Selective invalidation requires adequacy and implementation evidence. |
| D10 | baseline | Quoted sources and explicit scoped adoption first. Automatic inconsistent-premise reasoning needs a designed consequence policy; general HOL consistency checking is not assumed. |
| D11 | baseline | Current development: macOS ARM64/Isabelle2026-RC1. Handoff target also includes Linux x86_64 to cover upstream environment. Each supported target needs its own evidence; paths remain configurable. |
| D12 | baseline | Local offline browser workbench with native backing and expert theory access is the primary authoring surface. UI and CLI share operations. Component-library choice remains replaceable; upstream workbench behavior is migration scope. |
| D13 | baseline | Source/replayable developments are durable; heaps/compiled code are runtime-specific derivatives with checked dependency closure. |
| D14 | accepted | One generated executable HOL authority machine is the actual runtime transition function. Typed request graphs and finite linked family interpreters compose operations; native meanings remain open. Native gate, executable linker and durable host seam receive joint review before downstream signatures freeze. |
| D15 | open | Backend portfolio: native ML available first; Sepref/LLVM compatibility and benefit need evidence. No fully verified downstream compiler is presumed. |
| D16 | open | External publication/Solana compatibility scope. Package import/export is required; chain integration is neither presumed complete nor silently discarded. |
| D17 | open | Missing corpus replacement snapshot/extraction policy; exact original is unknown. Document compatibility semantics and retain the limitation. |
| D18 | open | Full migration scope of six siblings. Present requirement is discovery/contract stress testing; expansion needs an explicit decision. |
| D19 | open | Project license and redistribution closure for runtime, solvers and corpora. Do not infer a license grant for new code from an upstream license or publish before this is settled. |
| D20 | baseline | Preimplementation audit G01–G03: claim scope/modality, assurance route and artifact lifecycle are separate. Ordinary-user tentative artifacts and scoped model/test/observation results remain useful; no empirical proof route or opaque-wrapper completion loophole. Native-registry owns extensible codec/profile registration, reviewed with operational and interpretation lanes. Original literals survive language normalization; composite/partial results retain their exact scope. |
| D21 | baseline | Audit G04/G07: routing blockers are scoped, not a universal terminal decline or indiscriminate fallback. Final outcome arbitration precedes authoritative answer-state adoption; transcript recording is separate. Session restoration does not re-execute old requests. Retirement/retention/access authority constrains cached handles and pinned generations. |
| D22 | baseline | Audit G05/G06: native semantic admission, empirical operational qualification and active publication are distinct. Feedback/configuration changes publish versioned policies. Connector discovery/test/requalification and background acquisition obey effect authority; source event time is distinct from receipt/poll time and origin/configuration belongs to each observation. |
| D23 | accepted | Repeatable regression and attributable exposure history; fresh holdouts only for freshness/generalization claims. Isolate in-memory and persistent learning. Retire blocks new invocation/acquisition; revoke/forget cancel dependent pending publication, and forget erases managed derivatives. Retained snapshot computations may finish absent revocation; no late acquisition reactivates a retired binding. Preserve local Film and code experimentation as artifact workflows. Network adapters remain D16. |
| D24 | accepted | Scala Headless/PIDE supervisor, resident Poly/ML authority, custom protocol commands, prebuilt application heaps and SQLite single-writer journal plus immutable blobs. Commit exact native-authorized batches with revision/epoch checks; acknowledge after durability. Current-authority check, dispatch-lease consumption and executor handoff are serialized with retirement; interrupted handoff may be unknown. Restore records/state, not historical requests. |
| D25 | accepted | Finite typed executable bundle; recipe/config/data and plans reuse compiled family kernels/interpreter. Theorem/native definition additions need no compilation if representable through existing operations. New carriers/kernels/code setup and optional fused plans stage a new bundle. No presumed dynamic SML ABI; packed values/session migration require admitted generation bridges. |
| D26 | accepted | Default autonomous extensions are supported declarative objects/strategies. Workers return inert certificates, compact reconstruction recipes or bounded native proof terms. Arbitrary ML/Isar execution, new axioms and unrestricted code setup are privileged native developments/plugins, not ordinary proof transport. A process is not a security sandbox. |
| D27 | accepted | Canonical .thy declarations with source-preserving form edits, expert blocks preserved. Package/release/deployment/workspace share one lineage. No duplicated editable JSON semantics or separate publication systems for authoring, search and synthesis. |
| D28 | accepted | Per-capability migration distinguishes owned algorithm/model, source/engine observation, external action and candidate workflow. Real behavior and actual assurance bridge are recorded separately; observation relabeling cannot complete an owned algorithm lift. All three shipped synthesis mechanisms share lifecycle but retain their proposal behavior. |
| D29 | accepted | Kernel consequence is default for reusable logical knowledge; refined execution is default for ordinary certified computation; oracle consequence requires explicit profile. Runtime guards are discharged before invocation, independently of retained source/model premises. PO-01–10 formal targets and TB-01–05 trusted-boundary contracts have distinct closure statuses. |

| D30 | accepted | Proof-only evidence has explicit NoExecution dependency, never fictitious bundle0. Semantic target matching and execution requirements are separate; actual executable claims retain registered pins. Kernel facts can serve ordinary bundle-pinned requests without a rebuild, while required-executable claims reject absent/swapped provenance. C03/C04 semantic revision2 and coordinated codec/consumer migration implement this correction. |


| D31 | accepted | Shared generated execution uses Isabelle's verified abstract nat/int implementation over target integers, via the narrow Code_Target_Numeral theory closure. Unary nat is unsuitable for actual metadata identifiers/counts/exact arithmetic. Preserve HOL semantics, full schema identity and exact values; requalify actual code setup/pins and consumers, never reduce values to hide the cost. |
| D32 | accepted | Persist workspace-scoped stable association IDs allocated durably before issuance; fresh native in-process handles remain separate. Restore only by authenticated artifact closure, exact native reconstruction/re-admission, complete saved-semantic/ID correspondence and atomic lifecycle-aware install. Neither IDs/hashes nor parsed manifests prove authority; no replay of external effects. |
| D33 | accepted | Unknown source origin is explicit and preserved through import, repoll, queries and adoption. It cannot be coerced to measured or simulated provenance. Window queries retain the original population and unclassified clocks; a closed-window claim requires both clock classification and actual source/materialization coverage. |
| D34 | accepted | Open parameterized requests with owned typed output reservations. Preserve original requirements and graph; one-shot native result associations specialize only declared parameters. Pure computations do not fabricate external attempts. Input substitution and each downstream result binding remain distinct, and publication commits the exact slot ledger atomically. |
| D35 | accepted | Recovery authorizes all accessible retained native evidence, including unused evidence, against the latest checkpoint while retrieving artifacts from their originating committed records. Native dependency closure includes managed inputs, targets, assumptions and private development contexts; names or hashes cannot supply missing lifecycle edges. |
| D36 | accepted | The generated authority owns session adoption, freshness, operation fuel, background jobs and qualification publication. Empirical results remain scoped observations, separate from semantic admission. Exposure eligibility is monotone and consumed durably before held-out access; measured/aborted outcome is a separate dimension. |
| D37 | accepted | Source rows preserve actual observed REAL values as explicit binary64 bytes, distinct from integers, text and blobs. Preserve dynamic storage class and extraction semantics; byte equality is not SQL numeric equality. Long values and multi-chunk semantic decoding remain required by actual shipped corpora. |
| D38 | accepted | One canonical numeric native-generation identity map serves kernel and refined routes. Ordinary native construction allocates context identities; verified recovery stages unregistered contexts, then atomically installs the complete saved context graph through fixed typed checker fragments. Parent context dependencies are explicit, and physical context sharing never merges logical provenance or durable IDs. |
| D39 | accepted | Recovery manifests distinguish finite KernelEvidence, MathRequest and MathOutput roles. Native fixed checkers interpret each role; refined results are never coerced into kernel descriptors. Math request association uses the actual request ID, with original input identity separately retained. |
| D40 | accepted | One source identity follows each actual input owner across mathematical requests and native provenance. Checked recovery shares one restored owner for each saved source identity, rejects inconsistent bytes/encoding, and preserves distinct origins even when their bytes match. Source ownership is never inferred from semantic generation or content equality. |

| D41 | accepted | A durable identity lease can be extended on the same opaque workspace allocator. Host commits each disjoint range before native installation; failed installation burns the range. Multi-object producers reserve complete ID bundles atomically before publishing any object. No unleased gaps, allocator replacement or guessed contiguous extension. |

| D42 | accepted | Every external attempt is associated with an explicit owned goal and optional reserved output. Recurring jobs instantiate fresh child requests/slots from their immutable authorized parent template; job incarnation and cumulative budget survive individual iterations. Current scope, blockers, licensed prerequisites and freshness are checked before staging and serialized handoff. |

## Change protocol

Append the reason, inspected evidence, affected tasks/contracts, and migration/check
plan for consequential changes. Reconsider accepted direction with the user;
resolve routine engineering choices through investigation without inventing
permission barriers.

## Corrections retained

- The earlier no-Isabelle-in-ordinary-deployment requirement was superseded.
- Expression/DAG correctness does not prove Python lifting, routing, sources,
  state, or final C emission.
- Core source already includes workbench, stateful specialists and connectors;
  include them in compatibility rather than treating authoring as wholly absent.
- Successful examples guide synthesis/search but do not license universal rewrites.
- Foundation peer review caught an omitted state/time dependency and over-restrictive
  package exports. C03/C04 now require request observation context and commit
  preconditions; C01 permits support packages without fake capabilities. These are
  integration repairs before consumers depend on revision 0.
- The [preimplementation omissions review](../docs/review/PREIMPLEMENTATION.md)
  checks actual runtime, domain, workbench and sibling source against that baseline.
  Its G01–G08 requirements elaborate shared semantic contracts before concrete
  interfaces are consumed. They do not mark any migration or metatheory complete.

## Revision 2 rationale and migration

The omissions audit exposed requirements that the old architecture left open to
incompatible implementations: actual authority ownership, heterogeneous execution,
worker proof transfer, publication/recovery and growth compilation. The four
[design reviews](../docs/design/adversarial-design-review.md) now converge on one
generated core with typed finite linking and explicit trusted integration. The
shared proposal incorporates review corrections for runtime guards, generation
migration, atomic dispatch handoff and retirement versus revocation.

`design-convergence` is complete following user agreement on 2026-10-15.
Core owners implement the agreed boundaries through the existing C01–C05
semantic contracts; schema revision 0 remains a descriptor, not a frozen runtime
protocol. Narrow linkage/proof-transport and host/recovery probes are assigned
early, before dependent interfaces freeze. Product/family tasks retain full scope.
No new proof or deployment claim follows from the design review.

## Integration review — native/host event serialization

Root review of the actual reducer and durable probe found that `AddBlocker` and
`SetOutcome` can invalidate a pending claim without changing the workspace
revision or authority epoch. Checking those two numbers alone before a host
commit is insufficient: a later rejected `DurableAck` cannot undo published disk
state. D24/C04 therefore require the production coordinator to serialize all
generated events with the complete native staging/precommit/artifact/transaction/
acknowledgement sequence, or prove an equivalent all-relevant-state token.
The host must consume generated authorization, not reimplement its policy.

`runtime-service` and `state-effects` own the real bridge and interleaving/crash
checks; `operational-model` supplies the shared predicates. Durable reconstruction
includes grants, blockers, outcomes and lifecycle state, not merely visible
bindings. Revocation cannot disappear on restart. Current probes establish only
the mechanisms documented in their reports. Native rendering likewise derives
claims from current licensed visible bindings; raw Accepted tags and free-form
text are insufficient evidence of current output authority (PO-04/TB-05).


## Integration review — numeral representation and native recovery

The actual exported authority-codec SML used `datatype nat = Zero_nat | Suc of nat`.
The codec proof session completed, but its runtime test attempted to evaluate a
256-bit schema identity in that representation. Increasing the timeout cannot
repair that algorithmic cost. D31 selects the installed narrow
Code_Target_Numeral/Code_Target_Nat/Code_Abstract_Nat/Code_Target_Int closure as a
shared generated-execution baseline. Authority61 owns src/isabelle/codegen and
its exact installed-source pins; consumer owners migrate through the shared build
queue. This changes compiled setup, not logical meanings. Prior invariant/codec
proof results remain historical source evidence; actual generated consumer checks
must pass under the new setup. No whole HOL-Library or HOL-Analysis heap is needed.

Root reviewed registry/RECOVERY.md and the inert envelope implementation before
accepting D32. Host owns the existing journal and bounded monotonic ID allocator;
reservation commits before return and unused block IDs are burned after a crash.
Admission owns opaque construction, native reconstruction and complete semantic
comparison, including target, hypotheses, premises, sorts, interpretation,
generation and dependency IDs. Registry owns fresh native object storage and
non-authorizing envelope parsing. The first real consumer is nonempty
AttachEvidence recovery; an empty-only restart or manifest roundtrip does not
close it. Recovery checks latest revocation/forget state and releases private
native roots/caches as well as disk payloads. Private context developments cannot
be interned into an irreversible shared global heap.

The pure source codec/query kernel must be below family admission in the module
graph. A family-specific admission module imports the generic gate and that pure
kernel; the final executable wrapper imports both and seals their actual typed
association. The generic gate stays family-independent. This avoids cyclic imports
and duplicate generated carrier types without a callback or cast escape hatch.

## Integration review — requests, lifecycle and qualification

D33 follows the actual importer, where ordinary imports already used Unknown
origin. The native source model must retain that fact. An empty filtered window
does not establish absence when observations with missing or incomparable clocks
were discarded. Observed-known selection retains those diagnostics; a request for
a classified window checks the original population and its source coverage.

D34 addresses a concrete integration obstruction: a request cannot require an
accepted answer before execution. Root reviewed the proposed finite slot API in
docs/formal/operational.md. Reservation-aware opening fixes the native template,
profile, immutable input and original graph. Separate result slots per graph node
prevent acquisition from pretending to know downstream query answers. Native
admission checks actual typed instantiation; the generated reducer checks ownership,
origin, scope, dependencies, cancellation and one-shot use. Unbound result goals
cannot be licensed. Pure results have no external attempt; acquisition results
retain the exact confirmed attempt and input. Original templates remain available.
Slot changes and authorized publication share stage/precommit/commit/ack; candidate
binding alone grants no historical retention. Reconcile never performs substitution
or repeats an effect. Migration includes the metadata schema, proofs, host codec,
request ingress, family wrappers, rendering and restart/interleaving checks.
An immutable source context distinguishes `RetainedSourceSnapshot` from
`ReservedSourceOutput`; an actual slot ID cannot masquerade as a snapshot ID.
Execution/cache association includes the resolved native input and dependencies.
Parameterized premises need the same treatment as targets: the native template
`P(output) ==> result_spec(output)` cannot retain a premise ID while silently
changing its term. Retain original premise-template identities and checked native
substitution correspondence to specialized premises. Account for every original
condition; native normalization may merge equal instantiated hypotheses only with
the corresponding checked equality, never by dropping an obligation. The initial
row-query family may use identity substitution for its fixed condition IDs.

D35 follows inspection of native_descriptor.ML, whose initial dependency list was
only the semantic generation. That is insufficient for managed private sources
unless an authoritative source-to-generation edge actually exists. Native producers
must attach the complete managed dependency closure before admission/retention;
workers cannot supply it by labels. Whole-private-generation invalidation is an
acceptable conservative baseline, but an unrelated public HOL context must survive.
The generated recovery query includes accessible unused evidence because it can
answer a future request. Latest-checkpoint authorization and originating artifact
commit are distinct. Reconstruction is qualified before committing recoverable
evidence, then rechecked against current lifecycle before atomic restoration.

D36 integrates the effects primitives into the existing generated reducer rather
than creating another permission machine. Session adoption carries exact currently
licensed bindings and expected session version; utterance recording grants no
accepted context. Freshness uses the shared signed clock with origin/basis and
actual read versions. Admitted operation costs consume the existing request fuel
atomically with dispatch; execution cannot obtain unlimited zero-cost steps.
Background work retains owner, source, budget and incarnation; stale completion
cannot republish. Forget commits durable revocation before managed release and
must support retrying incomplete erasure without restoring access.

Actual pure/external invocation uses a statically assembled private ticket module.
Only the single resident state owner holds issuance; fixed typed family consumers
receive restricted opaque consumption interfaces. Split the family-independent
state core below wrappers and final protocol wiring above them when needed to avoid
an import cycle. There is no global constructor from decoded command metadata and
no arbitrary callback-as-proof interface. Persist the generated charge/attempt,
then issue and consume once at immediate handoff under all-event serialization.
Bind the exact profile/code, request/slot, resolved input and cost. Recovery never
reissues command tickets. Charge whole fixed operations/plans at the boundary,
avoiding per-scalar/per-node fsync or native term construction.

Qualification records bind candidate/baseline, interpretation policy, learned state,
source/state observations, exam/scorer, dataset/split, runtime/resource profile,
exposure history, run attempt and explicit qualification policy. Measured results
require an actual scoped TestObservation binding; aborted/spent records license no
capability. Exposure/eligibility is separate from outcome: a measured run may also
have spent its held-out allowance. Reserve exposure durably before access or dispatch;
crash or abort cannot refund freshness. Unknown imported exposure is not fresh.
Publication joins this scoped observation with independently admitted native
capabilities, current dependency/freshness checks and expected-previous-policy CAS.
No threshold or experiment receipt proves functional correctness. Authority owns
the state/events; package lifecycle produces inert records through the native host.

Root also reviewed native policy composition: A.join requires actual ancestry,
exact union of approved axiom tables and the intersection of oracle policies.
It supports legitimate separately authored definitions without a package-side
semantic checker. Native two-parent and unapproved-extension checks remain required.

D37 follows bounded inspection of shipped ConceptNet weight, nutrition amounts and
grams, warehouse readings/bounds and admitted-fact scores. These are REAL values;
the initial four-constructor row carrier omitted them. Source text samples also
exceed 255 bytes, including a 64,353-byte calibration value. The source owner adds
an explicit eight-byte REAL carrier, with byte-level well-formedness/codec laws and
explicit query-domain handling. SQLite extraction can normalize values; a captured
binary64 observation is not a claim about original on-disk bits. Native numeric
meaning, comparisons, ranking and aggregation require their actual semantics and
refinement. Raw streaming capture alone does not complete semantic row import.
Evidence: docs/coverage/classification/storage-preservation.md and its bounded
storage-samples.json; no corpus rehash or full scan was needed to refute the model.

## Integration review — ordinary expert source and actual operation instances

C01 includes original expert `.thy` development, not only bounded formula recipes.
Inspection of A.advance showed that exact axiom-table equality rejects even new
ordinary definitions unless a controlled constructor records their conservative
extension. A.define is one such constructor. Resetting policy over a worker's
finished theory, or trusting its Defs/command-observer labels, would bypass admission.
Native_build61 therefore owns actual receiver replay of original source under fixed
approved imports, commands, attributes and proof methods, with controlled native
constructors and exact byte spans. The initial definition/lemma path is a first
consumer; type definitions and other required expert packages remain tracked with
their actual witnesses/side conditions. Unsupported source remains editable and
diagnosable. Arbitrary native plugin/ML trust remains explicit and separate.

The same installed/build identity issue applies to restart: theory names and sequent
syntax do not distinguish different definitions. Host boot identity binds the bytes
actually loaded, immutable source/setup closure and toolchain. An Isabelle heap
digest trailer alone is insufficient. Immutable images should be reused across
workers under managed ownership; copying/hashing whole heaps per request is not the
deployment design. Dynamic service source must also be pinned or prebuilt into the
selected image. Recovery reconstructs the actual approved context.

One sealed fixed-family operation instance connects executable registration,
pre-answer source declaration, execution tickets and qualification invocation.
Staged-execution owns the actual callable/code pin/specification/refinement/codec
and cost profile; admission owns native declaration/provenance association; host
owns registration lifetime and current-state issuance. A representation-profile
declaration or numeric profile ID alone is not this instance. Source recipes exist
before future observations and retain their original typed requirement and graph.
Each result remains a separate D34 slot. No arbitrary evaluator callback bridges
these components.

Held-out eligibility is keyed by the actual exposure resource and governed observer/
learner scope, separately from candidate/run identity. A new candidate, learned
state, policy alias or history ID cannot refresh an already exposed dataset/split.
Exact qualification thresholds are evaluated over bound metric values/units/scales,
with missing/uncertain values handled explicitly. They remain operational policy,
not native semantic truth. Freshness claims are relative to the tracked exposure
policy; the machine cannot establish absence of unrecorded human knowledge.

## Integration review — access, exposure and real search consumers

Retained access conditions preserve their own source/read versions, session identity
and clock/window requirements. They cannot be replaced by a follow-up request's
StateTimeUnused. A controlled RequireAccess form may omit conversation CAS, which
changes on answer adoption, while RequireObservation retains it for contextual
request freshness. Promotion preserves inherited access conditions and full Forget
provenance; its policy grant is checked at staging and durable acknowledgement.

Full provenance is not permission to inspect every ancestor. Admission review found
native context/theorem getters and row-count outcomes retaining entire observations.
These remain privileged owner interfaces. Recipient views expose only the selected
qualified value/assertion and required scope, coverage and unknown-data qualifiers,
without private rows, theory contexts or unrestricted proof/source getters. This is
an actual host/native projection boundary, not a new authorization Boolean. Explicit
same-owner expert editing remains supported; privileged ML plugins are not sandboxed
by an ML signature. Private source Forget must invalidate dependent promoted views.

Holdout exposure includes inspection, export and worker input, not just a scored
qualification run. Protected dataset access records exposure durably before revealing
bytes or handing out an input lease. Classification binds actual item/content membership
and governed observer/learner scope; aliases and overlapping known resources do not
reset exposure. Unknown imported history or membership cannot establish FreshHoldout.
Original public authoring material remains inspectable with unknown/spent eligibility.
Lifecycle supplies classified source associations, generated authority owns transitions,
and the host mediates actual reads. A separate lifecycle permission machine is rejected.

The strategy-engine task now starts against the existing plan interfaces while its
upstream completion gates stay open. Its first real consumer is a bounded native
multi-step proof scheduler using fixed retrieval/application/simplification/splitting
operations and an approved catalogue/context. Workers produce inert proof transport
for independent receiver reconstruction; they cannot publish acceptance. The complete
task still includes synthesis, counterexamples, refinement proposals, budget/cancellation
and deployed search integration. Generic pruning lemmas and isolated-learning fixtures
alone do not satisfy it.

## Integration review — native assembly and reconstruction identity

Native resident assembly now has a dedicated owner, assembly61. Host61 retains the
Scala protocol, deployment images, durable store and resource lifecycle. The five
native service files (including metadata_frame.ML) move together so the generated
state carrier remains one universe. The assembly owns a single state owner and
private typed tickets. Unsupported returned commands must be rejected before durable
commit/state installation, not after acknowledge has installed their state. Actual
family handoff and completion then use the same fixed operation and request objects.

Recovery of multiple facts with one durable semantic generation must reconstruct one
actual context island. Replaying equal text into sibling theories and reusing the
same metadata ID is insufficient for native rule composition. Reuse exact approved
construction nodes with managed leases; proof-specific wire/source ownership remains
separate. Distinct durable generations may use separate fresh registry wrappers over
the same approved actual context, without merging durable identities. Equal bytes
from unrelated private origins do not establish shared ownership or access. Tests
must compose recovered facts using actual native rule application and exercise release
and Forget across shared roots, beyond isolated sequent equality.

The first governed test-data producer uses canonical finite typed native declarations
and controlled source slices with fixed family request/result/scorer profiles. Expected
answers are attributed test expectations, not world axioms. Original Oracle7 JSON
panels/scorers remain preserved, with an explicit later controlled mapping rather than
invented generic JSON semantics. The inspected paint panel's legacy scorer uses answer
status, numeric substring matching within 1% of max(1,abs(gold)), word substrings and
must-decline cases. A new typed scorer is a separately named policy; changing those
criteria cannot be presented as legacy score parity or functional correctness.

### D38/D39 implementation boundaries

One numeric identity map serves both kernel and refined contexts. Recovery constructs
unregistered contexts, checks the entire graph with fixed typed checkers, then merges
their opaque identity fragments in one atomic installation. It does not allocate
ordinary fresh durable IDs and overwrite them. Shared physical construction caches
remain distinct from logical aliases preserving each saved context's parent/source
lineage. Shared-context recovery must demonstrate real cross-fact native composition.

Manifest v2 distinguishes kernel evidence, mathematical requests and mathematical
outputs. Its finite parser validates role/shape/integrity only. Each fixed native
checker reconstructs the actual carrier, request, specification and context/code
association. Original input identity remains separate from request identity. Version1
is explicitly unsupported until a concrete migration exists.

Ordinary source reconstruction uses the actual native definition command so the
definition theorem form, code certificate and specification registration agree with
ordinary Isabelle source. A primitive definition of a superficially equivalent lambda
is insufficient source fidelity. Complete private package dependencies must share a
governed source/worker lifetime; one captured draft is only the first materializer.

Semantic claim dependencies and private managed provenance remain separate. Retained
outputs cover their evidence's full managed closure; Forget invalidates assignments by
both closures. Host persistence records ownership before writing private artifacts,
atomically adopts them into the commit, and cleans abandoned writes on failure/restart.
Access denial precedes erasure and does not itself establish StorageErased. Recovery
buffers and surviving resident processes participate in that managed lifetime.

Canonical context IDs are one-to-one across the entire live workspace map, including
previous entries. Detach a mapping only when its actual context owner is torn down,
not when one descriptor is released. Kernel and mathematical consumers sharing a
recovered context require a typed shared context lease; the workspace owner releases
it after all associated jobs, requests, outputs and family instances are stopped.
Fixtures cannot keep old and reconstructed context generations simultaneously live
under the same workspace identity to avoid testing this invariant. If reconstruction
fails after attempting identity installation, poison that resident incarnation and
require a fresh process; releasing objects alone does not roll back the identity map.

Fixed row metadata contains constructor data. Its unchanged term can be certified and
decoded in the actual public kernel context without retaining an unrelated private
theory. Reject private constants/types and unresolved abstractions instead of silently
normalizing them away. This does not establish original declaration ownership: the
producer parses exact protected configuration bytes/slices into those parameters and
retains their owners, separately from the original natural-language request. Authored
private definitions require actual P construction and substitution evidence. A caller
cannot attach an arbitrary source owner to unrelated metadata to manufacture provenance.
The authored declaration supplies semantic source/query settings, not runtime request,
attempt, binding or reserved-output IDs. A fixed native constructor instantiates those
settings with actual gate-allocated identities and current context pins, preserving the
declared source/schema/version/query/scope/window conditions. Its native relation binds
the original configuration and natural-language input to the reserved output template.
Parsing a full tuple containing caller-chosen numbers does not grant those identities.

D40 moves ordinary source identity allocation to a common authority consumed by both
request and native-source producers. Recovery's shared source pool must be governed
by the actual fixed role checkers and retain/refcount all consumers. No public raw
saved-ID setter or parallel alias registry supplies this correspondence.


## Integration review — lifetime, source fidelity and display contracts

The first shared-context recovery fixture now executes native rule composition and
retained context teardown. D40 remains a distinct migration: canonical numeric IDs
alone do not share actual input ownership. Kernel and mathematical consumers require
one fixed-checker-governed source pool with leases, conflicting saved-ID payload
rejection and distinct equal-byte origins. The next composed check must use an actual
mathematical instance after the last kernel descriptor releases its shared context.

Managed provenance release detaches and cleans its bounded descendant graph with
interrupts masked; an interrupt between detachment and cleanup cannot strand context
associations. Long joins remain outside these cleanup locks. Resident entries own
both their computation worker and completion monitor, so a cleanup barrier waits for
both before releasing private input, output and context roots. Math proposal export
and token issuance are exception-safe before global registration; fixed one-shot
BeforeExport/BeforeIssue test diagnostics may exercise these boundaries, but are
absent from the resident protocol and accept no callbacks.

Raw mathematical input bytes and the prepared native parameter have distinct managed
rows. The parameter depends on the original input; Execute consumes the parameter,
and the result depends on that execution. Semantic prerequisite edges remain separate
from full managed ownership closure, avoiding dependency cycles manufactured from all
owned IDs.

A loaded theorem or a rational profile identifier does not license final rendering.
The fixed display bridge must connect the actual selected result-view implementation,
original request expression and emitted bytes through its admitted native contract.
The existing actual_result_view_checked_sentence theorem supplies a concrete target;
math, language and assembly owners must connect its premises and code associations to
the publication path. The modular evidence interface is still under integration review.

Actual ordinary-source replay refuted Token.source_of as a byte-fidelity primitive:
Isabelle uses compact Symbol_Pos text with DEL padding. Preserve the original input
and map native token positions in Isabelle symbols to original byte ranges. Replaying
normalized token text or weakening the equality test is not an acceptable repair.
Recipe extraction must reuse the same corrected range calculation.

After the current frozen proof/codec check, the generated lifecycle model must reject
UpdateObservation for inaccessible sessions and remove erased session observations,
views and recorded utterance references. Revocation, tombstone and spent-exposure
audit identities remain separate. A stale token cannot restore forgotten context
metadata even if a later freshness check would deny publication.

D41 is required for continuing deployed growth beyond the initial 65,536-ID lease.
Replenishment appends actual durably reserved ranges to the existing allocator;
preflight alone is racy, so registration atomically reserves its complete ID bundle
before partially constructing/publishing managed objects. Do not invoke host callbacks
while holding allocator locks. This is open runtime/growth acceptance, not a claim
about the current frozen service implementation.


### Refined display bridge and source-owner migration

The display contract is a separate fixed native theorem, avoiding a mathematics to
language module cycle. Its conjunction covers original integer captures to the whole
AST, exact result-view projection, and the existing full sentence-meaning/escaping
implication. An opaque bridge admits that target in the actual M instance generation,
pins both math execution and the statement-checker code, and checks those theorem
antecedents against the original request and saved output. Gate evidence, emission and
recovery retain the bridge identity and dependencies. Multiple restored requests with
one bridge ID share its actual owner and reject conflicting code/generation pins.
Equal code pins alone do not merge distinct logical bridge identities. Workspace
ownership releases bridges before their shared instance/context; individual request
policy release does not destroy a shared M instance.

D40 uses L base ownership plus independent consumer leases and explicit invalidation.
Managed_Native_Unit and R acquire leases; a staging pool drops only its own ownership
when transferring checked inputs. Forget invalidates all consumers. Fixed source and
context correspondence fragments install in one atomic tagged identity map. Static
native-image lexical functor assembly is an explicit ML trusted boundary, like existing
generation fragments; the resident/worker interface exposes no raw saved-ID factory.

### Remaining effect authorization design

Inspection of intent_permitted confirms no goal-scoped blocker/dependency guard, and
request_prestate = attempt_prestate prevents later operations after the first commit
in one immutable request. This is an unresolved C03 behavior and authority issue.
The proposed repair explicitly associates each attempt with its owning goal, checks
current goal dependencies/blockers/capability and matches reserved outputs where
present. The request prestate stays historical while each attempt pins its own staging
revision and serialized handoff rechecks current authority. Source-slot inference alone
cannot cover general effects. Authority owns the concrete schema/jobs/replay migration
for review before implementation; effects remain unavailable until the guard is fixed.


## Integration review — measured closure costs and recurring effects

The actual generated forget_closure pilot timed out at five seconds for 1,024-node
chain, dense and duplicate-record cases. The existing function repeats a full scan
and remdups for length(values) rounds. An indexed refinement must preserve the exact
returned list, since the authority emits ordered RemoveManaged commands. HOL remdups
keeps last occurrences; a discovery-order traversal is not automatically equivalent.
The candidate proof characterizes nonempty-input output by final reachability and
retained-record order, while empty values preserve the original seed list verbatim.
Finite exploration is only a way to refute that target; the native equality theorem,
selected generated code and composed cleanup behavior are required before replacement.
The current pilot sorts its result oracle, so it does not independently test list order.

D42 replaces request_prestate equality on every later attempt with attempt-specific
staging revision and current handoff checks. Add attempt_goal and optional output slot;
output-producing effects match the exact reserved origin/profile/input. Generic effects
still need a native goal-to-operation association. Jobs reference their original
immutable parent goal, and each polling iteration receives a fresh child request,
goal, output slot and attempt, with explicit parent/job/incarnation associations.
A parent must already exist; no reparenting or cycles. Each operation consumes both
its child allowance and the cumulative job budget atomically; restart preserves the
remaining budget. Parent cancellation or loss of authority propagates to active
children. Completed historical snapshots remain distinct from current publication;
late completion from an old incarnation cannot publish. Recovery reissues no workers.

Persistent monitoring authorization needs its declared freshness policy: unrelated
conversation CAS must not accidentally terminate an intentionally persistent monitor,
but RequireObservation cannot silently become StateTimeUnused or RequireAccess.
Native job-template instantiation binds the actual source/schema/profile requirements.
Two completed polls, stop/restart, old completion and budget preservation are mandatory
composition cases, not a one-result demonstration. Metadata/codecs/frames and fixed
native producers migrate together; old schema interpretation must fail explicitly.

The no-field lifecycle repair additionally checks accessible read-object IDs in both
observation refresh and freshness, compares refresh against a surviving session view's
CAS, and rejects recording forgotten utterance IDs. This prevents a stale token from
reintroducing removed metadata after the old current observation disappears. The
intentional CAS flexibility of authenticated retained-access grants remains unchanged.

Low-level source lease release must update its active lease identity and input owner
count in one atomic input state. Multilease unit construction/release uses short,
bounded interrupt-masked storage mutations with failure rollback; detaching a token
before interruptible cleanup can strand owners. Long joins and supplied callbacks do
not belong inside those sections. Normal-path lease tests do not alone qualify this
cancellation boundary.

## D43 — Native build candidates are typed artifacts

Approved for the next coordinated consumer migration; not implemented or qualified.
An authored development can produce a retained environment with zero theorem exports.
The existing claim-only output ledger cannot represent this without a dummy claim,
and qualified package activation cannot stand in for ordinary candidate construction.

Use a closed goal requirement sum, ClaimRequirement or ArtifactRequirement, and one
typed assignment ledger, ClaimOutput or ArtifactOutput. Derive slot category from
the original requirement. ArtifactReady never licenses an assertion. Distinguish
logical and artifact dependencies while preserving ordered, acyclic readiness;
current retained candidates from prior requests can also supply actual owned parent
inputs. Construction, individual native theorem admission, and qualified activation
remain separate operations. The concrete algebra, ownership, proof targets and
consumer migration are recorded in docs/formal/operational.md under D43.

The fixed native builder captures exact retained source bytes/slice, revision,
manifest, actual approved parent developments, export intent and operation profile.
Only the service's durable charged execution can issue its one-use execution ticket.
Use the existing opaque Executable_Identity pin as build identity, not implementation
acceptance: the fixed builder captures its own shipped theory/ML context, and the
service checks that exact pin and installed build closure. A caller-created pin or
numeric profile is insufficient. Native Isabelle replay is trusted implementation
under the stated boundary, not a claimed generated-HOL refined computation. Produced
native objects still pass C02; the candidate has no invented assurance-route theorem.

Staging and durable acknowledgement recheck current ownership, source revision,
parent liveness, blockers and exact execution lineage. Recovery reconstructs the
same protected source/import recipe without redispatching interrupted work. Rollback
owns the entire replay, descriptor and candidate publication chain; unused IDs may
be burned, but partial descriptors and stranded leases may not survive failure.

Authority owns the typed algebra and generated codec migration; native_build owns
the fixed builder; admission and recovery own actual provenance/reconstruction;
assembly and host own service ingress, lifecycle and durable consumption; authoring
consumes the resulting candidate API. Shared schema changes wait for the current
decoder baseline and a coordinated migration window. D42 jobs are a separate batch.

## D44 — Atomic retirement of now-unowned native support

Forgetting the last request can leave accessible shared bridge/code rows with no
remaining native request artifact from which to reconstruct them. Strict recovery
correctly rejects this state. A second queued Forget is insufficient: a crash between
the two durable commits leaves the invalid checkpoint.

Approve a closed list-root Forget transition which reuses the checked closure once,
updates the lifecycle epoch once and commits the complete denial/removal set in one
checkpoint. Keep singleton Forget compatibility. An empty root list is rejected.
The fixed native gate derives additional bridge/code roots from exact current owner
state under serialization, after computing the primary closure. It preserves groups
needed by durable required requests, evidence including unused evidence, and other
retained consumers. Worker/caller roots or stale queue-time snapshots cannot select
support retirement. Uncommitted proposals sharing a removed group are canceled at
acknowledgement; invisible pending proposals cannot keep durable orphan rows alive.

Native draining follows the durable acknowledgement. Strict recovery is unchanged.
Authority owns model/events/proofs/generated codec and singleton-equivalence checks;
assembly owns current-state Frame/Owner/gate selection and native drain; host retains
its atomic commit and public forget RPC. Check surviving requests, unused evidence,
last-owner crash/restart, pending cancellation and immediate Forget after reservation.
This smaller migration follows the current decoder baseline and precedes D43. It is
approved design, not current execution evidence.

D44 transport sends the exact newly denied IDs captured by the prepared candidate,
bounded before it can be offered for commit. Compare revocation and forgetting
categories separately: forgetting an already revoked object still needs physical
erasure intent. The durable checkpoint retains the full denial state, and existing
persisted erasure intents remain retryable when a repeated Forget has no new IDs.

Support retirement must protect survivors against the entire additional dependency
closure, including paths through inaccessible retained derivatives. Compute one
backward ancestor summary from protected surviving references, using all retained
records and unioning dependencies for duplicate IDs. Prove its equivalence to
intersection with the forward Forget closure; testing just bridge/code references
is insufficient. Reuse the narrow pinned RBT foundation for indexed traversal and
membership, without changing global set code equations. The generated consumer
requires the refinement proof and a scaling check; repeated per-group fixed-point
scans are not an acceptable final implementation. The same foundation owns exact
order-preserving denial-history difference, avoiding quadratic remdups/membership
cost as history grows. A bounded transport delta does not bound cumulative history.

Revoke followed by Forget must preserve every outstanding cleanup job and its
captured roots for the same target. Do not replace an earlier failed job when a
later category adds erasure intent. Aggregate the barrier, retry failed owned jobs,
and release completed closures; an empty repeated delta leaves existing intent
intact. Bound retained job resources and host retry behavior. Native installation
release follows completion of its own jobs, preserving shared context owners.

Construction rollback uses a bounded opaque P scope, created by the caller before
interruptible work. P records fresh products inside publication before unmasking;
the receiving graph transfers ownership in the same short masked boundary as its
own publication. Aborting releases only those fresh products. Qualification and
the future descriptor/candidate chain use the same ownership abstraction. This
does not authorize masking proof search or introducing caller cleanup callbacks.

## D45 — Keep resident protocol input free for Scala replies

The real resident caller exposed a deadlock absent from manual ML fixtures:
Protocol_Command runs the service synchronously on Isabelle's protocol reader;
request export invokes SHA256 through Scala and waits for Scala.result, which
requires that same reader. Root confirmed this path in the installed Isabelle
sources. Longer timeouts and serialized client requests do not repair it.

The protocol handler validates and enqueues bounded fixed service commands, then
returns. One owned worker/FIFO preserves service-command order and existing
authority serialization while allowing Scala replies to enter. Bound both bytes
and items; specify overflow, exact request failure replies and worker lifetime.
No arbitrary callback or privileged command interface is introduced. Long proof
search, joins and heavy construction still belong outside authority locks; moving
the reader alone does not establish their cancellation or resource contract.

Assembly owns the native queue and host owns transport diagnostics. The actual
concurrent request, durable publication, nonempty restart and selective Forget
consumer remains the regression. Rebuild/package qualification follows the repair;
the previously captured image is historical evidence, not the repaired deployment.

The initial queue profile allows at most 64 active plus queued messages and
16 MiB total retained frame bytes, preserving the existing 2.2 MB per-frame bound.
Each active burst has a fresh internal identity. Taking an empty queue clears its
worker and identity atomically; stale finalizers cannot clear a successor burst.
A matched fatal abort sets incarnation poison before releasing queue ownership.
Fork failure leaves the enqueue uncommitted and rejects its exact request ID.
Late failure can follow an already emitted reply, so this is not an exactly-once
reply or rollback guarantee. Durable recovery remains authoritative.

## D46 — Extend the resident consumer through fixed capability families

Domain execution joins the same authoritative reservation, charge, output and
lifecycle pipeline through fixed Domain constructors in request, gate and recovery
sums. It does not create a parallel service or accept arbitrary callbacks. The
domain owner carries the capability through its actual caller and licensed result;
assembly supports the shared sum changes after D44 convergence. D43 artifact
construction does not by itself gate independent domain implementation.

An adopted model ID must have an exact native proposition association, including
the complete condition statement and its actual owner. Mere retention of an ID is
insufficient. Domain workers consume those opaque associations and the existing
operation-ticket boundary. Source relations and search retain their own concrete
consumer obligations. Factor repeated ownership and recovery mechanisms where
possible while preserving the distinct typed carriers and admission requirements.

## D47 — Recover newly produced proofs as checked certificates

A search result is not necessarily a named theorem in its original specialist.
Add a fixed managed proof producer retaining the original target source and slice,
actual receiver development and source owners, and bounded inert proof transport.
It reparses the target in that receiver context, admits the certificate through
C02, and publishes an owned consequence. Numeric IDs and caller-created theorem
metadata cannot create this association.

The closed reconstruction graph gains a Proof construction and the result selector
distinguishes Named from Produced. Preserve existing named v1 recipes and use an
explicit v2 produced recipe; old decoders must reject unsupported new profiles.
Encode control-bearing proof bytes canonically and enforce encoded, decoded and
aggregate bounds before allocation/publication. Construction scopes own rollback
across replay, proof admission and descriptor publication. Recovery checks the
certificate against the exact reconstructed context and complete sequent; it does
not rerun heuristic search or issue an execution ticket.

The contract retains explicit hypotheses, premises and sort expectations. Empty
lists may qualify the initial closed-goal fixture but do not define the complete
system's expressive scope. Unsupported expectation profiles must reject explicitly
and remain tracked. This claim-producing path is distinct from D43 artifact
construction. Recovery owns the native producer/recipe migration; search owns its
actual caller and assembly owns shared publication consumption.

D47 recipe versioning clarification: v1 is exclusively a Named result over an
all-legacy graph and explicitly rejects Proof constructions. v2 supports Produced
and Named results, including a named descendant of a proof-producing development.
Use v2 whenever the graph contains Proof. Preserve existing v1 bytes, exact full
sequents and ordered ancestry; do not prohibit useful named descendants merely
to simplify the codec.

The approved retained-growth consumer uses an actual owned candidate development,
exact source/sample provenance and bounded typed expression resolution. It closes
samples and executes the existing installed mathematical bundle with charged
tickets. Sample observations are nonassertional artifacts with separate universal
obligations; explicit retention cannot activate a capability. Qualification and
publication consume separate native gates. Updating back to a retained prior
candidate requires fresh qualification under current authority and current-slot
comparison, never checkpoint rewind. These choices implement D43/D46 and do not
introduce a second candidate identity or authority system.

D43 fixed builder resource profile: one charged unit denotes one bounded native
source-build attempt, with cost 1 and exact request/execution/slot, operation,
profile, code and semantic-generation bindings. Source/import/export bounds and
controlled replay timeout remain enforced; a failed attempt consumes its charge.
This is an attempt budget, not a CPU-time or memory guarantee. Actual costs are
measured separately and no resource-isolation theorem follows from the timeout.

Update qualification must distinguish structural native-export comparison from
semantic preservation. Identical full-sequent syntax in sibling theories can name
constants with different definitions. Structural observations alone cannot justify
semantic-generation or result-cache reuse. Preservation requires checked context
and constant correspondence or an appropriate admitted equivalence bridge. A
meaning-changing replacement retains its new semantic identity and must satisfy
its own publication policy; it cannot inherit preservation by matching names.

Initial logical-export publication has a distinct native-export-admission/1
criterion with no regression baseline. An independently captured, source-owned
manifest/export intent precedes the build and binds exact canonical exports and
source closure. C02 admission supplies their actual propositions, assumptions,
extension policy and provenance. The qualification observation records only this
checklist, with a new semantic generation; it makes no behavioral-quality or
preservation claim. Empty-export candidates remain durable development artifacts,
not active logical capabilities. Structural replacement comparison remains a
separate baseline-backed profile. Host/native intent registration must connect
the protected original descriptor to the request, not copy names from its result.

D43/D46 shared implementation clarification: factor repeated mechanical identity,
handoff and lifetime bookkeeping across actual Math and Build/Qualification
consumers first, extending the closed family sum as other consumers become ready.
Each branch retains its own opaque native request, meanings, worker and checker;
there is no universal untyped value or caller-provided authority callback. A shared
resource-control cell does not replace the generated Owner permission machine.
The common durable handoff issues the same restricted tickets/permits and checks
current source and incarnation. Recovery retains distinct fixed request, candidate
and qualification roles, with shared source/context ownership and no replay of
charges or external effects. Central cleanup includes pending roots and preserves
the existing bounded cancellation, drain and retry semantics. This factoring must
not make every future family a prerequisite for running the current consumers.

## D48 — Versioned source acquisition preserves its actual representation

The original /1 source admission law equates retained bytes with the /1 batch
encoding. The /2 framed streaming input has different bytes and bounds; changing
only the runtime decoder would disconnect that law from its consumer. Introduce
an explicit versioned acquisition branch and migrate the implementation contract,
acquire/query theorem, admission and output judgment together. Preserve the /1
law and existing /1 recovery meaning. Never reinterpret an old recipe as /2.

The /2 branch requires an independent stream representation specification covering
frames, terminal/completeness state, schema and decoded rows, with refinement of
the actual bounded materializer and retention of the original /2 bytes. Merely
defining preservation as successful materialization is insufficient. Primitive
types, duplicates, long text, partial/error states and trailing malformed input
remain explicit obligations. The importer owns the materializer/specification;
the native source owner owns kernel/recipe/admission composition. Actual v1-data
family consumers and the graph projection consume that same guarded association.
The name of the upstream dataset does not select the wire version. Native checks,
actual acquired-source queries, restart and retirement must qualify the migration
before any wider source-preservation claim.

D43 upload timeout clarification: stopping a host wait does not cancel a queued
native command. Generate an inert bounded upload nonce before begin; retain the
nonce-to-stage/prepared association so lost begin or finish replies can be
reconciled. Exact-header retries are idempotent and conflicting reuse rejects.
Discard before acceptance monotonically abandons the upload and releases only
its producer ownership; it must suppress a racing finish publication. Acceptance
uses the exact nonce and known prepared handle. After acceptance, nonce discard
cannot release independently accepted/retained consumer ownership.

The host arbitrates offer, acceptance and cancellation explicitly. A lost accept
reply retains the known handle for reconciliation or confirmed handle release;
it cannot fall through generic cleanup that forgets unresolved native ownership.
Retiring jobs and tombstones remain bounded without evicting unresolved owners.
Settlement requires the original sender to have stopped and the relevant native
commands to have drained in protocol order, not merely a timed-out future.
Unresolved teardown is reported and retained; hard quiescence does not follow
from an unbounded thread join. Transport failure may require explicit resident
fail-stop, while ordinary upload timeouts use the fixed reconciliation protocol.

D46 composition clarification: independent resident requests cannot be grouped
in the client and presented as one dependent multipart request. Composition needs
one native request identity with its typed goals/slots and licensed intermediate
bindings, or an admitted same-request composition adapter. Final arbitration and
conversation adoption consume that request's actual outcomes; partial/refused
parts remain structured. Assembly owns the shared request/dispatch change with
dialogue and plan consumers. Existing single-goal behavior remains supported.

## D49 — Resolve installed imports through explicit exact public roots

Native builder and recovery share an immutable configured registry of approved
installed public roots. Each entry binds its actual native theory and admission
policy under the pinned image. A stronger boot/service context cannot stand in
for a lower imported theory merely because it includes that theory. Include only
configured roots, not every reachable ancestor by default.

Recovery introduces an explicit Installed_Public locator and includes its exact
identity in reconstruction keys. Preserve legacy Public/v1 meanings and reject
unsupported profiles rather than silently reinterpreting them. Builder import
resolution and replay consume the same registry; tests distinguish lower core and
boot contexts and reject mismatches. Assembly and recovery coordinate mutation
after the current capture; this is an implementation decision, not checked coverage.

## D50 — Preserve ConceptNet source semantics separately from graph costs

The shipped ConceptNet reader has lexical normalization, ranking, category and
confidence filters, bounded expansion and source metadata. Its source profile
retains all original cells and row identity, exact labels and explicit retrieval
coverage. Confidence/ranking weight is not shortest-path cost. A numeric graph
kernel alone does not preserve this source reader's behavior.

Use a fixed ConceptNet sibling request in the existing closed source family sum,
sharing acquired-source ownership, operation tickets and generic graph algorithms.
Keep corpus-specific label/coverage semantics in that profile rather than adding
lexical authority to generic graph calls. Exact-label repair and any original
plural/sense proposals remain explicit; source IsA edges do not become world
axioms. Truncated traversal cannot justify absence. Source, ConceptNet, graph and
rendering owners migrate actual consumers together; no parallel authority store.

## D51 — Qualify workspace compatibility before selecting an upgrade

D44 changes the exact shared-input dependency record. Old40ac checkpoints do not
match the new restoration contract; a same-generation restart pass does not prove
upgrade compatibility. Failed restoration may still allocate identities or update
resident bookkeeping even when it commits no native authority checkpoint.

New generations may be staged as inert candidates. Fresh installation and exact
same-generation staging remain allowed; replacing an existing selection requires
the guarded compatibility/promotion path. Artifact completeness alone cannot
select a replacement. Preserve the previous pinned generation and original state.

The host supplies a protected consistent snapshot under the actual exclusive
workspace writer lock, without opening the original database through a mutating
runtime. Reject unsafe live resource ownership rather than copying a process's
authority. Keep that lease through bounded old/new pinned-runtime probes. A failed
probe must leave original state and selection intact. Promotion needs its own
recoverable state/installation transaction; filesystem copying is not that proof.

Any D44 row normalization must be a checked, guarded migration using exact
authenticated request/source material. Do not rewrite dependencies by numeric ID,
clear old denials or recreate forgotten source payloads. Legacy codec meanings
remain explicit. Deployment, host, authority and recovery own the actual migration
and failure-preservation consumer; it is not yet qualified.

## D52 — Separate source acquisition from observer qualification

Common source ownership and acquisition must not require count-plan fields or
import graph/MST/search implementations. Fixed observer leaves own their settings,
meaning, executable and refinement; the installed aggregate statically connects
their closed request/result variants to the same authority and tickets.

The private input witness binds a qualified typed source association to the exact
versioned acquisition predicate, original manifest/bytes, actual carrier and
observation. Leaf entrypoints consume that same association through fixed native
specialization. An unrelated list of accepted theorems, private ML signature or
copied batch is not a correspondence proof. No runtime evaluator/proof callbacks
or recipient raw-carrier API are introduced.

The first row association supports count/relation/graph/ConceptNet. Documents
retain their own original-byte association; do not reconstruct document truth
from row text or introduce a universal payload type. Common lifetime/occurrence
mechanisms can be shared by these statically typed associations.

Acquire and cache authenticated scalar dimensions during charged decoding.
Observer precharge uses a cheap conservative bound before projection, sorting or
search; the charged worker rechecks actual bounds. These work models are not CPU
or memory theorems. Preserve the actual D48 base evidence before migrating it,
then qualify common acquisition, independent leaves and real aggregate consumers.

## D53 — Native multi-goal requests preserve per-child authority

One opaque parent scope owns original input, policy, observation and request ID.
Typed children own minted goal/slot/interpretation IDs, exact requirements,
semantic/executable pins and source leases. Sealing checks a common parent,
unique goals/slots and ordered typed predecessor references before one composite
reservation. Reuse the existing plan calculus for per-node partial outcomes.

Native equality/recovery must distinguish workspace/request/goal and exact slot;
the old single-entry request map cannot represent composite children. Parent
cancellation drains all children, scoped blockers preserve unrelated siblings,
and final arbitration precedes conversation adoption. A source-owned construction
rollback scope is not a semantic request parent.

Admission, execution/charge, qualification, output licensing and recovery consume
the owning child's pins. D43 qualification explicitly identifies its goal. Legacy
single-pin effect/job paths reject composite requests until their explicit goal
migration; that restriction does not complete heterogeneous effect acceptance.
Inventory and migrate every consumer and version the codec explicitly, preserving
authenticated old meanings rather than reinterpreting record fields. Authority,
assembly, plans, language, recovery and family owners coordinate this change after
the captured D44 baseline; independent interfaces are not a completed migration.

D43/D53 artifact composition retains typed `KnownInput` or `ReservedOutput`
parent references in the immutable requirement. The current unified ledger resolves
these to exact ordered candidate identities for execution; callers cannot guess
future IDs or rewrite the original requirement after its predecessor completes.
Builder, qualifier, recovery and native service consumers migrate together.

## D54 — Source-derived quantities retain a fixed composite association

A source-derived domain request uses an opaque fixed SourceDomain wrapper owning
the same qualified SourceCell and exact domain request, with checked unit/value/
model correspondence. Its lifetime and managed dependencies include both owners
through charging, publication, rendering, recovery and Forget. A bare domain
request cannot authorize the source-derived answer. Do not add caller-provided
dependencies to native proof construction merely to emulate this association.

Recovery reconstructs both associations and their checked relation; serialized
wrapper fields do not confer authority. The source, domain, integration and native
service owners migrate the closed ingress variant together. This is an approved
consumer design, not a claim of implemented or checked source/domain composition.

## D55 — Recover every typed child, including pending qualifications

Frame uses a generic RequestChildRole to require exactly one native material for
each retained child. A closed decoder selects Math/Source/Domain/Build/qualification
material; acceptance compares the actual operation family, full immutable
requirement, request/goal/slot and semantic/executable pins. Manifest tags only
select decoding. Missing, duplicate or mismatched material rejects. Historical
whole-request Math meanings retain explicit version handling.

InitialQualificationRequest and UpdateQualificationRequest are distinct from
measured qualification result roles. Pending reconstruction preserves exact
Prepared/Reserved/Started state and candidate/intent/baseline ownership without
replaying measurement, start, effects or tickets. A restored Started attempt with
no result is interrupted; retry needs a fresh eligible attempt and charge.

## D56 — Qualification output consumes its paid attempt

QualificationOrigin identifies the exact started reservation that pays for its
measurement output. StageOutput checks the same owner, goal, slot, pins, profile
and lineage; StageQualification consumes that output. It cannot substitute a
second ExecutePure charge or publish an unrelated universal assertion. Codec and
all typed consumers migrate together after the current compiler capture.

Execution, qualification and publication directly check shared parent identity
and dependencies for accessibility. Parent cancellation/revocation stops all
children; child-specific denial still preserves unrelated siblings.

## D57 — Qualifier observations have their own fixed semantic context

A TestObservation uses the actual fixed shipped qualifier observer context and
executable/profile pin. Candidate and baseline native generations remain explicit
protected subjects/dependencies of the observation and publication. A Build-to-Q
plan can therefore seal its observer goal before the new candidate exists; it
does not guess a future native generation.

The native observer meaning and producer must actually inhabit that context.
Relabelling a theorem in a candidate context is not this construction. Recovery
authenticates the observer against the actual installed image/code and rechecks
the exact candidate/baseline association. Candidate theorem exports retain their
own native contexts. Existing-candidate qualification alone is not Build-to-Q
composition acceptance.

## D58 — Artifact output context differs from builder context

artifact_assigned_generation records the actual new candidate native context.
The goal generation remains the fixed builder or observer context. The native
candidate gate supplies this correspondence; a metadata number cannot confer it.
The resulting generation participates in registration, managed dependencies and
exact reconstruction checks. Do not infer it from an unordered dependency list.
Batch this codec/consumer migration with D56 after the current capture.

## D59 — Restore domain conditions through their actual native association

Domain recovery uses distinct fixed pairs: `quantities/1` + `domain-request`
and `quantities-runtime-refinement/1` + `domain-output`, both controlled recipes
with their actual executable pin. Request material is nonassertional. Output
material retains the full conditional target, condition propositions, actual
owned request/output and admitted implementation/model/display contracts. It is
a runtime-refinement association, not a kernel theorem asserting each answer.

Restoration checks the fixed execution and native correspondence. A serialized
condition ID or target cterm cannot recreate authority. The fixed factory consumes
the real committed recovery object and reconstructs the exact receiver/source
pool declaration; only after full correspondence may it preserve authenticated
identities. The source-domain variant retains both reconstructed associations.
It never escapes as a bare domain request.

Inert snapshot types may move before the condition module, with explicit aliases
and consumer checks. Keep the private condition constructor and fixed restoration
factory in one lexical scope. A caller-supplied checking functor or raw-ID setter
is not an acceptable substitute. Generated checkpoint membership is a narrow
additional check, not the native correspondence proof. Service, recovery, host
and source-domain consumers migrate together; restart/Forget remain actual checks.

## D60 — Select interpretations before reserving required goals

Route alternatives are proposals, not independent required parts of a request.
Compare/select before constructing or claiming a child for each actual requested
goal; losing alternatives must not leave permanent NeedsInput children. The first
native comparison uses the same protected unclaimed input child, exact original
span, actual executable/native context and certified mathematical predicate.
Cross-family equality requires an admitted interpretation/conversion witness
retaining all conditions and dependencies. Metadata or display equality is not
that witness; without it, present distinct interpretations.

Routing policy distinguishes unaddressed input (`None`) from an explicitly
addressed but unavailable source (`Some []`). The latter permits no fallback.
An explicit allowed set restricts candidates. This is a language-policy change,
not a reinterpretation of the authority carrier. Actual native routing and
resident arbitration consumers require their own checks.

## D61 — Installed bootstrap uses an invocation-owned settings home

The standalone shell/JVM bootstrap needs neither checkout nor system Python or
compiler. It validates the same pinned inventory and invokes the fixed packaged
application entrypoints. Each invocation creates and owns a fresh temporary
settings home, including HOME/USER_HOME, under a controlled environment; durable
workspace and image locations remain explicit. Existing user-home startup files
must not execute before verification. Cleanup removes only its own temporary home.

The inventory records `bootstrap_user_home=fresh-owned-temporary/1` and the
`{bootstrap_home}` placeholder. Bootstrap code, runtime and OS remain explicit
trust assumptions; hashing the bootstrap is not a proof of its implementation.
Python/JVM verifier parity and actual outside-checkout source/native restart
consumers are separate gates. Earlier packages retain their historical policy.

## D62 — Pending initial qualification may precede its candidate

InitialQualificationRequest version 2 explicitly distinguishes Template and
Bound. A Template owns the actual prepared Build request, original intent, exact
reserved Build edge and fixed observer/qualification identities. It cannot invent
the candidate or its generation. Bind only the same durably acknowledged native
output lease, preserving those identities. Recovery restores the Build request
before the template; it does not execute the build or measurement.

The undeployed initial-request v1 format is explicitly refused, not silently
reinterpreted. Update requests remain bound-only under their existing version.
Tests distinguish restart before Build, after Build before qualification, and
interrupted measurement; the production acknowledgement/recovery consumer is
required beyond a scoped fixture.

## D63 — Search results retain proof provenance and original goal identity

Literal native search has closed `literal-native-proof/1` roles `search-request`
(nonassertional, empty sequent) and `search-output` (actual native acceptance,
nonempty full sequent), with the fixed executable pin. The outer output binds the
original request/goal/slot/evidence and receiver requirement to the protected
inner source-proof reconstruction. The proof development may have a fresh native
generation; it is provenance, not a replacement for the original goal's pins or
a second user-visible claim.

The fixed gate checks actual native context identity, exact target/full sequent,
source recipe and policy, then genuinely re-admits the checked theorem into the
original receiver generation. Copying IDs, calling contexts equal by name, or
restating into an unrelated alias is not this operation. Recovery checks the same
association and owns the inner verified reconstruction; releasing it must not
release another consumer's shared source owner.

The first public-image profile requires exact original receiver policy before
claim/charge. Arbitrary admitted package contexts need their own captured approved
receiver policy; this remains required scope beyond the initial fixed profile.
Host/registry roles, native gates, authenticated Scope recovery and actual resident
dispatch migrate together. A compiled protocol or isolated proof does not close
the deployed-search gate.

D63 clarification (2026-10-16): restoration requirements identify abstract evidence
by `(evidence ID, semantic generation)`, alongside request-child and artifact
requirements. Authenticated stored material selects the closed family decoder;
metadata must not relabel every kernel consequence as a generic KernelRole.
The fixed native factory verifies the concrete role, claim, target, pins, route,
dependencies and full requirement. Require exactly one accessible association;
reject absent, duplicate and cross-role matches. `restore_required` payload
version 2 carries this change; earlier captured deployments retain their original
wire meaning. This introduces no new persistent producer registry.

## D64 — Durable Build source bindings own the actual captured revision

Create a durable source binding from the actual managed source guard and exact
native BuildRequest slot in the same authorized commit. It pins original managed
source objects across head edits; a path/hash row alone is insufficient. Binding
identity is immutable after commit. Failed commits must not leave an authoritative
source owner behind.

Recovery restores historical read ownership only from authenticated committed
native capability material and continuing draft permission. Historical diagnosis
may inspect the captured source after a head edit. Resumption or publication
additionally requires the exact current head and a new explicit authorized
request/attempt under current permissions and budget. Restore never redispatches
or spends again; an interrupted/unknown old attempt remains historical.

Forget retires the durable binding and queues dependent native child/source
cleanup through the protected lifecycle. Independent native leases must not keep
permission alive. Inert durable bindings may survive a closed snapshot; active
process/worker owners still prevent it. The actual build, host persistence,
source-diagnostic and recovery consumers must check this association together.

D64 continuation clarification: an unpaid prepared/deferred request can remain
inspectable and bindable after restoration. Execution still needs an explicit
current-authorized transition checking actual parents, source head, permissions
and unspent budget/ticket. The first implementation may create a new request;
a future explicit continuation must reuse a proved modeled transition, never
treat historical source access as a dispatch grant.

## D65 — Session inputs retain independent source ownership

A session utterance must not depend on the survival of an unrelated child request
lease. A native SessionEntry retains the actual original input and observation
view under its own governed lifetime. Restoration uses a distinct typed
`required_session_inputs` inventory: exact original SessionLocal managed row,
input identity and recorded/pending phase. There is no inferred semantic generation
or fabricated zero generation in this requirement.

The closed nonassertional `native-session-input/1` / `session-input` envelope records
the actual positive captured native context, original source encoding/bytes,
observation, fixed executable pin and full development dependencies. The fixed
native verifier reconstructs and checks the whole expected source row before
acquiring the shared recovery pool owner. Host inventory supplies exactly one
protected current association per input; its manifest tag only selects a decoder.

Pending source registration can restore inertly before RecordUtterance. Transcript
access additionally needs actual recorded membership and current read authority.
Forget of session, input or required context prevents reconstruction, including
attempts to recover from dead child material. Restoration performs no dispatch,
adoption or theorem admission. Conversation, Frame/Owner, host inventory and native
recovery migrate together, with pending-crash, no-child and context-Forget consumers.

D65 wire migration: `restore_required` payload version 3 distinguishes artifact
requirements (`request-child`, artifact/evidence identity and known semantic
generation) from `source-input` requirements (input identity and pending/recorded
phase, with no semantic-generation field). The host supplies exactly one protected
source capability with the actual positive native context. The native factory
checks the complete original SessionLocal row before acquiring its owner.
Unsupported versions refuse explicitly; archived version 1/2 meanings remain
unchanged. Frame, inventory, host decoder and conversation recovery must migrate
together; a version tag alone does not qualify this path.

## D66 — Persist immediate effect transitions before actual handoff

The existing model's ClaimAndStart is an immediate transition: it changes Prepared
to Running, charges the actual intent and emits ClaimStart. It is not a modeled
Persist event. The existing native Frame/Owner transport nevertheless prepares
and journals immediate transition candidates as well as modeled Persist batches.
For immediate candidates its acknowledgement field is None; do not manufacture a
model DurableAck or add a parallel permission mechanism.

Use that actual path: protected native gate selects the exact ClaimAndStart
candidate; host commits its predicted charged/Running checkpoint and the existing
`native_dispatch` unknown record atomically; native acknowledgement validates and
installs that same candidate; the fixed executor consumes the one-use permit and
performs the handoff under the coordinator/current-source guard. Parsed command
fields are inspection data, never the permit. Target, attempt, source/configuration,
registration and epoch must agree with the actual retained objects.

Before commit there is no handoff. A crash after commit, including before native
acknowledgement or before external invocation, conservatively leaves Unknown.
Recovery never replays it. Reconciliation needs the actual matching attempt/protocol
observation and generated transition. Cancellation or retirement before permit
consumption prevents dispatch; it does not invent an external failure receipt.
The first real consumer is the controlled MCP fixture workflow. All crash windows,
changed configuration and late-publication refusal require actual bridge tests.

## D67 — Source-qualified quantities retain their own recovery association

Use the closed pairs `source-quantities/1` + `source-domain-request` (empty,
nonassertional) and `source-quantities-runtime-refinement/1` +
`source-domain-output` (nonempty actual source-qualified runtime refinement).
They preserve existing slot/evidence association meanings and do not confer a
per-answer kernel theorem. The protected material retains the Q wrapper,
Common/Cell acquisition ancestry, original source/Scope owners and all conditions.

A bare DomainRequest/Output fallback would discard source guards and is forbidden.
The fixed factory reconstructs the actual source and domain associations before
publication; missing original producer/recovery support remains an explicit
refusal. Registry/host closed-role decoding, native matching and resident recovery
migrate together after their active capture windows.

## D68 — Deferred Build recovery shares the original input constructor

Extract only inert exact metadata record types and their canonical validator/codec
before the Inputs module. Keep the authenticated deferred reconstruction factory
inside the lexical boundary of the actual private prepared-input constructor.
Recovery must check original metadata, input identity and ordered parent ownership;
it cannot reupload source or expose a setter for saved IDs.

The Build child may import the same Native_Request_Scope session/theory used by
recovery. Its dependency on Admission and Authority_Codec is acyclic and already
needed by the runtime. This is preferable to duplicating Scope or Inputs identity.
The builder, deferred codec, recovery factory and actual reconstruction tests
migrate together. Type extraction and codec round trips do not establish restored
execution authority or close the deferred Build consumer.

## D69 — MCP operations reuse one installed configuration owner

Capture and upload the actual managed configuration once, obtaining a protected
native configuration owner and its actual input identity. Only the private host
installer may bind that returned identity to the retained MCP installation.
Discovery, qualification and invocation each create a fresh bounded packet source
linked to this same owner. Configuration capture precedes packet creation when
the canonical packet label contains the native configuration identity.

Do not accept a caller-supplied sourceBinding as authority, allocate a new config
identity on every operation, or equate identical configuration bytes with the same
installed owner. The host transfers exact captured bytes and continuing managed
source pins; the native service retains their actual literal/source associations.
Current-head, epoch, credentials, registration and lifecycle checks still govern
handoff and publication. A digest or packet label is not an ownership witness.

Effects owns the fixed native configuration/packet transfer and retained owner;
the connector owns private managed capture and packet construction; assembly/host
own dispatch and the D66 durable acknowledgement. Their tests must exercise the
actual Discover → Qualify → Invoke sequence, changed configuration, cancellation,
unknown outcome and retirement. The sensor label contract remains unchanged.

## D70 — Artifact lifecycle closure is intrinsic and checked

Artifact publication must check current child access, including late staging and
acknowledgement after revocation. Its retained dependency closure must include the
actual owning request, goal, output slot, shared parent dependencies, original
goal references and result generation. These are intrinsic relationships, not
optional dependencies a proposed output may omit.

Use one canonical model helper to derive the expected closure from the uniquely
identified current owner. Missing or ambiguous ownership returns no result.
Preflight rejects proposed retained rows that do not already match this closure;
it must not manufacture native source or ownership evidence by adding IDs to
untrusted rows. Installation, visibility/recovery queries and the fixed native
producer/reconstructor use the same rule. Structurally available request/goal/slot
references belong in assignment references as well.

This strengthens the existing artifact path without a new schema or authority
mechanism. Authority and assembly own the migration; source ownership remains
checked by the native gate. Required consumers cover valid producer rows, omitted
intrinsic edges, request/goal/slot Revoke and Forget, and both staging and pending
acknowledgement windows. The first child-access guard repair can be checked
separately from the complete canonical retention migration.
