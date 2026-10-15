# Adversarial design review

2026-10-15. Design recommendation, not an implemented architecture or a new
scope agreement. Read against [the architecture](../ARCHITECTURE_PROPOSAL.md),
[G01–G08](../review/PREIMPLEMENTATION.md), C01–C05 semantic revision 1 and
[PO-01–10](../../project/PROOF_OBLIGATIONS.md). Source evidence below comes from
the bounded [domain](../review/domain-gaps.md), [runtime](../review/runtime-gaps.md)
and [workbench](../review/workbench-gaps.md) inspections; these scenarios were
not executed. The user has not requested an example-driven implementation ritual.

## Judgment

The native Isabelle direction is viable. The current documents are a strong
requirements register, but not yet an architecture sufficient for independent
implementation. They permit several mutually incompatible implementations that
would each appear locally compliant. Honest completion gates do not solve that.

I would keep the destination and reduce the number of mechanisms: **one authority
and state transition core, one development/artifact lineage, one capability
registration discipline, and several deliberately separate domain semantics.**
Search, authoring, qualification, connector work and deployment consume those
mechanisms; they do not each acquire their own result authority, publication
protocol or mutable registry. Domain-specific algorithms and representations
remain independent. This is substantial software even with that reduction.

## Changes I would make before implementation fans out

### 1. Fix the native privilege boundary before promising policy independence

An opaque accepted-record constructor does not constrain arbitrary ML running
inside the same privileged Isabelle process. Native plugins can perform host
effects or mutate operational state without asking our scheduler. Theorem
dependency auditing cannot establish the absence of those effects. C05 already
says ML is trusted plugin code; its practical consequence must become an
installation/runtime rule, not a footnote.

Use three explicit interfaces: ordinary authoring produces declarations in
supported languages; search workers produce untrusted candidates; privileged
native extensions are installed into a reviewed runtime generation with an
explicit trust boundary. Generated code does not obtain the third interface by
being placed in a package. Proof-search methods exposed to strategies come from
registered operations; arbitrary ML text is not a search action. An expert may
extend the native application, but such an installation changes its trust and
deployment closure. This preserves native openness without pretending all plugin
code is sandboxed or formally verified.

The precise target is acceptance soundness for every permitted policy program
and worker response under those execution interfaces. It is not immunity to a
malicious extension already granted full authority inside the kernel host.

### 2. Make the modeled transition core the actual authority path

Choose a code-generated HOL transition/checking core over finite request,
publication, dependency and authority records. Connect it to a small native ML
gate retaining actual contexts, terms and theorems, and to host executors through
explicit commands and completion observations. Its core state contains typed
references and provenance identities, not copies of arbitrary source corpora or
all of HOL. The generated transition result is consumed by the real runtime;
there must not be a parallel hand-written dispatcher that merely resembles it.

The native gate and host observer remain separate proof/implementation
obligations. A proof that a record has permitted flags does not prove that ML
faithfully extracted its theorem dependencies, that a function pointer matches
its code-generation identity, or that a remote action happened. These bridges
must be named before choosing the data representation. Do not conceal them in
a generic `adapter_correct` assumption and declare the architecture closed.

Avoid both extremes: a universal reflective HOL interpreter would be unnecessary
and obstruct native extensibility; a pure reference state machine beside a
privileged unmodeled service would leave the central assurance claim unfulfilled.

### 3. Share typed composition, not a universal domain datatype

The operational interface should have explicit input/output positions, native
types, preconditions, representations and outcomes. Within a linked generation,
accepted implementations execute over efficient family values. Cross-family
composition supplies an explicit admitted conversion or a checked plan
elaboration. Independent profiles are linked at registration/plan compilation;
ordinary requests do not rebuild a global theory or heap.

A semantic profile should be a named, versioned native development with its
operations and reusable codecs, not a second language that restates every HOL
definition. Do not require a complete bespoke compiler, serializer, display DSL
and optimizer for every profile. Shared collection, exact-number, observation
and artifact libraries should cover recurring cases; affine temperatures,
reference frames, SQL NULL and calendar semantics still need distinct laws.

The wire envelope may be extensible and carry bounded references. That does not
permit a dynamic JSON value to become the semantic authority. Conversely, native
values need not be reified into HOL terms or serialized for every element of an
array. The binding between bulk execution, its representation and licensed result
is the bridge to prove. Settle ownership and granularity of this bridge together
with execution, not separately in registry and compiler lanes.

### 4. Separate behavior coverage from assurance without weakening either

The ledger currently prevents an opaque Python wrapper from being called a lift.
Keep that rule, but specify what counts as the intended behavior of a capability.
The SQL specialist actually offers SQLite execution. A native implementation of
the same bounded setup/query/observation protocol, with a proved observer bridge,
may preserve that service while explicitly trusting a versioned SQLite boundary.
It does not verify SQLite's evaluator. A declared formal SQL fragment is a
different, stronger semantic service. Neither is an excuse to relabel arbitrary
untranslated Python as complete.

For each migrated capability record two independent decisions: the observable
behavior that is preserved or deliberately repaired, and the exact guarantee
connected to its real implementation. Record the external boundary separately.
For owned mathematical algorithms, observation-only relabeling does not meet
the required algorithmic lift. For intrinsically external data/tools, preserving
the real observation/effect protocol is part of the correct specification.

Decide these boundary classes before family work starts. Otherwise one lane will
attempt to verify all of SQLite while another will call every Python invocation
an observed computation. Both can cite the present prose. Similarly, the 3,608
tracked-path denominator is an inventory, not 3,608 independent verification
projects. Reachability and product workflows determine the concrete obligations;
unclassified entries remain open until that decision is evidenced.

### 5. Use one development lineage across authoring and deployed growth

Gap-derived examples, authored code, inferred formulas, search-discovered lemmas,
compiled plans and imported packages should be revisions of connected development
objects with explicit dependencies and artifact identities. Search and UI create
proposals through the same operations. Qualification produces attributable test
observations; native admission produces accepted logical/implementation objects;
activation publishes a version. Those are independent dimensions, not one linear
`draft -> verified -> deployed` status enum.

This preserves Oracle7's three synthesis mechanisms without implementing three
separate growth platforms: catalogue/toolchain execution, ordered pipeline search
with differential samples, and typed bounded enumeration can have distinct search
state and proposal logic while sharing test observations, candidate storage,
activation, learned-state isolation and provenance. No claim is made that their
search algorithms are interchangeable.

Film and explanation export should consume the same structured response/artifact
graph as the workbench, with conditions and historical status retained. They do
not need a second account of reasoning. Rendering metadata is not proof about
the resulting media bytes; the export contract must say what is actually checked.

### 6. Use a transactional local core with explicit external uncertainty

Choose a precise local commit unit: publication of a generation, authoritative
session deltas, and managed-store visibility are committed by the same authority
protocol, with distinct command variants. Distinguish the durable utterance from
an accepted answer binding. Independent request parts may complete separately,
but their dependency graph determines which results can feed later parts.

External execution has a different boundary. Record a durable attempt identity
and authorized intent, perform the action, then record confirmed or unknown
completion. A crash between external execution and acknowledgement is uncertain;
no local reducer proves exactly-once execution. Retrying requires the executor's
idempotency/reconciliation contract. Cancelling a request cannot erase an action
that already happened.

Restore session checkpoints and accepted transitions without reissuing commands.
Use retention-classed stores and explicit tombstones for retired material; do not
make an append-only event log contain every private payload forever. Every late
worker commit checks current authority as well as pinned semantic identity.
Source-event time and acquisition time remain separate observations. These are
shared lifecycle rules for sensors, tests, source onboarding and ordinary calls,
not four independently implemented state systems.

Two details cannot be left to independent store and executor implementations.
First, define the dispatch linearization point: revocation invalidates an
unconsumed permit, while an already dispatched action may require reconciliation.
An old native permit cannot authorize a later host launch after retirement merely
because the request was once pinned. Second, conservative dependency propagation
must cover actual managed reads and derived learning state; searching for matching
text later cannot implement forgetting. Restrict untrusted workers to declared
inputs or conservatively classify all their available inputs as dependencies.
Keeping a curated private derivative is an explicit retention decision, not proof
that it ceased to contain information from its source.

### 7. Narrow generic proof targets to composable statements, not weaker claims

PO-01–10 are good obligation headings but unbounded projects if interpreted as
single universal theorems. Before implementation, specify their quantification:
the finite linked signature, the actual interpretation rules, admitted operation
contracts, explicit host assumptions and enabled transformations. Domain instances
then discharge concrete bridges. A new primitive or optimization extends that
ledger and cannot inherit coverage from a theorem over an empty signature.

In particular, interpretation soundness is relative to declared language rules,
not a proof of intended human meaning. Blocker scope must refer to explicit
interpretations/premises/authority objects; arbitrary natural-language entailment
cannot decide it. Source adoption proves a conditional consequence, not the
truth of imported facts. Proving a finite test evaluator does not establish
general program correctness or test-set representativeness.

Initially exact identity plus explicit dependency pins can support safe reuse.
General semantic search subsumption and selective invalidation should be enabled
only with their own proofs. Whole-generation invalidation and no speculative
equivalence pruning preserve the destination while avoiding gratuitous proof
obligations. Performance evidence may justify narrower proven accelerations.

### 8. Choose a deployment shape now; keep optimization portfolios replaceable

Use one packaged resident native authority service with bundled heaps and local
client resources. External workers return proposals or executor observations;
they do not mint accepted values. Ordinary execution uses compiled native values;
proof construction happens where the requested claim or knowledge promotion
requires it. Native ML is the baseline backend. Additional lowerings consume
the same operation/representation contract when justified by measured workloads.

Bound search at the supervisor as well as the modeled scheduler. Logical fuel
does not bound an arbitrary simplifier, compiler or external tool. Define the
trusted process/resource enforcement and which operations may be preempted.
Cancellation latency, memory use and worker interference belong to deployment
acceptance, even when the logical theorem is already proved.

This does not require one universal optimizer or an ahead-of-time standalone
executable for all future HOL extensions. It does require efficient execution
and serious native search on the end-user machine, offline for the bundled core.
The two declared target platforms must share these product semantics rather than
silently offering different capabilities because a build dependency is missing.

## Ten design discriminator scenarios

These are paper-level adversarial questions for the architecture. They are not
a requirement to implement ten prototypes, nor evidence that tests have passed.
For each, name the concrete representations, authority boundary and expected
observations; “the framework is extensible” is not an answer.

| Scenario and shipped evidence | What distinguishes a viable design |
|---|---|
| **1. Literal identity through interpretation.** Hash text containing two spaces; parse multiline JSON; interpret case-sensitive genotype. `dataformats/organ_formats_v1.py:32–74`; `genetics-v2/organ_genetics_v1.py:117–161`, under `upstream/root/specialists/`. | Original payload and derived language spans coexist. A recognizer cannot change the bytes handed to the operation. Genotype case is not normalized away. The accepted claim identifies the input actually processed. G02/PO-01,02,04. |
| **2. Heterogeneous composition without scalar erasure.** Combine an affine temperature point/difference, logarithmic sound level and framed robot vector in one multipart turn. `units-v3-r2/organ_units_v1.py:49–54`; `acoustics/organ_acoustics_v1.py:76–102`; `robotics-v2/organ_robotics_v1.py:68–90`. | Compatible conversions are explicit; incompatible arithmetic is rejected locally. Exact/approximate representations and reference parameters survive composition. Bulk execution does not require a term per number. G02,03/PO-02,03,07. |
| **3. SQL is useful before full SQL verification.** Ask for an execution result with NULL/blob rows, an engine error, and more than twenty rows. `sql/organ_sql_v1.py:21–54,95–121`. | The chosen SQLite observation profile and any formal fragment are distinguishable. A prefix, timeout and reported syntax error cannot collapse to one success flag. The native observer bridge is real; Python wrapping is not completion. G01–03/PO-03,04. |
| **4. Witness versus optimum and partial policy compliance.** Return a feasible nonminimal graph path, then ask whether cooling satisfies the full rule after checking only its total time. `algorithms/organ_algorithms_v1.py:61–111`; `coldchain-v2/organ_coldchain_v1.py:46–62`. | Path existence, cost bound and optimality are separate claims. Checked and unresolved policy clauses remain visible. Success on one obligation cannot license the stronger conclusion. G01,03/PO-02–05. |
| **5. Tentative code that passes the user's tests.** An ordinary user receives a program from one of the three existing synthesis mechanisms, with a counterexample outside its samples. See runtime review R1/R5/R6. | The artifact remains useful and deliverable with exact test observations; it is neither suppressed nor universally admitted. Search library learning is isolated during evaluation, then explicitly promoted. G01,05,08/PO-03–05,08. |
| **6. Competing routes and a dependent follow-up.** A personal reader is addressed; another interpretation has a failed premise check; an outer guard withholds a candidate answer. Next comes “and its population?” Workbench `server.py:417–490`, `exam.py:56–64`; runtime review R2/R3. | Blockers have explicit scope. One route cannot evade its failed check, but a valid addressed reading is not globally blocked. Only the finally adopted structured referent seeds the follow-up; transcript storage is separate. G03,04,07/PO-01,04,08,10. |
| **7. Import an already examined specialist and adapt routing.** Import original manifest/card/panel/scorer plus exposed exam log; feedback changes its word routing while an old request runs. Workbench `exam.py:145–224`, `server.py:568–611`, `mcp.py:201–214,274–287`. | Original artifacts remain editable and exposure attributable. Native admission, operational qualification and activation can vary independently. A policy revision is atomic; no hidden shared mutable vocabulary survives the identity boundary. G05,08/PO-08,09. |
| **8. Sensor time and retirement race.** Repoll the same MQTT message, change units/configuration, receive an invalid newest sample, then retire during a pending poll. Workbench `sensors.py:235–236,304–339,399–428`. | Event and receipt clocks, sample identity, missingness and configuration belong to each observation. Window populations are explicit. Current authority prevents late resurrection; pinned history grants no renewed access. G06,07/PO-03,09,10. |
| **9. Qualification performs an effect and crashes.** A connector test increments a remote counter, loses its acknowledgement, then the application reconnects. Workbench `exam.py:281–289`, `mcp.py:252–271`, `server.py:448–459`. | Test paths require the same effect authority as user calls. Unknown external outcome survives restart. Session restoration does not rerun the request. Retry requires a concrete executor rule, not a generic rollback assertion. G06,07/PO-05,10. |
| **10. Gap-to-specialist-to-offline handoff with private explanation export.** A retained decline becomes draft examples, a repaired original package is qualified and deployed, and an explanation Film includes its historical answer. Then retire the private source. Workbench `server.py:509–557,826–841,986–1006`; `static/app.js:325–377`. | One lineage connects artifacts, examples, evidence and dependencies. Export selects permitted derived contents and preserves conditions. Local explanation and authoring work offline; optional media calls are explicit effects. Retirement reaches caches and derived artifacts under the chosen policy. G05–08/PO-04,08–10. |

## Decisions that must precede executable interface fan-out

1. **Authority and host boundary:** which code executes inside the privileged
   native worker, which packages may extend it, and which command/receipt path is
   the only route to publication and effects.
2. **Typed operation linkage:** inputs/outputs, representation witnesses, code
   identity and native theorem attachment; cross-profile conversions and bulk
   value lifetimes; generation/plan linking granularity.
3. **Claim and outcome algebra:** the relation among ordinary response acts,
   scoped claims, candidate artifacts, subgoal dependencies and accepted evidence.
   Include collection completeness and explicit unresolved obligations now.
4. **State commit and recovery:** local atomicity, partial-result adoption,
   external unknown outcomes, cancellation/revocation and restoration. Decide
   how durable host observations connect to generated transitions.
5. **Dependency and retention identity:** separate semantic generations, mutable
   session state, observation clocks and current access authority. Select a
   retention policy schema that can invalidate derived material without retaining
   its content forever merely to preserve replay.
6. **Coverage boundary classes:** which original services are algorithmic lifts,
   source/engine observations or external effects, and what actual bridge closes
   each class. A family may need several classes.
7. **Baseline deployment and search interface:** resident native authority and
   worker supervision; no startup theory build; finite strategy operations and
   resource ownership shared across user, background and qualification work.

These require concrete choices, not completion of every domain proof. Review
them jointly across semantics, runtime and authoring; the current “8 dispatchable”
task count is not evidence that eight independent interface designs are safe.

## Choices that can remain parametric

Exact family data structures and numerical algorithms; learned search policies;
which provable rewrite or subsumption rules are enabled; secondary compiler
backends; index implementations; UI component library; source replacement snapshot;
and bounded policy parameters can remain open behind the chosen interfaces.
Their concrete assumptions, tests and proof instances still precede activation.

Held-out evaluation can support multiple named exposure protocols if identity,
provenance and activation policy are already explicit. Film's media encoding and
optional service providers can remain open; the explanation object, content
permissions and export fidelity cannot. External chain publication remains an
explicit scope decision, not a dependency of the native registry. Sibling products
remain stress tests unless scope is deliberately expanded.

## Suggested parallel seams after those decisions

Keep the existing task IDs as requirements/acceptance accounting, but dispatch
implementation by stable shared boundaries: authority core/native gate; typed
execution/linker and family libraries; development store/publication/retention;
interpretation/routing; search policies; authoring views; supervised executors and
deployment. The first three require a joint design before independent ownership.
Family migrations then supply actual operation contracts to that shared core.

Do not create separate registries for proof search, synthesis, authoring and
deployment, or separate evidence objects for each UI. Do not centralize all domain
algorithms into the authority reducer either. The desired simplification is shared
control of meaning, identity and authority, with specialized execution underneath.

No code was built or executed for this review; no task status or future evidence
was changed. The recommendations require root synthesis and agreement before
they replace the baseline architecture.

Cross-lane read: [authoring review](authoring-review.md) agrees on one development
lineage, canonical native sources with approachable projections, independent
admission/qualification/activation and shared lifecycle operations. Its forgetting
contract needs the conservative dependency boundary described above. Runtime and
semantic drafts were still being prepared when this initial review was written;
the recommendations have been sent to their owners for integration.
