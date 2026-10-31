# Connect native providers to Oracle

The [capability catalog](CAPABILITIES.md) lists the operations that run today.
Graph optimization, exact polynomial/dimensional rewriting, reaction balancing,
numerical solving/fitting, thermal models, dependency batches, DNA alignment and
regression have optional PyO3 and standalone HTTP consumers. Durable data/language
hosting and relocatable packaging also run. These are not yet consumers of the
full upstream specialist cascade, and have no new specialist-panel scores.

## Next specialist consumers

| Consumer | Integration work and acceptance question |
| --- | --- |
| `algorithms`, `networking`, `warehouse`, `robotics-v2` | Use existing MST and directed shortest-path operations on supplied or explicitly sourced graphs. Add cuts/connectivity/counterfactuals as separate operations. Does the specialist answer new independently checked questions and improve its shipped panel? |
| `mathorgan`, `calculus`, quantity, mechanics, energy, fusion | Extend polynomial rewriting to typed expressions with explicit domains and assumptions. Compile compatible formula parts into shared subproblems; check dimensions, missing assumptions and certificate replay. Current polynomial search does not replace SymPy. |
| `thermo`, `hvac`, `electrical`, `fluids-r2`, `labsolutions`, `statistics` | Connect typed models to existing linear/fitting/thermal providers. Preserve units, weighting, rank and original-row residuals; test rank loss, scaling, perturbations and model plausibility. |
| `chemistry`, `chemistry-v3`, `labsolutions` | Feed the existing exact balancing operation complete supplied species/inventories. Test isotope/charge conservation, free coefficients and infeasible positive balances. Conservation does not establish reaction rate or feasibility. |
| Relation readers, lessons and dependency planning | Turn finite batch dependencies into demand-driven maintained views only where measured workloads justify retained state. Test withdrawal, duplicate/alternative support, cycles and restart against fresh recomputation. |
| Defaults and exception reasoning | Hosted query/enumeration, durable evidence revisions and restart recovery now run with an admitted solver. Connect revised evidence to a concrete calculation or planning consumer; improve checked restoration before introducing persistent solver state. The [current receipt](../evidence/2026-10-31-native-cycle-validation.json) covers actual solver and recovery paths; it does not establish full Engine dialogue or action authority. |
| Astronomy and geometry | Evaluate pinned ephemeris/frame/time and spatial libraries against explicit source coverage and boundary cases. Keep large data shared. Precise time arithmetic does not define a Mars calendar. |
| Empirical readouts | Admit shared model artifacts and task-specific native inference. Record model/data versions, held-out accuracy, calibration and abstention before promotion. |

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

## Retained experiments

The [provider evaluation](../evidence/2026-10-29-reasoning.json) includes actual
extension/adapter calls. On one synthetic 4,096-vertex, 16,384-edge graph,
median native time was 3.884 ms versus 14.995 ms for independent Python Prim,
including native checking and JSON/PyO3. Seven repetitions and phase timings
are retained; this does not establish a full-Engine or concurrency speedup.

The [incremental benchmark](../evidence/2026-10-29-incremental.json) is a negative
result: 48 nodes over 80 versions took 74.234 ms with dataflow versus 7.556 ms
with fresh traversal. Every settled delta and answer matched. Larger,
demand-driven workloads must justify retaining arrangements.

The [resident extracted checker](../../src/extract/discrete-certificate/README.md)
is connected to the actual Rust MST producer through `KernelTenant` and an
operator-admitted process pool. Connected-tree acceptance can carry admitted
HOL build evidence; disconnected forests remain under the independent Rust
check. This is a separate library path, not automatic extracted checking on
every HTTP graph operation.

Next evidence should measure specialist coverage gains and the complete consumer
cost, including parsing, checking, transport and recovery. Keep independent truth
cases and failed runs. The [roadmap](ROADMAP.md) tracks broader runtime work.
