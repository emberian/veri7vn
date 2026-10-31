# Cross-review: turn shared machinery into stronger specialists

31 October 2026. Design review of all eleven completed scout reports, with targeted source checks. Research/planning only: no implementation, builds, tests or new panel numbers. No new papers were acquired; this review relies on the scouts' explicitly scoped primary-source readings and current source, not independent verification of their entire bibliographies.

## Main judgement

The portfolio is technically credible and substantially more useful than a wholesale Rust rewrite. Its largest delivery risk is that every report begins with a sensible prerequisite, and their union becomes another round of host infrastructure with no new specialist. Organize the work around completed consumer workflows. Share only the contracts those workflows immediately need; do not put a universal value engine, global evidence system, persistent solver or general planner on their critical path. Mini hosting belongs elsewhere.

Three capability families deserve parallel investment: exact constrained computation; scientific/statistical modeling over supplied observations; and reading/searching retained structured data. Learned discourse binding is a fourth, deliberately empirical research track. Formal assurance should strengthen these capabilities, not force every useful new computation into exact arithmetic or relegate learned operations to implementation aids.

## Verified intersections and corrections

Source checks substantiate the strongest representation recommendations. `native/oracle-host/src/pure.rs::invoke` builds an operation envelope, calls `wire::encode`, converts it to a string, invokes the provider and reparses its reply. Typed entry points already exist. This is a removable bridge, not a reason to redesign each provider. However, preserving duplicate-key rejection, exact numeric literals, missing/null distinctions and byte limits is part of the change; a typed call is not automatically semantically equivalent.

`native/oracle-core/src/reader.rs::compile_candidate` serializes an already constructed program and calls `Program::parse` before compilation. Its evaluation loop explicitly checks every entity-producing intermediate, including dead branches. Thus packed handles and shared evidence are worthwhile continuations of existing work; ordinary dead-code elimination is not a drop-in optimization. The reader already has lexical/region sharing and canonical stages. Do not sell another chart or interner as a new foundation. Repair the poisoned alias export first and retain data-only/code-only comparisons.

The dimensional collision is real: `Fusion.thy` defines six axes ending in dollars; `native/oracle-reasoning/src/dimensions.rs` defines seven SI axes whose sixth is amount of substance. A shared quantity contract must use a named dimension schema and explicit conversion. It must also separate temperature points from differences, exact supplied values from measured uncertainty, and mathematical dimension from physical role. A length is not evidence that it is the requested height. Currency needs denomination/date policy when conversion is requested, not placement into an SI slot.

The bio scout correctly identifies the critical cost: `oracle-bio::replay` calls `optimal_score`, an independent rolling-row quadratic computation. A faster candidate aligner cannot remove that floor. Exact collection search and coordinate-preserving translation are genuinely different capabilities; unit edit distance, affine alignment and sketch similarity must remain different operations.

`session.rs::SessionTurn` and schema-2 records already exist. Extend the committed-answer boundary; do not introduce competing session or replay systems. Similarly, AND/OR support and negative guards are needed for revision semantics, but reachability alone cannot decide whether an answer lost its last support. A host ledger is justified by an explicit revise-and-explain consumer, not by incremental-engine availability.

The exact LP proposal has the best cross-domain reuse: positive supplied-species balances, constrained mixtures and resource allocation. Its four witness outcomes are stronger than heuristic bounded positivity search. Preserve original-row binding and normalization maps. Integer-minimal coefficients, uncertain physical models and discrete schedules are separate problems. Mathematical optimality over supplied rows is not model adequacy.

## Minimal common contracts, with separate owners

1. **Admitted input reference:** immutable owned data plus content/schema identity; source and coverage revision where applicable. Domain types own row, sequence, graph and model semantics. Do not require all inputs to become Arrow tables or one universal arena.
2. **Result claim and status:** distinguish exact checked result, numerical result with acceptance diagnostics, empirical prediction, solver-trusted conclusion, unsupported input and exhausted resources. These are claim kinds, not a single assurance ladder. Record scope and assumptions; never let a common `checked` boolean erase them.
3. **Execution context:** existing cancellation/budget mechanisms with shared nested-call accounting. Byte/cell counts alone are inadequate for rational arithmetic: coefficient bit growth and checking work need limits. Keep provider semantic caps. New context types do not make SVD or third-party solvers preemptible.
4. **Delivered context delta:** referent/quantity/evidence updates commit only after arbitration. Equal display strings do not establish equal entities or evidence. Computational memoization and presented provenance can have different identities.

Coverage itself has at least four distinct meanings: supplied rows fully read, source snapshot query fully traversed, admitted parse candidates exhausted, and population/world completeness asserted. They must not share an unqualified boolean. Sampling assumptions are a fifth concern, not a consequence of any of the four.

## First two phases

**Phase 1: deliver useful native workflows while removing demonstrated friction.** Connect existing numerical calibration end to end and pair it with an exact one-predictor mode, without presenting them as interchangeable uncertainty models. Extend the current thermal consumer to repeated scenarios and analytic sensitivity; reuse its factorization where valid, with dense SVD as reference. Ship exact both-strand fragment search over immutable supplied sequence collections, including complete paging and source coordinates. Build bounded exact LP checking with supplied-species positivity as its first consumer and a stock-constrained blend example as its second. Each must have a real specialist folder/adapter, own panel and independent truth cases, not just a callable kernel.

Alongside those consumers, repair reader export and remove the two measured serialization/flattening bridges. Freeze the four shared contracts narrowly around their needs. Give learned binding/readout research a capped activation/label pilot; do not wait for formal verification or a durable evidence platform. These are parallel work packages, not a promise that all finish on one timetable.

**Phase 2: compose and deepen.** Add qualified multi-hop reading and deeper nesting with explicit completeness/refusal semantics; attach retained observation revisions to one concrete calibration/thermal or planning workflow. Add events-and-exposure GLMs and sequence translation with coordinate maps. Extend exact LP to user-facing blend explanations and bounds. Choose transient thermal integration only after scenario/sensitivity semantics and numerical acceptance are solid. Promote learned bindings only if held-out prose usefulness survives controls, retaining empirical status. Persistent solver arrangements, full streaming statistics, sketches and alternative aligners remain workload-driven choices rather than mandatory platform milestones.

At both phase boundaries report shipped own-scorer numbers separately from new workflow panels and independently authored truth cases. Compare actual host dispatch, not isolated provider success. This review has none of those new results.

## Three design experiments worth doing

**A. One scenario dataset across exact, numerical and empirical computation.** Use a supplied engineering notebook: extracted observations remain empirical; confirmed table rows feed calibration; supplied network parameters feed thermal scenarios; a bounded blend/resource problem receives exact certificates. Hypothesis: common input/claim identity supports valuable composition without a universal solver. Reject if adapters silently strengthen uncertainty, conflate roles or require bespoke global orchestration for every step. This experiment probes capability and semantic interfaces together.

**B. Preserve packed structure through answer agreement.** Compare highly shared derivations against genuinely distinct denotations, recording compilation, evidence hydration, peak bytes and final refusals. Hypothesis: typed handles/shared outcome evidence remove substantial work without reducing the admitted interpretation set. Learned ranking alone generally cannot reduce exhaustive successful-case work; it can find disagreement earlier or improve bounded search utility. Reject claims that top-k agreement establishes exhaustive correctness.

**C. Useful learned bindings before mechanistic naming.** Compare frozen-activation readouts against lexical, position-only, embedding and generated-answer baselines on unseen relations/templates and independently authored prose. Measure complete-table utility and wrong bindings at fixed coverage, not only tuple averages. Source offsets establish traceability, not entailment. Hypothesis: an empirical relation table is useful even without an interpretable mechanism. Reject it if gains disappear outside synthetic templates; defer SAE/IIT work unless it improves this consumer or a separately measured causal question.

One opportunity deserves emphasis: revision experiments can test the *same* model before and after a withdrawn observation, changed boundary condition or corrected species inventory. This joins grounded data, powerful specialists and accountable updates without first building a general knowledge operating system.

## Architecture and native-host excellence is a parallel deliverable

The two phases above include a first-class architectural track, not merely local fast paths supporting specialists. Its acceptance criteria are:

- **Typed dataflow:** validated typed values and immutable input handles survive provider dispatch, composition and evidence hydration. Removing serde calls is insufficient if each boundary still clones full inputs or flattens shared results. The current `pure.rs` envelope/reparse and `reader.rs` encode/parse bridges are concrete unfinished paths; preserve their admission semantics while eliminating redundant representations.
- **Explicit ownership:** distinguish immutable images, worker scratch, request arenas, durable session/evidence records and evictable caches. Scratch cleanup must survive cancellation; cache eviction cannot erase committed conversational meaning. Extend existing `SessionTurn`/runtime ownership instead of adding another state authority.
- **One execution budget:** nested calls inherit deadline, cancellation and aggregate memory/work/output accounting. Third-party SVD/alignment calls are not made interruptible by passing a context; retain capacity until return and use bounded process containment where hard termination is required.
- **Bounded fair scheduling:** enforce global and tenant admission, bounded queues and starvation-resistant service; avoid nested worker pools. Test mixed cheap/expensive requests, cancellation while queued and overload without unbounded retained input.
- **One operation contract:** Rust catalogs, host descriptor snapshots, schemas and PyO3 exports agree on feature availability, versions, limits and result/refusal meaning. Direct typed calls must not create a second, more permissive API.
- **Measured simplification and performance:** compare release builds through actual dispatch, including children, retained sessions, cold/warm latency, concurrent tails, peak/private memory and cancellation delay. Track removed duplicate adapters/representations as well as speed. No measured improvement is claimed yet.

Each phase must satisfy architectural acceptance alongside consumer scores. A universal framework is unnecessary; a coherent host with simpler shared execution paths is not optional.
