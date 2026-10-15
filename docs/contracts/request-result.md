# C03 — Requests, interpretations, results and diagnostics

Semantic revision 1. Descriptor format remains `veri7vn.package/0`.
These are shared semantic variants; wire encoding and concrete ML
signatures are **reserved**, pending the first integrated native client.

## Request

A request has a correlation ID, a pinned immutable environment and a request
observation context (C04), input, an interpretation policy, explicitly allowed
assurance routes (C02), and an execution budget/effect policy (C05). The observation
context names the relevant session/state versions and evaluation time with its clock
basis; explicitly stateless/timeless work records that distinction. Follow-up answers
and freshness decisions must not silently read whichever state or wall clock happens
to be current. A natural-language input is text plus source spans. A structured input
uses a declared capability-specific codec or a native term in its context; there is
no universal JSON encoding of arbitrary HOL values. The input's pretty printing is
never treated as its semantic identity.

Preserve the original input immutably while retained under C04: bytes where available, otherwise
codepoints with the declared encoding boundary. Normalized language is a derived
view with explicit mappings back to original spans, including deleted/expanded
segments. Record which view was interpreted. Embedded code, quoted strings, byte
payloads and case-sensitive symbols pass through their declared literal codec;
language normalization must not silently change them. Hashing two spaces and one
space, parsing multiline JSON and interpreting genotype case are distinct operations.

Families register extensible semantic profiles: native carriers/types, operation
signatures, representation relations, supported codecs, display projections,
materialization bounds and evidence obligations. Profiles declare literal encoding,
normalization/escaping, exact or approximate numeric conventions, permitted
operations/conversions and relevant model/reference parameters. This covers such
distinctions as affine temperature points versus differences, logarithmic levels,
frames and angles, finite probability models, and calendar dates versus durations.
No shared scalar-plus-unit encoding or closed universal HOL value type substitutes
for these distinctions. A codec cannot serialize native proof authority. Detailed
registries and codec signatures remain a shared implementation design decision.

Resolved inputs are explicit interpretations. Each interpretation records its
originating spans, recognized grammar/rule bindings, entity/role choices, native
target and still-open conditions. A model-generated reading is a proposal until
the chosen interpretation policy accepts it. Correct reasoning about one reading
does not prove that it captures the human's intended question.

Interpretation produces one of:

```text
Resolved(reading)
Ambiguous(nonempty alternatives, separating choices)
Unrecognized(diagnostics)
```

Resolving ambiguity must retain the selected interpretation and the decision that
selected it. Dispatch order is not permission to discard meaningful alternatives.
The engine must support author inspection and repair of interpretation independently
of executing a specialist.

Routing separately records applicable candidates, unresolved interpretations and
scoped blockers. A blocker names the interpretation, premise, capability or request
scope it constrains and what would discharge it. A fallback cannot evade an applicable
failed check; rejecting one reading need not forbid a different justified reading.
Precedence and continuation decisions are versioned policy with inspectable
observations, not a universal core-first or try-next-on-decline rule. Refusal limits
particular claims or actions; it need not prohibit explanation, clarification or help.
Internal routing dispositions distinguish no reading, unsupported capability, missing
dependency, unresolved interpretation, rejected candidate and an established
obstruction. They are not interchangeable with the final user outcome. Arbitration
checks whether an alternative preserves the requested claim, resolves its obstruction
or requires a fresh interpretation decision; conflicting candidates are compared
under the same interpretation/source policy rather than taking the first answer.

## Claim scope, response acts and artifacts

Claim scope/modality, assurance route and artifact lifecycle are orthogonal. Preserve
asserted, conditional, quoted, hypothetical and fictional framing as applicable.
Also preserve whether the claim is a mathematical consequence, a report of a source/engine run,
a finite-model prediction, a test observation, or an optimum over a stated candidate
set. A proved classifier computation does not establish real-world label accuracy;
a score in `[0,1]` is not thereby a probability. Assumptions, candidate/model universe
and observation conditions belong to the claim, not only to optional prose.

An ordinary-user response may deliver candidate code, other artifacts, clarification,
reference commands or conversational speech acts without claiming a universally
correct executable capability. Such responses need not be encoded as failed theorem
answers. A candidate can carry exact test observations and outstanding obligations;
neither its delivery nor passing those tests activates or admits it. Commands supplied
as reference text remain data until a separate authorized execution (C05). Accepted
claims about any observations still need their proper scope and existing C02 route;
there is no fourth empirical proof route.
Fictional/role-play framing must survive rendering and persistence; it cannot create
an external-action receipt. A helpful acknowledgement alongside a blocked world claim
is not an evasion of the block.

An engine-observation capability must bind the actual version/configuration, exact
input/setup, output/error and execution boundary. An error reported by that engine
may be the requested observation; a timeout cannot be relabeled syntax invalidity.
The observer itself needs a real implementation contract. Wrapping arbitrary Python
and reporting that it ran is not a completed lift of its domain semantics.

Artifacts and claims bind their actual referenced content. A check of metadata or
a pre-render plan does not establish a property of emitted bytes, pixels or a final
document. That stronger claim needs a rendering/serialization connection or validation
of the actual output. Generated illustration is decoration unless separately licensed
as evidence; exported explanations retain conditions and historical status.

## Result variants

```text
Accepted(licensed structured claim/result, interpretation,
         accepted assurance record, explicit conditions, dependencies,
         request observation context)
NeedsInput(alternatives or missing conditions, diagnostics)
Declined(reason, diagnostics)
Inconclusive(reason, searched_scope, diagnostics)
Failed(diagnostics)
Cancelled(diagnostics)
```

`Inconclusive` includes timeout, budget exhaustion and incomplete search. It is
never an accepted negative answer. A missing store is a dependency failure, not
evidence that no matching fact exists. A successful existence witness and a complete
enumeration of all results require different evidence. A conflict can be an accepted
structured report *about conflicting source statements*, provided that is the exact
licensed claim; it is not unrestricted permission to infer from contradictory facts.

These variants describe claim/subgoal outcomes, not the entire vocabulary of response
acts or artifact delivery. Only `Accepted` carries an accepted assurance record for
its exact claim. A candidate artifact may be shown in ordinary workflows with its
separate lifecycle and supported observations; it never silently becomes an accepted
universal correctness claim.
Conditions and provenance are retained even if ordinary UI text is concise. The
renderer must preserve claim polarity, scope, units, numeric semantics, alternatives
and conditions. Streaming progress events have no answer-acceptance authority.

Multipart responses retain an outcome, interpretation, conditions and dependencies
per subgoal, plus their dependency graph. An answered part does not discharge another
part; dependent subquestions consume explicit typed intermediate results/state,
not reparsed answer prose or unrelated sessions. Collections retain schema, ordering,
multiplicity and completeness/coverage: a displayed prefix is not all rows, SQL NULL
is not an execution failure, and no unique mode differs from unavailable data.
Preserve witnesses, costs and optimality bounds separately. Feasibility does not
prove minimality; failure to find a witness does not prove impossibility. Pagination
and display truncation must not silently strengthen the structured claim.
The turn's partial/completed summary follows that graph. Independent nodes can run
concurrently. Speculative search, tests and refinement may consume candidate artifacts
as candidates, retaining their unresolved obligations. Authoritative claim/state
consumers cannot treat those values as accepted bindings or silently discharge a
blocked dependency. Partial-progress commit policy remains explicit under C05.

## Diagnostics

A diagnostic contains a stable code, severity, author/user-readable explanation,
relevant source spans or object locators, and optional counterexamples or proposed
repairs. The initial vocabulary is:

- `package.invalid`, `package.unresolved_export`, `environment.mismatch`
- `interpretation.ambiguous`, `interpretation.unrecognized`
- `admission.target_mismatch`, `admission.undeclared_assumption`,
  `admission.forbidden_dependency`, `admission.unresolved_obligation`
- `execution.domain`, `execution.budget`, `execution.cancelled`,
  `execution.unavailable`, `execution.failure`
- `source.unavailable`, `source.conflict`, `source.coverage_required`

Codes identify the category; structured details explain the actual failure.
Do not put secrets or unrestricted backend dumps into user-facing diagnostics.
Repair proposals distinguish changes that preserve intended meaning from changes
to the domain/specification. For real square roots, restricting `x >= 0` and changing
`sqrt(x*x) = x` to `sqrt(x*x) = abs(x)` are different repairs.

## Cross-lane checks

Exercise a resolved mathematical request, ambiguous entity, missing source,
conditional theorem, source conflict, forbidden assurance route, exhausted search,
and cancelled request end-to-end. The client must not turn a non-accepted claim into
an accepted assertion, strip a premise, or confuse historical and current answers.
Also exercise literal round trips/span maps, typed NULL/blob rows and truncation,
exact rationals/framed vectors, feasible-but-nonoptimal witnesses, partial dependent
subgoals, ordinary tentative code with observed tests, a scoped blocker and a rendered
artifact whose metadata alone is insufficient to establish the requested property.

These are source-backed requirements from [G01–G04/G08](../review/PREIMPLEMENTATION.md),
[domain DG-01–DG-07](../review/domain-gaps.md), and [workbench findings 3/8](../review/workbench-gaps.md).
The [runtime R1–R4/R7 review](../review/runtime-gaps.md) supplies the routing,
dependent-turn, ordinary-artifact and final-arbitration cases.
They are not claims that the present native smoke tests implement these behaviors.
