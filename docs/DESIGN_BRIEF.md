# veri7vn: design brief

Status: foundation complete, 2026-10-15. The Isabelle-native direction and
authoring-focused product requirements are accepted. Architecture revision 2 is
agreed and scoped implementation is authorized. Descriptor
schemas are not frozen executable interfaces; the complete platform remains work.

Current synthesis: [ARCHITECTURE_PROPOSAL.md](ARCHITECTURE_PROPOSAL.md).
Current work and decisions: [project plan](../project/PLAN.md) and
[decision register](../project/DECISIONS.md).

## What ember has asked for

- Download and audit Oracle7, recover its actual algorithmic structure, improve
  correctness and performance, and create something its author can keep growing.
- Absorb the Python's capabilities into a symbolic system; do not mistake a small
  verified arithmetic fragment for a replacement of the whole system.
- Use Isabelle, including the possibility of shipping the application within
  Isabelle itself. Serious proof search on the end-user machine is in scope.
- Make witness production and checking central. A flexible search algorithm need
  not itself be verified if its results have adequate checked justification.
- Develop a substantial metatheory connected to concrete executable tools.
- Engineer performance and deployability from the beginning, including data
  structures, compilation, startup, search, memory, and evidence costs.
- Make the result a useful gift to Oracle7's author: continuity, approachable
  extension, understandable diagnostics, and an ordinary deployment path.
- Make authoring and growth usable without the original implementers beside the
  author. Growth includes new abstractions, proved operations, implementations,
  and search methods, not only replay of a fixed library.
- The root agent owns design, synthesis, and dispatch. Agree consequential design
  decisions before implementation. Subagents are now authorized to trailblaze;
  isolated experiments should resolve design uncertainties, not silently settle
  the architecture.
- Use Scry extensively for research, authenticating through `~/.scry-key` without
  exposing that credential in transcripts, source files, command arguments, or logs.

## Important corrections to earlier exploration

The early `o7ir/`, root `isabelle/`, `generated/`, and compilation-test prototype
was removed at the user's request on 2026-10-15. The
[cleanup record](design/prototype-cleanup.md) gives its recoverable Git history.
The native scaffold, isolated native probes, and upstream audit tooling remain.
The old checked DAG theorem established expression/DAG evaluation correspondence
for parametric pure operations. It did not establish correctness of the Python
lift, natural-language interpretation, database operations, routing, state,
C emission, or whole-system behavior.

An extracted standalone executable is an available deployment direction, not a
requirement that forbids a native Isabelle deployment. Likewise, a compiler for
arbitrary Python is not the present objective: systematic recovery of capabilities
with explicit preservation or repair obligations is the proposed route.

The earlier claim that ordinary deployment should require no running Isabelle was
superseded by the native deployment discussion. Language interpretation must also
have a declared formal relation; leaving all NLP permanently outside the assurance
story would lose an earlier commitment. The user declined turning two example
workloads into a prerequisite design exercise; use the existing behavior to test
the architecture's coverage without treating that exercise as an agreed workflow.

The root should recover surrounding exchanges with `cv` after compaction rather
than treating summaries as complete specifications. `cv prompts` was removed;
use `cv show <id> --kind prompt,answer`, then `--around` or `--range`. Current chat:
`codex:01a13efb-aa97-7902-9c91-3c5409ae3da5`.

## Research responsibilities

- `native_metatheory`: open native definitions versus reified operational syntax;
  capability admission; plan/search/effect semantics; theorem dependencies;
  source assertions, context changes, and cache validity.
- `native_execution`: resident Isabelle runtime, staging, efficient execution,
  proof search, data access, deployment, and concrete assurance/performance costs.
- `fact_provenance`: Scry access and substantial literature research, building on
  its completed investigation of Oracle7's source data.
- Root: reconcile these into a coherent proposal and tool suite, keeping user
  requirements and unresolved decisions visible.

## Questions the proposal must answer

1. What is a capability, and which parts of its meaning are native HOL definitions
   versus syntax with a formally defined interpreter?
2. What exactly does an accepted answer establish, including interpretation,
   source premises, approximation, and context dependencies?
3. How does an extension become executable without acquiring unchecked logical
   authority? Which extension properties need proofs, tests, or measurements?
4. How are strategy search and operational state represented, executed, bounded,
   improved, and related to their specification?
5. Which computations run as compiled ML, which produce reconstructed proofs,
   and where does a computational trust boundary remain?
6. How are corpus queries, absence/uniqueness claims, snapshots, changes, and
   contextual assumptions handled without treating all imported claims as axioms?
7. How do repeated successful searches become reusable proofs and efficient
   programs, with sound generalization and cache invalidation?
8. What precisely ships to an end user, and what work is required at startup,
   capability admission, and each query?
9. How does this cover the actual Oracle7 reader, calculator, synthesis, dialogue,
   routing, memory, and self-extension machinery, including currently unavailable
   dependencies?

The user subsequently authorized project management and early scaffolding for
parallel agents. The project plan now governs that work. Writing this brief does
not authorize external publication or silently promote research probes into
the production framework. Consequential interface changes must be reconciled with
their consumers before broader dependent implementation.
