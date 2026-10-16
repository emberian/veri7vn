# Research foundations

The research map supports three distinct improvements: logical knowledge (proved definitions/rules), search knowledge (heuristic ranking/strategies), and execution knowledge (compiled algorithms connected to specifications). A faster heuristic adds no axiom. Native contexts, specialized calculi, and explicit implementation bridges avoid both ad hoc tactic accumulation and a mandatory universal interpreter.

## Mechanisms worth reusing

| Work | Application and boundary |
| --- | --- |
| [Isabelle Framework](https://doi.org/10.1007/978-3-540-71067-7_7) | Native extensible contexts/inference provide logical state; application behavior still needs operational semantics. |
| [Eisbach](https://trustworthy.systems/publications/nictaabstracts/Matichuk_MW_16.abstract), [methods](https://isa-afp.org/browser_info/current/AFP/AutoCorres2/Eisbach_Methods.html) | Reusable structured goal/premise methods; search failure is not refutation. |
| [PSL](https://doi.org/10.1007/978-3-319-63046-5_32), [AFP](https://isa-afp.org/entries/Proof_Strategy_Language.html) | Lazy/backtracking/parallel strategies retain efficient successful replay; one replay is not a general theorem. |
| [IsaPlanner](https://doi.org/10.1007/978-3-540-45085-6_22) | Explicit contextual proof plans/continuations support lemma discovery; historical architecture needs compatibility work. |
| [Hipster](https://arxiv.org/abs/1405.3426), [goal conjecturing](https://arxiv.org/abs/1806.04774) | Enumerate/test/prove equations or goal-directed auxiliaries; tests propose, proofs certify. |
| [MaSh](https://doi.org/10.1007/s10817-016-9362-8), [TacticToe](https://doi.org/10.1007/s10817-020-09580-x) | Learn premise/tactic ranking while retaining independent acceptance. TacticToe is HOL4, not an Isabelle plugin. |
| [Sepref](https://doi.org/10.1007/s10817-017-9437-1), [network flow](https://doi.org/10.1007/s10817-017-9442-4) | Refine abstract algorithms into imperative representations with proofs. Fixed-width overflow and actual code execution remain obligations. |
| [Isabelle-LLVM](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.ITP.2019.22), [project](https://www21.in.tum.de/~lammich/isabelle_llvm_par/) | Potential optimized/parallel backend; semantic mapping, exporter, LLVM and ABI retain trust boundaries. |
| [Resource currencies](https://doi.org/10.1007/978-3-030-72019-3_11) | Track costs through refinement; retrieved text was incomplete and no latency claim follows. |
| [Congruence-closure proofs](https://arxiv.org/abs/2209.03398) | Optimize explanation DAG/replay size as well as search/extraction cost; side conditions must match numerical semantics. |
| [HOL-to-ML translation](https://doi.org/10.1017/S0956796813000282) | Explicit implementation relation is useful precedent, not a theorem about Isabelle's ordinary code generator. |
| [Stratified Datalog](https://www.isa-afp.org/entries/Stratified_Datalog.html), [nested relational algebra](https://doi.org/10.1145/3035918.3035961) | Precise recursion/environment semantics support query compilation; abstract correctness does not certify SQL/index implementations. |

Definitions/locales establish meanings; interpretation proposes a revisable typed question; strategies search native contexts; accepted results retain exact assumptions. Repeated computations can reuse proved algorithms/refinements. Sources remain attributed data. Negative, unique, ranked, or aggregate answers need completeness semantics beyond positive witnesses.

The inspected [PSL](https://github.com/data61/PSL), [Hipster](https://github.com/moajohansson/IsaHipster), and LLVM project versions do not establish Isabelle2026-RC1 compatibility. None was installed or compatibility-built by this research. Installed source and designated component checks decide adoption.

## Updates and nonmonotone provenance

[DBSP](https://www.vldb.org/pvldb/vol16/p1601-budiu.pdf) defines incrementalization `QΔ = D ∘ Q ∘ I`: accumulated output deltas equal full evaluation at each transaction time. Efficient maintenance replaces recomputation with proved compositional laws. Its [formalization](https://github.com/tchajed/database-stream-processing-theory) uses finite-support integer-weighted collections, distinct, relational operators, and recursive circuits; it is precedent, not an adopted Isabelle dependency.

Cache identity must include database version, query meaning, interpretation, and assumptions. Deletion needs multiplicity/support accounting; joins can amplify small changes. Uniqueness can change `0→1→many→1`; retaining only the winning row is inadequate. Anti-joins depend on excluded relations/coverage, minimum deletion needs replacement state, and windows require closure/watermark semantics.

[Provenance-lean v1.2.0](https://zenodo.org/records/22900284) distinguishes regular, aggregate-token, and provenance columns in its [kind-indexed language](https://github.com/PierreSenellart/provenance-lean/blob/v1.2.0/Provenance/AggQuery.lean). It deliberately restricts grouping, token comparison, difference, and deduplication; ungrouped scalar aggregation is excluded. Its [adequacy counterexample](https://github.com/PierreSenellart/provenance-lean/blob/v1.2.0/Provenance/QueryAdequacy.lean) leaves annotation `2∸1=1` where plain set difference removes the tuple. [Support adequacy](https://github.com/PierreSenellart/provenance-lean/blob/v1.2.0/Provenance/SupportAdequacy.lean) needs stronger monus-preserving conditions; [difference limitations](https://arxiv.org/abs/1105.2255) prevent uniform semiring generalization. Update weights, bags, possible worlds, and proof provenance are different meanings. No independent Lean build was performed.

## Reproduction

`tools/research_scry.py` uses [Scry's HTTP API](https://scry.io/docs/sql-over-https) and [error contract](https://scry.io/docs/errors), only `/v1/scry/{context,schema,query}`. It loads `~/.scry-key` internally, verifies TLS, disables redirects, redacts credentials, bounds requests, and avoids automatic retries. SQL-derived idempotency keys and defaults30s/10million nanodollars raw burden/multiplier1 bound calls; burden is not a price quote.

```sh
.venv/bin/python tools/research_scry.py context --output var/research/scry/context.json
.venv/bin/python tools/research_scry.py schema --output var/research/scry/schema.json
.venv/bin/python tools/research_scry.py schema --relation academic.papers --output var/research/scry/schema-papers.json
.venv/bin/python tools/research_scry.py query --sql-file var/research/scry/psl.sql --output var/research/scry/psl.json
```

Read schema first. Indexed lowercase `openalex.works.search_text_lc` searches titles, not authors/abstracts; `academic.catalog.title` is mixed-case. Exact `academic.papers` retrieval uses discovered DOI-derived `paper_key`, encoding later slashes `%2f`. Corpus gaps and incomplete extraction require primary-source checks.

Ignored `var/research/scry/` holds SQL/responses, `fulltext.json/fulltext2.json`, and `dbsp-discovery`, `dbsp-fulltext`, `nonmonotone-provenance` pairs. Text rows are `[paper_key,converter,quality_label,text]`; DBSP is `10.48550/arxiv.2203.16684`. An unrelated wrong-key result was excluded. Discovery metadata and quality labels are not compatibility/completeness evidence. Observed calls reported free_slack, zero spend, and no partial deadline; this promises neither future pricing nor complete literature coverage. Retrieved paper texts remain local working material, not redistribution content.
