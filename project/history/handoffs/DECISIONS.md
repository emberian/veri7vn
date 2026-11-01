# Design decisions

This register records operative architecture and migration obligations. Implementation status and owners belong in [tasks.json](tasks.json); a decision is not execution evidence. Current user direction takes precedence.

The agreed [revision 2 architecture](../docs/ARCHITECTURE_PROPOSAL.md) combines open native meanings, generated authority, finite typed execution and durable ownership.

| ID | Status | Decision / consequence |
|---|---|---|
| D01 | accepted | Primary product is an Isabelle-native engineering environment with serious deployed search/growth. A client may be external; semantic authority is native. |
| D02 | accepted | Open HOL meanings plus specialized operational calculi and real proof/refinement bridges. No universal closed HOL value type or wrapper counted as a lift. |
| D03 | accepted | Performance from the start: staged compilation, efficient runtime values, whole-path measurement. Extraction-only products are optional projections. |
| D04 | accepted | Coherent specialist development connects authoring source, meanings, implementation, evidence, examples, sources and deployment. Generated artifacts derive from canonical source. |
| D05 | accepted | Interpretation, conditions, disagreement, failures, state and effects stay explicit. Versioned source reports are not global world-truth axioms. |
| D06 | accepted | Kernel theorem admission, refined/generated execution and evaluation-oracle execution have distinct assurance routes, with no silent downgrade. |
| D07 | accepted | Root integrates scoped implementation. Reuse native probes and upstream references only after checking their statements and runtime connection. |
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

Record the reason, affected contracts, migration and refuting checks for consequential changes. Preserve authenticated old codec meanings or reject them explicitly. Update implementation status in the task ledger rather than declaring a migration complete here.

## Scope

Ordinary deployment may include Isabelle. Authoring, stateful specialists and connectors are core compatibility scope. Examples guide search but cannot license universal rewrites. Support packages need no fake callable exports. Expression/DAG correctness does not establish routing, sources, state or deployment.

## Architecture rationale

One generated authority and statically linked typed family interpreters avoid incompatible permission machines and universal untyped values. C01–C05 connect runtime guards, worker proof transport, generation migration, publication and recovery. Descriptor validation remains structural; actual native objects and executable consumers supply semantics.

## native/host event serialization

Revision and epoch alone miss changes such as AddBlocker and SetOutcome. Serialize all generated events with staging, precommit, artifact installation, transaction and acknowledgement, or prove an equivalent complete-state token. Restore grants, blockers, outcomes and lifecycle state. Rendering consumes currently licensed visible bindings, not raw Accepted tags (D24, PO-04, TB-05).

## numeral representation and native recovery

D31 uses the narrow Code_Target_Numeral/Nat/Int closure; unary nat cannot represent large metadata efficiently. Migrate actual generated consumers and pins without changing HOL meanings. Durable ID ranges commit before issuance; crashes burn unused IDs. Reconstruction checks complete native target, hypotheses, premises, sorts, interpretation, generation and dependencies against the latest lifecycle checkpoint. Pure source kernels sit below family admission; sealed executable wrappers join both without cycles or duplicate carriers.

## requests, lifecycle and qualification

Reserve immutable requirements before answers exist. Each graph node has its own output slot; checked native substitution preserves every original premise occurrence and its correspondence. Retained snapshots and reserved future outputs are distinct. Native producers attach complete managed provenance; public contexts survive unrelated private-source invalidation.

The generated authority owns adoption, freshness, costs, jobs and qualification. Private typed tickets bind actual profile/code, request/slot, resolved input and cost; persist the charge before one-use serialized handoff. Recovery never reissues tickets. Qualification binds subjects, policy, learned state, source observations, scorer, split, exposure, attempt and resources. Reserve held-out exposure before inspection/export/worker access; aliases cannot refresh eligibility. Measured observations and independently admitted capabilities meet only at guarded publication. Native policy join requires actual ancestry, approved axiom union and oracle-policy intersection.

Unknown source origins and incomparable clocks remain explicit. Window absence needs original-population coverage. REAL cells retain binary64 bytes separately from numeric meaning; long text and streamed decoding require independent semantic preservation.

## ordinary expert source and actual operation instances

C01 includes original expert .thy source. Controlled constructors record conservative extensions; resetting policy over a finished worker theory bypasses admission. Replay approved imports/commands/methods against original byte spans. Unsupported packages remain editable and diagnosable. Boot identity pins actual loaded source/setup/toolchain, not theory names or a heap trailer.

A sealed fixed-family instance joins executable registration, source declaration, tickets and qualification. Representation/profile IDs alone do not create a callable association. Thresholds use actual bound metric values/units and remain operational policy; identical sequent syntax across different definitions does not establish preservation.

## access, exposure and real search consumers

Retained access preserves original read versions, session and clock requirements; follow-up requests cannot erase them. Recipient projections expose selected qualified content and necessary conditions, not privileged raw rows or theorem/context getters. Promotion retains Forget provenance.

Search begins with bounded fixed retrieval/application/simplification/splitting and independently reconstructed proof transport. Complete scope still includes cross-family retrieval, synthesis, counterexamples, conjecture/refinement proposals, adaptive orchestration and deployed budget/cancellation. A failed proof route is not a refutation.

## native assembly and reconstruction identity

One native state carrier, owner and private ticket instance serve the resident application. Reject unsupported commands before committing their state. Shared durable generations reconstruct one actual context island; equal replay text in sibling theories is insufficient for native composition. Distinct logical generations may share physical construction while retaining separate parent/source provenance.

Governed test expectations are attributed data, not world axioms. Preserve original Oracle7 scorer behavior under a named compatibility policy; replacement typed scorers cannot claim legacy parity merely by sharing examples.

### D38/D39 implementation boundaries

Fixed typed checkers stage unregistered contexts and atomically install complete identity/source fragments. Never allocate fresh durable IDs and overwrite them. Canonical IDs remain one-to-one across the live workspace; detach only at actual owner teardown. Poison the incarnation if identity installation fails after mutation.

Recovery preserves native definition command forms, code certificates and ordered ancestry. Semantic dependencies and managed ownership are distinct; retained outputs cover both. Record ownership before writing private artifacts, atomically adopt writes, and clean abandoned writes. Denial precedes erasure.

Fixed row metadata may decode in a public context only when it contains public constructor data. Actual protected configuration slices establish declaration ownership; caller numeric IDs cannot supply request/attempt/output authority. A shared fixed-checker source pool preserves equal-byte distinct origins and rejects conflicting payloads.

## lifetime, source fidelity and display contracts

Use independent input leases and explicit invalidation. Mask bounded ownership mutations and rollback, not proof search or long joins. Resident cleanup drains worker and completion monitor before releasing roots. Raw input, prepared parameter and execution are separate managed rows.

Preserve original bytes and translate Isabelle symbol positions to original byte offsets; Token.source_of normalized text is not a fidelity primitive. Observation refresh rejects inaccessible sessions/read objects and forgotten utterances. Durable allocator extension appends disjoint committed ranges to the same allocator and atomically reserves each producer's complete ID bundle.

### Refined display bridge and source-owner migration

A fixed native display contract joins original integer capture/AST, result projection and sentence meaning/escaping. Actual emission and recovery retain its identity, math execution pin and statement-checker pin. Shared bridge IDs share an owner; equal pins alone do not merge logical identities. Release bridges before shared instances/contexts. Source/context fragments install atomically; no resident raw saved-ID factory is exposed.

### Effect authorization

Attempts need an explicit owning goal, optional reserved output and attempt-specific staging revision. Current dependencies, blockers, capability and handoff authority must be checked; immutable request prestate remains historical. D42/D66/D72 govern the coordinated implementation. Legacy singleton restrictions remain explicit until owning-child migration is qualified.

## measured closure costs and recurring effects

Indexed Forget must preserve the exact returned list and RemoveManaged order, including HOL remdups last-occurrence semantics and unchanged seeds for empty values. Require the native equality/refinement theorem, selected generated code and composed cleanup checks; sorted test oracles cannot establish order.

Each recurring poll creates fresh child request/goal/slot/attempt under an immutable authorized parent/job template. Charge child and cumulative budgets atomically; preserve remaining budget across restart. Parent cancellation and old incarnations block late publication. Persistent-monitor freshness policy must be explicit. Check two polls, stop/restart, stale completion and budget preservation. Low-level lease identity and owner counts change atomically with bounded rollback.

## D43 — Native build candidates are typed artifacts

Use closed ClaimRequirement/ArtifactRequirement and ClaimOutput/ArtifactOutput sums. ArtifactReady is nonassertional; empty-export developments are valid retained candidates. Keep construction, C02 theorem admission and qualified activation separate. Typed KnownInput/ReservedOutput edges preserve ordered parent ownership; resolve future outputs through the actual ledger.

The fixed builder captures exact source/revision/manifest/export intent, approved parents and shipped executable pin. One charged unit pays for one bounded build attempt, including failure; it is not a CPU/RSS guarantee. Only durable execution issues its one-use ticket. Recheck source head, ownership, blockers and lineage at staging/acknowledgement. Caller-owned construction scopes cover replay through descriptor/candidate publication. Restore the protected recipe without redispatch. Migrate algebra, codec, builder, native provenance, service, host and authoring together.

## D44 — Atomic retirement of now-unowned native support

Forget the primary roots and now-unowned shared support atomically in one checkpoint/epoch update. Reject empty root lists; preserve singleton behavior. Under serialization derive extra roots from exact current owners, preserving required requests, accessible unused evidence and retained consumers. Cancel uncommitted proposals sharing removed groups at acknowledgement; drain native resources after durability.

Protect survivors through the entire dependency closure, including inaccessible derivatives and duplicate-ID edges. Use a proved indexed backward summary and exact order-preserving denial difference rather than repeated scans. Transport newly denied Revoke and Forget categories separately; already revoked objects may still need erasure. Preserve and retry all cleanup jobs across repeated categories, including empty deltas.

Bounded opaque construction scopes register fresh products before unmasking and transfer them at receiving-owner publication. Abort releases only those products. Check last owner, survivors/unused evidence, immediate Forget, crash/restart, pending cancellation and cleanup failure.

## D45 — Keep resident protocol input free for Scala replies

Protocol_Command must enqueue bounded fixed service commands and return, allowing Scala.result replies to reach the reader. One owned FIFO preserves command order and existing authority serialization. Initial limits: 64 active/queued messages, 16MiB retained frames, existing 2.2MB frame bound. Specify overflow and exact request failure replies.

Fresh burst identities prevent stale finalizers clearing successors; empty-queue worker reset is atomic. Matched fatal abort poisons the incarnation. Fork failure rejects without committed enqueue. Late failure may follow a reply; this is not exactly-once delivery. Keep search/joins outside authority locks and qualify concurrent publication, restart and Forget in the real resident.

## D46 — Extend the resident consumer through fixed capability families

Extend closed request/gate/recovery sums through fixed typed families sharing reservation, charge, output and lifecycle. Factor mechanical identity/handoff/ownership across actual consumers; retain each opaque request, worker, meaning and checker. A resource-control cell is not permission authority.

Adopted model IDs require exact owned native propositions and complete conditions. Independent client requests cannot impersonate dependent multipart composition: use one native parent with typed children, licensed intermediates and final arbitration before adoption. D43 does not block independent domain work; new families need actual consumer checks, not callbacks or another service.

## D47 — Recover newly produced proofs as checked certificates

Managed proof production retains actual receiver/source/slice and bounded inert proof transport, reparses the target and admits through C02. Recovery uses a closed Proof construction and Named/Produced selectors. v1 means Named over all-legacy graphs and rejects Proof; v2 supports either selector, including named descendants of proof-producing developments. Preserve full sequents and ordered ancestry. Canonically encode control bytes and bound encoded/decoded/aggregate allocation.

Caller-owned scopes cover replay/admission/publication; recovery reconstructs certificates, never search or tickets. Initial empty external hypotheses/premises/sorts are a supported profile, not a permanent expressive limit.

Retained growth candidates preserve source/sample provenance and execute installed typed mathematics under charge. Samples are nonassertional; universal obligations, qualification and activation stay separate. Structural export comparison cannot justify semantic/cache reuse across changed definitions. Initial native-export-admission/1 has no baseline: protected intent precedes Build, C02 checks exports, and empty-export artifacts remain inactive. Returning to a prior candidate requires fresh current qualification.

## D48 — Versioned source acquisition preserves its actual representation

Version acquisition explicitly: /1 bytes obey the original batch law; /2 framed streams need their own independent representation specification and refinement of the bounded materializer. Migrate runtime, acquire/query theorem, admission, output and recovery together. Preserve old meanings. Cover frames, schema, completeness, duplicate/primitive cells, long text, partial/error state and trailing malformed input; successful materialization alone is not the specification.

Uploads use bounded inert nonces with exact-header idempotency, conflict refusal and reconciled begin/finish/accept ownership. Discard before acceptance monotonically abandons producer ownership and suppresses racing finish; after acceptance it cannot destroy independent consumers. Lost replies retain unresolved owners until ordered command drain and sender settlement. Timeouts do not cancel native work; unresolved teardown may require resident fail-stop. Qualify actual acquired-source/family queries, restart and retirement.

## D49 — Resolve installed imports through explicit exact public roots

Builder and recovery share an immutable registry of configured exact installed public roots, binding actual theory and admission policy under the pinned image. A stronger boot theory cannot replace a lower imported root. Do not expose every ancestor automatically. Installed_Public locators participate in reconstruction keys; preserve legacy Public/v1 semantics. Check lower/core versus boot contexts and mismatch refusal.

## D50 — Preserve ConceptNet source semantics separately from graph costs

ConceptNet retains lexical normalization, exact labels/cells/row identity, ranking/category/confidence policy, bounded expansion and retrieval coverage. Ranking weights are not shortest-path costs; source IsA edges are not world axioms. Use a fixed sibling in the closed source family with common acquisition/tickets and generic graph algorithms. Label repair and plural/sense proposals remain explicit; truncated traversal cannot justify absence. Qualify the real reader/graph/rendering composition.

## D51 — Qualify workspace compatibility before selecting an upgrade

Stage new generations inertly. Replacing the selected installation requires guarded compatibility/promotion, not artifact completeness or same-generation restart. Preserve old selection and source state.

Hold an actual exclusive workspace snapshot lease through bounded old/new pinned-runtime probes; reject unsafe live ownership. Failed restoration can mutate native IDs, so original storage must remain isolated. Promotion needs a recoverable state/installation transaction. Normalize old rows only by checked migration over authenticated request/source material; never rewrite IDs, clear denials or recreate forgotten bytes. Qualify failure preservation and compatible upgrade separately.

## D52 — Separate source acquisition from observer qualification

Common acquisition owns the exact versioned source/manifest/bytes/carrier/observation independently of count, graph or search leaves. Fixed observer specialization consumes the same opaque typed association and its correspondence proof, not copied batches or accepted-theorem lists. Documents keep their own original-byte association; no universal payload or raw recipient carrier API.

Cache authenticated dimensions during charged decode. Precharge uses a cheap conservative bound before expensive projection/sort/search; workers recheck actual bounds. These work models do not prove CPU/RSS limits. Preserve D48 base evidence and check independent leaves plus aggregate consumers.

## D53 — Native multi-goal requests preserve per-child authority

One opaque parent owns original input, policy, observation and request ID. Typed children own goal/slot/interpretation identities, exact requirements, pins and source leases. Seal common parent, unique identities and ordered typed predecessors before composite reservation. Construction rollback scopes are resource ownership, not semantic parents.

All consumers distinguish workspace/request/goal/exact slot and use the owning child's pins. Parent cancellation drains children; scoped denial preserves siblings. Final arbitration precedes adoption. Legacy single-pin effects/jobs refuse composite requests pending explicit migration. Inventory every consumer and version old meanings explicitly. Artifact parent edges retain KnownInput/ReservedOutput until the actual ledger resolves them; no guessed future IDs or rewritten requirements.

## D54 — Source-derived quantities retain a fixed composite association

An opaque fixed SourceDomain wrapper owns the same qualified SourceCell and exact domain request with checked value/unit/model correspondence. Charging, publication, display, recovery and Forget retain both owners and conditions. Bare domain requests or caller-added dependency IDs cannot stand in for this native relation. Restore both actual associations before publication and qualify the closed ingress/service consumer.

## D55 — Recover every typed child, including pending qualifications

RequestChildRole requires exactly one actual native material per retained child. Closed family decoding compares operation family, full immutable requirement, request/goal/slot and semantic/executable pins. Tags choose decoding only; missing/duplicate/cross-role material rejects.

Pending initial/update qualification roles preserve Prepared/Reserved/Started and candidate/intent/baseline ownership without replay. Started without result is interrupted; retry needs fresh eligibility and charge. Preserve explicit historical whole-request formats.

## D56 — Qualification output consumes its paid attempt

QualificationOrigin binds measurement output to its exact paid started reservation. StageOutput checks owner/goal/slot/pins/profile/lineage; StageQualification consumes it. Neither an extra ExecutePure nor an unrelated universal claim substitutes. Execution, qualification and publication directly check shared parent identity/dependencies and current accessibility. Migrate codec and typed consumers together.

## D57 — Qualifier observations have their own fixed semantic context

TestObservation inhabits the fixed shipped qualifier observer context and executable/profile. Candidate/baseline generations are protected subjects/dependencies, allowing Build-to-Q sealing before the candidate exists. Do not relabel candidate-context theorems. Restore actual observer image/code and exact subjects; existing-candidate checks alone do not qualify composition.

## D58 — Artifact output context differs from builder context

artifact_assigned_generation is the actual produced candidate context; goal generation remains builder/observer context. The fixed gate proves correspondence and retains it through registration, dependencies and recovery. Do not infer generation from unordered dependencies. Migrate with qualification lineage and consumers.

## D59 — Restore domain conditions through their actual native association

Use fixed `quantities/1` + `domain-request` and `quantities-runtime-refinement/1` + `domain-output` roles with actual executable pins. Requests are nonassertional; outputs retain conditional target, condition propositions, actual owned objects and admitted implementation/model/display contracts. This is runtime refinement, not a kernel theorem per answer.

Restore real committed native declarations and full source/receiver correspondence before preserving authenticated IDs. Keep private condition constructors and fixed factory together; no checking callback/raw-ID setter. Source-domain outputs preserve their wrapper. Check actual restart/Forget and host/service consumers.

## D60 — Select interpretations before reserving required goals

Select route proposals before constructing required children. Losing alternatives must not become permanent NeedsInput goals. Native comparison retains the same protected input/span, context/executable and certified predicate. Cross-family equality needs an admitted interpretation/conversion witness with conditions/dependencies; otherwise show distinct interpretations.

Routing distinguishes unaddressed None from explicitly addressed unavailable Some []; the latter forbids fallback. Allowed sets restrict candidates. Qualify actual native routing and resident arbitration without changing authority meanings.

## D61 — Installed bootstrap uses an invocation-owned settings home

Standalone shell/JVM bootstrap verifies pinned inventory without checkout, Python or compiler. Each invocation owns a fresh temporary settings home (HOME/USER_HOME) under controlled environment; durable workspace/image paths are explicit. User startup files must not run first. Cleanup removes only that home. Record `bootstrap_user_home=fresh-owned-temporary/1` and `{bootstrap_home}`. Runtime/OS/bootstrap remain trust assumptions. Qualify verifier parity and outside-checkout source/native restart separately.

## D62 — Pending initial qualification may precede its candidate

InitialQualificationRequest v2 separates Template from Bound. Template owns actual prepared Build, original intent, exact reserved edge and fixed observer identities; bind only the same durably acknowledged native output lease. Restore Build before template without execution. Refuse undeployed v1 explicitly; update requests remain bound-only. Check before Build, after Build before qualification and interrupted measurement through production acknowledgement/recovery.

## D63 — Search results retain proof provenance and original goal identity

`literal-native-proof/1` distinguishes nonassertional empty-sequent search-request from actual full-sequent search-output. Outer material preserves original request/goal/slot/evidence/receiver; fresh proof generation is separate provenance. The fixed gate checks actual context, full target/sequent, source recipe and approved policy, then re-admits in the original receiver. Recovery owns the private verified graph without releasing another consumer's roots.

The initial public-image profile requires exact receiver policy before claim/charge. Admitted authored contexts remain required: capture their actual approved policy and reconstruct them through protected P ownership. Separate executable pin lineage from logical dependencies only after auditing fixed tactics and checking a real sibling-context consumer; no theory-name relabel or silent image-policy relaxation.

Restoration identifies abstract evidence by evidence ID plus semantic generation; closed native factories check actual role/claim/route/conditions/pins/dependencies and exactly one accessible association. restore_required v2 introduced this distinction; later versions retain explicit meanings. Current deployment still needs composed proof, publication, recovery and lifecycle checks.

## D64 — Durable Build source bindings own the actual captured revision

Commit durable source binding from the actual managed guard and exact BuildRequest slot. Pin captured source objects/revision across head edits; immutable binding IDs and path/hash metadata alone grant no ownership. Failed commit leaves no authoritative owner.

Authenticated restoration provides historical read access under continuing draft permission. Resumption/publication additionally checks current head/parents/permissions and a fresh authorized request/attempt/budget. An unpaid restored prepared/deferred request may remain inspectable/bindable; no automatic dispatch. Forget retires binding and dependent roots; independent physical leases cannot preserve permission. Qualify host/native diagnostics, terminal history and recovery together.

## D65 — Session inputs retain independent source ownership

SessionEntry independently retains original input/observation; it cannot borrow lifetime from a child. required_session_inputs identifies exact SessionLocal row/input and pending/recorded phase, without invented semantic generation.

`native-session-input/1` / session-input is nonassertional and carries positive actual context, original encoding/bytes, observation, executable pin and development dependencies. Fixed verification checks the whole expected row before shared-pool acquisition. Pending registration may restore inertly; transcript reads need recorded membership and current authority. Forget session/input/context denies reconstruction. No dispatch/adoption/theorem admission occurs.

restore_required v3 separated artifact tuples from source-input phase rows; subsequent versions evolve explicitly. Frame, host inventory, conversation and recovery migrate together with pending-crash/no-child/context-Forget checks.

## D66 — Persist immediate effect transitions before actual handoff

ClaimAndStart is immediate: Prepared→Running, exact charge and ClaimStart. Use the existing host journal path for immediate candidates, with acknowledgement=None rather than invented DurableAck. Commit the predicted checkpoint and native_dispatch Unknown record atomically; native acknowledgement installs that candidate; fixed executor consumes the permit under current-source/serialized handoff.

Before commit no invocation occurs. Postcommit crashes conservatively leave Unknown; recovery never repeats execution. Reconcile only actual matching observations. Cancel/retire before consumption denies handoff without fabricating a failure receipt. Host OperationIdentity separately carries numeric operation and name; compare profile/code/operation/step/units and Build installation step. Test swapped fields and all commit/handoff windows.

## D67 — Source-qualified quantities retain their own recovery association

Use `source-quantities/1` + source-domain-request and `source-quantities-runtime-refinement/1` + source-domain-output. Preserve actual SourceDomain wrapper, Common/Cell ancestry, original Scope/source owners and every condition. A bare Domain fallback discards guards and rejects. Registry/host role decoding and native/service restoration migrate together; missing producer support remains explicit refusal.

## D68 — Deferred Build recovery shares the original input constructor

Extract inert metadata types/validator/codec before Inputs, but keep authenticated deferred factory beside the private prepared-input constructor. Check original metadata/input and ordered parents; neither reupload nor raw saved-ID setter is permitted. Reuse the same Native_Request_Scope identity. Codec/type factoring is not execution authority: builder, recovery and actual reconstruction tests must connect.

## D69 — MCP operations reuse one installed configuration owner

Capture managed MCP configuration once into a protected native owner/input. Only private installer binds it to installation. Discovery, qualification and invocation create fresh bounded packet sources linked to that owner; capture configuration before labels containing its identity.

Equal bytes, sourceBinding IDs, packet labels or repeated allocation cannot establish same installation. Preserve exact source pins plus current head/epoch/credentials/registration/lifecycle guards. Qualify Discover→Qualify→Invoke, changed configuration, cancellation, Unknown and retirement. Sensor label meanings remain separate.

## D70 — Artifact lifecycle closure is intrinsic and checked

Artifact publication rechecks child access at staging and acknowledgement. Canonically derive full closure from unique actual owner: request/goal/slot, parent dependencies, original references and result generation. Reject ambiguous/missing ownership and proposed rows omitting intrinsic edges; do not repair untrusted rows by adding IDs. Use the same rule for installation, visibility, recovery and native producers. Keep available request/goal/slot references in assignment references. Check omitted edges and Revoke/Forget in both windows.

## D71 — Native gate liveness cannot reenter its authority owner

Gate liveness runs under Owner's monitor and may inspect intrinsic objects/physical ownership only. Synchronously refuse same-owner reentry; do not mirror permission state. Statically split intrinsic conversation roots before Owner from fixed query-driven ingress after it.

ExactObservation means full canonical equality plus access, including clocks/read metadata; selected-read freshness alone is weaker. Carry original observation as expected inert data and compare against current state during staging/versioned acknowledgement.

An early sealed Roots capsule independently retains original session Entry/input/pin/source/development across Scope/recovery. Its destructor-only release cannot query Owner or compute dependencies under the monitor. Keep retry roots on failure. Check reentry refusal, successful later acknowledgement and stale observation in both windows.

## D72 — Effect responses are atomically retained observations

External responses are nonassertional acquired sources, distinct from claims and Build artifacts. StageEffectObservation/RecordEffectObservation atomically register RequestLocal source, exact attempt/status and Confirmed/EffectFailed through Persist/DurableAck. Fixed native material binds real protocol/encoding/bytes/receipt/configuration/operation; canonical JSON is not original wire truth. Unique Running/Unknown attempt, current child/blockers/configuration/job epoch and original ownership are checked at staging/acknowledgement without recharge. Prevent duplicate intent IDs resetting history.

Unknown has no response and never permits reinvocation. Status-only terminal reconciliation forecloses later attachment; response consumers commit bytes and status together. Persist terminal history after Forget to reject exact/new-batch replay. Private staged storage joins the same commitNative transaction; draft APIs cannot expose unacknowledged responses. Failure reports undelivered, not retried external execution. Retrieval borrows actual source under current permission; restart never invokes.

Use `local-mcp/1` + effect-source-observation, Controlled_Recipe, empty sequent and exact pin. Reuse the bounded authenticated response blob; configuration/packet/response still need shared-pool associations. restore_required v4 has semantic artifact tuples plus source-input pending/recorded and acquired-source confirmed/failed rows without fabricated generations. Inner authority metadata wire v3 is a separate migration; mismatches preserve old checkpoints.

The counter profile uses bounded typed JSON-tree witness with independent exact canonical and ordered-receipt checks. Reject duplicate keys, invalid scalars/unsupported numbers; do not treat JVM Double formatting as proof. effect_source_open binds actual source/attempt/status/hashes/context to owner incarnation/checkpoint; only bridge-minted opaque confirmation opens it, serialized against lifecycle mutation. Lease reads continue checking permission. Configuration epoch belongs to original installed owner, distinct from attempt/job epoch, and must migrate upload/recovery/packet/response together.

Qualify real delivery/retrieval/restart, persistence failure, blockers/cancellation, status-only resolution and replay after Forget. Legacy singleton effects remain explicit until owning-child migration.

## D73 — Temporary recall readers have leases; ordinary sessions have no default TTL

Temporary saved-conversation readers default to seven days, clamped to 1–365; ordinary saved conversations have no default TTL. Each reader owns managed identity and persisted exclusive deadline; expiry revokes derivatives without deleting the original. Conversation Forget retires readers. Preserve quotation/date/route provenance and apply expiry to cached/pronoun recall too.

Use generated lease/source policy plus opaque native wall-clock witness with unix-utc-ms/1 origin. Check created≤now<deadline at staging and acknowledgement, exact policy/source and authority version. Reject missing/duplicate leases, incompatible origins or earlier times. Restore original deadline without renewal/replay. Native wall time is environmental, not reboot-monotonic proof. Automatic expiry remains pending until actual consumer checks.

## D74 — Cancelled execution and retained historical verification are distinct

Separate cancelled execution from retained verification. First make output capsules carry/authenticate original source/recipe and restore inert proof context without active Scope, dispatch or recharge. Then narrow active child inventory only to actual obligations: parent/child accessible, slot present, parent not cancelled and goal not Cancelled. Do not discard other terminal continuations such as accepted measurement awaiting qualification/publication. Evidence/artifacts/acquired sources retain their own governed ownership.

Search and Math need independent historical native owners; unpublished evidence needs its authenticated capsule. Build OutputOwner independently retains actual parent CandidateOwner leases, not copied handles. Preserve installed roots/restored ancestry and counted lifetimes. Never fabricate consumed execution for precharge cancellation. Stopped requests may retain generated history without a worker.

No-result cancellation also retains accessible original bytes through an explicit inert source-support requirement with exact original role/child/context/recipe. Derive attribution from actual retained source/read association and original metadata; dependency intersection is insufficient. Source-only restore creates no Scope/prepared worker/ticket. Keep fail-closed inventory until Math/Search/Build/aggregate consumers migrate together. Check cancel before/after charge, retained output/source, restart, historical retrieval and Forget.

## D75 — Effect attempts retain their original recipe before execution

Persist `local-mcp/1` + effect-request nonassertional Controlled_Recipe at Reserve, before support/ClaimAndStart. It owns original control recipe, configuration/packet, immutable configuration epoch, actual managed public-image context and exact pin. Missing response cannot erase ownership needed to inspect Unknown.

Restore inert original ownership/history through the existing authenticated graph/journal, never permits/executors/external sessions/retries. Effects, authority, assembly and host coordinate role/version migration. Credential revisions invalidate execution configuration; historical response access follows actual managed source permissions. Map any credential-dependent denial to a real managed owner. This mapping remains pending co-review before connector lifecycle completion.

## D76 — Search logical dependencies are separate from executable lineage

Approved; implementation and qualification pending. Fixed search ML needs actual
HOL logical ancestry and checked transfer of its embedded conjI/impI facts, not
ancestry from the theory that compiled the Search implementation. Replace only
that implementation-theory guard at prepare. Preserve exact executable pin,
private ticket and generation matching, receiver ancestry into worker, target/fact
transfer and independent full-proof reconstruction/admission back in the exact
receiver. Keep worker=receiver where the profile permits; do not create an
artificial merged theory merely to satisfy executable provenance.

Check a real authored Main-based sibling receiver, plus wrong pin/ticket and
foreign receiver refusals. This narrow change does not qualify authored graph,
approved-policy, publication or recovery integration. The broader typed source
discriminator and native-source/1 source-input independent-root migration remain
required deferred work. Coordinate the finite edit after the current loaded
Workshop capture; the remaining-budget priority is routing/metaprogramming and
documentation rather than another broad schema migration.
