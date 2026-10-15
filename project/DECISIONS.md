# Design decisions

Accepted direction follows the conversation and authorization to scaffold.
Baseline engineering choices can change with evidence; research reports do not
override this register or the user.

| ID | Status | Decision / consequence |
|---|---|---|
| D01 | accepted | Primary product is an Isabelle-native engineering environment with serious deployed search/growth. A client may be external; semantic authority is native. |
| D02 | accepted | Open HOL meanings plus specialized operational calculi and real proof/refinement bridges. No universal closed HOL value type or wrapper counted as a lift. |
| D03 | accepted | Performance from the start: staged compilation, efficient runtime values, whole-path measurement. Extraction-only products are optional projections. |
| D04 | accepted | Coherent specialist development connects authoring source, meanings, implementation, evidence, examples, sources and deployment. Generated artifacts derive from canonical source. |
| D05 | accepted | Interpretation, conditions, disagreement, failures, state and effects stay explicit. Versioned source reports are not global world-truth axioms. |
| D06 | accepted | Kernel theorem admission, refined/generated execution and evaluation-oracle execution have distinct assurance routes, with no silent downgrade. |
| D07 | accepted | Root synthesizes/dispatches/integrates; scoped agents implement. Preserve existing prototypes as experiments and require evidence for reuse. |
| D08 | baseline | Descriptor schemas validate structure only. Portable receipts/identities locate artifacts, not native proof authority. Support/theory/data packages need not invent callable exports. |
| D09 | baseline | Requests pin theory/runtime/capability/data/interpretation generations and separately identify session/prestate and observation/evaluation time with its clock basis. Whole-generation dependencies are not sufficient for freshness or session state. Selective invalidation requires adequacy and implementation evidence. |
| D10 | baseline | Quoted sources and explicit scoped adoption first. Automatic inconsistent-premise reasoning needs a designed consequence policy; general HOL consistency checking is not assumed. |
| D11 | baseline | Current development: macOS ARM64/Isabelle2026-RC1. Handoff target also includes Linux x86_64 to cover upstream environment. Each supported target needs its own evidence; paths remain configurable. |
| D12 | baseline | Local browser workbench with native backing and expert theory access is the primary authoring surface. Audit upstream workbench reuse before choosing a UI stack. |
| D13 | baseline | Source/replayable developments are durable; heaps/compiled code are runtime-specific derivatives with checked dependency closure. |
| D14 | open | Common plan/strategy signature, effect model and authoritative transition implementation: core tasks settle these against shared contracts. |
| D15 | open | Backend portfolio: native ML available first; Sepref/LLVM compatibility and benefit need evidence. No fully verified downstream compiler is presumed. |
| D16 | open | External publication/Solana compatibility scope. Package import/export is required; chain integration is neither presumed complete nor silently discarded. |
| D17 | open | Missing corpus replacement snapshot/extraction policy; exact original is unknown. Document compatibility semantics and retain the limitation. |
| D18 | open | Full migration scope of six siblings. Present requirement is discovery/contract stress testing; expansion needs an explicit decision. |
| D19 | open | Project license and redistribution closure for runtime, solvers and corpora. Do not infer a license grant for new code from an upstream license or publish before this is settled. |

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
