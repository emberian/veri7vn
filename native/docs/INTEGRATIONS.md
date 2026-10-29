# Native reasoning integrations: capabilities, experiments and next consumers

29 October 2026. This develops the [roadmap](ROADMAP.md) into executable
providers and a domain expansion program. The aim is to improve what Oracle can
answer and what it costs to serve. Formal assurance is valuable where available;
it is not a prerequisite for every useful capability. Replies must describe
the evidence they actually have.

## The first executable cut

| Provider | Callable now | Boundary |
| --- | --- | --- |
| `oracle-reasoning`, petgraph | `graph.minimum_spanning_forest`: exact signed weights, parallel edges, isolated vertices, deterministic edge IDs and component counts. | An independent Rust checker verifies forest coverage and cycle optimality. Not yet connected to the extracted HOL checker. |
| `oracle-reasoning`, egg | `algebra.optimize_polynomial`: factor/reassociate exact integer polynomials and check the result by separate exact normalization. | No division, floating-point equivalence or global optimum claim. The search cost is a declared expression-tree model. |
| Same, dimensional admission | `algebra.optimize_dimensional_polynomial`: check supplied SI dimensions before and after rewriting. | Normalized linear quantities only; no affine unit conversion or inference of physical laws. Invalid original arithmetic cannot be hidden by cancellation. |
| `oracle-science`, faer | `science.solve_linear`, `science.least_squares`: coupled supplied equations and fitted parameters with rank, residual and conditioning diagnostics. | Floating-point computation over a caller's model. Rank policy, row weighting and nonunique solutions are explicit. |
| `oracle-incremental`, differential dataflow | Finite versioned dependency batches: reachability, upstream/downstream impact, insertions and retractions, settled output changes. | Declared finite graph; closure is potentially quadratic. No persistent hosted subscription, ontology completeness or general nonmonotonic semantics claim. |

Each crate has a library and CLI. PyO3 features `reasoning`, `science` and
`incremental` enable their respective `*_call` and `*_catalog` functions.
Default Python builds do not include these experimental providers. The ordinary
admitted-runtime operation registry is unchanged: native feature availability
does not itself admit a hosted operation.

The [reasoning host adapter](../../tools/oracle_components/reasoning.py) derives
limits from the actual native catalog and supports explicit host binding.
Ordinary construction is disabled; the operator selects the module and runtime
identity. Its identity string is not an attestation. The host still supplies
authentication, capacity admission, process containment and release provenance.
`Operations(None, config, providers=(provider,))` uses the actual discovery and
invocation registry without constructing a Python Engine. The retained binding
evaluation exercises that path for all three reasoning operations. This is not
yet the authenticated Mini HTTP/browser journey.

These implementations do not create a thread pool for each tenant. Scientific
decomposition is explicitly serial. Incremental batches run on the caller's
thread and discard their arrangements on return. Request variable names in the
e-graph are owned locally rather than retained in a process-global interner.
Cooperative search limits do not preempt a long library step; production hosting
must account for that boundary.

## Major integrations worth building

The following are proposals grounded in current specialist families and source
interfaces, not claims that the existing specialists already invoke the new
providers. Each has a user question, consumer and acceptance experiment.

| Integration | Existing consumers and new questions | Next implementation and decisive evidence |
| --- | --- | --- |
| **Network design and resilience** | `algorithms`, `networking`, `warehouse`, `robotics-v2`; “What is the cheapest connected network? Which links disconnect a site? What changes if this link fails?” | Consume supplied or explicitly sourced graphs. Add shortest paths, directed connectivity, cuts and counterfactual batches as distinct operations; an MST does not solve routing or redundancy. Compare small exhaustive cases and domain panels, then large sparse/dense graphs including checking and transport cost. |
| **Formula composition and reformulation** | `mathorgan`, `calculus`, quantity, mechanics, energy and fusion; “Can these measurements determine the unknown? Which equivalent formula is cheaper or better conditioned?” | Move from polynomial search to typed expression/assumption graphs, explicit domains and certificate replay. Compile compatible formula parts into shared subproblems. Compare existing fusion questions plus independently constructed multi-step questions, wrong dimensions and missing assumptions. |
| **Coupled balances and inverse problems** | `thermo`, `hvac`, `electrical`, `fluids-r2`, `labsolutions`, `statistics`; “What temperatures satisfy these heat balances? What stiffness and offset best fit these measurements?” | Connect typed specialist models to the supplied-matrix solver. Preserve units, weighting, rank and original-row residuals; add model-specific plausibility checks. Test manufactured exact systems, incompatible measurements, rank loss, scaling and perturbations. Statistical confidence needs a noise model, not merely a small residual. |
| **Exact reaction balancing** | `chemistry`, `chemistry-v3`, `labsolutions`; “Balance atoms and charge, and explain which coefficients remain free.” | Build exact stoichiometric matrices. Numerical nullspaces may propose candidates; rational/integer reconstruction and exact conservation checks decide acceptance. Multiple balances and positivity constraints remain explicit. Balancing does not establish reaction feasibility or rate. |
| **Maintained consequences and source withdrawal** | Relation readers, private lessons, dependency planning, ecology and provenance; “Which conclusions change when this source or dependency is removed?” | Promote the batch provider to demand-driven maintained views keyed by scope/release/version. Maintain support identities, settled frontiers and compacted history. Test duplicate supports, alternative paths, cycles, last-support withdrawal and restart against fresh recomputation after every version. |
| **Defaults and exceptions** | New planning/diagnostic specialists and supplied policy models; “What normally follows, which exceptions defeat it, and which alternatives remain consistent?” | Keep ASP/default reasoning separate from positive reachability. Declare closed predicates, assumptions and skeptical/credulous answer modes; integrate an appropriate solver through the same evidence boundary. Never convert missing public knowledge into falsehood. |
| **Numerically stable formulas** | `physics`, `statistics`, optics, finance and astronomy; “Which equivalent formulation loses less precision over this domain?” | Explore real identities with e-graphs, then evaluate floating-point error independently over a stated domain. Conditioning, interval analysis or rigorous bounds must guide selection. Reassociation is not generally an IEEE-754 identity. |
| **Astronomy and geometry from shared data** | `orbits`, `planetary`, `astronomy-*`, `geography`, `geometry-*`; state vectors, frame transforms, proximity and visibility. | Evaluate ANISE/hifitime and geo/rstar against pinned kernels, frames, time scales and geometric boundary cases. Keep large data shared; do not conflate precise time representation with a definition of a Mars calendar. |
| **Learned measurements and readouts** | New empirical specialists over model representations, signals or supplied observations. | Use shared tensor artifacts and native inference to compute properties unavailable to handwritten rules. Register task/model/data versions, held-out accuracy and abstention. A probe can be a substantive computation; its uncertainty remains empirical. |

## How the mechanisms fit together

Represent a request as typed quantities, entities, relations and explicit
assumptions, with source identities and a snapshot. Keep *equivalent expressions*,
*dependent facts* and *alternative hypotheses* distinct.

- A graph engine works on a supplied network or dependency structure.
- An e-graph explores equivalent expressions under an admitted theory and its
  conditions. An equality cannot be justified merely because two values happen
  to agree in one sample or because a language model says they are equivalent.
- A numerical provider evaluates or fits a declared model and reports diagnostic
  evidence. Units constrain the model but do not establish that it describes reality.
- An incremental engine maintains selected derived views when inputs change.
  It is an execution mechanism, not the semantics of belief revision.
- Extracted checkers, independent exact checks, numerical residuals, source
  provenance and empirical evaluation attach different kinds of evidence to
  specific claims. Avoid collapsing them into a single `verified` boolean.

An important design constraint is assumption withdrawal. Equality merging is
normally monotone; deleting a supporting fact does not automatically split a
previously merged e-class. Build assumption-dependent e-graphs for explicit
snapshots, or rebuild affected analyses when assumptions change. Do not simply
feed retractions into a dataflow and assume every downstream optimizer has undone
its equivalences.

For source provenance, distinguish alternative support from joint support:
`a+b` means either source suffices; `a*b` means both were used. A plain set of
source IDs loses this distinction. Factorized provenance DAGs are a promising
representation, but unrestricted polynomial expansion or recursive explanations
can be enormous. Retain bounded handles to explanation structure; do not claim
that today's reachability deltas already supply complete provenance.

For multi-tenant hosting, share immutable public resources and compiled rules.
Keep private overlays, assumptions and cache identities scoped. Do not replicate
the full public graph into every dataflow, or maintain all-pairs reachability
over the entire knowledge base. Demand-driven views and workload measurements
must decide what deserves persistent arrangements. Quiet tenants should not
own permanent solver workers or huge indexes.

## What the literature changes in this design

Selected sections were read from the existing local paper collection; these are
design deductions, not replications of the papers' experiments.

- [egg](https://arxiv.org/abs/2004.03082) motivates retaining alternatives and
  using domain analyses instead of a brittle sequence of destructive rewrites.
  Our immediate experiment checks an extracted candidate independently.
- [egglog](https://arxiv.org/abs/2304.04332) brings relational analyses and
  equality reasoning together. Its treatment of conditional rewriting suggests
  a later shared analysis of dimensions, nonzero facts and intervals. Evaluate
  it when these cooperating analyses exceed the small current egg provider.
- [Differential Dataflow](https://www.cidrdb.org/cidr2013/Papers/CIDR13_Paper111.pdf)
  distinguishes changes to input from progress through iterative computation.
  That motivates testing real recursive retractions and waiting for a frontier,
  rather than equating an input flush with a complete answer.
- [DBSP](https://arxiv.org/abs/2203.16684) supplies a complementary algebraic
  account of incremental view maintenance. Use it to state what a maintained
  view means and compare it with recomputation before choosing a backend.
- [Provenance Semirings](https://www.cs.ucdavis.edu/~green/papers/pods07.pdf)
  motivates retaining the algebra of joint and alternative support. Positive
  provenance does not by itself solve negation, defaults or contradictory facts.

## Assurance and performance experiments

The [retained provider evaluation](../evidence/2026-10-29-reasoning.json) uses
the actual Linux extension and host adapter. On the 4,096-vertex/16,384-edge
synthetic graph, median native time was 3.884 ms versus 14.995 ms for independent
Python Prim, including native result checking and JSON/PyO3. Seven repetitions
and phase timings are retained; this is not a general speedup or concurrency
claim. Six algebra examples passed exact checks; five selected lower tree costs.
Two scientific examples and the incremental support/cycle example ran through
the same built Python module.

The [incremental benchmark](../evidence/2026-10-29-incremental.json) is a negative
performance result: 48 nodes and 80 versions took 74.234 ms with maintained
dataflow versus 7.556 ms with fresh traversal. Every settled delta and answer
matched. On this small workload, retained state and coordination cost more than
they save. Keep fresh recomputation as the comparison and investigate larger,
demand-driven workloads before selecting a persistent engine. Do not claim a
performance benefit just because an algorithm is incremental.

The existing extracted `mst_cert` establishes more than tree membership: its
theorem states minimality against competing spanning structures. However,
`src/extract/discrete/main.sml` currently exposes question/answer requests, not
external certificate verification. The next extracted-code task is to export
and expose that checker without rebuilding the candidate internally. Explicit
isolated vertices and disconnected forests also need an honest mapping to its
edge-derived node universe; the Rust provider must not inherit a broader theorem
than the interface supports.

The first graph check enumerates every edge subset for 128 generated small
multigraphs, comparing candidate and checker behavior against exhaustive
optima. Independent Python Prim supplies a second implementation for larger
synthetic workloads. Benchmarks include candidate construction, checking and
JSON/PyO3 overhead. They do not establish an upstream whole-head speedup.

The polynomial checks include identities, false identities that agree at sample
points, exact large coefficients, expansion limits and dimensional cancellation.
Scientific tests include manufactured solutions, inconsistent equations,
nonidentifiability and numerical range failure. Incremental tests compare every
settled version with independent fresh graph traversal, including deletions.

Before admitting these in the full appliance, finish shared capacity and killable
process boundaries, release/artifact registration, complete evidence transport,
real operator enablement, and the agent/browser/restart journey. Then run the
affected shipped panels and independent domain batteries. No new specialist-panel
scores or Isabelle theorems follow from this experimental provider cut.

## Next batches

1. Qualify the optional providers together and publish a reproducible upstream
   checkpoint, including negative results and unfinished host boundaries.
2. Connect the extracted graph checker, a typed scientific specialist consumer
   and demand-driven incremental impact to real operations. Measure the first
   domain-coverage gains rather than only crate-level tests.
3. Develop assumption-aware symbolic composition, exact reaction balancing and
   richer graph queries against existing family panels and new independent cases.
4. Finish shared hosted admission/recovery; evaluate larger scientific,
   astronomy, optimization and probe providers through the same interfaces.

The [native foundation tracker](../../project/lanes/NATIVE-FOUNDATION-2026-10-28.md)
continues to track the complete appliance. These new capabilities complement
that work; they do not replace the unfinished conversational runtime.
