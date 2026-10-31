# Native capabilities

The standalone service advertises operations from the admitted extension's actual
catalog. Optional features must be compiled in and selected by the operator.
A listed Rust library is not automatically an HTTP operation.

| Profile | Operation IDs | What it does and where it stops |
| --- | --- | --- |
| `reasoning` | `graph.minimum_spanning_forest` | Finds and independently checks a minimum spanning forest with exact signed integer weights, parallel edges and isolated vertices. The HTTP operation uses the Rust check. Separate resident extracted checking is described below. |
| `reasoning` | `graph.shortest_path` | Directed integer-weight paths with checked finite, unreachable or unbounded witnesses. The graph is supplied by the caller. |
| `reasoning` | `algebra.optimize_polynomial`, `algebra.optimize_dimensional_polynomial`, `algebra.simplify_rational` | Bounded integer-polynomial rewriting, checked by separate exact normalization. The dimensional version checks supplied SI dimensions. `simplify_rational` adds division and exact rational literals over SI quantities: an untrusted e-graph search proposes a simpler formula, and a separate Rust checker replays its step-by-step certificate under the caller's closed variable bounds (same domain and same values on those bounds), lists each original denominator as nonzero within the bounds or not established, and can evaluate exactly at one point. Checked by replay, not proved in Isabelle; no transcendental functions, open intervals, floating-point identity or global optimum guarantee. |
| `reasoning` | `chemistry.balance_reaction` | Exact atom, charge and isotope conservation for supplied species. Does not establish reaction feasibility. See [chemistry](CHEMISTRY.md). |
| `reasoning` | `reasoning.exact_linear_feasibility` | Exact rational certificates over supplied inequalities `a*x <= b`, with unrestricted variables. A feasible point or a Farkas certificate is replayed separately in Rust. An optional minimization objective is metadata for this feasibility proposer: a feasible point does not establish optimality. Resource exhaustion withholds a conclusion. No Isabelle or model completeness claim. |
| `science` | `science.solve_linear`, `science.least_squares`, `science.thermal_network` | Numerical equations, fitting and supplied thermal models, with diagnostics. A small residual does not establish the model's truth. |
| `science` | `science.thermal_scenarios` | Reuses one supplied passive network factorization for bounded complete load/boundary scenarios and local load/conductance sensitivities. Checks balances at the original nodes. Scenarios are samples, not uncertainty bounds or a worst-case search; labels and physical assumptions remain supplied premises. |
| `incremental` | `incremental.dependencies`, `incremental.rooted_dependencies` | Versioned finite dependency batches, insertions/retractions and settled changes; rooted queries restrict the requested view. Arrangements are discarded after the call; no hosted subscription. |
| `bio` | `bio.align_pairwise` | Supplied-sequence alignment. See [DNA and statistics](BIO-STATISTICS.md) for scoring and limits. |
| `bio` | `bio.search_collection` | Batched exact ACGT fragment search across supplied immutable records, both strands, original zero-based half-open coordinates, source-bound cursors and bounded pages. Completion covers the cursor suffix; full absence requires every page from the beginning. No homology or alignment claim. |
| `statistics` | `statistics.calibration` | Supplied paired data and a y-on-x line: forward mean, new observation or algebraic inverse point. Units are labels. Conditional pointwise intervals require stated model/noise assumptions; inverse intervals withhold a value. No measurement-error correction or causal claim. |
| `statistics` | `statistics.linear_regression` | Conditional inference over a supplied linear model and noise assumptions. See [DNA and statistics](BIO-STATISTICS.md). |
| `logic` | `logic.query`, `logic.enumerate` | Stable models of one supplied, complete, finite, grounded normal logic program (no variables, disjunction or aggregates), using an operator-admitted clingo executable. `query` answers skeptical and credulous truth per atom; `enumerate` lists all models up to 256. Every returned model is independently checked; "no model", "true in all models" and inconsistency trust the solver without a certificate. Timeouts, caps and solver failures give `inconclusive`, never `inconsistent`. `scope.tenant` must be the host tenant; `scope.complete_program` is the caller's unverified claim. Replies carry a content hash of the program. Nothing is stored; results authorize no action. See its [README](../oracle-logic/README.md). |
| `reasoning` | `reasoning.optimize_linear` | Minimizes a supplied rational linear objective under explicit inequalities. Separate exact replay checks original-row primal/dual optimality, infeasibility or unbounded-ray certificates. Exhaustion withholds a conclusion; no integer optimization or source completeness claim. |
| `science` | `science.thermal_transient` | Supplied passive heat capacities, piecewise constant loads and fixed reservoirs. Adaptive implicit integration retains local error estimates, original-node integrated energy balances and sampled threshold brackets. These are numerical estimates, not rigorous global error bounds or a real building forecast. |
| `bio` | `bio.translate_coding_intervals` | Literal standard-code translation of explicit supplied forward/reverse intervals, with codon-to-original-source coordinates and explicit frame, remainder, stop and ambiguity policies. Does not find genes, infer initiation, call ORFs or infer protein function. |
| `statistics` | `statistics.events_exposure` | Grouped-binomial logistic and exposure-aware Poisson models on supplied rows. A reported finite fit requires an exact existence/identifiability certificate and numerical convergence. Separation, unsupported inference and unresolved optimization remain explicit; caller assumptions do not establish sampling or causality. |
| `statistics` | `statistics.sequential_monitor` | Replays a bounded ordered stream with a prespecified confidence-sequence contract, error allocation, bounds and sampling assumptions. No retained monitor or automatic stopping; an empty interval remains an answered mathematical result. Caller-supplied history is not authenticated provenance. |
| `runtime` | `graph.query`, `graph.execute` | Query DAGs over an admitted KQA-shaped image. These IDs refer to data queries, not the supplied-graph optimizer above. `execute` journals a versioned session turn. |
| `runtime` | `kqa.query`, `kqa.execute` | The pinned 27-operation KQA program vocabulary. Typed values retain exact decimals, unit and date distinctions; ambiguous cases can refuse. |
| `runtime` | `reader.whole`, `reader.execute` | Learned whole templates, exact fragment/outer composition, 2–4-segment chains and one nested fragment pass. Successful readings must agree. `execute` journals the language turn; `whole` is pure. Requires admitted in-image reader tables. |
| `runtime` | `graph.batch` | Typed graph/KQA plans share one image lease and bounded stage/column caches. Previous selection is empty. Every item retains its result or explicit failure; later unattempted items are marked. |
| `runtime` | `graph.coverage` | Traverses a declared canonical relation domain to actual EOF. Count, absence and uniqueness require complete traversal and matching snapshot/domain. Does not establish alias, class or world completeness. |
| `runtime` | `context.execute` | Atomically observes, scales, clears or inspects a delivered dimensionless scalar. Preserves exact versus imported Python-float origin. Uses native session ownership; no automatic Engine conversation takeover. |
| `runtime` + `logic` | `logic.workspace`, `logic.workspace.solve` | Persists identified supplied evidence and withdrawals in the session journal, then freshly solves a checked immutable revision. Solving needs the operator-admitted solver. Local coverage declarations remain supplied premises; negative conclusions retain solver trust. |

New operations require matching compiled catalogs and host descriptors. The
first and expansion batches have passed their hosted workflow panels. See the results below and the [data/state guide](DATA-AND-STATE.md).

Pure supplied-argument operations recompute on retry. Stateful runtime operations
persist exact replies with their session changes; pure operations do not.
See [runtime hosting](RUNTIME-HOST.md) for release
admission and retry identity, and [standalone serving](STANDALONE.md) for HTTP.

## Extracted code and library-only paths

`KernelExecutor` hosts bounded resident extracted quantity/acoustics kernels and
the connected-MST checker. These are operator-admitted library paths, not extra
operations automatically added to standalone discovery. With `reasoning`,
`KernelTenant.minimum_spanning_forest` composes the Rust candidate/checker with
the resident extracted checker. Disconnected graphs, singletons and isolated
vertices are outside that extracted connected-tree guarantee. HOL evidence also
requires admission of the actual compiler/proof receipts. See the [checker
contract](../../src/extract/discrete-certificate/README.md).

Rust hosts can atomically commit authorized effect intents with state and reply,
then claim and settle them through `HostEffects`. No teaching, filesystem,
network or other external executor is supplied by that outbox.

`oracle-logic` is hosted as the optional `logic` profile and has been exercised
through the relocated Linux package. Its model checks and solver-trusted absence
claims are distinct; see its [README](../oracle-logic/README.md), the core
[receipt](../evidence/2026-10-29-logic-validation.json) and the macOS
[hosting receipt](../evidence/2026-10-29-logic-hosted.json).

The [design experiments](../experiments/README.md) explore streaming queries,
maintained views, conditional formulas and evidence revisions. Their new code
and examples compile and their authored fixtures and tests pass on macOS
([receipt](../evidence/2026-10-29-experiments-execution.json)); they are not benchmarked, have no panel numbers, and are
absent from service discovery.

## Coverage and evidence

No new shipped specialist-panel scores are available. Component checks and small
real-data samples describe narrower results:

| Retained workload | Result |
| --- | --- |
| [233 KQA programs](../evidence/2026-10-28-programs.json) | 225 correct, 8 withheld, 0 wrong; all pinned operations exercised. |
| [100 retained reader questions](../evidence/2026-10-29-segment-reader-validation.json); [re-run with the arena and scalar-query changes](../evidence/2026-10-29-combined-qualification.json) | 36 correct, 4 refused, 60 unknown, 0 wrong or execution errors. Segment/nested composition adds interpretations, with no answer gain on this set. The combined re-run (Linux release, plus a macOS debug check) gives the same counts and the same outcome on all 100 questions. |
| [New 16-question segment/nested acceptance cohort](../evidence/2026-10-29-targeted-composition.json); [re-run with the arena and scalar-query changes](../evidence/2026-10-29-combined-qualification.json) | First run failed acceptance: 1 correct, 7 unanswered, 4 expected declines, 4 byte-limit errors. After the arena and scalar-query changes, Linux release and macOS debug both give 2 correct, 8 unanswered, 6 expected declines, 0 wrong, 0 errors; the 8 unanswered are still misses (`answer_form`), so acceptance is not met. |
| [Hosted/relocated appliance](../evidence/2026-10-29-stable-appliance-validation.json) | Durable HTTP and relocated package journeys passed on manufactured data. This does not qualify the full Oracle Engine or signed Mini integration. |
| [31 October hosted consumer workflows](../evidence/2026-10-31-sol-wave-validation.json) | Calibration 16/16, thermal scenarios 9/9, sequence search 7/7 dev and 10/10 held-out, exact blends 4/4. No wrong answers or false acceptance in these manufactured supplied-data cases; separate from shipped specialist exams. |
| [Plural-first reader experiment](../evidence/2026-10-31-native-expansion-validation.json) | Release targeted cohort improves from two correct/eight unanswered/six expected declines to ten correct/six expected declines; original 100 has 36 correct with no coverage gain. Both release cells have zero wrong/errors at the same one-second limit. Earlier debug deadline failures remain in the first-wave receipt. |
| [Expansion workflows](../evidence/2026-10-31-native-expansion-validation.json) | GLM 27/27, sequential monitoring 26/26, thermal transients 12/12, translation 8/8 dev and 12/12 held-out, exact optimization 6/6, scalar context 8/8. These include intended refusals. Durable evidence and the 64-tenant journey are checked separately. |

Language coverage still excludes content-key fallback, deeper nesting, analogy,
clause/date wrappers and the complete upstream routing/dialogue system. Reader
interpretations are learned hypotheses about meaning. Query completeness is
relative to the admitted image and plan, not the world.
