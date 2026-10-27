# Learned representations and symbolic programs, 27 October 2026

Owner: Sol literature lane. **No specialist panels ran; no new panel numbers or
runtime improvement are claimed.** No production source, theorem, model or
appliance was changed. This lane provides primary papers, a concrete experiment
design and five tiny tests of the distinctions below.

The useful ambition is broader than a neural parser in front of a proof checker.
A readout can compute a useful relation or quantity that Oracle cannot currently
compute, even if it neither controls nor explains the base model's answer.
That should be a first-class empirical operation. Separately, we can train
representations to follow an intended symbolic computation and test that claim
with interventions. Neither route needs to wait for the other.

Eleven primary PDFs and the circuit-tracing paper in its native author HTML are
saved under
[/Users/ember/paperbin/oracle7-20261027/neurosymbolic/](/Users/ember/paperbin/oracle7-20261027/neurosymbolic/README.md).
The [manifest](/Users/ember/paperbin/oracle7-20261027/neurosymbolic/manifest.json)
records source/resolved URLs, hashes, authors, publication/preprint distinctions,
reading depth and negative evidence. Selected full-text sections were read, not
every page. This is a bounded research selection, not a frontier census.

Both requested search systems were used: **seven Kagi queries** and **three
Scry queries**, with literal limits 15, 10 and 5 under the existing client's
10-million-nanodollar per-query guard. All completed, returning 9, 10 and 3
rows. The broad causal-training search returned mixed-domain material; targeted
lookups verified the selected records. Scry's frozen catalog receipt has an
observed extent ending 26 September, so it cannot establish complete October
coverage. Queries, raw results and schema are saved in `search/`; primary PDFs
and author/publisher pages were checked before using claims. Neither credential
was printed, shell-sourced or saved in the artifacts.

## What the sources establish

| Work and primary source | Useful result | Boundary and Oracle consequence |
| --- | --- | --- |
| Ellis et al., [DreamCoder](https://arxiv.org/abs/2006.08381), 2020 preprint | Neural recognition guides typed program search; solved programs yield reusable library abstractions; replay and imagined tasks train the next recognition model. | Program examples can underspecify intent; the paper concentrates on crisp symbolic solution spaces. Learn reusable operation compositions rather than unrestricted Python; examples and panel success are not universal specification proofs. |
| Gurnee and Tegmark, [Language Models Represent Space and Time](https://arxiv.org/abs/2310.02207), ICLR 2024 | Linear regression from internal activations recovers spatial coordinates and temporal quantities; evaluation includes block holdouts and changes of entity type. | Their country-centroid counterexample explains why ordinary random splits can overstate geometric structure. A numeric readout is already useful computation; geographic/time generalization requires stronger splits. It does not make a sourced current fact. |
| Burns et al., [Discovering Latent Knowledge](https://arxiv.org/abs/2212.03827), 2022 preprint / ICLR 2023 | Contrast-Consistent Search (CCS) extracts yes/no classifiers from activations without task labels and can outperform generated answers in their evaluations. | This makes activation readout a capability channel worth evaluating, independently of what a chat head emits. It does not establish a universal truth direction. |
| Farquhar et al., [Challenges with unsupervised LLM knowledge discovery](https://arxiv.org/abs/2312.10029), 2023 preprint | Arbitrary classifiers can satisfy CCS consistency; distracting features and simulated characters can change what is recovered. | Keep the positive CCS result and its refutation together. Test readout utility against labelled held-out tasks and distractors; low consistency loss alone cannot identify truth. This criticism does not refute supervised readouts generally. |
| Koh et al., [Concept Bottleneck Models](https://proceedings.mlr.press/v119/koh20a.html), ICML 2020 | Predicted concepts become an intermediate interface that humans can edit; independent, sequential and joint training expose different tradeoffs. | Editing a predicted concept is an intervention inside the model, not a real-world causal intervention. Our typed relation/type/entity fields can be such a bottleneck, provided residual channels do not secretly carry the decision around it. |
| Geiger et al., [Inducing Causal Structure](https://proceedings.mlr.press/v162/geiger22a.html), ICML 2022 | Interchange intervention training (IIT) trains aligned internal swaps to match counterfactual outputs from a specified causal model. | The full zero-loss abstraction statement concerns the specified input/intervention domain. A low sampled training loss is an empirical result. This is the most direct answer to deliberately training desired computational representations. |
| Geiger et al., [Distributed Alignment Search](https://arxiv.org/abs/2303.02536), 2023 preprint / CLeaR 2024 | DAS fits an orthogonal alignment so symbolic variables can occupy distributed subspaces rather than individual neurons. | Post-hoc alignment search freezes the base network; IIT changes it. Fit the alignment only on training data and test unseen source/base pairs, dimensions and negative-control variables. A learned alignment needs validation, as does a learned probe. |
| Zou et al., [Representation Engineering](https://arxiv.org/abs/2310.01405), 2023 preprint, downloaded revision 2025 | Population-level reading and control methods include direction-based readouts, activation steering and representation-adaptation objectives. | Reading utility, behavior control and factual correctness are separate measurements. A steering vector that changes answer style or apparent confidence does not warrant a factual claim. Readout-only success remains valuable. |
| Ameisen et al., [Circuit Tracing](https://transformer-circuits.pub/2025/attribution-graphs/methods.html), March 2025 | Cross-layer transcoders learn a sparse replacement computation; attribution graphs and interventions test local hypotheses. | The authors document missing attention computation, reconstruction errors, feature splitting/absorption and mechanistic-faithfulness failures. A readable replacement model can approximate outputs without using the same mechanism. Use this to discover candidates and diagnose small models, with original-model intervention checks when claiming a mechanism. |
| Karvonen et al., [SAEBench](https://arxiv.org/abs/2503.09532), ICML 2025 | Multiple downstream and disentanglement evaluations reveal that reconstruction/sparsity proxy improvements need not improve practical utility. | The downloaded v4 describes eight metrics; older abstracts say seven. Choose features by the operation's held-out utility and interference tests, not only automated feature descriptions or reconstruction error. |
| Gao et al., [Weight-sparse transformers have interpretable circuits](https://arxiv.org/abs/2511.13653), November 2025 preprint | Training with sparse weights can yield small, understandable task circuits; sparsity and scale move the capability/interpretability tradeoff. | The paper reports substantial compute inefficiency, remaining polysemanticity and limits on scaling beyond small models/simple tasks. Sparse-weight pretraining is an architectural research branch, not the first Oracle implementation step. |
| Galliamov et al., [Concepts' Information Bottleneck Models](https://arxiv.org/abs/2602.14626), ICLR 2026 | Information-bottleneck regularization targets redundant input information leaking through concept activations. | Their estimator and entropy-surrogate objectives have assumptions; accuracy/intervention results on their datasets do not establish semantic completeness or zero leakage in Oracle. This is a useful regularizer to ablate after the basic typed bottleneck works. |

A newer lead, [Subspace-Aware Sparse Autoencoders](https://arxiv.org/abs/2606.06333),
June 2026, was checked against its primary metadata and abstract. It replaces
single decoder directions with groups of subspace features, targeting feature
splitting. Its full paper and theorem assumptions were **not** reviewed here;
its claims are a follow-up lead, not a reason to select that architecture now.

## Three questions with different evidence

1. **Can we compute a useful function from this representation?** Fit a linear
   readout first, then a capacity-controlled nonlinear one if useful. Evaluate
   on untouched entities, domains and compositions, with uncertainty and
   abstention. A function that beats existing operations is valuable even when
   its mechanism is unknown and the base model never emits the result.
2. **Does this representation explain the base computation?** State a high-level
   variable and its expected effect; intervene and compare with the predicted
   counterfactual, controlling nuisance variables. Correlation alone cannot
   establish this. Conversely, failure of that causal alignment does not
   invalidate an independently useful readout.
3. **Is the result semantically correct for this question and world?** A program
   can typecheck and compute exactly while answering the wrong relation or using
   incomplete evidence. Simulation, steering, causal fidelity to a mistaken
   program and readable features do not establish truth. Empirical operations
   earn measured reliability; checked operations retain their explicit premises.

These are independent axes, not a ladder on which every capability must become
a proof before it is usable. A readout may compute an accurate new abstraction
without being a faithful account of the base decoder. A causal description may
faithfully explain an incorrect answer.

## Fit with the actual Oracle paths

The current direct Workbench operations in `tools/oracle_workbench/operations.py`
already accept structured inputs for table selection, document questions,
sensors and prose. Their catalog carries schemas, examples, limitations and
source hashes. That is a natural operation boundary for learned capabilities;
the schema is not itself a factual proof. Document questions currently reach
the keyword passage reader, and ProseFold's fidelity check is lexical.

`tools/relations/query_request.py` already produces a property, entity slot and
type constraint. `interpret` preserves competing literal-title and typed-name
readings; `frontdoor.py` composes readers conservatively. A learned parser should
produce this meaning explicitly, including unresolved alternatives, rather than
silently replacing those checks. The relation literature lane also identifies
missing classification/coverage, equal-label identities and unknown alternatives.
Neural confidence does not supply these missing premises.

Workbench's upstream MCP learning in `upstream/workbench/mcp.py` learns words
from user marks. That is a concrete existing learning loop, but word credit does
not learn a causal representation. DreamCoder suggests a stronger future loop:
learn reusable typed operations from successful tasks, then train recognition
and search around the expanded library. Promotion still needs the real exam,
independent counterexamples and bounded execution. No unrestricted learned-code
builder is added by this report.

## Two small capability experiments

The following sizes, operation names and acceptance criteria are **proposed**.
No training dataset, real model result or admission decision exists yet.

### A. Useful readouts as empirical operations

Start with `representations.time_estimate`: input is a historical entity name or
short attributed passage; output is an estimated date/interval or abstention.
Gurnee/Tegmark supplies a direct precedent for this numeric readout. This is
useful when a source does not give an explicit date, and can support ordering,
approximate search or historical grouping. Do not relabel the estimate as an
explicit source date. The source-precise date reader and the estimated operation
can both be offered with different meanings.

Use roughly 1,200 dated examples across people, works and events, drawn from
records already available for this purpose. Exclude ambiguous date roles and
edition/territory conflicts from the first task, or label those roles explicitly.
Compare a majority/mean baseline, character/token features, the current Oracle
operation, a prompted model answer, a frozen embedding readout and, where
activations are available, a layer-specific readout. Benchmark additional
capability over these baselines, rather than assuming hidden activations win.

Freeze an entity-disjoint test set before selecting layer, readout dimension or
regularization. Also hold out an entire entity class and contiguous time blocks;
test paraphrases, aliases, misleading modern dates in surrounding text and
counterfactual rewrites. Preserve duplicates by entity/work/edition as one group
across splits. Hidden pretraining exposure remains possible; a probe-test split
alone cannot establish training-corpus novelty. Report MAE, median and tail
absolute error, interval coverage/width and risk versus answered fraction by
held-out group. Select abstention thresholds on validation only. Calibration
under one distribution is not a guarantee after a historical/domain shift.

Return an explicit empirical receipt: task and date-role definition, model and
readout hashes, embedding/activation site, training-data revision, validation
scope, estimate/interval, uncertainty method and abstention reason. The operation
may return its own estimate to the user; it need not remain a search proposal.
If a caller later retrieves a source-backed exact date, expose that additional
evidence separately. Missing classification and coverage remain unknown.

The same interface can support a more semantic operation next:
`representations.relation`, a supervised readout deciding whether two supplied
passages support, contradict or leave a specified relation unresolved. That can
perform useful semantic work beyond lexical ProseFold comparisons. Test entity,
domain, negation, quantifier, attribution and composition holdouts against lexical
and prompted baselines. It is a learned relation judgment with empirical error,
not a semantic-equivalence theorem. Labels need explicit scope and independent
review; high agreement with weak labels cannot establish the desired semantics.

No causal-intervention requirement is imposed on either operation's utility
claim. Intervention tests become relevant if we additionally claim to have found
the mechanism the base network uses.

### B. Learned semantic parser to typed symbolic execution

Start with the existing relation-request shape and two Workbench operations:
`workbench.tables.lookup` and `workbench.documents.query`. Build a fixed,
non-executable JSON IR with operation ID, relation/property, literal entity span,
requested type, source handle, constraints and alternative parses. Do not allow
model-written paths, URLs, commands, fetch-completeness flags or code.

Train from about 600 manually checked request/IR pairs plus programmatically
generated contrast pairs. Include literal titles beginning with type words,
homonyms, inverse requests, conjunctions, unknown classifications and unsupported
requests. Split whole templates, entities and domains before training. Reserve
compositional holdouts such as known relation + previously unseen requested type.
Use a small trainable encoder with explicit heads for operation, property, kind
and span; let the existing table/relation execution path compute the result.
Train an abstention/alternative decision explicitly.

The checker rejects invalid IR, undeclared operations and unsatisfied evidence
premises. It cannot by typing alone detect a valid P50 parse of an intended P86
question. Measure exact semantic parse accuracy and end-to-end right/wrong/
withheld separately. Retain uncertainty over competing meanings; a valid wrong
parse is still wrong. Learned retrieval may rank candidates, but top-k truncation
must not become evidence of unique identity.

The experiment should compare (a) current rules, (b) task-only learned parser,
(c) parser with supervised concept bottleneck, and (d) the same bottleneck plus
intervention/equivariance objectives. These are ablations of capability and
structure, not four production deployments. Keep a frozen checkpoint and bounded
CPU smoke evaluation before any larger training decision.

## How to train the representations deliberately

Let `z_op, z_relation, z_kind, z_entity` be assigned latent blocks; allow a separate
explicitly labelled residual block only if the task needs it. A proposed loss is:

```text
L = L_task(IR)
  + a * L_concept(operation, relation, type, entity span)
  + b * L_interchange(symbolic counterfactual outputs)
  + c * L_equivariance(known meaning-preserving/meaning-changing rewrites)
  + d * L_bottleneck_or_group_sparsity
```

This is an Oracle experiment proposal inspired by the sources, not an objective
reported or validated for this repository. Compare each term against task-only
training and measure its cost in ordinary task accuracy and useful coverage.

For IIT, take a base request and a source request. Swap only the relation block;
the model should produce the base entity/type with the source relation. Swap only
the entity block and require the opposite dependency. Construct the reference
counterfactual from the typed IR, not from another model's free-form explanation.
Only compare swaps whose meaning and types are defined in the reference domain;
log invalid combinations separately. Evaluate unseen base/source combinations
and intervened multi-step compositions, alongside off-target effects.

For equivariance, alias substitution should transform the entity pointer while
preserving relation/type; an actual predicate rewrite should change the relation;
irrelevant quoted prose should preserve the request; negation, quantifiers and
scope changes must not be treated as synonyms. Apply entity permutation and
surface-order changes where their semantic mapping is known. Contrastive
embeddings can cluster genuinely equivalent typed programs and separate
near-miss programs, but only where the equivalence labels are warranted.

Soft concept probabilities and vector-valued concept embeddings can hide extra
information; a residual route can bypass the intended bottleneck. Compare hard
discrete/typed decisions, soft bottlenecks and residual ablations. Ask whether
each labelled concept is sufficient for the task: if the ontology omits
negation, date role or scope, forcing all prediction through it can destroy useful
information or incentivize leakage. Neither sparsity nor orthogonality alone
gives semantic disentanglement. Probe leakage/capacity controls include random
labels, shuffled concepts, nuisance-only readouts, lexical baselines and
low-capacity readouts; fit all feature selection and alignment on training only.

DAS is a post-hoc test if we start from an existing white-box encoder: freeze it,
learn an alignment on training examples, then evaluate interchange accuracy on
held-out pairs with the same negative controls. IIT instead changes the encoder
so a chosen computational abstraction becomes easier to read and intervene on.
SAEs/transcoders can discover unexpected candidate variables after either route;
require downstream utility for capability claims and original-network causal
tests for mechanism claims. A novel discovered variable might become a useful
new operation even before it has a symbolic counterpart.

## Required access and practical order

| Access | What is feasible | What it does not provide |
| --- | --- | --- |
| Text-only frontier API | Generate typed-program candidates, collect labelled behavior, distil a smaller model, compare prompted outputs. | Internal activation readouts, arbitrary activation patching, true base-model IIT/DAS, or SAE/transcoder training on that model. |
| Hosted embedding API | Train linear/nonlinear readouts or metric learning on the returned vector; evaluate them as independent functions. | An embedding is not necessarily a chat model's internal residual state. Success does not reveal its internal chat mechanism. |
| Open weights plus activation hooks | Readouts, controlled probes, DAS/patching, feature mining and a small trainable representation model. | Automatic access to the internals of an unrelated closed frontier model. Compute and supported architecture still matter. |
| Trainable weights and gradients | Joint task/concept/IIT objectives and architectural bottlenecks; sparse training as a later branch. | A guarantee of correct concepts, complete evidence, semantic equivalence or world truth. |

Run empirical readout A and typed-parser B as separate scoped experiments. If B
is already useful but its latent organization is poor, IIT provides a concrete
next experiment. Do not begin by training a frontier-scale sparse model or a
new transcoder dictionary. The public [circuit-tracing release](https://www.anthropic.com/research/open-source-circuit-tracing)
shows that tools exist for supported open-weight models; it does not grant
white-box access to a frontier API we can call.

## Exact local result and remaining consumer work

Repository changes are this report and
`tools/usage/neurosymbolic-literature/{README.md,test_claim_boundaries.py}`.
Command:

```sh
python3 -B tools/usage/neurosymbolic-literature/test_claim_boundaries.py
```

Exact latest result: **5 tests passed in 0.003 seconds**. A hand-written readout recovers
the intended quantity on **49 synthetic states**, while **2,401 aligned quantity
swaps** leave the base decoder's output unchanged. Another example has perfect
observational readout on correlated data but fails **12/16** proposed causal
swaps. The other tests distinguish valid typing from intended relation, unknown
from false, and empirical estimates from sourced facts. These are finite
illustrations of the evaluation contracts; **no neural model was trained or
interpreted**. No Isabelle build, Engine run, GPU install or production edit ran.

Root owns choosing the first empirical task and sourcing its labels, adding the
operation provider and receipts, and connecting the parser to actual consumers.
Current interfaces can host both empirical and checked operations, with claims
appropriate to each. Before a runtime claim, run focused integration regressions
and the actual specialists' shipped panels under all six criteria. That scoreboard
remains the project's completion metric; this research adds no numbers to it.
