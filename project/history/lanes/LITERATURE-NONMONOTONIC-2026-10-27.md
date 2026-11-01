# Nonmonotonic reasoning for Oracle7, 27 October 2026

Owner: Sol nonmonotonic literature. **Panel numbers: none.** This lane changed
no active appliance, source kernel, upstream checkout or shipped specialist.
The experiment below is an untrusted design model, not measured Oracle behavior.

My recommendation is to build a small **assumption and dependency layer over
signed, scoped evidence**, then add bounded answer-set planning when there is a
real planning consumer. Nonmonotonic reasoning is useful here precisely because
it can make assumptions explicit and withdraw their consequences. Applying
closed-world negation indiscriminately to the relation store would worsen the
missing-classification and currentness failures in
[the relation audit](RELATIONS-SEMANTICS-2026-10-27.md).

Here, an assertion's sign means positive or negative polarity. Authentication
of its source is a separate property; the proposed polarity field is not a
cryptographic signature.

Eight primary papers, six newly fetched and two reused, are collected in
[/Users/ember/paperbin/oracle7-20261027/nonmonotonic/](/Users/ember/paperbin/oracle7-20261027/nonmonotonic/README.md).
The [manifest](/Users/ember/paperbin/oracle7-20261027/nonmonotonic/manifest.json)
records URLs, SHA-256 hashes, byte counts, versions, discovery and reading depth.
Selected full-text definitions and examples were read; no cover-to-cover claim.
Four Kagi queries and three Scry queries were used, with raw results retained in
`search/`. Scry used exact identifiers, literal LIMIT 5 and the existing client's
10-million-nanodollar exposure guard. One remembered arXiv identifier turned out
to name an unrelated physics paper and was rejected. Credentials were parsed in
process and never sourced, printed, or stored in the research outputs.

## The history points to different jobs

- [Reiter, 1980](http://www.horty.umiacs.io/courses/readings/reiter-default-1980.pdf),
  §§2.1–2.2, defines default theories and their fixed-point extensions. A default
  licenses a belief when its prerequisite holds and its justifications remain
  consistent with the eventual extension. There may be multiple extensions or
  none. This is a semantics for defeasible beliefs; an ordinary forward-chaining
  `if no exception then conclude` loop does not implement it in general.
- [McCarthy, 1980](https://www-formal.stanford.edu/jmc/circumscription.html)
  makes the choice of what to minimize central: circumscribe an abnormality
  predicate to express “normally,” for example. Minimizing every missing KG
  relation silently says the available graph is the world. The saved author PDF
  is a later version dated 1986 with an addendum; the author index identifies the
  original 1980 publication. Those dates should not be conflated.
- [de Kleer, 1986](https://www.dekleer.org/Publications/An%20Assumption-Based%20TMS.pdf),
  §§4.2–4.3, labels conclusions with minimal consistent sets of assumptions and
  records inconsistent environments. This supplies the machinery to explain
  which contexts support a conclusion. An ATMS does not by itself choose a
  nonmonotonic semantics or decide which source deserves belief. Its original
  Horn justification language does not admit arbitrary negated literals.
- [Alchourrón, Gärdenfors and Makinson, 1985](https://doi.org/10.2307/2274239),
  pp. 510–514, gives postulates and partial-meet constructions for contraction
  and revision of belief sets. It clarifies the difference between removing a
  belief and admitting a new belief while giving up conflicting commitments.
  Oracle needs source-level update policy before adopting those abstract
  operations: an untrusted new assertion should not automatically win.
- [Gelfond and Lifschitz, 1988](https://www.cs.utexas.edu/~vl/papers/stable.pdf),
  §2, defines the reduct and stable models. Its examples admit zero or several
  stable models. Modern ASP uses alternative models for search; returning the
  first model establishes a possible answer, not agreement across alternatives.
- [Van Gelder, Ross and Schlipf, 1991](https://doi.org/10.1145/116825.116838),
  §§1.3, 3, 5 and Theorem 8.1, gives one well-founded partial interpretation,
  leaving some atoms undefined. For fixed function-free programs its data
  complexity is polynomial. It is useful for deterministic recursive rule
  evaluation, but not equivalent to computing every skeptical stable-model
  consequence. “False in this program” still does not mean “false in the world.”
- [Sutcliffe, Pelletier and Hazen, 2018](https://cdn.aaai.org/ocs/17599/17599-77711-1-PB.pdf),
  §§1–2, develops conditional connectives for Belnap-style four-valued reasoning.
  Its four values separate neither assertion being supported from both being
  supported. Its discussion of implication and modus ponens matters: storing
  four flags alone does not implement a complete paraconsistent rule language.
  The original Belnap papers date to 1977; this collection contains the 2018
  primary research paper, not an original Belnap scan.
- [Gebser et al., journal 2019](https://doi.org/10.1017/S1471068418000054),
  §§3–4, supplies a concrete operational account of multi-shot ASP and external
  inputs. The saved arXiv v2 dates to 2018 and the first preprint to 2017.
  External atoms can activate rules across solves. Releasing an external makes
  it permanently false in that role; it is not the same operation as temporarily
  assigning it false. A reusable worker must respect this lifecycle.

## Ranked integration candidates

### 1. Signed evidence, explicit assumptions and retractable receipts

This should precede a new solver. The first consumers are relation eligibility,
conversation corrections and composition of sourced answers. Store an immutable
assertion with `id, source, subject, predicate, object, sign, valid_interval,
observed_at, source_revision, tenant`. Keep valid time separate from observation
time: discovering an old event today does not make the event happen today.
Retraction/supersession events deactivate support; they preserve its history.

Give each query four source states: supported positive, supported negative,
unknown, or conflict. Combine evidence only after resolving identity, scope and
overlapping validity. Different historical dates need not contradict each other.
Do not force genders, occupations or aliases into single-valued predicates.
An explicit negative also needs provenance and a precise scope.

Keep the default layer separate. A receipt should contain:

```text
query, answer_kind (source | conditional | provisional | conflict),
tenant, snapshot_revision, as_of, rule_version,
positive_support_ids, negative_support_ids,
assumption_ids, absence_guards, coverage_ids, upstream_receipt_ids
```

`not_known(exception)` is a revision-bound guard, not evidence for
`negative(exception)`. For a world-level negative or unique answer, require
explicit exclusion or authoritative scoped closure, including its expiration,
candidate universe and intended predicate. A complete SQL result establishes
only retrieval completeness. A default such as “assume this person is current
unless a dissolution is stored” cannot repair present-tense source truth.

Start by recomputing the small scoped dependency graph after changes. Then add
reverse dependency indexes once measurements justify incremental maintenance.
Index absence guards as dependencies too: a newly inserted exception can
invalidate a conclusion although none of its positive supporting rows changed.
With independent supports, removing one source must preserve conclusions still
supported by another. Version the resulting receipt even if its text is unchanged.
Bound derivations and reject overflow rather than silently losing alternatives.

**Acceptance:** replay the missing-gender and missing-occupation counterexamples;
unknown and conflict both block unique selection. Add correction/retraction,
multiple independent supports, coverage expiry and reinserted-exception cases.
Run these through actual arbitration and final wording, then the relevant shipped
panels. The current experiment supplies only reference cases.

**Cost and alternative:** this is an evidence-contract change across fetch,
decision, cache and rendering, not a parser-only edit. A single-context TMS or
bounded dependency DAG is simpler initially than a full ATMS. Full ATMS becomes
valuable when many overlapping hypothetical contexts are actively queried, at
the cost of potentially exponentially many minimal assumption environments.
AGM does not remove the need to choose source precedence and finite belief-base
operations. Preserve unresolved disagreement instead of using recency alone.

### 2. A small rule language with stratified defaults, then WFS if needed

Use finite, typed, range-restricted rules over a declared bounded domain. Begin
with stratified negation so that rule dependencies have an inspectable order.
Strict evidence rules and provisional default rules should have different output
types. Bind every rule evaluation to the same source revision and time interval.
For a negative dependency cycle, reject the rule bundle initially; if genuine
consumers need it, implement or adopt WFS and return `undefined` for unresolved
cycles. Do not break cycles by iteration order or by assuming every absent atom
false in the source store.

**Acceptance:** `a :- not b; b :- not a` must not produce an arbitrary unique
answer. A failed recursive derivation, unknown external predicate, empty source
query and expired closure certificate must remain distinguishable. All variables
in a negative literal need a finite positive domain binding. Test joint updates
atomically so a reader never observes half of a correction.

**Cost and alternative:** fixed function-free WFS has a useful polynomial data
bound; large joins and grounding can still dominate. A bounded stratified engine
has a smaller semantics and verification surface. General Reiter default logic
or predicate circumscription offers more expressive modeling, but would make
extension choice, consistency and execution harder before Oracle has a concrete
need. They are good design references and later modeling options.

### 3. Bounded ASP for alternatives, planning and diagnosis

Add ASP when Oracle needs to choose compatible interpretations, find repairs or
compose a plan with resources and exceptions. An explicit task API could be:

```text
solve(task, source_revision, finite_domain, rule_bundle,
      assumption_scope, mode, time_limit, grounding_limit)
  -> models | inconsistent | incomplete | unsupported
```

Expose `possible`, `skeptical` and `optimal` as different requests. A feasible
model can justify a candidate plan. Skeptical answering requires a satisfiable
base program and a completed countermodel search: forbid the queried atom and
establish that the remaining program is unsatisfiable. Timeout, an interrupted
enumeration, or an unsatisfiable base cannot establish skeptical truth. A unique
optimum also needs a proved optimum bound and tie handling, not the first model.

In ordinary answer-set systems explicit/strong negation does not automatically
make inconsistency harmless. Encode source assertions as independent positive
relations `supports_plus` and `supports_minus`, derive conflict explicitly, and
keep the raw assertion ledger outside any consistency-enforced planning model.
Use conflicts to request evidence or produce repairs; never infer arbitrary facts.

**Acceptance:** bird/penguin exceptions; competing plan defaults; no-model and
multiple-model programs; contradictory sources; changing external inputs;
grounding/time exhaustion; tenant reset and stale-revision replay. Require a
counterexample-free completed search for skeptical claims. Compare the shipped
panels separately from planning diagnostics.

**Cost and alternative:** clingo multi-shot reuse can save grounding and learned
search work, but mutable solver state adds lifecycle and memory obligations to
the hosted worker pool. Begin with isolated task-scoped solves and explicit
bounds. A deterministic DAG is preferable for ordinary sourced fact answers;
SAT/SMT is preferable when arithmetic constraints dominate and defaults are only
a small part of the task. No current appliance memory or latency benefit is
claimed from this literature.

## Proof and execution boundaries

Keep the Isabelle metalogic classical. Represent signed assertions and
nonmonotonic consequence as data and object-level relations inside HOL. Never
import both a source assertion and its denial as unrestricted HOL assumptions.
A nonmonotonic update invalidates a receipt's premises; it does not retract an
Isabelle theorem. The useful statement is conditional on a rule version, source
revision, scope, evidence interpretation and any coverage premises.

Proposed obligations, **not proved theorems**:

1. Every returned strict receipt has active, scoped source support; provisional
   assumptions cannot become strict support through composition.
2. Updating a source or an indexed absence/coverage dependency invalidates every
   affected receipt before it is returned as current. Independent valid support
   can produce a replacement receipt.
3. If the candidate universe is covered, exactly one candidate has sound positive
   eligibility and all other candidates have sound negative eligibility, every
   consistent completion respecting those premises has the same unique answer.
   Conflicting or unknown eligibility prevents this answer.

A checked normal-program stable-model witness can establish feasibility by
checking its reduct and least model. It cannot alone establish skeptical truth
or optimality. Those require further complete search or checkable certificates.
Keep an external solver untrusted until the precise result it reports is checked.

Planning beliefs must also remain separate from execution authority. An assumed
precondition can create a proposal. Performing an operation needs positively
established authorization and fresh required preconditions. Absence of a denial,
or a default that an operation is safe, is not authorization. This connects the
reasoning design to the hosted appliance's existing scoped identities and exact
request/replay boundaries without changing them during qualification.

## Experiment, checks and remaining work

Changed files:

- `tools/usage/nonmonotonic-literature/retractable_defaults.py`
- `tools/usage/nonmonotonic-literature/test_retractable_defaults.py`
- `tools/usage/nonmonotonic-literature/README.md`
- this report

Run: `python3 -B tools/usage/nonmonotonic-literature/test_retractable_defaults.py`.
Exact result: **8 tests passed in 0.009 seconds**. This includes all **341**
four-state assignments over 0–4 candidate IDs, every two-valued completion of
their unknowns when evidence is consistent, dependent-default retraction,
independent supports, explicit negative/conflict containment, scope/time
separation and rejection of recursive defaults. The relation fixture is modeled
with IDs 102/103; it does not invoke the native relation binary or Engine.

The Python model recomputes one bounded DAG, permits one default per head and
does not implement full ATMS, general WFS, AGM revision, ASP, arbitrary temporal
inference, or an authority-checking execution layer. Its receipt revision covers
the entire active view, so it can invalidate more than necessary; it does not
demonstrate incremental performance. No Isabelle statement changed and no build
or specialist panel ran. There are no new panel numbers.

The consumer is root's next correctness/design batch. Integrate candidate 1 with
the relation lanes and real correction/composition consumers first, obtain their
fresh panel results, and record the scope of any new claim. Candidates 2 and 3
need a concrete rule/planning workload before adopting a larger solver runtime.
