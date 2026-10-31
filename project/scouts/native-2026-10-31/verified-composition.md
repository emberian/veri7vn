# Verified composition: check the claim at a small boundary

31 October 2026. Research/design only: no builds, proofs, tests, implementation or new panel runs. This lane has **no panel numbers**. The current tracker reports algorithms-native 18 right / 0 wrong / 0 false yes of 42 per split, and eight wrong fallback answers in its composed dev run; these are existing receipts, not this lane's measurements.

## Recommendation

Keep one Rust execution host, reuse the extracted engines, and make candidate checking an explicit operation where it buys a stronger capability. Start with the already exported MST checker and exact arithmetic; next add an exact supplied-data calibration specialist. Preserve separate statuses for a mathematical result, an empirically checked numerical result, and an unsupported instance. A successful solver is not a certificate; a certificate is not evidence that supplied data describe the world.

## What the source actually establishes

`src/extract/discrete-certificate/Mst_Certificate_Export.thy` is already the right architectural example. `external_mst_cert vs es t` requires distinct vertices, at least two vertices, equality between the explicit vertex set and edge-derived vertices, and `mst_cert es t`. Acceptance implies `spans t es` and `connects t vs`; with any competitor satisfying `spans t' es`, it implies `wt t ≤ wt t'`. These statements do not mention a candidate producer. `Disc_Algos.thy` defines spanning as graph-edge membership, n−1 edges and connectivity; its independent minimality check counts edges above each weight threshold against components formed by cheaper edges. It is not a restatement of Kruskal.

The current protocol has narrower scope than the mathematical rational-weight predicate. `discrete-certificate/main.sml` accepts canonical, bounded `mst-cert-v2` frames, ≤64 vertices, ≤256 edges, i64 integer weights, and stable candidate edge-occurrence IDs. It distinguishes unsupported disconnected inputs from rejected candidates. Empty, singleton and isolated-vertex graphs cannot pass this exported predicate. Framing, occurrence projection and preliminary connectivity classification are explicitly untrusted. Do not turn unsupported into a claim of infeasibility. A future forest checker needs an explicit vertex universe and component partition, not merely removing a guard.

`src/extract/mathorgan/Math_Closed.thy` already defines `check_closed e v`: a supported closed AST whose original evaluator yields `Some v`. Acceptance proves `ev i e = Some v` for every variable reading and the corresponding `kernel (EvalExpr e)` value. Powers are limited to 2 or 3, and `0*(1/0)` remains undefined. `Math_Affine.thy` and `Math.thy` contain affine soundness, linear solution, conversion and integer-square-root interval results. This makes reuse preferable to a second arithmetic engine.

`Wordprob_Units.thy` proves scale conservation for selected geometry/motion constructors, inverse speed/distance under nonzero time, and six-digit rendering error. Geometry uses a selected rational pi, not real pi. English recognition is outside the theory. These are finite unit/model statements, not a general physical-law checker or a proof of the recognizer's interpretation.

`native/oracle-reasoning/src/formula.rs` owns a dimensional DAG, exact rationals, bounded arithmetic and replay. `formula_search.rs` translates egg explanations into that checker's certificates; search analysis facts are recomputed. The intended judgement preserves both value and definedness over caller-supplied closed bounds. This is **independent Rust replay, not an Isabelle theorem**. Its separation from egg is valuable; importing search metadata as trusted premises would destroy it. The older conditional-symbolics experiment is not the production implementation.

`GeoStats_Paired.thy` is particularly useful: `line_fit ps=Some(a,b)` implies zero residual sum and zero x-weighted residual sum. It also proves, for arbitrary competing `(c,d)`, `SSE(c,d)=SSE(a,b)+line_distance(c-a,d-b)` and `SSE(a,b)≤SSE(c,d)`. The exported fit declines when sample count or centered x variation is inadequate. This proves exact rational least squares for an intercept and one predictor. It does not prove prediction intervals, Gaussian assumptions, causal interpretation or the floating-point multi-feature provider. `GeoStats_Weighted.thy` proves balance and bounds for weighted means, not general weighted regression.

`native/oracle-statistics/README.md` states the broader provider has no Isabelle theorem or specialist panel score. It returns floating-point regression, uncertainty and diagnostics under declared assumptions; unit strings are retained assertions. Exact simple regression can complement this provider without pretending to verify all its inference.

The assurance audit is explicitly historical; its 2,234-statement classification is not today's inventory. The current native tracker still calls for a fresh assurance/beyond-parity audit. Audit the **consumer path and theorem premises** of selected operations first. Never infer current percentages from old counts or added theorem names.

## Three concrete designs

### 1. Small typed acceptance boundaries — first choice

Use domain-specific inputs and candidates, with a common receipt header only: operation/schema version, admitted input identity, assumption/data revision, checker identity, result claim and scope. Keep these types distinct from plain provider replies. Within one process a checked handle should retain immutable input ownership; across a process boundary bind the exact canonical input bytes and operation version. A request ID alone does not bind content.

For MST, candidate edge IDs refer to the original multigraph list. For closed arithmetic, candidate is an exact rational checked against the original AST. For measured quantities, use existing typed constructors with requested units and explicit pi/rounding choices; first reuse the kernel rather than prove a general dimension algebra. Do not design one universal certificate language now.

An acceptance receipt must name the narrow mathematical claim. Preserve `reject`, `unsupported`, resource exhaustion, protocol failure and cancellation separately. A timeout says nothing about whether the answer exists. Candidate production can be Rust, extracted search or a learned program; its origin grants no extra authority.

### 2. Exact calibration and accounting specialists — strongest new consumer

Offer supplied rational observations with explicit predictor/response units. Return exact intercept, slope, fitted residual moments and SSE, checked using the existing extracted fit. Initially compute with that engine directly. If a faster numerical proposer later earns its cost, add a tiny extracted predicate checking candidate normal equations over the original rows, then prove the general normal-equations-to-minimality implication from the existing SSE expansion. That is a proposed extension, not an existing theorem.

A useful specialist answers force/displacement calibration, cost/production fits and deterministic trend summaries. Separate the exact optimum of the supplied loss from empirical adequacy and statistical uncertainty. For near-rational floating-point output, failure to reconstruct an exact candidate should retain the numerical result with its existing qualification, not silently round it into a proved coefficient. For large data, rational growth may make the checker slower than solving; measure and reject that path if so.

### 3. Primal/dual certificates — later capability, not a solver rewrite

A small exact LP interface can unlock allocation, mixture and bounded planning specialists: supply rational `A,b,c`, nonnegative primal variables and a dual witness; check primal feasibility, dual feasibility and equal objective under one fixed inequality convention. A Farkas witness can certify infeasibility. Start with a checker and externally supplied candidates, not a general mixed-integer solver. This is new scope requiring its own mathematical statement and consumers; existing graph checks cannot confer this guarantee.

## Diversity and coverage boundaries

Independent Rust checks give local fault containment and broad availability; extracted HOL checks give a theorem about the defined predicate plus language/algorithm diversity. Running both only adds useful evidence when inputs and claims align. They still share possible input interpretation, canonicalization or omitted-data errors. Different programming languages do not establish independence by themselves. Do not port a verified solver to Rust simply to manufacture diversity.

`src/isabelle/reader/Relation_Reader.thy` explicitly assumes the fetch's `complete` flag. `answer_requires_coverage` proves acceptance requires that flag; it does not prove the database fetch exhaustive. For relational absence, uniqueness, counts and graph optimality derived from records, bind a coverage object to dataset revision, entity/property domain, filters and traversal limits. Completeness over the supplied subgraph is different from completeness over a source store, and both differ from completeness about reality. Pagination truncation, missing aliases and unqueried properties must invalidate negative/aggregate claims. A digest binds bytes; it does not prove coverage.

## Literature translated into choices

[McConnell, Mehlhorn, Näher and Schweitzer, *Certifying Algorithms*](https://people.mpi-inf.mpg.de/~mehlhorn/ftp/CertifyingAlgorithms.pdf), published 2011; downloaded author-hosted preprint dated 2010. Read §§6.2–6.3, 8.2, 8.5 and 9.7 plus definitions/context. Its original-input warning explains why a sorted output alone is insufficient: it must preserve the input multiset. Its composition rule requires the first postcondition to establish the second precondition. Consequently compose typed claims and premises, not booleans labelled checked. Its numerical section distinguishes validated error bounds from mere successful execution.

[Cheung, Gleixner and Steffy, *Verifying Integer Programming Results*](https://arxiv.org/abs/1611.08832), IPCO 2017, retrieved v2. Read introduction and certificate inference/assumption-discharge discussion (§§2–3). Sequential simple inference rules permit independent replay; branch assumptions must be discharged before accepting a global claim. LP primal/dual witnesses are a small entry point; MIP certificate growth and inference complexity argue against beginning with a universal optimization service.

Existing `~/paperbin/oracle7-20261027/symbolic/egg.pdf` and `egg.txt` were reused, with introduction/analysis sections inspected. Willsey et al.'s equality-saturation machinery motivates flexible search; it does not itself justify our domain-sensitive rational rewrite rules. Keep production replay authoritative.

Discovery used three focused Kagi searches and one bounded [Scry](https://scry.io) academic query, after live context/schema inspection. `arxiv.papers` was unavailable; the corrected `academic.papers` query completed. Search results are discovery, not evidence of formal guarantees. New PDFs, hashes, URLs and reading depth are in `~/paperbin/oracle-native-20261031/verified-composition/manifest.json`; no paper bodies enter the repository.

## Phases and decisive rejection cases

1. Inventory these four consumer paths and their exact predicates; freeze typed input/receipt semantics. No full audit or new solver required.
2. Pilot existing MST and closed-expression checkers through the host, measuring resident/wire cost separately from search. Retain existing panels and add independent truth cases.
3. Ship exact calibration with a real supplied-data workflow; only then choose candidate checking versus direct extracted computation. Consider LP after a concrete allocation consumer exists.

Acceptance tests must mutate the candidate **and input binding**: heavier spanning tree, omitted isolated vertex, duplicate/parallel occurrence IDs, tied/negative weights, reordered edge list with old candidate IDs; `0*(1/0)`, `x/x` with bounds containing zero, stale nonzero bounds, changed unit exponent, affine temperature as a linear quantity; constant-x data, one observation, duplicated observations, nonzero residual moment, mismatched x/y lengths and changed filtering. Coverage tests must truncate the final page, omit a competing value and change the source revision. LP tests must flip a dual inequality sign and submit a feasible but suboptimal point. Resource limits must produce no acceptance and retain useful qualified numerical output where available.

Dependencies: coordinate representation/input ownership with the runtime scout; certificate snapshots and retraction with evidence-revision scouts; exact versus numerical claims with statistics/science scouts; retained row coverage with reader planning. Open choices are user workload size and whether exact calibration has sufficient demand to justify a new surface. They are questions for implementation selection, not permission barriers.
