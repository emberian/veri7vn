# Symbolic methods worth building next

Sol research lane, 27 October 2026. **No shipped specialist panels were run; this lane has no new panel numbers. No formal theorem was added.** Eight primary papers were saved and selected body sections read. The isolated Python fixture passes. This report proposes production work; it does not claim that work is implemented.

My recommendation is to build one small, typed symbolic language with four cooperating capabilities: guarded equality saturation, counterexample-guided synthesis, relational constraint planning, and abstract interpretation. Start with the planner's recoverable misses and exact integer synthesis; let the same language become the search front end for the existing verified-CAS design. Four unrelated engines would multiply translation mistakes. The key architectural lesson from [Rosette](https://homes.cs.washington.edu/~bodik/ucb/Files/2013/onward13.pdf), sections 1–2, is that one executable semantics can support verification, synthesis, failure localization and repair queries. Adopting that pattern does not require adopting Racket or replacing Isabelle.

## What already exists

Read before recommending these additions:

- `docs/design/verified-cas.md` already specifies untrusted algebra search followed by extracted HOL checking, exact arithmetic, explicit domains and refusals. Equality saturation belongs in its finder/normalizer story; it is not a substitute for that design.
- `src/extract/mathorgan/Math_Affine.thy` normalizes affine trees and checks unique/all/no rational solutions. Its `affine_unique_checked` conclusion is `affine_satisfies vname l r t ↔ t=x`, under an actual checker premise. This is stronger than checking a supplied root at one point, but does not cover nonlinear formulas.
- `src/extract/codeorgan/CodeOrgan.thy` proves replay of the supplied examples. `check_every_example` says that checker acceptance and membership of `(args,want)` in the supplied cases imply `run p args = Some want`. It does not quantify over unseen inputs. `tools/code_evidence.py` says this explicitly too.
- AP1's `workbench/swarm/composer_v3.py` already has typed bottom-up search, observational equivalence, fitted constants, emitted-code replay and library learning. Its bank key is `(dimension, rounded example-output vector)`, and the bank is bounded at 250,000 expressions. This is useful empirical pruning, not a semantic equality relation.
- AP1's `point.py` already binds admitted source snapshots, preserves named quantities and caller aliases, and computes only the selected dependency chain. `_chain` nevertheless keeps the first producer for each output and has a four-layer bound. Guard-aware alternative selection is a real extension.
- `src/extract/fusion/Fusion.thy` already models typed specialist composition with bounded breadth-first search and shallowest-depth agreement. `Relation_Query.thy` already checks constrained entity/property-class selection and carries explicit completeness premises. New work should extend those consumers rather than add another unconnected answer route.
- The existing `chameleon.plan`/`validate_plan` operations already search explicit finite transition models and independently replay witnesses. Their Microfold representation has up to 63 Boolean facts, operator preconditions/effects and bounded search. Numeric constraints and symbolic procedure summaries would add something; another Boolean planner would repeat existing work.

These observations concern the local qualified AP1/U3 source family, not an audit of upstream 10.0. Current project tracking requires comparing that release before extending a contribution patch stack.

## 1. Guarded equality saturation: retain many algebraic views at once

**New ability:** simplify, rearrange, differentiate and compose formulas across specialists without choosing a destructive rewrite order in advance. An e-graph compactly retains equivalent expressions; extraction selects a useful expression under a cost such as size, runtime or numerical conditioning. [egg](https://arxiv.org/abs/2004.03082), sections 2–4, supplies rebuilding and e-class analyses. Its reported speedups are for its own benchmarks; none are measured here.

For veri7vn, the important addition is **conditional** equivalence. A rule such as `(x²-y²)/(x-y) = x+y` requires `x≠y`; `sqrt(x²)=x` requires `x≥0` over the reals; logarithm identities need their real positivity conditions; complex logarithms have branch conditions. Algebraic equality is also different from identical floating-point evaluation. A dimension check is necessary but cannot establish that width and height, temperature points and temperature differences, or two differently sourced periods denote the same quantity.

The strongest paper match is [egglog](https://arxiv.org/abs/2304.04332), section 6.2: Herbie's useful rewrites become guarded by cooperating interval and not-equal analyses. The case study also reports mixed accuracy outcomes, including cases where the old unsound rules find better numerical results. It does not establish universal precision improvement or supply an Isabelle checker.

**Consumer and first query:** the CAS finder receives “simplify `(x²-y²)/(x-y)` for `x∈[3,4] m`, `y∈[1,2] m`.” It proposes `x+y` and a rule-instance trace. The checker verifies every instance and guard, preserving the original expression's domain. With overlapping ranges, either retain the condition `x≠y`, split cases explicitly, or withhold that cancellation. An equality derived under one task's assumptions must never be inserted into a global e-class used by other tasks. Namespace graphs by the assumption context, or represent conditional equalities explicitly.

The fixture accepts separated ranges, rejects an unproved singularity guard and incompatible dimensions, rejects a tampered conclusion, and exhibits `x=y=2`: original undefined, unguarded simplification equal to 4. This is Python rule replay, not an e-graph implementation or proof.

## 2. Specification-driven CEGIS: make counterexamples guide program construction

**New ability:** synthesize conditionals, integer algorithms and small compositions against a stated relation over inputs, rather than merely fitting a fixed batch of examples. [Sketch](https://doi.org/10.1145/1168857.1168907), sections 5.2–5.4, alternates synthesis and verification for finite programs. [Syntax-Guided Synthesis](https://www.cis.upenn.edu/~alur/SyGuS13.pdf), sections II–III, separates the background theory, grammar and correctness specification. Neither grants completeness for arbitrary programs or arbitrary unbounded theories.

The existing composer is a natural candidate generator. Given `pre(inputs)` and `post(inputs,output)`, ask an SMT solver for an input satisfying `pre ∧ ¬post(candidate)`. Replay every counterexample through the independent semantics, add it to the example set and search again. `unknown` or timeout means unresolved. A solver's unsupported `unsat` claim is not enough for the project's formal assurance tier: reconstruct the theorem, or check a proof/certificate in a supported fragment. Start with quantifier-free linear integer/rational constraints, finite bit-vectors with explicitly declared overflow semantics, and bounded lists; nonlinear transcendental reasoning is not a cheap first step.

**Important integration detail:** when a new counterexample arrives, regenerate or split the composer's observation-equivalence classes. Expressions identical on the old example vector can disagree on the new input. Keeping only the old representative permanently can remove the correct solution. Only proved equalities may merge classes across all inputs. Rounded vectors must never become proof premises.

**Consumer and first query:** `builder.compose` gains a structured-specification path for “how many packets carry `n` payload bytes when each holds at most `d` bytes?” On mathematical integers with `n≥0`, `d>0`, require `q≥0`, `qd≥n`, and `q=0 ∨ (q-1)d<n`. The fixture starts with `(n,d)=(4,2)`, rejects `n//d` using `(1,2)`, rejects `(n+1)//d` using `(0,1)`, then checks `(n+d-1)//d` on every `n=0..64,d=1..16`: **1,040 inputs**. Its verifier is exhaustive enumeration, not SMT. No unbounded theorem follows from those checks. A later HOL result should state that the accepted expression satisfies the displayed postcondition for every mathematical integer input under the displayed precondition.

## 3. Relational constraints and Horn clauses: join alternatives and summarize loops

**New ability:** ask multi-input, multi-step questions with arithmetic guards and retain alternative derivations rather than committing to the first producer. A positive rule can join a part's exact named inputs, its domain conditions and a supplied source snapshot; its conclusion records the output and a derivation. egglog sections 3–4 supply the equality/relational combination and semi-naïve incremental evaluation. Its fixpoint may be infinite: a bounded run is an under-approximation of discoverable consequences, not proof that no answer exists.

The immediate consumer is `swarm point`, followed by Fusion and structured sourced queries. Keep every valid producer, compare answers under the existing agreement policy, and report why unavailable branches failed. When time, resource use or recursion enters the model, constrained Horn clauses can represent relations such as “after any number of batches, delivered bytes plus remaining bytes equals the starting quantity.” [Spacer/RecMC](https://seahorn.github.io/papers/spacer2014.pdf), sections 2, 4 and 6, shows modular under- and over-approximate procedure summaries. It is a path toward reusable arithmetic invariants, not a promise that arbitrary workflow verification terminates.

**Consumer and first query:** fill a 60 L cistern using either pump A at 0 L/s or pump B at 2 L/s. The fixture extracts only the actual AP1 `_chain` definition and shows it selects pump A. That route would fail during division; this is a recoverable refusal, not a demonstrated wrong answer. A one-step guarded relational fixture retains pump B and returns **30 s**, with pump A's `rate>0` failure recorded. This does not exercise full admission, program execution, the Engine, or a general Horn solver.

Sourced joins need separate premises for positive rows, absence and coverage. A missing database row does not prove a negative fact; uniqueness/counts/“all” need completeness for the queried scope. Deletions, revoked admissions and changed source snapshots require invalidation or recomputation. Positive semi-naïve insertion alone does not handle retraction. Existing `BoundPart` snapshots remain the authority for executable admissions. This is where the nonmonotonic lane should share a contract, rather than where a positive Datalog closure should silently acquire closed-world semantics.

## 4. Shared abstract interpretation: know enough about every candidate to search safely

**New ability:** cheaply infer ranges, signs, definedness and simple relationships for whole families of symbolic programs. Use a product of exact rational intervals, zero/nonzero/sign facts, integral/count properties, dimensions, named roles, and temperature point/difference kinds. “Reduced” means facts cooperate: a strictly positive interval implies nonzero; a count excludes negative values. Relational facts such as `x-y≥1` need a difference-bound or similar relational domain, since independent intervals lose correlations.

[Cousot and Cousot](https://www.di.ens.fr/~cousot/COUSOTpapers/POPL77.shtml), sections 6 and 9, explain the local soundness and convergence obligations. These facts are over-approximations: an interval containing zero does not prove a division fails, and an inconclusive analysis must withhold the rewrite rather than reject the underlying true identity. Empty/contradictory assumptions must not create arbitrary positive answers. Analyses of loops need a sound widening or another convergence argument; precision loss is visible.

**Consumers:** the same analysis enables guarded rewrites, filters impossible synthesis candidates, and checks a plan's denominator, logarithm and root guards before execution. For ideal transfer duration, `bytes≥0` and `rate>0` establish the basic arithmetic domain; setup time, protocol overhead or stochastic throughput require separate model inputs. Analysis cannot invent those physical assumptions.

[Demanded Abstract Interpretation](https://arxiv.org/abs/2104.01270), sections 2, 5–7, offers an additional performance idea: compute only the requested analysis and invalidate affected dependencies after edits while preserving equality with a fresh batch analysis. Adopt that machinery only after measuring repeated analysis of a shared library; the current four-layer planner does not justify a large incremental-analysis framework by itself. Initial implementation can recompute tiny graphs. The existing fixture's rational-enclosure guard is a deliberately small instance of this direction, not an implementation of the paper's demanded graphs.

## Assurance contract to share across all four

Search remains untrusted. The common typed AST needs an exact partial evaluator, a domain predicate, a printer showing what was interpreted, and a checked trace format naming each rule, substitution, assumption context and source identity. Preserve the existing split between English recognition and the theorem about the resulting expression.

The intended future checking statement is substantive: if `check Γ e e' trace` accepts, then for every valuation satisfying `Γ`, both expressions have the same definedness, and whenever defined they have the same value and declared quantity kind. If simplification deliberately extends the domain, retain the original domain in the answer instead of claiming the stronger statement. This lane has not formalized or checked that theorem. Solver-generated invariants likewise need checked initiation, preservation and postcondition obligations, relative to the actual transition semantics.

SAT models, traces and finite counterexamples are useful evidence that can be replayed independently. UNSAT certificates require a supported proof path; paper soundness is not implementation soundness. Inductive summaries of a caller-supplied physical model establish facts about that model, not about a real pump. Statistical confidence belongs in a separately labeled tier. I would not prioritize a probabilistic-logic engine in this lane before the exact specification and domain contracts exist.

## Proposed implementation order and measurements

1. Add guarded alternatives to the existing named-quantity planner. Include the pump case, conflicting alternative values, shared intermediates, cycles, removed admissions and unit/role mismatches. Measure completed supplied-data tasks and refusals, then the affected specialists' own panels through their actual consumer.
2. Add the structured-specification CEGIS mode to the existing builder and independent DSL interpreter. Preserve empirical-example mode. Measure success on a fixed held-out set of small integer/list specifications, solver timeouts, counterexamples and proof-checked versus merely finite-checked outputs. Do not score a generated training example as generalization.
3. Add the shared abstract facts and a bounded e-graph finder to CAS phase 0. Reuse its exact expression/domain language and checking boundary. Measure the CAS design's held-out elementary integration/simplification panels and shipped calculus control; include singularities, negative square-root cases and log branches as independent adversarial cases.
4. Introduce numeric CHC summaries or demanded recomputation when actual multi-step queries or profiling show that the simpler graph search is insufficient. Keep Microfold's existing finite Boolean search and witness replay usable.

This order delivers useful planning and construction behavior before committing to a large theorem-proving framework. The compounding capability is shared semantics: each new checked primitive, domain fact or admitted formula becomes available to search, simplification and planning together.

## Saved sources and exact experiment

The local library is `/Users/ember/paperbin/oracle7-20261027/symbolic/`. `manifest.json` records primary URLs, years, DOI where verified, PDF/text SHA-256 hashes, reused files, retrieval routes and selected body sections actually read. There are **eight core papers, seven available PDFs** (two reused via symlinks) and all eight body texts; Sketch is saved as full-body text only. The 1977 PDF is scanned, so its Scry extraction was used, with damaged mathematical notation explicitly flagged. An additional 2009 equality-saturation body was retrieved but is not relied on in these recommendations.

Both requested services were used: **[Scry](https://scry.io/)** for full bodies and **[Kagi](https://kagi.com/)** for primary-source discovery. Raw receipts and bounded SQL are retained locally. Scry rejected the initially guessed `arxiv.papers` relation; schema discovery corrected it to `academic.papers`. Two keyed, bounded queries returned two and three complete body rows, with no truncation, zero reported spend and `free_slack` billing. Missing queried keys were not treated as absence of papers. Credentials stayed in-process and were not printed.

Exact check:

```
.venv/bin/python -B tools/usage/symbolic-literature/prototype.py
```

Result: **exit 0**. Guard cases, tampered-certificate rejection, four exact-rational point checks, the singularity counterexample, three CEGIS rounds with exhaustive final checking of 1,040 inputs, and the actual `_chain` selection comparison all passed. Full JSON is `~/paperbin/oracle7-20261027/symbolic/prototype-result.json`. The fixture is explicitly untrusted and adds no formal theorem or specialist panel gain. No Engine, Isabelle build, heavy install, production runtime/kernel/Mini edit, commit or push was performed by this lane. Root owns integration.

Changed repository files: this report; `tools/usage/symbolic-literature/prototype.py`; `tools/usage/symbolic-literature/research.py`. Remaining work is the production implementation and the stated consumer/panel measurements, not another literature pass.
