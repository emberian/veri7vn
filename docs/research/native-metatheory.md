# Native meanings and operational authority

veri7vn combines an open Isabelle library with small explicit operational calculi. Native HOL definitions, types, specifications, and theorems carry logical meaning; typed plans, source interpretations, strategies, effects, and dependency graphs expose the structures the application manipulates. The core controls acceptance and state transitions while search remains free to propose candidates.

This research establishes the architecture's proof obligations, not a completed whole-system theorem. Under the fictional **Dijkstra–Axios standard**, every guarantee names its native statement, executable connection, assumptions, consumer, and remaining gap. The standard is a project review discipline, not external certification.

## Representation and capabilities

A heterogeneous registry can retain certified terms/types/theorems without pretending all future HOL values inhabit one universal datatype. Concrete generated fragments have explicit carriers and interpreters. Their elaboration/representation theorem connects them to native definitions:

```text
specification ← contract → native executable definition
                         ↕ interpretation/refinement
                 reified program → runtime representation
```

`Native_Call name` is only a call site. A usable entry identifies primitive semantics, implementation relation, conditions, effects, assumptions, and evidence route. Finite-example agreement remains empirical; it cannot justify arbitrary replacement. Oracle7's `CodeOrgan` example-based term merging is useful synthesis, not universal equivalence ([implementation](/Users/ember/dev/o7vn/upstream/root/wander-train/code_organ_v3.py:318)).

A capability development contains:

| Part | Required connection |
| --- | --- |
| Signature/specification | Types, applicability, output relation, assumptions |
| Executable/search procedure | Actual implementation and partiality/error behavior |
| Contract/refinement | Native theorem relating implementation, representations, state, and effects |
| Evidence | Witness format, checker meaning/soundness, and actual acceptance mechanism |
| Dependencies | Theory/context, source/domain observations, representation/rule/code versions |
| Interpretation | Original spans, proposed reading, unresolved ambiguity |
| Operational policy | Effects, budgets, replay, caching, execution restrictions |
| Empirical record | Tests, counterexamples, measured costs and compatibility, kept distinct from premises |

Use local theories, locales, definitions, and interpretations for parameterized developments. Context data and morphisms transport terms/theorems; global raw mutable tables bypass context discipline. Immutable request contexts pin generations; publishing a successor must not mutate running proof states. `Item_Net` and compact context data support indexing; one `Proof_Data` slot per specialist imposes initialization costs on every proof context.

Actual ancestry matters: `Context.subthy` and `Thm.transfer` support valid descendants; printed propositions or constant names do not establish compatibility across independent/rebuilt sessions. Installed references: [local theories](/Applications/Isabelle2026-RC1.app/src/Doc/Implementation/Local_Theory.thy:10), [contexts](/Applications/Isabelle2026-RC1.app/src/Doc/Implementation/Prelim.thy:10), [initialization](/Applications/Isabelle2026-RC1.app/src/Doc/Implementation/Prelim.thy:295), [named-theorem indexing](/Applications/Isabelle2026-RC1.app/src/Pure/Tools/named_theorems.ML:25).

## Judgments and proof structure

Let Θ denote native theory, Γ explicit assumptions, W a source snapshot, Σ the capability signature, Δ dependencies, and ε effects. The core judgments distinguish:

```text
Θ;Γ;W ⊢ text ⇝ interpretation
Σ;Γ ⊢ plan : input → output ! ε
Σ;W ⊢ (plan,input,state) ⇓ (outcome,state',trace)
Θ;Γ;W ⊢ evidence : claim ▷ Δ
license(interpretation,claim,answer_form,answer)
valid_dependencies(Δ,Θ,Γ,W,runtime_generation)
```

Interpretation proves a relationship under a grammar/linker/policy, not the user's private intent. Outcomes preserve ambiguity, decline/inapplicability, unresolved search, budget exhaustion, execution failure, and accepted answers. Contradictory candidates remain explicit.

Checker soundness justifies the exact claim under exact premises. Licensing separately connects that claim to structured output: a source report cannot silently become a world fact, an interval exact equality, or one reading every remaining reading. Rendering consumes licensed structure; unrestricted prose equivalence is another obligation.

Refinement preserves observable outcomes/effects, including partiality and nondeterminism. Numerical approximation requires an error relation; algebra over reals does not license floating reassociation. Extension correctness covers dispatch/representation/effects compatibility as well as logical admission.

| Theorem family | Actual consumer obligation |
| --- | --- |
| Typing/well-formedness preservation | Executed elaborator and conversions realize the checked syntax |
| Primitive/composition correctness | Every dispatched operation realizes registered semantics |
| Witness soundness/licensing | Real checker/emitter is reached through modeled acceptance |
| Search-policy independence | Proposal/ranking cannot bypass acceptance or mutate committed contexts |
| Quotient/deduplication correctness | Runtime keys preserve permitted answers and conflicts |
| Extension preservation | Published generation matches checked manifest and code |
| Dependency adequacy | All semantic reads/generations govern reuse and invalidation |
| Lowering correctness | Actual optimized artifact matches the refinement relation/backend assumptions |
| Budget safety | Worker/process/FFI behavior matches accounting; logical fuel is not a wall-clock theorem |

Sound accepted results do not require a verified heuristic searcher. Whole-system operational guarantees additionally depend on concrete parser, scheduler, storage, effect, and execution bridges. Each bridge needs an implementation relation, extraction, or checked validation—not a similar-looking ML function beside a theorem.

## Sources, coverage, and reuse

Distinguish source containment, policy-governed premise adoption, and logical consequence. Imported reports remain data or scoped assumptions, never unconditional global axioms. Preserve time/revision, qualifiers, rank, units, and observation context before reasoning.

Conflicting reports can remain quoted data, separately scoped classical hypotheses, or an explicitly specified non-explosive logic. Arbitrary HOL consistency checking is unavailable. Positive provenance establishes a witness; absence, uniqueness, maxima, ranking, and complete counts require domain coverage. Missing databases cannot supply negative evidence.

Large corpora need compact indexed data rather than a theorem object per row. Verified abstract queries and refinements can support compact per-result evidence. Merkle roots authenticate fragments under serialization/cryptographic assumptions; they prove neither source truth nor query completeness. Nonmonotone dependencies include excluded rows and comparison domains, not merely returned witnesses. See [background research](scry-background.md).

Caches bind meaning-changing context/source/code/rule/interpretation dependencies. Update correctness either keeps a result at its original snapshot or proves valid maintenance. Deletion may leave another derivation; a newly better candidate can invalidate ranking without changing old support. Search traces, accepted theorems, compiled programs, and learned rankings are separate reusable assets.

## Admission and execution boundaries

A theorem with zero subgoals and no oracles can still retain hypotheses or depend on arbitrary theory axioms. Admission checks full proposition, hypotheses, premises, sorts, approved ancestry/construction, transitive oracle dependencies, and exact executable attachment where promised. Approved definitions introduce definitional axioms; rejecting every new axiom-table entry is also incorrect.

The local probe constructs `2+2=5` by assumption: valid conditional sequent, zero subgoals/oracles. `Assumption.export` exposes its premise. Treating it as unconditional would be an application bug. Trusted ML can build theories and is not a security sandbox. Ordinary extension uses controlled definitions/replay; reviewed native plugins are a separate privilege. References: [Goal.prove](/Applications/Isabelle2026-RC1.app/src/Pure/goal.ML:192), [theorem API](/Applications/Isabelle2026-RC1.app/src/Pure/thm.ML:64), [oracle inspection](/Applications/Isabelle2026-RC1.app/src/Pure/thm_deps.ML:23).

Execution has three distinct guarantees: untrusted computation followed by ordinary kernel reconstruction; generated proved checkers under code/runtime trust; and refined compiled execution under specified backend assumptions. Evaluation-oracle theorems add that evaluator to logical trust. Static computation can instead provide hints for oracle-free certificates ([evaluation](/Applications/Isabelle2026-RC1.app/src/Doc/Codegen/Evaluation.thy:26), [certificates](/Applications/Isabelle2026-RC1.app/src/Doc/Codegen/Computations.thy:259)).

Fresh names/versioned generations avoid silently changing old meaning. Conservativity claims require their stated foundation and independent-fragment assumptions: [definitions](https://doi.org/10.1145/3158112), [independent fragments](https://arxiv.org/abs/2101.03807). Full host-logic reflection is not free; the [HOL4 reflection construction](https://intelligence.org/files/ProofProducingReflection.pdf) explicitly adds assumptions. [Faithful embeddings](https://arxiv.org/abs/2502.19311) motivate connected shallow/deep views; [self-formalization](https://doi.org/10.1007/s10817-015-9357-x) illustrates inference-to-operational-implementation composition. Neither supplies veri7vn's missing bridges automatically.

## Evidence and open work

[Native_Admission.thy](/Users/ember/dev/o7vn/experiments/native-metatheory/Native_Admission.thy), [ROOT](/Users/ember/dev/o7vn/experiments/native-metatheory/ROOT), and its build log test locale definitions, assumption export, and ordinary theorem construction without `sorry`, added axioms, or oracles. Session time5s/first invocation16s is feasibility evidence, not startup performance or a complete gate. [Research inputs](/Users/ember/dev/o7vn/experiments/native-metatheory/research) retain discovery and primary texts; installed RC1 source governs API compatibility.

Current completion work connects authoring, source import, interpretation, native search, admission, optimization, dependency-aware retention, and packaged deployment through their actual consumers. Important open obligations are source completeness, full context/code identity, extension compatibility, effect/worker refinement, and useful end-to-end workloads. The coverage ledger must distinguish recovered behavior, deliberate repair, and unsupported scope. No arithmetic fragment or generic adapter substitutes for that environment.
