# Design decisions

Accepted direction follows the conversation and authorization to scaffold.
Baseline engineering choices can change with evidence; research reports do not
override this register or the user.

Revision 2 of the [architecture proposal](../docs/ARCHITECTURE_PROPOSAL.md) is the
concrete design under review. Rows marked `proposed` await the user's design
agreement; they do not authorize implementation fan-out. The existing native
direction and the explicit prototype cleanup remain authorized.

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
| D14 | proposed | One generated executable HOL authority machine is the actual runtime transition function. Typed request graphs and finite linked family interpreters compose operations; native meanings remain open. Native gate, executable linker and durable host seam receive joint review before downstream signatures freeze. |
| D15 | open | Backend portfolio: native ML available first; Sepref/LLVM compatibility and benefit need evidence. No fully verified downstream compiler is presumed. |
| D16 | open | External publication/Solana compatibility scope. Package import/export is required; chain integration is neither presumed complete nor silently discarded. |
| D17 | open | Missing corpus replacement snapshot/extraction policy; exact original is unknown. Document compatibility semantics and retain the limitation. |
| D18 | open | Full migration scope of six siblings. Present requirement is discovery/contract stress testing; expansion needs an explicit decision. |
| D19 | open | Project license and redistribution closure for runtime, solvers and corpora. Do not infer a license grant for new code from an upstream license or publish before this is settled. |
| D20 | baseline | Preimplementation audit G01–G03: claim scope/modality, assurance route and artifact lifecycle are separate. Ordinary-user tentative artifacts and scoped model/test/observation results remain useful; no empirical proof route or opaque-wrapper completion loophole. Native-registry owns extensible codec/profile registration, reviewed with operational and interpretation lanes. Original literals survive language normalization; composite/partial results retain their exact scope. |
| D21 | baseline | Audit G04/G07: routing blockers are scoped, not a universal terminal decline or indiscriminate fallback. Final outcome arbitration precedes authoritative answer-state adoption; transcript recording is separate. Session restoration does not re-execute old requests. Retirement/retention/access authority constrains cached handles and pinned generations. |
| D22 | baseline | Audit G05/G06: native semantic admission, empirical operational qualification and active publication are distinct. Feedback/configuration changes publish versioned policies. Connector discovery/test/requalification and background acquisition obey effect authority; source event time is distinct from receipt/poll time and origin/configuration belongs to each observation. |
| D23 | proposed | Repeatable regression and attributable exposure history; fresh holdouts only for freshness/generalization claims. Isolate in-memory and persistent learning. Retire blocks new invocation/acquisition; revoke/forget cancel dependent pending publication, and forget erases managed derivatives. Retained snapshot computations may finish absent revocation; no late acquisition reactivates a retired binding. Preserve local Film and code experimentation as artifact workflows. Network adapters remain D16. |
| D24 | proposed | Scala Headless/PIDE supervisor, resident Poly/ML authority, custom protocol commands, prebuilt application heaps and SQLite single-writer journal plus immutable blobs. Commit exact native-authorized batches with revision/epoch checks; acknowledge after durability. Current-authority check, dispatch-lease consumption and executor handoff are serialized with retirement; interrupted handoff may be unknown. Restore records/state, not historical requests. |
| D25 | proposed | Finite typed executable bundle; recipe/config/data and plans reuse compiled family kernels/interpreter. Theorem/native definition additions need no compilation if representable through existing operations. New carriers/kernels/code setup and optional fused plans stage a new bundle. No presumed dynamic SML ABI; packed values/session migration require admitted generation bridges. |
| D26 | proposed | Default autonomous extensions are supported declarative objects/strategies. Workers return inert certificates, compact reconstruction recipes or bounded native proof terms. Arbitrary ML/Isar execution, new axioms and unrestricted code setup are privileged native developments/plugins, not ordinary proof transport. A process is not a security sandbox. |
| D27 | proposed | Canonical .thy declarations with source-preserving form edits, expert blocks preserved. Package/release/deployment/workspace share one lineage. No duplicated editable JSON semantics or separate publication systems for authoring, search and synthesis. |
| D28 | proposed | Per-capability migration distinguishes owned algorithm/model, source/engine observation, external action and candidate workflow. Real behavior and actual assurance bridge are recorded separately; observation relabeling cannot complete an owned algorithm lift. All three shipped synthesis mechanisms share lifecycle but retain their proposal behavior. |
| D29 | proposed | Kernel consequence is default for reusable logical knowledge; refined execution is default for ordinary certified computation; oracle consequence requires explicit profile. Runtime guards are discharged before invocation, independently of retained source/model premises. PO-01–10 formal targets and TB-01–05 trusted-boundary contracts have distinct closure statuses. |

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

`design-convergence` holds the work graph while this recommendation is discussed.
Core owners implement the proposed boundaries through the existing C01–C05
semantic contracts; schema revision 0 remains a descriptor, not a frozen runtime
protocol. Narrow linkage/proof-transport and host/recovery probes are assigned
early, before dependent interfaces freeze. Product/family tasks retain full scope.
No new proof or deployment claim follows from the design review.
